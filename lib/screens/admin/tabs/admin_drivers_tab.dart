import "../../../core/design/components/empty_state.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/design/components/driver_card.dart";
import "../../../core/data/models/driver.dart";
import "../../../core/data/fleet_repository.dart";

class AdminDriversTab extends StatelessWidget {
  const AdminDriversTab({super.key});

  Future<void> _callDriver(BuildContext context, String name, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r"[^0-9+]"), "");
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid phone number")),
      );
      return;
    }
    final uri = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Cannot place call to $phone")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Call failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Driver>>(
      stream: LocalFleetRepository.instance.watchDrivers(),
      builder: (context, snapshot) {
        final drivers = snapshot.data ?? [];

        if (drivers.isEmpty) {
          return const EmptyState(
            icon: Icons.person_outline_rounded,
            title: "No Registered Drivers",
            subtitle: "Drivers who onboard via mobile app or the Web Admin Dashboard will appear here.",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DriverCard(
                name: driver.name,
                phone: driver.phone,
                licenceNumber: driver.licenceNumber,
                isLicencePlaceholder: driver.isLicencePlaceholder,
                experienceYears: driver.experienceYears,
                assignedTruckPlate: driver.assignedTruckPlate,
                onCall: () => _callDriver(context, driver.name, driver.phone),
              ),
            );
          },
        );
      },
    );
  }
}
