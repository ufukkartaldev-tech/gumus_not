# Note Feature Architecture

## Overview
This document describes the refactored architecture for the note management feature in GümüşNot application.

## Architecture Principles

### 1. SOLID Principles Applied
- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Subtypes are substitutable for base types
- **Interface Segregation**: Clients depend on small, specific interfaces
- **Dependency Inversion**: High-level modules depend on abstractions

### 2. Clean Architecture Layers
```
┌─────────────────────────────────────┐
│           Presentation Layer        │ ← Screens, Widgets
├─────────────────────────────────────┤
│           Domain Layer              │ ← Use Cases, Entities
├─────────────────────────────────────┤
│           Data Layer                │ ← Repositories, Data Sources
└─────────────────────────────────────┘
```

## Component Details

### 1. Repository Pattern
**Purpose**: Abstract data access layer

**Interfaces**:
- `NoteRepository` - Abstract interface for all note operations
- `SearchService` - Abstract interface for search operations

**Implementations**:
- `SqliteNoteRepository` - SQLite database implementation
- `MockNoteRepository` - In-memory implementation for testing
- `AdvancedSearchService` - Fuzzy and semantic search implementation

### 2. State Management
**NoteProvider**:
- Manages UI state only (no business logic)
- Uses constructor dependency injection
- Implements debounced notifications to prevent rebuild storms
- Separates search, filter, and data management concerns

### 3. Dependency Injection
**NoteDependencyInjection**:
- Centralized dependency configuration
- Supports test mode with mock repositories
- Provides extension methods for easy service access

## Key Improvements from Previous Version

### 1. Eliminated Static Dependencies
**Before**: `DatabaseService.staticMethod()`
**After**: Constructor-injected `NoteRepository`

### 2. Separated Concerns
**Before**: `NoteProvider` handled state, business logic, and data access
**After**: 
- `NoteProvider` - State management only
- `NoteRepository` - Data access
- `SearchService` - Search algorithms

### 3. Improved Testability
**Before**: Hard to test due to static dependencies
**After**: Easy to mock dependencies via constructor injection

### 4. Performance Optimizations
- Single `notifyListeners()` call per operation
- Debounced notifications
- Local caching of computed properties

## Usage Examples

### 1. Accessing Services
```dart
// Using extension methods
final notes = context.noteProvider.notes;
final repository = context.noteRepository;

// Manual access
final provider = Provider.of<NoteProvider>(context);
```

### 2. Adding a Note
```dart
final newNote = Note(
  title: 'My Note',
  content: 'Content',
  createdAt: DateTime.now().millisecondsSinceEpoch,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
);

await context.noteProvider.addNote(newNote);
```

### 3. Searching Notes
```dart
await context.noteProvider.searchNotes('query');
// Results available in noteProvider.searchResults
```

### 4. Testing
```dart
// Setup
final mockRepo = MockNoteRepository();
final searchService = AdvancedSearchService();
final provider = NoteProvider(
  repository: mockRepo,
  searchService: searchService,
);

// Test
await provider.loadNotes();
expect(provider.notes, isEmpty);
```

## Migration Guide

### For Existing Code
1. Replace `DatabaseService.staticMethod()` calls with repository methods
2. Update `NoteProvider` usage to new API
3. Use dependency injection extension methods

### Breaking Changes
1. `NoteProvider` constructor now requires dependencies
2. Search methods return `Future<void>` instead of immediate results
3. State updates are debounced (use `await` for completion)

## Performance Considerations

### 1. Database Operations
- Use batch operations for bulk inserts/deletes
- Implement pagination for large datasets
- Consider SQLite FTS for full-text search

### 2. State Updates
- Use `Selector` for selective rebuilds
- Implement `Equatable` for value comparison
- Consider `ValueNotifier` for simple state

### 3. Memory Management
- Clear caches on logout
- Implement weak references for large objects
- Use `dispose` methods for cleanup

## Future Improvements

### 1. Caching Layer
- Add `NoteCache` for in-memory caching
- Implement cache invalidation strategies
- Add offline support with sync queue

### 2. Advanced Search
- Implement vector search with embeddings
- Add natural language processing
- Support for multiple search algorithms

### 3. Real-time Updates
- WebSocket integration for collaboration
- Conflict resolution for concurrent edits
- Version history and rollback