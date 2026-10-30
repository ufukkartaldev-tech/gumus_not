import 'package:flutter/material.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/security/services/biometric_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final BiometricService _biometricService = BiometricService();
  final NoteEncryptionService _encryptionService = NoteEncryptionService();
  final TextEditingController _passwordController = TextEditingController();

  bool _isAuthenticating = false;
  bool _canCheckBiometrics = false;
  bool _hasMasterPassword = false;
  bool _showPasswordInput = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLockState();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initLockState() async {
    final canCheck = await _biometricService.canCheckBiometrics();
    final hasEnv = await _encryptionService.hasEnvelope();

    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheck;
      _hasMasterPassword = hasEnv;
      // Biyometri desteklenmiyorsa ama ana parola varsa doğrudan parola alanını göster
      _showPasswordInput = !canCheck && hasEnv;
    });

    if (canCheck) {
      await _checkBiometricAuth();
    }
  }

  Future<void> _checkBiometricAuth() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    final authenticated = await _biometricService.authenticate();

    if (!mounted) return;
    if (authenticated) {
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Biyometrik doğrulama başarısız oldu veya iptal edildi.';
        if (_hasMasterPassword) {
          _showPasswordInput = true;
        }
      });
    }
  }

  Future<void> _unlockWithMasterPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen kasa parolasını girin.';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final isValid = await _encryptionService.verifyMasterPassword(password);
      if (!mounted) return;

      if (isValid) {
        // App Lock doğrulaması başarılı; kasa DEK'i oturuma açılmadan fail-closed şekilde ana ekrana geçilir
        _passwordController.clear();
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Kasa parolası hatalı!';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Doğrulama sırasında hata oluştu.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        CommandPaletteIntent: DoNothingAction(),
        NewNoteIntent: DoNothingAction(),
      },
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'GümüşNot Kilitli',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notlarınıza erişmek için kimliğinizi doğrulayın',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 36),

                    if (_isAuthenticating)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (_canCheckBiometrics) ...[
                        ElevatedButton.icon(
                          onPressed: _checkBiometricAuth,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Windows Hello / Biyometri ile Aç'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (_hasMasterPassword && !_showPasswordInput) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showPasswordInput = true;
                              });
                            },
                            icon: const Icon(Icons.password),
                            label: const Text('Kasa Parolası ile Kilidi Aç'),
                          ),
                        ],
                      ],

                      if (_showPasswordInput && _hasMasterPassword) ...[
                        if (_canCheckBiometrics) const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofocus: !_canCheckBiometrics,
                          decoration: InputDecoration(
                            labelText: 'Kasa Ana Parolası',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _unlockWithMasterPassword(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _unlockWithMasterPassword,
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Parola ile Kilidi Aç'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],

                      if (!_canCheckBiometrics && !_hasMasterPassword) ...[
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Bu cihazda Windows Hello / biyometrik kilit veya kasa ana parolası tanımlı değil.',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],

                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
