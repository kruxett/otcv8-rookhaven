# Rune Sentinel v20 – helt outfitutkast

PixelLab målade bas, bas + addon 1 samt bas + båda addons tillsammans i en och
samma generering, alla fyra riktningar och alla tre poser. Det är tre kompletta
bärlägen, inte färdiga fristående addonlager. AI varierar fortfarande vissa
grundkläder mellan stadierna och hjälmutsmyckningen behöver vidare granskning.
Grafiken är inte godkänd eller redo att importeras.

Referenserna innehåller kompletta originalark från DAT/SPR med bas, båda addons,
samtliga riktningar/gångbilder och färgmasker. Förberedda referenser: Warrior,
Demon Hunter, Wayfarer, Knight och Warmaster. Den sista genereringen använder
hela Knight och Warmaster inklusive deras färgmasker. Tidigare v19-rustning är
uttryckligen en ofärdig redigeringstarget för att behålla rustningskaraktären,
inte ett godkänt resultat.

AI-originalen är bevarade. Enda bearbetningen av outfitgrafiken efter AI är
automatisk Rec709-konvertering av kläder till neutralt grått i PixelLabs
workbench. Inga former eller detaljpixels har målats för hand. Originalets fasta
ansikten/händer är byte-identiska. AI har ändrat vissa klädkanter; full silhuett-
identitet hävdas därför inte. Numeriska kontroller ersätter inte visuell granskning.

PixelLab genererade även färglagret för hela arket gemensamt. Arbetsmasken
begränsas till grafikens opaka klädpixlar och närliggande AI-maskfärger snäpps
tekniskt till rent gult/rött/grönt/blått. Osäkra klassificeringar lämnas omaskerade
och redovisas i verification.json. Maskgränserna behöver visuell kontroll.

Öppna rune-sentinel-full-outfit.aseprite eller .ora. Bas och båda bärlägena har
egna redigerbara lager på olika rader; mask och originalreferenser är dolda.
Varje cell är 40×40 och visas utan omskalning i källarket. Rader 0–1 är bas,
2–3 bas + addon 1, 4–5 bas + båda. För varje par: N0 N1 N2 E0 E1 E2 på första
raden, S0 S1 S2 W0 W1 W2 på nästa. states/ innehåller motsvarande 12-bildsark
och native64-atlaser med samma +24,+24-placering utan omskalning.

Inga DAT/SPR-, server- eller shopfiler ändrades. Inget bygger på användargodkänd
grafik ännu. Fullt speltest och extraktion av oberoende addons återstår efter
designgranskning.
