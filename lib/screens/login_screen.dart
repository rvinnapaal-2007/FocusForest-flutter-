import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/forest_tree.dart';
import '../services/auth_service.dart';
import '../widgets/forest_painters.dart';
import '../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _info;
  bool _authHelp = false; // show "create account / reset password" shortcuts after a failed sign-in

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _authHelp = false;
    });
    try {
      await action();
      // On success AuthGate switches screens automatically.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AuthService.friendlyError(e);
          _authHelp = !_isSignUp &&
              e is FirebaseAuthException &&
              const ['invalid-credential', 'invalid-login-credentials', 'wrong-password', 'user-not-found'].contains(e.code);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    if (_isSignUp && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    await _run(() => _isSignUp
        ? AuthService.instance.signUp(_nameCtrl.text, email, pass)
        : AuthService.instance.signIn(email, pass));
  }

  Future<void> _forgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Type your email above first, then tap "Forgot password".';
        _info = null;
      });
      return;
    }
    await _run(() async {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) setState(() => _info = 'Password reset link sent to $email');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GrowingTree(species: TreeSpecies.binaryTree, height: 190),
                    const SizedBox(height: 4),
                    const FocusForestLogo(height: 64),
                    const SizedBox(height: 10),
                    Text(
                      AppConfig.tagline,
                      style: TextStyle(color: const Color(0xFFA7F3D0).withValues(alpha: 0.9), fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    _glassCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF06231B).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _modeToggle(),
                const SizedBox(height: 18),
                if (_isSignUp) ...[
                  _field(_nameCtrl, 'Your name', Icons.person_outline_rounded, hints: const [AutofillHints.name]),
                  const SizedBox(height: 12),
                ],
                _field(_emailCtrl, 'Email', Icons.mail_outline_rounded,
                    keyboard: TextInputType.emailAddress, hints: const [AutofillHints.email]),
                const SizedBox(height: 12),
                _field(
                  _passCtrl,
                  'Password',
                  Icons.lock_outline_rounded,
                  obscure: _obscure,
                  hints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                  onSubmit: _submit,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgot,
                      child: const Text('Forgot password?', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                if (_error != null) _message(_error!, const Color(0xFFEF4444), Icons.error_outline_rounded),
                if (_authHelp) _authHelpBox(),
                if (_info != null) _message(_info!, const Color(0xFF34D399), Icons.check_circle_outline_rounded),
                const SizedBox(height: 6),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(_isSignUp ? '🌱  Create account & plant my first tree' : '🌲  Sign in',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(AuthService.instance.signInWithGoogle),
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFBBF24))),
                    label: const Text('Continue with Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _authHelpBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not sure what went wrong? Try one of these:',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '- Created your account with Google? It has no password yet. Tap "Continue with Google", or "Set a password by email".\n'
            '- No account yet with this email? Create one.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            TextButton(
              onPressed: _busy ? null : () => _run(AuthService.instance.signInWithGoogle),
              child: const Text('Continue with Google', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12.5)),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _isSignUp = true;
                        _error = null;
                        _authHelp = false;
                      }),
              child: const Text('Create account', style: TextStyle(color: Color(0xFF34D399), fontSize: 12.5)),
            ),
            TextButton(
              onPressed: _busy ? null : _forgot,
              child: const Text('Set a password by email', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: _busy ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: selected ? Colors.white : Colors.white60, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        tab('Sign in', !_isSignUp, () => setState(() {
              _isSignUp = false;
              _error = null;
              _info = null;
            })),
        tab('Create account', _isSignUp, () => setState(() {
              _isSignUp = true;
              _error = null;
              _info = null;
            })),
      ]),
    );
  }

  Widget _message(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12.5, height: 1.3))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false,
      TextInputType? keyboard,
      Iterable<String>? hints,
      Widget? suffix,
      VoidCallback? onSubmit}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      autofillHints: hints,
      enabled: !_busy,
      style: const TextStyle(color: Colors.white),
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFF34D399), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF34D399))),
      ),
    );
  }
}
