#ifndef GUILDEMBLEMIMPORT_H
#define GUILDEMBLEMIMPORT_H
#include <string>
namespace GuildEmblemImport {
bool available();
bool begin();
// pending / cancelled / error:<message> / pixels:<canonical base64 RGBA>
std::string poll();
}
#endif
