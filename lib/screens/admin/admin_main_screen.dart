import "../../core/services/update_service.dart";
import "package:flutter/material.dart";
import "../../core/design/tokens/app_colors.dart";
import "../../core/design/tokens/app_typography.dart";
import "../../l10n/app_localizations.dart";
import "../settings/settings_screen.dart";
import "create_trip_screen.dart";
import "tabs/admin_home_tab.dart";
import "tabs/admin_trips_tab.dart";
import "tabs/admin_fleet_tab.dart";
import "tabs/admin_drivers_tab.dart";

class AdminMainScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;

  const AdminMainScreen({super.key, this.onToggleLanguage});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          UpdateService.checkForUpdates(context);
        }
      });
    });
  }

  void _openCreateTrip(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(onToggleLanguage: widget.onToggleLanguage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    final tabs = [
      AdminHomeTab(
        onNewTrip: () => _openCreateTrip(context),
        onViewAllTrips: () => setState(() => _currentIndex = 1),
      ),
      const AdminTripsTab(),
      const AdminFleetTab(),
      const AdminDriversTab(),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.brand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.appTitle,
                style: AppTypography.title(colors.text, fontSize: 22),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.textSecondary, size: 22),
            tooltip: l10n.settingsTitle,
            onPressed: () => _openSettings(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: colors.border, height: 1.0),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border, width: 1.0)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: colors.surface,
          height: 64,
          indicatorColor: colors.brand.withValues(alpha: 0.16),
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.home_rounded, color: colors.brand, size: 22),
              label: l10n.tabHome,
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: colors.brand, size: 22),
              label: l10n.tabTrips,
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.local_shipping_rounded, color: colors.brand, size: 22),
              label: l10n.tabTrucks,
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.people_rounded, color: colors.brand, size: 22),
              label: "Drivers",
            ),
          ],
        ),
      ),
    );
  }
}
