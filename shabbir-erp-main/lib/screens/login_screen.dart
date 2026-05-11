import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../widgets/app_header.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Apna naam likho pehle.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setBool('offline_logged_in', true);
      if (mounted) widget.onLogin();
    } catch (e) {
      setState(() { _error = 'Kuch masla aaya, dobara try karo.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height
                  - MediaQuery.of(context).padding.top
                  - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Logo
                ShabbirLogo(
                  size: 72,
                  bgColor: AppColors.accent,
                  textColor: AppColors.primary,
                  badgeColor: AppColors.primary,
                ),
                const SizedBox(height: 24),

                Text(
                  'Shabbir Ledger',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Business accounting, seedha aur simple.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 52),

                // Error message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.destructive.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 18, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Name label
                Text(
                  'APNA NAAM',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Name input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: TextField(
                    controller: _nameController,
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Jaise: Shabbir Ahmed',
                      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.accent, size: 20),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                ),
                const SizedBox(height: 16),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                          )
                        : Text(
                            'Shuru Karo',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aapka sab data sirf is device par save hoga. Koi internet ki zaroorat nahi. Backup le kar dusri jagah le ja sakte ho.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white54,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
