<#
  YıldızDesk güncelleyici — restoran bilgisayarında SYSTEM olarak, Görev Zamanlayıcı ("YildizDesk Guncelle") ile çalışır.
  Windows PowerShell 5.1 uyumludur. Kurulum: YıldızDesk 1.5.3 ve sonrasında motorla birlikte kendiliğinden; eski kurulumlarda
  Guncelleyici-Kur.cmd (UAC'li, bilgisayar başına bir kez).
  WMI/CIM KULLANMAZ: bazı bilgisayarlarda WMI takılır ve betik sonsuza dek beklerdi (Get-CimInstance yok; süreç komut satırı doğrudan okunur).

  Akış (her adım güvenli kapanır; şüphede GÜNCELLEME YAPILMAZ):
    1. Tek kopya kilidi (+ 0-10 dk rastgele gecikme: bilgisayarlar aynı anda sunucuya yüklenmesin)
    2. İmzalı bildirimi (yildizdesk.json + .imza) indir; GÖMÜLÜ açık anahtarla İMZAYI doğrula (RSA-SHA256). Geçersizse hiçbir şey yapılmaz.
    3. Paket/URL/SHA/boyut denetimi; kurulu sürümden YÜKSEK değilse çık (eski sürüme asla düşülmez)
    4. Aşamalı dağıtım kapısı: bu bilgisayarın YıldızDesk ID'sinin özeti % 100 < yuzde, ya da ID "kanarya" listesinde
    5. Açık uzak oturum varsa (YildizDesk.exe --cm süreci) ya da emin olunamıyorsa: bu tur atlanır
    6. Dosyayı kilitli klasöre indir; boyut + SHA-256 doğrula; kurulu klasörü YEDEKLE
    7. "YildizDesk.exe --update" (motorun kendi yerinde güncellemesi; klasörü silmez, servisi durdurup başlatır)
    8. Doğrula: servis çalışıyor + kayıt defterindeki sürüm yeni + YıldızDesk ID'si DEĞİŞMEMİŞ → olmazsa OTOMATİK GERİ AL
    Aynı sürüm için en çok 3 deneme. Günlük: %ProgramData%\YildizDesk\guncelle.log (1 MB'de döner).
    Güncelleyici betiğin kendisi de bildirimdeki "betik" alanıyla (imzalı + SHA-256) güncellenir.

  Deneme (HİÇBİR ŞEYİ DEĞİŞTİRMEZ):
    -SadeceDenetle         indirmeden/değiştirmeden ne yapacağını yazar. Aşağıdakiler YALNIZCA bununla geçerlidir:
    -AcikAnahtarDosyasi    güvenilen açık anahtarı (XML dosyası) geçici olarak değiştirir
    -BildirimAdresi        bildirimlerin okunacağı YEREL klasör (ağ yerine)
    -KurulanSurum / -DeskIdDeneme / -OturumVarDeneme   kurulu sürüm, ID ve açık oturum durumunu taklit eder
    -KomutSatiriDene <pid>  verilen sürecin komut satırını yazıp çıkar (açık-oturum denetiminin okuyucusunu denemek için)
    -OturumDene [-SurecAdiDene <ad>]  gerçek açık-oturum denetimini çalıştırıp "OTURUM-VAR: True/False" yazar ve çıkar
                            (-SurecAdiDene: bakılacak süreç adı; varsayılan YildizDesk)
#>
[CmdletBinding()]
param(
  [switch]$SadeceDenetle,
  [string]$AcikAnahtarDosyasi = '',
  [string]$BildirimAdresi = '',
  [string]$KurulanSurum = '',
  [string]$DeskIdDeneme = '',
  [switch]$OturumVarDeneme,
  [int]$KomutSatiriDene = 0,
  [string]$SurecAdiDene = '',
  [switch]$OturumDene
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Deneme parametreleri normal çalışmada ETKİSİZDİR (güvenilen anahtar/adres başka yere yönlendirilemez).
if (-not $SadeceDenetle) { $AcikAnahtarDosyasi = ''; $BildirimAdresi = ''; $KurulanSurum = ''; $DeskIdDeneme = ''; $OturumVarDeneme = $false; $KomutSatiriDene = 0; $SurecAdiDene = ''; $OturumDene = $false }

$BetikSurumu = '1.0.1'
$SurecAdi = 'YildizDesk'   # açık oturum (--cm) araması bu adlı süreçlerde yapılır
if ($SurecAdiDene) { $SurecAdi = $SurecAdiDene }
# ACIK-ANAHTAR-BASLA
$GuvenilenAnahtar = '<RSAKeyValue><Modulus>pcUD0Adc5Y2BjKlBMhnJ0rRBndajzrvnGT5cEA0voICc8qpShYasTFVO7w3VKFba3JLFgI2GLxMkUfpiRoyRd7MwfvVygksuUY8V6Q3SYrrseAYZS/2Zr6JUo7qhmeu3aDc9Tvl8OHv4pr1/c3U4p4D9Mk7A0yIU0iSUxYokOw15GqIdaBl1WGJFnFaZH8km4wZMsArpVxqcTS4h9zhzladqphhXr8C1P+ZS4aWCqUBKz8b6NUSvrVcSUClsgnG0l5gfblHcle4WG4CswfU4Is0BDjr40TWuswMi3Q+zPsOr2+zIaFvUnsnb411bHh8rsaY1EFDGJH9dxtW9EgGC05vc255PNrgsSKGQzIoGNI4Xj1SZQPp4TfZGocPOEqxSwsYp4hEA+CgWvMqJY2qBm5r0h9EcD2j8qg2gLEI0so6/eGKtkQzSr67FIM2Rhs/fEFoQKuprlAWGxDO5sp45yhmMmnnLtwMtS7Tf4IfVZ2dVAM7U31TzKZEMQqchkpMV</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
# ACIK-ANAHTAR-BITIS
$Taban = 'https://destek.yildizpos.com/guncelle'
$Veri = Join-Path $env:ProgramData 'YildizDesk'
$KurulumKlasoru = Join-Path $env:ProgramFiles 'YildizDesk'
$KurulanExe = Join-Path $KurulumKlasoru 'YildizDesk.exe'
$KayitAnahtari = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\YildizDesk'
$GunlukDosya = Join-Path $Veri 'guncelle.log'
$DenemeDosya = Join-Path $Veri 'denemeler.json'
$HizmetAdi = 'YildizDesk'
$EnCokDeneme = 3
$UrlDeseni = '^https://destek\.yildizpos\.com/guncelle/YildizDesk-\d+(\.\d+){2,3}\.exe$'
$BetikUrlDeseni = '^https://destek\.yildizpos\.com/guncelle/yildizdesk-guncelle-\d+(\.\d+){2,3}\.ps1$'

# Süreç komut satırını DOĞRUDAN Windows'tan okur (NtQueryInformationProcess, sınıf 60). WMI/CIM KULLANILMAZ: bazı bilgisayarlarda
# Get-CimInstance sonsuza dek takılır (gerçek bilgisayarda görüldü) ve "emin olamazsak güncelleme yapma" kuralı hiç devreye girmezdi.
# C# kaynağı bilerek yalnızca ASCII. Dönüş: komut satırı; okunamazsa null.
$SurecKodu = @'
using System;
using System.Runtime.InteropServices;
public static class YdSurec {
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h, int sinif, IntPtr tampon, int uzunluk, out int donen);
  [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint erisim, bool miras, int pid);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  public static string KomutSatiri(int pid) {
    IntPtr h = OpenProcess(0x1000, false, pid);  // PROCESS_QUERY_LIMITED_INFORMATION
    if (h == IntPtr.Zero) return null;
    try {
      int n; NtQueryInformationProcess(h, 60, IntPtr.Zero, 0, out n);  // 60 = ProcessCommandLineInformation; n = gereken boyut
      if (n <= 0 || n > 65536) return null;
      IntPtr b = Marshal.AllocHGlobal(n);
      try {
        if (NtQueryInformationProcess(h, 60, b, n, out n) < 0) return null;
        int uzunluk = (ushort)Marshal.ReadInt16(b);          // UNICODE_STRING.Length (bayt)
        IntPtr metin = Marshal.ReadIntPtr(b, IntPtr.Size);   // UNICODE_STRING.Buffer
        return metin == IntPtr.Zero ? "" : Marshal.PtrToStringUni(metin, uzunluk / 2);
      } finally { Marshal.FreeHGlobal(b); }
    } finally { CloseHandle(h); }
  }
}
'@

function Yaz([string]$Metin) {
  $satir = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Metin
  Write-Host $satir
  if ($SadeceDenetle) { return }
  try {
    if ((Test-Path -LiteralPath $GunlukDosya) -and ((Get-Item -LiteralPath $GunlukDosya).Length -gt 1MB)) { Move-Item -LiteralPath $GunlukDosya -Destination "$GunlukDosya.1" -Force }
    Add-Content -LiteralPath $GunlukDosya -Value $satir -Encoding UTF8
  } catch { }
}

function Imza-Dogru([byte[]]$Veri, [string]$ImzaB64, [string]$AnahtarXml) {
  if (-not $AnahtarXml) { return $false }
  $r = New-Object System.Security.Cryptography.RSACryptoServiceProvider
  $r.PersistKeyInCsp = $false
  try {
    $r.FromXmlString($AnahtarXml)
    $imza = [Convert]::FromBase64String($ImzaB64.Trim())
    # .NET: VerifyData(veri, İMZA, özet algoritması, dolgu)
    return $r.VerifyData($Veri, $imza, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
  } catch { return $false } finally { $r.Dispose() }
}

function Bildirim-Adresi([string]$Ad) {
  if ($BildirimAdresi) { return (Join-Path $BildirimAdresi $Ad) }
  return "$Taban/$Ad"
}

function Bayt-Al([string]$Adres) {
  if ($BildirimAdresi -and (Test-Path -LiteralPath $Adres)) { return , [IO.File]::ReadAllBytes($Adres) }
  $wc = New-Object System.Net.WebClient
  $wc.Headers['User-Agent'] = "YildizDeskGuncelle/$BetikSurumu"
  try { return , $wc.DownloadData($Adres) } finally { $wc.Dispose() }
}

function Surum-Cevir($Metin) {
  try { return [version]([string]$Metin) } catch { return $null }
}

function Kurulu-Surum {
  if ($KurulanSurum) { return [version]$KurulanSurum }
  try {
    $v = (Get-ItemProperty -Path $KayitAnahtari -Name DisplayVersion -ErrorAction Stop).DisplayVersion
    return [version]([string]$v)
  } catch { return $null }
}

function Desk-Id {
  if ($DeskIdDeneme) { return $DeskIdDeneme }
  try {
    $cikti = & $KurulanExe --get-id 2>$null | Out-String
    if ($cikti -match '(\d{6,12})') { return $Matches[1] }
  } catch { }
  return $null
}

function Oturum-Var {
  if ($OturumVarDeneme) { return $true }
  try {
    if (-not ('YdSurec' -as [type])) { Add-Type -TypeDefinition $SurecKodu -ErrorAction Stop }
    foreach ($s in [Diagnostics.Process]::GetProcessesByName($SurecAdi)) {
      $komut = [YdSurec]::KomutSatiri($s.Id)
      if ($null -eq $komut) {
        $bitti = $false
        try { $bitti = $s.HasExited } catch { }
        if ($bitti) { continue }   # arada kapanmış: sorun değil
        return $true               # okunamayan canlı süreç: emin olamayız
      }
      if ($komut -match '(^|\s)--cm(-no-ui)?(\s|"|$)') { return $true }
    }
    return $false
  } catch { return $true }   # emin olamazsak güncelleme YAPMA
}

function Asama-Izinli($DeskId, [int]$Yuzde, $Kanarya) {
  if ($DeskId -and ($Kanarya -contains $DeskId)) { return $true }
  if ($Yuzde -ge 100) { return $true }
  if ($Yuzde -le 0 -or -not $DeskId) { return $false }
  $ozet = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes($DeskId))
  return (([BitConverter]::ToUInt32($ozet, 0) % 100) -lt $Yuzde)
}

function Bildirim-Oku {
  $jsonB = Bayt-Al (Bildirim-Adresi 'yildizdesk.json')
  $imza = [Text.Encoding]::ASCII.GetString((Bayt-Al (Bildirim-Adresi 'yildizdesk.json.imza'))).Trim()
  $anahtar = $GuvenilenAnahtar
  if ($SadeceDenetle -and $AcikAnahtarDosyasi) { $anahtar = [IO.File]::ReadAllText($AcikAnahtarDosyasi) }
  if (-not (Imza-Dogru $jsonB $imza $anahtar)) { throw 'Bildirimin imzası geçersiz: güncelleme REDDEDİLDİ.' }
  $m = ([Text.Encoding]::UTF8.GetString($jsonB)) | ConvertFrom-Json
  if ($m.paket -ne 'yildizdesk') { throw "Yanlış paket: '$($m.paket)'" }
  $surum = Surum-Cevir $m.surum
  if (-not $surum) { throw "Sürüm okunamadı: '$($m.surum)'" }
  if (-not $BildirimAdresi -and ([string]$m.url) -notmatch $UrlDeseni) { throw "İndirme adresi izin verilen adres değil: '$($m.url)'" }
  if (([string]$m.sha256) -notmatch '^[0-9a-f]{64}$') { throw 'SHA-256 değeri geçersiz.' }
  $boyut = [long]$m.boyut
  if ($boyut -lt 5MB -or $boyut -gt 400MB) { throw "Dosya boyutu makul aralıkta değil: $boyut" }
  $yuzde = 100
  if ($m.PSObject.Properties['yuzde']) { $yuzde = [int]$m.yuzde }
  $kanarya = @()
  if ($m.PSObject.Properties['kanarya']) { $kanarya = @($m.kanarya | ForEach-Object { [string]$_ }) }
  $betik = $null
  if ($m.PSObject.Properties['betik'] -and $m.betik) {
    $bs = Surum-Cevir $m.betik.surum
    if ($bs -and ([string]$m.betik.url) -match $BetikUrlDeseni -and ([string]$m.betik.sha256) -match '^[0-9a-f]{64}$') {
      $betik = [pscustomobject]@{ Surum = $bs; Url = [string]$m.betik.url; Sha256 = [string]$m.betik.sha256 }
    }
  }
  return [pscustomobject]@{ Surum = $surum; Url = [string]$m.url; Sha256 = [string]$m.sha256; Boyut = $boyut; Yuzde = $yuzde; Kanarya = $kanarya; Betik = $betik }
}

function Betik-Guncelle($Betik) {
  if (-not $Betik) { return }
  if ($Betik.Surum -le [version]$BetikSurumu) { return }
  if ($SadeceDenetle) { Yaz "[denetle] güncelleyici betik güncellenecekti: $BetikSurumu -> $($Betik.Surum)"; return }
  try {
    $bayt = Bayt-Al $Betik.Url
    $hash = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bayt)) -replace '-', '').ToLowerInvariant()
    if ($hash -ne $Betik.Sha256) { Yaz 'Betik güncellemesi: SHA-256 uyuşmuyor, atlandı.'; return }
    $yeni = Join-Path $Veri 'yildizdesk-guncelle.ps1.yeni'
    [IO.File]::WriteAllBytes($yeni, $bayt)
    $hatalar = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($yeni, [ref]$null, [ref]$hatalar)
    if ($hatalar -and $hatalar.Count -gt 0) { Remove-Item -LiteralPath $yeni -Force; Yaz 'Betik güncellemesi: yeni betik söz dizimi denetimini geçmedi, atlandı.'; return }
    Move-Item -LiteralPath $yeni -Destination (Join-Path $Veri 'yildizdesk-guncelle.ps1') -Force
    Yaz "Güncelleyici betik güncellendi: $BetikSurumu -> $($Betik.Surum) (sonraki turda geçerli)"
  } catch { Yaz "Betik güncellemesi başarısız: $($_.Exception.Message)" }
}

function Denemeler-Oku {
  try { return (Get-Content -LiteralPath $DenemeDosya -Raw | ConvertFrom-Json) } catch { return $null }
}
function Deneme-Say([string]$Surum) {
  $d = Denemeler-Oku
  if ($d -and $d.PSObject.Properties[$Surum]) { return [int]$d.$Surum }
  return 0
}
function Deneme-Yaz([string]$Surum, [int]$Sayi) {
  $tablo = @{}
  $d = Denemeler-Oku
  if ($d) { foreach ($p in $d.PSObject.Properties) { $tablo[$p.Name] = $p.Value } }
  if ($Sayi -le 0) { $tablo.Remove($Surum) } else { $tablo[$Surum] = $Sayi }
  ($tablo | ConvertTo-Json -Compress) | Set-Content -LiteralPath $DenemeDosya -Encoding UTF8
}

function Hizmet-Calisiyor {
  try { return ((Get-Service -Name $HizmetAdi -ErrorAction Stop).Status -eq 'Running') } catch { return $false }
}

function Sonuc-Dogrula([version]$Beklenen, $EskiId) {
  $son = (Get-Date).AddSeconds(240)
  while ((Get-Date) -lt $son) {
    Start-Sleep -Seconds 6
    if (-not (Hizmet-Calisiyor)) { continue }
    $simdi = Kurulu-SurumKayitli
    if (-not $simdi -or $simdi -ne $Beklenen) { continue }
    $id = Desk-Id
    if ($EskiId -and $id -and $id -ne $EskiId) { return 'ID değişti' }
    if ($id) { return 'tamam' }
  }
  return 'zaman aşımı (hizmet çalışmıyor ya da sürüm değişmedi)'
}
function Kurulu-SurumKayitli {   # deneme taklidinden bağımsız: gerçek kayıt defteri
  try { return [version]([string](Get-ItemProperty -Path $KayitAnahtari -Name DisplayVersion -ErrorAction Stop).DisplayVersion) } catch { return $null }
}

function Geri-Al([string]$YedekKlasoru, [string]$EskiSurum) {
  Yaz 'GERİ ALINIYOR (yedekten)...'
  & sc.exe stop $HizmetAdi | Out-Null
  & taskkill.exe /F /IM YildizDesk.exe 2>$null | Out-Null
  Start-Sleep -Seconds 4
  & robocopy.exe $YedekKlasoru $KurulumKlasoru /E /IS /IT /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { Yaz "Geri alma: robocopy hata kodu $LASTEXITCODE" }
  try {
    Set-ItemProperty -Path $KayitAnahtari -Name DisplayVersion -Value $EskiSurum
    Set-ItemProperty -Path $KayitAnahtari -Name Version -Value $EskiSurum
  } catch { }
  & sc.exe start $HizmetAdi | Out-Null
  Start-Sleep -Seconds 12
  Yaz ("Geri alma sonucu: hizmet " + $(if (Hizmet-Calisiyor) { 'ÇALIŞIYOR' } else { 'ÇALIŞMIYOR (elle müdahale gerekebilir)' }))
}

function Guncelle([pscustomobject]$M, $EskiId, [version]$Kurulu) {
  $surumKlasoru = Join-Path (Join-Path $Veri 'guncelle') $M.Surum.ToString()
  New-Item -ItemType Directory -Force -Path $surumKlasoru | Out-Null
  $parca = Join-Path $surumKlasoru 'YildizDesk.exe.part'
  $hedef = Join-Path $surumKlasoru 'YildizDesk.exe'   # ad SABİT: uygulama kimliği dosya adından seçilir
  Yaz "İndiriliyor: $($M.Url)"
  $wc = New-Object System.Net.WebClient
  $wc.Headers['User-Agent'] = "YildizDeskGuncelle/$BetikSurumu"
  try { $wc.DownloadFile($M.Url, $parca) } finally { $wc.Dispose() }
  $boyut = (Get-Item -LiteralPath $parca).Length
  if ($boyut -ne $M.Boyut) { Remove-Item -LiteralPath $parca -Force; throw "İndirilen dosyanın boyutu uyuşmuyor ($boyut / $($M.Boyut))" }
  $hash = (Get-FileHash -LiteralPath $parca -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -ne $M.Sha256) { Remove-Item -LiteralPath $parca -Force; throw 'İndirilen dosyanın SHA-256 değeri uyuşmuyor: REDDEDİLDİ.' }
  Move-Item -LiteralPath $parca -Destination $hedef -Force
  Yaz 'Dosya doğrulandı (boyut + SHA-256).'

  $yedekKok = Join-Path $Veri 'yedek'
  $yedek = Join-Path $yedekKok $Kurulu.ToString()
  if (Test-Path -LiteralPath $yedekKok) { Get-ChildItem -LiteralPath $yedekKok -Directory | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
  New-Item -ItemType Directory -Force -Path $yedek | Out-Null
  & robocopy.exe $KurulumKlasoru $yedek /E /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Yedek alınamadı (robocopy $LASTEXITCODE): güncelleme iptal." }
  Yaz "Yedek alındı: $yedek"

  Yaz 'Güncelleme başlatılıyor (--update)...'
  $surec = Start-Process -FilePath $hedef -ArgumentList '--update' -PassThru -WindowStyle Hidden
  $null = $surec | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue
  $sonuc = Sonuc-Dogrula $M.Surum $EskiId
  if ($sonuc -eq 'tamam') {
    Yaz "GÜNCELLEME TAMAM: $Kurulu -> $($M.Surum)"
    Deneme-Yaz $M.Surum 0
    Get-ChildItem -LiteralPath (Join-Path $Veri 'guncelle') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $M.Surum.ToString() } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    return $true
  }
  Yaz "Güncelleme doğrulanamadı: $sonuc"
  Geri-Al $yedek $Kurulu.ToString()
  return $false
}

function Ana {
  $kurulu = Kurulu-Surum
  if (-not $kurulu) { Yaz 'YıldızDesk kurulu görünmüyor (kayıt defterinde sürüm yok): çıkılıyor.'; return 0 }

  try { $m = Bildirim-Oku } catch { Yaz "Bildirim kullanılamadı: $($_.Exception.Message)"; return 0 }
  Yaz "Kurulu sürüm: $kurulu | bildirimdeki sürüm: $($m.Surum) | betik: $BetikSurumu"
  Betik-Guncelle $m.Betik

  if ($m.Surum -le $kurulu) { Yaz 'Güncel: yapılacak bir şey yok.'; return 0 }

  $id = Desk-Id
  if (-not (Asama-Izinli $id $m.Yuzde $m.Kanarya)) { Yaz "Aşamalı dağıtım (%$($m.Yuzde)): bu bilgisayarın sırası henüz gelmedi."; return 0 }
  if (Oturum-Var) { Yaz 'Açık uzak oturum var (ya da emin olunamadı): bu tur atlandı.'; return 0 }
  $deneme = Deneme-Say $m.Surum.ToString()
  if ($deneme -ge $EnCokDeneme) { Yaz "Bu sürüm için $EnCokDeneme deneme yapıldı ve başarısız oldu: yeni bir sürüm bekleniyor."; return 1 }

  if ($SadeceDenetle) { Yaz "[denetle] GÜNCELLENECEKTİ: $kurulu -> $($m.Surum) (deneme $($deneme + 1)/$EnCokDeneme). Hiçbir şey değiştirilmedi."; return 0 }

  Deneme-Yaz $m.Surum.ToString() ($deneme + 1)
  try { if (Guncelle $m $id $kurulu) { return 0 } else { return 1 } }
  catch { Yaz "Güncelleme hatası: $($_.Exception.Message)"; return 1 }
}

# Güvenilen açık anahtar yoksa HİÇBİR ŞEY yapılmaz (güncelleme KAPALI): ne klasör oluşturulur ne beklenir.
if (-not $SadeceDenetle -and $GuvenilenAnahtar -notmatch 'RSAKeyValue') {
  Yaz 'Güvenilen açık anahtar gömülü değil: güncelleme KAPALI.'
  exit 2
}

# Deneme kancası (yalnızca -SadeceDenetle ile): verilen sürecin komut satırını yazıp çıkar; ağa/klasöre hiç dokunmaz.
if ($SadeceDenetle -and $KomutSatiriDene -gt 0) {
  Add-Type -TypeDefinition $SurecKodu
  $k = [YdSurec]::KomutSatiri($KomutSatiriDene)
  if ($null -eq $k) { Write-Host 'KOMUT-SATIRI: <okunamadi>' } else { Write-Host ('KOMUT-SATIRI: ' + $k) }
  exit 0
}
if ($SadeceDenetle -and $OturumDene) {
  Write-Host ('OTURUM-VAR: ' + (Oturum-Var))
  exit 0
}

# --- giriş: tek kopya kilidi + rastgele gecikme ---
$mutex = New-Object System.Threading.Mutex($false, 'Global\YildizDeskGuncelle')
$kilit = $false
try {
  try { $kilit = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $kilit = $true }
  if (-not $kilit) { Yaz 'Başka bir güncelleyici çalışıyor: çıkılıyor.'; exit 0 }
  if (-not $SadeceDenetle) {
    New-Item -ItemType Directory -Force -Path $Veri | Out-Null
    Start-Sleep -Seconds (Get-Random -Minimum 0 -Maximum 600)
  }
  $kod = Ana
  exit $kod
} catch {
  Yaz "Beklenmeyen hata: $($_.Exception.Message)"
  exit 1
} finally {
  if ($kilit) { try { $mutex.ReleaseMutex() } catch { } }
  $mutex.Dispose()
}
