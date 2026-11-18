"""Export actual native map frames into house crops and aspect-preserving previews.

No tile/sprite reconstruction or generated art. The capture must be a completed
owned loopback run, with each house's native tile bounds and acknowledged camera.
"""
from pathlib import Path
import argparse,hashlib,json,math,shutil,xml.etree.ElementTree as ET
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('capture',type=Path);p.add_argument('--install',action='store_true');args=p.parse_args()
run=args.capture.resolve();receipt=json.loads((run/'result.json').read_text())
assert receipt['status']=='PASS' and receipt['profile_restored'] and receipt['owned_processes_stopped']
catalogue=json.loads((run/'runtime/house-photo-catalogue.json').read_text())
frames={}
for line in (run/'client/Rookhaven-LocalPassives-Probe.log').read_text().splitlines():
    if line.startswith('HOUSE_PHOTO_FRAME '):
        f=json.loads(line[len('HOUSE_PHOTO_FRAME '):]);key=(f['id'],f['z']);assert key not in frames;frames[key]=f
houses_xml=run/'runtime/data/world/Untitled-1-house.xml'
expected={int(h.attrib['houseid']):h.attrib['name'] for h in ET.parse(houses_xml).getroot()}
assert {h['id']:h['name']for h in catalogue}==expected,'native map/catalogue identity mismatch'
assert len(frames)==sum(len(h['floors'])for h in catalogue),'incomplete captures'
assert all(len(h['floors'])==1 for h in catalogue),'choose/verify a main floor before exporting multi-floor houses'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
prepared=run/'prepared-photos';prepared.mkdir(exist_ok=False);(prepared/'previews').mkdir()
manifest={'format':1,'source':'Native OTCv8 map framebuffer; base map, no player decoration',
          'map':'rookalmost.otbm','mapSha256':sha(run/'runtime/data/world/rookalmost.otbm'),
          'housesXmlSha256':sha(houses_xml),'clientDataZipSha256':sha(run/'client/data.zip'),
          'serverSha256':receipt['server_sha256'],'clientSha256':receipt['client_sha256'],
          'previewSize':[186,210],'houses':[]}
for house in catalogue:
    floor=house['floors'][0];frame=frames[(house['id'],floor['z'])];cam=frame['position']
    assert frame['dimension']=={'width':15,'height':11} and cam['z']==floor['z']
    source=run/frame['file'].lstrip('/');image=Image.open(source).convert('RGB');assert image.size==(576,448)
    # Native MapView::transformPositionTo2D: visible 15x11 -> 18x14 tile
    # framebuffer with camera at tile (8,6). Keep one context tile per side.
    bounds=(floor['minx']-1,floor['miny']-1,floor['maxx']+2,floor['maxy']+2)
    cropbox=((8+bounds[0]-cam['x'])*32,(6+bounds[1]-cam['y'])*32,
             (8+bounds[2]-cam['x'])*32,(6+bounds[3]-cam['y'])*32)
    assert 0<=cropbox[0]<cropbox[2]<=image.width and 0<=cropbox[1]<cropbox[3]<=image.height,('incomplete context',house['id'],cropbox)
    crop=image.crop(cropbox);assert len(crop.getcolors(crop.width*crop.height))>64,('empty native frame',house['id'])
    target=prepared/(str(house['id'])+'.png');crop.save(target,optimize=True)
    thumb=crop.copy();thumb.thumbnail((186,210),Image.Resampling.NEAREST)
    preview=Image.new('RGB',(186,210),(0,0,0));preview.paste(thumb,((186-thumb.width)//2,(210-thumb.height)//2))
    thumb_target=prepared/'previews'/target.name;preview.save(thumb_target,optimize=True)
    manifest['houses'].append({'id':house['id'],'name':house['name'],'floor':floor['z'],
       'entry':house['entry'],'tileCount':len(floor['tiles']),'tileBounds':{k:v for k,v in floor.items()if k!='tiles'},
       'cropWorldBounds':list(bounds),'camera':cam,'frameSha256':sha(source),
       'image':target.name,'size':list(crop.size),'sha256':sha(target),
       'preview':'previews/'+target.name,'previewSha256':sha(thumb_target)})
(prepared/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Review sheets are kept with evidence, not packaged as client assets.
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
for page in range(math.ceil(len(catalogue)/20)):
    group=catalogue[page*20:(page+1)*20];sheet=Image.new('RGB',(808,5*252),(27,27,27));draw=ImageDraw.Draw(sheet)
    for i,house in enumerate(group):
        x=(i%4)*202+8;y=(i//4)*252+6
        sheet.paste(Image.open(prepared/'previews'/(str(house['id'])+'.png')),(x,y))
        draw.text((x,y+212),str(house['id'])+' · '+house['name'],font=font,fill=(225,225,225))
        draw.text((x,y+228),'Floor '+str(house['floors'][0]['z']),font=font,fill=(165,165,165))
    sheet.save(run/('houses-review-'+str(page+1)+'.png'))
if args.install:
    destination=ROOT/'modules/game_cyclopedia/images/houses/rookhaven';destination.mkdir(parents=True,exist_ok=True)
    shutil.copytree(prepared,destination,dirs_exist_ok=True)
    assert all(sha(destination/h['image'])==h['sha256'] and sha(destination/h['preview'])==h['previewSha256'] for h in manifest['houses'])
print(json.dumps({'status':'PASS','houses':len(catalogue),'floors':len(frames),'nativeCrops':len(catalogue),'previewSize':[186,210],'installed':args.install,'prepared':str(prepared)}))
