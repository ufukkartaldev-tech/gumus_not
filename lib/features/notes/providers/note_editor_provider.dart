import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class NoteEditorProvider with ChangeNotifier {
  NoteEditorProvider();

  bool _isEncrypted = false;
  bool _isDecrypted = false;

  bool get isEncrypted => _isEncrypted;
  bool get isDecrypted => _isDecrypted;

  Future<void> initialize(Note? note) async {
    _isEncrypted = note?.isEncrypted ?? false;
    _isDecrypted = !_isEncrypted;
    notifyListeners();
  }

  void setEncrypted(bool value) {
    _isEncrypted = value;
    if (!value) {
      _isDecrypted = true;
    }
    notifyListeners();
  }
}
