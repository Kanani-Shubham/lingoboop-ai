import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../../core/widgets/floating_pet_avatar.dart';
import '../../companion/presentation/companion_state.dart';
import '../../companion/presentation/lingo_card_widget.dart';
import '../../settings/presentation/pet_settings_sheet.dart';

class MainCompanionScreen extends ConsumerStatefulWidget {
  final bool showFloatingPet;
  const MainCompanionScreen({super.key, this.showFloatingPet = true});

  @override
  ConsumerState<MainCompanionScreen> createState() => _MainCompanionScreenState();
}

class _MainCompanionScreenState extends ConsumerState<MainCompanionScreen> {
  Offset _petPos = const Offset(110, 260);
  bool _hasTappedPet = false;
  String _displayName = 'Learner';
  double _todayMinutes = 0.0;
  int _dailyGoalMinutes = 10;

  @override
  void initState() {
    super.initState();
    _loadRealUserData();
  }

  Future<void> _loadRealUserData() async {
    try {
      final profile = await UserDataService.instance.getProfile();
      final prefs = await UserDataService.instance.getPreferences();
      final seconds = await UserDataService.instance.getTotalSpeechSeconds();

      if (mounted) {
        setState(() {
          if (profile != null && profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
            _displayName = profile['full_name'].toString().split(' ')[0];
          } else if (AuthService.instance.currentUser?.email != null) {
            _displayName = AuthService.instance.currentUser!.email!.split('@')[0];
          }
          if (prefs != null && prefs['daily_goal_minutes'] != null) {
            _dailyGoalMinutes = prefs['daily_goal_minutes'] as int;
          }
          _todayMinutes = (seconds / 60.0);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);
    final size = MediaQuery.of(context).size;

    // Boundary clamp: stay cleanly above bottom nav (64px) and card clearance
    final maxY = size.height - 180;

    final langPairTitle =
        '${companionState.sourceLanguage.flag} ${companionState.sourceLanguage.name.split(' ')[0]} → ${companionState.targetLanguage.flag} ${companionState.targetLanguage.name}';

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Stage Hub Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Pair Pill
                      InkWell(
                        onTap: notifier.toggleSettings,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                langPairTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons: History & Settings
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.history, color: AppColors.textDark, size: 22),
                            tooltip: 'Conversation History',
                            onPressed: () => Navigator.pushNamed(context, '/history'),
                          ),
                          InkWell(
                            onTap: notifier.toggleSettings,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 1.5),
                              ),
                              child: const Center(
                                child: Icon(Icons.tune, size: 18, color: AppColors.textDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Greeting & Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $_displayName',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companionState.statusNote,
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Practice Prompts Feed
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 90),
                    children: [
                      // Daily Practice Goal Card (Interactive -> Launches Daily Practice)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/daily-practice').then((_) {
                            _loadRealUserData();
                          });
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderSoft, width: 1.0),
                            boxShadow: const [
                              BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Daily Speech Practice',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    '${_todayMinutes.toStringAsFixed(1)} / $_dailyGoalMinutes min',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: companionState.activePet.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _dailyGoalMinutes > 0
                                      ? (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0)
                                      : 0.0,
                                  minHeight: 8,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    companionState.activePet.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'PRACTICE PROMPTS',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),

                      _buildPromptCard(
                        title: 'Ask for Directions',
                        subtitle: 'How do I reach the nearest railway station?',
                        sourceSample: 'નજીકનું રેલવે સ્ટેશન ક્યાં છે?',
                        targetTranslation: 'Where is the nearest railway station?',
                        notifier: notifier,
                      ),
                      _buildPromptCard(
                        title: 'Order Refreshments',
                        subtitle: 'Please give me two cups of hot masala tea.',
                        sourceSample: 'કૃપા કરીને મને બે કપ ગરમ મસાલા ચા આપો.',
                        targetTranslation: 'Please give me two cups of hot masala tea.',
                        notifier: notifier,
                      ),
                      _buildPromptCard(
                        title: 'Introduce Yourself',
                        subtitle: 'My name is, and I am learning English.',
                        sourceSample: 'મારું નામ છે, અને હું અંગ્રેજી શીખી રહ્યો છું.',
                        targetTranslation: 'My name is, and I am learning English.',
                        notifier: notifier,
                      ),
                      _buildPromptCard(
                        title: 'Free Speech Practice',
                        subtitle: 'Say anything out loud and hear it spoken back.',
                        sourceSample: '',
                        targetTranslation: '',
                        isFreeForm: true,
                        notifier: notifier,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. Settings Sheet Dropdown (#sh) - only if standalone preview
            if (widget.showFloatingPet && companionState.isSettingsOpen)
              Positioned(
                top: 60,
                left: 12,
                right: 12,
                child: const PetSettingsSheet(),
              ),

            if (widget.showFloatingPet) ...[
              // 3. Floating PolyCard Dialogue (#cd)
              if (companionState.isCardOpen)
                Positioned(
                  bottom: 76,
                  left: (_petPos.dx + 75 < size.width / 2) ? 108 : null,
                  right: (_petPos.dx + 75 < size.width / 2) ? null : 108,
                  child: const LingoCardWidget(),
                ),

              // 4. Draggable Floating 3D Pet Companion (#pw / #cv)
              Positioned(
                left: _petPos.dx,
                top: _petPos.dy,
                child: FloatingPetAvatar(
                  character: companionState.activePet,
                  mode: companionState.petMode,
                  showHint: !_hasTappedPet && !companionState.isCardOpen,
                  isCardOpen: companionState.isCardOpen,
                  dockSide: (_petPos.dx + 75 < size.width / 2) ? 'r' : 'l',
                  onTap: () {
                    setState(() => _hasTappedPet = true);
                    if (companionState.isCardOpen) {
                      notifier.closeCard();
                    } else {
                      final side = (_petPos.dx + 75 < size.width / 2) ? 'r' : 'l';
                      final tx = (side == 'r') ? -24.0 : (size.width - 126.0);
                      setState(() {
                        _petPos = Offset(tx, _petPos.dy);
                      });
                      notifier.openCard();
                    }
                  },
                  onDragUpdate: (delta) {
                    setState(() {
                      _petPos = Offset(
                        (_petPos.dx + delta.dx).clamp(-40.0, size.width - 110.0),
                        (_petPos.dy + delta.dy).clamp(60.0, maxY),
                      );
                    });
                    notifier.updatePetPosition(_petPos);
                  },
                  onDragEnd: () {
                    notifier.finishPetDrag();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard({
    required String title,
    required String subtitle,
    required String sourceSample,
    required String targetTranslation,
    bool isFreeForm = false,
    required CompanionNotifier notifier,
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
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
          onTap: () {
            notifier.openCard();
            if (isFreeForm) {
              notifier.startListening();
            } else {
              notifier.submitTypedText(targetTranslation);
            }
          },
        ),
      ),
    );
  }
}
