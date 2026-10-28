# SOLID ve Temiz Mimari Rehberi (Clean Architecture Guide)

Bu belge, GümüşNot projesinde uygulanan **SOLID** prensiplerini, **Feature-First (Özellik Odaklı) Katmanlı Mimari** yapısını ve bağımlılık enjeksiyonu (`NoteDependencyInjection`) düzenini açıklar.

---

## 🎯 Uygulanan SOLID Prensipleri

### 1. Single Responsibility Principle (Tek Sorumluluk)
* **`MarkdownNoteRepository`** (`lib/features/notes/repositories/markdown_note_repository.dart`): Yalnızca `.md` dosyalarının disk üzerindeki CRUD operasyonlarından, `FileStat` önbelleğinden ve atomik yazmadan sorumludur.
* **`NoteMarkdownCodec` & `MarkdownFrontmatter`** (`lib/core/storage/`): Yalnızca `Note` nesneleri ile YAML Frontmatter + Markdown metni arasındaki serileştirme/ayrıştırma işlemlerini yürütür.
* **`NoteEncryptionService`** (`lib/core/security/note_encryption_service.dart`): Yalnızca `PBKDF2-HMAC-SHA256` anahtar türetimi ve `AES-256-GCM` zarf şifreleme operasyonlarını yönetir.
* **`BacklinkService`** (`lib/features/notes/services/backlink_service.dart`): Yalnızca `[[WikiLink]]` bağlantı grafiği analizi, kırık bağlantı tespiti ve başlık değişimlerinde bağlantı yayılımından sorumludur.
* **`AdvancedSearchService`** (`lib/features/notes/services/advanced_search_service.dart`): Yalnızca çok kriterli filtreleme, Levenshtein bulanık arama ve Zettelkasten semantik puanlamadan sorumludur.

### 2. Open/Closed & Liskov Substitution Principles (Açık/Kapalı ve Yerine Geçme)
* **`NoteRepository`** (`lib/features/notes/repositories/note_repository.dart`) soyut arayüzü; üretim ortamında `MarkdownNoteRepository`, birim ve widget testlerinde ise `MockNoteRepository` ile hiçbir üst katman kodu değiştirilmeden ikame edilebilir.
* **`IAiService`** (`lib/features/ai/services/iai_service.dart`) soyut arayüzü; `GeminiAiService` ve `OpenAiCompatibleService` tarafından gerçeklenir.

### 3. Interface Segregation & Dependency Inversion (Arayüz Ayrımı ve Bağımlılığın Tersine Çevrilmesi)
* Üst seviye durum yöneticileri (`NoteProvider`, `AiProvider`), somut sınıflara değil soyut arayüzlere (`NoteRepository`, `SearchService`, `IAiService`) bağımlıdır.
* Tüm bağımlılıklar `NoteDependencyInjection` (`lib/features/notes/di/note_dependency_injection.dart`) üzerinden merkezi olarak enjekte edilir.

---

## 📁 Güncel Dizin ve Katman Yapısı

```text
lib/
├── core/
│   ├── security/
│   │   └── note_encryption_service.dart      # AES-256-GCM + PBKDF2 Zarf Şifreleme
│   ├── storage/
│   │   ├── markdown_frontmatter.dart         # YAML Frontmatter kodlayıcı/çözücü
│   │   ├── note_markdown_codec.dart          # Note <-> .md dosya dönüştürücü
│   │   └── sqlite_to_markdown_migrator.dart  # Tek seferlik SQLite -> .md göç servisi
│   ├── theme/
│   │   ├── app_theme.dart                    # Material 3 tema tanımları
│   │   └── theme_provider.dart               # Tema ve tipografi durum yönetimi
│   └── utils/
│       ├── markdown_cleaner.dart             # Markdown düz metin ve hashtag çıkarıcı
│       └── shortcut_manager.dart             # Klavye kısayol yöneticisi
├── features/
│   ├── ai/                                   # Çoklu sağlayıcı LLM ve SimHash önbellek
│   ├── backup/                               # Google Drive v2 AES-GCM ve ZIP yedekleme
│   ├── calendar/                             # Takvim görünümü
│   ├── export/                               # PDF, LaTeX ve toplu dışa/içe aktarım
│   ├── graph/                                # Quadtree + Isolate fizik motoru ve graf UI
│   ├── home_widget/                          # Android/iOS ana ekran widget servisi
│   ├── media/                                # Görsel seçimi ve yerel medya yönetimi
│   ├── notes/
│   │   ├── di/
│   │   │   └── note_dependency_injection.dart
│   │   ├── models/
│   │   │   ├── note_model.dart
│   │   │   ├── note_history.dart
│   │   │   └── note_template.dart
│   │   ├── providers/
│   │   │   ├── note_provider.dart
│   │   │   └── note_editor_provider.dart
│   │   ├── repositories/
│   │   │   ├── note_repository.dart          # Soyut Repository arayüzü
│   │   │   ├── markdown_note_repository.dart # Dosya tabanlı üretim implementasyonu
│   │   │   └── mock_note_repository.dart     # Bellek içi test implementasyonu
│   │   ├── services/
│   │   │   ├── search_service_interface.dart
│   │   │   ├── advanced_search_service.dart
│   │   │   ├── backlink_service.dart
│   │   │   ├── git_sync_service.dart
│   │   │   ├── workspace_service.dart
│   │   │   ├── template_file_storage.dart
│   │   │   └── voice_note_service.dart
│   │   ├── presentation/                     # Ekranlar (Main, NoteList, TagManagement vb.)
│   │   └── widgets/                          # MarkdownEditor, LivePreviewController, MathRenderer
│   ├── search/                               # Arama ekranı ve yardımcı arama servisi
│   ├── security/                             # BiometricService ve LockScreen
│   ├── settings/                             # Uygulama, AI ve çalışma alanı ayarları
│   └── tools/                                # CommandPalette, CrossReferenceTracker, Pomodoro, Heatmap
└── shared/                                   # SharingService ve ortak bileşenler
```

---

## 🚀 Bağımlılık Enjeksiyonu ve Kullanım Örnekleri

### 1. Uygulama Başlatma (`lib/main.dart`)
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: themeProvider),
    ChangeNotifierProvider.value(value: shortcutManager),
    ChangeNotifierProvider(create: (_) => AiProvider()..loadConfig()),
    ...NoteDependencyInjection.getProviders(),
  ],
  child: ConnectedNotebookApp(...),
);
```

### 2. Widget İçinden Servis ve Provider Erişimi
`NoteDependencyInjectionExtension` sayesinde `BuildContext` üzerinden tip güvenli erişim sağlanır:
```dart
final noteProvider = context.noteProvider;
final repository = context.noteRepository;
final workspaceService = context.workspaceService;

await noteProvider.addNote(newNote);
```

### 3. Birim ve Widget Testlerinde İzolasyon
```dart
final mockRepo = MockNoteRepository();
final searchService = AdvancedSearchService(mockRepo);
final provider = NoteProvider(
  repository: mockRepo,
  searchService: searchService,
);

await provider.loadNotes();
```
