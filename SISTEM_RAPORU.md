# GümüşNot — Sistem Analiz ve Mimari Durum Raporu

## 1. Sistem Özeti
**GümüşNot** (`connected_notebook`), Flutter ile geliştirilmiş, **yerel öncelikli (*Local-First*)**, çok platformlu bir Kişisel Bilgi Yönetimi (PKM) ve Zettelkasten not alma ekosistemidir.

* **Depolama Mimarisi**: `<Belgelerim>/GumusNot/notes/` altında YAML Frontmatter + Markdown (`.md`) dosyaları (`MarkdownNoteRepository`, `NoteMarkdownCodec`).
* **Bağlantılı Notlar (Zettelkasten)**: `[[WikiLink]]` çift yönlü bağlantılar, geri bağlantılar (`BacklinkService`), Hayalet Düğümler (`Ghost Nodes`) ve `Isolate` + `Quadtree` tabanlı 60 FPS Bilgi Grafiği.
* **Gizli Kasa (Vault)**: RFC 8018 `PBKDF2-HMAC-SHA256` (120.000 iterasyon) + `AES-256-GCM` zarf şifreleme (`NoteEncryptionService`, `.vault_key.json`).
* **Sürüm Kontrolü ve Yedekleme**: Yerel Git otomatik commit ve diff görüntüleme (`GitSyncService`), Google Drive `appDataFolder` üzerinde `AES-256-GCM` (`GNCB\x02`) şifreli bulut senkronizasyonu (`CloudSyncService`) ve `.zip` arşivleme.
* **Yapay Zekâ Asistanı**: Google Gemini ve OpenAI uyumlu (Ollama, LM Studio, DeepSeek, Groq) sağlayıcılarla RAG sohbet, özetleme, aksiyon çıkarımı ve 64-bit Charikar SimHash önbellekleme (`AiCacheService`).

---

## 2. Tamamlanan Kritik Mühendislik İyileştirmeleri

### A. SQLite'tan Yerel Markdown Dosya Mimarisine Geçiş
* **Önceki Durum**: Notlar kapalı bir `connected_notebook.db` SQLite veritabanında tutuluyordu; harici editörlerle düzenlenemiyor ve Git ile satır bazlı takip edilemiyordu.
* **Güncel Mimari**: Tüm notlar ve şablonlar YAML frontmatter içeren `.md` dosyalarına taşındı. `SqliteToMarkdownMigrator` eski SQLite verilerini ilk açılışta otomatik olarak `.md` dosyalarına aktarır. `WorkspaceService` dosya sistemini canlı izleyerek harici değişiklikleri anında yakalar.
* **CLI Uyumluluğu**: `bin/gumus_not.dart` komut satırı aracı da doğrudan `<Belgelerim>/GumusNot/notes/` altındaki `.md` dosyalarını `NoteMarkdownCodec` ile atomik olarak okuyup yazacak şekilde güncellendi.

### B. Endüstri Standardı Zarf Şifreleme (Envelope Encryption)
* **Önceki Durum**: Eski şifreleme yapısında anahtar türetimi ve kurtarma doğrulamasında deterministik olmayan zaman damgası hataları mevcuttu.
* **Güncel Mimari**: `NoteEncryptionService` ile 256-bit rastgele DEK üretilmekte, kullanıcı parolasından `PBKDF2-HMAC-SHA256` (120.000 iterasyon) ile türetilen KEK kullanılarak `AES-256-GCM` ile `.vault_key.json` içinde sarılmaktadır. Kasa kilitliyken yapılan not güncellemelerinde diskteki şifreli metnin (`enc:v1:...`) üzerine kilit yer tutucusunun yazılmasını önleyen koruma mevcuttur.

### C. Performans ve Eşzamanlılık (Concurrency) Optimizasyonları
* **Fizik Motoru ve TF-IDF Isolate Ayrımı**: Grafik fizik simülasyonu (`GraphPhysicsIsolate`) ve TF-IDF Kosinüs Benzerliği hesaplamaları (`CrossReferenceTracker`) arka plan `Isolate`'larına taşınarak ana UI thread'inde takılmalar önlendi.
* **Canlı Editör Sözdizimi Önbelleği**: `MarkdownLivePreviewController` içinde satır bazlı `InlineSpan` önbelleklemesi ve hızlı ASCII ön kontrolü uygulanarak uzun dökümanlarda yazma gecikmesi ortadan kaldırıldı.
* **Git Alt Süreç Senkronizasyonu**: `GitSyncService` içinde `Completer` tabanlı asenkron mutex kilidi ve 4 saniyelik debounce uygulanarak eşzamanlı kayıtlarda `.git/index.lock` çakışmaları engellendi.
