import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/firestore_config.dart';
import '../theme/app_theme.dart';

/// Home screen — Burning Man–inspired editorial layout:
/// full-width hero, minimal header, structured content blocks.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final dbName = FirestoreConfig.databaseId;
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: AppTheme.contentLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero section — immersive night-sky gradient
                SizedBox(
                  height: 340,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background (desert night / lit art glow)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.heroDark,
                              AppTheme.heroMid,
                              AppTheme.heroWarm,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Subtle radial glow (lit installation feel)
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 400,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(200),
                              gradient: RadialGradient(
                                colors: [
                                  Color.lerp(
                                    const Color(0xFFf59e0b),
                                    Colors.transparent,
                                    0.85,
                                  )!,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Minimal header overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              color: Color.lerp(
                                AppTheme.heroDark,
                                Colors.transparent,
                                0.3,
                              ),
                              padding: EdgeInsets.fromLTRB(
                                24,
                                MediaQuery.paddingOf(context).top + 12,
                                24,
                                16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'EVENT HUB',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            context.go('/?eventId=$eventId'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('CHECK-IN'),
                                      ),
                                      if (dbName == 'event-hub-dev')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'DEV',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: AppTheme.heroDark,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        )
                                      else
                                        const SizedBox.shrink(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content blocks — overlap hero bottom
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: isNarrow
                        ? _buildMobileContent(context, theme, eventId)
                        : _buildDesktopContent(context, theme, eventId),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(
    BuildContext context,
    ThemeData theme,
    String eventId,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: dark charcoal block — Quick Actions
        Expanded(
          flex: 4,
          child: _DarkBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _ActionTile(
                  icon: Icons.analytics_rounded,
                  label: 'Analytics Dashboard',
                  subtitle: 'Live check-in stats',
                  onTap: () =>
                      context.go('/admin/dashboard?eventId=$eventId'),
                ),
                _ActionTile(
                  icon: Icons.dashboard_customize_rounded,
                  label: 'Schema Editor',
                  subtitle: 'Define registration fields',
                  onTap: () =>
                      context.go('/admin/schema/registration?eventId=$eventId'),
                ),
                _ActionTile(
                  icon: Icons.person_add_rounded,
                  label: 'New Registrant',
                  subtitle: 'Walk-in entry',
                  onTap: () =>
                      context.go('/admin/registrants/new?eventId=$eventId'),
                ),
                _ActionTile(
                  icon: Icons.upload_file_rounded,
                  label: 'Import',
                  subtitle: 'CSV bulk import',
                  onTap: () =>
                      context.go('/admin/import/registrants?eventId=$eventId'),
                ),
                _ActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Check-in',
                  subtitle: 'Manual session check-in',
                  onTap: () => context.go('/?eventId=$eventId'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Right: two light blocks
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _LightBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration & Check-in Platform',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.heroDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage registrations, define custom fields, import attendees from CSV, and run check-in sessions. Event Hub keeps everything organized.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.contentDark,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => context.go(
                        '/admin/schema/registration?eventId=$eventId',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1e40af),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('READ MORE →'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _LightBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start by adding a registrant or importing your attendee list.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.contentDark,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          context.go('/admin/registrants/new?eventId=$eventId'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFea580c),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('NEW REGISTRANT'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent(
    BuildContext context,
    ThemeData theme,
    String eventId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LightBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registration & Check-in Platform',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.heroDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Manage registrations, define custom fields, import attendees from CSV, and run check-in sessions.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.contentDark,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    context.go('/admin/registrants/new?eventId=$eventId'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFea580c),
                  foregroundColor: Colors.white,
                ),
                child: const Text('NEW REGISTRANT'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DarkBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.dashboard_customize_rounded,
                label: 'Schema Editor',
                onTap: () =>
                    context.go('/admin/schema/registration?eventId=$eventId'),
              ),
              _ActionTile(
                icon: Icons.person_add_rounded,
                label: 'New Registrant',
                onTap: () =>
                    context.go('/admin/registrants/new?eventId=$eventId'),
              ),
              _ActionTile(
                icon: Icons.upload_file_rounded,
                label: 'Import',
                onTap: () =>
                    context.go('/admin/import/registrants?eventId=$eventId'),
              ),
              _ActionTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Check-in',
                onTap: () => context.go('/?eventId=$eventId'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DarkBlock extends StatelessWidget {
  const _DarkBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.contentDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(const Color(0xFF0f172a), Colors.white, 0.92)!,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LightBlock extends StatelessWidget {
  const _LightBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.contentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(const Color(0xFF0f172a), Colors.white, 0.95)!,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFFf59e0b), Colors.white, 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFea580c), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94a3b8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: const Color(0xFF64748b),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
