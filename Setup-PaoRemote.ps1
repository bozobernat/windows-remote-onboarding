# Copyright 2026 Bozo Bernat
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Required Notice: Copyright Bozo Bernat - https://github.com/bozobernat/windows-remote-onboarding
<#
PAO - Setup-PaoRemote: egy futtatasbol tavfelugyelet ala vonja ezt a Windows gepet.

MIRE VALO
  Kulso (nem a mi halozatunkon levo) gepet von be a PAO tavtamogatasba. A gepen
  egy MeshAgent szolgaltatas indul, ami KIFELE kapcsolodik a PAO szerverehez -
  ezert NEM kell portot nyitni a routeren, es nem kell fix IP.

MIERT KIFELE KAPCSOLODIK
  Sajat halozaton bejovo SSH-t is lehet epiteni: a gep var, mi csatlakozunk.
  Idegen gepen az nem jarhato ut, mert a NAT moge nem lehet bekopogni. Ezert
  kezdemenyez itt a gep kifele.

ONHORDO CSOMAG
  Nem tolt le semmit. Az ugynok binarisa (MeshAgent64.exe) es a beallitofajl
  (MeshAgent.msh) a script MELLETT van, es a script SHA256-tal ellenorzi
  mindkettot a pao-remote.json-bol, MIELOTT barmit futtatna.

HASZNALAT
  Jobbklikk a Run-Setup.bat-ra -> "Futtatas rendszergazdakent".

  Run-Setup.bat        -> telepites (megerositest ker)
  Diagnose-Setup.bat   -> csak vizsgal, semmit nem valtoztat
  Eltavolitas.bat      -> mindent eltavolit a geprol

KAPCSOLOK
  -Yes              a megerosito kerdes atugrasa (sajat gepen, kotegelt futtatashoz)
  -WithRdpAccount   helyi tamogatoi fiok letrehozasa (RDP-vel menedzselt gephez)
  -Diagnose         csak vizsgalat
  -Repair           a tipikus elromlasok javitasa (fokent a MeshServer-cim)
  -Uninstall        teljes eltavolitas
  -SkipSelfTest     az onteszt kihagyasa (nem ajanlott)

NAPLO
  C:\ProgramData\PAO-Tavoli-Support\Setup-PaoRemote.log
#>

[CmdletBinding()]
param(
    [switch] $Yes,
    [switch] $WithRdpAccount,
    [switch] $Diagnose,
    [switch] $Repair,
    [switch] $Uninstall,
    [switch] $SkipSelfTest
)

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$StateDir   = Join-Path $env:ProgramData 'PAO-Tavoli-Support'
$LogFile    = Join-Path $StateDir 'Setup-PaoRemote.log'
$AgentDir   = Join-Path $env:ProgramFiles 'Mesh Agent'
$AgentMsh   = Join-Path $AgentDir 'MeshAgent.msh'
$ServiceName = 'Mesh Agent'
$RdpAccount  = 'pao-tamogatas'
$RdpMarker   = Join-Path $StateDir 'rdp-fiok-letrehozva.marker'

# ---------------------------------------------------------------------------
# Kiiras
# ---------------------------------------------------------------------------
function Write-Log {
    param([string] $Text)
    try {
        if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
        Add-Content -Path $LogFile -Value ("{0}  {1}" -f (Get-Date).ToString('s'), $Text) -Encoding UTF8
    } catch { }
}
function Write-Step { param([string] $Text) Write-Host ''; Write-Host $Text -ForegroundColor Cyan; Write-Log "STEP $Text" }
function Write-Ok   { param([string] $Text) Write-Host "  [OK] $Text"   -ForegroundColor Green;  Write-Log "OK   $Text" }
function Write-Bad  { param([string] $Text) Write-Host "  [HIBA] $Text" -ForegroundColor Red;    Write-Log "HIBA $Text" }
function Write-Warn { param([string] $Text) Write-Host "  [FIGYELEM] $Text" -ForegroundColor Yellow; Write-Log "WARN $Text" }
function Write-Info { param([string] $Text) Write-Host "  $Text";                                Write-Log "info $Text" }

# ---------------------------------------------------------------------------
# Alapellenorzesek
# ---------------------------------------------------------------------------
function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Bad 'Ez a script rendszergazda jogot igenyel.'
        Write-Info 'Jobbklikk a Run-Setup.bat-ra -> "Futtatas rendszergazdakent".'
        exit 1
    }
}

function Get-PaoConfig {
    $p = Join-Path $ScriptDir 'pao-remote.json'
    if (-not (Test-Path $p)) { Write-Bad "Nincs meg a konfiguracio: $p"; exit 1 }
    try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { Write-Bad "A pao-remote.json nem olvashato: $($_.Exception.Message)"; exit 1 }
}

function Get-Sha256 {
    param([string] $Path)
    if (-not (Test-Path $Path)) { return $null }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

# A csomag epsegenek ellenorzese. Ez az egyetlen ok, amiert nem toltunk le semmit:
# igy a futtatott binaris pontosan az, amit becsomagoltunk.
function Test-PackageIntegrity {
    param($Cfg)
    $ok = $true
    $exe = Join-Path $ScriptDir 'MeshAgent64.exe'
    $msh = Join-Path $ScriptDir 'MeshAgent.msh'
    foreach ($item in @(
        @{ Nev = 'MeshAgent64.exe'; Ut = $exe; Vart = $Cfg.agentExeSha256 },
        @{ Nev = 'MeshAgent.msh';   Ut = $msh; Vart = $Cfg.mshSha256 })) {
        if (-not (Test-Path $item.Ut)) { Write-Bad "Hianyzik a csomagbol: $($item.Nev)"; $ok = $false; continue }
        $h = Get-Sha256 $item.Ut
        if ($h -ne $item.Vart.ToLower()) {
            Write-Bad "$($item.Nev): a SHA256 NEM egyezik - a csomag serult vagy modositott."
            Write-Info "  vart : $($item.Vart)"
            Write-Info "  kapott: $h"
            $ok = $false
        } else { Write-Ok "$($item.Nev) ellenorizve (SHA256 egyezik)" }
    }
    return $ok
}

function Get-ServerHostPort {
    param($Cfg)
    $u = [Uri] $Cfg.szerverUrl
    $port = $u.Port
    if ($port -le 0) { $port = 443 }
    return @{ Host = $u.Host; Port = $port }
}

function Test-ServerReachable {
    param($Cfg, [int] $TimeoutMs = 6000)
    $hp = Get-ServerHostPort $Cfg
    $c = New-Object Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect($hp.Host, $hp.Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $c.EndConnect($iar)
        return $c.Connected
    } catch { return $false } finally { $c.Close() }
}

# A szerver tanusitvanyanak ujjlenyomat-ellenorzese. Onalairt tanusitvanyt is
# biztonsagosan kezel: nem "elfogadunk mindent", hanem PONTOSAN azt az egyet,
# amit a csomagba beleirtunk.
function Test-ServerCertPin {
    param($Cfg)
    if (-not $Cfg.szerverCertSha256) { return $null }
    $hp = Get-ServerHostPort $Cfg
    $client = $null; $ssl = $null
    try {
        $client = New-Object Net.Sockets.TcpClient($hp.Host, $hp.Port)
        $seen = $null
        $cb = [Net.Security.RemoteCertificateValidationCallback] {
            param($sender, $cert, $chain, $errors)
            $script:SeenCertHash = [BitConverter]::ToString(
                [Security.Cryptography.SHA256]::Create().ComputeHash($cert.GetRawCertData())).Replace('-','').ToLower()
            return $true
        }
        $ssl = New-Object Net.Security.SslStream($client.GetStream(), $false, $cb)
        $ssl.AuthenticateAsClient($hp.Host)
        $seen = $script:SeenCertHash
        return @{ Vart = $Cfg.szerverCertSha256.ToLower(); Kapott = $seen; Egyezik = ($seen -eq $Cfg.szerverCertSha256.ToLower()) }
    } catch {
        return @{ Vart = $Cfg.szerverCertSha256.ToLower(); Kapott = $null; Egyezik = $false; Hiba = $_.Exception.Message }
    } finally {
        if ($ssl) { $ssl.Dispose() }
        if ($client) { $client.Close() }
    }
}

# ---------------------------------------------------------------------------
# Tajekoztatas es megerosites - idegen gepen ez nem formalitas
# ---------------------------------------------------------------------------
function Show-ConsentAndConfirm {
    param($Cfg)
    Write-Host ''
    Write-Host '===========================================================' -ForegroundColor White
    Write-Host ' PAO tavtamogatas - bevonas' -ForegroundColor White
    Write-Host '===========================================================' -ForegroundColor White
    Write-Host ''
    Write-Host "  Gep:      $env:COMPUTERNAME"
    Write-Host "  Helyszin: $($Cfg.helyszin)"
    Write-Host "  Szerver:  $($Cfg.szerverUrl)"
    Write-Host ''
    Write-Host '  Ez a telepites a kovetkezot teszi:'
    Write-Host '    - Felrak egy szolgaltatast (Mesh Agent), ami KIFELE kapcsolodik'
    Write-Host '      a fenti szerverhez. Bejovo portot NEM nyit a routeren.'
    Write-Host '    - Ezzel a tamogato tavolrol tud parancsot futtatni, fajlt masolni,'
    Write-Host '      es - ha kell - a kepernyot latni es az egeret/billentyuzetet hasznalni.'
    Write-Host '    - A gepen lathato jelzes lesz arrol, ha valaki csatlakozik.'
    Write-Host '    - Barmikor eltavolithato: Eltavolitas parancsikon az asztalon.'
    Write-Host ''
    if ($WithRdpAccount) {
        Write-Host "    - PLUSZ: letrehoz egy helyi tamogatoi fiokot ($RdpAccount) az" -ForegroundColor Yellow
        Write-Host '      RDP-alapu tavoli asztalhoz. Ez rendszergazda jogu fiok.' -ForegroundColor Yellow
        Write-Host ''
    }
    if ($Yes) { Write-Info 'A megerosites atugorva (-Yes).'; return $true }
    Write-Host '  Ha ezt jovahagyod, gepeld be: IGEN' -ForegroundColor White
    $ans = Read-Host '  Valasz'
    if ($ans.Trim().ToUpper() -ne 'IGEN') {
        Write-Bad 'Megszakitva - nem tortent valtozas a gepen.'
        return $false
    }
    Write-Log "CONSENT megadva: $env:USERNAME / $env:COMPUTERNAME"
    return $true
}

# ---------------------------------------------------------------------------
# Telepites
# ---------------------------------------------------------------------------
function Install-Agent {
    param($Cfg)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Info 'A Mesh Agent szolgaltatas mar letezik - nem telepitem ujra, csak a beallitast frissitem.'
    } else {
        $exe = Join-Path $ScriptDir 'MeshAgent64.exe'
        Write-Info 'Telepites...'
        $p = Start-Process -FilePath $exe -ArgumentList '-fullinstall' -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) { Write-Bad "A telepito nem nullaval tert vissza (exit $($p.ExitCode))."; return $false }
        Start-Sleep -Seconds 6
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $svc) { Write-Bad 'A telepites utan sincs Mesh Agent szolgaltatas.'; return $false }
        Write-Ok 'Mesh Agent szolgaltatas telepitve.'
    }
    return $true
}

# A telepito NEM viszi at a .msh-t (a binarist MeshAgent.exe-re nevezi at, a
# beallitofajl neve nem koveti) - ez elesben ket gepen is elbukott, ezert
# kezzel masoljuk be a helyes nevvel.
function Set-AgentSettings {
    param($Cfg)
    if (-not (Test-Path $AgentDir)) { Write-Bad "Nincs meg a telepitesi mappa: $AgentDir"; return $false }
    Copy-Item (Join-Path $ScriptDir 'MeshAgent.msh') $AgentMsh -Force
    $h = Get-Sha256 $AgentMsh
    if ($h -ne $Cfg.mshSha256.ToLower()) { Write-Bad 'A bemasolt .msh hash-e nem egyezik.'; return $false }
    $line = (Get-Content $AgentMsh) | Where-Object { $_ -like 'MeshServer=*' } | Select-Object -First 1
    if (-not $line -or $line -match '^MeshServer=local\s*$') {
        Write-Bad 'A .msh-ban nincs explicit MeshServer cim (vagy "local" all benne).'
        return $false
    }
    Write-Ok "Beallitas bemasolva. $line"
    return $true
}

function Restart-Agent {
    try {
        Restart-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 8
        Write-Ok 'Szolgaltatas ujrainditva.'
        return $true
    } catch { Write-Bad "A szolgaltatas ujrainditasa nem sikerult: $($_.Exception.Message)"; return $false }
}

# ---------------------------------------------------------------------------
# Onteszt - a filozofia:
# nem eleg "KESZ"-t irni, bizonyitani kell, hogy a csatorna tenylegesen all.
# ---------------------------------------------------------------------------
function Invoke-SelfTest {
    param($Cfg, [int] $MaxSeconds = 90)
    $hp = Get-ServerHostPort $Cfg
    $ip = $null
    try { $ip = ([Net.Dns]::GetHostAddresses($hp.Host) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString } catch { }
    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    while ((Get-Date) -lt $deadline) {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            $conns = @()
            try {
                $conns = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
                           Where-Object { $_.RemotePort -eq $hp.Port -and ($_.RemoteAddress -eq $ip -or $_.RemoteAddress -eq $hp.Host) })
            } catch { }
            if ($conns.Count -gt 0) {
                Write-Ok "A csatorna all: felepult kapcsolat a szerver fele ($($hp.Host):$($hp.Port))."
                return $true
            }
        }
        Start-Sleep -Seconds 5
    }
    Write-Bad "Az onteszt nem latott felepult kapcsolatot $MaxSeconds masodpercen belul."
    Write-Info 'Futtasd a Diagnose-Setup.bat-ot - az megmondja, hol akad el.'
    return $false
}

# ---------------------------------------------------------------------------
# Tamogatoi fiok (opcionalis) - RDP-vel menedzselt gephez
# ---------------------------------------------------------------------------
function New-RdpSupportAccount {
    $u = Get-LocalUser -Name $RdpAccount -ErrorAction SilentlyContinue
    if ($u) { Write-Info "A(z) $RdpAccount fiok mar letezik - nem nyulok hozza."; return $true }
    $b = New-Object byte[] 18
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    $pw = ([Convert]::ToBase64String($b)) -replace '[+/=]', 'x'
    $sec = ConvertTo-SecureString $pw -AsPlainText -Force
    New-LocalUser -Name $RdpAccount -Password $sec -FullName 'PAO tavtamogatas' `
                  -Description 'PAO tavtamogatoi fiok - az Eltavolitas torli' -PasswordNeverExpires | Out-Null
    # Magyar Windowson a csoportnevek lokalizaltak - SID-del hivatkozunk rajuk.
    # (Mert kiderult: Add-LocalGroupMember nevvel es SID-STRINGGEL sem
    #  mindig oldodik fel, ezert a csoport-OBJEKTUMOT keressuk meg SID alapjan.)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-32-555')) {   # Administrators, Remote Desktop Users
        try {
            $g = Get-LocalGroup -SID $sid -ErrorAction Stop
            Add-LocalGroupMember -Group $g -Member $RdpAccount -ErrorAction Stop
            Write-Ok "Hozzaadva a(z) '$($g.Name)' csoporthoz."
        } catch {
            if ($_.Exception.Message -notmatch 'mar tagja|already a member') {
                Write-Warn "Nem sikerult a(z) $sid csoporthoz adni: $($_.Exception.Message)"
            }
        }
    }
    # A jelszo a GEPEN marad, fajlban - nem kerul at a halozaton es nem irjuk ki.
    $pwFile = Join-Path $StateDir 'tamogatoi-fiok.jelszo'
    Set-Content -Path $pwFile -Value $pw -NoNewline -Encoding ASCII
    $acl = Get-Acl $pwFile
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-18')) {
        $r = New-Object Security.AccessControl.FileSystemAccessRule(
                 (New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'Allow')
        $acl.AddAccessRule($r)
    }
    Set-Acl -Path $pwFile -AclObject $acl
    Set-Content -Path $RdpMarker -Value (Get-Date).ToString('s') -Encoding ASCII
    Write-Ok "Tamogatoi fiok letrehozva. A jelszo itt van a gepen: $pwFile"
    Write-Info 'A jelszo nem hagyta el a gepet. Aki tavolrol dolgozik, ebbol olvassa ki.'
    return $true
}

# ---------------------------------------------------------------------------
# A gepre kiirt tajekoztato es az eltavolito
# ---------------------------------------------------------------------------
function Install-NoticeDocs {
    param($Cfg)
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
    foreach ($f in @('Setup-PaoRemote.ps1', 'pao-remote.json', 'MeshAgent.msh', 'MeshAgent64.exe',
                     'TAJEKOZTATO.txt', 'Eltavolitas.bat', 'Diagnose-Setup.bat', 'Repair-Setup.bat')) {
        $src = Join-Path $ScriptDir $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $StateDir $f) -Force }
    }
    Write-Ok "A csomag helyben is elerheto: $StateDir"

    # Asztali parancsikon az ELTAVOLITASHOZ - ez a lathato visszavonhatosag.
    try {
        $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
        $lnkPath = Join-Path $desktop 'PAO tavtamogatas - Eltavolitas.lnk'
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($lnkPath)
        $lnk.TargetPath       = Join-Path $StateDir 'Eltavolitas.bat'
        $lnk.WorkingDirectory = $StateDir
        $lnk.IconLocation     = "$env:SystemRoot\System32\shell32.dll,131"
        $lnk.Description      = 'A PAO tavtamogatas teljes eltavolitasa errol a geprol'
        $lnk.Save()
        Write-Ok 'Asztali parancsikon letrehozva az eltavolitashoz.'
    } catch { Write-Warn "A parancsikon letrehozasa nem sikerult: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------------------
# Diagnosztika - semmit nem valtoztat
# ---------------------------------------------------------------------------
function Invoke-PaoDiagnose {
    param($Cfg)
    Write-Step '1. Csomag'
    [void] (Test-PackageIntegrity $Cfg)

    Write-Step '2. Szerver elerheto-e'
    $hp = Get-ServerHostPort $Cfg
    if (Test-ServerReachable $Cfg) { Write-Ok "TCP kapcsolat felepult: $($hp.Host):$($hp.Port)" }
    else {
        Write-Bad "Nem erem el: $($hp.Host):$($hp.Port)"
        Write-Info 'Ez a leggyakoribb ok: a szerver nem erheto el kivulrol, vagy a gep tuzfala/proxyja blokkol.'
    }

    Write-Step '3. Szerver-tanusitvany (ujjlenyomat-ellenorzes)'
    $pin = Test-ServerCertPin $Cfg
    if ($null -eq $pin) { Write-Info 'Nincs ujjlenyomat a konfigban - kihagyva.' }
    elseif ($pin.Egyezik) { Write-Ok 'A szerver tanusitvanya egyezik a csomagban rogzitettel.' }
    else {
        Write-Bad 'A tanusitvany NEM egyezik a vart ujjlenyomattal!'
        Write-Info "  vart  : $($pin.Vart)"
        Write-Info "  kapott: $(if ($pin.Kapott) { $pin.Kapott } else { '(nem sikerult lekerni) ' + $pin.Hiba })"
        Write-Info 'Ez lehet szerver-csere is, de lehet kozbeekelodes. Ne folytasd, amig nem tisztazott.'
    }

    Write-Step '4. Ugynok allapota'
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Bad 'Nincs Mesh Agent szolgaltatas - a gep nincs bevonva.' }
    else {
        Write-Ok "Szolgaltatas: $($svc.Status), inditas: $($svc.StartType)"
        if (Test-Path $AgentMsh) {
            $line = (Get-Content $AgentMsh) | Where-Object { $_ -like 'MeshServer=*' } | Select-Object -First 1
            if ($line -match '^MeshServer=local\s*$') {
                Write-Bad 'A .msh-ban "MeshServer=local" all - az ugynok multicast-felderitest varna, ami NAT-on at nem mukodik.'
                Write-Info 'Javitas: Repair uzemmod (Setup-PaoRemote.ps1 -Repair).'
            } else { Write-Ok $line }
        } else { Write-Bad "Nincs .msh a telepitesi mappaban: $AgentMsh  -> Repair" }
    }

    Write-Step '5. Van-e elo kapcsolat a szerver fele'
    $ip = $null
    try { $ip = ([Net.Dns]::GetHostAddresses($hp.Host) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString } catch { }
    $conns = @()
    try { $conns = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
                     Where-Object { $_.RemotePort -eq $hp.Port -and ($_.RemoteAddress -eq $ip -or $_.RemoteAddress -eq $hp.Host) }) } catch { }
    if ($conns.Count -gt 0) { Write-Ok "Van felepult kapcsolat ($($conns.Count) db)." }
    else { Write-Bad 'Nincs felepult kapcsolat a szerver fele.' }

    Write-Step '6. Asztali utak ezen a gepen'
    $sessions = (query session 2>$null) -join "`n"
    $rdpActive = $sessions -match 'rdp-tcp#\d+\s+\S+\s+\d+\s+Active'
    if ($rdpActive) {
        Write-Warn 'Aktiv RDP-munkamenet van a gepen.'
        Write-Info 'Ilyenkor az ugynok KVM-je (konzol-kep) NEM mutatja ezt a munkamenetet - ez a MeshCentral'
        Write-Info 'ismert korlatja, nem hiba. Ilyen gepen a webes RDP-ut vagy az Assistant hasznalando.'
    } else { Write-Ok 'Nincs aktiv RDP-munkamenet - az ugynok KVM-je a konzolt mutatja.' }
    $deny = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -ErrorAction SilentlyContinue).fDenyTSConnections
    if ($deny -eq 0) { Write-Ok 'Az RDP engedelyezve van a gepen (a webes RDP-ut jarhato).' }
    else { Write-Info 'Az RDP tiltva van a gepen - csak a KVM/Assistant ut jarhato.' }
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Javitas - a tipikus, kivulrol okozott elromlasok
# ---------------------------------------------------------------------------
function Invoke-PaoRepair {
    param($Cfg)
    Write-Step 'Javitas'
    if (-not (Test-PackageIntegrity $Cfg)) { Write-Bad 'A csomag serult - javitas elmarad.'; return $false }
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Bad 'Nincs telepitve az ugynok - ez nem javitas, hanem telepites. Futtasd a Run-Setup.bat-ot.'; return $false }
    if (-not (Set-AgentSettings $Cfg)) { return $false }
    if (-not (Restart-Agent)) { return $false }
    if ($SkipSelfTest) { return $true }
    return (Invoke-SelfTest $Cfg)
}

# ---------------------------------------------------------------------------
# Eltavolitas
# ---------------------------------------------------------------------------

# Az eltavolitas utan a mappaban CSAK a naplo maradhat. Ez elesben elbukott:
# a MeshAgent.msh (a csoport BELEPTETESI TITKA), a pao-remote.json, a binaris
# es -WithRdpAccount eseten a jelszofajl ott maradt, mikozben a script azt irta
# ki, hogy a gepen nem maradt tavtamogatas. Amit a gep tulajdonosanak igerunk,
# azt meg is kell tenni - kulonben az igeret a rosszabb, nem a maradek fajl.
$KeepOnUninstall = @('Setup-PaoRemote.log')

function Remove-StateDirContent {
    # Kitorli a $StateDir teljes tartalmat a naplo kivetelevel. Visszaadja
    # azoknak a fajloknak a listajat, amiket NEM sikerult torolni - jellemzoen
    # a most futo Eltavolitas.bat es maga ez a script, mert azok ebbol a
    # mappabol futnak, es a Windows a futo fajlt nem engedi torolni.
    $stuck = @()
    if (-not (Test-Path $StateDir)) { return $stuck }
    foreach ($item in @(Get-ChildItem -LiteralPath $StateDir -Force)) {
        if ($KeepOnUninstall -contains $item.Name) { continue }
        try { Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction Stop }
        catch { $stuck += $item.FullName }
    }
    return $stuck
}

function Start-DeferredCleanup {
    # Az utolso ket fajlt (a futo .bat es .ps1) egy kulon folyamat takaritja el -
    # az mar nem ebbol a mappabol fut, ezert torolni tudja oket. Halasztott
    # torles nelkul a felhasznalonak kellene kezzel utana nyulnia, amit nem fog
    # megtenni.
    #   MIERT CIKLUS, ES NEM EGY VARAKOZAS: az Eltavolitas.bat a futtatas vegen
    #   'pause'-nal all, es amig a felhasznalo le nem uti, a cmd fogva tartja a
    #   .bat fajlt. Nem tudjuk, ez meddig tart, ezert nem varunk fix ideig, hanem
    #   ismetelten probalkozunk. A del a mar letorolt fajlra csendben elszall.
    param([string[]] $Paths)
    if (-not $Paths -or $Paths.Count -eq 0) { return $true }
    $q = ($Paths | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $inner = 'for /l %i in (1,1,60) do @(ping -n 3 127.0.0.1 >nul & del /f /q ' + $q + ' >nul 2>&1)'
    try {
        # A '/c' es a parancs KULON argumentum. Egyetlen sztringkent atadva a
        # Windowson elhasal ('" was unexpected at this time'), mert a PowerShell
        # a szokoz miatt az egeszet - a /c-t is - idezojelbe teszi. Elesben merve.
        Start-Process -FilePath $env:ComSpec -ArgumentList '/c', $inner -WindowStyle Hidden | Out-Null
        return $true
    } catch { return $false }
}

function Remove-SupportAccount {
    # A fiok SID-jet a torles ELOTT kell kiolvasni, mert a profil-mappat csak
    # SID alapjan szabad azonositani - nev alapjan mas fiok profiljara futnank.
    $sid = $null
    try { $sid = (Get-LocalUser -Name $RdpAccount -ErrorAction Stop).SID.Value } catch { }
    try {
        Remove-LocalUser -Name $RdpAccount -ErrorAction Stop
        Write-Ok "A tamogatoi fiok ($RdpAccount) torolve."
    } catch { Write-Warn "A tamogatoi fiok torlese nem sikerult: $($_.Exception.Message)"; return }
    if (-not $sid) { return }
    try {
        $prof = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'" -ErrorAction Stop
        if ($prof) {
            Remove-CimInstance -InputObject $prof -ErrorAction Stop
            Write-Ok 'A fiokhoz tartozo profil-mappa is torolve.'
        }
    } catch { Write-Warn "A fiok profil-mappaja a gepen maradt: $($_.Exception.Message)" }
}

function Invoke-PaoUninstall {
    Write-Step 'Eltavolitas'
    $exe = Join-Path $AgentDir 'MeshAgent.exe'
    if (Test-Path $exe) {
        try {
            $p = Start-Process -FilePath $exe -ArgumentList '-fulluninstall' -Wait -PassThru -NoNewWindow
            Write-Ok "Ugynok eltavolitva (exit $($p.ExitCode))."
        } catch { Write-Warn "Az ugynok eltavolitasa hibara futott: $($_.Exception.Message)" }
    } else { Write-Info 'Nincs telepitett ugynok.' }

    # A telepitesi mappaban maradt beallitofajl is beleptetesi adat: ha az
    # ugynok -fulluninstall-ja barmiert nem vitte el, kezzel kell.
    if (Test-Path $AgentMsh) {
        try { Remove-Item -LiteralPath $AgentMsh -Force -ErrorAction Stop; Write-Ok 'A telepitesi mappaban maradt .msh torolve.' }
        catch { Write-Warn "A telepitesi mappaban maradt .msh-t nem sikerult torolni: $AgentMsh" }
    }

    if (Test-Path $RdpMarker) { Remove-SupportAccount }

    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'PAO tavtamogatas - Eltavolitas.lnk'
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
    } catch { }

    $stuck = @(Remove-StateDirContent)
    $deferred = Start-DeferredCleanup $stuck

    Write-Host ''
    if ($deferred) {
        Write-Ok 'Kesz. A gepen nem maradt PAO-tavtamogatas: a szolgaltatas, a beleptetesi fajl, a beallitas es a jelszofajl is torolve.'
        if ($stuck.Count -gt 0) {
            Write-Info 'Az eltavolito sajat fajljai par masodperc mulva tunnek el - azokat egy'
            Write-Info 'kulon folyamat takaritja el, mert most meg futnak.'
        }
    } else {
        Write-Warn 'Ezeket nem sikerult torolni, es a halasztott torlest sem tudtam elinditani:'
        foreach ($p in $stuck) { Write-Info "  $p" }
        Write-Info 'Ezeket kezzel kell torolni - amig ott vannak, a beleptetesi adat is a gepen van.'
    }
    Write-Info "A naplo szandekosan megmarad, hogy legyen nyoma, mi tortent: $LogFile"
    Write-Info 'Jelszot es beleptetesi titkot nem tartalmaz. Ha ez sem kell, a mappa torolheto.'
}

# ---------------------------------------------------------------------------
# Fo ag
# ---------------------------------------------------------------------------
Assert-Admin
$Cfg = Get-PaoConfig

Write-Host ''
Write-Host "PAO Setup-PaoRemote  -  $env:COMPUTERNAME  -  $((Get-Date).ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor White
Write-Log "=== inditas (Diagnose=$Diagnose Repair=$Repair Uninstall=$Uninstall Yes=$Yes WithRdpAccount=$WithRdpAccount) ==="

if ($Uninstall) { Invoke-PaoUninstall; exit 0 }
if ($Diagnose)  { Invoke-PaoDiagnose $Cfg; exit 0 }
if ($Repair)    { if (Invoke-PaoRepair $Cfg) { exit 0 } else { exit 1 } }

# --- telepites ---
Write-Step '1. Csomag ellenorzese'
if (-not (Test-PackageIntegrity $Cfg)) { Write-Bad 'A csomag nem ep - nem telepitek.'; exit 1 }

Write-Step '2. Szerver elerhetosege'
$hp = Get-ServerHostPort $Cfg
if (-not (Test-ServerReachable $Cfg)) {
    Write-Bad "A szerver nem erheto el: $($hp.Host):$($hp.Port)"
    Write-Info 'Enelkul a bevonasnak nincs ertelme - az ugynok nem tudna hova kapcsolodni.'
    Write-Info 'Ellenorizd az internetkapcsolatot, illetve hogy a szerver kivulrol elerheto-e.'
    exit 1
}
Write-Ok "A szerver elerheto: $($hp.Host):$($hp.Port)"

$pin = Test-ServerCertPin $Cfg
if ($null -ne $pin -and -not $pin.Egyezik) {
    Write-Bad 'A szerver tanusitvanya NEM egyezik a csomagban rogzitett ujjlenyomattal.'
    Write-Info 'Ez lehet szerver-csere, de lehet kozbeekelodes is. Nem telepitek.'
    Write-Info 'Ha a szerver tenyleg cserelt tanusitvanyt, uj csomag kell.'
    exit 1
}
if ($null -ne $pin) { Write-Ok 'A szerver tanusitvanya egyezik a vart ujjlenyomattal.' }

Write-Step '3. Tajekoztatas es jovahagyas'
if (-not (Show-ConsentAndConfirm $Cfg)) { exit 2 }

Write-Step '4. Ugynok telepitese'
if (-not (Install-Agent $Cfg)) { exit 1 }

Write-Step '5. Beallitas (a szerver cimenek rogzitese)'
if (-not (Set-AgentSettings $Cfg)) { exit 1 }
if (-not (Restart-Agent)) { exit 1 }

if ($WithRdpAccount) {
    Write-Step '6. Tamogatoi fiok'
    [void] (New-RdpSupportAccount)
}

Write-Step '7. Dokumentumok es eltavolito'
Install-NoticeDocs $Cfg

if (-not $SkipSelfTest) {
    Write-Step '8. Onteszt - a csatorna tenyleges kiprobalasa'
    if (-not (Invoke-SelfTest $Cfg)) {
        Write-Host ''
        Write-Bad 'A telepites megtortent, de a csatorna nem all. NE tekintsd kesznek.'
        exit 1
    }
}

Write-Host ''
Write-Host '===========================================================' -ForegroundColor Green
Write-Ok  "KESZ - a(z) $env:COMPUTERNAME gep bevonva."
Write-Info "Helyszin: $($Cfg.helyszin)"
Write-Info "Csoport: $($Cfg.csoport)"
Write-Info "Tajekoztato es eltavolito: $StateDir"
Write-Host '===========================================================' -ForegroundColor Green
Write-Log '=== kesz ==='
exit 0
