# GümüşNot — Algoritma ve Veri Yapıları Dokümantasyonu

Bu belge, GümüşNot kod tabanında kullanılan çekirdek algoritmaları, kriptografik protokolleri ve performans optimizasyonlarını açıklar.

---

## 1. Kuvvet Yönelimli Grafik Motoru ve Quadtree Uzamsal İndeksleme
**Dosyalar:**
* `lib/features/graph/algorithms/graph_physics_engine.dart`
* `lib/features/graph/algorithms/quadtree.dart`
* `lib/features/graph/models/graph_builder.dart`

### Çalışma Mantığı
Bilgi grafiği, notları düğüm (`GraphNode`) ve `[[WikiLink]]` / ortak etiket ilişkilerini kenar (`GraphEdge`) olarak modeller. Henüz dosyası oluşturulmamış ancak referans verilmiş bağlantılar **Hayalet Düğüm (`isGhost: true`)** olarak grafiğe eklenir.

Ana UI iş parçacığının (thread) 60 FPS akıcılığını korumak için tüm fizik simülasyonu `GraphPhysicsIsolate` üzerinden arka plan **Dart `Isolate`** iş parçacığında hesaplanır:

1. **Coulomb İtme Kuvveti (Repulsion):**
   $$F_{\text{rep}} = \frac{k_r}{\max(d^2, 1.0)}$$
   Düğümlerin üst üste binmesini engeller. Düğüm sayısı $N > 100$ olduğunda `GraphSpatialIndex` (**Quadtree**) devreye girerek uzayı dörde böler ve yalnızca $R = 300$ piksel yarıçapındaki komşu düğümleri sorgular; böylece karmaşıklık $O(N^2)$'den **$O(N \log N)$** seviyesine iner.
2. **Hooke Yay Çekim Kuvveti (Attraction):**
   $$F_{\text{att}} = (d - L_{\text{ideal}}) \cdot k_a \cdot w$$
   Birbirine bağlı düğümleri ideal yay uzunluğunda ($L_{\text{ideal}}$) dengeler.
3. **Merkezcil Kuvvet (Center Gravity) ve Sönümleme (Damping):**
   Düğümlerin tuval dışına savrulmasını önlemek için merkeze doğru hafif bir çekim uygulanır ve her adımda hız vektörü sönümleme katsayısıyla ($\text{damping} \approx 0.85$) çarpılarak maksimum hız ($v_{\max} = 50$) sınırlandırılır.

---

## 2. Zarf Şifreleme (Envelope Encryption) ve Anahtar Türetimi
**Dosya:** `lib/core/security/note_encryption_service.dart`

Gizli Kasa (*Vault*) içindeki notlar endüstri standardı **Zarf Şifreleme** mimarisiyle korunur:

1. **Veri Şifreleme Anahtarı (DEK):** `Random.secure()` ile üretilen kriptografik olarak rastgele 256-bit (32-byte) anahtardır. Aktif oturumda işletim sistemi güvenli anahtarlığında (`FlutterSecureStorage`) tutulur.
2. **Anahtar Şifreleme Anahtarı (KEK) — `PBKDF2-HMAC-SHA256`:**
   Kullanıcının belirlediği Ana Paroladan (*Master Password*), RFC 8018 uyumlu `PBKDF2-HMAC-SHA256` algoritması (**120.000 iterasyon**, 128-bit rastgele tuz/salt) ile 256-bit KEK türetilir. Sabit zamanlı karşılaştırma (*constant-time comparison*) uygulanır.
3. **Anahtar Sarma (`.vault_key.json`):**
   DEK, KEK kullanılarak **`AES-256-GCM`** (96-bit IV + 128-bit kimlik doğrulama etiketi) ile şifrelenir ve `<Belgelerim>/GumusNot/notes/.vault_key.json` dosyasına yazılır. Parola değiştirildiğinde not dosyaları yeniden şifrelenmez; yalnızca `.vault_key.json` içindeki DEK zarfı yeniden sarılır.
4. **Not Yükü Şifrelemesi (`enc:v1`):**
   Her şifreli not kaydında yeni bir 12-byte IV üretilir ve gövde `enc:v1:<base64_iv>:<base64_ciphertext>` formatında YAML frontmatter altına yazılır.

---

## 3. 64-Bit Charikar SimHash Semantik AI Önbelleği
**Dosya:** `lib/features/ai/services/ai_cache_service.dart`

Yapay zekâ isteklerinde hem API kotasını korumak hem de diskte düz metin not saklamamak için iki katmanlı (L1 RAM + L2 `SharedPreferences`) **SimHash** önbelleği kullanılır:

1. **Özellik Çıkarımı (Shingling):** Metin normalize edilir; kelime token'ları (ağırlık: `2`) ve 3-gram karakter dizileri (ağırlık: `1`) çıkarılır.
2. **64-Bit FNV-1a ve SimHash Vektörü:** Her özellik 64-bit FNV-1a (`0xCBF29CE484222325` offset, `0x100000001B3` asal çarpan) ile hash'lenir. 64 elemanlı ağırlık vektörü $V$'de bit `1` ise $+w$, `0` ise $-w$ eklenir. Sonuçta $V[i] > 0$ olan bitler `1` yapılarak 64-bit SimHash imzası elde edilir.
3. **Hamming Mesafesi ile Yakın Eşleşme:** İki metin arasındaki 64-bit SimHash farkının bit sayısı ($\text{popcount}(h_1 \oplus h_2) \le 4$) eşik değerinin altındaysa önbellekteki AI yanıtı doğrudan döndürülür. Şifreli notlar (`isEncrypted: true`) yalnızca L1 RAM önbelleğinde tutulur, diske yazılmaz.

---

## 4. TF-IDF ve Kosinüs Benzerliği ile Çapraz Referans Tespiti
**Dosya:** `lib/features/tools/widgets/cross_reference_tracker.dart`

Açık olan not ile çalışma alanındaki diğer tüm şifresiz notlar arasındaki anlamsal yakınlık arka plan `Isolate`'ında (`Isolate.run`) hesaplanır:

1. **Ön İşleme:** Markdown işaretleri temizlenir, Türkçe/İngilizce etkisiz kelimeler (*stop words*) çıkarılır.
2. **TF-IDF Vektörleştirme:**
   $$\text{TF}(t, d) = \frac{\text{count}(t, d)}{|d|}, \quad \text{IDF}(t) = \ln\left(\frac{N}{\text{df}(t)}\right) + 1$$
3. **Kosinüs Benzerliği ve Hibrit Skor:**
   $$\text{CosineSim}(A, B) = \frac{\vec{V}_A \cdot \vec{V}_B}{\|\vec{V}_A\| \|\vec{V}_B\|}$$
   Kosinüs benzerliği (%45 ağırlık), ortak etiket oranı (%35 ağırlık) ve doğrudan `[[WikiLink]]` bağlantısı (%20 ağırlık) birleştirilerek en yüksek skorlu 5 ilişkili not önerilir.

---

## 5. Ağırlıklı Bulanık (Levenshtein) ve Zettelkasten Graf Araması
**Dosyalar:**
* `lib/features/notes/services/advanced_search_service.dart`
* `lib/features/search/services/search_service.dart`

1. **Çok Kriterli ve Bulanık Puanlama:**
   * Tam başlık eşleşmesi, başlık başlangıcı, etiket eşleşmesi ve gövde içi geçiş sıklığı puanlanır.
   * Yazım hatalarını tolere etmek için dinamik programlama tabanlı **Levenshtein Mesafesi** ($\text{mesafe} \le 2$) uygulanır (etkisiz kelimeler bulanık aramadan muaf tutulur).
2. **Semantik Komşuluk Desteği (Graph Boost) ve Güncellik (Recency):**
   * Arama terimiyle doğrudan eşleşen çekirdek (*seed*) notların `[[WikiLink]]` komşularına semantik bonus puan eklenir.
   * `AdvancedSearchService` içinde gelen bağlantı sayısına göre logaritmik PageRank bonusu ve son güncellenme tarihine göre üstel zaman aşımı çarpanı ($e^{-0.005 \cdot \text{gün}}$) uygulanır.

---

## 6. Canlı Markdown Sözdizimi Gizleme ve Artımlı Dosya Önbelleği
**Dosyalar:**
* `lib/features/notes/widgets/markdown_live_controller.dart`
* `lib/features/notes/repositories/markdown_note_repository.dart`

* **Satır Bazlı `InlineSpan` Önbelleği (`MarkdownLivePreviewController`):** Yalnızca imlecin bulunduğu aktif satırda ham Markdown sembollerini gösterir; diğer satırlarda sembolleri gizleyip biçimlendirilmiş `TextSpan` ağacını `_LineKey` ile önbelleğe alır (maks. 5.000 satır). ASCII karakter kodu ön kontrolü ile düz metin satırlarda Regex motorunu çalıştırmaz.
* **`FileStat` Önbelleği ve Atomik Yazma (`MarkdownNoteRepository`):** Her `.md` dosyasının `modified` zaman damgası ve `size` bilgisi bellekte tutulur; değişmeyen dosyalar diskten tekrar okunmaz. Kayıt işlemleri `<dosya>.<timestamp>.tmp` üzerinden `flush()` + `rename()` ile atomik olarak gerçekleştirilir.
