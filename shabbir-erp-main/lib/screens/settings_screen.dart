import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../providers/erp_provider.dart';
import '../services/backup_service.dart';
import '../services/github_gist_service.dart';
import '../services/security_service.dart';
import '../widgets/app_header.dart';
import 'pattern_lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _patternEnabled = false;
  bool _loadingBackupLocal = false;
  bool _loadingRestoreLocal = false;
  bool _loadingGistBackup = false;
  bool _loadingGistRestore = false;
  bool _loadingLogout = false;
  String _offlineName = 'User';
  String _savedGistId = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await SecurityService.instance.isPatternEnabled();
    final hasPattern = await SecurityService.instance.hasPatternSet();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _patternEnabled = enabled && hasPattern;
        _offlineName = prefs.getString('user_name') ?? 'User';
        _savedGistId = prefs.getString('gist_id') ?? '';
      });
    }
  }

  // ── Name Editing ───────────────────────────────────────────────────────────
  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _offlineName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Naam Tabdeel Karo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Apna naam likho',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () { final n = ctrl.text.trim(); if (n.isNotEmpty) Navigator.of(context).pop(n); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      if (mounted) setState(() => _offlineName = name);
      _snack('Naam update ho gaya!');
    }
  }

  // ── Pattern Lock ───────────────────────────────────────────────────────────
  Future<void> _togglePattern() async {
    if (_patternEnabled) {
      final verified = await Navigator.of(context).push<bool>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PatternLockScreen(mode: PatternLockMode.verify, onSuccess: () => Navigator.of(context).pop(true), onCancel: () => Navigator.of(context).pop(false)),
      ));
      if (verified == true) { await SecurityService.instance.disablePattern(); if (mounted) setState(() => _patternEnabled = false); _snack('Pattern lock band ho gaya'); }
    } else {
      final set = await Navigator.of(context).push<bool>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PatternLockScreen(mode: PatternLockMode.set, onSuccess: () => Navigator.of(context).pop(true), onCancel: () => Navigator.of(context).pop(false)),
      ));
      if (set == true) { if (mounted) setState(() => _patternEnabled = true); _snack('Pattern lock laga diya'); }
    }
  }

  Future<void> _changePattern() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PatternLockScreen(mode: PatternLockMode.change, onSuccess: () => Navigator.of(context).pop(true), onCancel: () => Navigator.of(context).pop(false)),
    ));
    if (changed == true) _snack('Pattern tabdeel ho gaya');
  }

  // ── Local Backup ───────────────────────────────────────────────────────────
  Future<void> _backupLocal() async {
    setState(() => _loadingBackupLocal = true);
    try {
      await BackupService.instance.backupToLocalStorage();
      _snack('Backup file tayyar — save karo ya share karo');
    } catch (e) {
      _snack('Backup nahi hua: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingBackupLocal = false);
    }
  }

  Future<void> _restoreLocal() async {
    final confirm = await _confirmDialog('Device se Restore?', 'Backup file select karo. Ye current data replace kar dega. Undo nahi hoga.');
    if (!confirm) return;
    setState(() => _loadingRestoreLocal = true);
    try {
      final success = await BackupService.instance.restoreFromLocalFile();
      if (!success) { _snack('Koi file select nahi ki'); return; }
      if (mounted) await context.read<ERPProvider>().reload();
      _snack('Data restore ho gaya!');
    } catch (e) {
      _snack('Restore nahi hua: ${e.toString().replaceAll("Exception:", "").trim()}', error: true);
    } finally {
      if (mounted) setState(() => _loadingRestoreLocal = false);
    }
  }

  // ── GitHub Gist Backup ─────────────────────────────────────────────────────
  Future<void> _gistBackup() async {
    final token = await _askToken();
    if (token == null || token.isEmpty) return;
    setState(() => _loadingGistBackup = true);
    try {
      final gistId = await GithubGistService.backup(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gist_id', gistId);
      await prefs.setString('github_token', token);
      if (mounted) setState(() => _savedGistId = gistId);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Backup Kamyab!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aapka data online save ho gaya. Ye Gist ID apne paas rakh lo restore ke liye:', style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () { Clipboard.setData(ClipboardData(text: gistId)); _snack('Gist ID copy ho gaya!'); },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(child: Text(gistId, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
                    const Icon(Icons.copy, size: 16, color: AppColors.primary),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text('(Copy karo aur kahin save karo)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedForeground)),
            ]),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Theek Hai', style: GoogleFonts.inter(fontWeight: FontWeight.w600)))],
          ),
        );
      }
    } catch (e) {
      _snack('${e.toString().replaceAll("Exception:", "").trim()}', error: true);
    } finally {
      if (mounted) setState(() => _loadingGistBackup = false);
    }
  }

  Future<void> _gistRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('github_token') ?? '';
    final tokenCtrl = TextEditingController(text: savedToken);
    final gistCtrl = TextEditingController(text: _savedGistId);

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Online se Restore', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: tokenCtrl,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'GitHub Token',
              hintText: 'ghp_xxxx...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: gistCtrl,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Gist ID',
              hintText: 'Backup Gist ID paste karo',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Restore', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;

    if (!result) return;
    final token = tokenCtrl.text.trim();
    final gistId = gistCtrl.text.trim();
    if (token.isEmpty || gistId.isEmpty) { _snack('Token aur Gist ID dono chahiye', error: true); return; }

    setState(() => _loadingGistRestore = true);
    try {
      await GithubGistService.restore(token, gistId);
      await prefs.setString('github_token', token);
      await prefs.setString('gist_id', gistId);
      if (mounted) setState(() => _savedGistId = gistId);
      if (mounted) await context.read<ERPProvider>().reload();
      _snack('Data restore ho gaya online backup se!');
    } catch (e) {
      _snack('${e.toString().replaceAll("Exception:", "").trim()}', error: true);
    } finally {
      if (mounted) setState(() => _loadingGistRestore = false);
    }
  }

  Future<String?> _askToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('github_token') ?? '';
    final ctrl = TextEditingController(text: saved);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('GitHub Token', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('github.com → Settings → Developer Settings → Personal Access Tokens → "gist" permission do', style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedForeground, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ghp_xxxx...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Backup Karo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await _confirmDialog('Sign Out?', 'Aap login screen par wapas jayenge. Data safe rahega.');
    if (!confirm) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_logged_in');
    if (mounted) widget.onLogout();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<bool> _confirmDialog(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Haan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
      backgroundColor: error ? AppColors.destructive : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('About Shabbir ERP', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Text('Powered by Shabbir Ahmed.\n\nThis app is totally AI-generated.', style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close', style: GoogleFonts.inter()))],
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final initials = _offlineName.trim().isNotEmpty
        ? _offlineName.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        const AppHeader(title: 'Settings', subtitle: 'Account, security & data'),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            // ── Account Card ──
            _SectionLabel('Account'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: [AppColors.cardShadow]),
              child: Row(children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(15)),
                  child: Center(child: Text(initials, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.accent))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_offlineName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.foreground)),
                  Text('Offline Mode — data sirf is device par', style: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 11.5, color: AppColors.mutedForeground, height: 1.4)),
                ])),
                GestureDetector(
                  onTap: _editName,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Security ──
            _SectionLabel('Security'),
            _Tile(icon: Icons.grid_view_outlined, title: 'Pattern Lock', subtitle: _patternEnabled ? 'Chalu hai — band karne ke liye tap karo' : 'Band hai — chalane ke liye tap karo', trailing: Switch(value: _patternEnabled, onChanged: (_) => _togglePattern(), activeColor: AppColors.primary)),
            if (_patternEnabled) _Tile(icon: Icons.refresh_outlined, title: 'Pattern Tabdeel Karo', subtitle: 'Naya unlock pattern banao', onTap: _changePattern),
            const SizedBox(height: 24),

            // ── Local Backup ──
            _SectionLabel('Local Backup (Device)'),
            _Tile(icon: Icons.phone_android_outlined, title: 'Device pe Backup', subtitle: 'JSON file download karo apne phone mein', loading: _loadingBackupLocal, onTap: _backupLocal),
            _Tile(icon: Icons.folder_open_outlined, title: 'Device se Restore', subtitle: 'Pehle save ki hui backup file select karo', loading: _loadingRestoreLocal, onTap: _restoreLocal),
            const SizedBox(height: 24),

            // ── Online Backup ──
            _SectionLabel('Online Backup (GitHub Gist)'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accent.withOpacity(0.25))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.cloud_outlined, size: 16, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _savedGistId.isNotEmpty
                    ? 'Aakhri backup Gist: $_savedGistId'
                    : 'GitHub account se free online backup. Phone kho jaye ya delete ho — phir bhi data milega.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.foreground, height: 1.5),
                )),
              ]),
            ),
            _Tile(icon: Icons.cloud_upload_outlined, title: 'Online Backup Karo', subtitle: 'GitHub Gist mein data save karo (free)', loading: _loadingGistBackup, onTap: _gistBackup),
            _Tile(icon: Icons.cloud_download_outlined, title: 'Online se Restore Karo', subtitle: 'GitHub Gist se data wapas lao', loading: _loadingGistRestore, onTap: _gistRestore),
            const SizedBox(height: 24),

            // ── Account Actions ──
            _SectionLabel('Account'),
            _Tile(icon: Icons.logout, title: 'Sign Out', subtitle: 'Login screen par wapas jao', destructive: true, loading: _loadingLogout, onTap: _logout),
            const SizedBox(height: 36),
            _SectionLabel('About'),
            _Tile(icon: Icons.info_outline, title: 'About Shabbir ERP', subtitle: 'Powered by Shabbir Ahmed. AI-generated.', onTap: () => _showAboutDialog(context)),
            const SizedBox(height: 12),
            Center(child: Text('Shabbir ERP  v1.0.0', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.mutedForeground))),
          ],
        )),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.mutedForeground, letterSpacing: 0.8)),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool loading;
  final bool dimmed;

  const _Tile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap, this.destructive = false, this.loading = false, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1.0,
        child: GestureDetector(
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: [AppColors.cardShadow]),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: destructive ? const Color(0xFFFEE2E2) : AppColors.secondary, borderRadius: BorderRadius.circular(11)),
                child: loading
                    ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: destructive ? AppColors.destructive : AppColors.primary))
                    : Icon(icon, size: 18, color: destructive ? AppColors.destructive : AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: destructive ? AppColors.destructive : AppColors.foreground)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.mutedForeground), maxLines: 2),
              ])),
              if (trailing != null) trailing!
              else if (onTap != null && !loading) Icon(Icons.chevron_right, size: 18, color: destructive ? AppColors.destructive : AppColors.mutedForeground),
            ]),
          ),
        ),
      ),
    );
  }
}
