# Full training pipeline: dataset → calibrate Milk Mirror → TFLite
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$python = "python"
if (Test-Path "..\venv\Scripts\python.exe") {
    $python = "..\venv\Scripts\python.exe"
}

Write-Host "=== 1/3 Prepare dataset from assets/images ===" -ForegroundColor Cyan
& $python prepare_dataset.py

Write-Host "`n=== 2/3 Calibrate Milk Mirror (liters from folder labels) ===" -ForegroundColor Cyan
& $python calibrate_milk_mirror.py

Write-Host "`n=== 3/3 Train TFLite (MobileNetV2) ===" -ForegroundColor Cyan
& $python train_model.py

Write-Host "`nDone. Restart the Flutter app (R) to load new model + calibration." -ForegroundColor Green
