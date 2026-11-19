// Only this importer uses the Vista-era shell/WIC interfaces. Keep the legacy
// framework's platform defines separate from the file chooser implementation.
#ifdef WIN32
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#if !defined(NTDDI_VERSION) || NTDDI_VERSION < 0x06000000
#undef NTDDI_VERSION
#define NTDDI_VERSION 0x06000000
#endif
#endif
#include "guildemblemimport.h"
#include "crypt.h"
#include <memory>
#include <mutex>
#include <thread>
#include <vector>
#include <cstring>
#ifdef WIN32
#include <winsock2.h>
#include <windows.h>
#include <shobjidl.h>
#include <wincodec.h>
#include <wrl/client.h>
#include <zlib.h>
#endif

namespace {
struct Job { std::mutex mutex; std::string result="pending"; };
std::shared_ptr<Job> active;
#ifdef WIN32
using Microsoft::WRL::ComPtr;
constexpr size_t maxFileBytes=65536;
uint32_t be32(const unsigned char* p) {
    return (uint32_t(p[0])<<24)|(uint32_t(p[1])<<16)|(uint32_t(p[2])<<8)|p[3];
}
// Bound dimensions and strip all ancillary metadata before entering the OS
// decoder. Uploaded files, compressed chunks and paths never go to the server.
bool sanitizePng(const std::vector<unsigned char>& input,std::vector<unsigned char>& clean) {
    const unsigned char signature[]={137,80,78,71,13,10,26,10};
    if (input.size()<45 || input.size()>maxFileBytes || memcmp(input.data(),signature,8)) return false;
    clean.assign(signature,signature+8);
    bool header=false,data=false,end=false;
    for (size_t offset=8;offset<input.size();) {
        if (input.size()-offset<12) return false;
        const auto n=be32(input.data()+offset);
        if (n>input.size()-offset-12) return false;
        const auto* type=input.data()+offset+4;
        const auto* bytes=type+4;
        if (crc32(0,type,n+4)!=be32(bytes+n)) return false;
        const std::string tag(reinterpret_cast<const char*>(type),4);
        if (!header && tag!="IHDR") return false;
        if (tag=="acTL" || tag=="fcTL" || tag=="fdAT") return false;
        bool keep=false;
        if (tag=="IHDR") {
            if (header || n!=13 || be32(bytes)!=32 || be32(bytes+4)!=32) return false;
            header=true;keep=true;
        } else if (tag=="PLTE" || tag=="tRNS") {
            if (data) return false;
            keep=true;
        } else if (tag=="IDAT") { data=true;keep=true;
        } else if (tag=="IEND") {
            if (n || !data || offset+12!=input.size()) return false;
            end=true;keep=true;
        } else if (!(type[0]&32)) return false;
        if (keep) clean.insert(clean.end(),input.begin()+offset,input.begin()+offset+n+12);
        offset+=n+12;
    }
    return header && data && end;
}
std::string chooseAndDecode(HWND owner) {
    ComPtr<IFileOpenDialog> dialog;
    if (FAILED(CoCreateInstance(CLSID_FileOpenDialog,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&dialog)))) return "error:The file chooser could not be opened.";
    const COMDLG_FILTERSPEC filters[]={{L"PNG emblem (32 x 32)",L"*.png"}};
    if (FAILED(dialog->SetOptions(FOS_FILEMUSTEXIST|FOS_PATHMUSTEXIST|FOS_FORCEFILESYSTEM|FOS_DONTADDTORECENT)) ||
        FAILED(dialog->SetFileTypes(1,filters))) return "error:The file chooser could not be configured.";
    dialog->SetTitle(L"Choose a guild emblem (32 x 32 PNG, up to 64 KiB)");
    const auto shown=dialog->Show(owner);
    if (shown==HRESULT_FROM_WIN32(ERROR_CANCELLED)) return "cancelled";
    ComPtr<IShellItem> item;
    if (FAILED(shown) || FAILED(dialog->GetResult(&item))) return "error:The selected file could not be opened.";
    PWSTR path=nullptr;
    if (FAILED(item->GetDisplayName(SIGDN_FILESYSPATH,&path))) return "error:The selected file could not be opened.";
    const HANDLE file=CreateFileW(path,GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    CoTaskMemFree(path);
    if (file==INVALID_HANDLE_VALUE) return "error:The selected file could not be read.";
    LARGE_INTEGER size{};
    const bool sizeOk=GetFileSizeEx(file,&size) && size.QuadPart>0 && size.QuadPart<=maxFileBytes;
    std::vector<unsigned char> input(sizeOk?static_cast<size_t>(size.QuadPart):0);
    DWORD read=0;
    const bool readOk=sizeOk && ReadFile(file,input.data(),static_cast<DWORD>(input.size()),&read,nullptr) && read==input.size();
    CloseHandle(file);
    if (!readOk) return "error:Choose a PNG file no larger than 64 KiB.";
    std::vector<unsigned char> clean;
    if (!sanitizePng(input,clean)) return "error:Use a static 32 x 32 PNG. Animated or damaged images are not supported.";
    ComPtr<IWICImagingFactory> factory;
    ComPtr<IWICStream> stream;
    ComPtr<IWICBitmapDecoder> decoder;
    ComPtr<IWICBitmapFrameDecode> frame;
    ComPtr<IWICFormatConverter> converter;
    GUID format{};UINT frames=0,width=0,height=0;
    if (FAILED(CoCreateInstance(CLSID_WICImagingFactory,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&factory))) ||
        FAILED(factory->CreateStream(&stream)) || FAILED(stream->InitializeFromMemory(clean.data(),static_cast<DWORD>(clean.size()))) ||
        FAILED(factory->CreateDecoderFromStream(stream.Get(),nullptr,WICDecodeMetadataCacheOnDemand,&decoder)) ||
        FAILED(decoder->GetContainerFormat(&format)) || !IsEqualGUID(format,GUID_ContainerFormatPng) ||
        FAILED(decoder->GetFrameCount(&frames)) || frames!=1 || FAILED(decoder->GetFrame(0,&frame)) ||
        FAILED(frame->GetSize(&width,&height)) || width!=32 || height!=32 ||
        FAILED(factory->CreateFormatConverter(&converter)) || FAILED(converter->Initialize(frame.Get(),GUID_WICPixelFormat32bppRGBA,
            WICBitmapDitherTypeNone,nullptr,0,WICBitmapPaletteTypeCustom))) return "error:The PNG could not be decoded.";
    std::string pixels(4096,'\0');
    if (FAILED(converter->CopyPixels(nullptr,128,4096,reinterpret_cast<BYTE*>(&pixels[0])))) return "error:The PNG could not be decoded.";
    for (size_t i=0;i<pixels.size();i+=4) if (!pixels[i+3]) pixels[i]=pixels[i+1]=pixels[i+2]=0;
    return "pixels:"+g_crypt.base64Encode(pixels);
}
#endif
}
bool GuildEmblemImport::available() {
#ifdef WIN32
    return true;
#else
    return false;
#endif
}
bool GuildEmblemImport::begin() {
#ifdef WIN32
    if (active) return false;
    auto job=std::make_shared<Job>();
    const HWND owner=GetActiveWindow();
    active=job;
    try {
        std::thread([job,owner]() {
            std::string result="error:The emblem could not be imported.";
            const auto com=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED|COINIT_DISABLE_OLE1DDE);
            if (SUCCEEDED(com)) {
                try { result=chooseAndDecode(owner); } catch (...) {}
                CoUninitialize();
            }
            std::lock_guard<std::mutex> lock(job->mutex);
            job->result=std::move(result);
        }).detach();
    } catch (...) { active.reset();return false; }
    return true;
#else
    return false;
#endif
}
std::string GuildEmblemImport::poll() {
    if (!active) return "cancelled";
    auto job=active;
    std::lock_guard<std::mutex> lock(job->mutex);
    if (job->result=="pending") return "pending";
    active.reset();
    return std::move(job->result);
}
