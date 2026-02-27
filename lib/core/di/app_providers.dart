import 'package:flutter/material.dart';
import '../core/di/dependency_injection.dart';

/// Main application wrapper with dependency injection
/// This should be used as the root of the application
class AppWithProviders extends StatelessWidget {
  final Widget child;
  final Environment environment;

  const AppWithProviders({
    Key? key,
    required this.child,
    this.environment = Environment.development,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Configure environment
    ProviderConfig.setEnvironment(environment);
    ProviderConfig.configureForEnvironment();

    // Setup providers
    return DependencyInjection.setupProviders(
      child: AppInitializer(child: child),
      isTestMode: environment == Environment.test,
    );
  }
}

/// Widget to initialize services after providers are set up
class AppInitializer extends StatefulWidget {
  final Widget child;

  const AppInitializer({Key? key, required this.child}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await DependencyInjection.initializeServices(context);
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Initialization Error', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeApp,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Usage example:
/// 
/// ```dart
/// void main() {
///   runApp(
///     AppWithProviders(
///       environment: kDebugMode ? Environment.development : Environment.production,
///       child: MyApp(),
///     ),
///   );
/// }
/// 
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: HomeScreen(),
///     );
///   }
/// }
/// 
/// class HomeScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     // Services are now available through context
///     final noteService = context.noteService;
///     final noteStateProvider = context.noteStateProvider;
///     
///     return Scaffold(
///       body: Center(
///         child: ElevatedButton(
///           onPressed: () => noteActionProvider.loadNotes(),
///           child: Text('Load Notes'),
///         ),
///       ),
///     );
///   }
/// }
/// ```
