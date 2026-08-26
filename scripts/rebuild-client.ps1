<#
.SYNOPSIS
    Rebuilds the docker compose "client" image, but only if anything under client/
    (excluding client/output/) has changed since the last build. Safe/cheap to call
    on every startup — it no-ops when there's nothing to do.

.PARAMETER Gpu
    Use docker-compose.gpu.yml instead of docker-compose.yml.

.EXAMPLE
    ./scripts/rebuild-client.ps1
    ./scripts/rebuild-client.ps1 -Gpu
#>
param(
    [switch]$Gpu
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$composeFile = "docker-compose.yml"
if ($Gpu) {
    $composeFile = "docker-compose.gpu.yml"
}

$hashFile = "client/.docker-build-hash"

$files = Get-ChildItem -Path "client" -Recurse -File |
    Where-Object { $_.FullName -notmatch '[\\/]output[\\/]' -and $_.Name -ne ".docker-build-hash" } |
    Sort-Object FullName

$lines = foreach ($file in $files) {
    $fileHash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    "$fileHash  $($file.FullName)"
}
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
$currentHash = [System.BitConverter]::ToString($sha256.ComputeHash($bytes)).Replace("-", "").ToLower()

$previousHash = $null
if (Test-Path $hashFile) {
    $previousHash = (Get-Content $hashFile -Raw).Trim()
}

if ($currentHash -eq $previousHash) {
    Write-Host "client/ unchanged - skipping client image build."
    exit 0
}

Write-Host "client/ changed - building client image..."
docker compose -f $composeFile build client
Set-Content -Path $hashFile -Value $currentHash -NoNewline
