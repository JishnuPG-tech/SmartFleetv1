import "package:flutter/material.dart";
import "../../core/design/tokens/app_colors.dart";
import "../../core/design/tokens/app_typography.dart";
import "../../core/design/tokens/app_spacing.dart";
import "../../core/design/components/buttons.dart";
import "../../core/data/models/driver.dart";
import "../../core/data/seed_data.dart";
import "../../core/data/fleet_repository.dart";
import "../../l10n/app_localizations.dart";

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedFrom;
  String? _selectedTo;
  final _cargoController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedDriverId;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _cargoController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onConfirmAndSubmit(AppLocalizations l10n, List<Driver> drivers) async {
    if (!_formKey.currentState!.validate()) return;

    final driver = drivers.firstWhere((d) => d.id == _selectedDriverId);
    final colors = context.colors;

    // Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.cardBorderRadius,
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            l10n.confirmTripTitle,
            style: AppTypography.title(colors.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.confirmTripSubtitle,
                style: AppTypography.body(colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                "$_selectedFrom ➔ $_selectedTo",
                style: AppTypography.heading(colors.brand),
              ),
              const SizedBox(height: 8),
              Text(
                "Cargo: ${_cargoController.text.trim()} (${_weightController.text.trim()} Tons)",
                style: AppTypography.body(colors.text),
              ),
              const SizedBox(height: 8),
              Text(
                "Driver: ${driver.name} · ${driver.assignedTruckPlate}",
                style: AppTypography.body(colors.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.btnCancel,
                style: AppTypography.heading(colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.buttonBorderRadius),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.btnConfirmAndSend, style: AppTypography.heading(colors.onBrand)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        final weight = double.tryParse(_weightController.text.trim()) ?? 10.0;
        await LocalFleetRepository.instance.createTrip(
          from: _selectedFrom!,
          to: _selectedTo!,
          cargo: _cargoController.text.trim(),
          weightTons: weight,
          driverId: _selectedDriverId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trip created and dispatched to driver!"),
              backgroundColor: Color(0xFF0B6E3A),
            ),
          );
          Navigator.pop(context);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final places = SeedData.places;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          l10n.newTripTitle,
          style: AppTypography.title(colors.text),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: colors.border, height: 1.0),
        ),
      ),
      body: StreamBuilder<List<Driver>>(
        stream: LocalFleetRepository.instance.watchDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? [];

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // 1. ORIGIN PICKER
                Text(l10n.fromPlace, style: AppTypography.heading(colors.text)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedFrom,
                  hint: Text(l10n.selectPlace, style: AppTypography.body(colors.textSecondary)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.trip_origin_rounded, color: colors.brand),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: places.map((p) => DropdownMenuItem(value: p, child: Text(p, style: AppTypography.body(colors.text)))).toList(),
                  onChanged: (val) => setState(() => _selectedFrom = val),
                  validator: (val) => val == null ? l10n.errFromRequired : null,
                ),

                const SizedBox(height: 20),

                // 2. DESTINATION PICKER
                Text(l10n.toPlace, style: AppTypography.heading(colors.text)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedTo,
                  hint: Text(l10n.selectPlace, style: AppTypography.body(colors.textSecondary)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on_rounded, color: colors.statusDanger),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: places.map((p) => DropdownMenuItem(value: p, child: Text(p, style: AppTypography.body(colors.text)))).toList(),
                  onChanged: (val) => setState(() => _selectedTo = val),
                  validator: (val) {
                    if (val == null) return l10n.errToRequired;
                    if (val == _selectedFrom) return l10n.errSamePlace;
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // 3. CARGO & WEIGHT
                Text(l10n.cargoTitleLabel, style: AppTypography.heading(colors.text)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cargoController,
                  decoration: InputDecoration(
                    hintText: "e.g. Industrial Steel Coils",
                    hintStyle: AppTypography.body(colors.textSecondary),
                    prefixIcon: Icon(Icons.inventory_2_outlined, color: colors.brand),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  style: AppTypography.body(colors.text),
                  validator: (val) => val == null || val.trim().isEmpty ? l10n.errCargoRequired : null,
                ),

                const SizedBox(height: 20),

                Text(l10n.cargoWeightLabel, style: AppTypography.heading(colors.text)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: "e.g. 24.5",
                    hintStyle: AppTypography.body(colors.textSecondary),
                    prefixIcon: Icon(Icons.scale_rounded, color: colors.brand),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  style: AppTypography.body(colors.text),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return l10n.errWeightRequired;
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) return l10n.errWeightRequired;
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // 4. ASSIGN DRIVER
                Text(l10n.assignDriverLabel, style: AppTypography.heading(colors.text)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedDriverId,
                  hint: Text(l10n.selectDriverHint, style: AppTypography.body(colors.textSecondary)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded, color: colors.brand),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: drivers.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text("${d.name} (${d.assignedTruckPlate})", style: AppTypography.body(colors.text)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDriverId = val),
                  validator: (val) => val == null ? l10n.errDriverRequired : null,
                ),

                const SizedBox(height: 32),

                // SUBMIT BUTTON (56dp)
                PrimaryButton(
                  label: l10n.btnSendToDriver,
                  icon: Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: () => _onConfirmAndSubmit(l10n, drivers),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
