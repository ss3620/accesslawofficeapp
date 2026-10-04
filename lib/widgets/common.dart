import 'package:flutter/material.dart';

import '../theme/colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.compact = false,
    this.light = false,
    this.showTagline = true,
  });

  final bool compact;
  final bool light;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? Colors.white : AppColors.navy;
    final tagColor = light ? AppColors.goldLight : AppColors.gold;
    final logoSize = compact ? 48.0 : 64.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandLogo(size: logoSize),
        SizedBox(height: compact ? 12 : 16),
        Text(
          'Access Law Firm',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: titleColor,
                fontSize: compact ? 24 : 32,
              ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Experience × Affordability = Access',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tagColor,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }
}

class SplashBrand extends StatelessWidget {
  const SplashBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: 112),
        SizedBox(height: 24),
        Text(
          'Access Law Firm',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.compact = false,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? label : (count == 1 ? '1 new' : '$label new'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.gold = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: gold
          ? ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
            )
          : null,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(label),
    );
  }
}

/// Keeps a solid background behind scroll views so iOS overscroll does not
/// flash the default grey Material canvas.
class ScrollScreenBody extends StatelessWidget {
  const ScrollScreenBody({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.cream,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: backgroundColor),
        child,
      ],
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar && title != null
          ? AppBar(title: Text(title!), actions: actions)
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: child),
    );
  }
}
