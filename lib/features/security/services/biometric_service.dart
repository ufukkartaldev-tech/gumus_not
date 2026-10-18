import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  static const String _appLockKey = 'app_lock_enabled';

  /// Cihazda biyometrik veya cihaz kilidi (PIN/Şifre) var mı kontrol eder
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Kullanıcının uygulama kilidini açıp açmadığını döner (varsayılan: false)
  Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_appLockKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Uygulama kilidi tercihini günceller
  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockKey, enabled);
  }

  /// Kimlik doğrulama işlemini başlatır
  Future<bool> authenticate() async {
    try {
      final isSupported = await canCheckBiometrics();
      if (!isSupported) {
        // Cihaz kilit desteklemiyorsa erişime izin ver
        return true;
      }

      // biometricOnly: false -> Yüz/Parmak izi yoksa Windows Hello veya telefon PIN'ini sorar.
      return await _auth.authenticate(
        localizedReason: 'GümüşNot\'a erişmek için kimliğinizi doğrulayın',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
