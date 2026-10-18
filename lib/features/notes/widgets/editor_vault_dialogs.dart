import 'package:flutter/material.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';

/// User interface dialogs for setting up and unlocking encrypted note vaults.
class EditorVaultDialogs {
  EditorVaultDialogs._();

  static Future<bool> promptSetupMasterPassword(
    BuildContext context,
    NoteEncryptionService encryptionService,
  ) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kasa Parolası Belirleyin 🔒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notlarınızı başka bir cihaza taşıdığınızda veya cihazınız sıfırlandığında şifreli notlarınızı kurtarabilmek için bir Kasa Parolası belirleyin.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kasa Parolası (en az 6 karakter)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parola Tekrar',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final p1 = passController.text;
                final p2 = confirmController.text;
                if (p1.length < 6) {
                  setDialogState(() => errorText = 'Parola en az 6 karakter olmalıdır.');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => errorText = 'Parolalar eşleşmiyor.');
                  return;
                }
                try {
                  await encryptionService.setupMasterPassword(p1);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (e) {
                  setDialogState(() => errorText = 'Hata: $e');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  static Future<bool> promptUnlockWithMasterPassword(
    BuildContext context,
    NoteEncryptionService encryptionService,
  ) async {
    final passController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kasa Parolasını Girin 🔑'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Şifreli kasa anahtarını (.vault_key.json) bu cihazda açmak için kasa parolanızı girin.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kasa Parolası',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await encryptionService.unlockWithMasterPassword(
                    passController.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on InvalidVaultPasswordException {
                  setDialogState(() => errorText = 'Parola hatalı.');
                } catch (e) {
                  setDialogState(() => errorText = 'Kasa açılamadı: $e');
                }
              },
              child: const Text('Kasayı Aç'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  static Future<bool> confirmRemoveEncryption(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şifreleme Kaldırılsın mı?'),
        content: const Text('Not düz metin olarak saklanacak. Devam edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
