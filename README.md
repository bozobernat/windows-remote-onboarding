# windows-remote-onboarding

Onboards a Windows machine into remote support in **one elevated run** — even
when the machine is behind someone else's NAT.

The agent connects **outbound**, so there is no port to open on the remote
machine's router and no static IP to arrange. The package is **self-contained**:
it downloads nothing, and it verifies the SHA256 of the agent binary and its
settings file *before* running either.

In production on two real machines (Windows 11 and Windows 10 22H2). It
replaced a paid AnyDesk subscription.

*Magyar nyelvű leírás: [README.hu.md](README.hu.md)*

**License:** PolyForm Noncommercial 1.0.0 — free for any noncommercial use; commercial use needs a separate licence (see [License](#license)).

---

## The part most remote-access tooling skips

Remote support software can do everything a person sitting at the keyboard can
do. This package treats that as something to **disclose, not hide**:

- **A plain-language notice is written onto the machine** (`TAJEKOZTATO.txt`)
  saying exactly what was installed, what it permits, that a visible indicator
  appears on connection, and what does *not* happen (no inbound port, no
  continuous screen recording, machine not exposed to the internet).
- **A desktop uninstall shortcut** removes the agent service, the support
  account (and its profile), the shortcut itself, and the whole
  `C:\ProgramData\PAO-Tavoli-Support` folder — including `MeshAgent.msh`, the
  configuration and the generated password file. No permission needed, no call
  to the supporter, immediate. Only the log file is kept on purpose; it holds no
  password and no enrolment data (see *What it does not do*).
- **The installer asks for typed confirmation** after printing what it will do.
- **No admin account is created** unless you explicitly pass `-WithRdpAccount`.

If your remote-support setup cannot be revoked by the person whose machine it
is, in under ten seconds, without asking you — it is not consent, it is access.

## Integrity, before anything runs

- Every packaged file (agent binary, settings, config) is checked against a
  SHA256 recorded in `pao-remote.json`. A mismatch stops the run.
- The server's TLS certificate is **pinned** by fingerprint (`Test-ServerCertPin`).
- Nothing is fetched at install time, so the binary that runs is exactly the
  one packaged, and no download has to be trusted.
- Note how the pin works: the reachability probe accepts any chain and the
  fingerprint is compared afterwards. That is a pin, not chain validation —
  it is stricter than trusting a CA, but it is not the same thing.

## One package per site

Each site gets its own device group and its own package. A package built for
one group cannot register into another group, and access is revocable per
group — so onboarding a machine never widens access to the rest.

> [!WARNING]
> **Read before installing**
>
> This script **configures remote access on a Windows machine**. If
> misconfigured or misused, it allows full takeover of the host. Run it only on
> machines you own, or are explicitly authorised by the owner to administer —
> and with the owner's knowledge. **Review the source before running it**: it
> executes with administrative privileges and makes persistent changes. This is
> a personal project published without warranty, support or any service
> commitment; you assume all risk arising from its use.

---

## Modes

| Command | What it does |
|---|---|
| `Run-Setup.bat` | install (asks for confirmation) |
| `Diagnose-Setup.bat` | inspect only — changes nothing |
| `Repair-Setup.bat` | fix the common breakages (mainly a wrong server address) |
| `Eltavolitas.bat` | remove everything |

Switches: `-Yes`, `-WithRdpAccount`, `-Diagnose`, `-Repair`, `-Uninstall`,
`-SkipSelfTest`.

## The self-test is the point

An onboarding script that prints "DONE" when the channel is not actually up is
worse than one that fails loudly. Two layers guard against that:

- `Invoke-SelfTest` runs **on the target machine at the end of installation**
  and only reports success if the channel is genuinely up. If it is not, it
  says what is wrong.
- `Setup-PaoRemote.Tests.ps1` — a **276-line, dependency-free** test harness
  with 24 assertions, covering every failure class actually hit during
  development. **It does not need Pester** and runs under `pwsh` on Linux too:

```
pwsh -NoProfile -File ./Setup-PaoRemote.Tests.ps1
```

  **It validates an assembled package, not a bare clone.** Most assertions
  check the packaged agent binary, the `.msh` settings and the real
  `pao-remote.json` against their recorded hashes — and those three files are
  deliberately absent from this repository. On a fresh clone the harness will
  therefore report failures; run it in the folder where you have assembled a
  complete package.

It deliberately tests only what can be decided **without modifying a machine**.
The rest is the on-target self-test's job.

## Example output

Run for real, on this machine, under a portable PowerShell 7 (`pwsh`) on
Linux — not Windows, and not typed up by hand — directly against this
repository's checkout, with nothing added or removed. This is what you get
on a fresh clone, on any OS: the packaged-file checks in sections 1–2
correctly fail, because the real per-site package (`pao-remote.json`,
`MeshAgent.msh`, `MeshAgent64.exe`) is gitignored by design (see above) and
never shipped in the repo. With a real assembled package in place, those
same 7 checks pass and the run is 24/24 — nothing in the test file is
Windows-specific or specific to this missing-package state.

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

The test harness itself prints its assertion names and messages in Hungarian
(the language the script was built and debugged in); the assertions and pass
count are otherwise self-explanatory. The 7 failures above are the expected,
by-design ones — see "What it does not do" below.

## What it does not do

- **It does not include the agent binary or the enrolment secret.** You supply
  `MeshAgent64.exe` and `MeshAgent.msh` from your own MeshCentral server.
  `MeshAgent.msh` contains the group enrolment secret — it is gitignored here
  and must never be committed anywhere.
- **KVM does not show an RDP session.** If someone works on the machine over
  RDP, the agent's screen function shows the console session, not theirs. This
  is a MeshCentral design limit, not a bug. `Diagnose-Setup.bat` tells you
  which route is available.
- **It does not open a port** on the remote machine's router, and does not make the
  machine reachable from the internet.
- **The uninstaller keeps the log file** in `C:\ProgramData\PAO-Tavoli-Support`,
  on purpose: it is the record of what was installed and when. It contains no
  password and no enrolment data, and can be deleted at any time. Everything
  else in that folder is removed. Its own two files (the running `Eltavolitas.bat`
  and `Setup-PaoRemote.ps1`) cannot be deleted while they are running, so a
  detached process retries in the background and removes them once you close the
  uninstaller window; the script says so when it happens.
- **The notice left on the machine does not mention the support account.**
  `TAJEKOZTATO.txt` describes the agent, but not the local administrator account
  that `-WithRdpAccount` creates. If you use that switch, tell the owner
  separately — the notice alone is then incomplete.
- **`-Yes` skips the typed confirmation** that the disclosure section describes.
  Use it only on machines that are yours.
- **`-WithRdpAccount` has no `.bat`.** The four batch files run the script with
  fixed switches; to pass this one, call the `.ps1` directly from an elevated
  PowerShell.

## Setup

1. Stand up a MeshCentral server and create a device group for the site.
2. Download that group's `MeshAgent64.exe` and `MeshAgent.msh` into this folder.
3. Copy `pao-remote.example.json` to `pao-remote.json`; fill in the site label,
   group, `szerverUrl`, `agentWss` (must match the `MeshServer=` line in the
   `.msh`), the two file hashes (`agentExeSha256`, `mshSha256`) and the server
   certificate fingerprint (`szerverCertSha256`).
4. Copy the **whole folder** to the target machine — to a local disk, not a
   mapped network drive. An elevated session does not see mapped drives by
   default; the `.bat` detects this and says so, but copying is simpler.
5. Right-click `Run-Setup.bat` → *Run as administrator*.

Log: `C:\ProgramData\PAO-Tavoli-Support\Setup-PaoRemote.log`

---

## How this was built, and what that means

The code was written by an AI coding agent (Claude). I specified the behaviour,
decided the trust model (outbound-only, pinned certificate, per-site groups,
disclosure over stealth), found the failure modes on real machines, and
I operate it.

What a generated script does not give you is the list of things that actually
broke on someone else's Windows box, and the tests written afterwards so they
cannot break again. That list is what the 24 assertions are.

The script, the notice left on the machine and the inline comments are in
Hungarian — that is the language of the people whose machines it onboards. The behaviour is
fully described above.

## License

This project is available under the **PolyForm Noncommercial License 1.0.0**
(see [LICENSE](LICENSE)). You may use, modify and share it free of charge,
without asking, **for any noncommercial purpose** — including personal and family
use, charitable organisations, educational institutions, publicly funded research
bodies, public health and public safety organisations, and government
institutions. Under the licence this holds regardless of how those organisations
are funded.

**Commercial use requires a separate licence from me.** That includes offering
the software, or a service built on it, for money — as a subscription, or bundled
with installation or a support desk. Open an issue at <https://github.com/bozobernat/windows-remote-onboarding/issues> titled
"commercial licence". I am not against it; I want to know about it.

```
Required Notice: Copyright Bozó Bernát — https://github.com/bozobernat/windows-remote-onboarding
```

*(Under the licence's "Notices" section, anyone who passes the software on must
keep this line.)* How the human and the machine contributions are separated:
[AUTHORSHIP.md](AUTHORSHIP.md).

### Contributing

Fixes are welcome. Before a pull request can be merged you need to sign
[CLA.md](CLA.md) — a short statement that I may also use your contribution,
including under commercial licences. Without it, your contribution would tie the
project's hands later.

### Trademarks

This project is not affiliated with, endorsed by, or sponsored by Microsoft, the MeshCentral project, or any other third party whose products it interoperates with. All trademarks are the property of their respective owners.
