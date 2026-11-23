#requires -Version 5.1
<#
  터치라인 누아르 스킨 업데이트 도구 (Football Manager 27 · Windows · Steam)

  하는 일
  1. GitHub 릴리스의 업데이트 정보(noir-update.json)와 서명 목록(noir-update.json.sigs)을 받아, 이 파일 안의
     공개 키로 확인합니다. 서명이 맞지 않거나, 전에 받은 것보다 오래된 정보면 아무것도 받지 않고 멈춥니다.
  2. 게임 폴더 · 게임 빌드 · 설치된 테마를 확인하고, 바뀐 스킨 파일만 내려받아 새 버전 설치 패키지를
     이 컴퓨터(%LOCALAPPDATA%\TouchlineNoir\packages)에 다시 만듭니다. 받은 파일은 모두 SHA-256으로 확인합니다.
  3. FM27이 꺼진 뒤, 패키지 파일을 다시 확인하고 설치가 끝날 때까지 바꿀 수 없게 잡아 둔 채로, 그 패키지의
     설치 과정(2-Install.cmd와 같은 검사 · 원본 백업 · 확인)을 관리자 권한으로 실행합니다.
     게임 파일은 이 단계에서만, 스킨 설치 도구를 통해서만 바뀝니다.
  4. 새 버전 알림(선택): 켜 두면 로그인할 때와 3시간마다 업데이트 정보만 확인해, 새 버전이 있으면
     Windows 알림을 띄웁니다. FM이 실행 중일 때는 알리지 않습니다.
  5. 게임 안 알림(선택, BepInEx 플러그인): 게임 안 카드의 '업데이트하기'로 열리면 묻지 않고 새 버전을
     미리 받아 두고, FM이 꺼지면 바로(0.25초 안) 설치를 시작합니다. 진행 상황은 게임 안 카드에 보입니다.

  사용: Update-TouchlineNoir.cmd 를 두 번 클릭합니다.
  옵션: -CheckOnly        확인만 하고 끝냅니다.
        -PrepareOnly      새 버전 패키지를 받아 두기만 하고 설치하지 않습니다.
        -Theme LIGHT      테마를 고르거나 바꿉니다 (CLASSIC 또는 LIGHT).
        -GamePath "폴더"  fm.exe가 있는 게임 폴더를 직접 알려 줍니다.
        -Notify On        새 버전 알림을 켭니다.  -Notify Off  알림을 끄고 등록한 항목을 모두 지웁니다.
        -Yes              묻지 않고 진행합니다 (관리자 권한 확인 창은 그대로 뜹니다).
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Theme,
    [string]$GamePath,
    [switch]$CheckOnly,
    [switch]$PrepareOnly,
    [switch]$Yes,
    [string]$Notify,
    [switch]$NotifyCheck,
    [switch]$FromProtocol,
    [switch]$NoSelfUpdate,
    [string]$ManifestUrl,
    [string]$CacheRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$UpdaterVersion = 5
$DefaultManifestUrl = 'https://github.com/touchline-noir/touchline-noir-skin/releases/latest/download/noir-update.json'
$DefaultCacheRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TouchlineNoir'
# BEGIN TRUSTED KEYS (key id = first 16 hex digits of SHA-256 of the RSA modulus)
$TrustedKeys = @{
    'd1472c957cdab4de' = '<RSAKeyValue><Modulus>segRmsXUw9FuwOk2ZycrkNz+h3sLeNihlioENnbeIr70oRgUSYc2B9fueRKLqnlIaSd64LUvelyesCdmqZnCrSHQOmKYNsJ7uJjggaNTK7JZiOi4fduNmoc9xOTvAh4KoL2HdSQ+Qpkusg6wn8pOwSoVOc3Jl0eWj0ZXObJGfXg1XWsSWLSkkijpbGtx1xndn+TUXOxMo3VyHd3bXXVlhTiGKAZIGDDjjpgGr4VY8LRS1pRUdE9BbuUgZYNzVE5a9WWAkg1yZuOrrD3/CL3Wif+Nfo3eLZe1MZNEbXOGgIu2W8aXWBppNH0CTRDoj71cJqA2ACKoBoFFJALGYspNqlYf5hY5xgrd7jbw5OVa/OkZAVC6Dbuf4swtfbA8Nv2psx2LUsqYG2e6mUE+Lrs7Y4DkBx5UmbC9ROadAE8djWOdTRzOYNyIL+5HN6/9B2akmWbyO91C4czNDF2KHWLsS9AiVZe5T0cYEdDwV4kmCnGkKneORYxwkPBR1eIe8stN</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
}
# END TRUSTED KEYS
$AllowLoopback = $false
$BundleDirectory = 'fm_Data\StreamingAssets\aa\StandaloneWindows64'
$CacheMarker = '.touchline-noir-cache'
$ToolMarker = '.touchline-noir-tool'
$Segment = '[A-Za-z0-9](?:[A-Za-z0-9 ._()+-]*[A-Za-z0-9_()+-])?'
$PathPattern = '^' + $Segment + '(?:/' + $Segment + ')*\z'
$TaskName = 'TouchlineNoir Update Check'
$AppId = 'TouchlineNoir.SkinUpdater'
$ProtocolName = 'touchline-noir-update'
$ReleasePage = 'https://github.com/touchline-noir/touchline-noir-skin/releases/latest'
$RemindAfterHours = 72
# System folders come from the OS, not from environment variables a user-level setting could redirect.
$SystemDirectory = [Environment]::SystemDirectory
$PowerShellExe = Join-Path $SystemDirectory 'WindowsPowerShell\v1.0\powershell.exe'
$LauncherText = (@(
    '@echo off',
    'setlocal',
    'set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules;%PSModulePath%"',
    '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-TouchlineNoir.ps1" %*',
    'set "noir_result=%errorlevel%"',
    'if not "%NOIR_NO_PAUSE%"=="1" pause',
    'exit /b %noir_result%'
) -join "`r`n") + "`r`n"
$script:Transcript = $false
$script:NotifyLog = $null
$script:NoPause = $false
$script:InGame = $null
$script:InGameVersion = ''
$script:SingleInstance = $null
$script:WindowShown = $false
$script:ProgressTotal = 0L
$script:ProgressBase = 0L
$script:ProgressShown = [DateTime]::MinValue
$script:ProgressFiles = 0
$script:ProgressFileTotal = 0
$script:AutoClose = $false

function Say([string]$Text) { Write-Host $Text }
function Note([string]$Text) { Write-Host $Text -ForegroundColor DarkGray }
function Good([string]$Text) { Write-Host $Text -ForegroundColor Green }
function Warn([string]$Text) { Write-Host $Text -ForegroundColor Yellow }

function Stop-Updater([int]$Code) {
    Complete-InGameRequest
    if ($script:Transcript) { try { Stop-Transcript | Out-Null } catch { } ; $script:Transcript = $false }
    if ($FromProtocol -and -not $NotifyCheck -and -not $script:NoPause) {
        if ($script:AutoClose) { Wait-KeyOrTimeout 15 }
        else { try { [void](Read-Host '창을 닫으려면 Enter를 누르세요') } catch { } }
    }
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
function Test-ReservedPath([string]$Path) {
    foreach ($part in $Path.Split('/')) {
        if ($part.Split('.')[0] -match '^(?i:con|prn|aux|nul|com[0-9]|lpt[0-9])\z') { return $true }
    }
    return $false
}
function Get-Entry($Object, [string]$What) {
    $path = Get-Text $Object 'path' $PathPattern
    if (Test-ReservedPath $path) { throw ('업데이트 정보 형식이 올바르지 않습니다: path (' + $What + ')') }
    $sha = Get-Text $Object 'sha256' '^[0-9a-f]{64}\z'
    $url = Get-Text $Object 'url' '^https?://[^\s"<>\\]+\z'
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
function Format-PackageVersion([string]$Text) {
    if ($Text -cmatch '^([0-9]+\.[0-9]+\.[0-9]+)((?:-[a-z0-9.]+)*?)-(classic|light)-windows\z') {
        return ('V' + $Matches[1] + $Matches[2] + ' ' + $Matches[3].ToUpperInvariant())
    }
    if ($Text) {
        $clean = $Text -replace '[^\x20-\x7E]', '?'
        if ($clean.Length -gt 40) { $clean = $clean.Substring(0, 40) }
        return $clean
    }
    return '알 수 없음'
}
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-StreamSha256([IO.Stream]$Stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-FileSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { return (Get-StreamSha256 $stream) } finally { $stream.Dispose() }
}
function Test-ReparsePoint([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}
function Test-FileMatch([string]$Path, [string]$Sha256, [long]$Size) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Test-ReparsePoint $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path -Force).Length -ne $Size) { return $false }
    return ((Get-FileSha256 $Path) -ceq $Sha256)
}
function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { [void][IO.Directory]::CreateDirectory($Path) }
}
function Remove-TreeSafely([string]$Path) {
    # Never follows junctions or symbolic links: a reparse point is removed as a link, its target is left alone.
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        if ($item.PSIsContainer) { [IO.Directory]::Delete($item.FullName, $false) } else { [IO.File]::Delete($item.FullName) }
        return
    }
    if ($item.PSIsContainer) {
        foreach ($child in @(Get-ChildItem -LiteralPath $item.FullName -Force)) { Remove-TreeSafely $child.FullName }
        [IO.Directory]::Delete($item.FullName, $false)
    } else {
        if (($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) { $item.Attributes = [IO.FileAttributes]::Normal }
        [IO.File]::Delete($item.FullName)
    }
}
function ConvertTo-ArgumentText([string]$Value) {
    # Windows command-line quoting (CommandLineToArgvW rules): always quoted, backslashes before quotes doubled.
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($c in $Value.ToCharArray()) {
        if ($c -eq [char]92) { $slashes++; continue }
        if ($c -eq [char]34) { [void]$builder.Append(('\' * ($slashes * 2 + 1)) + '"') }
        else { [void]$builder.Append(('\' * $slashes) + $c) }
        $slashes = 0
    }
    [void]$builder.Append(('\' * ($slashes * 2)) + '"')
    return $builder.ToString()
}
function Join-ArgumentText([string[]]$Arguments) { return (($Arguments | ForEach-Object { ConvertTo-ArgumentText $_ }) -join ' ') }
function Invoke-Child([string]$File, [string[]]$Arguments) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = Join-ArgumentText $Arguments
    $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($info)
    try { $process.WaitForExit(); return $process.ExitCode } finally { $process.Dispose() }
}
function Test-ManifestSignatures([byte[]]$Data, [byte[]]$SignatureDocument) {
    try { $document = (New-Object Text.UTF8Encoding($false, $true)).GetString($SignatureDocument).TrimStart([char]0xFEFF) | ConvertFrom-Json } catch { return $false }
    if ((Get-Prop $document 'schema') -ne 1) { return $false }
    foreach ($entry in @(Get-Prop $document 'signatures')) {
        $keyId = [string](Get-Prop $entry 'key')
        if ([string](Get-Prop $entry 'alg') -cne 'rsa-pkcs1-sha256' -or $keyId -cnotmatch '^[0-9a-f]{16}\z' -or -not $TrustedKeys.ContainsKey($keyId)) { continue }
        try { $signature = [Convert]::FromBase64String(([string](Get-Prop $entry 'sig')).Trim()) } catch { continue }
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
        try {
            $rsa.PersistKeyInCsp = $false
            $rsa.FromXmlString($TrustedKeys[$keyId])
            if ($rsa.VerifyData($Data, 'SHA256', $signature)) { return $true }
        } finally { $rsa.Dispose() }
    }
    return $false
}
function New-HttpClient {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    # Several small files are fetched at once (Save-SmallDownloads); .NET Framework allows only 2 connections per host by default.
    try { if ([Net.ServicePointManager]::DefaultConnectionLimit -lt 8) { [Net.ServicePointManager]::DefaultConnectionLimit = 8 } } catch { }
    $client = New-Object Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(10)
    [void]$client.DefaultRequestHeaders.UserAgent.TryParseAdd('TouchlineNoirUpdater/' + $UpdaterVersion)
    return $client
}
function Assert-Url([string]$Url) {
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { throw ('잘못된 주소입니다: ' + $Url) }
    if ($uri.Scheme -ceq 'https') { return $uri }
    if ($AllowLoopback -and $uri.Scheme -ceq 'http' -and ($uri.Host -ceq '127.0.0.1' -or $uri.Host -ceq 'localhost')) { return $uri }
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
function Show-LineProgress([string]$Text) {
    # One console line rewritten in place. PowerShell's progress bar is not used: after it disappears the console restores
    # the lines beneath it and prints every double-width (Korean) character there twice. ASCII only, so the padding fits.
    if ($NotifyCheck) { return }
    try {
        $plain = -join ($Text.ToCharArray() | Where-Object { [int]$_ -ge 32 -and [int]$_ -lt 127 })
        $width = [Math]::Max(20, [Console]::WindowWidth - 1)
        if ($plain.Length -gt $width) { $plain = $plain.Substring(0, $width) }
        [Console]::Write([char]13 + $plain.PadRight($width) + [char]13)
    } catch { }
}
function Clear-LineProgress { Show-LineProgress '' }
function Save-VerifiedDownload($Client, $Entry, [string]$Destination, [string]$Label) {
    $uri = Assert-Url $Entry.Url
    $partial = $Destination + '.partial'
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $response = $null; $source = $null; $target = $null; $sha = $null
        try {
            Remove-TreeSafely $partial
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
                    Show-LineProgress ('  {0}%  {1} / {2}  {3}' -f $percent, (Format-Size $done), (Format-Size $Entry.Size), $Label)
                    Write-InGameProgress ($script:ProgressBase + $done)
                }
            }
            [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
            $hash = ([BitConverter]::ToString($sha.Hash)).Replace('-', '').ToLowerInvariant()
            $target.Dispose(); $target = $null
            if ($done -ne $Entry.Size -or $hash -cne $Entry.Sha256) { throw ('받은 파일의 확인 값이 다릅니다 (' + $Label + ')') }
            Remove-TreeSafely $Destination
            [IO.File]::Move($partial, $Destination)
            Clear-LineProgress
            return
        } catch {
            $message = Get-ErrorText $_
            if ($null -ne $target) { $target.Dispose(); $target = $null }
            Clear-LineProgress
            try { Remove-TreeSafely $partial } catch { }
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
function Read-LimitedContent($Response, [long]$Size) {
    # The whole body in memory, never more than the expected size (null when it is bigger or the length header differs).
    $length = $Response.Content.Headers.ContentLength
    if ($null -ne $length -and $length -ne $Size) { return $null }
    $source = $Response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    try {
        $memory = New-Object IO.MemoryStream
        $chunk = New-Object byte[] 65536
        while (($read = $source.Read($chunk, 0, $chunk.Length)) -gt 0) {
            $memory.Write($chunk, 0, $read)
            if ($memory.Length -gt $Size) { return $null }
        }
        return ,($memory.ToArray())
    } finally { $source.Dispose() }
}
function Save-SmallDownloads($Client, $Steps) {
    # Files up to 4 MB (installer scripts, documents) are requested six at a time: one after another every GitHub download
    # (a redirect, then the file) takes about 0.3 s. Each file gets the same size and SHA-256 check; a file that fails here
    # is fetched once more on its own by Save-VerifiedDownload (three attempts, clear error text).
    $queue = @($Steps)
    for ($start = 0; $start -lt $queue.Count; $start += 6) {
        $pending = @()
        foreach ($step in $queue[$start..([Math]::Min($start + 5, $queue.Count - 1))]) {
            $task = $null
            try { $task = $Client.GetAsync((Assert-Url $step.Entry.Url), [Net.Http.HttpCompletionOption]::ResponseHeadersRead) } catch { $task = $null }
            $pending += [pscustomobject]@{ Step = $step; Task = $task }
        }
        foreach ($item in $pending) {
            $step = $item.Step
            $saved = $false
            $response = $null
            try {
                if ($null -ne $item.Task) {
                    $response = $item.Task.GetAwaiter().GetResult()
                    if ($response.IsSuccessStatusCode) {
                        $bytes = Read-LimitedContent $response $step.Entry.Size
                        if ($null -ne $bytes -and $bytes.Length -eq $step.Entry.Size -and (Get-BytesSha256 $bytes) -ceq $step.Entry.Sha256) {
                            $partial = $step.Destination + '.partial'
                            Remove-TreeSafely $partial
                            [IO.File]::WriteAllBytes($partial, $bytes)
                            Remove-TreeSafely $step.Destination
                            [IO.File]::Move($partial, $step.Destination)
                            $saved = $true
                        }
                    }
                }
            } catch { $saved = $false } finally { if ($null -ne $response) { $response.Dispose() } }
            if (-not $saved) { Save-VerifiedDownload $Client $step.Entry $step.Destination $step.Entry.Path }
            $script:ProgressBase += $step.Entry.Size
            $script:ProgressFiles++
            Show-LineProgress ('  files {0} / {1}' -f $script:ProgressFiles, $script:ProgressFileTotal)
            Write-InGameProgress $script:ProgressBase
        }
    }
    Clear-LineProgress
}
function Copy-Verified([string]$Source, $Entry, [string]$Destination) {
    $partial = $Destination + '.partial'
    Remove-TreeSafely $partial
    # Hashed while copying (one read of the game file); every package file is checked again from disk before the install.
    $in = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $sha = [Security.Cryptography.SHA256]::Create()
    $copied = 0L
    try {
        $out = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $chunk = New-Object byte[] 1048576
            while (($read = $in.Read($chunk, 0, $chunk.Length)) -gt 0) {
                $out.Write($chunk, 0, $read)
                [void]$sha.TransformBlock($chunk, 0, $read, $null, 0)
                $copied += $read
                if ($copied -gt $Entry.Size) { break }
            }
        } finally { $out.Dispose() }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
    } finally { $in.Dispose() }
    $copiedHash = ([BitConverter]::ToString($sha.Hash)).Replace('-', '').ToLowerInvariant()
    $sha.Dispose()
    if ($copied -ne $Entry.Size -or $copiedHash -cne $Entry.Sha256 -or (Get-Item -LiteralPath $partial -Force).Length -ne $Entry.Size) {
        Remove-TreeSafely $partial
        throw ('게임 폴더에서 가져온 파일의 확인 값이 다릅니다: ' + $Entry.Path)
    }
    Remove-TreeSafely $Destination
    [IO.File]::Move($partial, $Destination)
}
function Lock-PackageFiles($Steps) {
    # Re-verify every package file through a handle that denies writing, deleting and renaming, and keep the handles open
    # until the elevated install has finished: the installer then runs exactly the bytes checked here.
    $leases = New-Object 'Collections.Generic.List[IO.FileStream]'
    try {
        foreach ($step in $Steps) {
            if (Test-ReparsePoint $step.Destination) { throw ('패키지 파일이 링크로 바뀌어 있습니다: ' + $step.Entry.Path) }
            $stream = [IO.File]::Open($step.Destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $leases.Add($stream)
            if ($stream.Length -ne $step.Entry.Size -or (Get-StreamSha256 $stream) -cne $step.Entry.Sha256) { throw ('패키지 파일이 확인 뒤에 바뀌었습니다: ' + $step.Entry.Path) }
            $stream.Position = 0
        }
        return ,$leases
    } catch {
        foreach ($lease in $leases) { $lease.Dispose() }
        throw
    }
}
function Test-FmRunning {
    $list = [Diagnostics.Process]::GetProcessesByName('fm')
    try { return ($list.Length -gt 0) } finally { foreach ($process in $list) { $process.Dispose() } }
}
function Wait-KeyOrTimeout([int]$Seconds) {
    # After a finished in-game update: closes by itself (any key closes at once).
    try {
        for ($left = $Seconds; $left -gt 0; $left--) {
            [Console]::Write([char]13 + ('창은 ' + $left + '초 뒤 저절로 닫힙니다. 바로 닫으려면 아무 키나 누르세요.').PadRight(60))
            for ($tick = 0; $tick -lt 10; $tick++) {
                if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); [Console]::WriteLine(); return }
                Start-Sleep -Milliseconds 100
            }
        }
        [Console]::WriteLine()
    } catch { Start-Sleep -Seconds $Seconds }
}
function Wait-FmExit {
    # Continues at most a quarter of a second after fm.exe ends (waits on the process handle, no fixed pause). An ended
    # process can stay in the process list while another program still holds a handle to it: waits up to 5 seconds for that.
    $ended = $null
    while ($true) {
        $list = [Diagnostics.Process]::GetProcessesByName('fm')
        try {
            if ($list.Length -eq 0) { return }
            $live = @($list | Where-Object { $exited = $false; try { $exited = $_.HasExited } catch { $exited = $false }; -not $exited })
            if ($live.Count -gt 0) {
                $ended = $null
                try { [void]$live[0].WaitForExit(250) } catch { Start-Sleep -Milliseconds 250 }
            } else {
                if ($null -eq $ended) { $ended = [Diagnostics.Stopwatch]::StartNew() }
                if ($ended.ElapsedMilliseconds -ge 5000) { return }
                Start-Sleep -Milliseconds 100
            }
        } finally { foreach ($process in $list) { $process.Dispose() } }
    }
}

# ---- In-game notice link (optional BepInEx plugin TouchlineNoir.UpdateNotice) ----
function Find-InGameRequest([string[]]$GameFolders) {
    # The in-game notice's '업데이트하기' button leaves this file next to itself just before it asks Windows to open this tool.
    foreach ($folder in $GameFolders) {
        if (-not $folder) { continue }
        try {
            $notice = Join-Path $folder 'BepInEx\plugins\TouchlineNoir.UpdateNotice'
            $file = Join-Path $notice 'update-request.json'
            if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Test-ReparsePoint $notice) -or (Test-ReparsePoint $file)) { continue }
            if ((Get-Item -LiteralPath $file).Length -gt 4096) { continue }
            $request = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $id = [string](Get-Prop $request 'id')
            if ([string](Get-Prop $request 'action') -cne 'update' -or $id -cnotmatch '^[0-9a-f]{32}\z') { continue }
            $at = [DateTime]::Parse([string](Get-Prop $request 'requested_utc'), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
            $age = ([DateTime]::UtcNow - $at).TotalMinutes
            if ($age -lt -5 -or $age -gt 30) { continue }
            return [pscustomobject]@{ Folder = $notice; File = $file; Id = $id; Game = $folder }
        } catch { continue }
    }
    return $null
}
function Write-InGameStatus([string]$Stage, [string]$Text, [int]$Percent = -1) {
    # Progress for the in-game card (the plugin only shows this text). Best effort: never stops the updater.
    if ($null -eq $script:InGame) { return }
    try {
        $status = [ordered]@{ schema = 1; request = $script:InGame.Id; pid = $PID; stage = $Stage; text = $Text; percent = $Percent; updated_utc = [DateTime]::UtcNow.ToString('o') }
        $path = Join-Path $script:InGame.Folder 'update-status.json'
        $temporary = $path + '.tmp'
        [IO.File]::WriteAllText($temporary, ($status | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            try {
                # [NullString]::Value: PowerShell would pass $null to a .NET string parameter as an empty string (no backup file wanted).
                if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::Replace($temporary, $path, [System.Management.Automation.Language.NullString]::Value) } else { [IO.File]::Move($temporary, $path) }
                break
            } catch { if ($attempt -eq 5) { throw }; Start-Sleep -Milliseconds 40 }
        }
    } catch { }
}
function Write-InGameProgress([long]$Done, [switch]$Force) {
    if ($null -eq $script:InGame -or $script:ProgressTotal -le 0) { return }
    # FM closed while files are still coming: this window comes forward now, not only when the download is done.
    if (-not $script:WindowShown -and -not (Test-FmRunning)) { Show-UpdaterWindow }
    if (-not $Force -and ([DateTime]::UtcNow - $script:ProgressShown).TotalMilliseconds -lt 500) { return }
    $script:ProgressShown = [DateTime]::UtcNow
    $percent = [int][Math]::Min(100, [Math]::Floor(100.0 * $Done / $script:ProgressTotal))
    Write-InGameStatus 'downloading' ('새 버전 ' + $script:InGameVersion + ' 받는 중: ' + $percent + '% (' + (Format-Size $Done) + ' / ' + (Format-Size $script:ProgressTotal) + ', 파일 ' + $script:ProgressFiles + '/' + $script:ProgressFileTotal + '). FM은 계속 써도 됩니다.') $percent
}
function Complete-InGameRequest {
    # A request is used once: a later click-target run (a notification click, for example) is not taken for an in-game request.
    if ($null -eq $script:InGame) { return }
    try {
        if (Test-Path -LiteralPath $script:InGame.File -PathType Leaf) {
            $request = [IO.File]::ReadAllText($script:InGame.File, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if ([string](Get-Prop $request 'id') -ceq $script:InGame.Id) { Remove-Item -LiteralPath $script:InGame.File -Force }
        }
    } catch { }
}
function Initialize-WindowHelper {
    # Compiled while FM is still running, so the window can come forward without delay when FM closes.
    try {
        if (-not ('TouchlineNoir.UpdaterWindow' -as [type])) {
            Add-Type -Namespace TouchlineNoir -Name UpdaterWindow -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
'@
        }
    } catch { }
}
function Show-UpdaterWindow {
    # Opened from the in-game notice, this window starts minimized so it does not cover the game. Once FM is gone it comes
    # forward, so the administrator confirmation (UAC) opens in front instead of as a blinking taskbar button.
    if ($script:WindowShown) { return }
    $script:WindowShown = $true
    try {
        Initialize-WindowHelper
        $window = [TouchlineNoir.UpdaterWindow]::GetConsoleWindow()
        if ($window -eq [IntPtr]::Zero) { return }
        $owner = [TouchlineNoir.UpdaterWindow]::GetWindow($window, 4)
        if ($owner -ne [IntPtr]::Zero) { $window = $owner }
        [void][TouchlineNoir.UpdaterWindow]::ShowWindow($window, 9)
        [void][TouchlineNoir.UpdaterWindow]::SetForegroundWindow($window)
    } catch { }
}
function Save-VerifiedManifestCopy([byte[]]$Manifest, [byte[]]$Signatures, [string]$Directory) {
    # A copy of the verified update information for the optional in-game notice (BepInEx plugin). The plugin checks the
    # signature again itself, so FM never needs internet access of its own. Best effort: a failure never stops the updater.
    try {
        $directory = $Directory
        if (Test-ReparsePoint $directory) { Remove-TreeSafely $directory }
        Ensure-Directory $directory
        foreach ($item in @(@('noir-update.json.sigs', $Signatures), @('noir-update.json', $Manifest))) {
            $target = Join-Path $directory $item[0]
            $partial = $target + '.partial'
            Remove-TreeSafely $partial
            [IO.File]::WriteAllBytes($partial, [byte[]]$item[1])
            Remove-TreeSafely $target
            [IO.File]::Move($partial, $target)
        }
    } catch { Write-NotifyLog ('업데이트 정보 사본을 저장하지 못함: ' + $_.Exception.Message) }
}
function Get-CoreVersion([string]$Text) {
    if ($Text -match '^([0-9]+)\.([0-9]+)\.([0-9]+)') { return [Version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]) }
    return $null
}
function Read-Answer([string]$Prompt) {
    if ($Yes) { return 'Y' }
    return ([string](Read-Host $Prompt)).Trim()
}
function Read-JsonState([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try { $state = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json; if ($null -ne $state) { return $state } } catch { }
    }
    return (New-Object psobject)
}
function Save-JsonState([string]$Path, $State) {
    $temporary = $Path + '.tmp'
    [IO.File]::WriteAllText($temporary, ($State | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    [IO.File]::Move($temporary, $Path)
}
function Set-StateValue($State, [string]$Name, $Value) { $State | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force }

# ---- New-version notification (opt-in; everything lives in this Windows user account) ----
function Write-NotifyLog([string]$Text) {
    if (-not $script:NotifyLog) { return }
    try { [IO.File]::AppendAllText($script:NotifyLog, ([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $Text + "`r`n"), (New-Object Text.UTF8Encoding($false))) } catch { }
}
function Limit-NotifyLog {
    try {
        if ((Test-Path -LiteralPath $script:NotifyLog -PathType Leaf) -and (Get-Item -LiteralPath $script:NotifyLog).Length -gt 262144) {
            $keep = @([IO.File]::ReadAllLines($script:NotifyLog, [Text.Encoding]::UTF8) | Select-Object -Last 400)
            [IO.File]::WriteAllLines($script:NotifyLog, [string[]]$keep, (New-Object Text.UTF8Encoding($false)))
        }
    } catch { }
}
function Get-NotifyStatePath { return (Join-Path $CacheRoot 'notify.json') }
function Read-NotifyState { return (Read-JsonState (Get-NotifyStatePath)) }
function Save-NotifyState($State) { Save-JsonState (Get-NotifyStatePath) $State }
function Get-ScriptVersion([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
    $match = [regex]::Match([IO.File]::ReadAllText($Path), '(?m)^\$UpdaterVersion = ([0-9]+)')
    if ($match.Success) { return [int]$match.Groups[1].Value }
    return 0
}
function Get-ExtraArguments {
    # Only non-default settings are persisted, and only values that cannot break a command line.
    $extra = @()
    if (-not $CacheRoot.Equals($DefaultCacheRoot, [StringComparison]::OrdinalIgnoreCase)) { $extra += @('-CacheRoot', $CacheRoot) }
    if ($ManifestUrl -cne $DefaultManifestUrl) { $extra += @('-ManifestUrl', $ManifestUrl) }
    return ,$extra
}
function Sync-NotifyTool {
    # A stable copy that the scheduled check and the notification click use (the extracted folder may be moved or deleted).
    $tool = Join-Path $CacheRoot 'tool'
    if (Test-ReparsePoint $tool) { Remove-TreeSafely $tool }
    Ensure-Directory $tool
    $marker = Join-Path $tool $ToolMarker
    if (-not (Test-Path -LiteralPath $marker)) { [IO.File]::WriteAllText($marker, 'touchline-noir updater tool copy') }
    $toolScript = Join-Path $tool 'Update-TouchlineNoir.ps1'
    $self = [IO.Path]::GetFullPath($PSCommandPath)
    if (-not $self.Equals([IO.Path]::GetFullPath($toolScript), [StringComparison]::OrdinalIgnoreCase)) {
        if ((Get-ScriptVersion $toolScript) -le $UpdaterVersion) { Remove-TreeSafely $toolScript; Copy-Item -LiteralPath $self -Destination $toolScript -Force }
        $readme = Join-Path (Split-Path -Parent $self) 'README-UPDATER-KO.txt'
        if (Test-Path -LiteralPath $readme -PathType Leaf) { $toolReadme = Join-Path $tool 'README-UPDATER-KO.txt'; Remove-TreeSafely $toolReadme; Copy-Item -LiteralPath $readme -Destination $toolReadme -Force }
    }
    $launcher = Join-Path $tool 'Update-TouchlineNoir.cmd'
    $wanted = [Text.Encoding]::ASCII.GetBytes($LauncherText)
    $current = $(if ((Test-Path -LiteralPath $launcher -PathType Leaf) -and -not (Test-ReparsePoint $launcher)) { [IO.File]::ReadAllBytes($launcher) } else { [byte[]]@() })
    if (($current -join ',') -cne ($wanted -join ',')) { Remove-TreeSafely $launcher; [IO.File]::WriteAllBytes($launcher, $wanted) }
    return $tool
}
function Register-ProtocolHook {
    # The click target (notification click, in-game notice button): runs powershell.exe directly (no cmd.exe parsing);
    # Windows passes no URL text to it (no %1). Only what differs is rewritten.
    $toolScript = Join-Path (Join-Path $CacheRoot 'tool') 'Update-TouchlineNoir.ps1'
    $extra = Get-ExtraArguments
    $protocolKey = 'HKCU:\Software\Classes\' + $ProtocolName
    $commandKey = $protocolKey + '\shell\open\command'
    if (-not (Test-Path -LiteralPath $commandKey)) { [void](New-Item -Path $commandKey -Force) }
    if ([string](Get-Item -LiteralPath $protocolKey).GetValue('') -cne 'URL:Touchline Noir Update') { Set-Item -LiteralPath $protocolKey -Value 'URL:Touchline Noir Update' }
    [void](New-ItemProperty -LiteralPath $protocolKey -Name 'URL Protocol' -Value '' -PropertyType String -Force)
    $command = (ConvertTo-ArgumentText $PowerShellExe) + ' ' + (Join-ArgumentText (@('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $toolScript, '-FromProtocol') + $extra))
    if ([string](Get-Item -LiteralPath $commandKey).GetValue('') -cne $command) { Set-Item -LiteralPath $commandKey -Value $command }
}
function Register-NotifyHooks {
    # Writes the notification name, the click target and the scheduled check; only what differs is rewritten.
    $tool = Join-Path $CacheRoot 'tool'
    $toolScript = Join-Path $tool 'Update-TouchlineNoir.ps1'
    $extra = Get-ExtraArguments
    $appKey = 'HKCU:\Software\Classes\AppUserModelId\' + $AppId
    if (-not (Test-Path -LiteralPath $appKey)) { [void](New-Item -Path $appKey -Force) }
    [void](New-ItemProperty -LiteralPath $appKey -Name 'DisplayName' -Value '터치라인 누아르 스킨' -PropertyType String -Force)
    Register-ProtocolHook
    $arguments = '--headless ' + (Join-ArgumentText (@($PowerShellExe, '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $toolScript, '-NotifyCheck') + $extra))
    $conhost = Join-Path $SystemDirectory 'conhost.exe'
    $existing = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue
    if ($null -ne $existing -and @($existing.Actions).Count -eq 1 -and [string]$existing.Actions[0].Execute -ceq $conhost -and [string]$existing.Actions[0].Arguments -ceq $arguments) { return }
    $action = New-ScheduledTaskAction -Execute $conhost -Argument $arguments -WorkingDirectory $tool
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $logon.Delay = 'PT3M'
    $repeat = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(30)) -RepetitionInterval (New-TimeSpan -Hours 3)
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    [void](Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -Action $action -Trigger @($logon, $repeat) -Settings $settings -Principal $principal -Description '터치라인 누아르 스킨 새 버전 알림. 끄기: Update-TouchlineNoir.cmd -Notify Off' -Force)
}
function Initialize-Toast {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
}
function Show-NoirToast([string]$Title, [string]$Body1, [string]$Body2, [string]$Launch, [bool]$Silent) {
    Initialize-Toast
    $escape = [Security.SecurityElement]
    $xml = '<toast activationType="protocol" launch="' + $escape::Escape($Launch) + '" duration="long"><visual><binding template="ToastGeneric">' +
        '<text>' + $escape::Escape($Title) + '</text><text>' + $escape::Escape($Body1) + '</text><text>' + $escape::Escape($Body2) + '</text>' +
        '</binding></visual><actions>' +
        '<action content="업데이트 도구 열기" activationType="protocol" arguments="' + $ProtocolName + ':open"/>' +
        '<action content="바뀐 점 보기" activationType="protocol" arguments="' + $ReleasePage + '"/>' +
        '</actions></toast>'
    $document = New-Object Windows.Data.Xml.Dom.XmlDocument
    $document.LoadXml($xml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $document
    $toast.Tag = 'update'
    $toast.Group = 'touchline-noir'
    if ($Silent) { $toast.SuppressPopup = $true }
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
}
function Enable-Notify([string]$Game, [string]$ThemeName) {
    [void](Sync-NotifyTool)
    Register-NotifyHooks
    $state = Read-NotifyState
    Set-StateValue $state 'enabled' $true
    Set-StateValue $state 'declined' $false
    Set-StateValue $state 'game_path' $Game
    Set-StateValue $state 'theme' $ThemeName
    Set-StateValue $state 'enabled_at' ([DateTime]::UtcNow.ToString('o'))
    Save-NotifyState $state
    Good '새 버전 알림을 켰습니다. 로그인할 때와 3시간마다 확인하고, FM을 하는 동안에는 알리지 않습니다.'
    Note ('  끄려면: Update-TouchlineNoir.cmd -Notify Off   (작업 스케줄러 항목: ' + $TaskName + ')')
}
function Disable-Notify {
    try { Unregister-ScheduledTask -TaskName $TaskName -TaskPath '\' -Confirm:$false -ErrorAction Stop } catch { }
    foreach ($key in @(('HKCU:\Software\Classes\' + $ProtocolName), ('HKCU:\Software\Classes\AppUserModelId\' + $AppId))) {
        if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    }
    try { Initialize-Toast; [Windows.UI.Notifications.ToastNotificationManager]::History.Clear($AppId) } catch { }
    $state = Read-NotifyState
    Set-StateValue $state 'enabled' $false
    Save-NotifyState $state
    $tool = [IO.Path]::GetFullPath((Join-Path $CacheRoot 'tool'))
    $self = [IO.Path]::GetFullPath($PSCommandPath)
    if ((Test-Path -LiteralPath (Join-Path $tool $ToolMarker) -PathType Leaf) -and -not $self.StartsWith($tool + '\', [StringComparison]::OrdinalIgnoreCase)) { Remove-TreeSafely $tool }
    Good '새 버전 알림을 껐습니다. 작업 스케줄러 항목과 알림 등록을 지웠습니다.'
}
function Invoke-NotifyOffer([string]$Game, [string]$ThemeName) {
    if ($Yes -or $CheckOnly -or $PrepareOnly -or $NotifyCheck -or $null -ne $script:InGame) { return }
    try {
        $state = Read-NotifyState
        if ((Get-Prop $state 'enabled') -eq $true) {
            [void](Sync-NotifyTool)
            Register-NotifyHooks
            Set-StateValue $state 'game_path' $Game
            Set-StateValue $state 'theme' $ThemeName
            Save-NotifyState $state
            return
        }
        if ((Get-Prop $state 'declined') -eq $true) { return }
        Say ''
        Say '새 버전이 나오면 Windows 알림으로 알려 드릴까요?'
        Note '  로그인할 때와 3시간마다 업데이트 정보만 확인합니다. FM을 하는 동안에는 알리지 않습니다.'
        Note '  나중에 바꾸려면: Update-TouchlineNoir.cmd -Notify On  또는  -Notify Off'
        $answer = ([string](Read-Host '알림 켜기 (Y/N)')).Trim()
        if ($answer -match '^(y|yes|ㅛ|예|네)\z') { Enable-Notify $Game $ThemeName }
        else {
            Set-StateValue $state 'declined' $true
            Save-NotifyState $state
            Say '알림을 켜지 않았습니다.'
        }
    } catch { Warn ('알림을 설정하지 못했습니다: ' + (Get-ErrorText $_)) }
}

try {
    if (-not ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSEdition -ceq 'Desktop')) {
        throw 'Windows PowerShell 5.1에서 실행해 주세요. Update-TouchlineNoir.cmd를 두 번 클릭하면 됩니다.'
    }
    if (-not [Environment]::Is64BitProcess) { throw '64비트 Windows PowerShell에서 실행해 주세요. Update-TouchlineNoir.cmd를 두 번 클릭하면 됩니다.' }
    if ($Notify -and $Notify -notmatch '^(on|off)\z') { throw '-Notify 뒤에는 On 또는 Off 를 써 주세요.' }
    if (-not $CacheRoot) { $CacheRoot = $DefaultCacheRoot }
    if ($CacheRoot -match '["%\x00-\x1f]') { throw '-CacheRoot 값에 쓸 수 없는 문자(" % 또는 제어 문자)가 있습니다.' }
    $CacheRoot = [IO.Path]::GetFullPath($CacheRoot).TrimEnd('\')
    $cacheDrive = [IO.Path]::GetPathRoot($CacheRoot)
    if ($CacheRoot.Length -le 2 -or $cacheDrive -cnotmatch '^[A-Za-z]:\\\z' -or (New-Object IO.DriveInfo($cacheDrive)).DriveType -ne [IO.DriveType]::Fixed) {
        throw '-CacheRoot는 이 컴퓨터 고정 드라이브의 폴더(드라이브 맨 위 제외)여야 합니다.'
    }
    Ensure-Directory $CacheRoot
    if (-not $ManifestUrl) { $ManifestUrl = $DefaultManifestUrl }
    if ($ManifestUrl -match '["%\s]') { throw '-ManifestUrl 값에 쓸 수 없는 문자가 있습니다.' }
    [void](Assert-Url $ManifestUrl)
    if ($Notify -ieq 'off') { Disable-Notify; Stop-Updater 0 }
    $notifyState = Read-NotifyState
    $silentToast = (Get-Prop $notifyState 'silent_toast') -eq $true
    if ($NotifyCheck) {
        $logs = Join-Path $CacheRoot 'Logs'
        Ensure-Directory $logs
        $script:NotifyLog = Join-Path $logs 'notify.log'
        Limit-NotifyLog
        if ((Get-Prop $notifyState 'enabled') -ne $true) { Write-NotifyLog '알림이 꺼져 있어 확인하지 않음'; Stop-Updater 0 }
        if ((Test-FmRunning) -and (Get-Prop $notifyState 'notify_while_fm_running') -ne $true) { Write-NotifyLog 'FM 실행 중: 다음 확인 때 다시 봄'; Stop-Updater 0 }
        Write-NotifyLog ('확인 시작 (업데이트 도구 v' + $UpdaterVersion + ')')
        try { Register-NotifyHooks } catch { Write-NotifyLog ('알림 등록 갱신 실패: ' + (Get-ErrorText $_)) }
    } else {
        try {
            $logs = Join-Path $CacheRoot 'Logs'
            Ensure-Directory $logs
            Start-Transcript -LiteralPath (Join-Path $logs ('update-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.log')) | Out-Null
            $script:Transcript = $true
        } catch { }
        # One updater window at a time (the in-game button, a notification click and the .cmd can each open one).
        $script:SingleInstance = New-Object Threading.Mutex($false, 'Local\TouchlineNoir.SkinUpdater')
        $owned = $false
        try { $owned = $script:SingleInstance.WaitOne(0) } catch { $owned = ($_.Exception -is [Threading.AbandonedMutexException]) -or ($_.Exception.InnerException -is [Threading.AbandonedMutexException]) }
        if (-not $owned) {
            Warn '스킨 업데이트 도구가 이미 열려 있습니다. 열려 있는 창을 써 주세요.'
            $script:NoPause = [bool]$FromProtocol
            Stop-Updater 4
        }
        if ($FromProtocol) {
            $earlyState = Read-JsonState (Join-Path $CacheRoot 'updater-state.json')
            $script:InGame = Find-InGameRequest @([string](Get-Prop $earlyState 'last_game_path'), [string](Get-Prop $notifyState 'game_path'))
            if ($null -ne $script:InGame) {
                # The request's own game folder is the one to update.
                if (-not $GamePath) { $GamePath = $script:InGame.Game }
                try { $Host.UI.RawUI.WindowTitle = '터치라인 누아르 스킨 업데이트' } catch { }
                Write-InGameStatus 'starting' '업데이트 도구가 열렸습니다. 새 버전 정보를 확인하는 중...'
            }
        }
    }
    $interactive = -not ($Yes -or $NotifyCheck)

    Say ''
    Say ('터치라인 누아르 스킨 업데이트 도구 v' + $UpdaterVersion)
    Say '────────────────────────────────────────'
    $client = New-HttpClient
    Say '최신 버전 정보를 확인하는 중...'
    $verified = $false
    for ($attempt = 1; $attempt -le 2 -and -not $verified; $attempt++) {
        try {
            $manifestBytes = Get-SmallDownload $client $ManifestUrl 4MB
            $signatureBytes = Get-SmallDownload $client ($ManifestUrl + '.sigs') 64KB
        } catch {
            throw ('업데이트 정보를 받지 못했습니다. 인터넷 연결을 확인해 주세요. (' + (Get-ErrorText $_) + ')')
        }
        $verified = Test-ManifestSignatures $manifestBytes $signatureBytes
        if (-not $verified -and $attempt -eq 1) { Start-Sleep -Seconds 3 }
    }
    if (-not $verified) { throw '업데이트 정보의 서명이 맞지 않습니다. 아무 파일도 받지 않고 멈춥니다.' }
    $manifestText = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes).TrimStart([char]0xFEFF)
    $manifest = $manifestText | ConvertFrom-Json
    if ((Get-Prop $manifest 'schema') -ne 1 -or (Get-Prop $manifest 'product') -cne 'touchline-noir-skin') {
        throw '이 업데이트 도구가 읽을 수 없는 업데이트 정보입니다. GitHub 릴리스에서 TOUCHLINE-NOIR-UPDATER.zip을 새로 받아 주세요.'
    }
    $latestVersion = Get-Text $manifest 'version' '^[0-9]+\.[0-9]+\.[0-9]+\z'
    $latestDisplay = Get-Text $manifest 'display_version' '^V[0-9][0-9A-Za-z .-]*\z'
    $latestCore = Get-CoreVersion $latestVersion
    $manifestSha = Get-BytesSha256 $manifestBytes
    # Rollback protection: never accept an older signed manifest than one already seen with this cache.
    $updaterStatePath = Join-Path $CacheRoot 'updater-state.json'
    $updaterState = Read-JsonState $updaterStatePath
    $highestSeen = Get-CoreVersion ([string](Get-Prop $updaterState 'highest_manifest_version'))
    if ($null -ne $highestSeen -and $latestCore -lt $highestSeen) {
        throw ('전에 받은 업데이트 정보(V' + $highestSeen + ')보다 오래된 정보(V' + $latestCore + ')라 멈춥니다. 잠시 뒤 다시 실행해 주세요.')
    }
    if ($null -eq $highestSeen -or $latestCore -gt $highestSeen) {
        Set-StateValue $updaterState 'highest_manifest_version' $latestVersion
        Save-JsonState $updaterStatePath $updaterState
    }
    Good ('서명 확인 완료 · 공개 최신 버전: ' + $latestDisplay)
    Write-InGameStatus 'checking' ('공개 최신 버전 ' + $latestDisplay + ' 확인 · 설치된 스킨을 확인하는 중...')
    Save-VerifiedManifestCopy $manifestBytes $signatureBytes (Join-Path $CacheRoot 'latest')

    # The updater replaces only its own script (never the running .cmd launcher), then restarts once.
    $updaterInfo = Get-Prop $manifest 'updater'
    $newUpdater = 0; [void][int]::TryParse([string](Get-Prop $updaterInfo 'version'), [ref]$newUpdater)
    $minUpdater = 0; [void][int]::TryParse([string](Get-Prop $manifest 'min_updater_version'), [ref]$minUpdater)
    if (-not $NoSelfUpdate -and $newUpdater -gt $UpdaterVersion) {
        Say ('업데이트 도구 새 버전(v' + $newUpdater + ')을 먼저 받습니다.')
        Write-NotifyLog ('업데이트 도구 v' + $newUpdater + '로 바꿈')
        $selfDirectory = Split-Path -Parent $PSCommandPath
        $staging = Join-Path $CacheRoot 'updater'
        Ensure-Directory $staging
        $replaced = $false
        foreach ($item in @(Get-Prop $updaterInfo 'files')) {
            $entry = Get-Entry $item 'updater'
            if ($entry.Path -cnotin @('Update-TouchlineNoir.ps1', 'README-UPDATER-KO.txt')) { continue }
            $staged = Join-Path $staging ($entry.Sha256.Substring(0, 16) + '-' + $entry.Path)
            if (-not (Test-FileMatch $staged $entry.Sha256 $entry.Size)) { Save-VerifiedDownload $client $entry $staged $entry.Path }
            $destination = Join-Path $selfDirectory $entry.Path
            Remove-TreeSafely $destination
            Copy-Item -LiteralPath $staged -Destination $destination -Force
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
            if ($null -ne $script:SingleInstance) { try { $script:SingleInstance.ReleaseMutex() } catch { } }
            exit (Invoke-Child $PowerShellExe $forward)
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

    if (($NotifyCheck -or $FromProtocol) -and -not $GamePath) {
        # Opened by the scheduled check, a notification or the in-game notice: start from the game folder seen last time
        # (searching every library and app folder takes several seconds; the click target passes no arguments).
        foreach ($savedGame in @([string](Get-Prop $notifyState 'game_path'), [string](Get-Prop $updaterState 'last_game_path'))) {
            if ($savedGame -and (Test-Path -LiteralPath (Join-Path $savedGame 'fm.exe') -PathType Leaf)) { $GamePath = $savedGame; break }
        }
    }
    if ($GamePath) { Say '게임 폴더를 확인하는 중...' } else { Say '게임 폴더를 찾는 중... (드라이브의 게임 라이브러리를 확인합니다)' }
    if ($GamePath) {
        # Same explicit-path check as the installer (Resolve-GameSelection), without scanning every other install location.
        $found = @(Get-Fm27RootCandidates $GamePath.Trim().Trim('"') 'Explicit')
        if ($found.Count -ne 1) { throw '알려 준 경로에서 FM27을 찾지 못했습니다. fm.exe가 있는 폴더를 알려 주세요.' }
        $game = [string]$found[0].Path
    } else {
        $found = @(Get-Fm27Installations)
        if ($found.Count -eq 1) { $game = [string]$found[0].Path }
        elseif ($found.Count -eq 0) {
            if (-not $interactive) { throw 'FM27 설치 폴더를 찾지 못했습니다. -GamePath로 fm.exe가 있는 폴더를 알려 주세요.' }
            $answer = ([string](Read-Host 'FM27 설치 폴더(fm.exe가 있는 폴더)를 입력하세요')).Trim().Trim('"')
            $found = @(Get-Fm27RootCandidates $answer 'Explicit')
            if ($found.Count -ne 1) { throw '입력한 경로에서 FM27을 찾지 못했습니다.' }
            $game = [string]$found[0].Path
        } else {
            Say 'FM27 설치가 여러 개 있습니다:'
            for ($i = 0; $i -lt $found.Count; $i++) { Say ('  {0}) {1}  [{2}]' -f ($i + 1), $found[$i].Path, $found[$i].Source) }
            if (-not $interactive) { throw '여러 설치 중 하나를 -GamePath로 골라 주세요.' }
            $pick = 0
            if (-not [int]::TryParse(([string](Read-Host '번호를 고르세요')).Trim(), [ref]$pick) -or $pick -lt 1 -or $pick -gt $found.Count) { throw '잘못된 번호입니다.' }
            $game = [string]$found[$pick - 1].Path
        }
    }
    Say ('게임 폴더: ' + $game)
    if ([string](Get-Prop $updaterState 'last_game_path') -cne $game) {
        Set-StateValue $updaterState 'last_game_path' $game
        Save-JsonState $updaterStatePath $updaterState
    }
    # Security software may hide the user profile from fm.exe: the notice plugin's own folder is always readable by the game.
    $noticeFolder = Join-Path $game 'BepInEx\plugins\TouchlineNoir.UpdateNotice'
    if ((Test-Path -LiteralPath $noticeFolder -PathType Container) -and -not (Test-ReparsePoint $noticeFolder)) {
        Save-VerifiedManifestCopy $manifestBytes $signatureBytes (Join-Path $noticeFolder 'latest')
        # The notice's '업데이트하기' button opens this updater through the click target (no scheduled task is added).
        try { [void](Sync-NotifyTool); Register-ProtocolHook } catch { Write-NotifyLog ('업데이트 도구 연결을 등록하지 못함: ' + $_.Exception.Message) }
    }

    # Game build: the same four pinned loader identities the installer checks.
    $identityCache = @{}
    $build = $null
    foreach ($candidate in @(Get-Prop $manifest 'builds')) {
        $match = $true
        $identities = @(Get-Prop $candidate 'identity')
        if ($identities.Count -lt 1) { throw '업데이트 정보 형식이 올바르지 않습니다: identity' }
        foreach ($identity in $identities) {
            $relative = Get-Text $identity 'relative_path' $PathPattern
            $expected = Get-Text $identity 'sha256' '^[0-9a-f]{64}\z'
            if (-not $identityCache.ContainsKey($relative)) {
                $file = Join-Path $game $relative.Replace('/', '\')
                $identityCache[$relative] = $(if (Test-Path -LiteralPath $file -PathType Leaf) { Get-FileSha256 $file } else { '' })
            }
            if ($identityCache[$relative] -cne $expected) { $match = $false; break }
        }
        if ($match) { $build = $candidate; break }
    }
    if ($null -eq $build) {
        if ($NotifyCheck) {
            $buildMark = Get-BytesSha256 ([Text.Encoding]::ASCII.GetBytes((Get-FileSha256 (Join-Path $game 'fm.exe')) + (Get-FileSha256 (Join-Path $game 'GameAssembly.dll'))))
            if ((Get-Prop $notifyState 'notified_build') -cne $buildMark) {
                Show-NoirToast 'FM27 게임 빌드가 바뀌었습니다' '설치된 스킨이 지원하는 빌드와 다릅니다.' '이 빌드용 스킨이 나오면 다시 알려 드립니다.' $ReleasePage $silentToast
                Set-StateValue $notifyState 'notified_build' $buildMark
                Save-NotifyState $notifyState
                Write-NotifyLog '지원하지 않는 게임 빌드: 한 번 알림'
            } else { Write-NotifyLog '지원하지 않는 게임 빌드 (이미 알림)' }
            Stop-Updater 0
        }
        $supported = (@(Get-Prop $manifest 'builds') | ForEach-Object { 'Steam ' + (Get-Prop $_ 'game_build') }) -join ', '
        Warn ('이 FM27 빌드는 아직 지원하지 않습니다. 지원 빌드: ' + $supported)
        Warn 'FM27이 업데이트되었다면 그 빌드에 맞춘 스킨이 나올 때까지 기다려 주세요. 게임 파일은 바꾸지 않았습니다.'
        Write-InGameStatus 'error' '이 FM27 빌드는 아직 지원하지 않습니다. 이 빌드용 스킨이 나올 때까지 기다려 주세요. 게임 파일은 바꾸지 않았습니다.'
        Stop-Updater 2
    }
    $buildId = Get-Text $build 'game_build' '^[0-9]+\z'
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
    if ($receiptVersion -cmatch '-(classic|light)-windows\z') { $receiptTheme = $Matches[1].ToUpperInvariant() }
    if ($receiptAction -ceq 'Restore') { Say '설치 기록: 스킨을 되돌린 상태(원래 FM 화면)' }
    elseif ($receiptVersion) { Say ('설치 기록: ' + (Format-PackageVersion $receiptVersion)) }
    else { Say '설치 기록: 없음' }

    $themes = @((Get-Prop $build 'themes').PSObject.Properties | ForEach-Object { $_.Name })
    if ($NotifyCheck) {
        if ($receiptAction -ceq 'Restore') { Write-NotifyLog '스킨을 되돌린 상태: 알리지 않음'; Stop-Updater 0 }
        $chosen = $receiptTheme
        if (-not $chosen) { $chosen = [string](Get-Prop $notifyState 'theme') }
        if ($chosen -cnotin $themes) { Write-NotifyLog '테마를 알 수 없음: 알리지 않음'; Stop-Updater 0 }
    } elseif ($Theme) {
        $chosen = $Theme.Trim().ToUpperInvariant()
        if ($chosen -cnotin $themes) { throw ('테마는 ' + ($themes -join ' 또는 ') + ' 중에서 골라 주세요.') }
    } elseif ($receiptTheme -and $receiptAction -cne 'Restore' -and $receiptTheme -cin $themes) {
        $chosen = $receiptTheme
    } else {
        if (-not $interactive) { throw '설치된 테마를 알 수 없습니다. -Theme CLASSIC 또는 -Theme LIGHT로 골라 주세요.' }
        Say '설치할 테마를 고르세요:'
        for ($i = 0; $i -lt $themes.Count; $i++) { Say ('  {0}) {1}' -f ($i + 1), $themes[$i]) }
        $pick = 0
        if (-not [int]::TryParse(([string](Read-Host '번호')).Trim(), [ref]$pick) -or $pick -lt 1 -or $pick -gt $themes.Count) { throw '잘못된 번호입니다.' }
        $chosen = $themes[$pick - 1]
    }
    if ($Notify -ieq 'on') { Enable-Notify $game $chosen; Stop-Updater 0 }
    $package = Get-Prop (Get-Prop $build 'themes') $chosen
    $packageVersion = Get-Text $package 'package_version' '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)*-(classic|light)-windows\z'
    $packageDisplay = Get-Text $package 'display_name' '^V[0-9][0-9A-Za-z .-]*\z'

    $receiptStamp = $receiptVersion + '|' + [string](Get-Prop $receipt 'TimestampUtc') + '|' + $chosen
    if ($NotifyCheck -and (Get-Prop $notifyState 'ok_manifest') -ceq $manifestSha -and (Get-Prop $notifyState 'ok_receipt') -ceq $receiptStamp) {
        Write-NotifyLog ('최신 상태 그대로: ' + $packageDisplay)
        Stop-Updater 0
    }

    $entries = @(@(Get-Prop $package 'files') | ForEach-Object { Get-Entry $_ $chosen })
    if (@($entries | ForEach-Object { $_.Path.ToLowerInvariant() } | Select-Object -Unique).Count -ne $entries.Count) { throw '업데이트 정보에 같은 파일이 두 번 있습니다.' }
    $packagesRoot = Join-Path $CacheRoot 'packages'
    if (Test-ReparsePoint $packagesRoot) { Remove-TreeSafely $packagesRoot }
    $packageRoot = Join-Path $packagesRoot $packageVersion
    if (Test-ReparsePoint $packageRoot) { Remove-TreeSafely $packageRoot }
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
        $name = Get-Text $file 'name' '^[A-Za-z0-9._-]+\.bundle\z'
        $installedHash = Get-Text $file 'installed_sha256' '^[0-9a-f]{64}\z'
        $sourceHash = Get-Text $file 'source_sha256' '^[0-9a-f]{64}\z'
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
    $knownOlder = @($bundles | Where-Object { $_.State -cin @('stock', 'previous') })

    # A receipt that names a newer, non-public build is trusted only while no installed file is a known public or stock file
    # (the author's own test builds); a receipt that merely claims "newer" over known older files does not stop the update.
    $installedCore = Get-CoreVersion $receiptVersion
    if ($changing.Count -gt 0 -and $knownOlder.Count -eq 0 -and $null -ne $installedCore -and $installedCore -gt $latestCore -and $receiptAction -cne 'Restore') {
        if ($NotifyCheck) { Write-NotifyLog '설치된 스킨이 공개 최신보다 새 버전: 알리지 않음'; Stop-Updater 0 }
        Good ('설치된 스킨(' + (Format-PackageVersion $receiptVersion) + ')이 공개 최신 버전보다 새 버전입니다. 그대로 둡니다.')
        Stop-Updater 0
    }
    # A newer package whose skin files are all installed already (installer or documents only, e.g. V5.0.2 over V5.0.1) is
    # still an update: its installer runs once and the receipt then names the new version.
    $packageCore = Get-CoreVersion $packageVersion
    $toolsOnly = ($changing.Count -eq 0 -and $receiptAction -ceq 'Install' -and $receiptTheme -ceq $chosen -and $null -ne $installedCore -and
        $null -ne $packageCore -and $installedCore -lt $packageCore)
    $changeText = $(if ($toolsOnly) { '스킨 화면 파일은 그대로 · 설치 도구 업데이트' } else { '바뀌는 스킨 파일 ' + $changing.Count + '개' })

    if ($NotifyCheck) {
        if ($changing.Count -eq 0 -and -not $toolsOnly) {
            Set-StateValue $notifyState 'ok_manifest' $manifestSha
            Set-StateValue $notifyState 'ok_receipt' $receiptStamp
            Save-NotifyState $notifyState
            Write-NotifyLog ('최신: ' + $packageDisplay)
            Stop-Updater 0
        }
        $lastVersion = [string](Get-Prop $notifyState 'notified_version')
        $lastAt = [string](Get-Prop $notifyState 'notified_at')
        $recent = $false
        if ($lastVersion -ceq $packageVersion -and $lastAt) {
            try { $recent = ([DateTime]::UtcNow - [DateTime]::Parse($lastAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)).TotalHours -lt $RemindAfterHours } catch { $recent = $false }
        }
        if ($recent) { Write-NotifyLog ('새 버전 있음(' + $packageDisplay + '), 최근에 이미 알림'); Stop-Updater 0 }
        Show-NoirToast ('새 버전이 나왔습니다: ' + $packageDisplay) ('지금 설치된 버전: ' + (Format-PackageVersion $receiptVersion) + ' · ' + $changeText) '눌러서 업데이트 도구를 엽니다. 설치는 FM을 끈 뒤 진행됩니다.' ($ProtocolName + ':open') $silentToast
        Set-StateValue $notifyState 'notified_version' $packageVersion
        Set-StateValue $notifyState 'notified_at' ([DateTime]::UtcNow.ToString('o'))
        Save-NotifyState $notifyState
        Write-NotifyLog ('새 버전 알림: ' + $packageDisplay + ' (' + $changeText + ')')
        Stop-Updater 0
    }

    if ($changing.Count -eq 0 -and -not $toolsOnly) {
        Good ('이미 최신입니다: ' + $packageDisplay + ' (스킨 파일 ' + $bundles.Count + '개가 모두 같습니다)')
        if ($null -ne $script:InGame) {
            Write-InGameStatus 'latest' ('이미 최신입니다: ' + $packageDisplay + '. 설치할 것이 없습니다.')
            $script:NoPause = $true
        }
        Invoke-NotifyOffer $game $chosen
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
        if (-not $have -and $entry.Path -cmatch '^payload/([A-Za-z0-9._-]+\.bundle)\z') {
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
    if ($toolsOnly) { Say '스킨 화면 파일은 그대로이고, 설치 도구와 안내 문서가 바뀌었습니다.' }
    Say ('내려받을 크기: ' + (Format-Size $downloadBytes) + ' (파일 ' + $downloads.Count + '개)')
    $notes = @(Get-Prop $manifest 'notes_ko')
    if ($notes.Count -gt 0) {
        Say ''
        Say '바뀐 점:'
        foreach ($line in $notes) { Say ('  - ' + ([string]$line -replace '[\x00-\x1f]', ' ')) }
    }
    Say ''
    if ($CheckOnly) {
        Say '확인만 했습니다 (-CheckOnly). 게임 파일은 바꾸지 않았습니다.'
        Stop-Updater 0
    }
    if ($null -ne $script:InGame) {
        Say '게임 안 알림에서 "업데이트하기"를 눌렀습니다. 묻지 않고 새 버전을 준비합니다 (FM은 계속 써도 됩니다).'
    } else {
        $answer = Read-Answer '업데이트할까요? (Y/N)'
        if ($answer -notmatch '^(y|yes|ㅛ|예|네)\z') {
            Say '취소했습니다. 게임 파일은 바꾸지 않았습니다.'
            Stop-Updater 3
        }
    }

    $script:InGameVersion = $packageDisplay
    $script:ProgressTotal = $downloadBytes
    $script:ProgressBase = 0L
    $script:ProgressFiles = 0
    $script:ProgressFileTotal = $downloads.Count
    if ($downloadBytes -gt 0) { Write-InGameStatus 'downloading' ('새 버전 ' + $packageDisplay + ' 받는 중: 0% (0 B / ' + (Format-Size $downloadBytes) + ', 파일 0/' + $downloads.Count + '). FM은 계속 써도 됩니다.') 0 }
    else { Write-InGameStatus 'downloading' ('새 버전 ' + $packageDisplay + ' 준비 중...') }
    if ($null -ne $script:InGame) { Initialize-WindowHelper }
    $small = @()
    foreach ($step in $plan) {
        if ($step.Have) { continue }
        $parent = Split-Path -Parent $step.Destination
        if (Test-ReparsePoint $parent) { Remove-TreeSafely $parent }
        Ensure-Directory $parent
        if ($step.LocalSource) { Copy-Verified $step.LocalSource $step.Entry $step.Destination; Write-InGameProgress $script:ProgressBase }
        elseif ($step.Entry.Size -le 4MB) { $small += $step }
        else {
            Save-VerifiedDownload $client $step.Entry $step.Destination $step.Entry.Path
            $script:ProgressBase += $step.Entry.Size
            $script:ProgressFiles++
            Write-InGameProgress $script:ProgressBase -Force
        }
    }
    Save-SmallDownloads $client $small
    $script:ProgressTotal = 0L
    foreach ($step in $plan) {
        Remove-TreeSafely ($step.Destination + '.partial')
        if (-not (Test-FileMatch $step.Destination $step.Entry.Sha256 $step.Entry.Size)) { throw ('패키지 파일 확인 실패: ' + $step.Entry.Path) }
    }
    Good ('새 버전 패키지 준비 완료: ' + $packageRoot)
    if ($PrepareOnly) {
        Say '받아 두기만 했습니다 (-PrepareOnly). 위 폴더의 2-Install.cmd로 설치할 수 있습니다.'
        Stop-Updater 0
    }

    if (Test-FmRunning) {
        if ($null -ne $script:InGame) {
            Initialize-WindowHelper
            Write-InGameStatus 'ready' ('준비 완료: ' + $packageDisplay + '. 게임을 저장하고 FM을 종료하면 바로 설치합니다 (관리자 권한 확인 창에서 "예").') 100
        }
        Warn 'FM27이 실행 중입니다. FM을 종료하면 바로 설치를 시작합니다. (그만두려면 Ctrl+C)'
        Wait-FmExit
        Good 'FM27 종료 확인: 설치를 시작합니다.'
    }
    if ($null -ne $script:InGame) { Show-UpdaterWindow; Write-InGameStatus 'installing' ('설치 중: ' + $packageDisplay) }

    $launch = Join-Path $packageRoot 'Launch.ps1'
    $leases = Lock-PackageFiles $plan
    try {
        Say ''
        Say '설치 전 검사 (읽기만 함)...'
        $checkCode = Invoke-Child $PowerShellExe @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launch, '-Action', 'Check', '-GamePath', $game, '-NonInteractive', '-NoPause')
        if ($checkCode -ne 0) { throw '설치 전 검사에서 멈췄습니다. 위의 ERROR를 확인해 주세요. 게임 파일은 바꾸지 않았습니다.' }
        Say ''
        Say '설치합니다. 관리자 권한 확인 창(UAC)에서 "예"를 누르면 새 창에서 설치가 진행됩니다.'
        $installCode = Invoke-Child $PowerShellExe @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launch, '-Action', 'Install', '-GamePath', $game, '-NoPause')
    } finally {
        foreach ($lease in $leases) { $lease.Dispose() }
    }
    if ($installCode -ne 0) { throw ('설치가 끝나지 않았습니다 (코드 ' + $installCode + '). 관리자 권한 확인 창에서 "아니요"를 눌렀거나 설치 창에 ERROR가 있습니다. 설치 도구는 실패하면 바꾼 파일을 되돌립니다.') }

    $left = @($bundles | Where-Object { (Get-FileSha256 $_.Target) -cne $_.Installed })
    if ($left.Count -gt 0) { throw ('설치 후 확인에서 다른 파일이 있습니다: ' + (($left | ForEach-Object { $_.Name }) -join ', ')) }
    $after = $null
    try { $after = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $after = $null }
    if ([string](Get-Prop $after 'Version') -cne $packageVersion -or [string](Get-Prop $after 'Action') -cne 'Install') {
        throw '설치 후 확인에서 설치 기록이 새 버전을 가리키지 않습니다. 설치 창의 메시지를 확인해 주세요.'
    }
    Say ''
    Good ('업데이트 완료: ' + $packageDisplay)
    Write-InGameStatus 'done' ('업데이트 완료: ' + $packageDisplay)
    if ($null -ne $script:InGame) { $script:AutoClose = $true }
    Say ('이 버전의 설치 도구 폴더(되돌리기 3-Restore.cmd 포함): ' + $packageRoot)

    foreach ($old in @(Get-ChildItem -LiteralPath $packagesRoot -Force)) {
        if ($old.FullName -ieq $packageRoot) { continue }
        if (($old.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Remove-TreeSafely $old.FullName; continue }
        if ($old.PSIsContainer -and (Test-Path -LiteralPath (Join-Path $old.FullName $CacheMarker) -PathType Leaf)) {
            try { Remove-TreeSafely $old.FullName } catch { }
        }
    }
    Invoke-NotifyOffer $game $chosen
    Stop-Updater 0
} catch {
    $message = Get-ErrorText $_
    Write-NotifyLog ('오류: ' + $message)
    Write-InGameStatus 'error' ('업데이트하지 못했습니다: ' + $message)
    if ($null -ne $script:InGame -and -not (Test-FmRunning)) { Show-UpdaterWindow }
    Write-Host ''
    Write-Host ('오류: ' + $message) -ForegroundColor Red
    Stop-Updater 1
}
