import 'package:flutter/material.dart';
import 'package:smartfleet_flutter/core/data/models/trip.dart';
import 'package:smartfleet_flutter/core/data/models/truck.dart';
import 'package:smartfleet_flutter/core/theme/app_theme.dart';
import 'package:smartfleet_flutter/l10n/app_localizations.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
  });

  factory StatusChip.forTrip(BuildContext context, TripStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case TripStatus.waiting:
        return StatusChip(
          label: l10n.statusWaiting,
          icon: Icons.hourglass_empty,
          textColor: AppColors.statusWaitingText,
          backgroundColor: AppColors.statusWaitingBg,
        );
      case TripStatus.accepted:
        return StatusChip(
          label: l10n.statusAccepted,
          icon: Icons.check,
          textColor: AppColors.statusRunningText,
          backgroundColor: AppColors.statusRunningBg,
        );
      case TripStatus.running:
        return StatusChip(
          label: l10n.statusRunning,
          icon: Icons.navigation,
          textColor: AppColors.statusRunningText,
          backgroundColor: AppColors.statusRunningBg,
        );
      case TripStatus.delivered:
        return StatusChip(
          label: l10n.statusDelivered,
          icon: Icons.check_circle,
          textColor: AppColors.statusDoneText,
          backgroundColor: AppColors.statusDoneBg,
        );
      default:
        return StatusChip(
          label: 'Alert',
          icon: Icons.warning,
          textColor: AppColors.statusWaitingText,
          backgroundColor: AppColors.statusWaitingBg,
        );
    }
  }

  factory StatusChip.forTruck(BuildContext context, TruckStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case TruckStatus.available:
        return StatusChip(
          label: l10n.filterAll,
          icon: Icons.check_circle,
          textColor: AppColors.statusDoneText,
          backgroundColor: AppColors.statusDoneBg,
        );
      case TruckStatus.onTrip:
        return StatusChip(
          label: l10n.statusRunning,
          icon: Icons.local_shipping,
          textColor: AppColors.statusRunningText,
          backgroundColor: AppColors.statusRunningBg,
        );
      case TruckStatus.inWorkshop:
        return StatusChip(
          label: l10n.statusInWorkshop,
          icon: Icons.build,
          textColor: AppColors.statusProblemText,
          backgroundColor: AppColors.statusProblemBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
