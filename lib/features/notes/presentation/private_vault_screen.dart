import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:connected_notebook/core/security/biometric_service.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';

class PrivateVaultScreen extends StatefulWidget {
  const PrivateVaultScreen({Key? key}) : super(key: key);

  @override
  State<PrivateVaultScreen> createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends State<PrivateVaultScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _recoveryKeyController = TextEditingController();

  bool _isSettingPassword = false;
  bool _canUseBiometrics = true;
  bool _showPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isBiometricReady = false;
  IconData _biometricIcon = Icons.fingerprint;
  String _biometricButtonLabel = 'Biyometrik Giriş';
  List<Note> _privateNotes = [];

  late final BiometricService _biometricService;

  @override
  void initState() {
    super.initState();
    _biometricService = BiometricService.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VaultProvider>().syncState();
      _checkVaultStatus();
      _checkBiometrics();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

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
    final vaultProvider = context.read<VaultProvider>();
    if (vaultProvider.isUnlocked) {
      await _loadPrivateNotes();
      return;
    }

    final bioEnabled = await _biometricService.isBiometricEnabled();
    if (bioEnabled && (await _biometricService.getStatus() == BiometricStatus.ready)) {
      await _attemptBiometricUnlock();
    }
  }

  Future<void> _attemptBiometricUnlock() async {
    final status = await _biometricService.getStatus();

    if (status == BiometricStatus.notSupported) {
      _showError('Cihazınızda biyometrik donanım bulunamadı.');
      return;
    }

    if (status == BiometricStatus.supportedButNotEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Biyometrik destekleniyor ama kayıtlı parmak izi/yüz yok. Lütfen ayarlardan ekleyin.'),
          action: SnackBarAction(label: 'TAMAM', onPressed: () {}),
        ),
      );
      return;
    }

    final storedPassword = await _biometricService.authenticateAndRetrievePassword();
    if (storedPassword == null) return;

    final unlocked = await context.read<VaultProvider>().unlockWithPassword(storedPassword);
    if (unlocked) {
      await _loadPrivateNotes();
      _showSuccess('Giriş başarılı');
    } else {
      _showError('Kasa anahtarı doğrulanamadı.');
    }
  }

  Future<void> _loadPrivateNotes() async {
    try {
      final noteProvider = context.read<NoteProvider>();
      await noteProvider.loadNotes();

      setState(() {
        _privateNotes = noteProvider.notes.where((note) => note.isEncrypted).toList();
      });
    } catch (e) {
      _showError('Özel notlar yüklenemedi: $e');
    }
  }

  Future<void> _unlockVault() async {
    if (_passwordController.text.isEmpty) {
      _showError('Şifre boş olamaz');
      return;
    }

    final currentPassword = _passwordController.text;
    _passwordController.clear();

    final unlocked = await context.read<VaultProvider>().unlockWithPassword(currentPassword);
    if (!mounted) return;

    if (unlocked) {
      await _loadPrivateNotes();
      _showSuccess('Kasa başarıyla açıldı');

      if (_canUseBiometrics && !(await _biometricService.isBiometricEnabled())) {
        _showBiometricOfferDialog(currentPassword);
      }
    } else {
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

    final password = _newPasswordController.text;

    try {
      await context.read<VaultProvider>().initializeVault(password: password);
      if (!mounted) return;

      setState(() {
        _isSettingPassword = false;
      });

      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _recoveryKeyController.clear();

      await _loadPrivateNotes();
      _showSuccess('Kasa şifresi başarıyla ayarlandı');

      if (_canUseBiometrics) {
        _showBiometricOfferDialog(password);
      }
    } catch (e) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showError('Şifre ayarlanamadı: $e');
    }
  }

  Future<void> _savePrivateNote() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Başlık boş olamaz');
      return;
    }

    try {
      final vaultProvider = context.read<VaultProvider>();
      final noteProvider = context.read<NoteProvider>();

      final createdNote = await vaultProvider.createPrivateNote(
        title: _titleController.text.trim(),
        content: _contentController.text,
        tags: const ['özel', 'vault'],
      );

      await noteProvider.loadNotes();
      setState(() {
        _privateNotes.insert(0, createdNote);
      });

      _titleController.clear();
      _contentController.clear();
      _showSuccess('Not başarıyla kaydedildi');
    } catch (e) {
      _showError('Not kaydedilemedi: $e');
    }
  }

  Future<void> _updatePrivateNote(Note note, String plainContent) async {
    try {
      final updated = await context.read<VaultProvider>().updatePrivateNote(
            note: note,
            plainTextContent: plainContent,
          );

      final index = _privateNotes.indexWhere((n) => n.id == updated.id);
      if (index != -1) {
        setState(() {
          _privateNotes[index] = updated;
        });
      }

      await context.read<NoteProvider>().loadNotes();
      _showSuccess('Şifreli not güncellendi');
    } catch (e) {
      _showError('Güncelleme başarısız: $e');
    }
  }

  Future<void> _showBiometricOfferDialog(String? password) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Biyometrik Giriş'),
        content: const Text('Kasanızı parmak izi veya yüz tanıma ile açmak ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hayır'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _biometricService.authenticate(
                localizedReason: 'Biyometrik girişi etkinleştirmek için doğrulayın',
              );
              if (success && password != null) {
                await _biometricService.enableBiometricLogin(password);
                _showSuccess('Biyometrik giriş etkinleştirildi');
              }
            },
            child: const Text('Evet, Etkinleştir'),
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
            const Text('Lütfen kurtarma anahtarınızı girin:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Kurtarma anahtarı',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<VaultProvider>().unlockWithRecoveryKey(controller.text.trim());
              if (!mounted) return;
              if (success) {
                await _loadPrivateNotes();
                _showSuccess('Kasa kurtarıldı. Lütfen şifrenizi güncelleyin.');
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

  void _openPrivateNoteDetail(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PrivateNoteDetailScreen(
          note: note,
          onSave: _updatePrivateNote,
        ),
      ),
    );
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
    return Consumer<VaultProvider>(
      builder: (context, vaultProvider, _) {
        final isUnlocked = vaultProvider.isUnlocked;
        final isBusy = vaultProvider.isBusy;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            title: const Text('Şifreli Freelance İş Defteri'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
            actions: [
              if (isUnlocked)
                IconButton(
                  icon: const Icon(Icons.lock),
                  onPressed: () async {
                    await context.read<VaultProvider>().lockVault();
                    if (!mounted) return;
                    setState(() {
                      _privateNotes.clear();
                    });
                  },
                  tooltip: 'Kilitle',
                ),
            ],
          ),
          body: isBusy
              ? const Center(child: CircularProgressIndicator())
              : (!isUnlocked
                  ? (_isSettingPassword ? _buildSetupPassword() : _buildUnlockScreen())
                  : Column(
                      children: [
                        _buildQuickStats(),
                        _buildAddNoteForm(),
                        Expanded(child: _buildPrivateNotesList()),
                      ],
                    )),
        );
      },
    );
  }

  Widget _buildUnlockScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work, size: 80, color: Theme.of(context).primaryColor),
          const SizedBox(height: 24),
          Text(
            'Şifreli Freelance İş Defteri',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                onPressed: () => setState(() => _showPassword = !_showPassword),
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
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _isSettingPassword = true),
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

  Widget _buildSetupPassword() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: Theme.of(context).primaryColor),
          const SizedBox(height: 24),
          Text(
            'Kasa Şifresi Belirle',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
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
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
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
                Text('Toplam ${_privateNotes.length} özel iş notu'),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'İş Adı',
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
            child: Consumer<VaultProvider>(
              builder: (context, vaultProvider, _) {
                return ElevatedButton.icon(
                  onPressed: vaultProvider.isBusy ? null : _savePrivateNote,
                  icon: vaultProvider.isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(vaultProvider.isBusy ? 'Kaydediliyor...' : 'Şifreli Kaydet'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateNotesList() {
    if (_privateNotes.isEmpty) {
      return const Center(child: Text('Henüz iş notu yok'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _privateNotes.length,
      itemBuilder: (context, index) {
        final note = _privateNotes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Şifreli içerik - detay açıldığında çözülecek'),
            trailing: const Icon(Icons.lock, size: 16),
            onTap: () => _openPrivateNoteDetail(note),
          ),
        );
      },
    );
  }
}

class _PrivateNoteDetailScreen extends StatefulWidget {
  const _PrivateNoteDetailScreen({
    required this.note,
    required this.onSave,
  });

  final Note note;
  final Future<void> Function(Note note, String plainContent) onSave;

  @override
  State<_PrivateNoteDetailScreen> createState() => _PrivateNoteDetailScreenState();
}

class _PrivateNoteDetailScreenState extends State<_PrivateNoteDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  Future<String>? _contentFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController();
    _contentFuture = context.read<VaultProvider>().resolveReadableContent(widget.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        widget.note.copyWith(title: _titleController.text.trim()),
        _contentController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('İçerik çözülemedi: ${snapshot.error}'));
          }

          _contentController.text = snapshot.data ?? '';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Şifre çözülmüş içerik',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
