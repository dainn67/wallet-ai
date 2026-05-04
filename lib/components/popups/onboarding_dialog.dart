import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/services/storage_service.dart';

const _accent = Color(0xFF0F172A);
const _dotInactive = Color(0xFFE2E8F0);

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
    final isLastPage = _currentPage == _slides.length - 1;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
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
                  itemBuilder: (_, i) => _Slide(slide: _slides[i], l10n: l10n),
                ),
              ),
              const SizedBox(height: 24),
              _DotIndicator(count: _slides.length, current: _currentPage),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _PrimaryPill(
                  label: l10n.translate(isLastPage ? 'onboarding_got_it' : 'onboarding_next'),
                  onTap: isLastPage ? _handleGotIt : _handleNext,
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
  const _Slide({required this.slide, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(slide.imageAsset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l10n.translate(slide.textKey),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _accent,
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? _accent : _dotInactive,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _PrimaryPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
