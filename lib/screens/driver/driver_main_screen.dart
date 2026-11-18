import "../../core/services/update_service.dart";
import "package:flutter/material.dart";
import "../../core/design/tokens/app_colors.dart";
import "../../core/design/tokens/app_typography.dart";
import "../../core/data/models/driver.dart";
import "../../core/data/seed_data.dart";
import "../../l10n/app_localizations.dart";
import "../settings/settings_screen.dart";
import "tabs/driver_trip_tab.dart";
import "tabs/driver_earnings_tab.dart";
import "tabs/driver_profile_tab.dart";

class DriverMainScreen extends StatefulWidget {
  final Driver? driver;
  final VoidCallback? onToggleLanguage;

  const DriverMainScreen({
    super.key,
    this.driver,
    this.onToggleLanguage,
  });

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
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
    final driver = widget.driver ?? SeedData.drivers.first;

    final tabs = [
      DriverTripTab(driver: driver),
      DriverEarningsTab(driverId: driver.id),
      DriverProfileTab(
        driver: driver,
        onToggleLanguage: widget.onToggleLanguage,
      ),
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
            Text(
              l10n.appTitle,
              style: AppTypography.title(colors.text, fontSize: 22),
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
              icon: Icon(Icons.navigation_outlined, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.navigation_rounded, color: colors.brand, size: 22),
              label: l10n.tabTrip,
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: colors.brand, size: 22),
              label: l10n.tabEarnings,
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: colors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.person_rounded, color: colors.brand, size: 22),
              label: l10n.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
