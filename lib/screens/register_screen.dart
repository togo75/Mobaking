import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import 'app_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _stepLabels = ['Tɔgɔ', 'Telefɔni', 'Sabali'];

  final PageController _pageController = PageController();
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmPinCtrl = TextEditingController();

  int _step = 0;
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _agreeTerms = false;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _pinError;
  String? _confirmPinError;

  bool _validateStep(int step) {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _pinError = null;
      _confirmPinError = null;
    });

    switch (step) {
      case 0:
        if (_fullNameCtrl.text.trim().length < 2) {
          setState(() => _nameError = 'I tɔgɔ bɛɛ sɛbɛn');
          return false;
        }
        final email = _emailCtrl.text.trim();
        if (email.isNotEmpty) {
          final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');
          if (!emailRegex.hasMatch(email)) {
            setState(() => _emailError = 'Email man ɲi');
            return false;
          }
        }
        return true;
      case 1:
        if (_phoneCtrl.text.trim().length < 8) {
          setState(() => _phoneError = 'Nimɔrɔ man ɲi');
          return false;
        }
        return true;
      case 2:
        // ✅ PIN exactement 4 chiffres
        if (_pinCtrl.text.length != 4) {
          setState(() => _pinError = 'I ka nimɔrɔ 4 sɛbɛn');
          return false;
        }
        if (_confirmPinCtrl.text != _pinCtrl.text) {
          setState(() => _confirmPinError = 'PIN nimɔrɔw tɛ kelen');
          return false;
        }
        if (!_agreeTerms) {
          _showSnackBar('I ka kondisɔnw sɔn walisa ka taa ɲɛ', isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goNext() {
    if (!_validateStep(_step)) return;
    if (_step == _stepLabels.length - 1) {
      _register();
      return;
    }
    setState(() => _step += 1);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final error = await ServiceLocator.instance.auth.signUp(
        fullName: _fullNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        pin: _pinCtrl.text.trim(),
      );

      if (!mounted) return;

      if (error != null) {
        _showSnackBar(error, isError: true);
        setState(() => _isLoading = false);
        return;
      }

      _showSnackBar('Kɔnti dara ka ɲɛ !', isError: false);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Fili: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              shadowColor: Colors.black.withValues(alpha: 0.04),
              elevation: 2,
            ),
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                          const Color(0xFF6B4CF7).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Kɔnti da',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A6CF7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModernStepIndicator(
                    totalSteps: _stepLabels.length,
                    currentStep: _step,
                    stepLabels: _stepLabels,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _identityStep(),
                  _phoneStep(),
                  _securityStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor:
                        const Color(0xFF4A6CF7).withValues(alpha: 0.6),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == _stepLabels.length - 1
                              ? 'N ka kɔnti da'
                              : 'Taa ɲɛ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepScroll({
    required String title,
    required String subtitle,
    required Widget child,
    required IconData icon,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                  const Color(0xFF6B4CF7).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: const Color(0xFF4A6CF7)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _identityStep() {
    return _stepScroll(
      title: 'I tɔgɔ ye di ?',
      subtitle: 'Tɔgɔ min bɛna jira i ka wari cilenw kan',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _ModernTextField(
            controller: _fullNameCtrl,
            label: 'Tɔgɔ bɛɛ',
            hint: 'Fatoumata Sangaré',
            errorText: _nameError,
            prefixIcon: Icons.person_outline_rounded,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 18),
          _ModernTextField(
            controller: _emailCtrl,
            label: 'Email adrɛsi (a tɛ wajibi)',
            hint: 'fatoumata@example.com',
            errorText: _emailError,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _emailError = null),
          ),
        ],
      ),
    );
  }

  Widget _phoneStep() {
    return _stepScroll(
      title: 'I ka telefɔni nimɔrɔ',
      subtitle: 'Walisa ka i ka sabali nimɔrɔw sɔrɔ',
      icon: Icons.phone_outlined,
      child: _ModernPhoneField(
        controller: _phoneCtrl,
        errorText: _phoneError,
        onChanged: (_) => setState(() => _phoneError = null),
      ),
    );
  }

  Widget _securityStep() {
    return _stepScroll(
      title: 'I ka kɔnti kɔlɔsi',
      subtitle: 'I ka PIN nimɔrɔ 4 sugandi',
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernPinField(
            controller: _pinCtrl,
            label: 'PIN nimɔrɔ',
            obscure: _obscurePin,
            errorText: _pinError,
            onToggleVisibility: () => setState(() => _obscurePin = !_obscurePin),
            onChanged: (_) => setState(() => _pinError = null),
          ),
          const SizedBox(height: 16),
          _ModernPinField(
            controller: _confirmPinCtrl,
            label: 'PIN dasɔn',
            obscure: _obscureConfirmPin,
            errorText: _confirmPinError,
            onToggleVisibility: () =>
                setState(() => _obscureConfirmPin = !_obscureConfirmPin),
            onChanged: (_) => setState(() => _confirmPinError = null),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => setState(() => _agreeTerms = !_agreeTerms),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _agreeTerms
                    ? const Color(0xFF4A6CF7).withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreeTerms
                      ? const Color(0xFF4A6CF7).withValues(alpha: 0.3)
                      : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _agreeTerms
                          ? const Color(0xFF4A6CF7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _agreeTerms
                            ? const Color(0xFF4A6CF7)
                            : const Color(0xFF94A3B8),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _agreeTerms
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'N bɛ kondisɔnw sɔn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            _agreeTerms ? FontWeight.w600 : FontWeight.w400,
                        color: _agreeTerms
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ========== MODERN STEP INDICATOR ==========

class _ModernStepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final List<String> stepLabels;

  const _ModernStepIndicator({
    required this.totalSteps,
    required this.currentStep,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF4A6CF7)
                            : isActive
                                ? const Color(0xFF4A6CF7).withValues(alpha: 0.4)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stepLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < totalSteps - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }
}

// ========== MODERN TEXT FIELD ==========

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? errorText;
  final IconData prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.errorText,
    required this.prefixIcon,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: errorText != null ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                prefixIcon,
                size: 20,
                color: errorText != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ========== MODERN PHONE FIELD ==========

class _ModernPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _ModernPhoneField({
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Telefɔni nimɔrɔ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: errorText != null ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text('🇲🇱', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 4),
                    Text(
                      '+223',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A6CF7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '76 00 00 00',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ========== MODERN PIN FIELD ==========

class _ModernPinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final String? errorText;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String>? onChanged;

  const _ModernPinField({
    required this.controller,
    required this.label,
    required this.obscure,
    this.errorText,
    required this.onToggleVisibility,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                letterSpacing: 0.3,
              ),
            ),
            GestureDetector(
              onTap: onToggleVisibility,
              child: Row(
                children: [
                  Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    obscure ? 'Jira' : 'Dogɔ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: errorText != null ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.lock_rounded,
                size: 20,
                color: errorText != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 4,   // ✅ PIN 4 chiffres
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '• • • •',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 4,
                    ),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}