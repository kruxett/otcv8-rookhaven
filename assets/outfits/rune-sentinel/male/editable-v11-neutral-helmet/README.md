# Rune Sentinel – vit/grå bas och gemensam hjälmkonstruktion

Användarens senaste feedback: grundgrafiken ska vara vit/neutral, proportionerna i v10 verkar rätt, men huvudspikarna följer inte med mellan vinklarna. V10:s individuellt ritade kronor är därför underkända. Den här versionen är en **neutral hjälmstudie**, inte en färdig betald outfit.

## Filer

- `neutral-helmet-four-directions.png`: syd, öst, nord och väst i samma neutrala bas, förstoring och 1×.
- `base-neutral.png`: neutral kropp utan den separata hjälmkonstruktionen.
- `helmet-neutral.png`: neutral hjälm/krona på separat lager.
- `base-color-mask.png` och `helmet-color-mask.png`: separata arbetsmasker för native fyrfärgssystemet.
- `neutral-composite.png` och `composite-color-mask.png`: kombinerad bild och mask för granskning.
- `rune-sentinel-neutral-helmet.aseprite` / `.ora`: redigerbar neutral bas, hjälm och masklager, med native referens dold/låst.

Alla recolorerbara baspixlar är gråskalepixlar med R=G=B. Hud och ursprungliga fasta färger ligger kvar som i Tibias native bas. Ingen spelarpalett, blå klädfärg, guldfärg eller cyanfärg är inbakad i visningsbilden. Maskerna använder native gul/röd/grön/blå för huvud/primär/ben/fot-detalj och transparent för fast grafik. De slutliga materialvalen för hela outfitten återstår.

## Samma konstruktion i fyra vinklar

Sydvyns tre spikar används för att kalibrera en enda krona: vänster- och högerspikar samt en högre mittspik på en böjd, upphöjd framplåt och en sluten hjälmring. Spikarnas fästen, relativa höjder, lutningar och tvärsnitt är samma i samtliga vinklar. Det är den gemensamma konstruktionen som vrids 0/-90/180/90 grader, inte fyra separat uppfunna spikbilder. Därför överlappar spikarna i profil; alla tre ska inte vara utspridda som i frontalvyn. Djupordning och skymning av skallformen ingår i konstruktionen.

Konstruktion: `../source/v11-neutral-helmet/crown-rig-v2.json`. Planerings-/ritverktyg: `../../tools/build_neutral_helmet.py`. Verktyget skriver konstruktionsdata och bevakade pixeländringar; själva bildändringarna utförs av PixelLab pixelart_workbench. Varje riktning utgår från den faktiska Citizen-kroppen och dess huvudmask. Inga nya kroppsposer genereras och befintliga sprites skalas inte om.

Referenserna granskades som matchande fyrvyserier: Knight 131, Warrior 134 och Warmaster 335 från Rookhavens DAT/SPR, samt de installerade Tibia-figurerna 1976, 632 och kron-/hjälmkandidater i 1210/1211, 1449/1450 och 1456/1457. Se `../source/v11-neutral-helmet/matched-helmet-references.png` och `crown-candidates.png`. Särskilt Knight-hjälmens sidovy visar hur utskotten överlappar i djupet. Onlinekataloger som också konsulterades: [Royal Costume](https://www.tibiawiki.com.br/wiki/Royal_Costume_Outfits), [Golden](https://www.tibiawiki.com.br/wiki/Golden_Outfits). Detta är referenser för konstruktion och perspektiv; ingen hel hjälm eller outfit kopierades som slutgrafik.

## Kontroller och kvarstående arbete

Originalets opaka kroppstäckning, fasta ansikts-/handpixlar och native kroppsplacering är bevarade. Alla recolorerbara pixlar är neutrala. Nya pixlar ligger endast i den definierade hjälmkonstruktionen. Native helvit palett ger exakt samma bild. ASE/ORA läses tillbaka med pixelidentiska lager. Se `validation.json`; tekniska kontroller ersätter inte användarens bedömning av hjälmens form och stil.

Rustningens exklusiva detaljering, slutlig uppdelning i bas/addon1/addon2, färgzoner för färdig outfit, gångfaser och female-motsvarighet återstår. Det här är ingen spelbild eller godkänd shopgrafik. Inga DAT/SPR-, shop- eller serverposter importerades.
