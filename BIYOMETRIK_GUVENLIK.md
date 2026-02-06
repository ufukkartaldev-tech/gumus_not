# 🔐 Biyometrik Güvenlik (Parmak İzi / Yüz Tanıma)

GümüşNot, özel kasanızdaki (Gizli Kasa) hassas notlarınızı korumak için cihazınızın biyometrik doğrulama sistemlerini kullanır.

## ✨ Özellikler

*   **Hızlı Kasa Erişimi:** Uzun şifreler girmek yerine parmak izi veya yüz tanıma ile saniyeler içinde kasanızı açın.
*   **Tam Güvenlik:**
    *   Kasa şifreniz, cihazınızın güvenli çipinde (Secure Storage / Keychain) son derece güvenli bir şekilde saklanır.
    *   Bu şifreye sadece biyometrik doğrulama başarılı olduğunda erişilir.
*   **İsteğe Bağlı Seçim:** Biyometrik girişi istediğiniz zaman etkinleştirebilir veya devre dışı bırakabilirsiniz.

## 🚀 Nasıl Kullanılır?

### Etkinleştirme
1.  **Gizli Kasa**'yı açın.
2.  İlk kez şifre belirlerken veya başarılı bir girişten sonra sistem size "Biyometrik Giriş Etkinleştirilsin mi?" diye soracaktır.
3.  **"Evet"** diyerek onaylayın.

### Kullanım
1.  Kasa ekranına geldiğinizde **"Biyometrik Giriş"** butonunu göreceksiniz.
2.  Butona basın veya uygulama açılışında otomatik çıkan pencerede kimliğinizi doğrulayın.
3.  Doğrulama başarılı olduğunda kasanız otomatik olarak açılır.

### Desteklenen Yöntemler

Platform | Yöntem | Durum
--- | --- | ---
**Android** | Parmak İzi, Yüz Tanıma, İris | ✅ Aktif
**iOS** | Touch ID, Face ID | ✅ Aktif
**Windows** | Windows Hello (PIN/Yüz/Parmak) | 🚧 Hazırlanıyor

## 🔧 Teknik Detaylar

Özellik | Açıklama
--- | ---
**Kütüphane** | `local_auth` + `flutter_secure_storage`
**Şifre Saklama** | Android Keystore / iOS Keychain
**Şifreleme** | AES-256 (Şifre saklanırken otomatik şifrelenir)

## ⚠️ Güvenlik Notları

*   Biyometrik giriş, cihazınızdaki *herhangi* bir kayıtlı parmak izi veya yüz ile çalışır. Cihazınızı başkalarıyla paylaşıyorsanız ve onların biyometrik verileri de kayıtlıysa, kasanızı açabilirler.
*   Şifrenizi unutursanız ve biyometrik giriş çalışmazsa, **Kurtarma Anahtarı** dışında verilerinize erişmenin **HİÇBİR YOLU YOKTUR**. Kurtarma anahtarınızı mutlaka saklayın.

## ❓ Sorun Giderme

**Soru:** "Biyometrik donanım bulunamadı" hatası alıyorum.
**Çözüm:** Cihazınızda parmak izi veya yüz tanıma sensörü olduğundan ve en az bir biyometrik verinin kayıtlı olduğundan emin olun.

**Soru:** Biyometrik butonu görünmüyor.
**Çözüm:** Uygulama, cihazınızın donanım desteğini otomatik algılar. Donanım yoksa buton gizlenir.
