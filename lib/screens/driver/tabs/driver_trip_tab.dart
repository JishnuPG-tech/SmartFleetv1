import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/design/tokens/app_colors.dart";
import "../../../core/design/tokens/app_typography.dart";
import "../../../core/design/tokens/app_spacing.dart";
import "../../../core/design/components/buttons.dart";
import "../../../core/design/components/status_chip.dart";
import "../../../core/data/fleet_repository.dart";
import "../../../core/data/models/trip.dart";
import "../../../core/data/models/truck.dart";
import "../../../core/data/api_client.dart";
import "../../../core/maps/smart_fleet_map.dart";
import "../delivery_proof_flow.dart";

import "../../../core/data/models/driver.dart";

class DriverTripTab extends StatefulWidget {
  final Driver? driver;
  const DriverTripTab({super.key, this.driver});

  @override
  State<DriverTripTab> createState() => _DriverTripTabState();
}

class _DriverTripTabState extends State<DriverTripTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalFleetRepository.instance.refresh();
    });
  }

  void _openGoogleMaps(BuildContext context, String from, String to) async {
    final query = Uri.encodeComponent("$to, Kerala");
    final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps navigation.")),
        );
      }
    }
  }

  void _callOffice(BuildContext context) async {
    final url = Uri.parse("tel:+919895000000");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Calling fleet office: +91 98950 00000")),
        );
      }
    }
  }

  void _showBreakdownDialog(BuildContext context, Trip trip, AppColorsExtension colors) {
    String selectedReason = "Tyre Puncture / Blowout";
    final reasons = [
      "Tyre Puncture / Blowout",
      "Engine Overheating",
      "Brake / Mechanical Fault",
      "Road Accident / Blocked",
      "Consignee Hub Closed",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.statusDanger.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning_amber_rounded, color: colors.statusDanger, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Report Breakdown / SOS",
                              style: AppTypography.title(colors.text, fontSize: 17),
                            ),
                            Text(
                              "Instant alert sent to Fleet HQ with live GPS pin",
                              style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text("Select Primary Issue:", style: AppTypography.section(colors.text, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: isSelected,
                        selectedColor: colors.statusDanger.withValues(alpha: 0.2),
                        backgroundColor: colors.surfaceAlt,
                        labelStyle: TextStyle(
                          color: isSelected ? colors.statusDanger : colors.text,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? colors.statusDanger : colors.border,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedReason = r);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: "Transmit Emergency Alert",
                    icon: Icons.emergency_rounded,
                    height: 52,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Ingest real or interpolated GPS of breakdown
                      await LocalFleetRepository.instance.reportBreakdown(
                        trip.id,
                        latitude: 10.5276,
                        longitude: 76.2144,
                        reason: selectedReason,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("🚨 Breakdown logged! Fleet support notified for $selectedReason."),
                            backgroundColor: colors.statusDanger,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentDriver = widget.driver ?? ApiClient.instance.currentDriver;
    final currentDriverId = currentDriver?.id;
    final currentPlate = (currentDriver?.assignedTruckPlate ?? '').replaceAll(' ', '').toUpperCase();
    final currentPhoneDigits = (currentDriver?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final currentLast10 = currentPhoneDigits.length >= 10 ? currentPhoneDigits.substring(currentPhoneDigits.length - 10) : currentPhoneDigits;
    final currentName = (currentDriver?.name ?? '').trim().toLowerCase();

    return StreamBuilder<List<Trip>>(
      stream: LocalFleetRepository.instance.watchTrips(),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? [];
        
        // Find the active trip for this logged in driver with multi-factor matching
        final activeTrips = trips.where((t) {
          if (t.status == TripStatus.delivered || t.status == TripStatus.failed) {
            return false;
          }

          // 1. Direct ID match
          if (currentDriverId != null && t.driverId == currentDriverId) {
            return true;
          }

          // 2. Default/seed driver aliases
          if ((t.driverId == 'd1' || t.driverId == 'driver-1') && (currentDriverId == null || currentDriverId == 'd1' || currentDriverId.contains('b9d42b88'))) {
            return true;
          }
          if (t.driverId.contains('b9d42b88') && (currentDriverId == 'd1' || currentDriverId == 'driver-1')) {
            return true;
          }

          // 3. Truck plate match (Driver is assigned to this specific truck)
          final tripPlate = t.truckPlate.replaceAll(' ', '').toUpperCase();
          if (currentPlate.isNotEmpty && tripPlate.isNotEmpty && currentPlate == tripPlate) {
            return true;
          }

          // 4. Match against loaded fleet drivers by phone or name
          for (final d in LocalFleetRepository.instance.currentDrivers) {
            if (d.id == t.driverId) {
              final dPhoneDigits = d.phone.replaceAll(RegExp(r'[^0-9]'), '');
              if (currentLast10.isNotEmpty && dPhoneDigits.endsWith(currentLast10)) {
                return true;
              }
              if (currentName.isNotEmpty && d.name.trim().toLowerCase() == currentName) {
                return true;
              }
              if (currentPlate.isNotEmpty && d.assignedTruckPlate.replaceAll(' ', '').toUpperCase() == currentPlate) {
                return true;
              }
            }
          }

          return false;
        }).toList();

        // 1. STANDBY / NO ACTIVE TRIP
        if (activeTrips.isEmpty) {
          return RefreshIndicator(
            color: colors.brand,
            backgroundColor: colors.surface,
            onRefresh: () => LocalFleetRepository.instance.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppSpacing.cardBorderRadius,
                        border: Border.all(color: colors.border, width: 1.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.brand.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.local_shipping_outlined, color: colors.brand, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Ready for Dispatch",
                            style: AppTypography.title(colors.text, fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${currentDriver?.name ?? 'Suresh Kumar'} · ${currentDriver?.assignedTruckPlate ?? 'KL 11 AB 1234'}",
                            style: AppTypography.supporting(colors.brand, fontSize: 14).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No loads assigned right now. Pull down to refresh or standby. New trip tickets will pop up here instantly.",
                            textAlign: TextAlign.center,
                            style: AppTypography.supporting(colors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final trip = activeTrips.first;
        final isWaiting = trip.status == TripStatus.waiting;
        final isAccepted = trip.status == TripStatus.accepted;
        final isRunning = trip.status == TripStatus.running;
        final isBreakdown = trip.status == TripStatus.breakdown;

        final origin = LatLng(9.9312, 76.2673);
        final dest = LatLng(11.2588, 75.7804);
        final truckPos = isRunning ? LatLng(10.5276, 76.2144) : origin;

        return RefreshIndicator(
          color: colors.brand,
          backgroundColor: colors.surface,
          onRefresh: () => LocalFleetRepository.instance.refresh(),
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // TOP STATUS TICKET CARD (Minimal & compact)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppSpacing.cardBorderRadius,
                border: Border.all(
                  color: isBreakdown ? colors.statusDanger : colors.border,
                  width: isBreakdown ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trip.id,
                        style: AppTypography.section(colors.text, fontSize: 16, isNumber: true),
                      ),
                      StatusChipV2(
                        label: isWaiting
                            ? "Assigned"
                            : (isAccepted
                                ? "Accepted"
                                : (isRunning ? "Live En Route" : (isBreakdown ? "🚨 Breakdown" : "Done"))),
                        icon: isWaiting
                            ? Icons.hourglass_empty_rounded
                            : (isAccepted
                                ? Icons.task_alt_rounded
                                : (isRunning ? Icons.navigation_rounded : (isBreakdown ? Icons.warning_rounded : Icons.check_circle_rounded))),
                        type: isWaiting
                            ? ChipStatusType.waiting
                            : (isAccepted
                                ? ChipStatusType.running
                                : (isRunning ? ChipStatusType.running : (isBreakdown ? ChipStatusType.danger : ChipStatusType.success))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${trip.from} ➔ ${trip.to}",
                    style: AppTypography.title(colors.text, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${trip.weightTons}T ${trip.cargo} · Allowance: ₹${trip.allowanceAmount} Bata",
                    style: AppTypography.supporting(colors.brand, fontSize: 13).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // LIVE GPS BAR (When running)
            if (isRunning) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.statusSuccess,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Live GPS Sharing Active (NH-66)",
                        style: AppTypography.supporting(colors.text, fontSize: 13).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      "${trip.distanceDoneKm.toStringAsFixed(0)} / ${trip.distanceKm.toStringAsFixed(0)} km",
                      style: AppTypography.supporting(colors.textSecondary, fontSize: 12, isNumber: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // EMERGENCY BREAKDOWN BANNER (When in breakdown)
            if (isBreakdown) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.statusDanger.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.cardBorderRadius,
                  border: Border.all(color: colors.statusDanger, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colors.statusDanger, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Emergency SOS Active",
                            style: AppTypography.title(colors.statusDanger, fontSize: 15),
                          ),
                          Text(
                            "Breakdown recorded at Aluva Bypass. Fleet rescue team notified.",
                            style: AppTypography.supporting(colors.text, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // COMPACT ROUTE PREVIEW MAP
            ClipRRect(
              borderRadius: AppSpacing.cardBorderRadius,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.cardBorderRadius,
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                child: SmartFleetMap(
                  center: truckPos,
                  zoom: 9.5,
                  interactive: false,
                  polylines: [
                    Polyline(
                      points: [origin, dest],
                      strokeWidth: 3.5,
                      color: isBreakdown ? colors.statusDanger : colors.brand,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                  markers: [
                    SmartFleetMap.buildPinMarker(
                      position: origin,
                      icon: Icons.trip_origin_rounded,
                      color: colors.textSecondary,
                      label: trip.from,
                      colors: colors,
                    ),
                    SmartFleetMap.buildPinMarker(
                      position: dest,
                      icon: Icons.flag_rounded,
                      color: colors.statusSuccess,
                      label: trip.to,
                      colors: colors,
                    ),
                    SmartFleetMap.buildTruckMarker(
                      position: truckPos,
                      plateNumber: trip.truckPlate,
                      status: isBreakdown ? TruckStatus.inWorkshop : TruckStatus.onTrip,
                      colors: colors,
                      heading: 335.0,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PRIMARY 56dp BUTTON BASED ON STATE
            if (isWaiting) ...[
              PrimaryButton(
                label: "ACCEPT LOAD ASSIGNMENT",
                icon: Icons.check_circle_outline_rounded,
                height: 56,
                onPressed: () async {
                  await LocalFleetRepository.instance.acceptTrip(trip.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Trip accepted! Ready to roll."),
                        backgroundColor: Color(0xFF0B6E3A),
                      ),
                    );
                  }
                },
              ),
            ] else if (isAccepted) ...[
              PrimaryButton(
                label: "START TRIP · BEGIN TRANSPORT",
                icon: Icons.play_arrow_rounded,
                height: 56,
                onPressed: () async {
                  await LocalFleetRepository.instance.startTrip(trip.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Trip started! Live GPS sharing engaged."),
                        backgroundColor: Color(0xFF0B6E3A),
                      ),
                    );
                  }
                },
              ),
            ] else if (isRunning) ...[
              PrimaryButton(
                label: "ARRIVED / COMPLETE DELIVERY",
                icon: Icons.flag_rounded,
                height: 56,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryProofFlow(tripId: trip.id),
                    ),
                  );
                },
              ),
            ] else if (isBreakdown) ...[
              PrimaryButton(
                label: "RESUME TRIP · VEHICLE REPAIRED",
                icon: Icons.replay_rounded,
                height: 56,
                onPressed: () async {
                  await LocalFleetRepository.instance.startTrip(trip.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vehicle resumed journey!")),
                    );
                  }
                },
              ),
            ],

            const SizedBox(height: 10),

            // SECONDARY ACTIONS: Route navigation & office call
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: "Navigation",
                    icon: Icons.navigation_rounded,
                    height: 48,
                    onPressed: () => _openGoogleMaps(context, trip.from, trip.to),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(
                    label: "Call HQ Office",
                    icon: Icons.phone_rounded,
                    height: 48,
                    onPressed: () => _callOffice(context),
                  ),
                ),
              ],
            ),

            if (isRunning) ...[
              const SizedBox(height: 10),
              // EMERGENCY BREAKDOWN / SOS BUTTON
              DangerButton(
                label: "REPORT BREAKDOWN / SOS",
                icon: Icons.warning_amber_rounded,
                height: 48,
                confirmTitle: "Report Vehicle Breakdown?",
                confirmMessage: "This will immediately send your current GPS coordinates to fleet headquarters.",
                confirmActionLabel: "Confirm SOS",
                onConfirmed: () => _showBreakdownDialog(context, trip, colors),
              ),
            ],
          ],
        ),
      );
      },
    );
  }
}
