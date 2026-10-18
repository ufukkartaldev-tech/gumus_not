import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/widgets/custom_widgets.dart';

/// Minimal, high-productivity app bar for the markdown editor with quick toggles and options menu.
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String statusLabel;
  final bool isDirty;
  final bool isAutoSaving;
  final bool isLoading;
  final bool isEncrypted;
  final bool isUnlocked;
  final bool isPreviewMode;
  final bool isRecording;
  final bool isAiLoading;
  final int? selectedColor;
  final bool isPomodoroVisible;
  final bool isCrossReferenceVisible;
  final bool canShowBacklinks;

  final VoidCallback onBackPressed;
  final VoidCallback onToggleEncryption;
  final VoidCallback onTogglePreview;
  final VoidCallback onToggleVoiceRecording;
  final VoidCallback onShowAiMenu;
  final VoidCallback onSaveNote;
  final VoidCallback onSelectColor;
  final VoidCallback onShowTagSheet;
  final VoidCallback onTogglePomodoro;
  final VoidCallback onToggleBacklinks;
  final VoidCallback onExportPdf;
  final VoidCallback onExportLatex;
  final VoidCallback onShare;
  final VoidCallback onToggleFocusMode;

  const EditorAppBar({
    super.key,
    required this.statusLabel,
    required this.isDirty,
    required this.isAutoSaving,
    required this.isLoading,
    required this.isEncrypted,
    required this.isUnlocked,
    required this.isPreviewMode,
    required this.isRecording,
    required this.isAiLoading,
    required this.selectedColor,
    required this.isPomodoroVisible,
    required this.isCrossReferenceVisible,
    required this.canShowBacklinks,
    required this.onBackPressed,
    required this.onToggleEncryption,
    required this.onTogglePreview,
    required this.onToggleVoiceRecording,
    required this.onShowAiMenu,
    required this.onSaveNote,
    required this.onSelectColor,
    required this.onShowTagSheet,
    required this.onTogglePomodoro,
    required this.onToggleBacklinks,
    required this.onExportPdf,
    required this.onExportLatex,
    required this.onShare,
    required this.onToggleFocusMode,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomAppBar(
      title: statusLabel,
      showBackButton: true,
      onBackPressed: onBackPressed,
      actions: [
        // Vault Lock / Unlock Toggle
        IconButton(
          icon: Icon(
            !isEncrypted
                ? Icons.lock_outline
                : (isUnlocked ? Icons.lock_open : Icons.lock),
            color: isEncrypted ? theme.colorScheme.primary : null,
          ),
          onPressed: onToggleEncryption,
          tooltip: !isEncrypted
              ? 'Notu Şifrele'
              : (isUnlocked ? 'Şifrelemeyi Kaldır' : 'Kasayı Aç'),
        ),

        // Live Preview / Preview Toggle
        IconButton(
          icon: Icon(
            isPreviewMode ? Icons.edit_note_rounded : Icons.remove_red_eye_outlined,
            color: isPreviewMode ? theme.colorScheme.primary : null,
          ),
          onPressed: onTogglePreview,
          tooltip: isPreviewMode ? 'Düzenleme Modu' : 'Tam Önizleme',
        ),

        // Voice Note Toggle
        IconButton(
          icon: Icon(
            isRecording ? Icons.mic : Icons.mic_none,
            color: isRecording ? Colors.red : null,
          ),
          onPressed: onToggleVoiceRecording,
          tooltip: 'Sesli Not',
        ),

        // AI Assistant Toggle
        IconButton(
          icon: isAiLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          onPressed: isAiLoading ? null : onShowAiMenu,
          tooltip: 'Yapay Zeka Asistanı',
        ),

        // Save Button (Clean and prominent)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onSaveNote,
            icon: isAutoSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(isDirty ? 'Kaydet*' : 'Kaydet'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
        ),

        // Overflow Options Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tooltip: 'Daha Fazla Seçenek',
          onSelected: (value) {
            switch (value) {
              case 'color':
                onSelectColor();
                break;
              case 'tags':
                onShowTagSheet();
                break;
              case 'pomodoro':
                onTogglePomodoro();
                break;
              case 'backlinks':
                onToggleBacklinks();
                break;
              case 'pdf':
                onExportPdf();
                break;
              case 'latex':
                onExportLatex();
                break;
              case 'share':
                onShare();
                break;
              case 'focus':
                onToggleFocusMode();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'tags',
              child: Row(
                children: [
                  Icon(Icons.label_outline_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Etiketler & Mod'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'color',
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 20, color: selectedColor != null ? Color(selectedColor!) : null),
                  const SizedBox(width: 12),
                  const Text('Kağıt Rengi'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'focus',
              child: const Row(
                children: [
                  Icon(Icons.fullscreen_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Zen Odak Modu'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pomodoro',
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: isPomodoroVisible ? Colors.red : null),
                  const SizedBox(width: 12),
                  Text(isPomodoroVisible ? 'Pomodoro Gizle' : 'Pomodoro Sayacı'),
                ],
              ),
            ),
            if (canShowBacklinks)
              PopupMenuItem(
                value: 'backlinks',
                child: const Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Çapraz Bağlantılar'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'share',
              child: const Row(
                children: [
                  Icon(Icons.share_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Notu Paylaş'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('PDF Olarak Kaydet'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'latex',
              child: const Row(
                children: [
                  Icon(Icons.text_format_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('LaTeX Olarak Dışa Aktar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
