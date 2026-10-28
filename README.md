# GümüşNot — Akıllı ve Bağlantılı Kişisel Bilgi Ağı (PKM)

GümüşNot, **Zettelkasten** metodolojisinden ilham alan, **yerel öncelikli (*Local-First*)** yaklaşımı benimseyen, çok platformlu ve kriptografik olarak güvenli bir bağlantılı not alma ekosistemidir. Notlarınızı kapalı bir veritabanına hapsetmek yerine dosya sisteminizde standart **YAML Frontmatter + Markdown (`.md`)** dosyaları olarak saklar ve birbirine bağlı bir **Kişisel Bilgi Ağı (*Personal Knowledge Graph*)** oluşturur.

---

## 🚀 Öne Çıkan Özellikler

### 1. Yerel Öncelikli (Local-First) Markdown Depolama ve Git Sürüm Kontrolü
* **Açık Dosya Formatı**: Tüm notlar `<Belgelerim>/GumusNot/notes/` dizininde insan tarafından okunabilir `.md` dosyaları (`NoteMarkdownCodec`) olarak saklanır; Obsidian, VS Code veya herhangi bir metin editörüyle doğrudan düzenlenebilir.
* **Canlı Klasör İzleme (`WorkspaceService`)**: Uygulama dışından `.md` dosyalarında yapılan değişiklikler `Directory.watch` ile gerçek zamanlı algılanır ve arayüze yansıtılır.
* **Otomatik Git Sürüm Geçmişi (`GitSyncService`)**: Çalışma dizininde yerel Git havuzu başlatılır; yapılan değişiklikler otomatik olarak commit'lenir ve uygulama içinden geçmiş (`git log`) ile satır bazlı farklar (`git diff`) incelenebilir.
* **Otomatik SQLite Göçü (`SqliteToMarkdownMigrator`)**: Eski sürümlerdeki `connected_notebook.db` SQLite veritabanı ilk açılışta otomatik ve kayıpsız olarak `.md` dosyalarına dönüştürülür.

### 2. Bağlantılı Not Mimarisi (Zettelkasten) ve Bilgi Grafiği
* **Çift Yönlü Bağlantılar (`[[WikiLink]]`)**: `[[Not Başlığı]]` veya `[[Not Başlığı|Görünen Ad]]` sözdizimi ile notlar arasında dinamik ilişkiler ve geri bağlantılar (*Backlinks*) kurulur. Bir notun başlığı değiştirildiğinde tüm çalışma alanındaki bağlantılar otomatik güncellenir.
* **60 FPS Kuvvet Yönelimli Grafik (`GraphPhysicsIsolate` & `Quadtree`)**: Arka plan `Isolate` iş parçacığında çalışan fizik motoru ve $O(N \log N)$ **Quadtree** uzamsal indeksleme ile binlerce düğümü akıcı şekilde görselleştirir.
* **Hayalet Düğümler (*Ghost Nodes*)**: Henüz oluşturulmamış ancak `[[Başlık]]` ile referans verilmiş kavramları grafikte tespit eder ve tek tıkla gerçek nota dönüştürür.
* **TF-IDF Çapraz Referans Önerileri (`CrossReferenceTracker`)**: Açık olan not ile diğer notlar arasındaki içerik benzerliğini **TF-IDF + Kosinüs Benzerliği** ile arka plan `Isolate`'ında hesaplayarak ilgili notları önerir.

### 3. Zarf Şifreleme (Envelope Encryption) ve Güvenlik
* **Gizli Kasa (`NoteEncryptionService`)**: Hassas notlar RFC 8018 **`PBKDF2-HMAC-SHA256` (120.000 iterasyon)** ile türetilen Anahtar Şifreleme Anahtarı (KEK) ve **`AES-256-GCM`** ile korunan 256-bit Veri Şifreleme Anahtarı (DEK) mimarisiyle (`.vault_key.json`) şifrelenir.
* **Biyometrik Uygulama Kilidi (`BiometricService`)**: Parmak izi, FaceID veya Windows Hello ile uygulama giriş koruması.
* **Şifreli Google Drive Bulut Yedekleme (`CloudSyncService`)**: Notlar istemci tarafında `AES-256-GCM` (`GNCB\x02` ikili zarf formatı) ile şifrelenerek Google Drive `appDataFolder` alanına yedeklenir.

### 4. Çoklu Sağlayıcı Yapay Zekâ Asistanı (`features/ai`)
* **Esnek LLM Desteği**: **Google Gemini** ve **OpenAI Uyumlu** tüm uç noktalarla (OpenAI, DeepSeek, Groq, yerel **Ollama** `http://localhost:11434/v1` ve **LM Studio**) çalışır.
* **RAG ve Akıllı Dönüşümler**: Bağlam-zenginleştirilmiş not sohbeti, özet çıkarma, aksiyon maddesi (`- [ ]`) tespiti, otomatik etiket önerisi ve akademik/profesyonel ton dönüşümü sunar.
* **Mahremiyet Korumalı SimHash Önbellek (`AiCacheService`)**: 64-bit **Charikar SimHash** yerel duyarlı karma (*Locality-Sensitive Hashing*) algoritması ile benzer sorguları API maliyeti olmadan yanıtlar; diskte hiçbir zaman düz metin not içeriği saklamaz.

### 5. Profesyonel Editör, Araçlar ve Dışa Aktarım
* **Canlı Önizlemeli Editör (`MarkdownLivePreviewController`)**: İmlecin bulunmadığı satırlarda Markdown işaretlerini gizleyerek anında biçimlendirilmiş metin sunar; **LaTeX/KaTeX** matematiksel formülleri (`$...$`, `$$...$$`), etkileşimli görev listelerini, **Slash (`/`)** komut menüsünü ve **Vim** klavye modunu (`NORMAL`/`INSERT`) destekler.
* **Sesli Dikte (`VoiceNoteService`)**: Mikrofon üzerinden Türkçe konuşmayı gerçek zamanlı metne dönüştürür.
* **Akademik LaTeX (`.tex`), PDF ve ZIP Çıktısı**: Notları tekli veya toplu olarak derlenmeye hazır **LaTeX** (`article`, `report`, `book`, `IEEEtran`), vektörel **PDF** veya tam `.zip` yedeği olarak dışa aktarır.
* **Terminal CLI Aracı (`bin/gumus_not.dart`)**: Terminalden doğrudan `<Belgelerim>/GumusNot/notes/` dizinine `.md` notu ekleme (`add`), pipe kaydetme (`save`), listeleme (`list`), okuma (`read`) ve arama (`search`).

---

## 🛠 Teknoloji Yığını

* **Framework & Dil**: Flutter (Material 3) & Dart SDK `^3.10.7`
* **Durum Yönetimi & DI**: `provider` + `NoteDependencyInjection`
* **Depolama**: YAML Frontmatter + Markdown (`yaml`, `path_provider`, `path`), `shared_preferences`
* **Güvenlik & Kriptografi**: `encrypt` (`AES-256-GCM`), `crypto` (`PBKDF2-HMAC-SHA256`), `flutter_secure_storage`, `local_auth`
* **Yapay Zekâ & Ağ**: `google_generative_ai`, `http` (HTTPS zorunlu uzak iletişim)
* **Bulut & Arşiv**: `google_sign_in`, `googleapis` (Drive v3), `googleapis_auth`, `archive`
* **Editör & Matematik**: `flutter_markdown`, `flutter_math_fork` (KaTeX), `flutter_highlighter`
* **Dışa Aktarım**: `pdf`, `printing`, `file_picker`
* **OS Entegrasyonları**: `speech_to_text`, `image_picker`, `home_widget`, `receive_sharing_intent`, `share_plus`, `args`

---

## ⚙️ Kurulum ve Çalıştırma

1. **Bağımlılıkları Yükleyin**:
   ```bash
   flutter pub get
   ```

2. **Uygulamayı Çalıştırın**:
   ```bash
   flutter run -d windows  # Windows Masaüstü
   flutter run -d android  # Android
   flutter run -d ios      # iOS
   flutter run -d macos    # macOS
   flutter run -d linux    # Linux
   ```

3. **Komut Satırı Aracını (CLI) Kullanın**:
   ```bash
   dart run bin/gumus_not.dart add --title "Toplantı Notu" --tag is,plan "Proje mimarisi tamamlandı #onemli"
   cat error.log | dart run bin/gumus_not.dart save --title "Sunucu Hatası" --tag error
   dart run bin/gumus_not.dart list --tag error
   dart run bin/gumus_not.dart read "Toplantı Notu"
   dart run bin/gumus_not.dart search "mimari"
   ```

4. **Testleri ve Analizi Çalıştırın**:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 📚 Mimari ve Teknik Belgeler

* **[Algoritma ve Mantık Dokümantasyonu](ALGORITMA_DOKUMAN.md)** — Fizik motoru, Quadtree, Zarf Şifreleme, SimHash, TF-IDF ve arama algoritmaları.
* **[Sistem Analiz Raporu](SISTEM_RAPORU.md)** — Sistem mimarisi, güvenlik katmanları ve tamamlanan mühendislik iyileştirmeleri.
* **[SOLID ve Temiz Mimari Rehberi](SOLID_MIGRATION_GUIDE.md)** — Katmanlı mimari, DI yapısı ve test stratejisi.
* **[Not Modülü Mimarisi](lib/features/notes/ARCHITECTURE.md)** — `features/notes` katman detayları.

---

## 📄 Lisans

Bu proje **MIT Lisansı** altında korunmaktadır. Detaylar için `LICENSE` dosyasına bakabilirsiniz.

Copyright (c) 2026 Ufuk Kartal.
