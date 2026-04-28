import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/services/storage_service.dart';

// Slide data class
class _OnboardingSlide {
  final String imageAsset;
  final String textKey; // l10n key
  const _OnboardingSlide({required this.imageAsset, required this.textKey});
}

// Slide config — only this list needs changing if slides are added/reordered
const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    imageAsset: 'assets/onboarding/slide_1.png',
    textKey: 'onboarding_slide_1_text',
  ),
  _OnboardingSlide(
    imageAsset: 'assets/onboarding/slide_2.png',
    textKey: 'onboarding_slide_2_text',
  ),
  _OnboardingSlide(
    imageAsset: 'assets/onboarding/slide_3.png',
    textKey: 'onboarding_slide_3_text',
  ),
];

/// Non-dismissible onboarding dialog with three sequential slides.
///
/// Opens via [OnboardingDialog.show]. Resolves when user taps "Got it" on the
/// last slide and the completion flag is written to [StorageService].
class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  /// Opens the onboarding dialog. Returns after the user taps "Got it".
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
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
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleGotIt(BuildContext context) async {
    await StorageService().setBool(StorageService.keyOnboardingComplete, true);
    if (context.mounted) Navigator.of(context).pop();
  }

  Widget _buildSlide(_OnboardingSlide slide, LocaleProvider l10n) {
    return Column(
      children: [
        Expanded(
          child: Image.asset(slide.imageAsset, fit: BoxFit.contain),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            l10n.translate(slide.textKey),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    final isLastPage = _currentPage == _slides.length - 1;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PageView — fixed height, swipe blocked
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _buildSlide(_slides[i], l10n),
              ),
            ),
            // Button row
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLastPage
                      ? () => _handleGotIt(context)
                      : _handleNext,
                  child: Text(
                    isLastPage
                        ? l10n.translate('onboarding_got_it')
                        : l10n.translate('onboarding_next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
