import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/features/security/services/biometric_service.dart';

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool canCheck = false;
  bool isSupported = false;
  bool authResult = false;
  bool throwOnCanCheck = false;

  @override
  Future<bool> get canCheckBiometrics async {
    if (throwOnCanCheck) throw PlatformException(code: 'NotAvailable');
    return canCheck;
  }

  @override
  Future<bool> isDeviceSupported() async {
    return isSupported;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      return Future.value(authResult);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocalAuthentication fakeAuth;
  late BiometricService biometricService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeAuth = FakeLocalAuthentication();
    biometricService = BiometricService(auth: fakeAuth);
  });

  group('BiometricService Fail-Closed Security Tests', () {
    test('authenticate returns false (fail-closed) when device does not support biometrics or lock', () async {
      fakeAuth.canCheck = false;
      fakeAuth.isSupported = false;

      final result = await biometricService.authenticate();

      expect(result, isFalse, reason: 'Must fail-closed when hardware is unsupported');
    });

    test('authenticate returns false when PlatformException is thrown', () async {
      fakeAuth.throwOnCanCheck = true;

      final result = await biometricService.authenticate();

      expect(result, isFalse);
    });

    test('authenticate returns true when device supports biometrics and auth succeeds', () async {
      fakeAuth.canCheck = true;
      fakeAuth.isSupported = true;
      fakeAuth.authResult = true;

      final result = await biometricService.authenticate();

      expect(result, isTrue);
    });

    test('authenticate returns false when user cancels authentication', () async {
      fakeAuth.canCheck = true;
      fakeAuth.isSupported = true;
      fakeAuth.authResult = false;

      final result = await biometricService.authenticate();

      expect(result, isFalse);
    });

    test('isAppLockEnabled defaults to false and persists correctly', () async {
      expect(await biometricService.isAppLockEnabled(), isFalse);

      await biometricService.setAppLockEnabled(true);
      expect(await biometricService.isAppLockEnabled(), isTrue);

      await biometricService.setAppLockEnabled(false);
      expect(await biometricService.isAppLockEnabled(), isFalse);
    });
  });
}
