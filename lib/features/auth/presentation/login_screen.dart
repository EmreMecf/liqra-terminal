import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _emailFocus  = FocusNode();
  final _passFocus   = FocusNode();

  bool   _obscure    = true;
  bool   _rememberMe = false;
  bool   _loading    = false;
  String? _errorMsg;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Giriş ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      await AuthService.instance.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        rememberMe: _rememberMe,
      );
      // AuthService.isLoggedIn değişince main.dart'taki Consumer AppShell'e geçer
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080F),
      body: Stack(
        children: [
          // Arka plan ışıltısı
          _BackgroundGlow(),
          // İçerik
          FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Logo(),
                      const SizedBox(height: 40),
                      _Card(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle('Giriş Yap'),
                              const SizedBox(height: 24),

                              // E-posta
                              _PosTextField(
                                controller:  _emailCtrl,
                                focusNode:   _emailFocus,
                                label:       'E-posta adresi',
                                icon:        Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).requestFocus(_passFocus),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'E-posta adresinizi girin.';
                                  }
                                  if (!v.contains('@')) return 'Geçerli bir e-posta girin.';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Şifre
                              _PosTextField(
                                controller:  _passCtrl,
                                focusNode:   _passFocus,
                                label:       'Şifre',
                                icon:        Icons.lock_outline_rounded,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Şifrenizi girin.';
                                  if (v.length < 6) return 'Şifre en az 6 karakter olmalı.';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Beni Hatırla
                              _RememberMeRow(
                                value:    _rememberMe,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                              ),

                              const SizedBox(height: 8),

                              // Hata mesajı
                              if (_errorMsg != null) ...[
                                _ErrorBanner(message: _errorMsg!),
                                const SizedBox(height: 16),
                              ],

                              const SizedBox(height: 8),

                              // Giriş butonu
                              _LoginButton(
                                loading:   _loading,
                                onPressed: _loading ? null : _login,
                              ),

                              const SizedBox(height: 16),

                              // Şifremi Unuttum
                              Center(
                                child: TextButton(
                                  onPressed: _loading ? null : _showPasswordReset,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white38,
                                  ),
                                  child: const Text(
                                    'Şifreni mi unuttun?',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                      _Footer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Şifre sıfırlama dialog ────────────────────────────────────────────────
  void _showPasswordReset() {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Şifre Sıfırlama',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kayıtlı e-posta adresinize şifre sıfırlama bağlantısı gönderilecek.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _PosTextField(
              controller: ctrl,
              label: 'E-posta adresi',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Şifre sıfırlama bağlantısı gönderildi.'),
                  backgroundColor: Color(0xFF0AFFE0),
                ),
              );
            },
            child: const Text(
              'Gönder',
              style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Alt bileşenler
// ════════════════════════════════════════════════════════════════════

class _BackgroundGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -120,
      left: -120,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.teal.withOpacity(0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Liqra logo — teal "L" + beyaz metin
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(
                text: 'L',
                style: TextStyle(color: AppColors.teal),
              ),
              TextSpan(
                text: 'iqra',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold.withOpacity(0.6)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Terminal Pro  ·  POS Kasası',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withOpacity(0.06),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _PosTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode?          focusNode;
  final String              label;
  final IconData            icon;
  final bool                obscureText;
  final Widget?             suffix;
  final TextInputType?      keyboardType;
  final TextInputAction?    textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  const _PosTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.icon,
    this.obscureText    = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      focusNode:       focusNode,
      obscureText:     obscureText,
      keyboardType:    keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator:       validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: AppColors.teal,
      decoration: InputDecoration(
        labelText:      label,
        labelStyle:     const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon:     Icon(icon, color: Colors.white30, size: 18),
        suffixIcon:     suffix,
        filled:         true,
        fillColor:      Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.accentRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.accentRed, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.accentRed, fontSize: 12),
      ),
    );
  }
}

class _RememberMeRow extends StatelessWidget {
  final bool    value;
  final ValueChanged<bool?> onChanged;
  const _RememberMeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value:           value,
            onChanged:       onChanged,
            activeColor:     AppColors.teal,
            checkColor:      Colors.black,
            side:            const BorderSide(color: Colors.white30),
            shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: const Text(
            'Beni hatırla',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColors.accentRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.accentRed.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.accentRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:    AppColors.accentRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool     loading;
  final VoidCallback? onPressed;
  const _LoginButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? AppColors.tealGradient
              : const LinearGradient(colors: [Colors.white12, Colors.white12]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppColors.teal.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor:     Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    color:       Colors.black,
                    fontSize:    15,
                    fontWeight:  FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Liqra Terminal Pro  v2.0',
      style: TextStyle(color: Colors.white12, fontSize: 11),
    );
  }
}
