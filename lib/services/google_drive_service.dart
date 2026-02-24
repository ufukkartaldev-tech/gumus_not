import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'encryption_service.dart';
import '../models/note_model.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final _secureStorage = const FlutterSecureStorage();
  drive.DriveApi? _driveApi;
  AuthClient? _client;
  
  // Google OAuth istemci kimlikleri (bunları Google Cloud Console'dan almalısınız)
  static const String _clientId = 'YOUR_CLIENT_ID_HERE';
  static const String _clientSecret = 'YOUR_CLIENT_SECRET_HERE';
  static const List<String> _scopes = [drive.DriveApi.driveScope];

  // Google kimlik doğrulama
  Future<bool> authenticate() async {
    try {
      final credentials = await _getStoredCredentials();
      
      if (credentials != null) {
        _client = authenticatedClient(
          http.Client(),
          credentials,
        );
        _driveApi = drive.DriveApi(_client!);
        return true;
      }

      // Yeni kimlik doğrulama gerekli
      return await _authenticateNewUser();
    } catch (e) {
      print("Google Drive kimlik doğrulama hatası: $e");
      return false;
    }
  }

  Future<AccessCredentials?> _getStoredCredentials() async {
    try {
      final stored = await _secureStorage.read(key: 'google_credentials');
      if (stored != null) {
        final credentialsJson = json.decode(stored);
        return AccessCredentials.fromJson(credentialsJson);
      }
    } catch (e) {
      print("Kayıtlı kimlik bilgileri okunamadı: $e");
    }
    return null;
  }

  Future<bool> _authenticateNewUser() async {
    try {
      final client = await clientViaUserConsent(
        ClientId(_clientId, _clientSecret),
        _scopes,
        (prompt) => print('Please go to the following URL and grant access: $prompt'),
      );
      
      _client = client;
      _driveApi = drive.DriveApi(client);
      
      // Kimlik bilgilerini güvenli sakla
      await _secureStorage.write(
        key: 'google_credentials',
        value: json.encode(client.credentials.toJson()),
      );
      
      return true;
    } catch (e) {
      print("Yeni kullanıcı kimlik doğrulama hatası: $e");
      return false;
    }
  }

  // Veritabanını şifrele ve Google Drive'a yedekle
  Future<bool> backupToDrive() async {
    try {
      if (_driveApi == null) {
        final authenticated = await authenticate();
        if (!authenticated) return false;
      }

      // Veritabanını al
      final notes = await DatabaseService.getAllNotes();
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': true,
      };

      // Veriyi şifrele
      final encryptedData = EncryptionService.encrypt(json.encode(backupData));

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/gumusnot_backup_${DateTime.now().millisecondsSinceEpoch}.gnb');
      await backupFile.writeAsString(encryptedData);

      // Google Drive'a yükle
      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
      final driveFile = drive.File(
        name: 'GumusNot_Backup_${DateTime.now().toIso8601String()}.gnb',
        parents: ['appDataFolder'], // Uygulama özel klasörü
      );

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Geçici dosyayı temizle
      await backupFile.delete();

      print("Yedekleme başarıyla tamamlandı: ${result.name}");
      return true;
    } catch (e) {
      print("Google Drive yedekleme hatası: $e");
      return false;
    }
  }

  // Google Drive'dan yedek al ve geri yükle
  Future<bool> restoreFromDrive() async {
    try {
      if (_driveApi == null) {
        final authenticated = await authenticate();
        if (!authenticated) return false;
      }

      // Google Drive'daki yedek dosyalarını listele
      final response = await _driveApi!.files.list(
        q: "name contains 'GumusNot_Backup' and name contains '.gnb'",
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 10,
      );

      if (response.files!.isEmpty) {
        print("Yedek dosyası bulunamadı");
        return false;
      }

      // En son yedek dosyasını indir
      final latestBackup = response.files!.first;
      final downloadedFile = await _driveApi!.files.get(
        latestBackup.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/restore_backup.gnb');
      
      // İndirilen veriyi dosyaya yaz
      if (downloadedFile is drive.Media) {
        final downloadData = await downloadedFile.stream.fold(
          BytesBuilder(),
          (builder, data) => builder..add(data),
        );
        await backupFile.writeAsBytes(downloadData.toBytes());
      } else {
        // Alternatif yöntem
        final response = await http.get(Uri.parse('https://www.googleapis.com/drive/v3/files/${latestBackup.id}?alt=media'));
        await backupFile.writeAsBytes(response.bodyBytes);
      }

      // Şifreli veriyi çöz
      final encryptedContent = await backupFile.readAsString();
      final decryptedData = EncryptionService.decrypt(encryptedContent);
      
      final backupData = json.decode(decryptedData);
      
      // Mevcut verileri temizle (isteğe bağlı)
      // await DatabaseService.clearAllNotes();
      
      // Yedeklenen verileri geri yükle
      final notes = (backupData['notes'] as List)
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
      
      for (final note in notes) {
        await DatabaseService.insertNote(note);
      }

      // Geçici dosyayı temizle
      await backupFile.delete();

      print("Geri yükleme başarıyla tamamlandı: ${latestBackup.name}");
      print("${notes.length} not geri yüklendi");
      return true;
    } catch (e) {
      print("Google Drive geri yükleme hatası: $e");
      return false;
    }
  }

  // Yedekleme geçmişini listele
  Future<List<Map<String, dynamic>>> getBackupHistory() async {
    try {
      if (_driveApi == null) {
        final authenticated = await authenticate();
        if (!authenticated) return [];
      }

      final response = await _driveApi!.files.list(
        q: "name contains 'GumusNot_Backup' and name contains '.gnb'",
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 20,
      );

      return response.files!.map((file) => {
        'id': file.id,
        'name': file.name,
        'createdTime': file.createdTime,
        'size': file.size,
      }).toList();
    } catch (e) {
      print("Yedekleme geçmişi alma hatası: $e");
      return [];
    }
  }

  // Kimlik doğrulamayı sıfırla
  Future<void> signOut() async {
    try {
      _client?.close();
      _client = null;
      _driveApi = null;
      await _secureStorage.delete(key: 'google_credentials');
      print("Google Drive kimlik doğrulaması sıfırlandı");
    } catch (e) {
      print("Çıkış yapma hatası: $e");
    }
  }

  // Servis durumunu kontrol et
  bool get isAuthenticated => _driveApi != null;
  
  void dispose() {
    _client?.close();
  }
}
