<#
  YıldızDesk güncelleyicisini bu bilgisayara kurar (BİR KEZ; tekrar çalıştırmak güvenlidir, günceller).
  Yönetici (UAC) olarak çalıştırın:  powershell -ExecutionPolicy Bypass -File .\guncelleyici-kur.ps1

  Yaptıkları:
    1. C:\ProgramData\YildizDesk\ klasörünü oluşturur; YALNIZCA SYSTEM ve Yöneticiler yazabilir (güncelleme dosyası bu klasörde doğrulanıp çalıştırılır;
       sıradan bir kullanıcı araya dosya koyamasın diye). Kimlikler dile bağlı olmasın diye SID ile verilir.
    2. yildizdesk-guncelle.ps1'i (bu betiğin yanındaki dosya) oraya kopyalar.
    3. "YildizDesk Guncelle" görevini SYSTEM olarak kaydeder: açılıştan 3 dk sonra + her 6 saatte bir.

  -KuruDeneme  : hiçbir şey değiştirmez, neyi oluşturacağını yazar (yönetici izni de gerekmez).
  -Kaldir      : görevi siler (klasör ve günlük kalır).
  -SadeceEksikse : görev VE betik dosyası zaten varsa HİÇBİR ŞEYE dokunmaz (motorun kurulumu bunu kullanır: çalışan bir güncelleme
                   görevini silip yeniden yaratmak güncelleyiciyi ortasında öldürürdü). Biri eksikse ikisini de kurar/onarır.
  -DurumDeneme : yalnızca -KuruDeneme ile; -SadeceEksikse kararını denemek için 'kurulu' ya da 'eksik' varsayar (gerçek görev gerekmez).
  -BetikYolu   : güncelleyici betiğin yolu (varsayılan: bu betiğin yanındaki yildizdesk-guncelle.ps1)
#>
[CmdletBinding()]
param(
  [string]$BetikYolu = '',
  [switch]$KuruDeneme,
  [switch]$Kaldir,
  [switch]$SadeceEksikse,
  [ValidateSet('', 'kurulu', 'eksik')][string]$DurumDeneme = ''
)
$ErrorActionPreference = 'Stop'

# Varsayılan: bu betiğin yanındaki yildizdesk-guncelle.ps1. ($PSScriptRoot, Windows PowerShell 5.1'de param varsayılanında BOŞ gelir
# ve argümansız çalıştırmayı bozar; bu yüzden yol burada, gövdede çözülür.)
if (-not $BetikYolu) {
  $kok = $PSScriptRoot
  if (-not $kok) { $kok = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $BetikYolu = Join-Path $kok 'yildizdesk-guncelle.ps1'
}

$Veri = Join-Path $env:ProgramData 'YildizDesk'
$Hedef = Join-Path $Veri 'yildizdesk-guncelle.ps1'
$GorevAdi = 'YildizDesk Guncelle'
$SidSystem = '*S-1-5-18'          # NT AUTHORITY\SYSTEM
$SidYoneticiler = '*S-1-5-32-544' # BUILTIN\Administrators (Türkçe Windows'ta "Yöneticiler")

function Yonetici-Mi {
  $kimlik = [Security.Principal.WindowsIdentity]::GetCurrent()
  return ([Security.Principal.WindowsPrincipal]$kimlik).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($Kaldir) {
  if ($KuruDeneme) { Write-Host "[deneme] '$GorevAdi' görevi silinecekti."; return }
  if (-not (Yonetici-Mi)) { throw 'Yönetici (UAC) olarak çalıştırın.' }
  if (Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $GorevAdi -Confirm:$false
    Write-Host "Görev silindi: $GorevAdi" -ForegroundColor Green
  } else { Write-Host 'Görev zaten yok.' }
  return
}

# -SadeceEksikse: görev VE betik dosyası zaten varsa HİÇBİR ŞEYE dokunma. (Motorun kurulumu bunu kullanır: çalışan bir güncelleme
# görevini silip yeniden yaratmak güncelleyiciyi ortasında öldürürdü; geri alma/doğrulama yarım kalırdı.) Biri eksikse ikisi de kurulur.
# -DurumDeneme yalnızca -KuruDeneme ile geçerlidir (testlerde gerçek görev yokken iki durumu da dener).
if ($SadeceEksikse) {
  if ($KuruDeneme -and $DurumDeneme) { $durum = $DurumDeneme }
  elseif ((Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $Hedef)) { $durum = 'kurulu' }
  else { $durum = 'eksik' }
  if ($durum -eq 'kurulu') { Write-Host "Güncelleyici zaten kurulu; dokunulmadı. (Görev: $GorevAdi, betik: $Hedef)"; return }
}

if (-not (Test-Path -LiteralPath $BetikYolu)) { throw "Güncelleyici betik bulunamadı: $BetikYolu" }
$metin = [IO.File]::ReadAllText($BetikYolu)
$hatalar = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($metin, [ref]$null, [ref]$hatalar)
if ($hatalar -and $hatalar.Count -gt 0) { throw "Güncelleyici betikte söz dizimi hatası var: $($hatalar[0].Message)" }
if ($metin -notmatch '\$GuvenilenAnahtar\s*=\s*''<RSAKeyValue>') {
  throw 'Güncelleyici betiğe açık anahtar gömülü değil (önce anahtar-uret.ps1 -Gom). Anahtarsız betik kurulmaz.'
}

$arguman = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Hedef + '"'

if ($KuruDeneme) {
  Write-Host '[deneme] Hiçbir şey değiştirilmedi. Yapılacaklar:' -ForegroundColor Cyan
  Write-Host "  - Klasör    : $Veri  (yalnızca SYSTEM + Yöneticiler yazabilir)"
  Write-Host "  - Kopyalanan: $BetikYolu -> $Hedef"
  Write-Host "  - Görev     : '$GorevAdi' (SYSTEM) — açılıştan 3 dk sonra + her 6 saatte bir"
  Write-Host "  - Komut     : powershell.exe $arguman"
  return
}

if (-not (Yonetici-Mi)) { throw 'Yönetici (UAC) olarak çalıştırın.' }

# 1) klasör + kilitli izinler
New-Item -ItemType Directory -Force -Path $Veri | Out-Null
& icacls.exe $Veri /inheritance:r /grant:r "${SidSystem}:(OI)(CI)F" "${SidYoneticiler}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Klasör izinleri ayarlanamadı (icacls $LASTEXITCODE)." }

# 2) betiği kopyala (yeni dosya + yer değiştirme: yarım dosya kalmasın)
Copy-Item -LiteralPath $BetikYolu -Destination "$Hedef.yeni" -Force
Move-Item -LiteralPath "$Hedef.yeni" -Destination $Hedef -Force

# 3) SYSTEM görevi
$eylem = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguman
$acilis = New-ScheduledTaskTrigger -AtStartup
$acilis.Delay = 'PT3M'
$tekrar = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(10)) -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 3650)
$kimlik = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$ayar = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
Register-ScheduledTask -TaskName $GorevAdi -Action $eylem -Trigger @($acilis, $tekrar) -Principal $kimlik -Settings $ayar -Description 'YildizDesk otomatik guncelleme (imzali bildirim, asamali dagitim, otomatik geri alma)' -Force | Out-Null

Write-Host "Kuruldu: '$GorevAdi' görevi (SYSTEM). Betik: $Hedef" -ForegroundColor Green
Write-Host "Günlük : $(Join-Path $Veri 'guncelle.log')"
Write-Host "Denemek için (hiçbir şey değiştirmez):  powershell -ExecutionPolicy Bypass -File `"$Hedef`" -SadeceDenetle"
