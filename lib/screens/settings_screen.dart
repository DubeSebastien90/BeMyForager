import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics_service.dart';
import '../services/demo_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _demoLoading = false;
  bool _saveToGallery = false;

  static const _prefKey = 'save_to_gallery';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    var enabled = prefs.getBool(_prefKey) ?? false;
    // If the toggle was on but permission was revoked, sync it back to off.
    if (enabled && !await Gal.hasAccess()) {
      enabled = false;
      await prefs.setBool(_prefKey, false);
    }
    if (mounted) setState(() => _saveToGallery = enabled);
  }

  Future<void> _setSaveToGallery(bool value) async {
    if (value) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        _showPermissionDeniedSnackbar();
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (mounted) setState(() => _saveToGallery = value);
  }

  void _showPermissionDeniedSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('gallery_permission_denied'.tr()),
        behavior: SnackBarBehavior.floating,
        action: Platform.isIOS
            ? SnackBarAction(
                label: 'open_settings'.tr(),
                onPressed: () =>
                    launchUrl(Uri.parse('app-settings:')),
              )
            : null,
      ),
    );
  }

  Future<void> _loadDemo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('load_demo_title'.tr()),
        content: Text('load_demo_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('load'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _demoLoading = true);
    try {
      await DemoDataService().populate();
      AnalyticsService.logDemoLoaded();
    } finally {
      if (mounted) {
        // Pop with true so HomeScreen knows to refresh the collection.
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _SectionHeader(label: 'language_section'.tr()),
          _LanguageTile(
            label: 'english'.tr(),
            selected: currentLang == 'en',
            onTap: () {
              context.setLocale(const Locale('en'));
              AnalyticsService.logLanguageChanged('en');
            },
          ),
          _LanguageTile(
            label: 'french'.tr(),
            selected: currentLang == 'fr',
            onTap: () {
              context.setLocale(const Locale('fr'));
              AnalyticsService.logLanguageChanged('fr');
            },
          ),
          const Divider(height: 1),
          _SectionHeader(label: 'photos_section'.tr()),
          SwitchListTile(
            secondary: Icon(Icons.photo_library_outlined, color: Colors.green[700]),
            title: Text('save_to_gallery'.tr()),
            subtitle: Text('save_to_gallery_subtitle'.tr()),
            value: _saveToGallery,
            activeThumbColor: Colors.green[700],
            onChanged: _setSaveToGallery,
          ),
          const Divider(height: 1),
          _SectionHeader(label: 'legal_section'.tr()),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.green[700]),
            title: Text('privacy_policy'.tr()),
            trailing: Icon(Icons.open_in_new, size: 18, color: Colors.grey[400]),
            onTap: () => launchUrl(
              Uri.parse('https://delicate-october-831.notion.site/privacy_policy-384802803a788016a864ec901fd1228e'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(height: 1),
          _SectionHeader(label: 'developer_section'.tr()),
          ListTile(
            leading: Icon(Icons.science_outlined, color: Colors.green[700]),
            title: Text('load_demo_tooltip'.tr()),
            trailing: _demoLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: _demoLoading ? null : _loadDemo,
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_rounded, color: Colors.green[700])
          : null,
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.green[700],
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
