import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

export 'date_range_filter.dart';

// ─── PageHeading ──────────────────────────────────────────────────────────────

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actions,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isDark ? .14 : .08),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: cs.primary.withValues(alpha: isDark ? .24 : .14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: .45),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  eyebrow.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: cs.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.9,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: isDark ? .115 : .075),
            cs.surface.withValues(alpha: .96),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: isDark ? AppShadows.smDark : AppShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 25),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (actions == null || actions!.isEmpty) return text;
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, children: actions!),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: text),
                const SizedBox(width: 24),
                Wrap(spacing: 10, runSpacing: 10, children: actions!),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── SectionCard ──────────────────────────────────────────────────────────────

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = Theme.of(context).dividerColor;
    final surface = Theme.of(context).colorScheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border, width: .7),
        boxShadow: isDark ? AppShadows.smDark : AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ─── SectionTitle ─────────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 16), trailing!],
    ],
  );
}

// ─── MetricCard ───────────────────────────────────────────────────────────────

enum MetricTone { blue, violet, green, amber, red }

class MetricCard extends StatefulWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.delta,
    this.isPositiveDelta,
    this.tone = MetricTone.blue,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;
  final String? delta;
  final bool? isPositiveDelta;
  final IconData icon;
  final MetricTone tone;
  final VoidCallback? onTap;

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _hovered = false;

  Color _accentColor() => switch (widget.tone) {
    MetricTone.blue => AppColors.brand,
    MetricTone.violet => AppColors.accent,
    MetricTone.green => AppColors.success,
    MetricTone.amber => AppColors.warning,
    MetricTone.red => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final color = _accentColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: _hovered
                ? color.withValues(alpha: .35)
                : Theme.of(context).dividerColor,
            width: .7,
          ),
          boxShadow: _hovered
              ? (isDark ? AppShadows.mdDark : AppShadows.md)
              : (isDark ? AppShadows.smDark : AppShadows.sm),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: _hovered ? .15 : .1),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: color.withValues(alpha: .14),
                          ),
                        ),
                        child: Icon(widget.icon, color: color, size: 19),
                      ),
                      const Spacer(),
                      // Delta badge
                      if (widget.delta != null)
                        _DeltaBadge(
                          delta: widget.delta!,
                          isPositive: widget.isPositiveDelta,
                        ),
                    ],
                  ),
                  const SizedBox(height: 19),
                  Text(
                    widget.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .75,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.1,
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                  ),
                  if (widget.detail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, this.isPositive});

  final String delta;
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    final isPos = isPositive ?? true;
    final color = isPos ? AppColors.success : AppColors.danger;
    final icon = isPos
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              delta,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── StatusPill ───────────────────────────────────────────────────────────────

enum StatusTone { neutral, info, success, warning, danger, purple }

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    this.tone = StatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  (Color fg, Color bg) _colors(BuildContext context) => switch (tone) {
    StatusTone.info => (AppColors.brand, const Color(0xFFDBEAFE)),
    StatusTone.success => (AppColors.success, const Color(0xFFD1FAE5)),
    StatusTone.warning => (AppColors.warning, const Color(0xFFFEF3C7)),
    StatusTone.danger => (AppColors.danger, const Color(0xFFFEE2E2)),
    StatusTone.purple => (AppColors.accent, const Color(0xFFEDE9FE)),
    StatusTone.neutral => (
      Theme.of(context).colorScheme.onSurfaceVariant,
      Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (fg, bg) = _colors(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? fg.withValues(alpha: .14) : bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 12),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact dot + text variant for use inside dense tables.
class StatusDot extends StatelessWidget {
  const StatusDot(this.label, {this.tone = StatusTone.neutral, super.key});

  final String label;
  final StatusTone tone;

  Color _dotColor(BuildContext context) => switch (tone) {
    StatusTone.info => AppColors.brand,
    StatusTone.success => AppColors.success,
    StatusTone.warning => AppColors.warning,
    StatusTone.danger => AppColors.danger,
    StatusTone.purple => AppColors.accent,
    StatusTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final color = _dotColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── AdaptiveGrid ─────────────────────────────────────────────────────────────

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxColumns = children.length.clamp(1, 4);
      final count =
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
              .floor()
              .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

// ─── ShimmerBox ───────────────────────────────────────────────────────────────

/// Animated shimmer placeholder used for skeleton loading states.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: .06)
        : Colors.black.withValues(alpha: .06);
    final shineColor = isDark
        ? Colors.white.withValues(alpha: .12)
        : Colors.black.withValues(alpha: .12);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [baseColor, shineColor, baseColor],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton row for table-style loading.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({this.wide = false});
  final bool wide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        ShimmerBox(width: 36, height: 36, borderRadius: AppRadius.full),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(
                width: wide ? 220 : 160,
                height: 12,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(height: 6),
              ShimmerBox(
                width: wide ? 140 : 100,
                height: 10,
                borderRadius: AppRadius.sm,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ShimmerBox(width: 64, height: 22, borderRadius: AppRadius.full),
      ],
    ),
  );
}

/// Skeleton for metric cards.
class _SkeletonMetricCard extends StatelessWidget {
  const _SkeletonMetricCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = Theme.of(context).dividerColor;
    final surface = Theme.of(context).colorScheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.5),
        boxShadow: isDark ? AppShadows.smDark : AppShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                ShimmerBox(width: 38, height: 38, borderRadius: AppRadius.md),
                Spacer(),
                ShimmerBox(width: 52, height: 20, borderRadius: AppRadius.full),
              ],
            ),
            SizedBox(height: 20),
            ShimmerBox(width: 80, height: 11, borderRadius: AppRadius.sm),
            SizedBox(height: 8),
            ShimmerBox(width: 120, height: 26, borderRadius: AppRadius.sm),
            SizedBox(height: 8),
            ShimmerBox(width: 100, height: 10, borderRadius: AppRadius.sm),
          ],
        ),
      ),
    );
  }
}

// ─── LoadingPanel ─────────────────────────────────────────────────────────────

enum LoadingStyle { skeleton, spinner }

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({
    this.label = 'Loading data…',
    this.style = LoadingStyle.skeleton,
    this.rowCount = 5,
    super.key,
  });

  final String label;
  final LoadingStyle style;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    if (style == LoadingStyle.spinner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Skeleton rows
    return Column(
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          _SkeletonRow(wide: i % 3 == 0),
          if (i < rowCount - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

/// Skeleton grid for metric cards (used in OverviewPage).
class MetricCardSkeletonGrid extends StatelessWidget {
  const MetricCardSkeletonGrid({this.count = 4, super.key});
  final int count;

  @override
  Widget build(BuildContext context) => AdaptiveGrid(
    children: [for (var i = 0; i < count; i++) const _SkeletonMetricCard()],
  );
}

// ─── ErrorPanel ───────────────────────────────────────────────────────────────

class ErrorPanel extends StatefulWidget {
  const ErrorPanel({
    required this.message,
    required this.onRetry,
    this.detail,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final String? detail;

  @override
  State<ErrorPanel> createState() => _ErrorPanelState();
}

class _ErrorPanelState extends State<ErrorPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon + title row
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to load data',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Actions row
            Row(
              children: [
                FilledButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
                if (widget.detail != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Hide detail' : 'Show detail'),
                  ),
                ],
              ],
            ),
            if (_expanded && widget.detail != null) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    widget.detail!,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ─── EmptyPanel ───────────────────────────────────────────────────────────────

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    required this.title,
    required this.description,
    this.icon = Icons.inbox_rounded,
    this.action,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with subtle gradient bg
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(alpha: .06),
                    cs.primary.withValues(alpha: .10),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: cs.primary.withValues(alpha: .12),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Icon(icon, size: 32, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ─── PageBody ─────────────────────────────────────────────────────────────────

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 600;
      final spacious = constraints.maxWidth >= 1500;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0D1018), AppColors.darkScaffold]
                : const [Color(0xFFF8F9FD), AppColors.lightScaffold],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 14 : (spacious ? 40 : 28),
            narrow ? 14 : 28,
            narrow ? 14 : (spacious ? 40 : 28),
            64,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _withSpacing(children),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  static List<Widget> _withSpacing(List<Widget> widgets) => [
    for (var i = 0; i < widgets.length; i++) ...[
      widgets[i],
      if (i != widgets.length - 1) const SizedBox(height: 20),
    ],
  ];
}

// ─── showAppMessage ───────────────────────────────────────────────────────────

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error
            ? AppColors.danger
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white.withValues(alpha: .9),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
}

// ─── showTypedConfirmation ────────────────────────────────────────────────────

Future<bool> showTypedConfirmation({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmationText,
  String actionLabel = 'Confirm',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _TypedConfirmationDialog(
      title: title,
      description: description,
      confirmationText: confirmationText,
      actionLabel: actionLabel,
      danger: danger,
    ),
  );
  return result ?? false;
}

Future<bool> showConfirmation({
  required BuildContext context,
  required String title,
  required String description,
  String actionLabel = 'Confirm',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      icon: danger
          ? const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.danger,
              size: 34,
            )
          : null,
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Text(description),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_action'),
          onPressed: () => Navigator.pop(dialogContext, true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
              : null,
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _TypedConfirmationDialog extends StatefulWidget {
  const _TypedConfirmationDialog({
    required this.title,
    required this.description,
    required this.confirmationText,
    required this.actionLabel,
    required this.danger,
  });

  final String title;
  final String description;
  final String confirmationText;
  final String actionLabel;
  final bool danger;

  @override
  State<_TypedConfirmationDialog> createState() =>
      _TypedConfirmationDialogState();
}

class _TypedConfirmationDialogState extends State<_TypedConfirmationDialog> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Danger header banner
            if (widget.danger)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .08),
                  border: Border(bottom: BorderSide(color: border, width: 0.5)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This action cannot be undone',
                          style: GoogleFonts.inter(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Confirmation phrase
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                          children: [
                            const TextSpan(text: 'Type '),
                            TextSpan(
                              text: widget.confirmationText,
                              style: GoogleFonts.robotoMono(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                fontSize: 12.5,
                              ),
                            ),
                            const TextSpan(text: ' to confirm.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: GoogleFonts.robotoMono(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: widget.confirmationText,
                      hintStyle: GoogleFonts.robotoMono(
                        color: cs.onSurfaceVariant.withValues(alpha: .4),
                        fontSize: 13.5,
                      ),
                    ),
                    onChanged: (value) => setState(
                      () => _valid = value == widget.confirmationText,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Actions
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border, width: 0.5)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.xl),
                  bottomRight: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _valid ? _submit : null,
                      style: widget.danger
                          ? FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            )
                          : null,
                      child: Text(widget.actionLabel),
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
}

// ─── FormSection ─────────────────────────────────────────────────────────────

/// A labeled group of related form fields.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: cs.onSurfaceVariant,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

// ─── PulsingDot ──────────────────────────────────────────────────────────────

/// Animated pulsing indicator for "pending" / "syncing" statuses.
class PulsingDot extends StatefulWidget {
  const PulsingDot({this.color = AppColors.info, this.size = 8.0, super.key});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.5,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, _) => Transform.scale(
      scale: _scale.value,
      child: Opacity(
        opacity: _opacity.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: .4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Inline spinner for button states ────────────────────────────────────────

class InlineSpinner extends StatelessWidget {
  const InlineSpinner({this.size = 16, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

// ─── CopyableText ────────────────────────────────────────────────────────────

/// Monospace text with an inline copy button — useful for UIDs, paths, etc.
class CopyableText extends StatefulWidget {
  const CopyableText(
    this.text, {
    this.display,
    this.fontSize = 11,
    this.style,
    this.copyLabel,
    super.key,
  });

  final String text;
  final String? display;
  final double fontSize;
  final TextStyle? style;
  final String? copyLabel;

  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  bool _copied = false;

  Future<void> _copy() async {
    if (!mounted) return;
    setState(() => _copied = true);
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } catch (_) {
      if (mounted) setState(() => _copied = false);
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.copyLabel ?? 'value';
    return Tooltip(
      message: _copied ? 'Copied!' : 'Copy $label',
      child: Semantics(
        button: true,
        label: _copied ? '$label copied' : 'Copy $label',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _copy,
            borderRadius: BorderRadius.circular(5),
            hoverColor: cs.primary.withValues(alpha: .08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.display ?? _truncateMiddle(widget.text),
                      overflow: TextOverflow.ellipsis,
                      style:
                          widget.style ??
                          GoogleFonts.robotoMono(
                            color: cs.onSurfaceVariant,
                            fontSize: widget.fontSize,
                          ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 14,
                      color: _copied ? AppColors.success : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _truncateMiddle(String s) {
    if (s.length <= 18) return s;
    return '${s.substring(0, 8)}…${s.substring(s.length - 6)}';
  }
}

// ─── TablePagination ─────────────────────────────────────────────────────────

class TablePagination extends StatelessWidget {
  const TablePagination({
    required this.page,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.busy = false,
    super.key,
  });

  final int page;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Page ${page + 1}',
            style: GoogleFonts.inter(
              color: cs.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: hasPrevious && !busy,
            onTap: onPrevious,
          ),
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: hasNext && !busy,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

// ─── SearchField ─────────────────────────────────────────────────────────────

class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.onSubmitted,
    this.hintText = 'Search…',
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final ValueChanged<String>? onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      hintText: hintText,
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: const Icon(Icons.close_rounded, size: 16),
            ),
    ),
    onChanged: (v) {
      onChanged?.call(v);
    },
    onSubmitted: (_) => onSubmitted(),
    style: GoogleFonts.inter(fontSize: 13.5),
  );
}
