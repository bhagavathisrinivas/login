import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({super.key});

  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _mobileCtrl    = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _adminKeyCtrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _obscureKey     = true;
  bool _isLoading      = false;

  late AnimationController _anim;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  static const _bg       = Color(0xFF0B0B1E);
  static const _rose     = Color(0xFFFF6B8A);
  static const _gold     = Color(0xFFFFB347);
  static const _purple   = Color(0xFF7C6FFF);
  static const _teal     = Color(0xFF4ECDC4);

  // !! Change this in production — ideally fetch from Firebase Remote Config
  static const _adminSecretKey = 'ADMIN@2024#SECRET';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _adminKeyCtrl.dispose();
    super.dispose();
  }

  // ─── Register ──────────────────────────────────────────────────────────────
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1 — Verify secret key
      if (_adminKeyCtrl.text.trim() != _adminSecretKey) {
        _toast('Invalid admin secret key. Access denied.', isError: true);
        return;
      }

      // 2 — Check email not already admin
      final emailCheck = await FirebaseFirestore.instance
          .collection('admins')
          .where('email',
          isEqualTo: _emailCtrl.text.trim().toLowerCase())
          .limit(1)
          .get();
      if (emailCheck.docs.isNotEmpty) {
        _toast('This email is already registered as admin.', isError: true);
        return;
      }

      // 3 — Create Firebase Auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());

      // 4 — Save to 'admins' collection
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(cred.user!.uid)
          .set({
        'uid':       cred.user!.uid,
        'name':      _nameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim().toLowerCase(),
        'mobile':    _mobileCtrl.text.trim(),
        'role':      'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5 — Also save role tag to 'users' collection for auth gate lookup
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'uid':   cred.user!.uid,
        'name':  _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'role':  'admin',
      });

      _toast('Admin account created!', isError: false);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      }
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code), isError: true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This email is already in use.';
      case 'weak-password':        return 'Password is too weak.';
      case 'invalid-email':        return 'Enter a valid email.';
      default:                     return 'Registration failed. Try again.';
    }
  }

  void _toast(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 13.5, color: Colors.white),
                overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
      backgroundColor:
      isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.5, -0.8),
                radius: 1.4,
                colors: [Color(0xFF2B0A1A), _bg],
              ),
            ),
          ),
          Positioned(
            top: -60, right: -60,
            child: _GlowBlob(
                color: _rose.withValues(alpha: 0.16), size: 240),
          ),
          Positioned(
            bottom: 60, left: -60,
            child: _GlowBlob(
                color: _gold.withValues(alpha: 0.10), size: 200),
          ),
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _DotGridPainter(),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: Column(
                              children: [
                                _buildAdminBadge(),
                                const SizedBox(height: 20),
                                _buildPersonalSection(),
                                const SizedBox(height: 14),
                                _buildPasswordSection(),
                                const SizedBox(height: 14),
                                _buildAdminKeySection(),
                                const SizedBox(height: 28),
                                _buildRegisterButton(),
                                const SizedBox(height: 20),
                                _buildLoginLink(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Registration',
                  style: GoogleFonts.syne(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text('Create a new administrator account',
                  style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _rose.withValues(alpha: 0.18),
            _gold.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _rose.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_rose, Color(0xFFCC3D5E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _rose.withValues(alpha: 0.40),
                    blurRadius: 14, offset: const Offset(0, 5))
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Administrator Account',
                    style: GoogleFonts.syne(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  'Requires a valid admin secret key.',
                  style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection() {
    return _SectionCard(
      title: 'PERSONAL INFO',
      icon: Icons.badge_outlined,
      color: _purple,
      child: Column(
        children: [
          _AdminField(
            controller: _nameCtrl,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            color: _purple,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              if (v.trim().length < 2) return 'Enter your full name';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AdminField(
            controller: _emailCtrl,
            label: 'Email Address',
            icon: Icons.email_outlined,
            color: _purple,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AdminField(
            controller: _mobileCtrl,
            label: 'Mobile Number',
            icon: Icons.phone_outlined,
            color: _purple,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Mobile is required';
              if (v.length < 10) return 'Enter a valid mobile number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final p = _passCtrl.text;
    return _SectionCard(
      title: 'PASSWORD',
      icon: Icons.lock_outline_rounded,
      color: _rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            color: _rose,
            obscureText: _obscurePass,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePass = !_obscurePass),
              child: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38, size: 19,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Minimum 8 characters';
              if (!RegExp(r'[A-Z]').hasMatch(v)) {
                return 'Include at least one uppercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(v)) {
                return 'Include at least one number';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _Chip(label: '8+ chars',  met: p.length >= 8, color: _teal),
              _Chip(label: 'Uppercase', met: RegExp(r'[A-Z]').hasMatch(p), color: _teal),
              _Chip(label: 'Number',    met: RegExp(r'[0-9]').hasMatch(p), color: _teal),
              _Chip(label: 'Special',   met: RegExp(r'[!@#\$%^&*]').hasMatch(p), color: _teal),
            ],
          ),
          const SizedBox(height: 14),
          _AdminField(
            controller: _confirmCtrl,
            label: 'Confirm Password',
            icon: Icons.lock_reset_rounded,
            color: _rose,
            obscureText: _obscureConfirm,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38, size: 19,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your password';
              }
              if (v != _passCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKeySection() {
    return _SectionCard(
      title: 'ADMIN SECRET KEY',
      icon: Icons.vpn_key_rounded,
      color: _gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: _gold.withValues(alpha: 0.8), size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This key is provided by the system administrator. '
                        'Unauthorized access is prohibited.',
                    style: GoogleFonts.dmSans(
                        color: _gold.withValues(alpha: 0.75),
                        fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AdminField(
            controller: _adminKeyCtrl,
            label: 'Admin Secret Key',
            icon: Icons.key_rounded,
            color: _gold,
            obscureText: _obscureKey,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureKey = !_obscureKey),
              child: Icon(
                _obscureKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38, size: 19,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Admin secret key is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_rose, Color(0xFFCC3D5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _rose.withValues(alpha: 0.42),
                blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.2))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Create Admin Account',
                  style: GoogleFonts.syne(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(
              text: 'Already have an admin account?  ',
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13.5)),
          TextSpan(
            text: 'Sign In',
            style: GoogleFonts.dmSans(
                color: _rose,
                fontWeight: FontWeight.w700,
                fontSize: 13.5),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  Navigator.pushReplacementNamed(context, '/login'),
          ),
        ]),
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Color    color;
  final Widget   child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 7),
              Text(title,
                  style: GoogleFonts.dmSans(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Admin Field ──────────────────────────────────────────────────────────────
class _AdminField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label;
  final IconData                   icon;
  final Color                      color;
  final bool                       obscureText;
  final Widget?                    suffix;
  final TextInputType?             keyboardType;
  final TextCapitalization         textCapitalization;
  final List<TextInputFormatter>?  inputFormatters;
  final String? Function(String?)? validator;

  const _AdminField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    this.obscureText        = false,
    this.suffix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:         controller,
      obscureText:        obscureText,
      keyboardType:       keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters:    inputFormatters,
      validator:          validator,
      style: GoogleFonts.dmSans(fontSize: 14.5, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.dmSans(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.45)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 12),
          child: Icon(icon, color: color, size: 19),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix != null
            ? Padding(
            padding: const EdgeInsets.only(right: 14),
            child: suffix)
            : null,
        suffixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.055),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 1.5),
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
        errorStyle: GoogleFonts.dmSans(
            color: const Color(0xFFFF5252), fontSize: 11.5),
      ),
    );
  }
}

// ─── Strength Chip ────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool   met;
  final Color  color;
  const _Chip({required this.label, required this.met, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
            size: 11,
            color: met ? color : Colors.white24,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: met ? color : Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Decorative ───────────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color  color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color,
              blurRadius: size / 1.3,
              spreadRadius: size / 5)
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028);
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}