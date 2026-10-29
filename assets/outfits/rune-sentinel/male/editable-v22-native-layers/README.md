# Rune Sentinel v22 – grafikförslag

PixelLab Pro målade alla 36 bärlägen tillsammans: bas, bas + addon1 och bas + båda,
med Warrior/Knight-originalens samtliga vinklar, gångbilder, addons och färgmasker
i samma underlag. Pro-inpaint korrigerade sedan norrbildernas fram/bak-fel och
stövlarnas material med övriga pixlar låsta. Originalen finns orörda under source/.

Detta är inte frihandsritat. Den tekniska uppdelningen väljer AI-målade pixlar
med hjälm-/överkroppsmasker till två oberoende addonlager. Resten av basens kläder
återanvänds exakt, som i native-outfits. Automatisk gråkonvertering behåller varje
vald pixels Rec709-ljushet. Maskmetadata använder native kroppskanaler och AI:s
etiketter; maskgränserna och detaljerna i lageruppdelningen behöver granskning.
Detta är ett grafiskt förslag, inte en pixel-exakt kopia av native anatomi eller
en spelverifierad import. Inga nya klient/server-outfits eller shoprättigheter
har lagts till.

Öppna rune-sentinel-native-layers.aseprite eller .ora. De tre översta lagren är
bas, addon1 och addon2. Slå av/på addons för kombinationerna 0/1/2/3. Färgmaskerna
är dolda och redigerbara. Varje native-cell är 64×64; AI-grafikens 40×40-celler
placeras oförstorade vid +24,+24. Rader N/E/S/W, kolumner stå/gång A/gång B.

Verification.json redovisar lager-/färg-/SPR-kontrollerna. Male-grafiken kräver
användargodkännande innan import. Female återstår efter godkänd stil.
