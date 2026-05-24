import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/configs/app_theme.dart';
import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/services/storage_service.dart';

class _OnboardingSlide {
  final String imageAsset;
  final String textKey;
  const _OnboardingSlide({required this.imageAsset, required this.textKey});
}

const _slides = <_OnboardingSlide>[
  _OnboardingSlide(imageAsset: 'assets/onboarding/slide_1.jpg', textKey: 'onboarding_slide_1_text'),
  _OnboardingSlide(imageAsset: 'assets/onboarding/slide_2.jpg', textKey: 'onboarding_slide_2_text'),
  _OnboardingSlide(imageAsset: 'assets/onboarding/slide_3.jpg', textKey: 'onboarding_slide_3_text'),
];

/// Non-dismissible onboarding dialog with three sequential slides.
///
/// Opens via [OnboardingDialog.show]. Resolves when the user taps the primary
/// CTA on the last slide and the completion flag is written to [StorageService].
class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const OnboardingDialog(),
    );
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleGotIt() async {
    await StorageService().setBool(StorageService.keyOnboardingComplete, true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final textTheme = Theme.of(context).textTheme;
    final isLastPage = _currentPage == _slides.length - 1;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxl,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl + AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _Slide(slide: _slides[i], l10n: l10n, textTheme: textTheme),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Progress indicator — LinearProgressIndicator with AppColors.primary
              LinearProgressIndicator(
                value: (_currentPage + 1) / _slides.length,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                backgroundColor: AppColors.outline,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLastPage ? _handleGotIt : _handleNext,
                  child: Text(l10n.translate(isLastPage ? 'onboarding_got_it' : 'onboarding_next')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final _OnboardingSlide slide;
  final LocaleProvider l10n;
  final TextTheme textTheme;
  const _Slide({required this.slide, required this.l10n, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.asset(slide.imageAsset, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            l10n.translate(slide.textKey),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
