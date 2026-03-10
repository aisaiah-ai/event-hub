import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';

/// Live Photo Wall — fullscreen display for event screens / projectors.
///
/// Route: /events/:eventSlug/photo-wall
///
/// Features:
///  - Realtime Firestore listener for approved images
///  - Animated mosaic grid with staggered fade-ins
///  - Spotlight mode: periodically highlights a single photo fullscreen
///  - Auto-advances continuously — no interaction needed
///  - Event branding overlay (logo, name, hashtag)
///  - Keyboard: F = fullscreen toggle, S = toggle spotlight, Space = pause
class PhotoWallPage extends StatefulWidget {
  const PhotoWallPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<PhotoWallPage> createState() => _PhotoWallPageState();
}

class _PhotoWallPageState extends State<PhotoWallPage>
    with TickerProviderStateMixin {
  final _repo = EventRepository();
  EventModel? _event;
  List<_Photo> _photos = [];
  StreamSubscription? _sub;
  bool _loading = true;

  // Spotlight
  bool _spotlightEnabled = true;
  int _spotlightIndex = -1;
  Timer? _spotlightTimer;
  Timer? _gridShuffleTimer;
  bool _paused = false;

  // Grid animation
  late AnimationController _fadeController;
  final _random = Random();

  // Display order (shuffled for visual variety)
  List<int> _displayOrder = [];

  // Per-source photo lists for merging
  final Map<String, List<_Photo>> _photosBySource = {};

  static const _spotlightDuration = Duration(seconds: 6);
  static const _gridDuration = Duration(seconds: 4);
  static const _spotlightInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spotlightTimer?.cancel();
    _gridShuffleTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final event = await _repo.getEventBySlug(widget.eventSlug);
    if (event == null || !mounted) return;
    setState(() => _event = event);

    // Realtime listener for approved images from both databases.
    final fs = FirebaseFirestore.instance;

    // Always use march-assembly — that's the canonical Firestore doc ID.
    const docId = 'march-assembly';

    // Realtime listener — no where clause to avoid index requirements.
    // Filter approved client-side.
    _sub = fs
        .collection('events')
        .doc(docId)
        .collection('images')
        .snapshots()
        .listen(
          (snap) {
            final approved = snap.docs
                .where((d) => d.data()['status'] == 'approved')
                .toList();
            print(
              '[PhotoWall] images total=${snap.docs.length} approved=${approved.length}',
            );
            _mergePhotos(approved, 'default');
          },
          onError: (e) {
            print('[PhotoWall] Error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  void _mergePhotos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String source,
  ) {
    final list = docs.map((doc) {
      final d = doc.data();
      return _Photo(
        id: doc.id,
        url: d['url'] as String? ?? '',
        thumbnailUrl: d['thumbnailUrl'] as String?,
        uploaderName: d['uploaderName'] as String?,
      );
    }).toList();

    _photosBySource[source] = list;

    // Merge all sources, deduplicate by ID
    final seen = <String>{};
    final merged = <_Photo>[];
    for (final photos in _photosBySource.values) {
      for (final p in photos) {
        if (seen.add(p.id)) merged.add(p);
      }
    }

    if (!mounted) return;
    setState(() {
      _photos = merged;
      _loading = false;
      _refreshDisplayOrder();
    });

    if (merged.isNotEmpty && _spotlightTimer == null) {
      _startTimers();
    }
  }

  void _refreshDisplayOrder() {
    _displayOrder = List.generate(_photos.length, (i) => i)..shuffle(_random);
  }

  void _startTimers() {
    // Spotlight timer: periodically show one photo fullscreen
    _spotlightTimer?.cancel();
    _spotlightTimer = Timer.periodic(_spotlightInterval, (_) {
      if (_paused || !_spotlightEnabled || _photos.isEmpty) return;
      _showSpotlight();
    });

    // Grid shuffle timer: periodically re-order grid for dynamism
    _gridShuffleTimer?.cancel();
    _gridShuffleTimer = Timer.periodic(_gridDuration, (_) {
      if (_paused || _spotlightIndex >= 0) return;
      if (mounted && _photos.length > 1) {
        setState(() => _refreshDisplayOrder());
      }
    });
  }

  void _showSpotlight() {
    if (_photos.isEmpty) return;
    final idx = _random.nextInt(_photos.length);
    setState(() => _spotlightIndex = idx);
    _fadeController.forward(from: 0);

    Future.delayed(_spotlightDuration, () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (mounted) setState(() => _spotlightIndex = -1);
      });
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyF:
        // Toggle fullscreen (browser)
        break;
      case LogicalKeyboardKey.keyS:
        setState(() => _spotlightEnabled = !_spotlightEnabled);
        break;
      case LogicalKeyboardKey.space:
        setState(() => _paused = !_paused);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF060610),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF101020), Color(0xFF060610)],
                ),
              ),
            ),

            // Main content
            if (_loading)
              _buildLoading()
            else if (_photos.isEmpty)
              _buildEmpty()
            else
              _buildPhotoGrid(),

            // Spotlight overlay
            if (_spotlightIndex >= 0 && _spotlightIndex < _photos.length)
              _buildSpotlight(_photos[_spotlightIndex]),

            // Bottom branding bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBrandingBar(),
            ),

            // Pause indicator
            if (_paused)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause, color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'PAUSED',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _gold, strokeWidth: 2),
          const SizedBox(height: 20),
          Text(
            'Loading photos...',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_rounded,
            color: _gold.withValues(alpha: 0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for photos...',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approved photos will appear here in real time',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cols = w > 1600
            ? 5
            : w > 1200
            ? 4
            : w > 800
            ? 3
            : 2;
        final cellW = w / cols;
        // Staggered heights for visual interest
        final bottomPad = 72.0; // branding bar
        final availH = h - bottomPad;
        final rows = (availH / cellW).ceil();
        final totalCells = cols * rows;

        return Padding(
          padding: const EdgeInsets.only(bottom: 72),
          child: Wrap(
            children: List.generate(min(totalCells, _photos.length), (gridIdx) {
              final photoIdx = _displayOrder.isNotEmpty
                  ? _displayOrder[gridIdx % _displayOrder.length]
                  : gridIdx % _photos.length;
              final photo = _photos[photoIdx];
              // Stagger: some cells are taller
              final tall = gridIdx % 7 == 0 && cols > 2;
              final cellH = tall ? cellW * 1.4 : cellW;

              return _AnimatedPhotoCell(
                key: ValueKey('${photo.id}-$gridIdx'),
                photo: photo,
                width: cellW,
                height: cellH,
                delay: Duration(milliseconds: (gridIdx * 80).clamp(0, 2000)),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSpotlight(_Photo photo) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
      child: Container(
        color: const Color(0xE6060610),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 40, 60, 100),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photo.url,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 300),
                  ),
                ),
              ),
            ),
            // Uploader name
            if (photo.uploaderName != null)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, color: _gold, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          photo.uploaderName!,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingBar() {
    final event = _event;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF060610).withValues(alpha: 0.95),
            const Color(0xFF060610),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Event logo
          if (event?.effectiveLogoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Image.asset(
                'assets/images/march_assembly_logo.png',
                height: 40,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          // Event name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (event?.organizationName != null)
                  Text(
                    event!.organizationName!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                Text(
                  event?.name ?? 'Event Photo Wall',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Photo count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library, color: _gold, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_photos.length}',
                  style: GoogleFonts.inter(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Hashtag
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_gold, Color(0xFFE87D2E)],
            ).createShader(bounds),
            child: Text(
              '#MarchAssembly',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Live indicator
          _LivePulse(),
        ],
      ),
    );
  }

  static const Color _gold = Color(0xFFF4A340);
}

// ══════════════════════════════════════════════════════════════════════
// Data
// ══════════════════════════════════════════════════════════════════════

class _Photo {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String? uploaderName;

  const _Photo({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.uploaderName,
  });
}

// ══════════════════════════════════════════════════════════════════════
// Transition effects
// ══════════════════════════════════════════════════════════════════════

enum _TransitionType { fadeScale, zoomIn, twirl, slideUp, flipIn, elastic }

// ══════════════════════════════════════════════════════════════════════
// Animated photo cell with random transitions
// ══════════════════════════════════════════════════════════════════════

class _AnimatedPhotoCell extends StatefulWidget {
  const _AnimatedPhotoCell({
    super.key,
    required this.photo,
    required this.width,
    required this.height,
    required this.delay,
  });

  final _Photo photo;
  final double width;
  final double height;
  final Duration delay;

  @override
  State<_AnimatedPhotoCell> createState() => _AnimatedPhotoCellState();
}

class _AnimatedPhotoCellState extends State<_AnimatedPhotoCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late _TransitionType _effect;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _effect =
        _TransitionType.values[_rng.nextInt(_TransitionType.values.length)];
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: _effect == _TransitionType.elastic ? 900 : 700,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        switch (_effect) {
          case _TransitionType.fadeScale:
            return Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.85 + 0.15 * Curves.easeOutCubic.transform(t),
                child: child,
              ),
            );

          case _TransitionType.zoomIn:
            final zoom = Curves.easeOutBack.transform(t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.3 + 0.7 * zoom, child: child),
            );

          case _TransitionType.twirl:
            final curve = Curves.easeOutCubic.transform(t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1.0 - curve) * pi * 0.5)
                  ..scale(0.8 + 0.2 * curve),
                child: child,
              ),
            );

          case _TransitionType.slideUp:
            final slide = Curves.easeOutQuart.transform(t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 40 * (1.0 - slide)),
                child: child,
              ),
            );

          case _TransitionType.flipIn:
            final curve = Curves.easeOutCubic.transform(t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX((1.0 - curve) * pi * 0.4),
                child: child,
              ),
            );

          case _TransitionType.elastic:
            final bounce = Curves.elasticOut.transform(t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: bounce, child: child),
            );
        }
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _HoverGlow(
              child: CachedNetworkImage(
                imageUrl: widget.photo.thumbnailUrl ?? widget.photo.url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1A1A2A),
                  child: const Center(
                    child: Icon(
                      Icons.photo,
                      color: Color(0xFF2A2A3A),
                      size: 24,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A2A),
                  child: const Icon(
                    Icons.broken_image,
                    color: Color(0xFF2A2A3A),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle glow/shimmer on each photo cell for added polish.
class _HoverGlow extends StatefulWidget {
  const _HoverGlow({required this.child});
  final Widget child;

  @override
  State<_HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<_HoverGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    // Each cell pulses at a slightly different rate for organic feel.
    final duration = Duration(milliseconds: 3000 + _rng.nextInt(2000));
    _ctrl = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);
    // Start at a random phase so they don't all pulse in sync.
    _ctrl.value = _rng.nextDouble();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.03 * _ctrl.value),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.05 * (1.0 - _ctrl.value)),
              ],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Live pulse indicator
// ══════════════════════════════════════════════════════════════════════

class _LivePulse extends StatefulWidget {
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFFE04C4C),
                  const Color(0xFFFF6B6B),
                  _ctrl.value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFE04C4C,
                    ).withValues(alpha: 0.4 * _ctrl.value),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: GoogleFonts.inter(
                color: const Color(0xFFE04C4C),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }
}
