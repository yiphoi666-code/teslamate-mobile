param(
  [string]$ApkPath = "dist\GarageLens-TeslaMate-v0.4.9-offline-resume-fix.apk",
  [string]$PackageName = "com.kaylabs.teslamate_mobile"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ResolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
  $ApkPath
} else {
  Join-Path $ProjectRoot $ApkPath
}

if (-not (Test-Path -LiteralPath $ResolvedApk)) {
  throw "APK not found: $ResolvedApk"
}

$XmlPath = Join-Path $ProjectRoot "build\adb-smoke-window.xml"
if (Test-Path -LiteralPath $XmlPath) {
  Remove-Item -LiteralPath $XmlPath -Force
}

adb shell am force-stop $PackageName | Out-Null
adb shell pm clear $PackageName | Out-Null
adb install -r $ResolvedApk | Out-Null
adb shell am start -n "$PackageName/.MainActivity" | Out-Null
Start-Sleep -Seconds 8

$xml = ""
for ($i = 1; $i -le 15; $i++) {
  Start-Sleep -Seconds 2
  cmd /c "adb shell uiautomator dump /sdcard/garage-lens-window.xml >nul 2>nul"
  if ($LASTEXITCODE -ne 0) {
    continue
  }

  cmd /c "adb pull /sdcard/garage-lens-window.xml `"$XmlPath`" >nul 2>nul"
  if ($LASTEXITCODE -ne 0) {
    continue
  }

  if (Test-Path -LiteralPath $XmlPath) {
    $xml = Get-Content -LiteralPath $XmlPath -Raw
    if ($xml.Contains("TeslaMate Reader API")) {
      break
    }
  }
}

if (-not $xml.Contains("TeslaMate Reader API")) {
  Start-Sleep -Seconds 5
  cmd /c "adb shell uiautomator dump /sdcard/garage-lens-window.xml >nul 2>nul"
  cmd /c "adb pull /sdcard/garage-lens-window.xml `"$XmlPath`" >nul 2>nul"
  if (Test-Path -LiteralPath $XmlPath) {
    $xml = Get-Content -LiteralPath $XmlPath -Raw
  }
}

if (-not $xml.Contains("TeslaMate Reader API")) {
  adb shell dumpsys window | Select-String -Pattern "mCurrentFocus|mFocusedApp"
  throw "Garage Lens UI did not become ready."
}

$checks = @(
  @("Connect Reader"),
  @("Data hidden"),
  @("TeslaMate Reader API"),
  @("Reader API URL"),
  @("Access token"),
  @("Test &amp; Save", "Test & Save")
)

$results = foreach ($aliases in $checks) {
  $found = $false
  foreach ($check in $aliases) {
    if ($xml.Contains($check)) {
      $found = $true
      break
    }
  }

  [PSCustomObject]@{
    Check = $aliases[0]
    Found = $found
  }
}

$results | Format-Table -AutoSize

if ($results.Found -contains $false) {
  throw "ADB smoke check failed."
}

Write-Host "ADB smoke check passed."
