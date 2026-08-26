<#
.SYNOPSIS
    Runs the sample client directly with Python (no Docker) - fast for local iteration.
    Creates/reuses a venv under client/.venv and (re)installs client/requirements.txt only
    when it has changed, then runs client/transcribe_client.py.

    Expects an ASR service already running (e.g. `poetry run whisper-asr-webservice` or
    `docker compose up whisper-asr-webservice`) at the server_url configured in
    client/config.yaml.

.EXAMPLE
    ./scripts/start-client.ps1
    ./scripts/start-client.ps1 --config other.yaml
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ClientArgs
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $repoRoot "client")

$venvDir = ".venv"
$marker = Join-Path $venvDir ".requirements.hash"

if (-not (Test-Path $venvDir)) {
    Write-Host "Creating venv at client/$venvDir ..."
    if (Get-Command py -ErrorAction SilentlyContinue) {
        py -3 -m venv $venvDir
    } else {
        python -m venv $venvDir
    }
}

$venvPython = Join-Path $venvDir "Scripts\python.exe"

$currentHash = (Get-FileHash -Path "requirements.txt" -Algorithm SHA256).Hash.ToLower()
$previousHash = $null
if (Test-Path $marker) {
    $previousHash = (Get-Content $marker -Raw).Trim()
}

if ($currentHash -ne $previousHash) {
    Write-Host "Installing client dependencies ..."
    & $venvPython -m pip install --quiet --upgrade pip
    & $venvPython -m pip install --quiet -r requirements.txt
    Set-Content -Path $marker -Value $currentHash -NoNewline
}

& $venvPython transcribe_client.py @ClientArgs
