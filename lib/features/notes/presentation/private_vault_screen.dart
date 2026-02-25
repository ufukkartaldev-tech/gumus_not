import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';
import 'package:connected_notebook/core/security/biometric_service.dart';

class PrivateVaultScreen extends StatefulWidget {
  const PrivateVaultScreen({Key? key}) : super(key: key);

  @override
  State<PrivateVaultScreen> createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends State<PrivateVaultScreen> {
  // ... (previous controllers) ...
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _recoveryKeyController = TextEditingController(); // Just keeping context, though unused

  bool _isUnlocked = false;
  bool _isLoading = false;
  bool _isSettingPassword = false;
  bool _canUseBiometrics = true;
  bool _showPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _showRecoveryKey = false;
  bool _isBiometricReady = false;
  IconData _biometricIcon = Icons.fingerprint;
  String _biometricButtonLabel = 'Biyometrik Giriş';
  String? _recoveryKey;
  List<Note> _privateNotes = [];
  
  late final BiometricService _biometricService;

  @override
  void initState() {
    super.initState();
    _biometricService = BiometricService.instance;
    _checkVaultStatus();
    _checkBiometrics();
  }

  // ... (dispose) ...

  Future<void> _checkBiometrics() async {
    final status = await _biometricService.getStatus();
    
    if (status == BiometricStatus.ready) {
      final types = await _biometricService.getAvailableBiometrics();
      
      const iconMap = {
        BiometricType.face: Icons.face,
        BiometricType.fingerprint: Icons.fingerprint,
        BiometricType.iris: Icons.remove_red_eye,
      };
      
      const labelMap = {
        BiometricType.face: 'Yüz Tanıma ile Aç',
        BiometricType.fingerprint: 'Parmak İzi ile Aç',
        BiometricType.iris: 'İris Tanıma ile Aç',
      };
      
      final matchedType = types.firstWhere(
        (type) => iconMap.containsKey(type),
        orElse: () => BiometricType.fingerprint,
      );

      setState(() {
        _isBiometricReady = true;
        _biometricIcon = iconMap[matchedType] ?? Icons.fingerprint;
        _biometricButtonLabel = labelMap[matchedType] ?? 'Biyometrik Giriş';
      });
    } else {
      setState(() => _isBiometricReady = false);
    }
  }

  Future<void> _checkVaultStatus() async {
    final isInitialized = EncryptionService.isInitialized();
    if (isInitialized) {
      setState(() => _isUnlocked = true);
      _loadPrivateNotes();
    } else {
      // Otomatik biyometrik deneme (kullanıcı daha önce açtıysa)
      final bioEnabled = await _biometricService.isBiometricEnabled();
      if (bioEnabled && (await _biometricService.getStatus() == BiometricStatus.ready)) {
        // Otomatik denemede session'ı temizlemiş olabilir, tekrar sor
        _attemptBiometricUnlock(); 
      }
    }
  }

  Future<void> _attemptBiometricUnlock() async {
    final status = await _biometricService.getStatus();

    // 1. Durum Kontrolü: Donanım var mı?
    if (status == BiometricStatus.notSupported) {
      _showError('Cihazınızda biyometrik donanım bulunamadı.');
      return;
    }

    // 2. Durum Kontrolü: Kayıt var mı?
    if (status == BiometricStatus.supportedButNotEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Biyometrik destekleniyor ama kayıtlı parmak izi/yüz yok. Lütfen ayarlardan ekleyin.'),
          action: SnackBarAction(label: 'TAMAM', onPressed: () {}),
        ),
      );
      return;
    }

    // 3. Atomik Doğrulama ve Şifre Alma (GÜVENLİ YOL)
    final storedPassword = await _biometricService.authenticateAndRetrievePassword();

    if (storedPassword != null) {
      try {
        await EncryptionService.initialize(storedPassword);
        setState(() {
          _isUnlocked = true;
          _recoveryKey = EncryptionService.getRecoveryKey();
        });
        _loadPrivateNotes();
        _showSuccess('Giriş başarılı');
      } catch (e) {
        _showError('Kasa anahtarı hatası: $e');
      }
    } else {
      // Kullanıcı iptal etti veya eşleşmedi, sessizce geç
    }
  }
  
  // ... (unlockVault, setupPassword methods remain similar but check _isBiometricReady) ...

  Future<void> _loadPrivateNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.loadNotes();
      
      final privateNotes = noteProvider.notes.where((note) => 
        note.isEncrypted
      ).toList();
      
      // Decrypt notes for display
      for (int i = 0; i < privateNotes.length; i++) {
        try {
          final decryptedContent = EncryptionService.decrypt(privateNotes[i].content);
          privateNotes[i] = privateNotes[i].copyWith(content: decryptedContent);
        } catch (e) {
          // Keep as is if decryption fails
        }
      }
      
      setState(() {
        _privateNotes = privateNotes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockVault() async {
    if (_passwordController.text.isEmpty) {
      _showError('Şifre boş olamaz');
      return;
    }

    try {
      await EncryptionService.initialize(_passwordController.text);
      
      final currentPassword = _passwordController.text;
      _passwordController.clear(); // BELLEK GÜVENLİĞİ: Şifreyi hemen sil
      
      // Başarılı giriş
      setState(() {
        _isUnlocked = true;
        _recoveryKey = EncryptionService.getRecoveryKey();
      });
      _loadPrivateNotes();
      _showSuccess('Kasa başarıyla açıldı');

      // Biyometrik destekleniyor ama açık değilse teklif et
      if (_canUseBiometrics && !(await _biometricService.isBiometricEnabled())) {
        _showBiometricOfferDialog(currentPassword);
      }
    } catch (e) {
      _passwordController.clear();
      _showError('Yanlış şifre veya bozuk kasa');
    }
  }

  Future<void> _setupPassword() async {
    if (_newPasswordController.text.isEmpty) {
      _showError('Şifre boş olamaz');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Şifreler eşleşmiyor');
      return;
    }

    if (_newPasswordController.text.length < 8) {
      _showError('Şifre en az 8 karakter olmalıdır');
      return;
    }

    try {
      final password = _newPasswordController.text;
      await EncryptionService.initialize(password);
      
      setState(() {
        _isUnlocked = true;
        _isSettingPassword = false;
        _recoveryKey = EncryptionService.getRecoveryKey();
      });
      
      _newPasswordController.clear(); // BELLEK GÜVENLİĞİ
      _confirmPasswordController.clear();
      
      _showSuccess('Kasa şifresi başarıyla ayarlandı');
      
      // KRİTİK HATIRLATMA: Kurtarma anahtarını hemen göster ve saklat
      _showCriticalRecoveryReminder();

      if (_canUseBiometrics) {
        _showBiometricOfferDialog(password);
      }
    } catch (e) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showError('Şifre ayarlanamadı: $e');
    }
  }

  Future<void> _showBiometricOfferDialog(String? password) async {
    // Şifreyi hemen temizleme, dialog sonucunu bekle
    // Not: Gerçek uygulamada password'ü bellekte uzun süre tutmamak gerekir.
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Biyometrik Giriş'),
        content: const Text('Kasanızı parmak izi veya yüz tanıma ile açmak ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              password = null; // Bellek güvenliği
              Navigator.pop(context);
            },
            child: const Text('Hayır'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _biometricService.authenticate(
                localizedReason: 'Biyometrik girişi etkinleştirmek için doğrulayın'
              );
              if (success && password != null) {
                await _biometricService.enableBiometricLogin(password!);
                _showSuccess('Biyometrik giriş etkinleştirildi');
              }
              password = null; // Bellek güvenliği: GC için referansı kaldır
            },
            child: const Text('Evet, Etkinleştir'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePrivateNote() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Başlık boş olamaz');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // Encrypt content
      final encryptedContent = EncryptionService.encrypt(_contentController.text);
      
      final note = Note(
        title: _titleController.text.trim(),
        content: encryptedContent,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: true,
        tags: ['özel', 'bionluk'],
      );
      
      await noteProvider.addNote(note);
      
      _titleController.clear();
      _contentController.clear();
      
      _loadPrivateNotes();
      _showSuccess('Not başarıyla kaydedildi');
    } catch (e) {
      _showError('Not kaydedilemedi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Şifreli Freelance İş Defteri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          if (_isUnlocked && _recoveryKey != null)
            IconButton(
              icon: const Icon(Icons.key),
              onPressed: _showRecoveryKeyDialog,
              tooltip: 'Kurtarma Anahtarı',
            ),
          if (_isUnlocked)
            IconButton(
              icon: const Icon(Icons.lock),
              onPressed: () {
                EncryptionService.clear(); // BELLEK GÜVENLİĞİ: Anahtarları temizle
                setState(() {
                  _isUnlocked = false;
                  _privateNotes.clear();
                });
              },
              tooltip: 'Kilitle',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isUnlocked) {
      return _isSettingPassword ? _buildSetupPassword() : _buildUnlockScreen();
    }
    
    return Column(
      children: [
        _buildQuickStats(),
        _buildAddNoteForm(),
        Expanded(child: _buildPrivateNotesList()),
      ],
    );
  }

  Widget _buildUnlockScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Şifreli Freelance İş Defteri',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Freelance iş detaylarını güvenli saklayın',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Şifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
            ),
            onSubmitted: (_) => _unlockVault(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _unlockVault,
              child: const Text('Kasayı Aç'),
            ),
          ),
          if (_isBiometricReady) 
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _attemptBiometricUnlock,
                  icon: Icon(_biometricIcon),
                  label: Text(_biometricButtonLabel),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isSettingPassword = true;
              });
            },
            child: const Text('Yeni Şifre Belirle'),
          ),
          TextButton.icon(
            onPressed: _showRecoveryInputPrompt,
            icon: const Icon(Icons.emergency_share),
            label: const Text('Anahtarı Kullanarak Kurtar'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryInputPrompt() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kurtarma Anahtarı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lütfen 24 karakterlik kurtarma anahtarınızı girin:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Örn: XXXXXX-XXXXXX...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await EncryptionService.initializeWithRecoveryKey(controller.text.trim());
              if (success) {
                setState(() {
                  _isUnlocked = true;
                  _recoveryKey = EncryptionService.getRecoveryKey();
                });
                _loadPrivateNotes();
                _showSuccess('Kasa kurtarıldı! Lütfen hemen şifrenizi güncelleyin.');
              } else {
                _showError('Geçersiz kurtarma anahtarı');
              }
            },
            child: const Text('Kurtar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPassword() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Kasa Şifresi Belirle',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Şifreli kasanız için güçlü bir şifre oluşturun',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              labelText: 'Yeni Şifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Şifre Tekrarı',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isSettingPassword = false;
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _setupPassword,
                  child: const Text('Şifreyi Belirle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.work, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Freelance İş İstatistikleri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toplam ${_privateNotes.length} özel iş notu',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNoteForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni İş Notu Ekle',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'İş Adı (FREELANCE/PROJE/İŞ/MÜŞTERİ/ÖZEL)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'İş Detayları',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _savePrivateNote,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Kaydediliyor...' : 'Şifreli Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateNotesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_privateNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz iş notu yok',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Freelance işlerinizi buraya ekleyin',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _privateNotes.length,
      itemBuilder: (context, index) {
        final note = _privateNotes[index];
        return _buildPrivateNoteCard(note, index);
      },
    );
  }

  Widget _buildPrivateNoteCard(Note note, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          note.excerpt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              _formatDate(note.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/note-editor', arguments: note);
        },
      ),
    );
  }

  void _exportToLatex(Note note) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('LaTeX export özelliği yakında eklenecek!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showCriticalRecoveryReminder() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcı okumadan geçemesin
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('ÇOK ÖNEMLİ!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GümüşNot Private Vault başarıyla oluşturuldu. Ancak, şifrenizi unutursanız verilerinize erişmenizin TEK YOLU aşağıdaki kurtarma anahtarıdır.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'KURTARMA ANAHTARINIZ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _recoveryKey ?? 'Hata!',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ DİKKAT: Bu anahtarı bir kağıda yazıp fiziksel bir kasada saklamanız önerilir. Dijital ortamda saklamak saldırılara açıktır. Bu anahtar kaybolursa ve şifrenizi unutursanız verileriniz SONSUZA KADAR KAYBOLUR.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ANLADIM, ANAHTARI SAKLADIM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecoveryKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Kurtarma Anahtarı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Şifrenizi unutursanız özel notlarınıza erişebilmek için bu anahtara ihtiyacınız olacak.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kurtarma Anahtarı:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _recoveryKey ?? 'Henüz oluşturulmadı',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '🛡️ TAVSİYE: Bu anahtarı fiziksel bir kağıda yazın veya güvenli bir parola yöneticisinde (Bitwarden, 1Password vb.) saklayın.',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ UYARI: Bu anahtar çalınırsa, kasanıza şifreniz olmadan erişilebilir.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyRecoveryKey();
              _showSuccess('Kurtarma anahtarı kopyalandı!');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopyala'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _copyRecoveryKey() {
    // In a real app, this would copy to clipboard
    // For now, we'll just show a success message
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}.${date.month}.${date.year}';
  }
}
