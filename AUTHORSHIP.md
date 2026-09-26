# Szerzőség / Authorship

**Projekt / Project:** `windows-remote-onboarding`
**Szerző / Author:** Bozó Bernát
**Első kiadás / First release:** 2026-09-26

## Magyar

Ez a projekt **ember által tervezett és irányított munka, amelynek kódját
részben MI-eszköz (Claude, Anthropic) segítségével írtuk.** A gépi
közreműködést nyíltan vállalom; az alábbiakat viszont ember végezte, és ezek
együtt adják a mű szerzői jogilag releváns részét:

- **A feladat és a követelmények meghatározása.** Mit csináljon a rendszer, mit
  ne, milyen esetekre kell működnie, mi számít hibának.
- **Az architektúra és a tervezési döntések:** csak kifelé irányuló kapcsolat; ujjlenyomatra kötött szervertanúsítvány; helyszínenként külön csomag és csoport; a bináris és a beállítófájl hash-ellenőrzése futtatás előtt; közlés a rejtőzés helyett (gépre kiírt tájékoztató, beírandó megerősítés, engedély nélkül futtatható eltávolító).
- **A válogatás és az elrendezés.** Mi került be a projektbe és mi maradt ki,
  milyen sorrendben és szerkezetben — beleértve azt is, mely megoldásokat
  vetettem el.
- **A tényleges tesztelés valós eszközökön:** két valódi, élesben bevont Windows-gépen (Windows 11 és Windows 10 22H2); a függőségmentes teszt-készlet 24 állítással, köztük egy tényleges futtatással ideiglenes mappán.
- **A hibák felismerése és a javítások iránya:** a valódi gépeken előjött hibaosztályok (pl. hálózati meghajtóról emelt joggal indítás, a Windows argumentum-idézése), és 2026 szeptemberében az eltávolító hibája: a beléptetési fájl a gépen maradt, miközben a szkript azt írta ki, hogy nem maradt semmi — javítva, mutációs próbával igazolt regressziós tesztekkel.
- **Az üzemeltetési tapasztalat visszavezetése a kódba.** Amit éles használat
  közben tanultam, és ami emiatt megváltozott a megoldásban.

A projekt **egésze** — a felépítése, az összeválogatása és az elrendezése —
szintén az én szerzői döntéseim eredménye, függetlenül attól, hogy az egyes
kódrészletek hogyan készültek.

## English

This project is **human-conceived and human-directed work whose code was written
in part with the help of an AI tool (Claude, by Anthropic).** I disclose the
machine contribution openly. The following, however, was done by a human, and
together these constitute the copyright-relevant part of the work:

- **Definition of the problem and the requirements** — what the system must do,
  what it must not, which cases it must handle, what counts as a failure.
- **Architecture and design decisions:** outbound-only connection; a pinned server certificate; a separate package and group per site; hash checks of the binary and the settings file before anything runs; disclosure over stealth (a notice left on the machine, typed confirmation, an uninstaller that needs no permission).
- **Selection and arrangement** — what went into the project and what stayed
  out, in what structure, including which approaches were rejected.
- **Actual testing on real devices:** on two real Windows machines enrolled in production (Windows 11 and Windows 10 22H2); a dependency-free test harness with 24 assertions, including one real run against a temporary folder.
- **Identifying defects and directing the fixes:** the failure classes that surfaced on real machines (e.g. elevated start from a mapped network drive, Windows argument quoting), and in September 2026 an uninstaller defect: the enrolment file stayed on the machine while the script claimed nothing was left — fixed, with regression tests verified by a mutation check.
- **Feeding operational experience back into the code.**

The project **as a whole** — its structure, selection and arrangement — is the
result of my authorial choices, regardless of how individual code fragments were
produced.

## Required Notice

A licenc „Notices" szakasza szerint mindenkinek, aki a szoftvert továbbadja,
tovább kell vinnie a `Required Notice:` kezdetű sorokat. / Under the licence's
"Notices" section, anyone who passes the software on must keep the lines starting
with `Required Notice:`.

```
Required Notice: Copyright Bozó Bernát — https://github.com/bozobernat/windows-remote-onboarding
```

## Ami nem ebben a fájlban dől el / What this file does not settle

Ez a feljegyzés a védhetőséget **javítja**, de nem tesz bizonyossá: a gépi
közreműködéssel készült művek jogi megítélése 2026-ban sem letisztázott, és
országonként eltér. Két dolog ettől függetlenül is áll: (1) a PolyForm
„Acceptance" szakasza szerint a feltételeket kötelezettségként ÉS feltételként
is el kell fogadni ahhoz, hogy bárki bármilyen engedélyt kapjon — aki elfogadta,
majd megszegi, az megállapodást szegett; (2) a projekt és a szerző neve nem a
szerzői jogon múlik.

This record **strengthens** the claim but does not make it certain: the legal
treatment of works made with machine assistance is unsettled in 2026 and varies
by country. Two things hold regardless: (1) under the PolyForm "Acceptance"
section the terms must be accepted as both obligations and conditions before any
licence is granted — whoever accepts and then breaches them breaches an
agreement; (2) the project's and the author's name do not depend on copyright.
