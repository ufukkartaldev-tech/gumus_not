import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive_io.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class CloudSyncService {
  static const String _dbName = 'connected_notebook.db';
  static const String _backupFileName = 'gumusnot_secure_backup.enc';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  /// Kullanıcının parolasıyla 32-byte (256-bit) AES anahtarı oluşturur
  enc.Key _generateKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Google ile giriş yapıp yetkilendirilmiş Drive API istemcisi döner
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      var account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      
      if (account == null) return null; // İptal edildi

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    } catch (e) {
      debugPrint('Google Sign-In Hatası: $e');
      return null;
    }
  }

  /// Veritabanını kilitli ZIP'e çevirir ve Drive'a yükler
  Future<Map<String, dynamic>> backupToDrive(String password) async {
    if (kIsWeb) return {'success': false, 'message': 'Web sürümü desteklenmiyor.'};

    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return {'success': false, 'message': 'Google girişi yapılamadı veya iptal edildi.'};

      // 1. Veritabanını Oku ve Zip'le
      final dbPath = p.join(await getDatabasesPath(), _dbName);
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return {'success': false, 'message': 'Veritabanı dosyası bulunamadı.'};

      final dbBytes = await dbFile.readAsBytes();
      final archive = Archive()..addFile(ArchiveFile(_dbName, dbBytes.length, dbBytes));
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Zip oluşturulamadı.');

      // 2. Şifrele (AES-256)
      final key = _generateKey(password);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));
      
      final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);
      
      // IV'yi (16 byte) dosyanın başına ekleyelim ki çözerken doğru vektörü bilelim
      final finalBytes = <int>[...iv.bytes, ...encrypted.bytes];

      // 3. Drive'a Yükle (appDataFolder -> Kullanıcı bu klasörü göremez, çok güvenlidir)
      final media = drive.Media(Stream.value(finalBytes), finalBytes.length);
      final driveFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      // Eski yedeği bul ve güncelle (Eğer yoksa yeni oluştur)
      final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: "name='$_backupFileName'");
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), existingFileId, uploadMedia: media);
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      return {'success': true, 'message': 'Yedek başarıyla şifrelenip buluta yüklendi! 🔒'};
    } catch (e) {
      debugPrint('Bulut yedekleme hatası: $e');
      return {'success': false, 'message': 'Yedekleme başarısız: $e'};
    }
  }

  /// Drive'dan şifreli yedeği indirir, parolayı çözer ve geri yükler
  Future<Map<String, dynamic>> restoreFromDrive(String password) async {
    if (kIsWeb) return {'success': false, 'message': 'Web sürümü desteklenmiyor.'};

    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return {'success': false, 'message': 'Google girişi yapılamadı.'};

      // 1. Dosyayı Bul
      final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: "name='$_backupFileName'");
      if (fileList.files == null || fileList.files!.isEmpty) {
        return {'success': false, 'message': 'Bulutta size ait bir yedek bulunamadı.'};
      }
      
      final fileId = fileList.files!.first.id!;

      // 2. Dosyayı İndir
      final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      if (bytes.length <= 16) return {'success': false, 'message': 'Yedek dosyası bozuk.'};

      // 3. Şifreyi Çöz
      final key = _generateKey(password);
      final ivBytes = Uint8List.fromList(bytes.sublist(0, 16));
      final encryptedBytes = Uint8List.fromList(bytes.sublist(16));
      
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key));
      
      List<int> decryptedZipBytes;
      try {
        decryptedZipBytes = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
      } catch (e) {
        // Parola yanlışsa çözme işleminde hata fırlatır
        return {'success': false, 'message': 'Parola yanlış! Yedeğiniz açılamadı. ❌'};
      }

      // 4. Zip'i aç ve veritabanını yerine koy
      final archive = ZipDecoder().decodeBytes(decryptedZipBytes);
      ArchiveFile? dbArchiveFile;
      for (final file in archive) {
        if (file.name == _dbName) {
          dbArchiveFile = file;
          break;
        }
      }

      if (dbArchiveFile == null) return {'success': false, 'message': 'Şifre çözüldü ancak içinden veritabanı çıkmadı.'};

      final dbPath = p.join(await getDatabasesPath(), _dbName);
      final newDbBytes = dbArchiveFile.content as List<int>;
      await File(dbPath).writeAsBytes(newDbBytes, flush: true);

      return {'success': true, 'message': 'Yedek başarıyla indirildi ve şifresi çözülüp geri yüklendi! ✅ Uygulamayı yeniden başlatın.'};
    } catch (e) {
      debugPrint('Bulut geri yükleme hatası: $e');
      return {'success': false, 'message': 'Geri yükleme başarısız: $e'};
    }
  }
}
