import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState>  _formKey   = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false; // flips to success view after sending

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Palette ── same as login_page.dart ───────────────────────────────────
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
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Firebase: send reset email ────────────────────────────────────────────
  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );

      // Animate cross-fade into success view
      await _animCtrl.reverse();
      if (mounted) setState(() => _emailSent = true);
      _animCtrl.forward();
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code));
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Check your internet connection and retry.';
      default:
        return 'Failed to send reset email. Please try again.';
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
              child:
                  Text(msg, style: const TextStyle(fontSize: 13.5))),
        ]),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
          // Background — same radial as login_page
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28),
                  child: _emailSent
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
  // FORM VIEW  (matches screenshot exactly)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 56),

        // ── Back arrow ──────────────────────────────────────────────────
        _BackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(height: 28),

        // ── Purple badge icon ───────────────────────────────────────────
        _BadgeIcon(icon: Icons.lock_reset_rounded, color: _accent),
        const SizedBox(height: 24),

        // ── Heading ─────────────────────────────────────────────────────
        const Text(
          'Forgot\nPassword 🔐',
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
          'Enter your email to receive a password reset link.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),

        // ── Email field ─────────────────────────────────────────────────
        Form(
          key: _formKey,
          child: _AppTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (String? v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 32),

        // ── Send Reset Link button ──────────────────────────────────────
        _GradientButton(
          label: 'Send Reset Link',
          icon: Icons.send_rounded,
          isLoading: _isLoading,
          onTap: _sendResetEmail,
        ),
        const SizedBox(height: 28),

        // ── Back to Sign In link ────────────────────────────────────────
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style:
                TextButton.styleFrom(foregroundColor: _accentLight),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.arrow_back_rounded, size: 14),
                SizedBox(width: 6),
                Text('Back to Sign In',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUCCESS VIEW  (shown after email is sent)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 56),
        _BackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(height: 28),

        // Teal badge — different icon to signal success
        _BadgeIcon(
            icon: Icons.mark_email_read_outlined, color: _teal),
        const SizedBox(height: 24),

        const Text(
          'Check your\nInbox 📬',
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
          'A password reset link has been sent to:',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14.5),
        ),
        const SizedBox(height: 12),

        // Email pill
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _teal.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.email_outlined,
                  color: _teal, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _emailCtrl.text.trim(),
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Steps card
        _buildStepsCard(),
        const SizedBox(height: 36),

        // Back to Sign In primary button
        _GradientButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          isLoading: false,
          onTap: () =>
              Navigator.pushReplacementNamed(context, '/login'),
        ),
        const SizedBox(height: 20),

        // Resend link
        Center(
          child: TextButton(
            onPressed: () async {
              await _animCtrl.reverse();
              if (mounted) setState(() => _emailSent = false);
              _animCtrl.forward();
            },
            style: TextButton.styleFrom(
                foregroundColor: _accentLight),
            child: const Text(
              "Didn't receive it? Resend",
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStepsCard() {
    const List<_StepData> steps = <_StepData>[
      _StepData('1', 'Open the email we sent you',   _accent),
      _StepData('2', 'Tap the reset link inside',     _teal),
      _StepData('3', 'Create your new password',      Color(0xFFFFB347)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WHAT\'S NEXT?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((_StepData s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.color.withValues(alpha: 0.15),
                    border: Border.all(
                        color: s.color.withValues(alpha: 0.35)),
                  ),
                  child: Center(
                    child: Text(s.number,
                        style: TextStyle(
                            color: s.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(s.label,
                      style: TextStyle(
                          color:
                              Colors.white.withValues(alpha: 0.75),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Step data model ───────────────────────────────────────────────────────────
class _StepData {
  final String number;
  final String label;
  final Color color;
  const _StepData(this.number, this.label, this.color);
}

// ── Reusable back button ──────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 17,
        ),
      ),
    );
  }
}

// ── Badge icon (circle with gradient) ────────────────────────────────────────
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

// ── Gradient button (matches login_page.dart style) ───────────────────────────
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

// ── App text field ─────────────────────────────────────────────────────────────
class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13.5),
        prefixIcon: Icon(prefixIcon,
            color: const Color(0xFF7C6FFF), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.09), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFF7C6FFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFFF5252), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFFF5252), width: 1.5),
        ),
        errorStyle: const TextStyle(
            color: Color(0xFFFF5252), fontSize: 11.5),
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
