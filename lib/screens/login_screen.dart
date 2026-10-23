import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import 'app_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _useEmail = false;
  String? _pinError;

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_fade);
    _entrance.forward();
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    setState(() => _pinError = null);

    if (_useEmail) {
      if (email.isEmpty || pin.isEmpty) {
        _showSnackBar('Aw ye fan bɛɛ dafa');
        return;
      }
    } else {
      if (phone.isEmpty || pin.isEmpty) {
        _showSnackBar('Aw ye fan bɛɛ dafa');
        return;
      }
    }

    if (pin.length < 4) {
      setState(() => _pinError = 'I ka gundo nimɔrɔ naani sɛbɛn');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final error = await ServiceLocator.instance.auth.signIn(
        phone: _useEmail ? null : phone,
        email: _useEmail ? email : null,
        pin: pin,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        _showSnackBar(error);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Ɛntɛrinɛti tɛ se ka don. I ka rezo lajɛ.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const AppShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocusNode.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 247, 248, 249),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Header collé au bord supérieur (pas de SafeArea)
                _buildCompactHero(),

                // ✅ Contenu dans la zone sûre
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Aw bisimila',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Don walasa ka i ka wari ci kɛ.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _LoginModeSwitch(
                          useEmail: _useEmail,
                          onChanged: (v) => setState(() => _useEmail = v),
                        ),
                        const SizedBox(height: 18),

                        if (_useEmail)
                          _ModernEmailField(
                            controller: _emailCtrl,
                            onSubmitted: () =>
                                FocusScope.of(context).requestFocus(_pinFocusNode),
                          )
                        else
                          _ModernPhoneField(
                            controller: _phoneCtrl,
                            onSubmitted: () =>
                                FocusScope.of(context).requestFocus(_pinFocusNode),
                          ),
                        const SizedBox(height: 18),

                        _ModernPinField(
                          controller: _pinCtrl,
                          focusNode: _pinFocusNode,
                          obscure: _obscurePin,
                          errorText: _pinError,
                          onToggleVisibility: () =>
                              setState(() => _obscurePin = !_obscurePin),
                          onCompleted: _login,
                          onChanged: (_) => setState(() => _pinError = null),
                        ),
                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showSnackBar('Nin baara bɛna kɛ sɔɔni'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text(
                              'I ɲinɛna i ka gundo nimɔrɔ kɔ wa?',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A6CF7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A6CF7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              disabledBackgroundColor:
                                  const Color(0xFF4A6CF7).withValues(alpha: 0.6),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Ka don',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Container(height: 1, color: const Color(0xFFE2E8F0)),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'walima',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(height: 1, color: const Color(0xFFE2E8F0)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Kɔnti t'i bolo?",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      transitionDuration:
                                          const Duration(milliseconds: 280),
                                      pageBuilder: (_, __, ___) =>
                                          const RegisterScreen(),
                                      transitionsBuilder: (_, anim, __, child) =>
                                          FadeTransition(opacity: anim, child: child),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 28),
                                ),
                                child: const Text(
                                  'Kɔnti kura',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4A6CF7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const _ModernTrustRow(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER — collé au bord supérieur
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCompactHero() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 21, 32, 87),
            Color.fromARGB(255, 46, 74, 176),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(50, 21, 32, 87),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo compact avec gradient
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A6CF7), Color(0xFF6B4CF7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Titre + sous-titre
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mobile Bamking',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wari sarali lakanalen',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge sɔnnen
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Sɔnnen',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========== LOGIN MODE SWITCH ==========

class _LoginModeSwitch extends StatelessWidget {
  final bool useEmail;
  final ValueChanged<bool> onChanged;

  const _LoginModeSwitch({required this.useEmail, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: !useEmail ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: !useEmail
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Telefɔni',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: !useEmail ? FontWeight.w700 : FontWeight.w500,
                    color: !useEmail ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: useEmail ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: useEmail
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Imeli',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: useEmail ? FontWeight.w700 : FontWeight.w500,
                    color: useEmail ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  const _ModernPhoneField({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Telefɔni nimɔrɔ',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569), letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Text('🇲🇱', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 3),
                    Text('+223', style: TextStyle(fontWeight: FontWeight.w700, color: Color.fromARGB(255, 10, 11, 12), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: (_) => onSubmitted?.call(),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '76 00 00 00',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400, fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernEmailField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  const _ModernEmailField({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imeli adirɛsi',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569), letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.email_outlined, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: (_) => onSubmitted?.call(),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'misali@imeli.com',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400, fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernPinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final String? errorText;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCompleted;
  final ValueChanged<String> onChanged;

  const _ModernPinField({
    required this.controller,
    required this.focusNode,
    required this.obscure,
    this.errorText,
    required this.onToggleVisibility,
    required this.onCompleted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gundo nimɔrɔ (PIN)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569), letterSpacing: 0.3),
            ),
            GestureDetector(
              onTap: onToggleVisibility,
              child: Row(
                children: [
                  Icon(
                    obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 16,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    obscure ? 'A jira' : 'A dogo',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
              width: errorText != null ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.lock_rounded,
                size: 18,
                color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  textAlignVertical: TextAlignVertical.center,
                  maxLength: 6,
                  onChanged: onChanged,
                  onSubmitted: (_) => onCompleted(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), letterSpacing: 4),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '• • • •',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400, letterSpacing: 4, fontSize: 15),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_rounded, size: 13, color: Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModernTrustRow extends StatelessWidget {
  const _ModernTrustRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          _trustItem(Icons.shield_rounded, 'Lakanalen', const Color(0xFF4A6CF7)),
          _divider(),
          _trustItem(Icons.class_rounded, 'Teliya', const Color(0xFF8B5CF6)),
          _divider(),
          _trustItem(Icons.headset_mic_rounded, 'Dɛmɛ tuma bɛɛ', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: const Color(0xFFE2E8F0));
}