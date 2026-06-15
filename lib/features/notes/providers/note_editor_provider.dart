import 'package:flutter/foundation.dart';

import '../models/note_model.dart';
import '../providers/vault_provider.dart';

/// View model for editor-specific encryption state.
class NoteEditorProvider with ChangeNotifier {
  NoteEditorProvider({required VaultProvider vaultProvider})
      : _vaultProvider = vaultProvider;

  final VaultProvider _vaultProvider;

  bool _isBusy = false;
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
    _isEncrypted = note?.isEncrypted ?? false;
    _isDecrypted = !_isEncrypted;
    _resolvedContent = note?.isEncrypted == true ? null : note?.content;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> unlockNote(Note note) async {
    await _runBusy(() async {
      final content = await _vaultProvider.resolveReadableContent(note);
      _resolvedContent = content;
      _isEncrypted = true;
      _isDecrypted = true;
    });
  }

  void setEncrypted(bool value) {
    _isEncrypted = value;
    if (!value) {
      _isDecrypted = true;
    }
    notifyListeners();
  }

  Future<T> _runBusy<T>(Future<T> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await operation();
      _errorMessage = null;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
