import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/lendly_buttons.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Hero section
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              
              AppSpacing.verticalXl,
              
              // Welcome text
              Text(
                'Welcome to Lendly',
                style: AppTextStyles.hero.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              
              AppSpacing.verticalMd,
              
              Text(
                'Connect, lend, and build trust with your college community',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              
              AppSpacing.verticalXl,
              
              // Action buttons
              LendlyPrimaryButton(
                text: 'Get Started',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
              ),
              
              AppSpacing.verticalMd,
              
              LendlySecondaryButton(
                text: 'Sign In',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}