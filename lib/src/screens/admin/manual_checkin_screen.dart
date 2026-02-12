import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/registrant.dart';
import '../../services/registrant_service.dart';
import '../../services/session_service.dart';
import '../../models/role_override.dart';
import 'registrant_new_screen.dart';

/// Check-in screen — mobile-first design with event branding,
/// QR scan CTA, manual search, and success feedback.
class ManualCheckinScreen extends StatefulWidget {
  const ManualCheckinScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    required this.checkedInBy,
    this.eventTitle,
    this.eventVenue,
    this.eventDate,
    this.registrantService,
    this.sessionService,
  });

  final String eventId;
  final String sessionId;
  final String checkedInBy;
  final String? eventTitle;
  final String? eventVenue;
  final DateTime? eventDate;
  final RegistrantService? registrantService;
  final SessionService? sessionService;

  @override
  State<ManualCheckinScreen> createState() => _ManualCheckinScreenState();
}

class _ManualCheckinScreenState extends State<ManualCheckinScreen> {
  late RegistrantService _registrantService;
  late SessionService _sessionService;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Registrant> _registrants = [];
  List<Registrant> _filtered = [];
  bool _loading = false;
  String? _error;
  Registrant? _lastCheckedIn;
  DateTime? _lastCheckedInAt;

  @override
  void initState() {
    super.initState();
    _registrantService = widget.registrantService ?? RegistrantService();
    _sessionService = widget.sessionService ?? SessionService();
    _searchController.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _registrantService.listRegistrants(widget.eventId);
      setState(() {
        _registrants = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _registrants
          : _registrants.where((r) {
              final p = r.profile.toString().toLowerCase();
              final a = r.answers.toString().toLowerCase();
              return p.contains(q) ||
                  a.contains(q) ||
                  r.id.toLowerCase().contains(q);
            }).toList();
    });
  }

  String _displayName(Registrant r) {
    final name =
        r.profile['name'] ?? r.profile['firstName'] ?? r.profile['fullName'];
    if (name?.toString().trim().isNotEmpty ?? false) {
      return name.toString().trim();
    }
    final first = r.profile['firstName'] ?? r.answers['firstName'];
    final last = r.profile['lastName'] ?? r.answers['lastName'];
    if ((first ?? last) != null) {
      return '${first ?? ''} ${last ?? ''}'.trim();
    }
    return r.id;
  }

  String _displaySubtitle(Registrant r) {
    final parts = <String>[];
    final role = r.profile['role'] ?? r.answers['role'];
    final unit =
        r.profile['unit'] ?? r.answers['unit'] ?? r.answers['affiliation'];
    if (role != null && role.toString().isNotEmpty) {
      parts.add(role.toString());
    }
    if (unit != null && unit.toString().isNotEmpty) {
      parts.add(unit.toString());
    }
    if (parts.isEmpty) return r.id;
    return parts.join(' • ');
  }

  Future<void> _checkIn(Registrant r) async {
    try {
      if (!r.eventAttendance.checkedIn) {
        await _registrantService.checkInEvent(
          widget.eventId,
          r.id,
          widget.checkedInBy,
        );
      }
      await _sessionService.checkInSession(
        widget.eventId,
        widget.sessionId,
        r.id,
        widget.checkedInBy,
      );
      if (mounted) {
        setState(() {
          _lastCheckedIn = r;
          _lastCheckedInAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createAndCheckIn() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            RegistrantNewScreen(eventId: widget.eventId, role: UserRole.staff),
      ),
    );
    if (id != null && mounted) {
      await _load();
      final found = _registrants.where((x) => x.id == id).toList();
      if (found.isNotEmpty) await _checkIn(found.first);
    }
  }

  void _onScanQr() {
    // Placeholder: wire up mobile_scanner or similar when added
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR scanning coming soon')));
  }

  String get _eventTitle => widget.eventTitle ?? _formatEventId(widget.eventId);

  String _formatEventId(String id) {
    if (id.isEmpty) return 'Event';
    final parts = id.split('-');
    return parts
        .map(
          (p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = widget.eventDate != null
        ? DateFormat('MMMM d, y').format(widget.eventDate!)
        : null;
    final venueStr = widget.eventVenue;

    return Scaffold(
      body: Stack(
        children: [
          // Base gradient — deep teal/blue
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0d3d4d),
                  Color(0xFF0a2f3d),
                  Color(0xFF082830),
                ],
              ),
            ),
          ),
          // Subtle geometric pattern overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(painter: _GeometricPatternPainter()),
            ),
          ),
          // Mosaic corner decorations
          Positioned(
            top: 0,
            right: 0,
            child: _MosaicCorner(orientation: _CornerOrientation.topRight),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _MosaicCorner(orientation: _CornerOrientation.bottomLeft),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo — stylized figure with halo
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFea580c),
                                width: 2,
                              ),
                              color: Colors.transparent,
                            ),
                          ),
                          const Icon(
                            Icons.accessibility_new_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          Positioned(
                            top: 4,
                            right: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFea580c),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Event Hub',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFcbd5e1),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _eventTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                height: 1.2,
                              ),
                            ),
                            if (dateStr != null || venueStr != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  dateStr,
                                  venueStr,
                                ].whereType<String>().join(' • '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF94a3b8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            context.go('/admin?eventId=${widget.eventId}'),
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // QR Scan button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onScanQr,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1d4ed8),
                                    Color(0xFF2563eb),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.lerp(
                                      const Color(0xFF2563eb),
                                      Colors.transparent,
                                      0.6,
                                    )!,
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scan Conference QR Code',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fastest way to check in',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94a3b8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // OR separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF94a3b8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Manual search field — light gradient, keyboard icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFf8fafc), Color(0xFFe2e8f0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color.lerp(
                            const Color(0xFF0a2f3d),
                            Colors.transparent,
                            0.85,
                          )!,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(
                        color: Color(0xFF1e293b),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter Name or CFC ID',
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748b),
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.keyboard_rounded,
                          color: Color(0xFF64748b),
                          size: 22,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF94a3b8),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Search results
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e293b),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: _filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No matches for "${_searchController.text}"',
                                style: const TextStyle(
                                  color: Color(0xFF94a3b8),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final r = _filtered[i];
                                return ListTile(
                                  title: Text(
                                    _displayName(r),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _displaySubtitle(r),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF94a3b8),
                                    ),
                                  ),
                                  onTap: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                    _checkIn(r);
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFf87171),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Success state — light card with dark text
                if (_lastCheckedIn != null && _lastCheckedInAt != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf8fafc),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Color.lerp(
                              const Color(0xFF0a2f3d),
                              Colors.transparent,
                              0.9,
                            )!,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22c55e),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Checked In Successfully',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF16a34a),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _displayName(_lastCheckedIn!),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF1e293b),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displaySubtitle(_lastCheckedIn!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF64748b),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Checked in at ${DateFormat.jm().format(_lastCheckedInAt!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF94a3b8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  )
                else
                  const Spacer(),
                const Spacer(),
                // Footer links
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        height: 1,
                        color: const Color(0xFF475569),
                        margin: const EdgeInsets.only(bottom: 16),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _createAndCheckIn,
                            child: Text(
                              'Manual Add Attendee',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF94a3b8),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF94a3b8),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: const Color(0xFF475569),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go('/admin?eventId=${widget.eventId}'),
                            child: Text(
                              'Switch Session / Day',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF94a3b8),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF94a3b8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle geometric (Greek-key style) pattern for background texture.
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 24.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var y = 0.0; y < size.height + spacing; y += spacing) {
      for (var x = 0.0; x < size.width + spacing; x += spacing) {
        canvas.drawRect(Rect.fromLTWH(x, y, 12, 12), paint);
        canvas.drawLine(Offset(x + 4, y), Offset(x + 4, y + 12), paint);
        canvas.drawLine(Offset(x, y + 4), Offset(x + 12, y + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _CornerOrientation { topRight, bottomLeft }

/// Decorative mosaic tile corner.
class _MosaicCorner extends StatelessWidget {
  const _MosaicCorner({required this.orientation});

  final _CornerOrientation orientation;

  @override
  Widget build(BuildContext context) {
    const tileSize = 8.0;
    const colors = [
      Color(0xFFea580c), // orange
      Color(0xFF7dd3fc), // light blue
      Colors.white,
    ];
    final tiles = <Widget>[];
    for (var i = 0; i < 6; i++) {
      for (var j = 0; j < 4; j++) {
        tiles.add(
          Container(
            width: tileSize,
            height: tileSize,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: colors[(i + j) % 3],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }
    }
    return SizedBox(
      width: 56,
      height: 48,
      child: orientation == _CornerOrientation.topRight
          ? Wrap(
              alignment: WrapAlignment.end,
              runAlignment: WrapAlignment.start,
              children: tiles,
            )
          : Wrap(
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.end,
              children: tiles,
            ),
    );
  }
}
