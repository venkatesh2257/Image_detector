# Full local + continuous learning pipeline (Windows PowerShell)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
    Write-Host "Warning: GOOGLE_APPLICATION_CREDENTIALS not set — Firestore export may skip."
}

Write-Host "=== 1) Export Firestore + merge local assets ==="
python export_firestore_dataset.py

Write-Host "=== 2) Build datasets (QA, balance, split) ==="
python dataset_manager.py

Write-Host "=== 3) Calibrate Milk Mirror ==="
python calibrate_milk_mirror.py

Write-Host "=== 4) Auto retrain (smart deploy) ==="
python auto_retrain.py --force

Write-Host "Done. Restart Flutter app to load new on-device model."
