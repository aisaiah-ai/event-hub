import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';

/// Live Photo Wall — **light-themed** version for projector display.
///
/// Route: /events/:eventSlug/photo-wall-light
class PhotoWallLightPage extends StatefulWidget {
  const PhotoWallLightPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<PhotoWallLightPage> createState() => _PhotoWallLightPageState();
}

class _PhotoWallLightPageState extends State<PhotoWallLightPage>
    with TickerProviderStateMixin {
  final _repo = EventRepository();
  EventModel? _event;
  List<_Photo> _photos = [];
  StreamSubscription? _sub;
  bool _loading = true;

  bool _spotlightEnabled = true;
  int _spotlightIndex = -1;
  Timer? _spotlightTimer;
  Timer? _gridShuffleTimer;
  bool _paused = false;

  late AnimationController _fadeController;
  final _random = Random();
  List<int> _displayOrder = [];
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

    final fs = FirebaseFirestore.instance;
    const docId = 'march-assembly';

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
            _mergePhotos(approved, 'default');
          },
          onError: (e) {
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
    _spotlightTimer?.cancel();
    _spotlightTimer = Timer.periodic(_spotlightInterval, (_) {
      if (_paused || !_spotlightEnabled || _photos.isEmpty) return;
      _showSpotlight();
    });

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
        backgroundColor: _bgColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              _buildLoading()
            else if (_photos.isEmpty)
              _buildEmpty()
            else
              _buildPhotoGrid(),

            if (_spotlightIndex >= 0 && _spotlightIndex < _photos.length)
              _buildSpotlight(_photos[_spotlightIndex]),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBrandingBar(),
            ),

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
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pause,
                        color: Color(0xFF666666),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PAUSED',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF666666),
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
          const CircularProgressIndicator(color: _accent, strokeWidth: 2),
          const SizedBox(height: 20),
          Text(
            'Loading photos...',
            style: GoogleFonts.inter(
              color: const Color(0xFF999999),
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
            color: _accent.withValues(alpha: 0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for photos...',
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approved photos will appear here in real time',
            style: GoogleFonts.inter(
              color: const Color(0xFF999999),
              fontSize: 14,
            ),
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
        const bottomPad = 72.0;
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
        color: const Color(0xE6F5F5F0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 40, 60, 100),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CachedNetworkImage(
                      imageUrl: photo.url,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                ),
              ),
            ),
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
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, color: _accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          photo.uploaderName!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1A1A1A),
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
            _bgColor.withValues(alpha: 0.95),
            _bgColor,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          if (event?.effectiveLogoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Image.asset(
                'assets/images/march_assembly_logo.png',
                height: 40,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (event?.organizationName != null)
                  Text(
                    event!.organizationName!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                Text(
                  event?.name ?? 'Event Photo Wall',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library, color: _accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_photos.length}',
                  style: GoogleFonts.inter(
                    color: _accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '#MarchAssembly',
            style: GoogleFonts.inter(
              color: _accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          _LivePulse(),
        ],
      ),
    );
  }

  static const Color _bgColor = Color(0xFFF5F5F0);
  static const Color _accent = Color(0xFFD48A20);
  static const Color _borderColor = Color(0xFFE0E0D8);
}

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

enum _TransitionType { fadeScale, zoomIn, twirl, slideUp, flipIn, elastic }

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
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0D8), width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.5),
                child: CachedNetworkImage(
                  imageUrl: widget.photo.thumbnailUrl ?? widget.photo.url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFEEEEE8),
                    child: const Center(
                      child: Icon(
                        Icons.photo,
                        color: Color(0xFFD0D0C8),
                        size: 24,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFEEEEE8),
                    child: const Icon(
                      Icons.broken_image,
                      color: Color(0xFFD0D0C8),
                    ),
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
                  const Color(0xFFCC3333),
                  const Color(0xFFFF5555),
                  _ctrl.value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFCC3333,
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
                color: const Color(0xFFCC3333),
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
