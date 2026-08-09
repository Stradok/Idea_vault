import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../state/idea_vault.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  Future<void> _openLegalDoc(String title, String asset) async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocScreen(title: title, asset: asset)),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and every idea, photo, voice '
          'note, and research report in it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    final auth = context.read<AuthService>();
    try {
      // Order matters: clean up Drive and revoke Google access *first*,
      // while we still hold valid credentials to do so — deleting the
      // Supabase auth user first would leave the app without a session to
      // authenticate the Drive cleanup calls with.
      await auth.drive.deleteAppFolder();

      final res =
          await Supabase.instance.client.functions.invoke('delete-account');
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['error'] != null) {
        throw Exception(data['error']);
      }

      if (!mounted) return;
      context.read<IdeaVault>().clear();
      await auth.disconnect();
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegalDoc('Privacy Policy', 'PRIVACY.md'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegalDoc('Terms of Service', 'TERMS.md'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: _deleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.delete_forever, color: Colors.red.shade700),
            title: Text(
              'Delete account',
              style: TextStyle(color: Colors.red.shade700),
            ),
            subtitle: const Text('Permanently erase your account and all data'),
            onTap: _deleting ? null : _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }
}

class LegalDocScreen extends StatelessWidget {
  final String title;
  final String asset;
  const LegalDocScreen({super.key, required this.title, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lines = snapshot.data!.split('\n');
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final line in lines) _LineWidget(line: line),
            ],
          );
        },
      ),
    );
  }
}

class _LineWidget extends StatelessWidget {
  final String line;
  const _LineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return const SizedBox(height: 12);
    if (trimmed.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(trimmed.substring(2),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      );
    }
    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(trimmed.substring(3),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );
    }
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return Text(trimmed.substring(2, trimmed.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w600));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(trimmed, style: const TextStyle(height: 1.4)),
    );
  }
}
