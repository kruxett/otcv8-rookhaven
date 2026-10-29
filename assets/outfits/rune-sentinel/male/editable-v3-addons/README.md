# Rune Sentinel – grundoutfit och två addons

**Status: flaggan är avvisad av användaren.** Den upplevdes inte sitta fast i figuren och designvalet gillades inte. V3 bevaras som historik; aktuellt ersättningsförslag finns i `../editable-v5-runeguard/`.

Användarens val: det första Rune Sentinel-provet är grundoutfit; Runecrown-varianten är grund med addon 1. Nytt förslag för addon 2: ett ryggmonterat blågrönt runstandar med guldkant, inspirerat av monteringen på den befintliga Warmaster-outfiten. Addon 2 inväntar grafikgodkännande.

Öppna `rune-sentinel-addons.aseprite` eller `rune-sentinel-addons.ora`. Grundoutfit, addon 1 och addon 2 ligger i separata redigerbara lager. Slå av/på addonlagren för de fyra kombinationerna. Citizen-posen finns som ett dolt referenslager.

| Native addonvärde | Bild | Lager |
| --- | --- | --- |
| 0 | `variant-0.png` | Grund |
| 1 | `variant-1.png` | Grund + krona/rustningsdekor |
| 2 | `variant-2.png` | Grund + runstandar |
| 3 | `variant-3.png` | Grund + båda addons |

`addon1-overlay.png` och `addon2-overlay.png` är själva tillvalslagren, inte hela ersättningsfigurer. De läggs ovanpå `base.png` i samma ordning som klientens `Outfit::draw` i `src/client/outfit.cpp`. Modellen använder patternY 0/1/2 och bitvärden 1/2. Addons kan därför väljas var för sig. Exempel från Brotherhood, Citizen, Knight, Warrior, Druid, Assassin och Warmaster extraherades direkt ur nuvarande lokala DAT/SPR, både syd- och nordvy; se `../source/v3-addons/references/`.

Den tidigare AI-bilden för Runecrown hade 18 transparenta pixlar där grundoutfiten var opak. Eftersom native addonlager inte raderar underliggande pixlar behåller den kombinerade bilden grundpixlarna på dessa platser. Grundoutfiten är oförändrad. Addon 2 är enbart nya pixlar utanför den befintliga figuren och överlappar inte addon 1. Alla fyra kombinationer har rekonstruerats och kontrollerats; ansikte, händer och nedre pose är bevarade. ASE/ORA-lagren har lästs tillbaka pixelidentiskt. Resultat i `validation.json`.

Detta projekt innehåller **färgsatta stilprov för sydvy, stillastående** på native 64 × 64-canvas. Övriga riktningar/gångsteg, neutral bas och fyrfärgsmasker för alla tre lagren, separat female-version och spelimport återstår. Förstoringen i `addon-combinations-preview.png` använder nearest neighbour. Befintliga DAT/SPR, serverrättigheter och shopposter har inte ändrats i denna iteration.
