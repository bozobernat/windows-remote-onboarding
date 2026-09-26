# windows-remote-onboarding

**Egy emelt jogú futtatásból** von be egy Windows-gépet a távtámogatásba — akkor
is, ha a gép valaki más NAT-ja mögött van.

Az ügynök **kifelé** kapcsolódik, ezért nincs mit nyitni a távoli gép routerén, és
nem kell fix IP-t intézni. A csomag **önhordó**: nem tölt le semmit, és az
ügynök-bináris meg a beállítófájl SHA256-át ellenőrzi, *mielőtt* bármelyiket
futtatná.

Két valódi gépen üzemel (Windows 11 és Windows 10 22H2). Kiváltotta a fizetős
AnyDesk-előfizetést.

*(English version: [README.md](README.md))*

**Licenc:** PolyForm Noncommercial 1.0.0 — nem kereskedelmi célra szabadon használható; kereskedelmi felhasználáshoz külön engedély kell (l. [Licenc](#licenc)).

---

## Amit a legtöbb távoli hozzáférés kihagy

A távtámogató szoftver mindent meg tud tenni, amit a gép elé leülő ember. Ez a
csomag ezt olyasminek kezeli, amit **közölni kell, nem elrejteni**:

- **Egy köznyelvi tájékoztató kerül a gépre** (`TAJEKOZTATO.txt`), ami leírja,
  pontosan mi települt, mire ad lehetőséget, hogy csatlakozáskor látható jelzés
  van, és mi az, ami *nem* történik (nincs bejövő port, nincs folyamatos
  képernyőfelvétel, a gép nem lett elérhető az internet felől).
- **Asztali eltávolító parancsikon**, ami leveszi az ügynök-szolgáltatást, a
  támogatói fiókot (és a profilját), magát a parancsikont, és a teljes
  `C:\ProgramData\PAO-Tavoli-Support` mappát — benne a `MeshAgent.msh`-sal, a
  beállítással és a generált jelszófájllal. Engedélykérés nélkül, azonnal, a
  támogató megkérdezése nélkül. Szándékosan csak a napló marad; abban nincs
  jelszó és nincs beléptetési adat (l. *Amit NEM csinál*).
- **A telepítő beírandó megerősítést kér**, miután kiírta, mit fog csinálni.
- **Nem hoz létre rendszergazdai fiókot**, csak ha kifejezetten megadod a
  `-WithRdpAccount` kapcsolót.

Ha a te távtámogatási megoldásodat nem tudja tíz másodperc alatt, a te
megkérdezésed nélkül visszavonni az, akié a gép — az nem beleegyezés, hanem
hozzáférés.

## Sértetlenség, mielőtt bármi fut

- Minden becsomagolt fájl (ügynök-bináris, beállítás, konfiguráció) SHA256-tal
  ellenőrizve a `pao-remote.json` alapján. Eltérésnél a futás leáll.
- A szerver TLS-tanúsítványa **ujjlenyomatra van kötve** (`Test-ServerCertPin`).
- Telepítéskor semmit nem tölt le, tehát a futó bináris pontosan az, amit
  becsomagoltunk, és nincs letöltés, amiben meg kellene bízni.
- Hogy a pinelés pontosan hogyan működik: az elérhetőség-próba bármilyen
  tanúsítványláncot elfogad, és az ujjlenyomatot utána veti össze. Ez pin, nem
  lánc-ellenőrzés — szigorúbb, mint egy CA-ban megbízni, de nem ugyanaz.

## Helyszínenként külön csomag

Minden helyszín saját eszközcsoportot és saját csomagot kap. Az egyik csoporthoz
készült csomag nem tud egy másik csoportba beregisztrálni, és a hozzáférés
csoportonként külön visszavonható — egy gép bevonása tehát sosem tágítja ki a
hozzáférést a többire.

> [!WARNING]
> **Figyelmeztetés — olvasd el telepítés előtt**
>
> Ez a szkript **távoli hozzáférést konfigurál egy Windows gépen**. Rosszul
> beállítva vagy rossz kézbe kerülve a gép teljes átvételét teszi lehetővé.
> Kizárólag olyan gépen futtasd, amely a tiéd, vagy amelynek üzemeltetésére a
> gép tulajdonosától kifejezett felhatalmazásod van — és a tulajdonos tudtával.
> Futtatás előtt **olvasd át a forráskódot**: rendszergazdai jogosultsággal fut
> és tartós változtatásokat végez a rendszeren. Ezt személyes projektként,
> ellenszolgáltatás nélkül teszem közzé, garancia és támogatási kötelezettség
> nélkül; a használatból eredő bármilyen kárért, adatvesztésért vagy biztonsági
> incidensért a felelősség a futtatóé.

---

## Üzemmódok

| Parancs | Mit csinál |
|---|---|
| `Run-Setup.bat` | telepítés (megerősítést kér) |
| `Diagnose-Setup.bat` | csak vizsgálat — semmit nem változtat |
| `Repair-Setup.bat` | a tipikus elromlások javítása (főleg rossz szervercím) |
| `Eltavolitas.bat` | mindent eltávolít |

Kapcsolók: `-Yes`, `-WithRdpAccount`, `-Diagnose`, `-Repair`, `-Uninstall`,
`-SkipSelfTest`.

## A lényeg az önteszt

Az a bevonó szkript, ami „KÉSZ"-t ír, miközben a csatorna valójában nem áll,
rosszabb annál, ami hangosan elhasal. Két réteg véd ez ellen:

- Az `Invoke-SelfTest` **a célgépen fut le a telepítés végén**, és csak akkor
  mond sikert, ha a csatorna tényleg áll. Ha nem, megmondja, mi a baj.
- A `Setup-PaoRemote.Tests.ps1` — **276 soros, függőségmentes** teszt-készlet,
  24 állítással, minden olyan hibaosztályra, amit a fejlesztés során valóban
  elkövettünk. **Nem kell hozzá Pester**, és `pwsh`-sel Linuxon is fut:

```
pwsh -NoProfile -File ./Setup-PaoRemote.Tests.ps1
```

  **Összeállított csomagot ellenőriz, nem egy friss klónt.** Az állítások nagy
  része a becsomagolt ügynök-binárist, a `.msh` beállítófájlt és a valódi
  `pao-remote.json`-t veti össze a rögzített hash-ekkel — ez a három fájl pedig
  szándékosan nincs benne ebben a repóban. Friss klónon tehát hibákat fog
  jelenteni; abban a mappában futtasd, ahol összeállítottad a teljes csomagot.

Szándékosan csak azt teszteli, ami **gépmódosítás nélkül** eldönthető. A többi
a célgépen futó önteszt dolga.

## Példa kimenet

Ez a kimenet valóban lefutott, ezen a gépen, egy hordozható PowerShell 7
(`pwsh`) alatt, Linuxon — nem Windowson, és nem kézzel begépelve —,
közvetlenül ennek a repónak a kihúzott (checkout) állapotán, semmi
hozzáadás vagy elvétel nélkül. Ez az, amit egy friss klónnál kapsz, bármelyik
operációs rendszeren: az 1–2. szakasz csomag-ellenőrzései helyesen buknak,
mert a valódi, helyszínre szabott csomag (`pao-remote.json`, `MeshAgent.msh`,
`MeshAgent64.exe`) szándékosan nincs a repóban (lásd fent), gitignore-olva
van. Egy valóban összeállított csomaggal ugyanez a 7 ellenőrzés is átmegy, és
a futás 24/24 — ebben a teszt-fájlban nincs Windows-specifikus rész, és nincs
a hiányzó csomaghoz kötött különleges eset sem.

```
Setup-PaoRemote - onteszt

1. A csomag teljes-e
  [BUKO] megvan minden fajl
         hianyzik: pao-remote.json
  [BUKO] a pao-remote.json ervenyes es megvannak a kotelezo mezoi
         a pao-remote.json nem olvashato
  [BUKO] a konfigban rogzitett hashek egyeznek a tenyleges fajlokkal
         a pao-remote.json nem olvashato
  [BUKO] a cert-ujjlenyomat 64 hexa karakter
         rossz alaku cert-ujjlenyomat  (a minta nem talalt: '^[0-9a-fA-F]{64}$')
  [OK]   a szerverUrl es az agentWss ugyanarra a gepre mutat

2. A beallitofajl (.msh)
  [BUKO] van explicit MeshServer cim, es NEM "local"
         MeshAgent.msh nem talalhato
  [BUKO] a .msh cime ugyanaz, mint a konfig agentWss mezoje
         MeshAgent.msh nem talalhato
  [BUKO] megvannak a beleptetesi mezok
         MeshAgent.msh nem talalhato

3. A script szerkezete
  [OK]   szintaktikailag helyes
  [OK]   megvan mind a hat kapcsolo
  [OK]   megvannak a kulcsfontossagu fuggvenyek
  [OK]   tisztan ASCII - a magyar konzolon nem torhet el
  [OK]   sehol nem kapcsolja ki a tanusitvany-ellenorzest
  [OK]   nem tolt le semmit futasidoben
  [OK]   a telepites megerositest ker (nem lehet csendben bevonni egy gepet)

4. Az indito .bat fajlok
  [OK]   mind ASCII es CRLF sorvegu
  [OK]   mind szol, ha halozati meghajtorol indul emelt jogon
  [OK]   az Eltavolitas.bat megerositest ker

5. A gepre kiirt tajekoztato
  [OK]   leirja, hogyan lehet megszuntetni
  [OK]   megmondja, mire ad lehetoseget - nem szepiti

6. Az eltavolitas tenyleg eltavolit
  [OK]   a megtartando lista CSAK a naplot tartalmazza
  [OK]   a "nem maradt semmi" uzenet csak a takaritas UTAN hangzik el
  [OK]   a takaritas a naplot meghagyja, mindent mast torol
  [OK]   a tajekoztato nem iger tobbet, mint amit az eltavolitas megtesz

Eredmeny: 17 rendben, 7 bukott.
```

A teszt-készlet maga is ASCII-ban, ekezet nelkul irja ki az allitasok
neveit es uzeneteit (ugyanugy, ahogy a fejlesztes es hibakereses is folyt) —
ez szandekos, lasd fent a "tisztan ASCII" allitast. A fenti 7 bukás a várt,
szándékos eset — l. lent az "Amit NEM csinál" szakaszt.

## Amit NEM csinál

- **Nem tartalmazza az ügynök binárisát és a beléptetési titkot.** A
  `MeshAgent64.exe`-t és a `MeshAgent.msh`-t a saját MeshCentral-szerveredről
  szeded le. A `MeshAgent.msh` a csoportba léptetés titkát tartalmazza — itt
  gitignore-olva van, és sehova nem szabad commitolni.
- **A KVM nem az RDP-munkamenetet mutatja.** Ha valaki RDP-n dolgozik a gépen,
  az ügynök képernyő-funkciója a konzol-munkamenetet látja, nem az övét. Ez a
  MeshCentral elvi korlátja, nem hiba. A `Diagnose-Setup.bat` megmondja, melyik
  út járható.
- **Nem nyit portot** a távoli gép routerén, és nem teszi a gépet elérhetővé az
  internet felől.
- **Az eltávolító a naplót szándékosan meghagyja** a
  `C:\ProgramData\PAO-Tavoli-Support` mappában: az a nyoma annak, mi és mikor
  került a gépre. Jelszót és beléptetési adatot nem tartalmaz, bármikor
  törölhető. A mappa minden más tartalmát törli. A saját két fájlját (a futó
  `Eltavolitas.bat`-ot és a `Setup-PaoRemote.ps1`-et) futás közben nem lehet
  törölni, ezért azokat egy külön folyamat takarítja el a háttérben, amint
  bezárod az eltávolító ablakát — a script ki is írja, amikor ez történik.
- **A gépre kiírt tájékoztató nem említi a támogatói fiókot.** A
  `TAJEKOZTATO.txt` az ügynökről szól, de nem arról a helyi rendszergazda-
  fiókról, amit a `-WithRdpAccount` létrehoz. Ha ezt a kapcsolót használod,
  mondd el külön a gép tulajdonosának — a tájékoztató önmagában hiányos lesz.
- **A `-Yes` kihagyja a begépelt megerősítést**, amit a fenti szakasz külön
  garanciaként említ. Csak saját gépen használd.
- **A `-WithRdpAccount`-hoz nincs `.bat`.** A négy batch-fájl rögzített
  kapcsolókkal indítja a szkriptet; ezt emelt jogú PowerShellből, közvetlenül a
  `.ps1`-nek kell átadni.

## Beállítás

1. Állíts fel egy MeshCentral szervert, és hozz létre egy eszközcsoportot az
   helyszínnek.
2. Töltsd le annak a csoportnak a `MeshAgent64.exe`-jét és `MeshAgent.msh`-ját
   ebbe a mappába.
3. Másold a `pao-remote.example.json`-t `pao-remote.json`-ra; töltsd ki az
   helyszín-megnevezést, a csoportot, a `szerverUrl`-t, az `agentWss`-t (egyeznie
   kell a `.msh` `MeshServer=` sorával), a két fájl-hash-t (`agentExeSha256`,
   `mshSha256`) és a szerver tanúsítvány-ujjlenyomatát (`szerverCertSha256`).
4. Másold **az egész mappát** a célgépre — helyi lemezre, **ne** leképezett
   hálózati meghajtóra. Az emelt jogú munkamenet alapból nem látja a leképezett
   meghajtókat; a `.bat` ezt észreveszi és szól, de a másolás egyszerűbb.
5. Jobbklikk a `Run-Setup.bat`-ra → *Futtatás rendszergazdaként*.

Napló: `C:\ProgramData\PAO-Tavoli-Support\Setup-PaoRemote.log`

---

## Hogyan készült, és ez mit jelent

A kódot AI-ügynök (Claude) írta. Én határoztam meg a viselkedést, én döntöttem
el a bizalmi modellt (csak kifelé kapcsolódás, ujjlenyomatra kötött tanúsítvány,
ügyfelenkénti csoportok, közlés a rejtőzés helyett), én futottam bele a
hibamódokba valódi gépeken, és én üzemeltetem az eredményt.

Amit egy generált szkript nem ad meg: annak a listája, ami valaki más Windows-
gépén ténylegesen elromlott, és a hozzá utólag megírt tesztek, hogy ne tudjon
újra elromlani. Ez a lista az a 24 állítás.

A szkript, a gépre kiírt tájékoztató és a kommentek magyarul vannak — azoknak az
embereknek a nyelvén, akiknek a gépét bevonja.

## Licenc

Ez a projekt a **PolyForm Noncommercial License 1.0.0** alatt érhető el (lásd:
[LICENSE](LICENSE)). Ingyenesen, engedélykérés nélkül használhatod, módosíthatod
és továbbadhatod **bármilyen nem kereskedelmi célra**, ideértve kifejezetten:

- magánszemélyként, a saját vagy a hozzátartozód otthonában;
- jótékonysági szervezetként (pl. egyházi vagy karitatív szolgálat);
- oktatási intézményként és közfinanszírozott kutatóhelyként;
- közegészségügyi vagy közbiztonsági szervezetként;
- állami vagy önkormányzati intézményként.

A licenc szerint ez akkor is így van, ha a szervezet állami vagy pályázati
finanszírozásból működik.

**Kereskedelmi felhasználáshoz külön engedély kell tőlem.** Ide tartozik, ha a
szoftvert vagy a rá épülő szolgáltatást pénzért kínálod — akár előfizetésként,
akár telepítéssel vagy ügyfélszolgálattal együtt. Ilyen esetben **nyiss egy
issue-t** a projektben (<https://github.com/bozobernat/windows-remote-onboarding/issues>), „commercial licence" címmel.
Nem zárkózom el tőle, csak tudni akarok róla.

```
Required Notice: Copyright Bozó Bernát — https://github.com/bozobernat/windows-remote-onboarding
```

*(Ezt a sort a licenc „Notices" szakasza alapján mindenkinek tovább kell vinnie,
aki a szoftvert továbbadja.)* A szerzőség emberi és gépi részének elhatárolása:
[AUTHORSHIP.md](AUTHORSHIP.md).

### Hozzájárulás

Örülök a javításoknak. Mielőtt pull requestet fogadok el, alá kell írnod a
[CLA.md](CLA.md)-t — egy rövid nyilatkozatot arról, hogy a beküldött kódot én is
felhasználhatom, beleértve a kereskedelmi engedélyeket. Enélkül a hozzájárulásod
később megkötné a projektet.

### Védjegyek

Ez a projekt nem áll kapcsolatban a Microsofttal, a MeshCentral projekttel, sem más olyan harmadik féllel, amelynek termékével együttműködik, és egyikük sem támogatja. A védjegyek a jogosultjaik tulajdonát képezik.
