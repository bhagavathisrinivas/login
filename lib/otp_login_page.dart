import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens (same as login_page.dart) ─────────────────────────────────
abstract class _T {
  static const Color bg       = Color(0xFF0B0B1E);
  static const Color accent   = Color(0xFF7C6FFF);
  static const Color accentLt = Color(0xFF9D93FF);
  static const Color teal     = Color(0xFF4ECDC4);

  static TextStyle display(double sz, {Color c = Colors.white}) =>
      GoogleFonts.syne(fontSize: sz, fontWeight: FontWeight.w800, color: c);

  static TextStyle body(double sz,
      {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.dmSans(
          fontSize: sz, fontWeight: w, color: color ?? Colors.white);

  static TextStyle muted(double sz) => GoogleFonts.dmSans(
      fontSize: sz, color: Colors.white.withValues(alpha: 0.45));
}

// ─── OTP Login Page ───────────────────────────────────────────────────────────
// Flow: Enter mobile → Send OTP → Enter 6-digit OTP → Verify → Navigate
class OtpLoginPage extends StatefulWidget {
  const OtpLoginPage({super.key});

  @override
  State<OtpLoginPage> createState() => _OtpLoginPageState();
}

class _OtpLoginPageState extends State<OtpLoginPage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  // 6 individual OTP digit controllers + focus nodes
  final List<TextEditingController> _otpCtrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  // ── State ──────────────────────────────────────────────────────────────────
  bool _codeSent    = false;   // true after verificationId received
  bool _isLoading   = false;
  bool _resending   = false;
  int  _resendSecs  = 60;      // countdown before allow resend
  Timer? _timer;

  String? _verificationId;
  int?    _forceResendToken;

  late AnimationController _anim;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ─── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendOtp({bool resend = false}) async {
    final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s|-'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(rawPhone)) {
      _toast('Enter a valid mobile number with country code (e.g. +91XXXXXXXXXX)',
          isError: true);
      return;
    }

    // Normalise: ensure +country-code prefix
    final phone = rawPhone.startsWith('+') ? rawPhone : '+91$rawPhone';

    setState(() => resend ? _resending = true : _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _forceResendToken,
      timeout: const Duration(seconds: 60),

      // ── Auto-retrieval (Android SMS hash) ──────────────────────────────────
      verificationCompleted: (PhoneAuthCredential cred) async {
        // Android only: auto-fills OTP
        setState(() => _isLoading = false);
        await _signInWithCredential(cred);
      },

      // ── Verification failed ────────────────────────────────────────────────
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading  = false;
          _resending  = false;
        });
        _toast(_friendlyError(e.code), isError: true);
      },

      // ── Code sent ─────────────────────────────────────────────────────────
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId  = verificationId;
          _forceResendToken = resendToken;
          _codeSent        = true;
          _isLoading       = false;
          _resending       = false;
          _resendSecs      = 60;
        });
        _startResendTimer();
        _toast('OTP sent to $phone', isError: false);
        // Auto-focus first OTP box
        Future.delayed(
          const Duration(milliseconds: 300),
              () => _otpFocus[0].requestFocus(),
        );
      },

      // ── Auto-retrieval timed out ───────────────────────────────────────────
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ─── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6) {
      _toast('Enter the complete 6-digit OTP.', isError: true);
      return;
    }
    if (_verificationId == null) {
      _toast('Verification session expired. Resend OTP.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code), isError: true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Sign in & route ───────────────────────────────────────────────────────
  Future<void> _signInWithCredential(PhoneAuthCredential cred) async {
    final userCred =
    await FirebaseAuth.instance.signInWithCredential(cred);
    final uid = userCred.user!.uid;

    // Fetch role from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      // First-time OTP user: create Firestore record
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid':       uid,
        'mobile':    userCred.user!.phoneNumber ?? '',
        'role':      'user',
        'isActive':  true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // Update lastSeen
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'lastSeen': FieldValue.serverTimestamp()});
    }

    final role = doc.data()?['role'] as String? ?? 'user';
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      role == 'admin' ? '/admin-dashboard' : '/home',
    );
  }

  // ─── Resend countdown ──────────────────────────────────────────────────────
  void _startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSecs <= 1) {
        t.cancel();
        setState(() => _resendSecs = 0);
      } else {
        setState(() => _resendSecs--);
      }
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-verification-code': return 'Incorrect OTP. Please try again.';
      case 'session-expired':           return 'OTP expired. Tap Resend.';
      case 'too-many-requests':         return 'Too many attempts. Try later.';
      case 'invalid-phone-number':      return 'Invalid phone number format.';
      case 'network-request-failed':    return 'Check your internet connection.';
      default:                          return 'Verification failed. Try again.';
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
                style: _T.body(13.5, color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
      backgroundColor:
      isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _T.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.9),
                radius: 1.5,
                colors: [Color(0xFF1C1650), _T.bg],
              ),
            ),
          ),
          Positioned(
            top: -70, right: -70,
            child: _GlowBlob(
                color: _T.accent.withValues(alpha: 0.18), size: 260),
          ),
          Positioned(
            bottom: 100, left: -55,
            child: _GlowBlob(
                color: _T.teal.withValues(alpha: 0.10), size: 200),
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
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildBackButton(),
                        const SizedBox(height: 28),
                        _buildLogo(),
                        const SizedBox(height: 24),
                        _buildHeading(),
                        const SizedBox(height: 36),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                      position: Tween<Offset>(
                                          begin:
                                          const Offset(0.05, 0),
                                          end: Offset.zero)
                                          .animate(anim),
                                      child: child)),
                          child: _codeSent
                              ? _buildOtpSection()
                              : _buildPhoneSection(),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Back button ───────────────────────────────────────────────────────────
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (_codeSent) {
          setState(() {
            _codeSent = false;
            _timer?.cancel();
            for (final c in _otpCtrls) c.clear();
          });
        } else {
          Navigator.maybePop(context);
        }
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(Icons.arrow_back_rounded,
            color: Colors.white.withValues(alpha: 0.7), size: 20),
      ),
    );
  }

  // ─── Logo ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_T.accent, Color(0xFF5A4FE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: _T.accent.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: const Icon(Icons.phonelink_lock_rounded,
          color: Colors.white, size: 28),
    );
  }

  // ─── Heading ───────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _codeSent ? 'Enter OTP 🔐' : 'OTP Login 📱',
          style: _T.display(32),
        ),
        const SizedBox(height: 8),
        Text(
          _codeSent
              ? 'We sent a 6-digit code to\n${_phoneCtrl.text.trim()}'
              : 'Enter your mobile number to receive\na one-time password.',
          style: _T.muted(14.5).copyWith(height: 1.6),
        ),
      ],
    );
  }

  // ─── Phase 1: Phone input ──────────────────────────────────────────────────
  Widget _buildPhoneSection() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone field
        _PhoneField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          accentColor: _T.accent,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Include country code, e.g. +91XXXXXXXXXX',
            style: _T.muted(12),
          ),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Send OTP',
          icon: Icons.send_rounded,
          onTap: _isLoading ? null : () => _sendOtp(),
          loading: _isLoading,
        ),
        const SizedBox(height: 24),
        _buildDivider(),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacementNamed(
                context, '/login'),
            style: TextButton.styleFrom(
              foregroundColor: _T.accentLt,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
            ),
            child: Text('Login with Password instead',
                style: _T.body(14,
                    color: _T.accentLt,
                    w: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Phase 2: OTP input ────────────────────────────────────────────────────
  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
            controller: _otpCtrls[i],
            focusNode: _otpFocus[i],
            accentColor: _T.accent,
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                _otpFocus[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _otpFocus[i - 1].requestFocus();
              }
              // Auto-verify when all 6 filled
              if (_otpCtrls.every((c) => c.text.isNotEmpty)) {
                _verifyOtp();
              }
            },
          )),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Verify OTP',
          icon: Icons.verified_rounded,
          onTap: _isLoading ? null : _verifyOtp,
          loading: _isLoading,
        ),
        const SizedBox(height: 24),

        // Resend row
        Center(
          child: _resendSecs > 0
              ? RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: 'Resend OTP in  ',
                  style: _T.muted(13.5)),
              TextSpan(
                  text: '${_resendSecs}s',
                  style: _T.body(13.5,
                      color: _T.accent,
                      w: FontWeight.w700)),
            ]),
          )
              : TextButton(
            onPressed: _resending
                ? null
                : () => _sendOtp(resend: true),
            style: TextButton.styleFrom(
              foregroundColor: _T.accentLt,
            ),
            child: _resending
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Color(0xFF9D93FF),
                    strokeWidth: 2))
                : Text('Resend OTP',
                style: _T.body(14,
                    color: _T.accentLt,
                    w: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ─── Primary CTA button ────────────────────────────────────────────────────
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool loading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_T.accent, Color(0xFF5A4FE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _T.accent.withValues(alpha: 0.42),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: loading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.2))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: Colors.white.withValues(alpha: 0.10),
                thickness: 1,
                height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR',
              style: _T.muted(11.5).copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        Expanded(
            child: Divider(
                color: Colors.white.withValues(alpha: 0.10),
                thickness: 1,
                height: 1)),
      ],
    );
  }
}

// ─── Phone Field ──────────────────────────────────────────────────────────────
class _PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final Color                 accentColor;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.accentColor,
  });

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
            () => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:    widget.controller,
      focusNode:     widget.focusNode,
      keyboardType:  TextInputType.phone,
      textInputAction: TextInputAction.done,
      style: GoogleFonts.dmSans(fontSize: 15, color: Colors.white),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        labelStyle: GoogleFonts.dmSans(
            fontSize: 13.5,
            color: _focused
                ? widget.accentColor
                : Colors.white.withValues(alpha: 0.40)),
        floatingLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _focused
                ? widget.accentColor
                : Colors.white.withValues(alpha: 0.55)),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 16),
          child: Icon(Icons.phone_rounded,
              size: 19,
              color: _focused
                  ? widget.accentColor
                  : Colors.white.withValues(alpha: 0.35)),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        filled:    true,
        fillColor: _focused
            ? widget.accentColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.055),
        contentPadding: const EdgeInsets.fromLTRB(0, 18, 18, 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: widget.accentColor, width: 1.5),
        ),
      ),
    );
  }
}

// ─── OTP Box ──────────────────────────────────────────────────────────────────
class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final Color                 accentColor;
  final ValueChanged<String>  onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
            () => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46, height: 56,
      decoration: BoxDecoration(
        color: _focused
            ? widget.accentColor.withValues(alpha: 0.12)
            : filled
            ? widget.accentColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? widget.accentColor
              : filled
              ? widget.accentColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.09),
          width: _focused ? 1.8 : 1.0,
        ),
        boxShadow: _focused
            ? [
          BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ]
            : [],
      ),
      child: TextFormField(
        controller:   widget.controller,
        focusNode:    widget.focusNode,
        textAlign:    TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength:    1,
        style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: widget.accentColor),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
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