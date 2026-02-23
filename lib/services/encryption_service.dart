import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class EncryptionService {
  static Uint8List? _masterKey;
  static Encrypter? _encrypter;
  static String? _recoveryKey;
  
  static const _storage = FlutterSecureStorage();
  static const _storageKeyWrappedPW = 'vault_mk_wrapped_pw';
  static const _storageKeyWrappedRecovery = 'vault_mk_wrapped_rec';
  static const _storageKeyIV = 'vault_mk_iv'; // Master key wrapping salt/iv

  static EncryptionService? _instance;
  static EncryptionService get instance {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  EncryptionService._();

  /// Kasa ilk kez kurulurken veya şifre ile açılırken kullanılır.
  static Future<void> initialize(String password, {String? recoveryKey}) async {
    final wrappedPW = await _storage.read(key: _storageKeyWrappedPW);
    
    if (wrappedPW == null) {
      // YENİ KURULUM: Master Key ve Recovery Key üret
      await _setupNewVault(password, recoveryKey: recoveryKey);
    } else {
      // MEVCUT KASA: Master Key'i şifre ile çöz (Unwrap)
      await _unlockWithPassword(password, wrappedPW);
    }
  }

  /// Kasa kurtarma anahtarı ile açılırken kullanılır.
  static Future<bool> initializeWithRecoveryKey(String recoveryKey) async {
    final wrappedRec = await _storage.read(key: _storageKeyWrappedRecovery);
    if (wrappedRec == null) return false;

    try {
      final mkBytes = await _unwrapKey(wrappedRec, recoveryKey);
      _masterKey = mkBytes;
      _encrypter = Encrypter(AES(Key(_masterKey!)));
      
      // Şifre unutulduğu için kurtarma sonrası yeni şifre istenmeli, 
      // ama şimdilik MK'ye eriştik.
      _recoveryKey = recoveryKey; 
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _setupNewVault(String password, {String? recoveryKey}) async {
    // 1. Rastgele Master Key üret (32 byte / 256 bit)
    final mk = Uint8List.fromList(List.generate(32, (index) => Random.secure().nextInt(256)));
    
    // 2. Kurtarma Anahtarı belirle (varsa kullan, yoksa üret)
    _recoveryKey = recoveryKey ?? _generateSecureRandomString(24);
    
    // 3. Şifre ve Kurtarma Anahtarı ile Master Key'i paketle (Wrap)
    final wrappedPW = await _wrapKey(mk, password);
    final wrappedRec = await _wrapKey(mk, _recoveryKey!);
    
    // 4. Paketleri sakla
    await _storage.write(key: _storageKeyWrappedPW, value: wrappedPW);
    await _storage.write(key: _storageKeyWrappedRecovery, value: wrappedRec);
    
    _masterKey = mk;
    _encrypter = Encrypter(AES(Key(_masterKey!)));
  }

  static Future<void> _unlockWithPassword(String password, String wrappedPW) async {
    try {
      final mkBytes = await _unwrapKey(wrappedPW, password);
      _masterKey = mkBytes;
      _encrypter = Encrypter(AES(Key(_masterKey!)));
      
      // Recovery key'i storage'dan veya logic'ten çekebiliriz 
      // ama zaten MK'miz var.
    } catch (e) {
      throw Exception('Şifre hatalı veya kasa bozuk');
    }
  }

  // --- Yardımcı Metodlar (Key Wrapping) ---

  static Future<String> _wrapKey(Uint8List keyToWrap, String protectionKey) async {
    // KDF: Şifreden AES anahtarı türet
    final derivedKey = Key(Uint8List.fromList(sha256.convert(utf8.encode(protectionKey)).bytes));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(derivedKey));
    
    final encrypted = encrypter.encryptBytes(keyToWrap, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<Uint8List> _unwrapKey(String wrappedPackage, String protectionKey) async {
    final parts = wrappedPackage.split(':');
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    
    final derivedKey = Key(Uint8List.fromList(sha256.convert(utf8.encode(protectionKey)).bytes));
    final encrypter = Encrypter(AES(derivedKey));
    
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }

  static String _generateSecureRandomString(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Okunabilir karakterler
    final rnd = Random.secure();
    return List.generate(length, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  // --- Genel API ---

  static String encrypt(String plainText) {
    if (_encrypter == null) throw Exception('Kasa kilitli');
    
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decrypt(String encryptedPackage) {
    if (_encrypter == null) throw Exception('Kasa kilitli');

    try {
      final parts = encryptedPackage.split(':');
      if (parts.length != 2) throw Exception('Format hatası');

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Şifre çözme hatası');
    }
  }

  // --- Bellek Güvenliği (Memory Hardening) ---

  static void wipe(Uint8List? list) {
    if (list == null) return;
    for (int i = 0; i < list.length; i++) {
      list[i] = 0;
    }
  }

  static void clear() {
    wipe(_masterKey);
    _masterKey = null;
    _encrypter = null;
    _recoveryKey = null;
    // GC'yi tetiklemek için hint (Dart'ta garantisi yok ama statik referansları koparmak önemli)
  }

  static bool isInitialized() => _encrypter != null;
  static String getRecoveryKey() => _recoveryKey ?? 'Kasa açıkken alınabilir';

  // --- Eski Uyumluluk veya Not Bazlı Şifreleme (Değişmedi ama Master Key entegre edilebilir) ---

  static String encryptWithPassword(String plainText, String password) {
    final salt = IV.fromSecureRandom(16);
    final key = Key(Uint8List.fromList(sha256.convert(utf8.encode(password + salt.base64)).bytes));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${salt.base64}:${iv.base64}:${encrypted.base64}';
  }

  static String decryptWithPassword(String encryptedPackage, String password) {
    final parts = encryptedPackage.split(':');
    final salt = IV.fromBase64(parts[0]);
    final iv = IV.fromBase64(parts[1]);
    final encoded = Encrypted.fromBase64(parts[2]);
    final key = Key(Uint8List.fromList(sha256.convert(utf8.encode(password + salt.base64)).bytes));
    return Encrypter(AES(key)).decrypt(encoded, iv: iv);
  }

  /// Kurtarma anahtarının geçerli olup olmadığını doğrular
  static bool verifyRecoveryKey(String recoveryKey, String password) {
    try {
      // Base64 format kontrolü
      final decoded = base64.decode(recoveryKey);
      if (decoded.length != 32) return false; // 256 bit = 32 byte
      
      // Kurtarma anahtarı formatı geçerli, gerçek doğrulama için attemptRecovery kullanılmalı
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Kurtarma anahtarı ile kurtarma işlemi yapar
  static Future<bool> attemptRecovery(String recoveryKey) async {
    try {
      final wrappedRec = await _storage.read(key: _storageKeyWrappedRecovery);
      if (wrappedRec == null) return false;

      final mkBytes = await _unwrapKey(wrappedRec, recoveryKey);
      _masterKey = mkBytes;
      _encrypter = Encrypter(AES(Key(_masterKey!)));
      _recoveryKey = recoveryKey;
      
      return true;
    } catch (e) {
      return false;
    }
  }
}

