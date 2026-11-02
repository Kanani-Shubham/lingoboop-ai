import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/overlay_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../companion/presentation/companion_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  double _speechRate = 1.0;
  bool _overlayRunning = false;
  bool _hasOverlayPermission = false;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlayState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _checkOverlayState();
    }
  }

  Future<void> _checkOverlayState() async {
    final hasPerm = await OverlayService.instance.checkPermission();
    final isRunning = await OverlayService.instance.isOverlayRunning();
    final prefs = await UserDataService.instance.getPreferences();
    final savedEnabled = prefs?['overlay_enabled'] as bool?;

    if (mounted) {
      setState(() {
        _hasOverlayPermission = hasPerm;
        _overlayRunning = isRunning || (hasPerm && (savedEnabled ?? false));
      });
    }
  }

  Future<void> _handleToggleOverlay(bool enable) async {
    final companionState = ref.read(companionProvider);

    if (enable) {
      final hasPerm = await OverlayService.instance.checkPermission();
      if (!hasPerm) {
        if (!mounted) return;
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Display Over Other Apps'),
            content: const Text(
              'To show your language learning companion above apps like WhatsApp, Chrome, or YouTube, Android requires the "Display over other apps" permission.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: companionState.activePet.accentColor,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Grant Permission', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await OverlayService.instance.requestPermission();
        }
        return;
      }

      // Start native overlay
      final colorHex = '#${companionState.activePet.accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      final ok = await OverlayService.instance.startOverlay(
        petKey: companionState.activePet.key,
        petName: companionState.activePet.name,
        petColorHex: colorHex,
        sourceLang: companionState.sourceLanguage.bcp47,
        targetLang: companionState.targetLanguage.bcp47,
      );

      // Persist to Supabase preferences
      await UserDataService.instance.savePreferences(overlayEnabled: true);

      if (mounted) setState(() => _overlayRunning = ok);
    } else {
      final ok = await OverlayService.instance.stopOverlay();
      // Persist to Supabase preferences
      await UserDataService.instance.savePreferences(overlayEnabled: false);
      if (mounted) setState(() => _overlayRunning = !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          children: [
            // Android Floating Pet Overlay Section
            _buildSectionHeader('PERSISTENT FLOATING COMPANION'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: state.activePet.accentColor,
                    title: const Text(
                      'Enable Floating Pet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Floats over other apps (WhatsApp, Chrome, YouTube). Stays available even after leaving LingoBoom.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.3),
                    ),
                    value: _overlayRunning,
                    onChanged: _handleToggleOverlay,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _hasOverlayPermission ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 16,
                        color: _hasOverlayPermission ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hasOverlayPermission
                            ? 'Display over other apps: Granted'
                            : 'Display over other apps: Missing permission',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _hasOverlayPermission ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (!_hasOverlayPermission) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: state.activePet.accentColor,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => OverlayService.instance.requestPermission(),
                      child: const Text('Open Android Settings to grant permission →'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Voice & Speech Section
            _buildSectionHeader('VOICE & AUDIO PLAYBACK'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Playback Speech Speed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${_speechRate.toStringAsFixed(1)}x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: state.activePet.accentColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _speechRate,
                    min: 0.5,
                    max: 1.5,
                    divisions: 4,
                    activeColor: state.activePet.accentColor,
                    inactiveColor: AppColors.phoneBackground,
                    onChanged: (val) {
                      setState(() => _speechRate = val);
                      UserDataService.instance.savePreferences(audioSpeed: val);
                    },
                  ),
                  const Text(
                    'Default playback speed for spoken translations and repetition practice.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Divider(height: 24, color: AppColors.borderSoft),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: state.activePet.accentColor,
                    title: const Text(
                      'Haptic Feedback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Vibrate on companion interactions and speech matching.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    value: _hapticEnabled,
                    onChanged: (val) => setState(() => _hapticEnabled = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Account & Session Section
            _buildSectionHeader('ACCOUNT & SESSION'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft, width: 1.0),
              ),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, color: Colors.red.shade700, size: 20),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                subtitle: const Text(
                  'Safely end current session on this device',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () async {
                  await AuthService.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
