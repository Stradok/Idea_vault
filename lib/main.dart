import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
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
      home: configured ? const AuthGate() : const SetupScreen(),
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
  late final Backend _backend;
  late final ReminderService _reminders;
  late final IdeaVault _vault;
  late final Stream<AuthState> _authStream;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _reminders = ReminderService();
    _backend = Backend(client);
    _vault = IdeaVault(
      store: _backend.ideas,
      media: _backend.media,
      reminders: _reminders,
    );
    _reminders.init();
    _authStream = client.auth.onAuthStateChange;
    _handleInitialSession(client);
  }

  Future<void> _handleInitialSession(SupabaseClient client) async {
    final session = client.auth.currentSession;
    if (session != null) {
      await _activateUser(session.user.id);
    }
    setState(() => _ready = true);
  }

  Future<void> _activateUser(String userId) async {
    _vault.setUserId(userId);
    await _vault.load();
  }

  @override
  void dispose() {
    _vault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _backend),
        Provider.value(value: _reminders),
        ChangeNotifierProvider.value(value: _vault),
      ],
      child: StreamBuilder<AuthState>(
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
      ),
    );
  }
}
