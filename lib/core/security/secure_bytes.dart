import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Mutable and wipeable byte container for sensitive material.
///
/// Note: In managed runtimes like Dart/Flutter, full memory-erasure guarantees
/// cannot be made for every temporary copy created by the runtime. This class
/// minimizes exposure by keeping sensitive data in mutable byte arrays and
/// providing explicit wipe semantics.
class SecureBytes {
  SecureBytes._(Uint8List bytes) : _bytes = bytes;

  Uint8List? _bytes;

  factory SecureBytes.fromBytes(Uint8List bytes, {bool copy = true}) {
    return SecureBytes._(copy ? Uint8List.fromList(bytes) : bytes);
  }

  factory SecureBytes.fromUtf8(String value) {
    return SecureBytes._(Uint8List.fromList(utf8.encode(value)));
  }

  bool get isDisposed => _bytes == null;

  int get length {
    final bytes = _requireBytes();
    return bytes.length;
  }

  Uint8List copy() {
    final bytes = _requireBytes();
    return Uint8List.fromList(bytes);
  }

  Uint8List borrow() {
    return _requireBytes();
  }

  void wipe() {
    final bytes = _bytes;
    if (bytes == null) return;

    final random = Random.secure();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }

    _bytes = null;
  }

  Uint8List _requireBytes() {
    final bytes = _bytes;
    if (bytes == null) {
      throw StateError('SecureBytes has already been wiped.');
    }
    return bytes;
  }
}
