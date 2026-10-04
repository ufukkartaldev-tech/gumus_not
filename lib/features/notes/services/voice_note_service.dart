import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceNoteService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  /// Mikrofon izni ve dil motoru başlatma
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }

    _isInitialized = await _speech.initialize(
      onError: (val) => print('Speech Error: $val'),
      onStatus: (val) => print('Speech Status: $val'),
    );

    return _isInitialized;
  }

  /// Dinlemeye başlar
  Future<void> startListening(Function(String) onResult) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: 'tr_TR', // Varsayılan Türkçe, ileride ayarlardan çekilebilir
      cancelOnError: true,
      partialResults: true,
    );
  }

  /// Dinlemeyi durdurur
  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
