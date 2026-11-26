# No network calls or project changes. Run with the Windows Godot 4.7.2 console binary.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Select Godot 4.7.2 executable (prefer _console.exe)'
$dialog.Filter = 'Godot executable (*.exe)|*.exe'
if ($dialog.ShowDialog() -ne 'OK') { Write-Host 'Cancelled; no tests run.'; exit 2 }
$godot = $dialog.FileName
$python = Get-Command py.exe -ErrorAction SilentlyContinue
$pyArgs = @('-3')
if (-not $python) { $python = Get-Command python.exe -ErrorAction SilentlyContinue; $pyArgs = @() }
if (-not $python) { Write-Host 'Python 3 is required. Install from python.org or run Godot tests manually.'; exit 2 }
$log = Join-Path $root 'FRAMEGAUGE_QA.log'
# Native stderr may be reported as PowerShell errors; let the validator inspect it and exit code.
$ErrorActionPreference = 'Continue'
& $python.Source @pyArgs '-u' (Join-Path $PSScriptRoot 'validate.py') '--godot' $godot '--gui' 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
Write-Host "Log: $log"
if ($code -eq 0) { Write-Host 'Automated checks PASSED. Manual release checks are still required.' -ForegroundColor Green } else { Write-Host 'Automated checks FAILED. Do not publish.' -ForegroundColor Red }
exit $code
