import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/firestore_config.dart';
import '../data/event_model.dart';

/// Live photos panel that streams approved images from Firestore.
/// Shows a rotating photo grid with auto-slideshow and photo count.
/// Optional color overrides for theming (light/dark).
class PhotosPanelColors {
  const PhotosPanelColors({
    this.cardBg = const Color(0xFF1A1A2A),
    this.cardBorder = const Color(0xFF2A2A3A),
    this.accent = const Color(0xFFB44CE0),
    this.textPrimary = Colors.white,
    this.textMuted = const Color(0xFF8888A0),
  });

  final Color cardBg;
  final Color cardBorder;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  static const dark = PhotosPanelColors();
  static const light = PhotosPanelColors(
    cardBg: Colors.white,
    cardBorder: Color(0xFFE0E0D8),
    accent: Color(0xFF9040B0),
    textPrimary: Color(0xFF1A1A1A),
    textMuted: Color(0xFF888880),
  );
}

class LivePhotosPanel extends StatefulWidget {
  const LivePhotosPanel({
    super.key,
    required this.event,
    this.isKiosk = false,
    this.maxHeight = 280,
    this.colors = PhotosPanelColors.dark,
  });

  final EventModel event;
  final bool isKiosk;

  /// Max height for the panel (used in bottom strip layout).
  final double maxHeight;
  final PhotosPanelColors colors;

  @override
  State<LivePhotosPanel> createState() => _LivePhotosPanelState();
}

class _LivePhotosPanelState extends State<LivePhotosPanel>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  List<_Photo> _photos = [];
  bool _loading = true;

  // Slideshow
  int _spotlightIndex = 0;
  Timer? _slideshowTimer;
  late AnimationController _fadeController;
  final _random = Random();

  // Grid display order (shuffled)
  List<int> _gridOrder = [];
  Timer? _gridShuffleTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..value = 1.0;
    _startStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _slideshowTimer?.cancel();
    _gridShuffleTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startStream() {
    final fs = FirestoreConfig.instanceOrNull;
    if (fs == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Use canonical doc ID
    final docId = widget.event.id == 'march-cluster-2026'
        ? 'march-assembly'
        : widget.event.id;

    _sub = fs
        .collection('events')
        .doc(docId)
        .collection('images')
        .snapshots()
        .listen(
          (snap) {
            final approved = snap.docs
                .where((d) => (d.data())['status'] == 'approved')
                .map((d) {
                  final data = d.data();
                  return _Photo(
                    id: d.id,
                    url: data['url'] as String? ?? '',
                    thumbnailUrl: data['thumbnailUrl'] as String?,
                    uploaderName: data['uploaderName'] as String?,
                  );
                })
                .toList();

            if (!mounted) return;
            final wasEmpty = _photos.isEmpty;
            setState(() {
              _photos = approved;
              _loading = false;
              _refreshGridOrder();
            });
            if (wasEmpty && approved.isNotEmpty) {
              _startTimers();
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  void _refreshGridOrder() {
    _gridOrder = List.generate(_photos.length, (i) => i)..shuffle(_random);
  }

  void _startTimers() {
    // Slideshow: cycle spotlight every 5 seconds
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_photos.isEmpty || !mounted) return;
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _spotlightIndex = (_spotlightIndex + 1) % _photos.length;
        });
        _fadeController.forward();
      });
    });

    // Grid shuffle every 6 seconds
    _gridShuffleTimer?.cancel();
    _gridShuffleTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_photos.length > 1 && mounted) {
        setState(() => _refreshGridOrder());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.isKiosk;
    final c = widget.colors;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              k ? 24.0 : 18.0,
              k ? 16.0 : 12.0,
              k ? 24.0 : 18.0,
              k ? 10.0 : 8.0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  color: c.accent,
                  size: k ? 22 : 18,
                ),
                SizedBox(width: k ? 10 : 8),
                Text(
                  'Live Photos',
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: k ? 18 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_photos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_photos.length} photos',
                      style: GoogleFonts.inter(
                        color: c.accent,
                        fontSize: k ? 12 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: c.accent,
                      strokeWidth: 2,
                    ),
                  )
                : _photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: c.textMuted.withValues(alpha: 0.5),
                          size: k ? 36 : 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No photos yet',
                          style: GoogleFonts.inter(
                            color: c.textMuted,
                            fontSize: k ? 14 : 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildPhotoContent(k),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoContent(bool k) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        k ? 18.0 : 14.0,
        0,
        k ? 18.0 : 14.0,
        k ? 14.0 : 10.0,
      ),
      child: Row(
        children: [
          // Spotlight photo (left side, larger)
          Expanded(flex: 3, child: _buildSpotlight(k)),
          SizedBox(width: k ? 10 : 8),
          // Grid thumbnails (right side)
          Expanded(flex: 2, child: _buildGrid(k)),
        ],
      ),
    );
  }

  Widget _buildSpotlight(bool k) {
    if (_photos.isEmpty) return const SizedBox.shrink();
    final photo = _photos[_spotlightIndex.clamp(0, _photos.length - 1)];
    final c = widget.colors;

    return FadeTransition(
      opacity: _fadeController,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: photo.url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (_, _) => Container(color: c.cardBorder),
              errorWidget: (_, _, _) => Container(
                color: c.cardBorder,
                child: Icon(Icons.broken_image, color: c.textMuted),
              ),
            ),
            if (photo.uploaderName != null && photo.uploaderName!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    k ? 12 : 10,
                    k ? 20 : 16,
                    k ? 12 : 10,
                    k ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    photo.uploaderName!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: k ? 13 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(bool k) {
    final gridPhotos = _gridOrder
        .where((i) => i != _spotlightIndex && i < _photos.length)
        .take(4)
        .toList();
    final c = widget.colors;

    if (gridPhotos.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: k ? 8 : 6,
      crossAxisSpacing: k ? 8 : 6,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: gridPhotos.map((i) {
        final photo = _photos[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: photo.thumbnailUrl ?? photo.url,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (_, _) => Container(color: c.cardBorder),
            errorWidget: (_, _, _) => Container(
              color: c.cardBorder,
              child: Icon(
                Icons.broken_image,
                color: c.textMuted,
                size: k ? 18 : 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Photo {
  const _Photo({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.uploaderName,
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final String? uploaderName;
}
