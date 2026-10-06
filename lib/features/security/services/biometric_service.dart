import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Cihazda biyometrik veya cihaz kilidi (PIN/Şifre) var mı kontrol eder
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      return false;
    }
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
        stickyAuth: true,
        biometricOnly: false,
        useErrorDialogs: true,
      );
    } on PlatformException catch (e) {
      return false;
    }
  }
}
