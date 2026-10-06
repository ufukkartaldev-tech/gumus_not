import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class NoteEditorProvider with ChangeNotifier {
  NoteEditorProvider();

  final bool _isBusy = false;
  bool _isEncrypted = false;
  bool _isDecrypted = false;
  String? _resolvedContent;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  bool get isEncrypted => _isEncrypted;
  bool get isDecrypted => _isDecrypted;
  String? get resolvedContent => _resolvedContent;
  String? get errorMessage => _errorMessage;

  Future<void> initialize(Note? note) async {
    _isEncrypted = false;
    _isDecrypted = true;
    _resolvedContent = note?.content;
    _errorMessage = null;
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
