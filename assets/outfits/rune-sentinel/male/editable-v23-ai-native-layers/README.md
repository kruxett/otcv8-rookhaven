# Rune Sentinel – nya native-lager målade av PixelLab

Grafiskt förslag. Inget är importerat eller användargodkänt.

Den AI-målade basen finns en gång per originalpose. PixelLab målade båda addons
för alla tolv poser gemensamt över synliga basfigurer och exporterade direkt
"New layer with changes". Utrustningen kommer alltså från riktiga transparenta
AI-lager, inte efterhandsklippning av sammanslagna figurer.

Förberedda anatomiska målningsområden låser ansikte/händer/kroppskonturer,
huvudets bakåtriktning och axlarnas placering. Addon2 kan inte rita om huvud,
addon1 eller ben. Hjälmfjädrarnas riktning är styrd genom målningsområden och
ett bilddiagram, inte en efterhandsflytt av pixlar. Originalets gångposer och
fotankare återanvänds. Alla fyra addon-kombinationer kompositeras på samma bas.

Färger och skuggor är oförändrade från PixelLabs slutliga lagerutdata.
Ingen neutralgråkonvertering, egen pixelmålning eller gissad delmask har
applicerats på grafiken efter generering. Endast kända hela bildrutor packas
om utan omskalning. De orörda exporterade PNG-filerna finns i denna mapp.

ASE/ORA innehåller tre synliga redigerbara native64-lager (bas, addon1,
addon2), dolda arbetsmasker och originalets anatomireferens. Varje ruta är
64×64; AI:s 40×40-rutor placeras vid +24,+24 utan omskalning. Rader N/E/S/W,
kolumner stå/gång A/gång B. Slå av/på addonlagren för kombinationerna 0/1/2/3.

Arbetsmaskernas gränser och runstenens färgkanal behöver visuell granskning
före import; de är inte en färdig godkänd färgsättning. Native gameplay,
female-variant och shopregistrering återstår efter godkänd grafisk design.

verification.json redovisar faktiska kontroller och samtliga genereringsjobb.
43 genereringar användes i denna användartur, inklusive tre tidigare försök
före den slutliga separata lagergenereringen.
