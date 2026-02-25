import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum BiometricStatus {
  notSupported,
  supportedButNotEnrolled,
  ready
}

class BiometricService {
  final LocalAuthentication auth;
  final FlutterSecureStorage storage;

  BiometricService({required this.auth, required this.storage});

  static final BiometricService instance = BiometricService(
    auth: LocalAuthentication(),
    storage: const FlutterSecureStorage(),
  );
  
  // Anahtarlar
  static const _keyPassword = 'vault_password';
  static const _keyBiometricEnabled = 'biometric_enabled';

  /// Cihazın biyometrik durumunu detaylı analiz eder
  /// Dönüş değerleri:
  /// - notSupported: Donanım yok
  /// - supportedButNotEnrolled: Donanım var ama parmak izi/yüz tanımlanmamış
  /// - ready: Her şey hazır
  Future<BiometricStatus> getStatus() async {
    try {
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        return BiometricStatus.notSupported;
      }

      final List<BiometricType> availableBios = await auth.getAvailableBiometrics();
      
      if (availableBios.isEmpty) {
        return BiometricStatus.supportedButNotEnrolled;
      }

      return BiometricStatus.ready;
    } catch (e) {
      debugPrint('Biyometrik durum hatası: $e');
      return BiometricStatus.notSupported;
    }
  }

  /// Mevcut biyometrik yöntemleri listele (İkon seçimi için)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Saf kimlik doğrulama (Sadece True/False döner)
  /// Lifecycle handle edilir (stickyAuth)
  Future<bool> authenticate({
    String localizedReason = 'GümüşNot Kasası için kimlik doğrulayın',
  }) async {
    try {
      return await auth.authenticate(localizedReason: localizedReason);
    } on PlatformException catch (e) {
      debugPrint('Auth Error: ${e.message}');
      // Kullanıcı iptal ettiyse veya donanım hatası varsa false döner
      return false;
    }
  }

  /// GÜVENLİ METOD: Kimlik doğrulamadan şifreyi ASLA vermez.
  /// Önce parmak izi sorar, geçerse şifreyi döner.
  Future<String?> authenticateAndRetrievePassword() async {
    // 1. Önce kimlik doğrula
    bool isAuthenticated = await authenticate(
      localizedReason: 'Kasa şifresini çözmek için doğrulama gerekli'
    );

    // 2. Başarısızsa null dön (Şifreye erişim yok)
    if (!isAuthenticated) {
      debugPrint('Doğrulama başarısız, şifre verilmedi.');
      return null;
    }

    // 3. Sadece şimdi şifreyi storage'dan oku
    return await _getStoredPassword();
  }

  /// Özel metod: Şifreyi storage'dan okur (Sadece içeriden çağrılabilir)
  Future<String?> _getStoredPassword() async {
    return await storage.read(key: _keyPassword);
  }

  /// Biyometrik girişi etkinleştir ve şifreyi güvenli sakla
  Future<void> enableBiometricLogin(String password) async {
    await storage.write(key: _keyPassword, value: password);
    await storage.write(key: _keyBiometricEnabled, value: 'true');
  }

  /// Biyometrik girişi devre dışı bırak
  Future<void> disableBiometricLogin() async {
    await storage.delete(key: _keyPassword);
    await storage.delete(key: _keyBiometricEnabled);
  }

  /// Biyometrik giriş özelliğinin açık olup olmadığını kontrol et
  Future<bool> isBiometricEnabled() async {
    return await storage.read(key: _keyBiometricEnabled) == 'true';
  }
}
