<#
.SYNOPSIS
    Starts whisper-asr-webservice via docker compose, waits for it to become ready,
    rebuilds the client image only if client/ has changed (see rebuild-client.ps1), then
    runs the sample client (docker-compose.yml "client" service) against it.

.PARAMETER Gpu
    Use docker-compose.gpu.yml / the GPU service instead of the CPU one.

.EXAMPLE
    ./scripts/start-docker.ps1
    ./scripts/start-docker.ps1 -Gpu

    HF_TOKEN and other overrides: copy .env.example to .env and edit it first.
#>
param(
    [switch]$Gpu
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$composeFile = "docker-compose.yml"
$service = "whisper-asr-webservice"
if ($Gpu) {
    $composeFile = "docker-compose.gpu.yml"
    $service = "whisper-asr-webservice-gpu"
}

if (-not (Test-Path ".env") -and (Test-Path ".env.example")) {
    Write-Host "No .env found - copying .env.example to .env (edit it to set HF_TOKEN etc.)."
    Copy-Item ".env.example" ".env"
}

Write-Host "Starting $service ..."
docker compose -f $composeFile up -d --build $service

Write-Host "Waiting for $service to become ready..."
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/docs" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        # not ready yet
    }
    Start-Sleep -Seconds 5
}
if ($ready) {
    Write-Host "$service is ready."
} else {
    Write-Warning "$service did not respond after 5 minutes; attempting to run the client anyway."
}

& "$PSScriptRoot/rebuild-client.ps1" -Gpu:$Gpu

Write-Host "Running client against $service ..."
docker compose -f $composeFile run --rm client
