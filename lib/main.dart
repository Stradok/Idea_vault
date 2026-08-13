import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/backend.dart';
import 'services/reminder_service.dart';
import 'state/idea_vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Missing/unreadable .env — fall through to the setup screen below.
  }

  if (!AppConfig.isConfigured) {
    runApp(const IdeaVaultApp(configured: false));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  runApp(const IdeaVaultApp(configured: true));
}

class IdeaVaultApp extends StatelessWidget {
  final bool configured;
  const IdeaVaultApp({super.key, required this.configured});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'IdeaVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF8F9FC),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFE5E7EB)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      // Wraps the whole Navigator (every route, including ones pushed later
      // via Navigator.push — not just the initial `home` route) so
      // context.read<...>() works from any screen. Providers being built
      // *inside* `home` instead of here was the bug: pushed routes are
      // sibling overlay entries, not descendants of `home`'s subtree.
      builder: (context, child) {
        if (!configured) return child!;
        return AppProviders(child: child!);
      },
      home: configured ? const AuthGate() : const SetupScreen(),
    );
  }
}

/// Owns the app's singleton services and provides them above the Navigator
/// (see the `builder` comment in [IdeaVaultApp]) so every screen — including
/// ones reached via Navigator.push — can see them.
class AppProviders extends StatefulWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

  @override
  State<AppProviders> createState() => _AppProvidersState();
}

class _AppProvidersState extends State<AppProviders> {
  late final AuthService _authService;
  late final ReminderService _reminders;
  late final Backend _backend;
  late final IdeaVault _vault;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _authService = AuthService();
    _reminders = ReminderService();
    _backend = Backend(client, _authService.drive);
    _vault = IdeaVault(
      store: _backend.ideas,
      media: _backend.media,
      reminders: _reminders,
      queue: _backend.queue,
    );
    _reminders.init();
  }

  @override
  void dispose() {
    _vault.dispose();
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _authService),
        Provider.value(value: _backend),
        Provider.value(value: _reminders),
        ChangeNotifierProvider.value(value: _vault),
      ],
      child: widget.child,
    );
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💡', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'IdeaVault needs setup',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Create a .env file in the project folder with your '
                  'Supabase URL and anon key. See .env.example.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => SystemNavigator.pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _authStream = client.auth.onAuthStateChange;
    _handleInitialSession(client);
  }

  Future<void> _handleInitialSession(SupabaseClient client) async {
    final session = client.auth.currentSession;
    if (session != null) {
      try {
        // Restores the Drive-scoped Google session (Supabase's own session
        // is already restored independently by supabase_flutter) so
        // DriveClient has a signed-in GoogleSignIn.currentUser before we
        // load ideas.
        await context.read<AuthService>().warmUpGoogleSession();
        await _activateUser(session.user.id);
      } catch (_) {
        // Fall through to showing the (possibly empty) home screen rather
        // than getting stuck on the loading spinner forever.
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _activateUser(String userId) async {
    final vault = context.read<IdeaVault>();
    vault.setUserId(userId);
    try {
      await vault.load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not load your ideas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (!_ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (session == null) {
          return const AuthScreen();
        }
        final vault = context.read<IdeaVault>();
        if (vault.userId != session.user.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && vault.userId != session.user.id) {
              await _activateUser(session.user.id);
            }
          });
        }
        return const HomeScreen();
      },
    );
  }
}
