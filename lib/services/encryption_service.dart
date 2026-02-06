import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class EncryptionService {
  static Key? _key;
  static IV? _iv;
  static Encrypter? _encrypter;
  static String? _recoveryKey;

  static EncryptionService? _instance;
  static EncryptionService get instance {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  EncryptionService._();

  static Future<void> initialize(String password, {String? recoveryKey}) async {
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final ivBytes = sha256.convert(utf8.encode(password + 'iv')).bytes.take(16).toList();
    
    _encrypter = Encrypter(AES(Key(Uint8List.fromList(keyBytes))));
    _iv = IV(Uint8List.fromList(ivBytes));
    
    // Generate and store recovery key if not provided
    if (recoveryKey == null) {
      _recoveryKey = _generateRecoveryKey(password);
    } else {
      _recoveryKey = recoveryKey;
    }
  }

  static String _generateRecoveryKey(String password) {
    // Generate a recovery key based on password + fixed salt
    // Note: This is currently just a hash of the password and doesn't allow true recovery without password
    // properly implemented, this would need to wrap the master key.
    const salt = 'recovery_salt_fixed_v1';
    final combined = password + salt;
    
    final recoveryBytes = sha256.convert(utf8.encode(combined)).bytes;
    return base64.encode(Uint8List.fromList(recoveryBytes));
  }

  static bool verifyRecoveryKey(String recoveryKey, String password) {
    try {
      final decodedKey = base64.decode(recoveryKey);
      const salt = 'recovery_salt_fixed_v1';
      final combined = password + salt;
      
      final expectedBytes = sha256.convert(utf8.encode(combined)).bytes;
      return const ListEquality().equals(decodedKey, expectedBytes);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> attemptRecovery(String recoveryKey) async {
    // This would typically involve prompting for the original password
    // For now, we'll implement a basic verification
    try {
      // Try to decode the recovery key to see if it's valid
      base64.decode(recoveryKey);
      _recoveryKey = recoveryKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  static String getRecoveryKey() {
    return _recoveryKey ?? '';
  }

  static String encrypt(String plainText) {
    if (_encrypter == null) {
      throw Exception('Anahtar oluşturulmadı (Kasa kilitli)');
    }
    
    // Rastgele IV oluştur (Her şifreleme için benzersiz olmalı - FBI bile desen bulamaz)
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    
    // IV + Şifreli Veri'yi birleştirip Base64 yapıyoruz
    // Böylece her şifrelemede sonuç farklı görünür (Semantic Security)
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decrypt(String encryptedPackage) {
    if (_encrypter == null) {
       throw Exception('Anahtar oluşturulmadı (Kasa kilitli)');
    }

    try {
      // Paketi aç: IV : CipherText
      final parts = encryptedPackage.split(':');
      if (parts.length != 2) {
        // Eski format desteği veya bozuk veri
        // Eğer eski bir sistemden geçiş yapıyorsak burayı yönetmeliyiz ama
        // şimdilik clean-start varsayıyoruz veya hata fırlatıyoruz.
        throw Exception('Geçersiz şifreleme formatı');
      }

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Şifre çözme hatası: Yanlış anahtar veya bozuk veri');
    }
  }

  // --- Özel/Tekil Şifreleme Metodları (Per-Note Encryption) ---

  static String encryptWithPassword(String plainText, String password) {
    if (plainText.isEmpty) return '';

    // 1. Salt Üret (Rainbow Table saldırılarına karşı)
    // Her not için benzersiz bir tuz (salt) oluşturuyoruz.
    final salt = IV.fromSecureRandom(16);
    
    // 2. Anahtar Türet (Password + Salt -> Key)
    // Basit bir KDF (Key Derivation Function) simülasyonu
    final key = Key(Uint8List.fromList(sha256.convert(utf8.encode(password + salt.base64)).bytes));
    
    // 3. IV Üret
    final iv = IV.fromSecureRandom(16);
    
    // 4. Şifrele
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // 5. Paketle: Salt:IV:Cipher
    return '${salt.base64}:${iv.base64}:${encrypted.base64}';
  }

  static String decryptWithPassword(String encryptedPackage, String password) {
    try {
      final parts = encryptedPackage.split(':');
      if (parts.length != 3) {
        throw Exception('Geçersiz şifre paketi');
      }

      final salt = IV.fromBase64(parts[0]);
      final iv = IV.fromBase64(parts[1]);
      final encrypted = Encrypted.fromBase64(parts[2]);

      // Anahtarı yeniden türet
      final key = Key(Uint8List.fromList(sha256.convert(utf8.encode(password + salt.base64)).bytes));
      
      final encrypter = Encrypter(AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Şifre yanlışsa genellikle padding hatası veya garbage data oluşur
      throw Exception('Şifre hatalı veya veri bozuk');
    }
  }

  static bool isInitialized() {
    return _encrypter != null;
  }

  static void clear() {
    _key = null;
    _iv = null; 
    _encrypter = null;
    _recoveryKey = null;
  }
}
