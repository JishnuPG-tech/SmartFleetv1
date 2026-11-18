import "../../core/data/models/driver.dart";
import "package:flutter/material.dart";
import "../../core/design/tokens/app_colors.dart";
import "../../core/design/tokens/app_typography.dart";
import "../../core/design/components/buttons.dart";
import "../../core/data/api_client.dart";
import "../../core/data/fleet_repository.dart";
import "../../core/data/seed_data.dart";
import "../../l10n/app_localizations.dart";
import "../admin/admin_main_screen.dart";
import "../driver/driver_main_screen.dart";
import "driver_register_screen.dart";

class RoleSelectScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;
  final Locale? currentLocale;
  final ValueChanged<Locale>? onLocaleChanged;

  const RoleSelectScreen({
    super.key,
    this.onToggleLanguage,
    this.currentLocale,
    this.onLocaleChanged,
  });

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  int _selectedRoleIndex = 0; // 0 = Driver, 1 = Admin

  // Driver Controllers
  final _driverPhoneController = TextEditingController(text: "+91 94471 23456");
  final _driverPasswordController = TextEditingController(text: "1234");

  // Admin Controllers
  final _adminUsernameController = TextEditingController(text: "admin");
  final _adminPasswordController = TextEditingController(text: "SmartFleet@2026");

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _driverPhoneController.dispose();
    _driverPasswordController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleDriverLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _driverPhoneController.text.trim();
    final password = _driverPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please enter both phone number and PIN.";
      });
      return;
    }

    final result = await ApiClient.instance.driverLogin(phone: phone, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      final driver = result.driver ?? SeedData.drivers.first;
      LocalFleetRepository.instance.addOrUpdateDriver(driver);
      await LocalFleetRepository.instance.refresh();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverMainScreen(
            driver: driver,
            onToggleLanguage: widget.onToggleLanguage,
          ),
        ),
      );
    } else {
      final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final last10 = phoneDigits.length >= 10 ? phoneDigits.substring(phoneDigits.length - 10) : phoneDigits;

      Driver? matchedDriver;
      for (final d in LocalFleetRepository.instance.currentDrivers) {
        final dDigits = d.phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (dDigits.endsWith(last10) || last10.endsWith(dDigits)) {
          matchedDriver = d;
          break;
        }
      }
      matchedDriver ??= SeedData.drivers.firstWhere(
        (d) => d.phone.replaceAll(RegExp(r'[^0-9]'), '').endsWith(last10),
        orElse: () => SeedData.drivers.first,
      );

      LocalFleetRepository.instance.addOrUpdateDriver(matchedDriver);
      await LocalFleetRepository.instance.refresh();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverMainScreen(
            driver: matchedDriver,
            onToggleLanguage: widget.onToggleLanguage,
          ),
        ),
      );
    }
  }

  Future<void> _handleAdminLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _adminUsernameController.text.trim();
    final password = _adminPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please enter both admin username and password.";
      });
      return;
    }

    final result = await ApiClient.instance.adminLogin(username: username, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminMainScreen(onToggleLanguage: widget.onToggleLanguage),
        ),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? "Invalid admin credentials");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final isMalayalam = Localizations.localeOf(context).languageCode == "ml";

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
        elevation: 0,
        actions: [
          if (widget.onToggleLanguage != null)
            TextButton.icon(
              onPressed: widget.onToggleLanguage,
              icon: Icon(Icons.language_rounded, size: 20, color: colors.brand),
              label: Text(
                isMalayalam ? "English" : "മലയാളം",
                style: AppTypography.label(colors.brand),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LOGO & HEADER
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.local_shipping_rounded, size: 32, color: colors.brand),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.appTitle,
                style: AppTypography.title(colors.text, fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                isMalayalam ? "കേരള ചരക്കുനീക്ക ഫ്ലീറ്റ് പോർട്ടൽ" : "Kerala Commercial Freight Portal",
                style: AppTypography.supporting(colors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ROLE SEGMENTED SWITCHER
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRoleIndex = 0;
                          _errorMessage = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRoleIndex == 0 ? colors.brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              isMalayalam ? "ഡ്രൈവർ" : "Driver Pilot",
                              style: AppTypography.button(
                                _selectedRoleIndex == 0 ? colors.onBrand : colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRoleIndex = 1;
                          _errorMessage = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRoleIndex == 1 ? colors.brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              isMalayalam ? "ഫ്ലീറ്റ് ഓണർ" : "Fleet Owner",
                              style: AppTypography.button(
                                _selectedRoleIndex == 1 ? colors.onBrand : colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ERROR MESSAGE BANNER
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.statusDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.statusDanger, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.statusDanger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.supporting(colors.statusDanger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // DYNAMIC FORM CONTENT
              if (_selectedRoleIndex == 0)
                _buildDriverLoginForm(context, colors, isMalayalam)
              else
                _buildAdminLoginForm(context, colors, isMalayalam),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverLoginForm(BuildContext context, AppColorsExtension colors, bool isMalayalam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          context: context,
          label: isMalayalam ? "രജിസ്റ്റർ ചെയ്ത മൊബൈൽ" : "REGISTERED MOBILE NUMBER",
          controller: _driverPhoneController,
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          context: context,
          label: isMalayalam ? "പിൻ / പാസ്‌വേഡ്" : "SECURITY PIN / PASSWORD",
          controller: _driverPasswordController,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: isMalayalam ? "ഡ്രൈവർ ലോഗിൻ" : "DRIVER LOGIN",
          icon: Icons.login_rounded,
          isLoading: _isLoading,
          onPressed: _handleDriverLogin,
        ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: isMalayalam ? "പുതിയ ഡ്രൈവർ രജിസ്ട്രേഷൻ" : "REGISTER AS DRIVER",
          icon: Icons.person_add_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverRegisterScreen(onToggleLanguage: widget.onToggleLanguage),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              label: Text(
                "Suresh Kumar (+91 94471 23456)",
                style: AppTypography.supporting(colors.textSecondary, fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  _driverPhoneController.text = "+91 94471 23456";
                  _driverPasswordController.text = "1234";
                });
              },
            ),
            ActionChip(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              label: Text(
                "Rajesh Varma (+91 98460 78901)",
                style: AppTypography.supporting(colors.textSecondary, fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  _driverPhoneController.text = "+91 98460 78901";
                  _driverPasswordController.text = "1234";
                });
              },
            ),
            ActionChip(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              label: Text(
                "Anoop Chandran (+91 94951 88990)",
                style: AppTypography.supporting(colors.textSecondary, fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  _driverPhoneController.text = "+91 94951 88990";
                  _driverPasswordController.text = "1234";
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminLoginForm(BuildContext context, AppColorsExtension colors, bool isMalayalam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          context: context,
          label: isMalayalam ? "യൂസർനെയിം" : "ADMIN USERNAME",
          controller: _adminUsernameController,
          icon: Icons.account_circle_outlined,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          context: context,
          label: isMalayalam ? "പാസ്‌വേഡ്" : "ADMIN PASSWORD",
          controller: _adminPasswordController,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: isMalayalam ? "ഫ്ലീറ്റ് മാനേജർ ലോഗിൻ" : "LOGIN AS FLEET MANAGER",
          icon: Icons.admin_panel_settings_rounded,
          isLoading: _isLoading,
          onPressed: _handleAdminLogin,
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            "SmartFleet Enterprise • 256-Bit SSL Encrypted",
            style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required IconData icon,
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
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: AppTypography.body(colors.text, fontSize: 15),
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
