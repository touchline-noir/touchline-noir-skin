#requires -Version 5.1
<#
  터치라인 누아르 스킨 업데이트 도구 (Football Manager 27 · Windows · Steam)

  하는 일
  1. GitHub 릴리스의 업데이트 정보(noir-update.json)와 서명을 받아, 이 파일 안의 공개 키로 확인합니다.
     서명이 맞지 않으면 아무것도 받지 않고 멈춥니다.
  2. 게임 폴더 · 게임 빌드 · 설치된 테마를 확인하고, 바뀐 스킨 파일만 내려받아 새 버전 설치 패키지를
     이 컴퓨터(%LOCALAPPDATA%\TouchlineNoir\packages)에 다시 만듭니다. 받은 파일은 모두 SHA-256으로 확인합니다.
  3. FM27이 꺼진 뒤, 그 패키지의 설치 과정(2-Install.cmd와 같은 검사 · 원본 백업 · 확인)을 관리자 권한으로
     실행합니다. 게임 파일은 이 단계에서만, 스킨 설치 도구를 통해서만 바뀝니다.

  사용: Update-TouchlineNoir.cmd 를 두 번 클릭합니다.
  옵션: -CheckOnly        확인만 하고 끝냅니다.
        -PrepareOnly      새 버전 패키지를 받아 두기만 하고 설치하지 않습니다.
        -Theme LIGHT      테마를 고르거나 바꿉니다 (CLASSIC 또는 LIGHT).
        -GamePath "폴더"  fm.exe가 있는 게임 폴더를 직접 알려 줍니다.
        -Yes              묻지 않고 진행합니다 (관리자 권한 확인 창은 그대로 뜹니다).
#>
[CmdletBinding()]
param(
    [string]$Theme,
    [string]$GamePath,
    [switch]$CheckOnly,
    [switch]$PrepareOnly,
    [switch]$Yes,
    [switch]$NoSelfUpdate,
    [string]$ManifestUrl,
    [string]$CacheRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$UpdaterVersion = 1
$DefaultManifestUrl = 'https://github.com/touchline-noir/touchline-noir-skin/releases/latest/download/noir-update.json'
$PublicKeyXml = '<RSAKeyValue><Modulus>3JmeuOogTBadgyGobMTHROideCa9DssUfDKTfSdhnyBk4JEL1+8P3uGltDvwVBNZJe2T5NuSFV3qo4QgZy8bOPMMees8d4dKO0Hh45yhNijGsGs2CGbgormGlv8AOe6E5DXHroSxTMYC4JG7K6A6CfHmHygf1pbx5e2rttv8g8UUeDTyTHFAmMjxECf3f6pIZJ4/NEDLJWcWXps+1k6n1BbQ3J2fuvnLlXbJMfOoc+3P95cBrx5cq/RM4IJyip/GwiAXvSpSm3cDu6zCFKOmtQ24bDRMnIMl1ZfVktTD9/OCBgkJ47CEbIzfre1lBEgm0B8mJ8eNCDUkBK9+rMP8M0AIWJtyYffnRYiXjwChxR4Tmp95Icgs+GwkLUf+i9uOe1IgZPWPEqOb0lBz+woeG1KEeuFxYBdL7uj7dJ4RDeHXDM9FnV/YBhi0k2gd3Zg0SRpy1LkTLKPA5uum7fa55/glPY28h0M10zlmO+Z214yO5BuZboKtI07eMbeibZZd</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
$BundleDirectory = 'fm_Data\StreamingAssets\aa\StandaloneWindows64'
$CacheMarker = '.touchline-noir-cache'
$PathPattern = '^[A-Za-z0-9][A-Za-z0-9 ._()+-]*(/[A-Za-z0-9][A-Za-z0-9 ._()+-]*)*$'
$script:Transcript = $false

function Say([string]$Text) { Write-Host $Text }
function Note([string]$Text) { Write-Host $Text -ForegroundColor DarkGray }
function Good([string]$Text) { Write-Host $Text -ForegroundColor Green }
function Warn([string]$Text) { Write-Host $Text -ForegroundColor Yellow }

function Stop-Updater([int]$Code) {
    if ($script:Transcript) { try { Stop-Transcript | Out-Null } catch { } ; $script:Transcript = $false }
    exit $Code
}
function Get-ErrorText($ErrorRecord) {
    $parts = @(); $e = $ErrorRecord.Exception
    while ($null -ne $e) {
        $wrapper = $e -is [Management.Automation.MethodInvocationException] -or $e -is [AggregateException]
        if (-not $wrapper -and $e.Message -and ($parts -notcontains $e.Message)) { $parts += $e.Message }
        $e = $e.InnerException
    }
    if ($parts.Count -eq 0 -and $ErrorRecord.Exception.Message) { $parts += $ErrorRecord.Exception.Message }
    return ($parts -join ' / ')
}
function Get-Prop($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}
function Get-Text($Object, [string]$Name, [string]$Pattern) {
    $value = Get-Prop $Object $Name
    if (-not ($value -is [string]) -or $value -cnotmatch $Pattern) { throw ('업데이트 정보 형식이 올바르지 않습니다: ' + $Name) }
    return $value
}
function Get-Entry($Object, [string]$What) {
    $path = Get-Text $Object 'path' $PathPattern
    $sha = Get-Text $Object 'sha256' '^[0-9a-f]{64}$'
    $url = Get-Text $Object 'url' '^https?://'
    $size = 0L
    if (-not [long]::TryParse([string](Get-Prop $Object 'size'), [ref]$size) -or $size -lt 0 -or $size -gt 4GB) {
        throw ('업데이트 정보 형식이 올바르지 않습니다: size (' + $What + ')')
    }
    return [pscustomobject]@{ Path = $path; Local = $path.Replace('/', '\'); Sha256 = $sha; Size = $size; Url = $url }
}
function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f $Bytes)
}
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-FileSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}
function Test-FileMatch([string]$Path, [string]$Sha256, [long]$Size) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $Path -Force).Length -ne $Size) { return $false }
    return ((Get-FileSha256 $Path) -ceq $Sha256)
}
function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { [void][IO.Directory]::CreateDirectory($Path) }
}
function Test-ManifestSignature([byte[]]$Data, [string]$SignatureText) {
    try { $signature = [Convert]::FromBase64String($SignatureText.Trim()) } catch { return $false }
    $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
    try {
        $rsa.PersistKeyInCsp = $false
        $rsa.FromXmlString($PublicKeyXml)
        return [bool]$rsa.VerifyData($Data, 'SHA256', $signature)
    } finally { $rsa.Dispose() }
}
function New-HttpClient {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $client = New-Object Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(10)
    [void]$client.DefaultRequestHeaders.UserAgent.TryParseAdd('TouchlineNoirUpdater/' + $UpdaterVersion)
    return $client
}
function Assert-Url([string]$Url) {
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { throw ('잘못된 주소입니다: ' + $Url) }
    if ($uri.Scheme -ceq 'https') { return $uri }
    if ($uri.Scheme -ceq 'http' -and ($uri.Host -ceq '127.0.0.1' -or $uri.Host -ceq 'localhost')) { return $uri }
    throw ('https 주소만 받을 수 있습니다: ' + $Url)
}
function Get-SmallDownload($Client, [string]$Url, [long]$Limit) {
    $uri = Assert-Url $Url
    $response = $Client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
        if (-not $response.IsSuccessStatusCode) { throw ('HTTP ' + [int]$response.StatusCode + ' - ' + $Url) }
        $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        try {
            $memory = New-Object IO.MemoryStream
            $chunk = New-Object byte[] 65536
            while (($read = $source.Read($chunk, 0, $chunk.Length)) -gt 0) {
                $memory.Write($chunk, 0, $read)
                if ($memory.Length -gt $Limit) { throw ('예상보다 큰 응답입니다: ' + $Url) }
            }
            return ,($memory.ToArray())
        } finally { $source.Dispose() }
    } finally { $response.Dispose() }
}
function Save-VerifiedDownload($Client, $Entry, [string]$Destination, [string]$Label) {
    $uri = Assert-Url $Entry.Url
    $partial = $Destination + '.partial'
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $response = $null; $source = $null; $target = $null; $sha = $null
        try {
            if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
            $response = $Client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) { throw ('HTTP ' + [int]$response.StatusCode) }
            $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $target = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $sha = [Security.Cryptography.SHA256]::Create()
            $chunk = New-Object byte[] 1048576
            $done = 0L; $shown = [DateTime]::UtcNow
            while (($read = $source.Read($chunk, 0, $chunk.Length)) -gt 0) {
                $target.Write($chunk, 0, $read)
                [void]$sha.TransformBlock($chunk, 0, $read, $null, 0)
                $done += $read
                if ($done -gt $Entry.Size) { throw '예상보다 큰 파일입니다' }
                if (([DateTime]::UtcNow - $shown).TotalMilliseconds -ge 400) {
                    $shown = [DateTime]::UtcNow
                    $percent = [int](100 * $done / [Math]::Max($Entry.Size, 1))
                    Write-Progress -Activity '내려받는 중' -Status ('{0}  {1} / {2}' -f $Label, (Format-Size $done), (Format-Size $Entry.Size)) -PercentComplete $percent
                }
            }
            [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
            $hash = ([BitConverter]::ToString($sha.Hash)).Replace('-', '').ToLowerInvariant()
            $target.Dispose(); $target = $null
            if ($done -ne $Entry.Size -or $hash -cne $Entry.Sha256) { throw ('받은 파일의 확인 값이 다릅니다 (' + $Label + ')') }
            if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
            [IO.File]::Move($partial, $Destination)
            Write-Progress -Activity '내려받는 중' -Completed
            return
        } catch {
            $message = Get-ErrorText $_
            if ($null -ne $target) { $target.Dispose(); $target = $null }
            Write-Progress -Activity '내려받는 중' -Completed
            if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue }
            if ($attempt -ge 3) { throw ('내려받기 실패: ' + $Label + ' (' + $message + ')') }
            Warn ('  다시 시도합니다 (' + $attempt + '/3): ' + $message)
            Start-Sleep -Seconds (2 * $attempt)
        } finally {
            if ($null -ne $sha) { $sha.Dispose() }
            if ($null -ne $target) { $target.Dispose() }
            if ($null -ne $source) { $source.Dispose() }
            if ($null -ne $response) { $response.Dispose() }
        }
    }
}
function Copy-Verified([string]$Source, $Entry, [string]$Destination) {
    $partial = $Destination + '.partial'
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
    $in = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $out = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $in.CopyTo($out, 1048576) } finally { $out.Dispose() }
    } finally { $in.Dispose() }
    if (-not (Test-FileMatch $partial $Entry.Sha256 $Entry.Size)) {
        Remove-Item -LiteralPath $partial -Force
        throw ('게임 폴더에서 가져온 파일의 확인 값이 다릅니다: ' + $Entry.Path)
    }
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
    [IO.File]::Move($partial, $Destination)
}
function Test-FmRunning {
    $list = [Diagnostics.Process]::GetProcessesByName('fm')
    try { return ($list.Length -gt 0) } finally { foreach ($process in $list) { $process.Dispose() } }
}
function Get-CoreVersion([string]$Text) {
    if ($Text -match '^([0-9]+)\.([0-9]+)\.([0-9]+)') { return [Version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]) }
    return $null
}
function Read-Answer([string]$Prompt) {
    if ($Yes) { return 'Y' }
    return ([string](Read-Host $Prompt)).Trim()
}

try {
    if (-not ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSEdition -ceq 'Desktop')) {
        throw 'Windows PowerShell 5.1에서 실행해 주세요. Update-TouchlineNoir.cmd를 두 번 클릭하면 됩니다.'
    }
    if (-not [Environment]::Is64BitProcess) { throw '64비트 Windows PowerShell에서 실행해 주세요. Update-TouchlineNoir.cmd를 두 번 클릭하면 됩니다.' }
    if (-not $CacheRoot) { $CacheRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TouchlineNoir' }
    $CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
    Ensure-Directory $CacheRoot
    try {
        $logs = Join-Path $CacheRoot 'Logs'
        Ensure-Directory $logs
        Start-Transcript -LiteralPath (Join-Path $logs ('update-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.log')) | Out-Null
        $script:Transcript = $true
    } catch { }

    Say ''
    Say ('터치라인 누아르 스킨 업데이트 도구 v' + $UpdaterVersion)
    Say '────────────────────────────────────────'
    if (-not $ManifestUrl) { $ManifestUrl = $DefaultManifestUrl }
    $client = New-HttpClient
    Say '최신 버전 정보를 확인하는 중...'
    try {
        $manifestBytes = Get-SmallDownload $client $ManifestUrl 4MB
        $signatureBytes = Get-SmallDownload $client ($ManifestUrl + '.sig') 64KB
    } catch {
        throw ('업데이트 정보를 받지 못했습니다. 인터넷 연결을 확인해 주세요. (' + (Get-ErrorText $_) + ')')
    }
    if (-not (Test-ManifestSignature $manifestBytes ([Text.Encoding]::ASCII.GetString($signatureBytes)))) {
        throw '업데이트 정보의 서명이 맞지 않습니다. 아무 파일도 받지 않고 멈춥니다.'
    }
    $manifestText = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes).TrimStart([char]0xFEFF)
    $manifest = $manifestText | ConvertFrom-Json
    if ((Get-Prop $manifest 'schema') -ne 1 -or (Get-Prop $manifest 'product') -cne 'touchline-noir-skin') {
        throw '이 업데이트 도구가 읽을 수 없는 업데이트 정보입니다. GitHub 릴리스에서 TOUCHLINE-NOIR-UPDATER.zip을 새로 받아 주세요.'
    }
    $latestVersion = Get-Text $manifest 'version' '^[0-9]+\.[0-9]+\.[0-9]+$'
    $latestDisplay = Get-Text $manifest 'display_version' '^V[0-9][0-9A-Za-z .-]*$'
    Good ('서명 확인 완료 · 공개 최신 버전: ' + $latestDisplay)

    # The updater replaces only its own script (never the running .cmd launcher), then restarts once.
    $updaterInfo = Get-Prop $manifest 'updater'
    $newUpdater = 0; [void][int]::TryParse([string](Get-Prop $updaterInfo 'version'), [ref]$newUpdater)
    $minUpdater = 0; [void][int]::TryParse([string](Get-Prop $manifest 'min_updater_version'), [ref]$minUpdater)
    if (-not $NoSelfUpdate -and $newUpdater -gt $UpdaterVersion) {
        Say ('업데이트 도구 새 버전(v' + $newUpdater + ')을 먼저 받습니다.')
        $selfDirectory = Split-Path -Parent $PSCommandPath
        $staging = Join-Path $CacheRoot 'updater'
        Ensure-Directory $staging
        $replaced = $false
        foreach ($item in @(Get-Prop $updaterInfo 'files')) {
            $entry = Get-Entry $item 'updater'
            if ($entry.Path -cnotin @('Update-TouchlineNoir.ps1', 'README-UPDATER-KO.txt')) { continue }
            $staged = Join-Path $staging ($entry.Sha256.Substring(0, 16) + '-' + $entry.Path)
            if (-not (Test-FileMatch $staged $entry.Sha256 $entry.Size)) { Save-VerifiedDownload $client $entry $staged $entry.Path }
            Copy-Item -LiteralPath $staged -Destination (Join-Path $selfDirectory $entry.Path) -Force
            if ($entry.Path -ceq 'Update-TouchlineNoir.ps1') { $replaced = $true }
        }
        if ($replaced) {
            $forward = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-NoSelfUpdate')
            foreach ($key in $PSBoundParameters.Keys) {
                if ($key -ceq 'NoSelfUpdate') { continue }
                $value = $PSBoundParameters[$key]
                if ($value -is [Management.Automation.SwitchParameter]) { if ($value.IsPresent) { $forward += ('-' + $key) } }
                else { $forward += @(('-' + $key), [string]$value) }
            }
            if ($script:Transcript) { try { Stop-Transcript | Out-Null } catch { } ; $script:Transcript = $false }
            Say '새 업데이트 도구로 다시 시작합니다.'
            & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') @forward
            exit $LASTEXITCODE
        }
    }
    if ($UpdaterVersion -lt $minUpdater) {
        throw '이 업데이트 도구는 너무 오래되었습니다. GitHub 릴리스에서 TOUCHLINE-NOIR-UPDATER.zip을 새로 받아 주세요.'
    }

    # Game discovery uses the installer's own read-only Find-Fm27.ps1 (hash pinned by the signed manifest).
    $finder = Get-Entry (Get-Prop $manifest 'finder') 'finder'
    $helpers = Join-Path $CacheRoot 'helpers'
    Ensure-Directory $helpers
    $finderPath = Join-Path $helpers ($finder.Sha256.Substring(0, 16) + '-Find-Fm27.ps1')
    if (-not (Test-FileMatch $finderPath $finder.Sha256 $finder.Size)) { Save-VerifiedDownload $client $finder $finderPath 'Find-Fm27.ps1' }
    $finderBytes = [IO.File]::ReadAllBytes($finderPath)
    if ((Get-BytesSha256 $finderBytes) -cne $finder.Sha256) { throw '게임 찾기 도구의 확인 값이 다릅니다.' }
    . ([ScriptBlock]::Create((New-Object Text.UTF8Encoding($false)).GetString($finderBytes).TrimStart([char]0xFEFF)))

    if ($GamePath) {
        $found = @(Get-Fm27Installations -GamePath $GamePath | Where-Object { $_.Source -ceq 'Explicit' })
        if ($found.Count -ne 1) { throw '알려 준 경로에서 FM27을 찾지 못했습니다. fm.exe가 있는 폴더를 알려 주세요.' }
        $game = [string]$found[0].Path
    } else {
        $found = @(Get-Fm27Installations)
        if ($found.Count -eq 1) { $game = [string]$found[0].Path }
        elseif ($found.Count -eq 0) {
            if ($Yes) { throw 'FM27 설치 폴더를 찾지 못했습니다. -GamePath로 fm.exe가 있는 폴더를 알려 주세요.' }
            $answer = ([string](Read-Host 'FM27 설치 폴더(fm.exe가 있는 폴더)를 입력하세요')).Trim().Trim('"')
            $found = @(Get-Fm27Installations -GamePath $answer | Where-Object { $_.Source -ceq 'Explicit' })
            if ($found.Count -ne 1) { throw '입력한 경로에서 FM27을 찾지 못했습니다.' }
            $game = [string]$found[0].Path
        } else {
            Say 'FM27 설치가 여러 개 있습니다:'
            for ($i = 0; $i -lt $found.Count; $i++) { Say ('  {0}) {1}  [{2}]' -f ($i + 1), $found[$i].Path, $found[$i].Source) }
            if ($Yes) { throw '여러 설치 중 하나를 -GamePath로 골라 주세요.' }
            $pick = 0
            if (-not [int]::TryParse(([string](Read-Host '번호를 고르세요')).Trim(), [ref]$pick) -or $pick -lt 1 -or $pick -gt $found.Count) { throw '잘못된 번호입니다.' }
            $game = [string]$found[$pick - 1].Path
        }
    }
    Say ('게임 폴더: ' + $game)

    # Game build: the same four pinned loader identities the installer checks.
    $identityCache = @{}
    $build = $null
    foreach ($candidate in @(Get-Prop $manifest 'builds')) {
        $match = $true
        $identities = @(Get-Prop $candidate 'identity')
        if ($identities.Count -lt 1) { throw '업데이트 정보 형식이 올바르지 않습니다: identity' }
        foreach ($identity in $identities) {
            $relative = Get-Text $identity 'relative_path' $PathPattern
            $expected = Get-Text $identity 'sha256' '^[0-9a-f]{64}$'
            if (-not $identityCache.ContainsKey($relative)) {
                $file = Join-Path $game $relative.Replace('/', '\')
                $identityCache[$relative] = $(if (Test-Path -LiteralPath $file -PathType Leaf) { Get-FileSha256 $file } else { '' })
            }
            if ($identityCache[$relative] -cne $expected) { $match = $false; break }
        }
        if ($match) { $build = $candidate; break }
    }
    if ($null -eq $build) {
        $supported = (@(Get-Prop $manifest 'builds') | ForEach-Object { 'Steam ' + (Get-Prop $_ 'game_build') }) -join ', '
        Warn ('이 FM27 빌드는 아직 지원하지 않습니다. 지원 빌드: ' + $supported)
        Warn 'FM27이 업데이트되었다면 그 빌드에 맞춘 스킨이 나올 때까지 기다려 주세요. 게임 파일은 바꾸지 않았습니다.'
        Stop-Updater 2
    }
    $buildId = Get-Text $build 'game_build' '^[0-9]+$'
    Say ('게임 빌드: Steam ' + $buildId + ' (지원)')

    # Installed state: the installer's last receipt names version and theme; file hashes decide what changes.
    $receipt = $null
    $receiptPath = Join-Path $game ('NativeCalmBackup\builds\' + $buildId + '\last-operation.json')
    if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
        try { $receipt = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $receipt = $null }
    }
    $receiptVersion = [string](Get-Prop $receipt 'Version')
    $receiptAction = [string](Get-Prop $receipt 'Action')
    $receiptTheme = ''
    if ($receiptVersion -cmatch '-(classic|light)-windows$') { $receiptTheme = $Matches[1].ToUpperInvariant() }
    if ($receiptAction -ceq 'Restore') { Say '설치 기록: 스킨을 되돌린 상태(원래 FM 화면)' }
    elseif ($receiptVersion) { Say ('설치 기록: ' + ($receiptVersion -replace '-windows$', '')) }
    else { Say '설치 기록: 없음' }

    $themes = @((Get-Prop $build 'themes').PSObject.Properties | ForEach-Object { $_.Name })
    if ($Theme) {
        $chosen = $Theme.Trim().ToUpperInvariant()
        if ($chosen -cnotin $themes) { throw ('테마는 ' + ($themes -join ' 또는 ') + ' 중에서 골라 주세요.') }
    } elseif ($receiptTheme -and $receiptAction -cne 'Restore' -and $receiptTheme -cin $themes) {
        $chosen = $receiptTheme
    } else {
        if ($Yes) { throw '설치된 테마를 알 수 없습니다. -Theme CLASSIC 또는 -Theme LIGHT로 골라 주세요.' }
        Say '설치할 테마를 고르세요:'
        for ($i = 0; $i -lt $themes.Count; $i++) { Say ('  {0}) {1}' -f ($i + 1), $themes[$i]) }
        $pick = 0
        if (-not [int]::TryParse(([string](Read-Host '번호')).Trim(), [ref]$pick) -or $pick -lt 1 -or $pick -gt $themes.Count) { throw '잘못된 번호입니다.' }
        $chosen = $themes[$pick - 1]
    }
    $package = Get-Prop (Get-Prop $build 'themes') $chosen
    $packageVersion = Get-Text $package 'package_version' '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)*-(classic|light)-windows$'
    $packageDisplay = Get-Text $package 'display_name' '^V[0-9][0-9A-Za-z .-]*$'

    $installedCore = Get-CoreVersion $receiptVersion
    $latestCore = Get-CoreVersion $latestVersion
    if (-not $Theme -and $null -ne $installedCore -and $installedCore -gt $latestCore -and $receiptAction -cne 'Restore') {
        Good ('설치된 스킨(' + ($receiptVersion -replace '-windows$', '') + ')이 공개 최신 버전보다 새 버전입니다. 그대로 둡니다.')
        Stop-Updater 0
    }

    $entries = @(@(Get-Prop $package 'files') | ForEach-Object { Get-Entry $_ $chosen })
    if (@($entries | ForEach-Object { $_.Path } | Select-Object -Unique).Count -ne $entries.Count) { throw '업데이트 정보에 같은 파일이 두 번 있습니다.' }
    $packageRoot = Join-Path $CacheRoot ('packages\' + $packageVersion)
    Ensure-Directory $packageRoot
    $markerPath = Join-Path $packageRoot $CacheMarker
    if (-not (Test-Path -LiteralPath $markerPath)) { [IO.File]::WriteAllText($markerPath, $packageVersion) }

    # The package's own manifest lists the 13 managed game bundles and their accepted hashes.
    $packageJsonEntry = @($entries | Where-Object { $_.Path -ceq 'package.json' })
    if ($packageJsonEntry.Count -ne 1) { throw '업데이트 정보에 package.json이 없습니다.' }
    $packageJsonEntry = $packageJsonEntry[0]
    $packageJsonPath = Join-Path $packageRoot 'package.json'
    if (-not (Test-FileMatch $packageJsonPath $packageJsonEntry.Sha256 $packageJsonEntry.Size)) { Save-VerifiedDownload $client $packageJsonEntry $packageJsonPath 'package.json' }
    $packageBytes = [IO.File]::ReadAllBytes($packageJsonPath)
    if ((Get-BytesSha256 $packageBytes) -cne $packageJsonEntry.Sha256) { throw 'package.json 확인 값이 다릅니다.' }
    $packageManifest = (New-Object Text.UTF8Encoding($false)).GetString($packageBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    if ([string](Get-Prop $packageManifest 'version') -cne $packageVersion -or [string](Get-Prop $packageManifest 'game_build') -cne $buildId) { throw 'package.json 버전이 업데이트 정보와 다릅니다.' }

    Say '설치된 스킨 파일을 확인하는 중...'
    $bundles = @()
    foreach ($file in @(Get-Prop $packageManifest 'files')) {
        if ([string](Get-Prop $file 'kind') -cne 'bundle') { continue }
        $name = Get-Text $file 'name' '^[A-Za-z0-9._-]+\.bundle$'
        $installedHash = Get-Text $file 'installed_sha256' '^[0-9a-f]{64}$'
        $sourceHash = Get-Text $file 'source_sha256' '^[0-9a-f]{64}$'
        $previous = @(Get-Prop $file 'previous_sha256')
        $target = Join-Path $game ($BundleDirectory + '\' + $name)
        $current = $(if (Test-Path -LiteralPath $target -PathType Leaf) { Get-FileSha256 $target } else { '' })
        $state = 'unknown'
        if ($current -ceq $installedHash) { $state = 'current' }
        elseif ($current -ceq $sourceHash) { $state = 'stock' }
        elseif ($previous -ccontains $current) { $state = 'previous' }
        $bundles += [pscustomobject]@{ Name = $name; Target = $target; Current = $current; Installed = $installedHash; State = $state }
    }
    if ($bundles.Count -lt 1) { throw 'package.json에 스킨 파일 목록이 없습니다.' }
    $changing = @($bundles | Where-Object { $_.State -cne 'current' })
    $unknown = @($bundles | Where-Object { $_.State -ceq 'unknown' })
    if ($changing.Count -eq 0) {
        Good ('이미 최신입니다: ' + $packageDisplay + ' (스킨 파일 ' + $bundles.Count + '개가 모두 같습니다)')
        Stop-Updater 0
    }
    if ($unknown.Count -gt 0) {
        Warn ('스킨 설치 도구가 모르는 파일이 있습니다: ' + (($unknown | ForEach-Object { $_.Name }) -join ', '))
        Warn '다른 UI 모드를 썼다면 그 모드를 먼저 되돌려 주세요. 설치 전 검사에서 멈출 수 있습니다.'
    }

    # Plan: reuse cached files, copy unchanged skin files from the game, download the rest.
    $plan = @()
    $downloadBytes = 0L
    foreach ($entry in $entries) {
        $destination = Join-Path $packageRoot $entry.Local
        $have = Test-FileMatch $destination $entry.Sha256 $entry.Size
        $localSource = $null
        if (-not $have -and $entry.Path -cmatch '^payload/([A-Za-z0-9._-]+\.bundle)$') {
            $bundleName = $Matches[1]
            $same = @($bundles | Where-Object { $_.Name -ceq $bundleName -and $_.Current -ceq $entry.Sha256 })
            if ($same.Count -eq 1) { $localSource = $same[0].Target }
        }
        if (-not $have -and -not $localSource) { $downloadBytes += $entry.Size }
        $plan += [pscustomobject]@{ Entry = $entry; Destination = $destination; Have = $have; LocalSource = $localSource }
    }
    $downloads = @($plan | Where-Object { -not $_.Have -and -not $_.LocalSource })

    Say ''
    Say ('새 버전: ' + $packageDisplay)
    Say ('바뀌는 스킨 파일: ' + $changing.Count + '개 / ' + $bundles.Count + '개')
    Say ('내려받을 크기: ' + (Format-Size $downloadBytes) + ' (파일 ' + $downloads.Count + '개)')
    $notes = @(Get-Prop $manifest 'notes_ko')
    if ($notes.Count -gt 0) {
        Say ''
        Say '바뀐 점:'
        foreach ($line in $notes) { Say ('  - ' + [string]$line) }
    }
    Say ''
    if ($CheckOnly) {
        Say '확인만 했습니다 (-CheckOnly). 게임 파일은 바꾸지 않았습니다.'
        Stop-Updater 0
    }
    $answer = Read-Answer '업데이트할까요? (Y/N)'
    if ($answer -notmatch '^(y|yes|ㅛ|예|네)$') {
        Say '취소했습니다. 게임 파일은 바꾸지 않았습니다.'
        Stop-Updater 3
    }

    foreach ($step in $plan) {
        if ($step.Have) { continue }
        Ensure-Directory (Split-Path -Parent $step.Destination)
        if ($step.LocalSource) { Copy-Verified $step.LocalSource $step.Entry $step.Destination }
        else { Save-VerifiedDownload $client $step.Entry $step.Destination $step.Entry.Path }
    }
    Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File -Filter '*.partial' | Remove-Item -Force
    foreach ($step in $plan) {
        if (-not (Test-FileMatch $step.Destination $step.Entry.Sha256 $step.Entry.Size)) { throw ('패키지 파일 확인 실패: ' + $step.Entry.Path) }
    }
    Good ('새 버전 패키지 준비 완료: ' + $packageRoot)
    if ($PrepareOnly) {
        Say '받아 두기만 했습니다 (-PrepareOnly). 위 폴더의 2-Install.cmd로 설치할 수 있습니다.'
        Stop-Updater 0
    }

    if (Test-FmRunning) {
        Warn 'FM27이 실행 중입니다. 게임을 완전히 닫으면 자동으로 계속합니다. (그만두려면 Ctrl+C)'
        while (Test-FmRunning) { Start-Sleep -Seconds 2 }
        Start-Sleep -Seconds 3
    }

    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $launch = Join-Path $packageRoot 'Launch.ps1'
    Say ''
    Say '설치 전 검사 (읽기만 함)...'
    & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launch -Action Check -GamePath $game -NonInteractive -NoPause
    if ($LASTEXITCODE -ne 0) { throw '설치 전 검사에서 멈췄습니다. 위의 ERROR를 확인해 주세요. 게임 파일은 바꾸지 않았습니다.' }
    Say ''
    Say '설치합니다. 관리자 권한 확인 창(UAC)에서 "예"를 누르면 새 창에서 설치가 진행됩니다.'
    & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launch -Action Install -GamePath $game -NoPause
    $installCode = $LASTEXITCODE
    if ($installCode -ne 0) { throw ('설치가 끝나지 않았습니다 (코드 ' + $installCode + '). 관리자 권한 확인 창에서 "아니요"를 눌렀거나 설치 창에 ERROR가 있습니다. 설치 도구는 실패하면 바꾼 파일을 되돌립니다.') }

    $left = @($bundles | Where-Object { (Get-FileSha256 $_.Target) -cne $_.Installed })
    if ($left.Count -gt 0) { throw ('설치 후 확인에서 다른 파일이 있습니다: ' + (($left | ForEach-Object { $_.Name }) -join ', ')) }
    Say ''
    Good ('업데이트 완료: ' + $packageDisplay)
    Say ('이 버전의 설치 도구 폴더(되돌리기 3-Restore.cmd 포함): ' + $packageRoot)

    foreach ($old in @(Get-ChildItem -LiteralPath (Join-Path $CacheRoot 'packages') -Directory -Force)) {
        if ($old.FullName -ieq $packageRoot) { continue }
        if (Test-Path -LiteralPath (Join-Path $old.FullName $CacheMarker) -PathType Leaf) {
            try { Remove-Item -LiteralPath $old.FullName -Recurse -Force } catch { }
        }
    }
    Stop-Updater 0
} catch {
    Write-Host ''
    Write-Host ('오류: ' + (Get-ErrorText $_)) -ForegroundColor Red
    Stop-Updater 1
}
