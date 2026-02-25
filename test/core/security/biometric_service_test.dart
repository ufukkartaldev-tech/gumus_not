import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:connected_notebook/core/security/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  const MethodChannel channel = MethodChannel('plugins.flutter.io/local_auth');

  group('BiometricService Tests', () {
    List<String> mockGetAvailableBiometrics = ['strong', 'weak', 'face', 'fingerprint'];
    bool mockIsDeviceSupported = true;
    bool mockAuthenticate = true;
    
    late BiometricService biometricService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      
      biometricService = BiometricService(
        auth: LocalAuthentication(),
        storage: const FlutterSecureStorage(),
      );
      
      // Setup Mock Method Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAvailableBiometrics':
              return mockGetAvailableBiometrics;
            case 'isDeviceSupported':
              return mockIsDeviceSupported;
            case 'authenticate':
              return mockAuthenticate;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('getStatus returns BiometricStatus.ready when device is supported and biometrics available', () async {
      mockIsDeviceSupported = true;
      mockGetAvailableBiometrics = ['face'];
      
      final status = await biometricService.getStatus();
      expect(status, BiometricStatus.ready);
    });
    
    test('getStatus returns BiometricStatus.supportedButNotEnrolled when available biometrics is empty', () async {
      mockIsDeviceSupported = true;
      mockGetAvailableBiometrics = [];
      
      final status = await biometricService.getStatus();
      expect(status, BiometricStatus.supportedButNotEnrolled);
    });

    test('getAvailableBiometrics returns matching values', () async {
      mockGetAvailableBiometrics = ['face', 'fingerprint'];
      final biometrics = await biometricService.getAvailableBiometrics();
      expect(biometrics.length, 2);
    });

    test('authenticate returns true on success', () async {
      mockAuthenticate = true;
      final result = await biometricService.authenticate(localizedReason: 'Test');
      expect(result, isTrue);
    });

    test('authenticate returns false on failure', () async {
      mockAuthenticate = false;
      final result = await biometricService.authenticate(localizedReason: 'Test');
      expect(result, isFalse);
    });

    test('enableBiometricLogin saves password and sets enabled flag', () async {
      await biometricService.enableBiometricLogin('test_password');
      
      final isEnabled = await biometricService.isBiometricEnabled();
      expect(isEnabled, isTrue);
    });

    test('disableBiometricLogin removes password and enabled flag', () async {
      await biometricService.enableBiometricLogin('test_password');
      await biometricService.disableBiometricLogin();
      
      final isEnabled = await biometricService.isBiometricEnabled();
      expect(isEnabled, isFalse);
    });

    test('authenticateAndRetrievePassword returns password on success', () async {
      mockAuthenticate = true;
      await biometricService.enableBiometricLogin('secure_password123');
      
      final password = await biometricService.authenticateAndRetrievePassword();
      expect(password, 'secure_password123');
    });

    test('authenticateAndRetrievePassword returns null if auth fails', () async {
      mockAuthenticate = false;
      await biometricService.enableBiometricLogin('secure_password123');
      
      final password = await biometricService.authenticateAndRetrievePassword();
      expect(password, isNull);
    });
  });
}
