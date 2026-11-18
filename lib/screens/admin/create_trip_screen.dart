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
  String? _selectedCargo;
  double? _selectedWeight;
  bool _isCustomCargo = false;
  bool _isCustomWeight = false;

  final _cargoController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedDriverId;

  bool _isSubmitting = false;

  static const List<String> _cargoPresetOptions = [
    "Industrial Steel Coils",
    "Cement Bags (50kg)",
    "Ceramic Floor Tiles",
    "FMCG Food Grains",
    "Petroleum & Lubricants",
    "Automotive Spare Parts",
    "Electronics & Appliances",
    "Timber & Plywood",
    "Agricultural Produce",
    "General Commercial Cargo",
    "Custom Cargo...",
  ];

  static final Map<double, String> _tonnagePresetOptions = {
    5.0: "5.0 Tons (Light Commercial)",
    10.0: "10.0 Tons (Medium Duty)",
    15.0: "15.0 Tons (Standard 6-Wheeler)",
    20.0: "20.0 Tons (Heavy 10-Wheeler)",
    24.5: "24.5 Tons (NH-66 Container)",
    28.0: "28.0 Tons (Multi-Axle Tipper)",
    32.0: "32.0 Tons (Heavy Duty Trailer)",
    35.0: "35.0 Tons (Heavy Bulk Hauler)",
    40.0: "40.0 Tons (Oversize Prime Mover)",
    -1.0: "Custom Weight...",
  };

  @override
  void initState() {
    super.initState();
    _selectedCargo = _cargoPresetOptions.first;
    _cargoController.text = _selectedCargo!;
    _selectedWeight = 24.5;
    _weightController.text = "24.5";
  }

  @override
  void dispose() {
    _cargoController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onCargoSelected(String? val) {
    if (val == null) return;
    setState(() {
      _selectedCargo = val;
      if (val == "Custom Cargo...") {
        _isCustomCargo = true;
        _cargoController.clear();
      } else {
        _isCustomCargo = false;
        _cargoController.text = val;
      }
    });
  }

  void _onWeightSelected(double? val) {
    if (val == null) return;
    setState(() {
      _selectedWeight = val;
      if (val == -1.0) {
        _isCustomWeight = true;
        _weightController.clear();
      } else {
        _isCustomWeight = false;
        _weightController.text = val.toStringAsFixed(1);
      }
    });
  }

  void _onConfirmAndSubmit(AppLocalizations l10n, List<Driver> drivers) async {
    if (!_formKey.currentState!.validate()) return;

    final driver = drivers.firstWhere((d) => d.id == _selectedDriverId);
    final colors = context.colors;
    final cargoText = _cargoController.text.trim();
    final weightText = _weightController.text.trim();

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
            style: AppTypography.title(colors.text, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.confirmTripSubtitle,
                style: AppTypography.supporting(colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_selectedFrom ➔ $_selectedTo",
                      style: AppTypography.section(colors.brand, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Cargo: $cargoText ($weightText Tons)",
                      style: AppTypography.body(colors.text, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Driver: ${driver.name} · ${driver.assignedTruckPlate}",
                      style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.btnCancel,
                style: AppTypography.button(colors.textSecondary, fontSize: 14),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.buttonBorderRadius),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.btnConfirmAndSend, style: AppTypography.button(colors.onBrand, fontSize: 14)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        final weight = double.tryParse(weightText) ?? 10.0;
        await LocalFleetRepository.instance.createTrip(
          from: _selectedFrom!,
          to: _selectedTo!,
          cargo: cargoText,
          weightTons: weight,
          driverId: _selectedDriverId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trip dispatched to driver!"),
              backgroundColor: Color(0xFFC6FF00),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Trip creation failed: $e"),
              backgroundColor: colors.statusDanger,
            ),
          );
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
          style: AppTypography.title(colors.text, fontSize: 18),
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
                Text(l10n.fromPlace, style: AppTypography.section(colors.text, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedFrom,
                  hint: Text(l10n.selectPlace, style: AppTypography.body(colors.textSecondary, fontSize: 14)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.trip_origin_rounded, color: colors.brand, size: 20),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: places.map((p) => DropdownMenuItem(value: p, child: Text(p, style: AppTypography.body(colors.text, fontSize: 14)))).toList(),
                  onChanged: (val) => setState(() => _selectedFrom = val),
                  validator: (val) => val == null ? l10n.errFromRequired : null,
                ),

                const SizedBox(height: 18),

                // 2. DESTINATION PICKER
                Text(l10n.toPlace, style: AppTypography.section(colors.text, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedTo,
                  hint: Text(l10n.selectPlace, style: AppTypography.body(colors.textSecondary, fontSize: 14)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on_rounded, color: colors.statusDanger, size: 20),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: places.map((p) => DropdownMenuItem(value: p, child: Text(p, style: AppTypography.body(colors.text, fontSize: 14)))).toList(),
                  onChanged: (val) => setState(() => _selectedTo = val),
                  validator: (val) {
                    if (val == null) return l10n.errToRequired;
                    if (val == _selectedFrom) return l10n.errSamePlace;
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // 3. CARGO DESCRIPTION (DROP-DOWN + OPTIONAL CUSTOM)
                Text("CARGO DESCRIPTION", style: AppTypography.section(colors.text, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedCargo,
                  hint: Text("Select cargo category", style: AppTypography.body(colors.textSecondary, fontSize: 14)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined, color: colors.brand, size: 20),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: _cargoPresetOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTypography.body(colors.text, fontSize: 14)))).toList(),
                  onChanged: _onCargoSelected,
                ),

                if (_isCustomCargo) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cargoController,
                    decoration: InputDecoration(
                      hintText: "Enter custom cargo description",
                      hintStyle: AppTypography.body(colors.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: colors.brand, size: 20),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.buttonBorderRadius,
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                    style: AppTypography.body(colors.text, fontSize: 14),
                    validator: (val) => val == null || val.trim().isEmpty ? l10n.errCargoRequired : null,
                  ),
                ],

                const SizedBox(height: 18),

                // 4. CARGO TONNAGE (DROP-DOWN + OPTIONAL CUSTOM)
                Text("CARGO WEIGHT (TONS)", style: AppTypography.section(colors.text, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<double>(
                  isExpanded: true,
                  value: _selectedWeight,
                  hint: Text("Select tonnage rating", style: AppTypography.body(colors.textSecondary, fontSize: 14)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.scale_rounded, color: colors.brand, size: 20),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: _tonnagePresetOptions.entries.map((e) {
                    return DropdownMenuItem<double>(
                      value: e.key,
                      child: Text(e.value, style: AppTypography.body(colors.text, fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: _onWeightSelected,
                ),

                if (_isCustomWeight) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: "Enter custom weight in tons (e.g. 26.5)",
                      hintStyle: AppTypography.body(colors.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_rounded, color: colors.brand, size: 20),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.buttonBorderRadius,
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                    style: AppTypography.body(colors.text, fontSize: 14),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l10n.errWeightRequired;
                      final n = double.tryParse(val.trim());
                      if (n == null || n <= 0) return l10n.errWeightRequired;
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 18),

                // 5. ASSIGN DRIVER
                Text(l10n.assignDriverLabel, style: AppTypography.section(colors.text, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedDriverId,
                  hint: Text(
                    drivers.isEmpty ? "Loading active drivers..." : l10n.selectDriverHint,
                    style: AppTypography.body(colors.textSecondary, fontSize: 14),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded, color: colors.brand, size: 20),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.buttonBorderRadius,
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  items: drivers.map((d) {
                    final plate = d.assignedTruckPlate.isNotEmpty ? " · ${d.assignedTruckPlate}" : "";
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        "${d.name}$plate",
                        style: AppTypography.body(colors.text, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDriverId = val),
                  validator: (val) => val == null ? l10n.errDriverRequired : null,
                ),

                const SizedBox(height: 28),

                // SUBMIT BUTTON (56dp)
                PrimaryButton(
                  label: l10n.btnSendToDriver,
                  icon: Icons.send_rounded,
                  isLoading: _isSubmitting,
                  height: 52,
                  onPressed: drivers.isEmpty ? null : () => _onConfirmAndSubmit(l10n, drivers),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
