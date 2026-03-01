import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/app_surface.dart';
import '../../events/data/event_model.dart';
import '../../events/data/event_repository.dart';
import '../../events/widgets/event_page_scaffold.dart';
import '../data/speaker_model.dart';
import '../data/speaker_repository.dart';

/// Speaker details page at /speaker/:speakerId.
/// Optional [eventSlug] loads event for branding (background + theme).
class SpeakerDetailsPage extends StatefulWidget {
  const SpeakerDetailsPage({
    super.key,
    required this.speakerId,
    this.eventSlug,
    this.speakerRepository,
    this.eventRepository,
  });

  final String speakerId;
  final String? eventSlug;
  final SpeakerRepository? speakerRepository;
  final EventRepository? eventRepository;

  @override
  State<SpeakerDetailsPage> createState() => _SpeakerDetailsPageState();
}

class _SpeakerDetailsPageState extends State<SpeakerDetailsPage> {
  late SpeakerRepository _speakerRepo;
  late EventRepository _eventRepo;

  Speaker? _speaker;
  EventModel? _event;
  bool _loading = true;
  String? _error;
  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    _speakerRepo = widget.speakerRepository ?? SpeakerRepository();
    _eventRepo = widget.eventRepository ?? EventRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load event first when we have eventSlug, so we can fetch speaker from event subcollection.
      EventModel? event;
      if (widget.eventSlug != null && widget.eventSlug!.isNotEmpty) {
        event = await _eventRepo.getEventBySlug(widget.eventSlug!);
      }
      final speaker = await _speakerRepo.getSpeakerById(
        widget.speakerId,
        eventId: event?.id,
        eventSlug: widget.eventSlug,
      );
      if (mounted) {
        setState(() {
          _speaker = speaker;
          _event = event;
          _loading = false;
          _contentVisible = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildScaffold(
        context,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null || _speaker == null) {
      return _buildScaffold(
        context,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: _theme(context).accent),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Speaker not found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Back',
                    style: TextStyle(color: _theme(context).primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildScaffold(context, body: _buildContent(context, _speaker!));
  }

  _SpeakerTheme _theme(BuildContext context) {
    if (_event != null) {
      return _SpeakerTheme(
        primary: _event!.primaryColor,
        accent: _event!.accentColor,
        cardBackgroundColor: _event!.cardBackgroundColor,
      );
    }
    return _SpeakerTheme(
      primary: const Color(0xFF0E3A5D),
      accent: const Color(0xFFF4A340),
      cardBackgroundColor: const Color(0xFF141420),
    );
  }

  Widget _buildScaffold(BuildContext context, {required Widget body}) {
    final theme = _theme(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.92)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(context),
          Positioned.fill(
            child: Container(
              color: theme.cardBackgroundColor.withValues(alpha: 0.75),
            ),
          ),
          SafeArea(
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    if (_event == null) {
      return Container(
        color: _theme(context).primary,
      );
    }
    final bgUrl = _event!.backgroundImageUrl;
    final slug = _event!.slug;
    String? asset;
    if (bgUrl != null && bgUrl.isNotEmpty) {
      if (bgUrl.contains('nlc') || bgUrl.contains('background2')) {
        asset = EventPageScaffold.nlcBackgroundAsset;
      } else if (bgUrl.contains('march_assembly')) {
        asset = EventPageScaffold.marchAssemblyBackgroundAsset;
      }
    }
    if (asset == null) {
      if (slug == 'nlc' || slug == 'nlc-2026') asset = EventPageScaffold.nlcBackgroundAsset;
      if (slug == 'march-cluster-2026') asset = EventPageScaffold.marchAssemblyBackgroundAsset;
    }
    if (asset != null) {
      return Positioned.fill(
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.22),
            BlendMode.darken,
          ),
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      color: _event!.primaryColor,
    );
  }

  Widget _buildContent(BuildContext context, Speaker speaker) {
    final theme = _theme(context);
    return AnimatedOpacity(
      opacity: _contentVisible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, speaker, theme),
                    const SizedBox(height: 24),
                    _buildContactRow(context, speaker, theme),
                    const SizedBox(height: 32),
                    _buildContentSection(context, speaker, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection(BuildContext context, Speaker speaker, _SpeakerTheme theme) {
    final width = MediaQuery.sizeOf(context).width;
    final contentPaddingH = width < 600 ? 20.0 : 28.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaker.bio != null && speaker.bio!.isNotEmpty) ...[
          _buildAboutCard(speaker, theme, horizontalPadding: contentPaddingH),
        ],
        AppSurface(
          margin: const EdgeInsets.only(top: 32),
          padding: EdgeInsets.symmetric(
            horizontal: contentPaddingH,
            vertical: 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsList(speaker, theme),
              if (speaker.topics.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildTopicsSection(speaker, theme),
              ],
              if (speaker.quote != null && speaker.quote!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildQuoteCard(speaker, theme, horizontalPadding: contentPaddingH),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Speaker speaker, _SpeakerTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12),
                blurRadius: 20,
              ),
            ],
          ),
          child: _buildPhoto(speaker, theme),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                speaker.effectiveDisplayName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (speaker.title != null && speaker.title!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  speaker.title!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                  ),
                ),
              ],
              if (speaker.cluster != null && speaker.cluster!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    speaker.cluster!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto(Speaker speaker, _SpeakerTheme theme) {
    const size = 96.0;
    final url = speaker.photoUrl;
    if (url == null || url.isEmpty) {
      return _InitialsCircle(name: speaker.effectiveDisplayName, size: size);
    }
    if (url.startsWith('assets/')) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _InitialsCircle(name: speaker.effectiveDisplayName, size: size),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => _InitialsCircle(name: speaker.effectiveDisplayName, size: size),
          errorWidget: (context, error, stackTrace) =>
              _InitialsCircle(name: speaker.effectiveDisplayName, size: size),
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, Speaker speaker, _SpeakerTheme theme) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 800;
    final buttonHeight = isWide ? 44.0 : 40.0;
    final buttons = <Widget>[];
    if (speaker.email != null && speaker.email!.trim().isNotEmpty) {
      buttons.add(
        _ContactButton(
          label: 'Email',
          icon: Icons.email_outlined,
          theme: theme,
          height: buttonHeight,
          onTap: () => _launchUrl('mailto:${speaker.email}'),
        ),
      );
    }
    if (speaker.phone != null && speaker.phone!.trim().isNotEmpty) {
      buttons.add(
        _ContactButton(
          label: 'Call',
          icon: Icons.phone_outlined,
          theme: theme,
          height: buttonHeight,
          onTap: () => _launchUrl('tel:${speaker.phone}'),
        ),
      );
    }
    if (speaker.facebookUrl != null && speaker.facebookUrl!.trim().isNotEmpty) {
      buttons.add(
        _ContactButton(
          label: 'Facebook',
          icon: Icons.facebook_rounded,
          theme: theme,
          height: buttonHeight,
          onTap: () => _launchUrl(speaker.facebookUrl!),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    if (isWide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SizedBox(
                width: double.infinity,
                child: buttons[i],
              ),
            ),
            if (i < buttons.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }
    return Row(
      children: buttons.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < buttons.length - 1 ? 12 : 0),
            child: e.value,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAboutCard(Speaker speaker, _SpeakerTheme theme, {required double horizontalPadding}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT THE SPEAKER',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: theme.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            speaker.bio!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsList(Speaker speaker, _SpeakerTheme theme) {
    final rows = <Widget>[];
    if (speaker.yearsInCfc != null) {
      rows.add(_StatRow(theme: theme, label: 'Years in CFC', value: '${speaker.yearsInCfc}', icon: Icons.calendar_today_rounded));
    }
    if (speaker.familiesMentored != null) {
      if (rows.isNotEmpty) rows.add(Divider(height: 24, color: Colors.white.withValues(alpha: 0.12)));
      rows.add(_StatRow(theme: theme, label: 'Families Mentored', value: '${speaker.familiesMentored}', icon: Icons.groups_rounded));
    }
    if (speaker.talksGiven != null) {
      if (rows.isNotEmpty) rows.add(Divider(height: 24, color: Colors.white.withValues(alpha: 0.12)));
      rows.add(_StatRow(theme: theme, label: 'Talks Given', value: '${speaker.talksGiven}', icon: Icons.mic_rounded));
    }
    if (speaker.location != null && speaker.location!.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(Divider(height: 24, color: Colors.white.withValues(alpha: 0.12)));
      rows.add(_StatRow(theme: theme, label: 'Location', value: speaker.location!, icon: Icons.location_on_rounded));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _buildTopicsSection(Speaker speaker, _SpeakerTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Topics',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: theme.accent,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: speaker.topics
              .map((t) => _TopicChip(label: t))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuoteCard(Speaker speaker, _SpeakerTheme theme, {required double horizontalPadding}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${speaker.quote}"',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${speaker.effectiveDisplayName}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatefulWidget {
  const _TopicChip({required this.label});
  final String label;

  @override
  State<_TopicChip> createState() => _TopicChipState();
}

class _TopicChipState extends State<_TopicChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hovered ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hovered ? 0.35 : 0.22),
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SpeakerTheme {
  const _SpeakerTheme({
    required this.primary,
    required this.accent,
    required this.cardBackgroundColor,
  });
  final Color primary;
  final Color accent;
  final Color cardBackgroundColor;
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.name, this.size = 96});
  final String name;
  final double size;

  static const _palette = [
    Color(0xFF6D4CFF),
    Color(0xFF3E7D4C),
    Color(0xFFE0B646),
    Color(0xFF4C7FE0),
    Color(0xFFE0614C),
    Color(0xFF4CE0C6),
    Color(0xFFB44CE0),
    Color(0xFFE04CAA),
  ];

  Color _colorFor(String s) {
    var hash = 0;
    for (final c in s.codeUnits) hash = (hash * 31 + c) & 0xFFFFFFFF;
    return _palette[hash % _palette.length];
  }

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFor(name).withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ContactButton extends StatefulWidget {
  const _ContactButton({
    required this.label,
    required this.icon,
    required this.theme,
    required this.onTap,
    this.height = 40,
  });
  final String label;
  final IconData icon;
  final _SpeakerTheme theme;
  final VoidCallback onTap;
  final double height;

  @override
  State<_ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<_ContactButton> {
  bool _hovered = false;
  bool _pressed = false;

  double get _backgroundOpacity {
    if (_pressed) return 0.20;
    if (_hovered) return 0.16;
    return 0.12;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _backgroundOpacity),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: Colors.white.withValues(alpha: 0.95)),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.icon,
  });
  final _SpeakerTheme theme;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.92)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
