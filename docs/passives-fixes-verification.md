# Rättningar efter slutgranskningen — 6 oktober 2026

Detta dokument följer upp de **sju punkter användaren bad oss rätta** efter
[slutgranskningen](passives-final-audit.md). Arbetet är lokalt i de separata
klient- och serverprojekten. Retro-layout, befintliga 32px-ikoner, den godkända
fyrpoängsgränsen för core majors och spelets försiktiga progression är bevarade.
Ingen produktionsserver eller DB33307 används av proverna.

**Arbetsstatus:** De sju tekniska rättningarna är klara lokalt. Riktade prov,
alla 18 naturliga capstones, startspells, partyprov och samtliga fem
regressionsgates passerar på slutbygget. Jaktbalans och samtidig
produktionsbelastning är fortfarande omätta; se avgränsningen längre ned.

## De sju rättningarna

| Punkt | Vad som har ändrats | Faktisk verifiering och aktuell status |
| --- | --- | --- |
| 1. UI/UX: dolt klassfel, missvisande Ready, klippta namn | Klassbekräftelsen har ett eget främre statusfält för väntan, fel, reconnect och timeout. Timeout flyttar fokus till Close. Spellkort säger **Cooldown ready**, visar utrustningskrav och kända hinder; vänster och höger vapenhand stöds. Nya tomma träd öppnas längst ned vid 800×600, explicit nodval visar hela ramen och namnet, vanlig scroll bevaras. | **PASS:** `passives-fixes-feedback.log` på slutklienten inkluderar vänsterhand, timeout/sena svar, samtliga sex träd vid verkliga 800×600 och katalogreplay. `passives-fixes-geometry.log` verifierar sex träd vid 1280×800/800×640. Fel- och timeoutbilderna har också granskats visuellt. |
| 2. Volley: motstridiga vapenkrav | XML kräver inte längre det native melee-vapen som stred mot scriptets launcherkrav. Scriptet söker bow/crossbow i båda händerna och kräver kompatibel ammunition. Befintliga 40 mana, 2 sekunders cooldown och högst fem skott är kvar. | **PASS:** `passives-fixes-volley.log` verifierar alla åtta fall: vänster/höger hand, två tillgängliga skott, inget vapen, ingen ammunition, fel ammunition, låg mana och alla mål bakom skjutriktningen. Lyckade casts betalar exakt 40 mana och rätt antal ammo; avvisade casts och cooldown-recast betalar inget. Cooldown är 2000 ms. Jaktbalans och samtidig belastning är separat omätta. |
| 3. Capstones: klassfrämmande förkrav vid 16 poäng | Native validator och katalog har klassvisa grupper av tre majors. Blade Storm kräver uttryckligen Measured Blade rank2 och kopplas till crit/offensiv väg. Klienten ritar katalogens verkliga kopplingar med separata spår. Stabil nodidentitet bevaras; gamla lagliga byggen som blivit ogiltiga får en kostnadsfri poängåterställning utan klassbyte. | **PASS för regler/migration:** `passives-fixes-routes.log` har 72 godkända och 55 avvisade allokeringar, inklusive alla 18 capstones med exakt16 spenderade poäng och 54 kombinationer av två relevanta majors. Saknad Blade Storm-anchor avvisas. `passives-fixes-refund.log` verifierar refund, bibehållen ny giltig fördelning, idempotent relog, avvisad korrupt ledger, oförändrade pengar och spells. `passives-fixes-capstones.log` avslutar dessutom alla 18 naturliga procs, varje gång med exakt 16 poäng vid level 40 samt Stop/logout efteråt. |
| 4. Aegis och Stonebond konkurrerar om samma skydd | Combat wards och Aegis har separata pooler; starkast behålls inom samma pool. Båda får bidra inom en gemensam mottagargräns, standard10% max HP. HUD visar summan. Borttagning av en källa lämnar den andra källans giltiga skydd kvar. | **PASS:** `passives-fixes-ward-party.log` avslutas med `PASSIVES_WARD_PARTY_RUNNER_OK`. Runnern kräver både huvudklientens riktiga shield-block/party/absorption-prov och den andra klientens verkliga healing/cast/cleanup. Det gäller två riktiga klienter i samma lokala party. `passives-fixes-synergies.log` verifierar dessutom Renewal, Aegis och Concord med två riktiga ordinary partyklienter. |
| 5. Avvisad Apply raderar utkast | Klienten sparar begärans action/session/revision och serverbas. Ett misslyckat Apply behåller en giltig aktuell draft när sparade ranks och revision är oförändrade. Timeout begär återhämtning; sena svar återinför aldrig en gammal kopia. Nyare serverrevision eller session tar över. | **PASS:** `passives-fixes-draft.log` visar riktig UI Apply under native combat: två draftpoäng förblir två, sparade0/revision1 oförändrade, därefter sparar retry exakt samma ranks. Native feedbackprovet täcker timeout, äldre/nyare svar, minskad budget och pensionerad session. |
| 6. Bloodletting tappar sista skadeticken | Ändliga specialsår fördelar tidsrester över kumulativa deadlines i motorticks. Kvarvarande schemalagd budget avslutas vid faktisk expiry om såret inte redan avbrutits. Vanlig äldre bleeding använder fortsatt sitt ordinarie schema. | **PASS för huvudfelet:** `passives-fixes-bleed.log` verifierar 36 fall med budget1–12 vid 18s/12,5s/17s, starkare ersättning med budget15 och naturlig trigger. `passives-fixes-finite-field.log` och dess `field.log` verifierar verkliga fields: specialsår levererar exakt budget2 och försvinner, vanlig bleeding ger4 och finns kvar. Rend-generatorfallet passerar också. Den slutliga huvudmatrisen har körts på slutbinären och avslutas med `PASSIVES_BLEED_FIX_OK`. |
| 7. Immuna mål får räknade men oskadliga sår/Rendvillkor | Specialsår avvisas för bleed-immunitet, fysisk immunitet och suppress innan de räknas. Stackstatus och Rends bonusvillkor använder giltiga egna specialsår. | **PASS för grant/stack och riktiga Rend-casts:** huvudprovet ger `ownStacks=0` och `rendOwnWoundGate=false` på bleed-immun men fysiskt sårbar testdummy. `passives-fixes-rend.log` verifierar fyra verkliga casts: normalt mål, bleed-immunt mål, giltigt eget sår och avslutat generatorsår. Faktisk skada matchar observerad originalroll och rätt faktor; endast giltigt eget sår får bonus. Slutlig huvudmatris, starkare replacement och cure passerar på samma slutbinär. |

Detaljer om klientens auktoritetsregler, scroll och modalstatus finns i
[passives-client-fixes.md](passives-client-fixes.md). Den extra kritiska
kodgranskningen hittade inga nya blocker i dessa delar. En efterföljande konkret
vänsterhandskontroll rättade det först för snäva utrustningshintet och lades in
som ett explicit native controllerprov.

## Påverkade befintliga system och riktade beroenden

Att ny UI eller ett nytt sår fungerar ersätter inte regressioner av befintliga
spells, conditions, lärlista eller persistens. Följande kontroller är därför
separata från tabellen ovan:

| Beroende | Orsak och bevarat kontrakt | Verifiering vid denna dokumentsnapshot |
| --- | --- | --- |
| ConditionDamage-generator | `alignFiniteDamageSchedule()` behöver initiera ett finit genererat schema innan det räknas om. Endast kvalificerade Bloodletting-sår använder omräkningen; ordinary strongest-condition-regeln ska vara kvar. | **PASS:** en riktig generator levererar sin budget på 1 skada. Fixturen förlänger uttryckligen dess expiry till 30000 ms så att en tom skadelista kan observeras före expiry. Med 27000 ms kvar räknas inget aktivt eget sår; ett verkligt Rend-cast får faktor 1,035 och faktisk/förväntad skada 63. Slutlig omkörning av hela bleedmatrisen passerar på samma binär. |
| Physical damage field | En vanlig condition får historiskt hållas kvar av ett field. Ett player-owned Bloodletting-sår ska ändå ta slut efter sin begränsade budget; det får inte fortsätta repetera medan målet står kvar. | **PASS:** `passives-fixes-finite-field.log` har `PASSIVES_FINITE_FIELD_SUITE_OK`; `out/passives-finite-field-tests/field.log` har `specialDamage=2`, `ownStacks=0`, `legacyDamage=4` och `legacyStacks=1`. Runnern återställer runtimefilen byte för byte; source/runtime/original har samma verifierade SHA256 nedan. |
| Aktiv permanent klass och spellinlärning | Trusted starter grants måste synka den faktiska lärlistan även när klassprofilen redan är aktiv. Synkningen är case-insensitive och idempotent. Vald klass och äldre lärda spells ska bestå genom save/relogin; vanliga lärar-/spellkrav ska inte kringgås för andra grants. | **PASS:** `passives-fixes-starters.log` avslutar hela sexklass-sviten. Klassloggarna i `out/class-spells-tests/` verifierar NPC-grant, lärlista efter relog, verkliga casts av båda startspells, wrongclass/wrongweapon/nomana/unlearned och återställning av äldre lärda spells. |
| Riktig Rend | Egen aktiv Bloodletting ger bonus; immunitet och avslutat generatorsår gör det inte. Ägarseparation, cure och avvisade casts ingår även i den slutliga bleed-/spellmatrisen. | **PASS för fyra riktiga casts:** `CLASS_SPELLS_REND_BLEED_OK` i `passives-fixes-rend.log`, se tabellen nedan. RNG-observern anropar den ursprungliga rollen; den ersätter inte skadan med ett förutbestämt värde. Det slutliga bleedprovet och de sex klassernas spell-/avvisningsprover passerar också. Annans sår som specifik Rend-cast är inte ett separat livefall i fyrfallsprovet; ägarvillkoret är granskat i nativekod. |
| Befintlig partyhealing och skada som healtrigger | Nya startercasts ska utlösa Renewal/Aegis/Concord en gång på rätt mottagare; ordinary peers ska inte behöva en admin-overlay. | **PASS:** `passives-fixes-synergies.log` avslutar Renewal, Aegis och Concord med två riktiga ordinary partyklienter. Detaljloggarna visar Renewal direkt 33 + HoT 6, Aegis direkt 30 och Concord efter Essence Lash skada 33/healing 13. |
| Native spellbetalning, delad cooldown, ammo och wieldkrav | Volley-fixen och ClassSpells-feedback får inte ändra korrekt betalning, ammunition eller auktoritativ shared exhaustion. Vänsterhand är en tillåten vapenplacering. | **PASS:** alla åtta Volleyfall, klientens readiness/timer/feedback samt hela sexklass-sviten med riktiga wield-, mana-, ammo- och exhaustion-kontroller. |
| Befintlig HP-condition, reconnect, vendor/TCP och featureflagga | Ward- och passivändringar måste lämna tidigare regressionsgates intakta och rensa endast den källa/session de tillhör. Baseline med flagga på utan overlay och med flagga av behöver jämföras. | **PASS:** slutlig ny körning av samtliga fem gates i `out/passives-fixes-regressions.log`: normal module guard, lifecycle, baseline enabled, baseline disabled och six-tree contract. Befintlig HP-condition, save/relogin, vendor soft logout, TCP detach, död, legacy bleeding/poison/cure, AoE crit, mana shield och äldre spellbetalning kontrolleras. |
| Alla18 naturliga capstones | Allokering med16 poäng verifierar att vägen är laglig, men inte att varje proc eller encounter är balanserad. | **PASS:** `PASSIVES_CAPSTONE_SMOKE_SUITE_OK cases=18 elapsed=490.9`. Varje fall kräver level 40, exakt 16 spenderade poäng, en naturlig proc och korrekt Stop/logout. Funktionell aktivering ersätter inte jaktbalans. |

### Rend: observerad originalroll och faktisk skada

Alla fyra fall använder den riktiga serverns spellcast och native combat.
Observern registrerar originalrollens resultat och HP omedelbart kring casten,
så efterföljande autoattacker inte räknas in i spellens skada.

| Fall | Originalroll | Giltiga egna sår före cast | Faktor | Faktisk / förväntad skada |
| --- | ---: | ---: | ---: | ---: |
| Normalt mål | 92 | 0 | 1,035 | 95 / 95 |
| Bleed-immunt men fysiskt sårbart mål | 76 | 0 | 1,035 | 79 / 79 |
| Giltigt eget Bloodletting-sår | 96 | 1 | 1,242 | 119 / 119 |
| Avslutat generatorsår | 61 | 0 | 1,035 | 63 / 63 |

Logg: `out/passives-fixes-rend.log`, med en
`CLASS_SPELLS_REND_BLEED_CASE_OK` per fall och slutmarkören
`CLASS_SPELLS_REND_BLEED_OK`.

### Återställd physical-field-fixtur

Runtimefilens tillfälliga itemdefinitioner återställdes exakt efter fälttestet.
Följande tre filer har samma SHA256, kontrollerad efter runnerns återställning:

- Serverns sourcefil: `../Rookhaven/data/items/items.xml`.
- Lokal runtimefil: `out/local-server/passives-runtime/data/items/items.xml`.
- Sparat original: `out/passives-finite-field-tests/items.original.xml`.

```text
890b19008edb53b92774611d151c88b45abd5d8d94ff8758328a6735b48d1dee
```

Detta bevisar återställning av itemfilen; det ersätter inte övriga cleanup-,
baseline- eller artefaktgates i slutomgången.

## Serverns huvudfil config.lua — ingen manuell ändring

**INGA NYA RADER SKA LÄGGAS TILL I SERVERNS HUVUDFIL `config.lua` FÖR DETTA
INKREMENT.** Den privata filen som styr serverkonfigurationen lämnas separat.
Användaren behöver alltså inte kopiera någon ny inställning till den nu.

Detta gäller de aktuella lokala rättningarna. Det är inte en instruktion att
aktivera de lokalt begränsade passiv-/klassystemen på DEV eller PROD.

## Versionerad balansfil som ska följa med en framtida leverans

Serverns **hela uppdaterade `data/lib/passives/config.lua` måste följa med** när
den här serverkoden senare levereras. Den ligger i speldata och är inte serverns
privata huvudfil. Dess Git-undantag är redan infört, liksom undantaget för
`data/lib/class_spells/config.lua`.

Den nya gemensamma wardinställningen finns i `common`:

```lua
wardCombinedCapPercent = 10,
```

Den styr den sammanlagda mottagargränsen för combat ward och Aegis. Samma sorts
ward staplas inte; starkast inom respektive pool behålls. Ett lägre aktivt
källspecifikt override begränsar den gemensamma gränsen. Tillåtet övre värde är25%.

Balansfilen innehåller också den gemensamma begränsningen av spellrabatter:

```lua
manaDiscountCapPercent = 50,
```

Rabatter får aldrig göra en spell med en ursprungligen positiv manakostnad helt
gratis. Installera den matchande hela balansfilen tillsammans med nativekod och
katalog, och starta om servern. Dessa konfigurationskällor har ingen hot reload.
Lägg inte balansraderna i huvudfilen som en ersättning för rätt speldatafil.

## Naturliga capstones och lokal uthållighet

Alla 18 fall kördes på samma server under 490,9 sekunder. Totalt användes
11,44 CPU-sekunder under fallen. Private memory efter fallen gick från
450,43 till 456,46 MiB; de sista fem samplen låg mellan 456,45 och 456,46 MiB.
Detta är ett uppmätt förlopp, inte ett bevis på produktionskapacitet eller på
frånvaro av alla möjliga minnesläckor.

| Klass | Naturligt aktiverade capstones |
| --- | --- |
| Reaver | Berserker, Bloodletting, Bloodguard |
| Blademaster | Duelist, Riposte, Blade Storm |
| Earthshaker | Aftershock, Stoneguard, Stonebond |
| Marksman | Deadeye, Skirmisher, Quarry |
| Arcanist | Conduit, Resonance, Spellweaver |
| Lifekeeper | Renewal, Aegis, Concord |

Proben använder ordinary autoattacker, shield-blocks, rörelse, casts och faktisk
healing. QA-kommandon för utrustning, fixturplacering, HP-deficit och refill
sätter upp fallen; de tvingar inte proccharges. Adminbudget är fortsatt 24,
men varje naturligt capstonebygge assertas till exakt 16 spenderade poäng.

## Avgränsad belastningsgranskning

Den kritiska kodgranskningen hittade ingen oändlig proc-loop eller permanent
läcka i de granskade vägarna. Nativekod begränsar samtidiga actions till 128,
träffmål till 64 per action, uppskjutna referenser till 65 per action och egna
schemalagda effekter till 512 globalt. Procskada, leech och conditions kan inte
starta samma proc-kedja rekursivt.

Serialkampanjen samlar serverns CPU-tid och private/working-set-minne efter varje
capstonefall i `out/passives-capstone-smoke-tests/server-samples.json`. Det är en
lokal uthållighetskontroll. CPU-tiden inkluderar världstasks och trace-loggning;
minnessamplingen mäter inte peak eller enbart passivsystemets allokeringar.

Följande konkreta skalningsvägar är fortfarande omätta under samtidig last:

- Sökning/sortering av monsterkandidater beror på antalet monster i radien.
- Partyrecipienter och globala actions/wards/HoTs/marks kräver state-svep.
- `bleedTargets` har en städtröskel på 64, inte en hård gräns för aktiva mål.
- Lua-spellpulser använder vanliga `addEvent`-timers utanför nativeköns 512-gräns.
  Stop gör deras gameplay ogiltigt; timers avslutas vid sina ordinarie deadlines.

En framtida samtidig belastningsgate behöver mäta monsterdensitet, stora partyn,
många spelare på samma mål, båda timerköerna och P95/P99 för serverns ticklatens.
Detta är inte ett påstående att produktionen klarar ett visst spelarantal.

## Artefaktkontroll

Det slutliga klientarkivet har 117 exakta källmatchningar efter dekryptering och
LuaJIT-kompilering. Det innehåller inga injicerade test/probe-startfiler.
Paketets checksum-manifest matchar den lokala serverns manifest byte för byte.
Bevis: `out/final-audit/artifact.json`.

| Artefakt | SHA256 |
| --- | --- |
| Klientens `data.zip` | `2157e35dd048bd6b7177626ec5b91a4d182e12606b1309dcb8995a8fbb00a592` |
| Checksum-manifest | `3f291a1e80a20ed49bd1ace99ba5fd501d02bcae4f8dbdb0487eddee3f5490df` |
| Lokal `tfs.exe` | `246b594d7d369cf45647c039286fb74149438a8412893a77711217777fbe1f82` |

## Testanpassningar och kvarstående gränser

Nya 16-poängspresets innehåller andra HP-ranks än tidigare 24-poängsfixturer.
Lifecycleprovet använder därför ett separat servervaliderat 21-poängsbygge med
fem Vitality-ranks. Alla gamla exakta 771/918/882/735-HP-, save-, detach- och
death-kontroller behålls. Det används inte i den naturliga level 40-kampanjen.
Rendprovet väntar befintlig login-/teleportpacification; fieldprovet rensar
attacktarget så att vanlig autoattack inte räknas som bleedskada. Inga av dessa
anpassningar stänger av ordinarie combat-gates eller förutbestämmer procskada.

Katalogens kopplingar och läsbara förkrav jämfördes separat med de verkliga
AND/OR-reglerna: **28 992 jämförelser**, sex träd och 126 kopplingar.
`out/passives-fixes-catalog.log` avslutas med `PASSIVES_CATALOG_METADATA_OK`.

- Controllerprovet använder riktiga native widgets/controllers med en scriptad
  transport och offline map. Det bevisar inte nätverkscommit, faktisk healing
  eller jakt; separata liveprover ovan täcker sådana handlingar.
- De verifierade16-poängsbyggena används i admin-overlay med total tillgänglig
  budget24 men spenderar exakt16. Permanent progression/budget följs separat i
  vanliga spelarprover. En godkänd allokering är inte ett automatiskt proc-bevis.
- Det riktiga partyprovet verifierar samverkan och absorption. Alla resistans-,
  PvP-, utrustnings- och serverbelastningskombinationer täcks inte av det.
- Faktisk human jaktbalans, onboarding1–7, ekonomin och produktionspeak förblir
  speltest-/profileringsarbete. Riktade tekniska rättningar är inte ett generellt
  balansgodkännande.
- Inget commit/push/deploy är gjort inom detta inkrement. Den ägda lokala
  servern är återställd till källans standarder och kör fortfarande på loopback.

## Bilder och manuell lokal testning

- [Retroträdet vid 800×640](../out/passives-fixes-screens/blademaster-retro-800x640.png).
- [Naturligt aktiverad Blade Storm med 16 poäng](../out/passives-fixes-screens/blade-storm-16-points.png).
- [Två utkastpoäng kvar efter avvisad Apply](../out/passives-fixes-screens/draft-preserved.png).
- [Klassbekräftelsens främre felstatus](../out/passives-fixes-screens/class-choice-error.png).

Starta `out/install/x64-LocalPassives/Start Local Passives.cmd`. Konto/lösenord:
`passivetest` / `passivetest`, karaktär **Passive Tester**. Servern använder
127.0.0.1:7174/7175 och DB33308. Exempel för ett tillfälligt adminträd:

```text
/passivetest start blademaster
/passivetest preset Passive Tester,bladestorm
/passivetest stop
```

GUI:t kan ändra testbygget inom adminbudget 24; det medföljande presetet
spenderar exakt 16. Inga riktiga klasser ändras av dessa overlaykommandon.
