# Slutgranskning av passiver och klassystem

**Historisk granskning före rättningarna.** Aktuell status, rättningar och faktiskt
körda tester finns i [rättnings- och verifieringsrapporten](passives-fixes-verification.md).
Fynd, reproduktioner och förslag nedan bevaras som underlag från den ursprungliga
granskningen. De beskriver inte vilka fel som fortfarande finns efter rättningarna.

Granskat den 6 oktober 2026 av huvudagenten och tre underagenter: UI/UX,
system/kod och en särskild kritiker. Omfattningen är de sex passiva träden,
permanent klassval vid tredje Ascension, två startspells per klass samt deras
klient-, strids-, konfigurations- och persistensberoenden.

Vid granskningen fungerade grunden i den lokala testmiljön, men tre reproducerade
fel och flera design- och leveransluckor återstod. Git-undantagen för de två balansfilerna har
rättats enligt användarens efterföljande instruktion. Godkända funktionstester innebär därför inte
att hela systemet är klart för utrullning eller att balansen är godkänd.
Retro-layout, fyrpoängsförkraven och lokal testning är fortsatt gällande.
Under denna ursprungliga granskning ändrades ingen spelkod eller balansering,
och inget commitades eller pushades. Utöver dokumentation och auditfixturer
ändrades då endast serverns `.gitignore`. Senare kodrättningar och deras resultat
redovisas i verifieringsrapporten ovan.

## Implementation vid den ursprungliga granskningen

| Del | Vad som fanns | Vad som återstod vid granskningen |
| --- | --- | --- |
| Sex träd | 17 noder per träd, 21 kopplingar, minor/major/capstone, servervaliderade förkrav, utkast och Apply | Avvisad Apply tappar utkast; klassvisa capstonevägar behöver granskas vid 16 poäng |
| Permanent klass | Separat klassidentitet med bibehållen vocation 3, NPC och retro klassväljare | Vanlig Look visar endast Ascended; vissa fel- och läslägen i klassväljaren behöver förbättras |
| Progression och respec | Centrala poängmilstenar och bankavgifter, klasslåst respec, sparad ledger | Normal jakt och ekonomisk verifiering; Ascensionens tidigare inventoryflytt saknar rollback |
| Startspells | Två faktiskt lärda spells per klass, befintliga effekter, serverägda kostnader och exhaustion | Nivå 1–7 och användningsvärdet mot faktiskt tillgängliga äldre spells |
| Senare spellinlärning | Befintligt learned-spell-system kan spara namn | Ny klasskatalog/grants/UI är fortfarande låsta till exakt två per klass; lärar-/quest-/prövningsgrund saknas |
| Konfiguration | Passivvärden, poäng/respec och startspellvärden har centrala källor; två exakta Git-undantag är nu införda | Strukturella gates finns fortfarande i både nativekod och katalog; ren checkout/leverans återstår |
| Lokal isolering | Egen klientprofil, loopbackserver, DB33308, normalprofil- och avstängningsgates | DEV/PROD-integration, updater, migrationsövning och belastningsgranskning |

Relaterade kontrakt finns i [UI-granskningen](passives-ui-review.md),
[permanent progression](passives-permanent.md), [startspells](class-starter-spells.md)
och [balansauditen](class-spell-balance-audit.md). Äldre rapportavsnitt beskriver
tidigare inkrement, inte alltid dagens värden. Numeriska värden hämtas från
serverns `data/lib/passives/config.lua` och `data/lib/class_spells/config.lua`.

## Prioriterade fel

### Avvisad Apply raderar ett giltigt utkast

**Hög prioritet, reproducerat i den riktiga klienten.** Två poäng lades till med
Add rank och Apply klickades under riktig strid. Servern avvisade begäran med
"Leave combat before changing your test build." Revisionen stannade på 1 och
sparade poäng på 0, men klientens utkast gick från **2 till 0**.

[acceptSnapshot](../modules/game_passives/passives.lua#L1150) bevarar bara ett
utkast när ingen begäran är pending. Serverns felresultat har en oförändrad
snapshot, som ändå ersätter utkastet innan pending rensas.

**Förslag:** Vid misslyckad Apply, behåll det inskickade utkastet när session,
revision och sparade ranks är oförändrade. Auktoritativt ändrad session/revision
eller sparade ranks ska fortfarande synkroniseras. Hantera timeout separat.

**Acceptans:** Riktig Apply under strid och ett persistensfel behåller utkastet;
retry efter strid sparar exakt samma ranks. Ny session eller ändrad revision
får inte återinföra ett föråldrat bygge.

Bevis: `out/final-audit/draft-reject.log`,
`PASSIVES_DRAFT_REJECT_EVIDENCE`, bilden `passives-draft-server-rejected.png`.
Auditproben stöder redan ett separat verify-läge efter en framtida fix.

### Små Bloodletting-sår tappar sista skadeticken

**Hög prioritet, mekanismen reproducerad med riktig condition.** API-proben
skapade ett ändligt player-owned sår med budget 5 och fem intervall på 2400 ms.
Efter expiry hade målet förlorat **4 HP**, inte 5, och såret var borta.
Det var en kontrollerad condition-probe, inte en naturlig tredje yxträff.

Conditionmotorn tickar varje 1000 ms och för över varje nästa intervall utan att
bevara föregående överdrag. Native Bloodletting har samma fel med dagens
[18-sekundersschema](../../Rookhaven/src/passives.cpp#L292): budget 5 ger fem
3600-ms-intervall, som tickas vid ungefär 4, 8, 12, 16 och 20 sekunder. Conditionen
hinner löpa ut vid 18 sekunder. Budget 4 har motsvarande problem.

**Förslag:** Skapa ett schema i hela motorticks och fördela både tids- och
skaderester, så den totala budgeten levereras innan expiry. Ändra den särskilda
Bloodletting-schemaläggningen utan att tyst ändra vanlig äldre bleeding.

**Acceptans:** Budget 1–12, standard och giltiga alternativa durations/tickantal,
naturlig trigger, tre sår, starkare ersättning, cure, immunity och cleanup.
Varje icke avbrutet, icke immunt sår ska leverera hela sin budget utan extra skada.

Bevis: `out/final-audit/bleed-budget.log`,
`beforeHP=1000000 afterHP=999996 expected=5 actual=4 stacksAfter=0`.

### Immuna mål får räknade men oskadliga sår

**Mellanprioritet, reproducerat edge case.** Den isolerade dummyn gavs tillfälligt
enbart conditionimmunitet mot bleed, med uttrycklig kontroll att den inte var
immun mot fysisk skada. Ett player-owned wound accepterades och räknades som
en stack även efter 6,5 sekunder, trots att HP inte minskade.

Direkt delayed-condition-grant saknar immunitykontroll. Räknade sår kan även
uppfylla [Rends egen-sår-bonus](../../Rookhaven/src/passives.cpp#L701); denna
bonuskonsekvens är kodverifierad, inte livekastad i auditproben. Befintliga
bleed-immuna monster har ofta även fysisk immunitet, så detta ska inte beskrivas
som extra Rend-skada på samtliga sådana monster.

**Förslag:** Avvisa immune wounds vid både grant och special-bleed-route.
Stackantal, combat status och Rend ska använda giltiga aktiva sår.

**Acceptans:** Bleed-immun men fysiskt sårbar dummy får inga specialstacks eller
Rendbonus; vanligt sårbart mål fungerar fortfarande. Äldre bleeding bibehålls.

Bevis: `out/final-audit/bleed-immunity.log`. Den tillfälliga runtimefixturen
återställdes i `finally` och servern startades om. Fixturefilens SHA256 matchar
åter källan: `3c5ce0e22897992f0a74db5f20528843534973dcaab642fcc7aa706ab783f555`.

### Centrala config-filer var ignorerade av Git

**Åtgärdat efter användarens förtydligande.** Serverns
[gitignore](../../Rookhaven/.gitignore#L190) hade en generell regel för alla filer
som heter `config.lua`. Före undantagen bekräftade `git check-ignore -v` detta för både
`data/lib/passives/config.lua` och `data/lib/class_spells/config.lua`.
De fanns lokalt men ingick inte bland nya filer som Git normalt tar med.
Passiv- och spellkod laddar dem med `dofile`.

Två exakta undantag är nu införda:

```gitignore
!data/lib/passives/config.lua
!data/lib/class_spells/config.lua
```

`git status --untracked-files=all` visar nu båda som nya inkluderbara filer.
`git check-ignore config.lua` bekräftar att serverns privata huvudkonfiguration
fortfarande ignoreras. Ingen Git-staging eller commit gjordes. Verifiera uppstart
från en ren checkout innan leverans.

## Serverns huvudconfig och manuella installationssteg

**Inga nya rader behöver läggas till i serverns huvudfil `config.lua` i detta skede.**
De två versionerade filerna ovan innehåller balansvärden och behöver följa med
en framtida serverkodleverans. De är separata från den privata huvudfilen.

`passiveTestEnabled = true` finns i den genererade, isolerade lokala
`out/local-server/passives-runtime/config.lua`. Det är inte en instruktion att
aktivera funktionen på DEV eller PROD. Native systemet kräver fortfarande loopback.

När ett senare leveransinkrement kräver huvudconfigändringar ska dess rapport ha
en tydlig **Obligatorisk ändring i serverns config.lua**-sektion med exakt kodblock,
miljö, standardvärden och omladdnings-/omstartsbehov. Manuell installation får inte
vara underförstådd i en lista över serverkodfiler.

## UI och UX

De nya namnplattorna och nodformerna fungerar visuellt i alla sex granskade
800×640-bilder. Ingen blockerande namn-, ikon- eller linjekrock hittades.

| Fynd | Påverkan | Lösningsförslag |
| --- | --- | --- |
| Klassbekräftelsen saknar eget statusfält | Waiting, fel och timeout skrivs i den bakomliggande huvudrutans footer; främre knappar kan verka sluta fungera | Visa status och återhämtning i aktiva dialogen. Testa utebliven respons och serveravvisning |
| Spellkort säger Ready endast utifrån cooldown | Spelaren med noll mana eller fel utrustning får missvisande beredskap | Skriv åtminstone Cooldown ready och visa kända hinder; servern avgör slutlig behörighet |
| Klassvalet stängs efter 60 sekunder utan synlig tidsförklaring | Sex klasser och permanent val kan kräva längre lästid | Visa expiry/tid; överväg längre eller kontrollerat förnybar offer utan att försvaga servergates |
| 800×600 klipper andra namnraden på vissa minors i första vyn | Alla kontroller är nåbara och scroll fungerar, men starten är mindre tydlig | Nya/tomma träd kan öppnas vid nederkanten; explicit nodval ska scrolla även namnplattan synlig. Bevara vanlig användarscroll |
| Klassidentiteten saknas i vanlig Look | Alla sex beskrivs fortfarande som Ascended | Lägg till vald klass via servermetadata utan att ändra vocation-ID |
| Porträtt och några äldre bildbevis behöver kompletteras | Manliga klassporträtt har inte samma granskning; äldre spellbilder visar tidigare värden | Granska båda varianter och ta nya spellbilder från aktuellt paket |

Referenser: [klassstatus](../modules/game_passives/classchoice.lua#L24),
[timeout](../modules/game_passives/classchoice.lua#L78),
[spelberedskap](../modules/game_passives/classspells.lua#L48),
[spellkatalog](../modules/game_passives/classspells.lua#L129),
[vanlig Look](../../Rookhaven/src/player.cpp#L119).

## Kritikerns designfynd

### Capstonevägar behöver verifieras vid första upplåsningen

Alla klasser ärver samma tre
[native familjer](../../Rookhaven/src/passives.cpp#L119) och
[katalogfamiljer](../../Rookhaven/data/lib/passives/test.lua#L34).
Blade Storm behöver critical hits men dess förkrav räknar Guard, Recovery och
Steady, inte crit-major Measured Blade. Stoneguard och Aegis ligger i
Pressure/Tactical/Sustain-familjen utan Guard.

Med dagens första capstonebudget, **16 poäng vid level 40**, kan Blade Storm få
högst **3% egen passiv critchans** utan critutrustning. Ett bygge kan spendera
10 på sina capstoneförkrav, 1 på capstone och 5 på critvägen. Vid antagna lyckade
attacker varannan sekund ger 3% cirka **67 sekunders förväntad väntan** per crit;
ytterligare monster måste dessutom finnas intill. Detta är en illustration,
inte uppmätt jakt eller en garanterad proc-tid. Det tidigare bounded naturaltestet
misslyckades vid 2,5% och fick använda ett större bygge med 5,5%.

**Förslag:** Redovisa ett fungerande 16-poängsbygge för var och en av de 18
capstonesen. Om kopplingarna ändras, använd klassvisa familjer med stabila ID:n,
samordnad native/katalogvalidering och hantering av äldre sparade builds.
Behåll den godkända fyrpoängsgaten. Alternativet att ändra trigger kräver ett
uttryckligt designbeslut; flyttad grafik löser inte reglerna.

### Gemensamma wards kan undantränga healer-capstone

[grantWard](../../Rookhaven/src/passives.cpp#L218) har ett enda aktivt ward per
mottagare och accepterar bara en starkare ersättare. Vid 735 max HP ger
Stonebond cirka 22 HP skydd. Aegis från 29 effektiv healing ger cirka 4 HP.
Ett kvarvarande Stonebond på minst 4 HP kan därför avvisa den senare Aegis-granten.
Det följer nuvarande anti-stackingregel; det är en balans- och feedbackfråga.

**Förslag:** Testa Lifekeeper+Aegis och Earthshaker+Stonebond i samma party och
mät skapade, avvisade, absorberade och utgångna wards. Gör avvisningsorsaken
begriplig. Besluta om gemensam skyddsbudget först efter mätningen; inför inte
obegränsad stacking för att dölja problemet.

### Startspells behöver egna användningsfall inom low and slow

Den konservativa balansen minskar risken för stora uppgraderingar men bevisar
inte att båda nya spells känns värda att få. Focused Thrust och Flurry konkurrerar
med faktiskt lärbar Swipe, vars billigare/tätare AoE kan vara stark i vanlig
rotation. Armor på två Flurry-träffar och capstone-ekon kan ytterligare ändra
resultatet. Jämför total rotation med samma legitima gear, mana och encounters;
öka inte råskadan enbart för att ett alternativ känns svagt.

Nya Ascension-spells lärs vid level 1 men maxmana är då 0. Mana räcker först
kring level 3–4, och befintlig vanlig grund-wand/rod kräver level 7. Det tidigare
Ascension-beteendet är bevarat. **Vanlig progression från 1 till 7** måste avgöra
om väntan känns rimlig och om utrustningen är tillgänglig. Admincasts vid level 40
ger inte det beviset.

## System och innehåll som återstår

- **Senare spellinlärning:** Skilj komplett klasskatalog från de två starter grants.
  Native namnlistor, startupvalidering, The Nameless och klientens två fasta kort
  behöver en gemensam utbyggbar learned-lista och lärarkrav. Att bara lägga till
  en tredje configrad är inte tillräckligt. Detta är en planlucka, inte en defekt
  inom det nuvarande två-startspell-inkrementet.
- **Ascensionens felvägar:** Befintlig inventoryflytt sker slot för slot utan
  rollback. Misslyckad senare flytt kan lämna delar i depot utan vald klass.
  Full depot och injicerat DB-fel ska testas innan förkontroll/rollback väljs.
  Inget itemförlustresultat har påvisats av denna granskning.
- **Volley:** Den befintliga registreringen kräver ett native melee-vapen medan
  scriptet kräver bow/crossbow. Spellen är därför inte en normalt användbar
  Marksman-baseline. En separat eligibilityfix och riktig ammo-/kostnads-/cooldown-
  kontroll behövs innan rotationsbalansen kan räkna med den.
- **Konkreta integrationstestluckor:** Hela legacy Soul Drain/Chain Lightning-
  budgetar mot echoes, alla element/resistanser, vanlig death-loss och tvåklassparty
  återstår. Tidigare smoke-resultat ska inte ersätta dessa mätningar.
- **Belastning:** Globala gränser på 128 actions och 512 schemalagda effekter kan
  neka context eller tyst hoppa över procs vid mättnad. Faktisk peakbelastning och
  fördelning mellan spelare är inte mätt. Lägg till diagnostik och profilera före
  utrullning; höj inte gränserna utan underlag.
- **Leverans:** Separera permanent produktionsfunktion från GOD-testoverlay och
  fixturekommandon, öva migration/återställning i separat DB-kopia och verifiera
  rätt DEV/PROD-paket, updater och checksums. Funktionerna är avsiktligt lokala nu.

## Sista kontroller som faktiskt kördes

| Kontroll | Resultat | Bevis |
| --- | --- | --- |
| Native UI för sex träd, 1280×800 och 800×640 | PASS med aktuellt paket | `out/passives-final-audit-preview.log` |
| Sex träd vid faktisk in-game-minimistorlek 800×600 | PASS för geometri, interaktion och scroll; initial namnklippning beskriven ovan | `out/final-audit/minimum-ui.log`, sex `passives-*-minimum-retro.png` |
| Normalprofilens module guard | PASS | `out/passives-regressions/normal-module-guard.log` |
| Lifecycle, save/reconnect, HP-condition-komposition, store och TCP | PASS | `out/passives-regressions/lifecycle.log` |
| Baseline med flagga på, utan overlay | PASS | `out/passives-regressions/baseline-enabled.log` |
| Baseline med flagga av | PASS | `out/passives-regressions/baseline-disabled.log` |
| Sex kataloger, 18 presets, förkrav, forged rejection, weapons och cleanup | PASS | `out/passives-regressions/six-trees-contract.log` |
| Riktig UI Apply under combat | FEL reproducerat: draft 2 → 0, sparade ranks/revision oförändrade | `out/final-audit/draft-reject.log` |
| Player-owned bleeding, liten budget | FEL reproducerat: 5 budget → 4 faktisk skada | `out/final-audit/bleed-budget.log` |
| Bleed-only immune target | FEL reproducerat: 1 räknad stack, ingen HP-skada | `out/final-audit/bleed-immunity.log` |
| Aktuell källa mot dekrypterat paket | PASS, 117 init-/modul-/bildresurser, nykompilerad bytekod, inga probe-entries i slutarkivet | `out/final-audit/artifact.json`, `check-artifact.py` |
| Runtimeåterställning och manifests | PASS; fixture identisk med källa och originalserver återstartad | `out/final-audit/immune-restored-start.log` |
| Git-inkludering av två balansfiler | RÄTTAT och verifierat; privat huvudconfig fortsatt ignorerad | Serverns `.gitignore`, `git status` och `git check-ignore` |

Regressionssammanfattning: `out/passives-final-audit-regressions.log`.
De nya reproduktionerna täcker beteenden som de tidigare godkända gatesen inte
kontrollerade. Deras OK-markörer betyder lyckad felreproduktion, inte rättad spelkod.
Tidigare verifiering av klasscommit, två starters, party-healing och permanenta
Reaver-felvägar återanvänds där källorna är oförändrade; dessa hela suites kördes
inte om i denna audit.

Auditadaptering behövdes för två provantaganden: offline-startens minsta höjd är
640, medan online-retro stöder 600; minimitestet kräver nu uttryckligen faktisk
root 800×600. Klientens Lua `readFileContents` returnerar råa krypterade bytes;
artefaktkontrollen jämför därför korrekt ENC3-dekryptering med källor/bytekod.
Inget av dessa första adapterfel är ett upptäckt produktionspaketfel.

Slutpaketets SHA256 är fortsatt
`9e9393aac30b200694c13b4fcb35a1b62e150cf7d6582221dc50148a3c092149`.
Klientens och runtimens checksummanifest matchar:
`8e9479c8f3fbd2b2aed5d560b98b617268088544b791876cbf201371bb4cd822`.
Inga produktionsservrar eller DB33307 berördes.

## Rekommenderad arbetsordning

1. Rätta Apply-utkast, Bloodletting-timing och immunity. Verifiera nya riktade
   regressioner på den rättade versionen. Configfilernas Git-undantag är redan införda.
2. Förbättra synlig klassstatus, spellberedskap och första scrollposition utan
   ändrad retrostil. Verifiera 800×600 och avvisning/timeout.
3. Testa Ascensionens inventory-/DB-felvägar och vanlig level 1–7-onboarding.
4. Granska alla 18 capstones med 16 poäng; besluta om klassvisa familjer innan
   sparade builds eller balancevärden ändras.
5. Mät legitima huntingrotationer och Aegis/Stonebond-party. Avsluta därefter
   senare-spell-grunden och planera migrations-/DEV-leverans.

Ingen ändrad capstoneväg, proc-trigger eller balanssiffra är beslutad av denna audit.
