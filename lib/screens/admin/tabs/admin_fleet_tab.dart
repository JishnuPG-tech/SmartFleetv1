import "../../../core/design/components/empty_state.dart";
import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "../../../core/design/tokens/app_colors.dart";
import "../../../core/design/tokens/app_typography.dart";
import "../../../core/design/tokens/app_spacing.dart";
import "../../../core/design/components/truck_card.dart";
import "../../../core/design/components/status_chip.dart";
import "../../../core/data/models/truck.dart";
import "../../../core/data/models/trip.dart";
import "../../../core/data/models/driver.dart";
import "../../../core/data/fleet_repository.dart";
import "../../../core/maps/smart_fleet_map.dart";
import "../../../l10n/app_localizations.dart";

class AdminFleetTab extends StatefulWidget {
  const AdminFleetTab({super.key});

  @override
  State<AdminFleetTab> createState() => _AdminFleetTabState();
}

class _AdminFleetTabState extends State<AdminFleetTab> {
  bool _isMapView = false;
  Truck? _selectedTruck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<Trip>>(
      stream: LocalFleetRepository.instance.watchTrips(),
      builder: (context, tripSnap) {
        return StreamBuilder<List<Driver>>(
          stream: LocalFleetRepository.instance.watchDrivers(),
          builder: (context, driverSnap) {
            return StreamBuilder<List<Truck>>(
              stream: LocalFleetRepository.instance.watchTrucks(),
              builder: (context, truckSnap) {
                final trucks = truckSnap.data ?? [];
                final trips = tripSnap.data ?? [];
                final drivers = driverSnap.data ?? [];

                final driverMap = {for (final d in drivers) d.id: d.name};

                // Active trips reserve the truck
                final activeTruckPlates = trips
                    .where((t) => t.status != TripStatus.delivered)
                    .map((t) => t.truckPlate)
                    .toSet();

                return Column(
                  children: [
                    // TOP BAR: LIST / MAP TOGGLE & TOTAL STAT
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(bottom: BorderSide(color: colors.border, width: 1.0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${trucks.length} Trucks",
                              style: AppTypography.section(colors.text, fontSize: 16, isNumber: true),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(Icons.view_list_rounded, size: 16),
                                label: Text("List"),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(Icons.map_rounded, size: 16),
                                label: Text("Map"),
                              ),
                            ],
                            selected: {_isMapView},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _isMapView = newSelection.first;
                                _selectedTruck = null;
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              textStyle: WidgetStatePropertyAll(AppTypography.supporting(colors.text, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // BODY CONTENT: LIST VIEW OR FULL MAP
                    Expanded(
                      child: _isMapView
                          ? Stack(
                              children: [
                                SmartFleetMap(
                                  center: const LatLng(10.5276, 76.2144),
                                  zoom: 7.8,
                                  markers: trucks.map((truck) {
                                    final effectiveStatus = truck.status == TruckStatus.inWorkshop
                                        ? TruckStatus.inWorkshop
                                        : (activeTruckPlates.contains(truck.plate)
                                            ? TruckStatus.onTrip
                                            : TruckStatus.available);

                                    return SmartFleetMap.buildTruckMarker(
                                      position: truck.position,
                                      plateNumber: truck.plate,
                                      status: effectiveStatus,
                                      colors: colors,
                                      heading: truck.heading,
                                      onTap: () {
                                        setState(() => _selectedTruck = truck);
                                      },
                                    );
                                  }).toList(),
                                  onTap: (_, _) {
                                    if (_selectedTruck != null) {
                                      setState(() => _selectedTruck = null);
                                    }
                                  },
                                ),

                                // SELECTED TRUCK CARD POPUP
                                if (_selectedTruck != null)
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: AppSpacing.cardBorderRadius,
                                        border: Border.all(color: colors.border, width: 1.0),
                                        boxShadow: AppSpacing.lightCardShadow,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _selectedTruck!.plate,
                                                  style: AppTypography.section(colors.text, fontSize: 16, isNumber: true),
                                                ),
                                              ),
                                              if (_selectedTruck!.status == TruckStatus.inWorkshop)
                                                StatusChipV2.danger(label: l10n.statusInWorkshop)
                                              else if (activeTruckPlates.contains(_selectedTruck!.plate))
                                                StatusChipV2.running(label: l10n.statusRunning)
                                              else
                                                StatusChipV2.success(label: l10n.statusAvailable),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => setState(() => _selectedTruck = null),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${_selectedTruck!.model} · ${_selectedTruck!.capacityTons.toStringAsFixed(0)}T",
                                            style: AppTypography.supporting(colors.textSecondary, fontSize: 13),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.person_rounded, size: 16, color: colors.brand),
                                              const SizedBox(width: 6),
                                              Text(
                                                driverMap[_selectedTruck!.assignedDriverId] ?? "Unassigned",
                                                style: AppTypography.supporting(colors.text, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : (trucks.isEmpty
                              ? const EmptyState(
                                  icon: Icons.local_shipping_outlined,
                                  title: "No Trucks in Fleet Database",
                                  subtitle: "Add commercial haulage trucks via the Web Admin Dashboard or backend database.",
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                  itemCount: trucks.length,
                                  itemBuilder: (context, index) {
                                    final truck = trucks[index];
                                    final driverName = driverMap[truck.assignedDriverId];

                                    TruckStatusType effectiveStatus;
                                    if (truck.status == TruckStatus.inWorkshop) {
                                      effectiveStatus = TruckStatusType.inWorkshop;
                                    } else if (activeTruckPlates.contains(truck.plate) || truck.status == TruckStatus.onTrip) {
                                      effectiveStatus = TruckStatusType.onTrip;
                                    } else {
                                      effectiveStatus = TruckStatusType.available;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: TruckCard(
                                        plate: truck.plate,
                                        model: truck.model,
                                        capacityTons: truck.capacityTons.toDouble(),
                                        status: effectiveStatus,
                                        driverName: driverName,
                                      ),
                                    );
                                  },
                                )),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
