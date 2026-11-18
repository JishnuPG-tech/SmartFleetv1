import "package:flutter/material.dart";
import "../../core/design/tokens/app_colors.dart";
import "../../core/design/tokens/app_typography.dart";
import "../../core/design/components/buttons.dart";
import "../../core/data/api_client.dart";
import "../../core/data/fleet_repository.dart";
import "../../core/data/models/driver.dart";
import "../driver/driver_main_screen.dart";

class DriverRegisterScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;

  const DriverRegisterScreen({super.key, this.onToggleLanguage});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _nameController = TextEditingController(text: "Rajesh Varma");
  final _phoneController = TextEditingController(text: "+91 94471 89201");
  final _licenseController = TextEditingController(text: "KL-07-2015-0082910");
  final _plateController = TextEditingController(text: "KL 07 CD 4589");
  final _expController = TextEditingController(text: "8");
  final _passwordController = TextEditingController(text: "pilot1234");

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _plateController.dispose();
    _expController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final license = _licenseController.text.trim();
    final plate = _plateController.text.trim();
    final expYears = int.tryParse(_expController.text.trim()) ?? 3;
    final password = _passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || license.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please fill in all mandatory fields.";
      });
      return;
    }

    final result = await ApiClient.instance.driverRegister(
      fullName: name,
      phone: phone,
      password: password,
      licenseNumber: license,
      experienceYears: expYears,
      assignedTruckPlate: plate.isNotEmpty ? plate : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      final driver = result.driver ?? Driver(
        id: result.userId ?? 'new-driver',
        name: name,
        phone: phone,
        licenceNumber: license,
        assignedTruckPlate: plate.isNotEmpty ? plate : 'KL 07 CD 4589',
        experienceYears: expYears,
      );

      LocalFleetRepository.instance.addOrUpdateDriver(driver);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DriverMainScreen(
            driver: driver,
            onToggleLanguage: widget.onToggleLanguage,
          ),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome $name! Commercial cockpit initialized.'),
        ),
      );
    } else {
      if (result.errorMessage != null && result.errorMessage!.contains("already registered")) {
        setState(() => _errorMessage = result.errorMessage);
      } else {
        final localDriver = Driver(
          id: 'driver-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          phone: phone,
          licenceNumber: license,
          assignedTruckPlate: plate.isNotEmpty ? plate : 'KL 07 CD 4589',
          experienceYears: expYears,
        );
        LocalFleetRepository.instance.addOrUpdateDriver(localDriver);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DriverMainScreen(
              driver: localDriver,
              onToggleLanguage: widget.onToggleLanguage,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMalayalam = Localizations.localeOf(context).languageCode == "ml";

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isMalayalam ? "ഡ്രൈവർ രജിസ്ട്രേഷൻ" : "Driver Pilot Onboarding",
          style: AppTypography.title(colors.text, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: colors.brand, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMalayalam ? "കേരള MVD വെരിഫിക്കേഷൻ" : "Govt Sarathi HMV Compliance",
                          style: AppTypography.section(colors.text, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMalayalam
                              ? "വാഹന ലൈസൻസ് വിവരങ്ങൾ ഡാറ്റാബേസിൽ സുരക്ഷിതമായി സൂക്ഷിക്കുന്നു."
                              : "Commercial vehicle credentials synced with Supabase & live fleet registry.",
                          style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.statusDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.statusDanger),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.supporting(colors.statusDanger, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 20),

            _buildField(
              context,
              isMalayalam ? "പൂർണ്ണ പേര്" : "FULL PILOT NAME",
              _nameController,
              Icons.person_rounded,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              isMalayalam ? "മൊബൈൽ നമ്പർ" : "REGISTERED MOBILE (FOR SMS/OTP)",
              _phoneController,
              Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              isMalayalam ? "ഡ്രൈവിംഗ് ലൈസൻസ് നമ്പർ (HMV)" : "HMV DRIVING LICENCE",
              _licenseController,
              Icons.badge_rounded,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              isMalayalam ? "അനുവദിച്ച ലോറി നമ്പർ" : "ASSIGNED TRUCK REGISTRATION (PLATE)",
              _plateController,
              Icons.local_shipping_rounded,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              isMalayalam ? "പരിചയസമ്പത്ത് (വർഷങ്ങൾ)" : "YEARS OF HEAVY VEHICLE EXPERIENCE",
              _expController,
              Icons.timeline_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildField(
              context,
              isMalayalam ? "സുരക്ഷാ പിൻ / പാസ്‌വേഡ്" : "SECURITY PIN / PASSWORD",
              _passwordController,
              Icons.lock_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: isMalayalam ? "രജിസ്ട്രേഷൻ പൂർത്തിയാക്കുക" : "COMPLETE REGISTRATION & ENTER COCKPIT",
              icon: Icons.check_circle_rounded,
              isLoading: _isLoading,
              onPressed: _handleRegister,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label(colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border, width: 1.0),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: AppTypography.body(colors.text, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
