# Rune Sentinel – omarbetning på låst native kropp

V8 underkändes av användaren eftersom armar, ben, fötter och proportioner inte följde basoutfiten. I denna version genereras ingen kropp. Citizen 128 extraherades på nytt direkt ur aktuell DAT/SPR och används för varje riktning, idlefas 0. Kroppens maskregioner, form och ursprungliga skuggfält behålls. Se `../source/v9-native-body-reset/direct-native-source.json`.

`original-vs-repaint.png` visar original till vänster och den nya arbetsversionen till höger i varje par. Det är avsiktligt en direkt jämförelse mot den faktiska basen. Detaljnivå och exklusivitet behöver fortfarande arbetas vidare; denna fil är inte godkänd shopgrafik. Den tidigare stilen används som färg-/designtema, inte som ny anatomi.

Redigera `rune-sentinel-native-body.aseprite` eller `.ora`. Lagren innehåller faktisk native pose och mask som dolda referenser, en kropp med oförändrat källskuggfält, små material-/runedetaljer utan ny kroppsgeometri samt hjälmens krona förankrad i den verkliga huvudmasken. Kronan har nya pixlar ovanför kroppen; de får inte förväxlas med förflyttning av basens skalle, händer eller lemmar. Dessa redigeringslager är ännu inte den färdiga DAT-strukturen för bas/addon1/addon2.

Alla ändringar utfördes med PixelLab pixelart_workbench som bevakade pixelpatchar; ingen AI-modell ritade om kroppen. Patcharna finns i `../source/v10-native-costume/`. Kroppens färger beräknas från samma ursprungliga gråskalepixel och materialkanal, så att klädmaterial kan ändras utan att anatomiska skuggformer målas om. Guld/turkost används endast inom valda ytor i det ursprungliga röda klädmaskområdet. Ben och fötter har exakt samma ursprungliga per-pixel-färgtransform som kontrollbasen, utan extra fåll, cape, flyttade gränser eller lagning med grannfärger.

Verifierat: inga borttagna originalkroppspixlar, oförändrade fasta ansikts-/handpixlar, inga nya kroppspixlar från y36 och nedåt, identiska ben-/fotpixels med den exakta native färgtransformen och verifierat källskuggfält för hela kroppens röda maskregion. De tre hjälmfinnarnas rötter väljs bland de faktiska huvudmaskpixlarna för respektive riktning. ASE/ORA-lager har lästs tillbaka pixelidentiskt och deras alpha-composite ger exakt den presenterade bilden. Se `validation.json`.

Detta är en ny arbetsversion för bedömning mot basen. Fyrfärgsmasker för den nya grafiken, slutliga fristående addons, gångfaser, female-version och spelimport återstår. Inga runtime-/shopresurser ändrades.
