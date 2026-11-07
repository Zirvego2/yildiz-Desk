# YıldızDesk

YıldızDesk, [RustDesk](https://github.com/rustdesk/rustdesk) **1.5.1** sürümünün küçük değişikliklerle derlenmiş halidir.
Yıldız POS müşterilerine uzaktan destek vermek için kullanılır. Lisans: **AGPL-3.0** (bkz. `LICENCE`).
Orijinal telif ve lisans bildirimleri korunmuştur.

## Orijinalden farkı

İlk commit değiştirilmemiş RustDesk 1.5.1'dir; ikinci commit ile aradaki fark şudur:

- `libs/hbb_common/src/config.rs`: uygulama adı `YildizDesk`, kuruluş `com.yildizpos`, sunucu `destek.yildizpos.com`,
  sunucunun **açık** anahtarı, gömülü ayarlar (tek seferlik + sabit şifre, doğru şifrede ayrıca onay sorulmaz,
  sunucu/ağ ayarları gizli).
- `flutter/windows/runner/Runner.rc`: Windows dosya özelliklerinde ürün ve şirket adı.
- `.github/workflows/yildizdesk-windows.yml`: yalnızca Windows x64 için tek dosyalık `YildizDesk.exe` üreten iş akışı.
  Diğer platformların iş akışları ve `libs/hbb_common` alt modülü bağlantısı kaldırıldı (kod doğrudan dizin içinde).

Bu depoda **gizli bilgi yoktur**: sunucu anahtarı yalnızca açık anahtardır.

## Derleme

GitHub > Actions > **YildizDesk Windows x64** > *Run workflow*. Çıktı: `YildizDesk-windows-x64` (YildizDesk.exe).
