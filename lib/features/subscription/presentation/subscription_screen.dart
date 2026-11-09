import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../companion/presentation/companion_state.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = 'yearly';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pro Badge & Header
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.activePet.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, size: 16, color: state.activePet.accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'TALKTAILS PRO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: state.activePet.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Unlock Unlimited\nSpeech & All Companions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 24),

              // Plan Cards: Yearly vs Monthly
              Row(
                children: [
                  // Yearly Plan (₹49/yr)
                  Expanded(
                    child: _buildPlanCard(
                      id: 'yearly',
                      title: 'Yearly Plan',
                      price: '₹49',
                      period: 'per year',
                      badge: 'SAVE 55%',
                      accentColor: state.activePet.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Monthly Plan (₹9/mo)
                  Expanded(
                    child: _buildPlanCard(
                      id: 'monthly',
                      title: 'Monthly Plan',
                      price: '₹9',
                      period: 'per month',
                      accentColor: state.activePet.accentColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Feature Matrix
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Everything Included in Pro:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureItem('1,800 seconds daily speech quota (30 mins)'),
                    _buildFeatureItem('Unlock all 6 companion pets (Pano, Pip, Leo)'),
                    _buildFeatureItem('Advanced Gnani Evon contextual translation'),
                    _buildFeatureItem('Unlimited AI conversation roleplay turns'),
                    _buildFeatureItem('Phonetic pronunciation scoring & coaching'),
                    _buildFeatureItem('Unlimited conversation history & audio replay'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Purchase Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.activePet.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Subscription Active!'),
                        content: Text(
                          'You are now subscribed to the TalkTails Pro ${_selectedPlan == "yearly" ? "₹49/year" : "₹9/month"} plan. All 6 pets and 1,800s daily quota are unlocked!',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: const Text('Awesome!'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    _selectedPlan == 'yearly' ? 'Subscribe for ₹49 / Year' : 'Subscribe for ₹9 / Month',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Cancel anytime in Google Play Store settings.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    required String period,
    String? badge,
    required Color accentColor,
  }) {
    final isSel = _selectedPlan == id;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? accentColor : AppColors.borderSoft,
            width: isSel ? 2.5 : 1.0,
          ),
          boxShadow: [
            if (isSel)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const SizedBox(height: 23),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: isSel ? accentColor : AppColors.textDark,
              ),
            ),
            Text(
              period,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
