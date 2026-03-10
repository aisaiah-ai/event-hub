import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../widgets/event_page_scaffold.dart';

/// Admin dashboard for reviewing and approving uploaded event images.
///
/// Route: /events/:eventSlug/images/admin
class ImageAdminDashboardPage extends StatefulWidget {
  const ImageAdminDashboardPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<ImageAdminDashboardPage> createState() =>
      _ImageAdminDashboardPageState();
}

class _ImageAdminDashboardPageState extends State<ImageAdminDashboardPage> {
  final _repo = EventRepository();
  EventModel? _event;
  List<_ImageItem> _images = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all, pending, approved, rejected
  final Set<String> _selected = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await _repo.getEventBySlug(widget.eventSlug);
      if (event == null) throw StateError('Event not found');

      print('[ImageAdmin] Event loaded: id=${event.id} slug=${event.slug}');

      // Read images directly from the (default) database, march-assembly doc.
      final fs = FirebaseFirestore.instance;
      print('[ImageAdmin] Firestore db: ${fs.databaseId}');

      final images = <_ImageItem>[];

      // Always read from march-assembly — that's where the API writes.
      for (final docId in {'march-assembly', event.id}) {
        print('[ImageAdmin] Trying events/$docId/images ...');
        try {
          final snap = await fs
              .collection('events')
              .doc(docId)
              .collection('images')
              .get();
          print('[ImageAdmin] events/$docId/images => ${snap.docs.length} docs');
          for (final doc in snap.docs) {
            if (images.any((i) => i.id == doc.id)) continue;
            final d = doc.data();
            print('[ImageAdmin]   doc ${doc.id}: status=${d['status']} uploader=${d['uploaderName']}');
            final createdAt = d['createdAt'];
            images.add(_ImageItem(
              id: doc.id,
              url: d['url'] as String? ?? '',
              thumbnailUrl: d['thumbnailUrl'] as String?,
              uploaderName: d['uploaderName'] as String? ?? 'Unknown',
              uploadedBy: d['uploadedBy'] as String? ?? '',
              status: d['status'] as String? ?? 'pending',
              createdAt: createdAt is Timestamp
                  ? createdAt.toDate()
                  : DateTime.tryParse(createdAt?.toString() ?? '') ??
                      DateTime.now(),
            ));
          }
        } catch (e, st) {
          print('[ImageAdmin] ERROR reading events/$docId/images: $e');
          print('[ImageAdmin] Stack: $st');
        }
      }

      images.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _event = event;
        _images = images;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_ImageItem> get _filtered {
    if (_filter == 'all') return _images;
    return _images.where((i) => i.status == _filter).toList();
  }

  int _countByStatus(String status) =>
      _images.where((i) => i.status == status).length;

  /// Canonical event doc ID for Firestore writes.
  String get _canonicalEventId {
    final e = _event;
    if (e == null) return 'march-assembly';
    return (e.id == 'march-cluster-2026' && e.slug == 'march-cluster-2026')
        ? 'march-assembly'
        : e.id;
  }

  Future<void> _updateStatus(String imageId, String status) async {
    if (_event == null) return;
    print('[ImageAdmin] Approving $imageId -> $status in events/$_canonicalEventId/images');
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_canonicalEventId)
          .collection('images')
          .doc(imageId)
          .update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      print('[ImageAdmin] Update successful');
      setState(() {
        final idx = _images.indexWhere((i) => i.id == imageId);
        if (idx != -1) {
          _images[idx] = _images[idx].copyWith(status: status);
        }
        _selected.remove(imageId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image ${status == 'approved' ? 'approved' : 'rejected'}'),
            backgroundColor: status == 'approved'
                ? const Color(0xFF4CE0A0)
                : const Color(0xFFE04C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[ImageAdmin] Update FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkUpdateStatus(String status) async {
    final event = _event;
    if (event == null || _selected.isEmpty) return;
    final ids = _selected.toList();
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.update(
        FirebaseFirestore.instance
            .collection('events')
            .doc(_canonicalEventId)
            .collection('images')
            .doc(id),
        {
          'status': status,
          'reviewedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    try {
      await batch.commit();
      setState(() {
        for (final id in ids) {
          final idx = _images.indexWhere((i) => i.id == id);
          if (idx != -1) {
            _images[idx] = _images[idx].copyWith(status: status);
          }
        }
        _selected.clear();
        _selectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ids.length} image${ids.length == 1 ? '' : 's'} ${status == 'approved' ? 'approved' : 'rejected'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk update failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteImage(String imageId) async {
    final event = _event;
    if (event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('This will permanently remove this image.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_canonicalEventId)
          .collection('images')
          .doc(imageId)
          .delete();
      setState(() {
        _images.removeWhere((i) => i.id == imageId);
        _selected.remove(imageId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: _event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 900,
      overlayOpacity: 0.85,
      overlayTint: const Color(0xFF0A0A14),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
              ? _buildError()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: _buildDashboard(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _gold, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load images',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _gold),
            label: Text('Retry', style: GoogleFonts.inter(color: _gold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final pending = _countByStatus('pending');
    final approved = _countByStatus('approved');
    final rejected = _countByStatus('rejected');
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.photo_library_rounded, color: _gold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image Review',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_images.length} total uploads',
                    style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.push('/events/${widget.eventSlug}/photo-wall'),
              icon: const Icon(Icons.tv_rounded, size: 16, color: _gold),
              label: Text(
                'Photo Wall',
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: _gold),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Stats row
        Row(
          children: [
            _StatChip(
              label: 'All',
              count: _images.length,
              color: Colors.white,
              selected: _filter == 'all',
              onTap: () => setState(() => _filter = 'all'),
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Pending',
              count: pending,
              color: const Color(0xFFE0B646),
              selected: _filter == 'pending',
              onTap: () => setState(() => _filter = 'pending'),
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Approved',
              count: approved,
              color: const Color(0xFF4CE0A0),
              selected: _filter == 'approved',
              onTap: () => setState(() => _filter = 'approved'),
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Rejected',
              count: rejected,
              color: const Color(0xFFE04C4C),
              selected: _filter == 'rejected',
              onTap: () => setState(() => _filter = 'rejected'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bulk actions bar
        if (_selectMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text(
                  '${_selected.length} selected',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selected.clear();
                    _selected.addAll(filtered.map((i) => i.id));
                  }),
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4CE0A0),
                  onTap: _selected.isEmpty
                      ? null
                      : () => _bulkUpdateStatus('approved'),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFE04C4C),
                  onTap: _selected.isEmpty
                      ? null
                      : () => _bulkUpdateStatus('rejected'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => setState(() {
                    _selectMode = false;
                    _selected.clear();
                  }),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: _textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: filtered.isEmpty
                  ? null
                  : () => setState(() => _selectMode = true),
              icon: const Icon(Icons.checklist_rounded, size: 16),
              label: const Text('Select'),
              style: TextButton.styleFrom(foregroundColor: _gold),
            ),
          ),
        ],

        // Image grid
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                const Icon(Icons.photo_outlined, color: _textMuted, size: 48),
                const SizedBox(height: 12),
                Text(
                  _filter == 'all'
                      ? 'No images uploaded yet'
                      : 'No $_filter images',
                  style: GoogleFonts.inter(color: _textMuted, fontSize: 14),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600
                  ? 3
                  : constraints.maxWidth > 400
                      ? 2
                      : 1;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filtered.map((img) {
                  final w =
                      (constraints.maxWidth - (crossCount - 1) * 10) /
                          crossCount;
                  return SizedBox(
                    width: w,
                    child: _ImageCard(
                      image: img,
                      selectMode: _selectMode,
                      selected: _selected.contains(img.id),
                      onToggleSelect: () => setState(() {
                        if (_selected.contains(img.id)) {
                          _selected.remove(img.id);
                        } else {
                          _selected.add(img.id);
                        }
                      }),
                      onApprove: () => _updateStatus(img.id, 'approved'),
                      onReject: () => _updateStatus(img.id, 'rejected'),
                      onDelete: () => _deleteImage(img.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  static BoxDecoration _cardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      );

  static const Color _gold = Color(0xFFF4A340);
  static const Color _cardBg = Color(0xFF1A1A2A);
  static const Color _cardBorder = Color(0xFF2A2A3A);
  static const Color _textMuted = Color(0xFF8888A0);
}

// ══════════════════════════════════════════════════════════════════════
// Data model
// ══════════════════════════════════════════════════════════════════════

class _ImageItem {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String uploaderName;
  final String uploadedBy;
  final String status;
  final DateTime createdAt;

  const _ImageItem({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.uploaderName,
    required this.uploadedBy,
    required this.status,
    required this.createdAt,
  });

  _ImageItem copyWith({String? status}) => _ImageItem(
        id: id,
        url: url,
        thumbnailUrl: thumbnailUrl,
        uploaderName: uploaderName,
        uploadedBy: uploadedBy,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

// ══════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : const Color(0xFF2A2A3A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? color : const Color(0xFF8888A0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: onTap != null ? color : color.withValues(alpha: 0.3)),
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: onTap != null ? color : color.withValues(alpha: 0.3),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.image,
    required this.selectMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final _ImageItem image;
  final bool selectMode;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  Color get _statusColor {
    switch (image.status) {
      case 'approved':
        return const Color(0xFF4CE0A0);
      case 'rejected':
        return const Color(0xFFE04C4C);
      default:
        return const Color(0xFFE0B646);
    }
  }

  IconData get _statusIcon {
    switch (image.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectMode ? onToggleSelect : () => _showFullImage(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFF4A340)
                : const Color(0xFF2A2A3A),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: image.thumbnailUrl ?? image.url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF2A2A3A),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8888A0),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF2A2A3A),
                      child: const Icon(
                        Icons.broken_image,
                        color: Color(0xFF8888A0),
                      ),
                    ),
                  ),
                ),
                // Status badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, size: 12, color: _statusColor),
                        const SizedBox(width: 4),
                        Text(
                          image.status.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: _statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Checkbox in select mode
                if (selectMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF4A340)
                            : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            // Info + actions
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.uploaderName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, h:mm a').format(image.createdAt),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8888A0),
                      fontSize: 10,
                    ),
                  ),
                  if (!selectMode) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (image.status != 'approved')
                          _SmallActionBtn(
                            icon: Icons.check,
                            color: const Color(0xFF4CE0A0),
                            tooltip: 'Approve',
                            onTap: onApprove,
                          ),
                        if (image.status != 'rejected') ...[
                          const SizedBox(width: 6),
                          _SmallActionBtn(
                            icon: Icons.close,
                            color: const Color(0xFFE04C4C),
                            tooltip: 'Reject',
                            onTap: onReject,
                          ),
                        ],
                        const Spacer(),
                        _SmallActionBtn(
                          icon: Icons.delete_outline,
                          color: const Color(0xFF8888A0),
                          tooltip: 'Delete',
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: image.url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            // Action buttons at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (image.status != 'approved')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onApprove();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CE0A0),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (image.status != 'rejected')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onReject();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE04C4C),
                        foregroundColor: Colors.white,
                      ),
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

class _SmallActionBtn extends StatelessWidget {
  const _SmallActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
