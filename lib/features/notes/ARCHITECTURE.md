# Note Feature Architecture (`features/notes`)

## Overview
This document describes the Clean Architecture and local-first Markdown persistence design of the `features/notes` module in **GümüşNot**.

## Clean Architecture Layers

```text
┌──────────────────────────────────────────────────────────┐
│ Presentation Layer (presentation/, widgets/)             │
│ MainScreen, NoteListScreen, MarkdownEditor, MathRenderer │
├──────────────────────────────────────────────────────────┤
│ State Management Layer (providers/)                      │
│ NoteProvider, NoteEditorProvider                         │
├──────────────────────────────────────────────────────────┤
│ Domain & Service Layer (services/, models/)              │
│ AdvancedSearchService, BacklinkService, GitSyncService,  │
│ WorkspaceService, TemplateFileStorage, VoiceNoteService  │
├──────────────────────────────────────────────────────────┤
│ Data Access Layer (repositories/, core/storage/)         │
│ NoteRepository -> MarkdownNoteRepository,                │
│ NoteMarkdownCodec, MarkdownFrontmatter,                  │
│ NoteEncryptionService                                    │
└──────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Repository Pattern
* **`NoteRepository`** (`repositories/note_repository.dart`): Abstract contract for note, template, backlink, task, and statistics operations.
* **`MarkdownNoteRepository`** (`repositories/markdown_note_repository.dart`): Production implementation storing each note as `<SanitizedTitle>.md` with YAML frontmatter in `<Documents>/GumusNot/notes/`. Features:
  * Incremental in-memory `FileStat` (`modified` timestamp + `size`) caching with a 2-second directory scan TTL.
  * Atomic file writes via temporary sibling files (`<target>.<timestamp>.tmp` -> `flush()` -> `rename()`).
  * Automatic `[[WikiLink]]` propagation across the workspace when a note title is renamed.
  * Ciphertext preservation when saving metadata updates on locked vault notes.
* **`MockNoteRepository`** (`repositories/mock_note_repository.dart`): In-memory implementation for unit and widget tests.

### 2. Services
* **`WorkspaceService`** (`services/workspace_service.dart`): Manages active workspace path and watches `<Documents>/GumusNot/notes/` via `Directory.watch` (with 400ms debounce and internal-write suppression) to reload external edits automatically.
* **`GitSyncService`** (`services/git_sync_service.dart`): Initializes a local Git repository in the notes directory, serializes all Git CLI invocations through an async mutex queue, debounces auto-commits (4s), and parses commit history (`NoteHistory`) and diffs (`NoteDiff`).
* **`AdvancedSearchService`** (`services/advanced_search_service.dart`): Implements `SearchService` (`services/search_service_interface.dart`) with multi-criteria filtering, Levenshtein fuzzy matching, incoming-link PageRank boost, and exponential recency decay.
* **`BacklinkService`** (`services/backlink_service.dart`): Computes incoming `[[WikiLink]]` backlinks, broken links, link statistics, and cross-note link renaming.
* **`TemplateFileStorage`** (`services/template_file_storage.dart`): Persists custom note templates as `.md` files under `<Documents>/GumusNot/templates/`.

### 3. State Management & Dependency Injection
* **`NoteProvider`** (`providers/note_provider.dart`): Coordinates UI state, folder/tag filtering, search results, and reactive workspace updates.
* **`NoteEditorProvider`** (`providers/note_editor_provider.dart`): Tracks active note encryption/decryption state in the editor.
* **`NoteDependencyInjection`** (`di/note_dependency_injection.dart`): Wires `WorkspaceService`, `GitSyncService`, `NoteEncryptionService`, `NoteRepository`, `BacklinkService`, `SearchService`, `NoteProvider`, and `NoteEditorProvider` into the widget tree.
