# Build the Android APK and copy it to the parent folder as fukton-v<N>.apk.
# Each build raises the build number in pubspec.yaml, so the phone treats the
# new APK as an update and keeps all practice data. The number is also written
# to lib/version.dart so the app can show which build is installed.
# Gradle cannot run from a path with Thai characters, so the build goes through
# an ASCII junction (C:\Users\Acer\dev\fukton-app) that points at this folder.
# Keep this file ASCII-only: Windows PowerShell 5.1 misreads UTF-8 scripts
# without a BOM, which garbles Thai file names.
# Usage:  powershell -ExecutionPolicy Bypass -File build-apk.ps1 [-Install]
param([switch]$Install)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$junction = 'C:\Users\Acer\dev\fukton-app'
$flutter = 'C:\Users\Acer\dev\flutter\bin\flutter.bat'
$adb = 'C:\Users\Acer\dev\android-sdk\platform-tools\adb.exe'

$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot'
$env:ANDROID_HOME = 'C:\Users\Acer\dev\android-sdk'

if (-not (Test-Path $junction)) {
    New-Item -ItemType Junction -Path $junction -Target $here | Out-Null
}

# The APK is signed with this PC's debug key. An update only installs over the
# old app when it is signed with the same key, so keep a copy beside the code.
$key = Join-Path $env:USERPROFILE '.android\debug.keystore'
$backup = Join-Path $here 'android\signing-key-backup'
if ((Test-Path $key) -and -not (Test-Path (Join-Path $backup 'debug.keystore'))) {
    New-Item -ItemType Directory -Force $backup | Out-Null
    Copy-Item $key $backup
}

# Bump the build number: version: 1.0.0+N  ->  1.0.0+(N+1)
$utf8 = New-Object Text.UTF8Encoding $false
$pubspec = Join-Path $here 'pubspec.yaml'
$text = [IO.File]::ReadAllText($pubspec)
$m = [regex]::Match($text, '(?m)^version:\s*([\d.]+)\+(\d+)')
$name = $m.Groups[1].Value
$next = [int]$m.Groups[2].Value + 1
$text = $text.Remove($m.Index, $m.Length).Insert($m.Index, "version: $name+$next")
[IO.File]::WriteAllText($pubspec, $text, $utf8)
[IO.File]::WriteAllText((Join-Path $here 'lib\version.dart'),
    "// Written by build-apk.ps1 on every build.`nconst appVersion = '$name';`nconst appBuild = $next;`n", $utf8)
Write-Host "Build number $next"

Push-Location $junction
try {
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
    $apk = Join-Path $junction 'build\app\outputs\flutter-apk\app-release.apk'
    $parent = Split-Path $here -Parent
    # Remove older copies so only the newest APK sits in the folder.
    Get-ChildItem $parent -Filter 'fukton-v*.apk' | Remove-Item
    $out = Join-Path $parent "fukton-v$next.apk"
    Copy-Item $apk $out -Force
    Write-Host "APK: $out"
    if ($Install) {
        # -r replaces the installed app and keeps its data
        & $adb install -r $apk
    }
} finally {
    Pop-Location
}
