import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  int _selectedMinutes = 10;
  String _selectedLevel = 'beginner';

  @override
  Widget build(BuildContext context) {
    final goals = [
      {'mins': 5, 'title': 'Casual', 'desc': '5 mins / day'},
      {'mins': 10, 'title': 'Regular', 'desc': '10 mins / day (Recommended)'},
      {'mins': 15, 'title': 'Dedicated', 'desc': '15 mins / day'},
      {'mins': 20, 'title': 'Intense', 'desc': '20 mins / day'},
    ];

    final levels = [
      {'key': 'beginner', 'title': 'Beginner', 'desc': 'I know basic words'},
      {'key': 'intermediate', 'title': 'Intermediate', 'desc': 'I can hold simple conversations'},
      {'key': 'advanced', 'title': 'Advanced', 'desc': 'I want fluency and natural rhythm'},
    ];

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Learning Rhythm',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set a daily goal to help your pet keep you motivated.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 24),

              // Daily Goal Section
              Text(
                'DAILY PRACTICE GOAL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 10),
              ...goals.map((g) {
                final isSel = g['mins'] == _selectedMinutes;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? AppColors.foxMaru : AppColors.borderSoft,
                      width: isSel ? 2.0 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      g['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSel ? AppColors.foxMaru : AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      g['desc'] as String,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check_circle, color: AppColors.foxMaru)
                        : null,
                    onTap: () => setState(() => _selectedMinutes = g['mins'] as int),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // Level Section
              Text(
                'CURRENT PROFICIENCY',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 10),
              ...levels.map((l) {
                final isSel = l['key'] == _selectedLevel;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? AppColors.foxMaru : AppColors.borderSoft,
                      width: isSel ? 2.0 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      l['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSel ? AppColors.foxMaru : AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      l['desc'] as String,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check_circle, color: AppColors.foxMaru)
                        : null,
                    onTap: () => setState(() => _selectedLevel = l['key'] as String),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.foxMaru,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/onboarding/pets');
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

