# Chay demo FitCenter: Face Service (face/) + kiosk Flutter. Chi dung cho may dev.
#   -Enroll <ma>  dang ky khuon mat bang webcam truoc khi chay (camera tu chup, khong can cham)
#   -Kiosk <duong-dan>  thu muc fitcenter_kiosk neu khong nam o cho mac dinh
#
# Can san: face\.venv (python -m venv face\.venv; face\.venv\Scripts\pip install -r face\requirements.txt),
# model BlazeFace/InsightFace da tai (xem face\README.md), va Flutter SDK (trong PATH hoac C:\src\flutter).
param([string]$Enroll, [string]$Kiosk)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$py = "$repo\face\.venv\Scripts\python.exe"
$envFile = "$repo\face\data\demo_env.ps1"

if (-not (Test-Path $py)) {
    throw "Chua co face\.venv. Xem face\README.md de cai moi truong Python."
}

# Tim thu muc kiosk: tham so -Kiosk, trong repo (sau khi frontend duoc merge), hoac git worktree song song.
$kioskCandidates = @(
    $Kiosk,
    "$repo\frontend\fitcenter_kiosk",
    (Join-Path (Split-Path $repo -Parent) 'Mat_troi_nho_nho_frontend\frontend\fitcenter_kiosk')
) | Where-Object { $_ }
$app = $kioskCandidates | Where-Object { Test-Path (Join-Path $_ 'pubspec.yaml') } | Select-Object -First 1

# Tim flutter: trong PATH, hoac C:\src\flutter.
$flutterCmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCmd) { $flutterCmd.Source } elseif (Test-Path 'C:\src\flutter\bin\flutter.bat') { 'C:\src\flutter\bin\flutter.bat' } else { $null }

Set-Location $repo
New-Item -ItemType Directory -Force "$repo\face\data" | Out-Null

# Khoa va token luu o face/data (da gitignore). Tao mot lan, lan sau dung lai.
if (-not (Test-Path $envFile)) {
    $key = & $py -c "import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
    $kiosk = & $py -c "import secrets;print(secrets.token_urlsafe(24))"
    $admin = & $py -c "import secrets;print(secrets.token_urlsafe(24))"
    @("`$env:FITCENTER_GALLERY_KEY = '$key'",
      "`$env:FITCENTER_KIOSK_TOKEN = '$kiosk'",
      "`$env:FITCENTER_ADMIN_TOKEN = '$admin'") | Set-Content $envFile -Encoding utf8
}
. $envFile

# Dong ban cu (kiosk, flutter, service) de khong tranh camera va cong 8750.
Get-Process fitcenter_kiosk -ErrorAction SilentlyContinue | Stop-Process -Force
Get-CimInstance Win32_Process -Filter "Name='dart.exe'" |
    Where-Object { $_.CommandLine -match 'flutter_tools' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$listener = netstat -ano | Select-String ':8750\s+.*LISTENING' | Select-Object -First 1
if ($listener) {
    Stop-Process -Id (($listener.ToString().Trim() -split '\s+')[-1]) -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
}

if ($Enroll) {
    Write-Host "Dang ky khuon mat cho '$Enroll': nhin thang vao camera, xoay dau nhe..."
    & $py -m face.prototype.enroll --member-id $Enroll
    if ($LASTEXITCODE -ne 0) { throw "Dang ky that bai" }
}
if (-not (Test-Path "$repo\face\data\gallery.enc")) {
    Write-Host "Chua co khuon mat nao duoc dang ky. Chay lai voi: -Enroll M001 (hoac dung nut dang ky tren kiosk)" -ForegroundColor Yellow
}

Write-Host 'Bat Face Service...'
$serviceLog = "$repo\face\data\service_err.txt"
$service = Start-Process $py -ArgumentList '-m', 'face.service' -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardError $serviceLog
try {
    $up = $false
    for ($i = 0; $i -lt 90 -and -not $up -and -not $service.HasExited; $i++) {
        Start-Sleep 1
        try { Invoke-RestMethod http://127.0.0.1:8750/v1/health -TimeoutSec 2 | Out-Null; $up = $true } catch { }
    }
    if (-not $up) {
        $reason = if (Test-Path $serviceLog) { (Get-Content $serviceLog -Tail 3) -join ' ' } else { '' }
        throw "Face Service khong len duoc. $reason"
    }

    if (-not $app -or -not $flutterPath) {
        if (-not $app) { Write-Host 'Khong tim thay thu muc kiosk Flutter (fitcenter_kiosk); dung -Kiosk <duong-dan>.' -ForegroundColor Yellow }
        if (-not $flutterPath) { Write-Host 'Khong tim thay Flutter SDK (flutter.bat).' -ForegroundColor Yellow }
        Read-Host 'Chi chay Face Service o 127.0.0.1:8750. Nhan Enter de tat'
        return
    }

    Write-Host 'Face Service san sang. Mo kiosk...'
    # flutter chay trong cua so rieng (khong dung terminal cua VS Code/PowerShell
    # Extension vi no coi chu flutter in ra la loi va dung script). Demo tren may
    # dev: nhung ca token Admin de trang dang ky khong hoi ma nua; ban that KHONG nhung.
    $flutterArgs = @(
        'run', '-d', 'windows',
        "--dart-define=FACE_KIOSK_TOKEN=$env:FITCENTER_KIOSK_TOKEN",
        "--dart-define=FACE_ADMIN_TOKEN=$env:FITCENTER_ADMIN_TOKEN",
        '--dart-define=FACE_SERVICE_URL=http://127.0.0.1:8750'
    )
    $flutter = Start-Process -FilePath $flutterPath -ArgumentList $flutterArgs -WorkingDirectory $app -PassThru
    Write-Host 'Dang build kiosk (khoang 30-60 giay), cua so kiosk se tu hien. Dong cua so flutter de thoat.'
    $flutter.WaitForExit()
} finally {
    Stop-Process -Id $service.Id -Force -ErrorAction SilentlyContinue
}
