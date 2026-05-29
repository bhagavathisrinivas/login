import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// This page is opened when the user taps the reset link in their email.
/// It receives the [oobCode] extracted from the deep link URL and
/// lets the user set a new password via Firebase.
class ResetPasswordPage extends StatefulWidget {
  final String oobCode; // action code from the email link

  const ResetPasswordPage({super.key, required this.oobCode});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState>  _formKey    = GlobalKey<FormState>();
  final TextEditingController _passCtrl   = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  bool _isSuccess      = false; // flips to success view after reset

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg1         = Color(0xFF0A0A1A);
  static const Color _accent      = Color(0xFF7C6FFF);
  static const Color _accentLight = Color(0xFF9D93FF);
  static const Color _teal        = Color(0xFF4ECDC4);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Firebase: confirm password reset ─────────────────────────────────────
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Verify the oobCode is still valid first
      await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);

      // Apply the new password
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _passCtrl.text,
      );

      // Animate into success state
      await _animCtrl.reverse();
      if (mounted) setState(() => _isSuccess = true);
      _animCtrl.forward();
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code));
    } catch (_) {
      _toast('Something went wrong. Please request a new reset link.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'This reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This reset link is invalid or already used.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this reset link.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Check your internet connection and retry.';
      default:
        return 'Reset failed. Please request a new reset link.';
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13.5))),
        ]),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.8),
                radius: 1.4,
                colors: <Color>[Color(0xFF1E1847), _bg1],
              ),
            ),
          ),
          // Glow blobs
          Positioned(
            top: -80,
            right: -80,
            child: _Glow(
                color: _accent.withValues(alpha: 0.18), size: 280),
          ),
          Positioned(
            bottom: 60,
            left: -60,
            child: _Glow(
                color: _teal.withValues(alpha: 0.12), size: 220),
          ),
          // Dot grid
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _DotGridPainter(),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _isSuccess
                      ? _buildSuccessView()
                      : _buildFormView(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORM VIEW — user enters new password
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 56),

        // Badge icon
        _BadgeIcon(icon: Icons.lock_outline_rounded, color: _accent),
        const SizedBox(height: 24),

        // Heading
        const Text(
          'Set New\nPassword 🔒',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your new password must be different\nfrom your previous password.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14.5,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 36),

        // Form
        Form(
          key: _formKey,
          child: Column(children: <Widget>[
            // New Password
            _AppTextField(
              controller: _passCtrl,
              label: 'New Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePass,
              suffixWidget: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePass = !_obscurePass),
                child: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              validator: (String? v) {
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 6) return 'Minimum 6 characters';
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return 'Include at least one uppercase letter';
                }
                if (!RegExp(r'[0-9]').hasMatch(v)) {
                  return 'Include at least one number';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password
            _AppTextField(
              controller: _confirmCtrl,
              label: 'Confirm New Password',
              prefixIcon: Icons.lock_reset_outlined,
              obscureText: _obscureConfirm,
              suffixWidget: GestureDetector(
                onTap: () => setState(
                    () => _obscureConfirm = !_obscureConfirm),
                child: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              validator: (String? v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password';
                }
                if (v != _passCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Strength hints
            _buildStrengthHints(),
          ]),
        ),
        const SizedBox(height: 36),

        // Submit button
        _GradientButton(
          label: 'Reset Password',
          icon: Icons.check_circle_outline_rounded,
          isLoading: _isLoading,
          onTap: _resetPassword,
        ),
        const SizedBox(height: 24),

        // Back to login
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            style:
                TextButton.styleFrom(foregroundColor: _accentLight),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.arrow_back_rounded, size: 14),
                SizedBox(width: 6),
                Text('Back to Sign In',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStrengthHints() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        _HintChip(
            label: '6+ chars',
            met: _passCtrl.text.length >= 6),
        _HintChip(
            label: 'Uppercase',
            met: RegExp(r'[A-Z]').hasMatch(_passCtrl.text)),
        _HintChip(
            label: 'Number',
            met: RegExp(r'[0-9]').hasMatch(_passCtrl.text)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUCCESS VIEW — password changed ✓
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 80),

        // Centre the success content
        Center(
          child: Column(children: <Widget>[
            // Animated tick badge
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[_teal, Color(0xFF00BCD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _teal.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Password\nUpdated! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Your password has been changed successfully.\nYou can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Success card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _teal.withValues(alpha: 0.25)),
              ),
              child: Row(children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_user_outlined,
                      color: _teal, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Account Secured',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text('Your new password is active',
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.5),
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded,
                    color: _teal, size: 20),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 48),

        // Sign In button
        _GradientButton(
          label: 'Sign In Now',
          icon: Icons.login_rounded,
          isLoading: false,
          onTap: () =>
              Navigator.pushReplacementNamed(context, '/login'),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

// ── Hint chip ─────────────────────────────────────────────────────────────────
class _HintChip extends StatelessWidget {
  final String label;
  final bool met;
  const _HintChip({required this.label, required this.met});

  static const Color _teal = Color(0xFF4ECDC4);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? _teal.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? _teal.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(
          met
              ? Icons.check_circle_outline_rounded
              : Icons.circle_outlined,
          size: 11,
          color: met ? _teal : Colors.white24,
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: met ? _teal : Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Badge icon ────────────────────────────────────────────────────────────────
class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _BadgeIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[color, color.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  static const Color _accent = Color(0xFF7C6FFF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[_accent, Color(0xFF5A4FE0)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _accent.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── App text field ────────────────────────────────────────────────────────────
class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixWidget;
  final String? Function(String?)? validator;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixWidget,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      validator: validator,
      onChanged: (_) {},
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5), fontSize: 13.5),
        prefixIcon: Icon(prefixIcon,
            color: const Color(0xFF7C6FFF), size: 20),
        suffixIcon: suffixWidget != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixWidget)
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.09), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF7C6FFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF5252), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        errorStyle:
            const TextStyle(color: Color(0xFFFF5252), fontSize: 11.5),
      ),
    );
  }
}

// ── Decorative ────────────────────────────────────────────────────────────────
class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: color,
              blurRadius: size / 1.4,
              spreadRadius: size / 4)
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const double spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
