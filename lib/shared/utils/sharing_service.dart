import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/core/database/database_service.dart';

class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  void initialize(BuildContext context) {
    // Windows platformunda paylaşım özelliğini devre dışı bırak
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      print("Paylaşım özelliği masaüstü platformlarda desteklenmiyor");
      return;
    }
    
    // TODO: Mobil platformlar için ReceiveSharingIntent implementasyonu
    print("Paylaşım özelliği mobil platformlarda aktif edilecek");
  }

  void dispose() {
    // No cleanup needed for now
  }
}
