import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/idea.dart';
import '../services/auth_service.dart';
import '../state/idea_vault.dart';
import 'add_idea_screen.dart';
import 'idea_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _queueIntroSeenKey = 'queue_intro_seen_v1';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowQueueIntro());
  }

  Future<void> _maybeShowQueueIntro() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_queueIntroSeenKey) == true) return;
    await prefs.setBool(_queueIntroSeenKey, true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aoa! Amman here 👋'),
        content: const SingleChildScrollView(
          child: Text(
            'Quick heads up before you dive in: this app is running on my '
            'personal savings and pure vibes, not some VC-funded server '
            "farm — so there's no big API budget behind it (yet 😅).\n\n"
            "Because of that, Research & News aren't instant. Add your "
            'idea, and it joins a queue — I process everyone\'s ideas one '
            'by one, first come first served. Less "Silicon Valley," more '
            '"bakery counter, please take a number." 🎟️\n\n'
            "You'll get your results as soon as your turn comes up. If "
            "you're testing at 3am and you're the only one awake, "
            'congrats, you\'re VIP tonight.\n\n'
            'Thanks for being my guinea pigs testers — appreciate you 🐹❤️\n\n'
            '— Amman',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Got it, let's go"),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final vault = context.read<IdeaVault>();
    await context.read<AuthService>().signOut();
    vault.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<IdeaVault>();
    final all = vault.ideas;
    final ideas = _query.isEmpty
        ? all
        : all
            .where((i) => i.title.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'IdeaVault',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: 'Favorites',
              icon: const Icon(Icons.star_outline),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search ideas...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ideas.isEmpty
                ? _EmptyState(hasIdeas: all.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: ideas.length,
                    itemBuilder: (context, index) {
                      final idea = ideas[index];
                      return _IdeaCard(idea: idea);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddIdeaScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Capture idea'),
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<IdeaVault>().favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                'Star an idea to keep it here.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return _IdeaCard(idea: favorites[index]);
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasIdeas;
  const _EmptyState({required this.hasIdeas});

  @override
  Widget build(BuildContext context) {
    if (hasIdeas) {
      return const Center(
        child: Text('No ideas match your search.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💡', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Your idea vault is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'A thought struck you? Capture it in seconds - type it,\n'
              'snap a photo, or record a quick voice note.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddIdeaScreen()),
              ),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Capture your first idea'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final Idea idea;
  const _IdeaCard({required this.idea});

  @override
  Widget build(BuildContext context) {
    final vault = context.read<IdeaVault>();
    final reminder = idea.reminderEnabled && idea.reminderAt != null
        ? 'Reminder ${DateFormat.MMMd().add_jm().format(idea.reminderAt!)}'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IdeaDetailScreen(ideaId: idea.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (idea.imageUrl != null)
              Image.network(
                idea.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idea.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMMMd().format(idea.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        if (reminder != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            reminder,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      if (idea.audioPath != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Icon(Icons.mic, size: 18, color: Colors.grey),
                        ),
                      IconButton(
                        tooltip: idea.isFavorite ? 'Unfavorite' : 'Favorite',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          idea.isFavorite
                              ? Icons.star
                              : Icons.star_border,
                          color: idea.isFavorite
                              ? Colors.amber.shade700
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () =>
                            vault.toggleFavorite(idea.id).catchError((e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Could not update favorite: $e')),
                            );
                          }
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
