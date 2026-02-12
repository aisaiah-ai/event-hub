import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Styled scaffold for admin screens with consistent header and layout.
class StyledScaffold extends StatelessWidget {
  const StyledScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
              )
            : null,
        title: Text(title),
        actions: actions,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}
