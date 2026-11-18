import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/components/status_chip.dart';
import '../../core/design/components/status_headline.dart';
import '../../core/design/components/live_badge.dart';
import '../../core/design/components/tracking_timeline.dart';
import '../../core/design/components/buttons.dart';
import '../../core/data/models/trip.dart';
import '../../core/data/models/driver.dart';
import '../../core/data/models/truck.dart';
import '../../core/data/seed_data.dart';
import '../../core/data/fleet_repository.dart';
import '../../core/maps/smart_fleet_map.dart';
import '../../core/maps/kerala_locations.dart';
import '../../core/maps/osrm_routing_service.dart';
import '../../core/maps/marker_interpolator.dart';
import '../../l10n/app_localizations.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  RouteResult? _routeResult;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final trips = await LocalFleetRepository.instance.getTrips();
    final tripList = trips.where((t) => t.id == widget.tripId).toList();
    if (tripList.isNotEmpty) {
      final trip = tripList.first;
      final origin = KeralaLocations.resolve(trip.from);
      final dest = KeralaLocations.resolve(trip.to);
      final result = await OsrmRoutingService.instance.getRoute(origin: origin, destination: dest);
      if (mounted) {
        setState(() {
          _routeResult = result;
        });
      }
    }
  }

  void _callDriver(BuildContext context, String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Calling $phone...")),
    );
  }

  void _shareOnWhatsApp(BuildContext context, Trip trip, String driverName) {
    final eta = trip.estimatedArrival;
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    final pct = (trip.progressPercent * 100).toInt();
    final text = 'SmartFleet: Trip ${trip.id} (${trip.from} to ${trip.to}). Driver: $driverName. Status: ${trip.status.name.toUpperCase()} ($pct% completed). ETA: $h:$m. Tracking link: https://smartfleet.app/t/${trip.id} [link feature not built yet]';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing via WhatsApp: $text'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          widget.tripId,
          style: AppTypography.title(colors.text, isNumber: true),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: colors.border, height: 1.0),
        ),
      ),
      body: StreamBuilder<List<Trip>>(
        stream: LocalFleetRepository.instance.watchTrips(),
        builder: (context, snapshot) {
          final allTrips = snapshot.data ?? [];
          final tripList = allTrips.where((t) => t.id == widget.tripId).toList();
          if (tripList.isEmpty) {
            return const Center(child: Text("Trip not found"));
          }
          final trip = tripList.first;

          return FutureBuilder<List<Driver>>(
            future: LocalFleetRepository.instance.getDrivers(),
            builder: (context, driverSnap) {
              final drivers = driverSnap.data ?? [];
              final driver = drivers.firstWhere(
                (d) => d.id == trip.driverId,
                orElse: () => SeedData.drivers.first,
              );

              ChipStatusType statusType;
              String statusLabel;
              switch (trip.status) {
                case TripStatus.waiting:
                  statusType = ChipStatusType.waiting;
                  statusLabel = l10n.statusWaiting;
                  break;
                case TripStatus.accepted:
                case TripStatus.running:
                  statusType = ChipStatusType.running;
                  statusLabel = l10n.statusRunning;
                  break;
                case TripStatus.delivered:
                  statusType = ChipStatusType.success;
                  statusLabel = l10n.statusDelivered;
                  break;
                case TripStatus.breakdown:
                case TripStatus.failed:
                  statusType = ChipStatusType.danger;
                  statusLabel = trip.status == TripStatus.breakdown ? "Breakdown" : "Failed";
                  break;
              }

              final origin = KeralaLocations.resolve(trip.from);
              final dest = KeralaLocations.resolve(trip.to);
              final truckPos = MarkerInterpolator.interpolateLatLng(origin, dest, trip.progressPercent);

              final markers = [
                SmartFleetMap.buildPinMarker(
                  position: origin,
                  icon: Icons.trip_origin_rounded,
                  color: colors.brand,
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
                  status: trip.status == TripStatus.delivered ? TruckStatus.available : TruckStatus.onTrip,
                  colors: colors,
                  heading: 335.0,
                ),
              ];

              final polylines = _routeResult != null
                  ? [
                      Polyline(
                        points: _routeResult!.points,
                        strokeWidth: 5.5,
                        color: colors.brand,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ]
                  : [
                      Polyline(
                        points: [origin, dest],
                        strokeWidth: 3.0,
                        color: colors.brand.withValues(alpha: 0.5),
                        strokeCap: StrokeCap.round,
                      ),
                    ];

              final arrivalTime = "${trip.estimatedArrival.hour.toString().padLeft(2, '0')}:${trip.estimatedArrival.minute.toString().padLeft(2, '0')}";

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // STATUS HEADLINE
                  StatusHeadline(
                    headline: trip.status == TripStatus.delivered
                        ? "Cargo Delivered Successfully"
                        : (trip.status == TripStatus.running
                            ? "Arriving by $arrivalTime"
                            : "Awaiting Driver Confirmation"),
                    subtitle: "${trip.from} ➔ ${trip.to} · ${(trip.progressPercent * 100).toInt()}% completed",
                  ),
                  const SizedBox(height: 12),

                  // LIVE BADGE & TRUCK PLATE ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: LiveBadge(
                          status: trip.status == TripStatus.running ? LiveStatus.live : LiveStatus.offline,
                          label: trip.status == TripStatus.running ? "Live GPS · Updated 12s ago" : "Stationary",
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChipV2(label: statusLabel, icon: Icons.local_shipping_rounded, type: statusType),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // MAP VIEW (Interactive road route + markers)
                  ClipRRect(
                    borderRadius: AppSpacing.cardBorderRadius,
                    child: Container(
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: AppSpacing.cardBorderRadius,
                        border: Border.all(color: colors.border, width: 1.5),
                      ),
                      child: SmartFleetMap(
                        center: truckPos,
                        zoom: 9.0,
                        polylines: polylines,
                        markers: markers,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TRACKING TIMELINE (Vertical, timestamps, current step pulses)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Shipment Journey", style: AppTypography.heading(colors.text)),
                          const SizedBox(height: 16),
                          TrackingTimeline(
                            steps: [
                              TimelineStepData(
                                title: "Trip Dispatched",
                                subtitle: "${trip.from} · Assigned to ${driver.name}",
                                timestamp: "08:30 AM",
                                isCompleted: trip.status != TripStatus.waiting,
                                isCurrent: trip.status == TripStatus.waiting,
                              ),
                              TimelineStepData(
                                title: "Cargo Loaded & Started",
                                subtitle: "${trip.cargo} (${trip.weightTons}T)",
                                timestamp: "09:15 AM",
                                isCompleted: trip.status == TripStatus.running || trip.status == TripStatus.delivered,
                                isCurrent: trip.status == TripStatus.accepted,
                              ),
                              TimelineStepData(
                                title: "In Transit on NH-66",
                                subtitle: "${trip.distanceDoneKm.toStringAsFixed(1)} km of ${trip.distanceKm.toStringAsFixed(0)} km",
                                timestamp: "01:45 PM",
                                isCompleted: trip.status == TripStatus.delivered,
                                isCurrent: trip.status == TripStatus.running,
                              ),
                              TimelineStepData(
                                title: "Destination Arrival",
                                subtitle: "${trip.to} · Proof of Delivery (POD)",
                                timestamp: trip.status == TripStatus.delivered ? "04:30 PM" : "ETA $arrivalTime",
                                isCompleted: trip.status == TripStatus.delivered,
                                isCurrent: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // DRIVER CARD (Singular Driver label, call button)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Driver", style: AppTypography.heading(colors.text)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: colors.brand.withValues(alpha: 0.15),
                                child: Icon(Icons.person_rounded, color: colors.brand, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(driver.name, style: AppTypography.heading(colors.text)),
                                    Text(driver.phone, style: AppTypography.body(colors.textSecondary, isNumber: true)),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.phone_rounded),
                                onPressed: () => _callDriver(context, driver.phone),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // WHATSAPP SHARE BUTTON
                  SecondaryButton(
                    label: "Share Tracking on WhatsApp",
                    icon: Icons.share_rounded,
                    onPressed: () => _shareOnWhatsApp(context, trip, driver.name),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
