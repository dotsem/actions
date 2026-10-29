$ErrorActionPreference = "Stop"

$AppName = if ($env:APP_NAME) { $env:APP_NAME } else { "app" }
$BuildMode = if ($env:BUILD_MODE) { $env:BUILD_MODE } else { "release" }
$ModeSuffix = if ($env:MODE_SUFFIX) { $env:MODE_SUFFIX } else { "" }

New-Item -ItemType Directory -Force -Path dist | Out-Null

$runnerDir = Get-ChildItem -Path "build/windows/x64/runner" -Directory | Where-Object { $_.Name -like "*$BuildMode*" } | Select-Object -First 1
if (-not $runnerDir) {
  Write-Error "windows runner bundle directory for mode '$BuildMode' not found"
  exit 1
}

Compress-Archive -Path "$($runnerDir.FullName)/*" -DestinationPath "dist/${AppName}-windows${ModeSuffix}.zip" -Force
