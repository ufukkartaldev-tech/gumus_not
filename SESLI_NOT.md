# 🎤 Sesli Not Alma Özelliği

GümüşNot artık **yapay zeka (AI) olmadan**, tamamen cihazınızın yerleşik konuşma tanıma motorunu kullanarak sesli not almanıza olanak tanır!

## ✨ Özellikler

*   **Offline Çalışma:** İnternet bağlantısı olmadan da çalışabilir (Cihaz desteğine bağlı).
*   **Ücretsiz:** Herhangi bir API anahtarı veya abonelik gerektirmez.
*   **Gerçek Zamanlı Yazma:** Konuştukça metin anında editöre eklenir.
*   **Otomatik Duraklatma:** Konuşmayı kestiğinizde otomatik olarak durur.
*   **Gizlilik Dostu:** Ses verileriniz üçüncü taraf sunuculara (OpenAI, Google Web API vb.) gönderilmez, cihazınızda işlenir.

## 🚀 Nasıl Kullanılır?

1.  Not editörünü açın.
2.  Alt araç çubuğunda bulunan **Mikrofon** simgesine dokunun.
3.  İlk kullanımda **Mikrofon İzni** isteyecektir, "İzin Ver" diyerek onaylayın.
4.  Konuşmaya başlayın! Söyledikleriniz imlecin olduğu yere yazılacaktır.
5.  Durdurmak için tekrar mikrofon simgesine dokunun veya bir süre sessiz kalın.

## 📋 Gereksinimler

Feature | Android | iOS | Windows/macOS/Linux
--- | --- | --- | ---
**Destek** | ✅ (Google Speech) | ✅ (Apple Speech) | ✅ (Hazırlanıyor)
**İzinler** | Mikrofon | Mikrofon + Konuşma Tanıma | Mikrofon

### Önemli Notlar

*   **Android:** Google uygulaması yüklü ve güncel olmalıdır.
*   **iOS:** Ayarlar > Genel > Klavye > Dikte açık olmalıdır.
*   **Dil:** Cihazınızın sistem dili veya klavye dili varsayılan olarak kullanılır (Türkçe desteklenir).

## 🔧 Teknik Detaylar

Kullanılan paket: `speech_to_text`

Bu paket, platforma özgü (native) konuşma tanıma servislerini kullanır:
*   Android: `SpeechRecognizer`
*   iOS: `SFSpeechRecognizer`

## ⚠️ Sorun Giderme

**Soru:** "Mikrofon erişimi sağlanamadı" hatası alıyorum.
**Çözüm:** Cihaz ayarlarından GümüşNot uygulamasına mikrofon izni verildiğinden emin olun.

**Soru:** Konuşuyorum ama yazmıyor.
**Çözüm:** İnternet bağlantınızı kontrol edin (bazı cihazlar ilk indirme için internet ister) veya Google/Siri sesli yazma ayarlarını kontrol edin.
