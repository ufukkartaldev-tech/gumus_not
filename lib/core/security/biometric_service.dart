
class BiometricService {
  Future<bool> isBiometricAvailable() async { return false; }
  Future<bool> authenticate(String reason) async { return true; }
  Future<void> enableBiometric(String password) async {}
  Future<void> disableBiometric() async {}
  Future<String?> getVaultPassword() async { return null; }
  Future<bool> isBiometricEnabled() async { return false; }
}
