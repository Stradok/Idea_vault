import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/affiliate_match.dart';
import '../models/idea.dart';
import '../models/news_item.dart';
import '../models/research.dart';
import '../services/backend.dart';
import '../services/idea_category.dart';
import '../state/idea_vault.dart';

class IdeaDetailScreen extends StatelessWidget {
  final String ideaId;
  const IdeaDetailScreen({super.key, required this.ideaId});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<IdeaVault>();
    final idea = vault.byId(ideaId);
    if (idea == null) {
      return const Scaffold(body: Center(child: Text('Idea not found')));
    }
    final category = detectCategory(idea.title);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(idea.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Favorite',
              icon: Icon(
                idea.isFavorite ? Icons.star : Icons.star_border,
                color: idea.isFavorite ? Colors.amber.shade700 : null,
              ),
              onPressed: () => vault.toggleFavorite(idea.id),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete idea?'),
                      content: Text(
                          '"${idea.title}" will be removed with its media.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await vault.deleteIdea(idea.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Research'),
              Tab(text: 'News'),
              Tab(text: 'For you'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ResearchTab(idea: idea, category: category),
            _NewsTab(idea: idea, category: category),
            _AdsTab(idea: idea, category: category),
          ],
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ResearchTab extends StatefulWidget {
  final Idea idea;
  final IdeaCategory category;
  const _ResearchTab({required this.idea, required this.category});

  @override
  State<_ResearchTab> createState() => _ResearchTabState();
}

class _ResearchTabState extends State<_ResearchTab> {
  late Future<ResearchReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ResearchReport> _load() {
    final backend = context.read<Backend>();
    return backend.research.research(
      ideaId: widget.idea.id,
      title: widget.idea.title,
      notes: widget.idea.notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.read<IdeaVault>();
    return FutureBuilder<ResearchReport>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerSection(context, vault),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                            'Researching your idea with live sources...'),
                      ),
                    ],
                  ),
                ),
              )
            else if (snapshot.hasError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Research failed to load.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _future = _load()),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else
              _ResearchReportView(report: snapshot.data!),
          ],
        );
      },
    );
  }

  Widget _headerSection(BuildContext context, IdeaVault vault) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.idea.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.category.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat.yMMMd().add_jm().format(widget.idea.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (widget.idea.notes != null && widget.idea.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(widget.idea.notes!, style: const TextStyle(height: 1.4)),
            ],
            if (widget.idea.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // imageUrl is a local file path — media is cached from Drive
                // on load, not served from a network URL. See DriveMediaService.
                child: Image.file(
                  File(widget.idea.imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (widget.idea.audioUrl != null) ...[
              const SizedBox(height: 12),
              _AudioNoteCard(url: widget.idea.audioUrl!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        _pickReminder(context, widget.idea, vault),
                    icon: Icon(
                      widget.idea.reminderEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                    ),
                    label: Text(
                      widget.idea.reminderEnabled
                          ? 'Reminder set'
                          : 'Set reminder',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminder(
      BuildContext context, Idea idea, IdeaVault vault) async {
    if (idea.reminderEnabled) {
      final cleared = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clear reminder?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (cleared == true) await vault.clearReminder(idea.id);
      return;
    }

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final scheduled = await vault.setReminder(idea.id, when);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(scheduled
          ? 'Reminder set for ${DateFormat.yMMMd().add_jm().format(when)}'
          : 'Reminders are not available on this device'),
    ));
  }
}

class _ResearchReportView extends StatelessWidget {
  final ResearchReport report;
  const _ResearchReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = report.potentialScore >= 80
        ? Colors.green.shade700
        : report.potentialScore >= 65
            ? Colors.amber.shade800
            : Colors.orange.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'AI Summary',
          icon: Icons.auto_awesome,
          child: Text(report.summary, style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Problem',
          icon: Icons.report_problem_outlined,
          child: Text(report.problem, style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Possible Solution',
          icon: Icons.lightbulb_outline,
          child: Text(report.solution, style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Target Market',
          icon: Icons.people_outline,
          child: Text(report.targetMarket,
              style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Cost Estimate',
          icon: Icons.attach_money,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.costRange,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 6),
              Text(report.costBreakdown,
                  style: const TextStyle(height: 1.4, color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Potential Score',
          icon: Icons.speed,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (report.potentialScore / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    color: scoreColor,
                    backgroundColor: const Color(0xFFEDEFF3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${report.potentialScore}/100',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: scoreColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Known Competitors',
          icon: Icons.fact_check_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: report.competitors
                .map((c) => Chip(
                      label: Text(c),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Key Insights',
          icon: Icons.psychology_outlined,
          child: Column(
            children: report.keyInsights
                .map((k) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800)),
                          Expanded(
                              child: Text(k, style: const TextStyle(height: 1.4))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        if (report.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Sources',
            icon: Icons.link,
            child: Column(
              children: report.sources
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _openUrl(s),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(Icons.open_in_new,
                                  size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _NewsTab extends StatefulWidget {
  final Idea idea;
  final IdeaCategory category;
  const _NewsTab({required this.idea, required this.category});

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  late Future<List<NewsItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NewsItem>> _load() {
    final backend = context.read<Backend>();
    return backend.news.fetchFor(
      widget.category,
      title: widget.idea.title,
      notes: widget.idea.notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load news.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <NewsItem>[];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No strong news matches found for this idea right now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openUrl(item.url),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.source.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _timeAgo(item.publishedAt),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (item.snippet.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(item.snippet,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                height: 1.4, color: Colors.black54)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Read article',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Icon(Icons.open_in_new,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _AdsTab extends StatefulWidget {
  final Idea idea;
  final IdeaCategory category;
  const _AdsTab({required this.idea, required this.category});

  @override
  State<_AdsTab> createState() => _AdsTabState();
}

class _AdsTabState extends State<_AdsTab> {
  late Future<List<AffiliateMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<Backend>().affiliates.matchesFor(
          ideaId: widget.idea.id,
          title: widget.idea.title,
          notes: widget.idea.notes,
          category: widget.category,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AffiliateMatch>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = snapshot.data ?? const <AffiliateMatch>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tools matched to your idea about '
              '${widget.category.label.toLowerCase()}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (matches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No matches found for this idea yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            for (final match in matches) ...[
              _ToolBanner(match: match),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'These are AI-matched suggestions based on the topic of your '
                  'idea, not paid placements.',
                  style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ToolBanner extends StatelessWidget {
  final AffiliateMatch match;
  const _ToolBanner({required this.match});

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[match.name.hashCode.abs() % Colors.primaries.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openUrl(match.url),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.build_outlined, color: Colors.white, size: 30),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${match.name}  ·  ${match.category}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(match.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Visit site',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioNoteCard extends StatefulWidget {
  final String url;
  const _AudioNoteCard({required this.url});

  @override
  State<_AudioNoteCard> createState() => _AudioNoteCardState();
}

class _AudioNoteCardState extends State<_AudioNoteCard> {
  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: Colors.black54),
          const SizedBox(width: 10),
          const Expanded(child: Text('Voice note', style: TextStyle(fontSize: 13))),
          StreamBuilder<PlayerState>(
            stream: _player.onPlayerStateChanged,
            builder: (context, snapshot) {
              final playing = snapshot.data == PlayerState.playing;
              return IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: () async {
                  if (playing) {
                    await _player.pause();
                  } else {
                    await _player.stop();
                    // widget.url is a local cached file path (see
                    // DriveMediaService), not a network URL.
                    await _player.play(DeviceFileSource(widget.url));
                  }
                },
                icon: Icon(playing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
              );
            },
          ),
        ],
      ),
    );
  }
}
