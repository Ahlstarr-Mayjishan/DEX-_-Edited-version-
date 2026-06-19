$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$rustProject = Join-Path $root "rust_source_analyzer"
$pythonWorker = Join-Path $root "python\deep_source_analyzer.py"

if (-not (Test-Path -LiteralPath $pythonWorker)) {
    throw "Python worker not found: $pythonWorker"
}

"" | python $pythonWorker | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Python worker validation failed."
}

Push-Location $rustProject
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) {
        throw "Rust worker build failed."
    }
}
finally {
    Pop-Location
}

Write-Host "Helper workers are ready."
