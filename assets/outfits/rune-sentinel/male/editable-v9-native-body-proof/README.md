# Native kroppskontroll – ingen ny outfitdesign

V8 med fyra Rune Sentinel-vinklar är uttryckligen **underkänt av användaren**. Bevarade hudpixlar och återställd alpha räckte inte: genereringen ändrade kroppens interna former, gränser mellan kroppsdelar och deras upplevda proportioner. De gamla kontrollerna ska inte beskrivas som verifierad anatomisk trohet.

Det här arket är en återställning och kontroll av den faktiska basen: **Citizen, looktype 128, base addon 0, idle phase 0**, samtliga fyra riktningar. Nativebilderna extraherades på nytt direkt ur nuvarande klient-DAT/SPR; de är pixelidentiska med tidigare råextraktion. Sprite-ID:n och aktuella resurs-hashes finns i `../source/v9-native-body-reset/direct-native-source.json`.

`native-body-comparison.png` visar varje original till vänster och exakt samma sprite med ett fast färgbyte till höger. Färgbytet gjordes genom bevakade PixelLab-pixelpatchar med exakt samma multiply-formel som native fyrfärgsmasken. Inga kroppsdelar, konturer, ledpositioner, skuggformer eller alpha har ritats om. Det finns ingen genererad kropp eller efterhandslagning av den här basen. Händer, ansikten och andra omaskerade pixlar är oförändrade. Detta är avsiktligt endast ett färgbyte för att bevisa underlagets trohet; det är inte nästa betalda outfitförslag.

Öppna `rookhaven-native-body-proof.aseprite` eller `.ora` för originalkropp, originalmask och färgad kontrollbild på separata lager. Färdig Rune Sentinel-rustning, hjälm, addons och gångfaser behöver arbetas fram ovanpå bevarade native kroppsdelar. Denna kontrollfil ska inte importeras som en ny shop-outfit.

Verifiering: varje färgad pixel måste vara exakt `round(original * vald materialfärg / 255)` för samma ursprungliga maskkanal. Alla övriga pixlar måste vara identiska med originalet. Samtliga pixlar i samtliga fyra riktningar uppfyller detta. Detta bevarar källans interna skuggfält och kroppsdelars former, inte bara ytterkontur eller ett antal hudpixlar. ASE/ORA-lagren har lästs tillbaka pixelidentiskt. Resultat i `validation.json`.

De tidigare outfitförslagen är historik och underkända för implementation. Inga klient-/server- eller shopresurser ändrades i denna återställning.
