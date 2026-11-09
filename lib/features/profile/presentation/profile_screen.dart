import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../companion/presentation/companion_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String _fullName = 'Learner';
  String _email = '';
  double _usedSeconds = 0.0;
  String _tier = 'Free Tier';
  double _maxSeconds = 120.0; // Free tier default

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserDataService.instance.getProfile();
      final seconds = await UserDataService.instance.getTotalSpeechSeconds();
      final sub = await UserDataService.instance.getSubscription();
      final user = AuthService.instance.currentUser;

      if (mounted) {
        setState(() {
          _fullName = profile?['full_name']?.toString() ??
              (user?.email != null ? user!.email!.split('@')[0] : 'Learner');
          _email = user?.email ?? profile?['email']?.toString() ?? '';
          _usedSeconds = seconds;
          if (sub != null && sub['tier'] != null) {
            final t = sub['tier'].toString();
            _tier = t[0].toUpperCase() + t.substring(1);
            if (t.toLowerCase() == 'pro' || t.toLowerCase() == 'premium') {
              _maxSeconds = 1800.0; // 30 minutes for Pro
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of TalkTails?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
          'My Profile',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfileData,
                color: state.activePet.accentColor,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  children: [
                    // User Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSoft, width: 1.0),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: state.activePet.accentColor.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'L',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: state.activePet.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (_email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _email,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: state.activePet.accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Active Buddy: ${state.activePet.name} (${state.activePet.species})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: state.activePet.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Daily Speech Quota Gauge (Calculated from real usage records)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSoft, width: 1.0),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daily Speech Quota',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '${_usedSeconds.toStringAsFixed(0)}s / ${_maxSeconds.toInt()}s',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: state.activePet.accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (_usedSeconds / _maxSeconds).clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(state.activePet.accentColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Plan: $_tier',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/subscription'),
                                child: Text(
                                  'Upgrade to Pro',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: state.activePet.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildActionItem(
                      icon: Icons.pets,
                      title: 'Change Companion',
                      subtitle: 'Choose between Maru, Mimi, Bun, Pano, Pip, Leo',
                      onTap: () => Navigator.pushNamed(context, '/pets'),
                    ),
                    _buildActionItem(
                      icon: Icons.history,
                      title: 'Conversation History',
                      subtitle: 'Review past translated sessions and scores',
                      onTap: () => Navigator.pushNamed(context, '/history'),
                    ),
                    _buildActionItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings & Audio',
                      subtitle: 'Audio speeds, language voices, haptics',
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                    ),
                    _buildActionItem(
                      icon: Icons.star_border,
                      title: 'Subscription & Plans',
                      subtitle: 'Unlock unlimited speech and all 6 pets',
                      onTap: () => Navigator.pushNamed(context, '/subscription'),
                    ),

                    const SizedBox(height: 24),

                    // Sign Out Button
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                        label: Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        onPressed: _handleSignOut,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.phoneBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textDark, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
        onTap: onTap,
      ),
    ),
  );
  }
}
