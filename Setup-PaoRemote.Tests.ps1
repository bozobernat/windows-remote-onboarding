# Copyright 2026 Bozo Bernat
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Required Notice: Copyright Bozo Bernat - https://github.com/bozobernat/windows-remote-onboarding
<#
Setup-PaoRemote.ps1 - onteszt. Fuggosegmentes: nem kell Pester.

MIERT VAN EZ A FAJL
  A tanulsag: a bevono script akkor
  is irhat "KESZ"-t, ha valojaban nem all a csatorna, es a statikus atolvasas
  nem konvergal. Ez a fajl azt ellenorzi, amit gep-modositas NELKUL is el lehet
  donteni - es minden eddig valoban elkovetett hibaosztalyra van benne teszt.

FUTTATAS (a csomag mappajabol)
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Setup-PaoRemote.Tests.ps1
  vagy PowerShell 7 alatt (Linuxon is):
    pwsh -NoProfile -File ./Setup-PaoRemote.Tests.ps1

AMIT NEM TUD TESZTELNI
  A tenyleges telepitest (szolgaltatas, fiok, parancsikon). Arra a scriptbe
  epitett ONTESZT valo (Invoke-SelfTest), ami a celgepen elesben nezi meg, hogy
  all-e a kapcsolat - es az eles proba egy valodi gepen.
#>

$ErrorActionPreference = 'Stop'
$script:Pass = 0
$script:Fail = 0
$Here = Split-Path -Parent $MyInvocation.MyCommand.Definition

function It {
    param([string] $Name, [scriptblock] $Body)
    try {
        & $Body
        $script:Pass++
        Write-Host ("  [OK]   " + $Name) -ForegroundColor Green
    } catch {
        $script:Fail++
        Write-Host ("  [BUKO] " + $Name) -ForegroundColor Red
        Write-Host ("         " + $_.Exception.Message) -ForegroundColor DarkRed
    }
}
function Section { param([string] $Name) Write-Host ''; Write-Host $Name -ForegroundColor Cyan }
function Assert-True  { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ("$Expected" -ne "$Actual") { throw ("$Message  (vart: '$Expected', kapott: '$Actual')") }
}
function Assert-Match {
    param([string] $Pattern, [string] $Text, [string] $Message)
    if ($Text -notmatch $Pattern) { throw ("$Message  (a minta nem talalt: '$Pattern')") }
}

$Ps1     = Join-Path $Here 'Setup-PaoRemote.ps1'
$CfgPath = Join-Path $Here 'pao-remote.json'
$MshPath = Join-Path $Here 'MeshAgent.msh'
$Cfg     = $null
if (Test-Path $CfgPath) { $Cfg = Get-Content $CfgPath -Raw | ConvertFrom-Json }

Write-Host ''
Write-Host 'Setup-PaoRemote - onteszt' -ForegroundColor White

# ---------------------------------------------------------------------------
Section '1. A csomag teljes-e'

It 'megvan minden fajl' {
    foreach ($f in @('Setup-PaoRemote.ps1','pao-remote.json','MeshAgent64.exe','MeshAgent.msh',
                     'Run-Setup.bat','Diagnose-Setup.bat','Repair-Setup.bat','Eltavolitas.bat',
                     'TAJEKOZTATO.txt')) {
        Assert-True (Test-Path (Join-Path $Here $f)) "hianyzik: $f"
    }
}

It 'a pao-remote.json ervenyes es megvannak a kotelezo mezoi' {
    Assert-True ($null -ne $Cfg) 'a pao-remote.json nem olvashato'
    foreach ($m in @('helyszin','csoport','szerverUrl','agentWss','szerverCertSha256','agentExeSha256','mshSha256')) {
        Assert-True ($Cfg.PSObject.Properties.Name -contains $m) "hianyzo mezo: $m"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $Cfg.$m)) "ures mezo: $m"
    }
}

It 'a konfigban rogzitett hashek egyeznek a tenyleges fajlokkal' {
    Assert-True ($null -ne $Cfg) 'a pao-remote.json nem olvashato'
    Assert-Equal $Cfg.agentExeSha256.ToLower() `
                 (Get-FileHash (Join-Path $Here 'MeshAgent64.exe') -Algorithm SHA256).Hash.ToLower() `
                 'az agent binaris hash-e nem egyezik'
    Assert-Equal $Cfg.mshSha256.ToLower() `
                 (Get-FileHash (Join-Path $Here 'MeshAgent.msh') -Algorithm SHA256).Hash.ToLower() `
                 'a .msh hash-e nem egyezik'
}

It 'a cert-ujjlenyomat 64 hexa karakter' {
    Assert-Match '^[0-9a-fA-F]{64}$' $Cfg.szerverCertSha256 'rossz alaku cert-ujjlenyomat'
}

It 'a szerverUrl es az agentWss ugyanarra a gepre mutat' {
    $a = ([Uri] $Cfg.szerverUrl).Host
    $b = ([Uri] $Cfg.agentWss).Host
    Assert-Equal $a $b 'a szerverUrl es az agentWss mas gepre mutat'
}

# ---------------------------------------------------------------------------
Section '2. A beallitofajl (.msh)'

It 'van explicit MeshServer cim, es NEM "local"' {
    # A projekt legdragabb zsakutkaja: LANonly modban a MeshCentral "local"-t ir
    # a .msh-ba, es multicast-felderitest varna - ami NAT mogul soha nem jut at.
    Assert-True (Test-Path $MshPath) 'MeshAgent.msh nem talalhato'
    $sor = (Get-Content $MshPath) | Where-Object { $_ -like 'MeshServer=*' } | Select-Object -First 1
    Assert-True ($null -ne $sor) 'nincs MeshServer sor a .msh-ban'
    Assert-True ($sor -notmatch '^MeshServer=local\s*$') 'a .msh-ban "local" all - az ugynok nem talalna haza'
    Assert-Match '^MeshServer=wss://' $sor 'a MeshServer nem wss:// cim'
}

It 'a .msh cime ugyanaz, mint a konfig agentWss mezoje' {
    Assert-True (Test-Path $MshPath) 'MeshAgent.msh nem talalhato'
    $sor = (Get-Content $MshPath) | Where-Object { $_ -like 'MeshServer=*' } | Select-Object -First 1
    Assert-Equal ('MeshServer=' + $Cfg.agentWss) $sor.Trim() 'a .msh es a konfig kulonbozo cimet tartalmaz'
}

It 'megvannak a beleptetesi mezok' {
    Assert-True (Test-Path $MshPath) 'MeshAgent.msh nem talalhato'
    $t = Get-Content $MshPath -Raw
    foreach ($m in @('MeshName=','MeshType=','MeshID=','ServerID=')) {
        Assert-True ($t.Contains($m)) "hianyzo mezo a .msh-ban: $m"
    }
}

# ---------------------------------------------------------------------------
Section '3. A script szerkezete'

It 'szintaktikailag helyes' {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref] $null, [ref] $errs)
    Assert-Equal 0 $errs.Count ('szintaktikai hiba: ' + (($errs | Select-Object -First 3 | ForEach-Object { $_.Message }) -join ' | '))
}

It 'megvan mind a hat kapcsolo' {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref] $null, [ref] $null)
    $nevek = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    foreach ($k in @('Yes','WithRdpAccount','Diagnose','Repair','Uninstall','SkipSelfTest')) {
        Assert-True ($nevek -contains $k) "hianyzo kapcsolo: -$k"
    }
}

It 'megvannak a kulcsfontossagu fuggvenyek' {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref] $null, [ref] $null)
    $fv = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
    foreach ($n in @('Assert-Admin','Test-PackageIntegrity','Test-ServerCertPin',
                     'Show-ConsentAndConfirm','Set-AgentSettings','Invoke-SelfTest','Invoke-PaoUninstall',
                     'Remove-StateDirContent','Start-DeferredCleanup','Remove-SupportAccount')) {
        Assert-True ($fv -contains $n) "hianyzo fuggveny: $n"
    }
}

It 'tisztan ASCII - a magyar konzolon nem torhet el' {
    $t = Get-Content $Ps1 -Raw
    Assert-True ($t -notmatch '[^\x00-\x7F]') 'nem-ASCII karakter van a scriptben'
}

It 'sehol nem kapcsolja ki a tanusitvany-ellenorzest' {
    # Tudatos dontes: a csomag onhordo, nem tolt le semmit, ezert nincs szukseg
    # semmilyen "fogadj el minden tanusitvanyt" beallitasra. Ha ez bukik, valaki
    # visszacsempeszte - es azzal a bevonas kozbeekelodesre nyithatova valna.
    $t = Get-Content $Ps1 -Raw
    Assert-True ($t -notmatch 'ServerCertificateValidationCallback\s*=\s*\{') 'globalis cert-ellenorzes-kikapcsolas van a scriptben'
}

It 'nem tolt le semmit futasidoben' {
    $t = Get-Content $Ps1 -Raw
    foreach ($tiltott in @('Invoke-WebRequest','Invoke-RestMethod','Start-BitsTransfer','DownloadFile')) {
        Assert-True ($t -notmatch [regex]::Escape($tiltott)) "letoltes van a scriptben: $tiltott"
    }
}

It 'a telepites megerositest ker (nem lehet csendben bevonni egy gepet)' {
    $t = Get-Content $Ps1 -Raw
    Assert-Match 'Read-Host' $t 'nincs megerosito kerdes'
    Assert-Match 'IGEN' $t 'nincs beirando megerosito szo'
}

# ---------------------------------------------------------------------------
Section '4. Az indito .bat fajlok'

It 'mind ASCII es CRLF sorvegu' {
    foreach ($b in @('Run-Setup.bat','Diagnose-Setup.bat','Repair-Setup.bat','Eltavolitas.bat')) {
        $raw = Get-Content (Join-Path $Here $b) -Raw
        Assert-True ($raw -notmatch '[^\x00-\x7F]') "nem-ASCII karakter: $b"
        Assert-True ($raw.Contains("`r`n")) "nem CRLF sorvegu: $b"
    }
}

It 'mind szol, ha halozati meghajtorol indul emelt jogon' {
    # A "Futtatas rendszergazdakent" emelt tokenje alapbol nem latja a lekepezett
    # meghajtokat (pl. Z:) - ilyenkor a script nem talalna sajat magat.
    foreach ($b in @('Run-Setup.bat','Diagnose-Setup.bat','Repair-Setup.bat','Eltavolitas.bat')) {
        Assert-Match 'NEM TALALOM' (Get-Content (Join-Path $Here $b) -Raw) "nincs benne a vedelem: $b"
    }
}

It 'az Eltavolitas.bat megerositest ker' {
    Assert-Match 'choice' (Get-Content (Join-Path $Here 'Eltavolitas.bat') -Raw) 'nincs megerosites az eltavolitasban'
}

# ---------------------------------------------------------------------------
Section '5. A gepre kiirt tajekoztato'

It 'leirja, hogyan lehet megszuntetni' {
    $t = Get-Content (Join-Path $Here 'TAJEKOZTATO.txt') -Raw
    Assert-Match 'Eltavolitas' $t 'nem hivatkozik az eltavolitora'
    Assert-Match 'MEGSZ' $t 'nincs benne a megszuntetesrol szolo szakasz'
}

It 'megmondja, mire ad lehetoseget - nem szepiti' {
    $t = Get-Content (Join-Path $Here 'TAJEKOZTATO.txt') -Raw
    Assert-Match 'billenty' $t 'nem mondja ki, hogy a billentyuzet is hasznalhato'
    Assert-Match 'rny' $t 'nem mondja ki, hogy a kepernyo lathato'
}

# ---------------------------------------------------------------------------
Section '6. Az eltavolitas tenyleg eltavolit'

It 'a megtartando lista CSAK a naplot tartalmazza' {
    # Ha ide barmi mas bekerul, a beleptetesi titok ujra a gepen maradhat.
    $t = Get-Content $Ps1 -Raw
    Assert-Match "\`$KeepOnUninstall\s*=\s*@\(\s*'Setup-PaoRemote\.log'\s*\)" $t `
        'a megtartando lista nem csak a naplot tartalmazza'
}

It 'a "nem maradt semmi" uzenet csak a takaritas UTAN hangzik el' {
    # Pont ez volt a hiba: a script azt irta ki, hogy nem maradt tavtamogatas,
    # mikozben a MeshAgent.msh, a konfig es a jelszofajl ott maradt a gepen.
    $t = Get-Content $Ps1 -Raw
    $torles = $t.IndexOf('Remove-StateDirContent)')
    $uzenet = $t.IndexOf('Kesz. A gepen nem maradt')
    Assert-True ($torles -gt 0) 'nincs meghivva a mappa-takaritas az eltavolitasban'
    Assert-True ($uzenet -gt $torles) 'a script elobb allitja, hogy nem maradt semmi, mint hogy torolne'
}

It 'a takaritas a naplot meghagyja, mindent mast torol' {
    # Ezt tenylegesen lefuttatjuk egy ideiglenes mappan - a statikus atolvasas
    # egyszer mar atengedte ezt a hibat.
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref] $null, [ref] $null)
    $fn = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                           $args[0].Name -eq 'Remove-StateDirContent' }, $true)) | Select-Object -First 1
    Assert-True ($null -ne $fn) 'nincs Remove-StateDirContent fuggveny'

    $StateDir = Join-Path ([IO.Path]::GetTempPath()) ('pao-uninst-' + [Guid]::NewGuid().ToString('N'))
    $KeepOnUninstall = @('Setup-PaoRemote.log')
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    try {
        foreach ($f in @('Setup-PaoRemote.log', 'MeshAgent.msh', 'pao-remote.json',
                         'tamogatoi-fiok.jelszo', 'MeshAgent64.exe', 'Eltavolitas.bat')) {
            Set-Content -Path (Join-Path $StateDir $f) -Value 'x' -Encoding ASCII
        }
        . ([scriptblock]::Create($fn.Extent.Text))
        $stuck = @(Remove-StateDirContent)
        Assert-Equal 0 $stuck.Count ('nem sikerult torolni: ' + ($stuck -join ', '))
        $maradt = @(Get-ChildItem -LiteralPath $StateDir -Force | ForEach-Object { $_.Name })
        Assert-Equal 1 $maradt.Count ('nem csak a naplo maradt a mappaban: ' + ($maradt -join ', '))
        Assert-Equal 'Setup-PaoRemote.log' $maradt[0] 'nem a naplo maradt meg'
    } finally { Remove-Item -LiteralPath $StateDir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a tajekoztato nem iger tobbet, mint amit az eltavolitas megtesz' {
    $t = Get-Content (Join-Path $Here 'TAJEKOZTATO.txt') -Raw
    Assert-Match 'napl' $t 'nem mondja meg, hogy a naplo a gepen marad'
    Assert-True ($t -notmatch 'minden hozz. tartoz. f.jlt') `
        'azt igeri, hogy MINDEN fajlt eltavolit - a naplo viszont marad'
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host ('Eredmeny: ' + $script:Pass + ' rendben, ' + $script:Fail + ' bukott.') `
    -ForegroundColor $(if ($script:Fail -eq 0) { 'Green' } else { 'Red' })
Write-Host ''
if ($script:Fail -gt 0) { exit 1 }
exit 0
