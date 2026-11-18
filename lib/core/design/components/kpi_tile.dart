import "package:flutter/material.dart";
import "../tokens/app_colors.dart";
import "../tokens/app_typography.dart";
import "../tokens/app_spacing.dart";

/// Compact metric card designed for high-density horizontal metric strips
class CompactMetricTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const CompactMetricTile({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = accentColor ?? colors.brand;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.cardBorderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppSpacing.cardBorderRadius,
            border: Border.all(color: colors.border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count.toString().padLeft(2, "0"),
                          style: AppTypography.value(colors.text, fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(
                  label,
                  style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backward compatible KpiTile with animation
class KpiTile extends StatefulWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Color containerColor;
  final VoidCallback? onTap;

  const KpiTile({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.containerColor,
    this.onTap,
  });

  @override
  State<KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<KpiTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = IntTween(begin: 0, end: widget.count).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KpiTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _animation = IntTween(begin: oldWidget.count, end: widget.count).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppSpacing.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.containerColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                ),
                child: Icon(widget.icon, size: 20, color: widget.accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.section(colors.text, fontSize: 15),
                ),
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final val = disableAnimations ? widget.count : _animation.value;
                  return Text(
                    val.toString().padLeft(2, "0"),
                    style: AppTypography.value(widget.accentColor, fontSize: 24),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
