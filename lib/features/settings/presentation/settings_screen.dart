import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../companion/presentation/companion_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _speechRate = 1.0;
  bool _overlayEnabled = true;
  bool _hapticEnabled = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
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
            // Voice & Speech Section
            _buildSectionHeader('VOICE & AUDIO PLAYBACK'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                    onChanged: (val) => setState(() => _speechRate = val),
                  ),
                  const Text(
                    'Default playback speed for translated sentences.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Android Floating Overlay Section
            _buildSectionHeader('COMPANION & OVERLAY'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: state.activePet.accentColor,
                    title: const Text(
                      'Floating Android Overlay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Float pet over other apps using Android WindowManager.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    value: _overlayEnabled,
                    onChanged: (val) => setState(() => _overlayEnabled = val),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
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
                      'Vibrate on pet taps and pronunciation matches.',
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
            _buildSectionHeader('ACCOUNT'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
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
