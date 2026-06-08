import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';


// ─── Design Tokens ────────────────────────────────────────────────────────────
abstract class _T {
  static const Color bg       = Color(0xFF0B0B1E);
  static const Color accent   = Color(0xFF7C6FFF); // user color
  static const Color accentLt = Color(0xFF9D93FF);
  static const Color adminClr = Color(0xFFFF6B8A); // admin color
  static const Color adminLt  = Color(0xFFFF9DB3);
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

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PAGE  (Password login — User & Admin)
// ─────────────────────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus   = FocusNode();

  bool _isAdmin   = false;
  bool _useEmail  = true;
  bool _isLoading = false;
  bool _obscure   = true;

  late AnimationController _anim;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  Color get _activeColor => _isAdmin ? _T.adminClr : _T.accent;

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
  }

  @override
  void dispose() {
    _anim.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Sign In ─────────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      _isAdmin ? await _adminSignIn() : await _userSignIn();
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyPwError(e.code), isError: true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _userSignIn() async {
    String email = _identifierCtrl.text.trim();
    if (!_useEmail) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('mobile', isEqualTo: email)
          .where('role', isEqualTo: 'user')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        throw Exception('No user account found for this mobile number.');
      }
      email = snap.docs.first.data()['email'] as String;
    }
    final cred = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: _passwordCtrl.text.trim());
    final doc  = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
    final role = doc.data()?['role'] as String? ?? 'user';
    if (role == 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception('This is an admin account. Use admin login.');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _adminSignIn() async {
    final email = _identifierCtrl.text.trim();
    final cred  = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: _passwordCtrl.text.trim());
    final doc  = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
    final role = doc.data()?['role'] as String? ?? 'user';
    if (role != 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception('Access denied. No admin privileges.');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/admin-dashboard');
  }

  String _friendlyPwError(String code) {
    switch (code) {
      case 'user-not-found':         return 'No account found with this email.';
      case 'wrong-password':         return 'Incorrect password. Please try again.';
      case 'too-many-requests':      return 'Too many attempts. Try again later.';
      case 'network-request-failed': return 'Check your internet connection.';
      default:                       return 'Sign-in failed. Check your credentials.';
    }
  }

  void _toast(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 17,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: _T.body(13.5, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ]),
      backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: _T.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.9),
              radius: 1.5,
              colors: _isAdmin
                  ? [const Color(0xFF2B0A1A), _T.bg]
                  : [const Color(0xFF1C1650), _T.bg],
            ),
          ),
        ),
        Positioned(
          top: -70, right: -70,
          child: _GlowBlob(color: _activeColor.withValues(alpha: 0.18), size: 260),
        ),
        Positioned(
          bottom: 100, left: -55,
          child: _GlowBlob(color: _T.teal.withValues(alpha: 0.10), size: 200),
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
                      _buildRoleToggle(),
                      const SizedBox(height: 32),
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildHeading(),
                      const SizedBox(height: 32),
                      if (!_isAdmin) ...[
                        _buildEmailMobileToggle(),
                        const SizedBox(height: 22),
                      ],
                      _buildForm(),
                      const SizedBox(height: 28),
                      _buildSignInButton(),
                      // ── OTP login button (user only) ────────────────────────
                      if (!_isAdmin) ...[
                        const SizedBox(height: 16),
                        _buildOtpButton(),
                      ],
                      const SizedBox(height: 28),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildBottomLink(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Role Toggle ─────────────────────────────────────────────────────────────
  Widget _buildRoleToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        _RoleTab(
          label: 'User Login',
          icon: Icons.person_outline_rounded,
          selected: !_isAdmin,
          color: _T.accent,
          onTap: () => setState(() {
            _isAdmin = false;
            _identifierCtrl.clear();
            _passwordCtrl.clear();
            _formKey.currentState?.reset();
          }),
        ),
        _RoleTab(
          label: 'Admin Login',
          icon: Icons.admin_panel_settings_outlined,
          selected: _isAdmin,
          color: _T.adminClr,
          onTap: () => setState(() {
            _isAdmin = true;
            _identifierCtrl.clear();
            _passwordCtrl.clear();
            _formKey.currentState?.reset();
          }),
        ),
      ]),
    );
  }

  // ── Logo ────────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 58, height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: _isAdmin
              ? [_T.adminClr, const Color(0xFFCC3D5E)]
              : [_T.accent, const Color(0xFF5A4FE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _activeColor.withValues(alpha: 0.42),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        _isAdmin ? Icons.admin_panel_settings_rounded : Icons.bolt_rounded,
        color: Colors.white, size: 30,
      ),
    );
  }

  // ── Heading ─────────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _isAdmin ? 'Admin Login' : 'Welcome Back 👋',
            style: _T.display(32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isAdmin
              ? 'Sign in to access the admin dashboard.'
              : 'Sign in to pick up where you left off.',
          style: _T.muted(14.5).copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ── Email / Mobile Toggle ───────────────────────────────────────────────────
  Widget _buildEmailMobileToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        _SmallTab(
          label: 'Email',
          icon: Icons.email_outlined,
          selected: _useEmail,
          color: _T.accent,
          onTap: () => setState(() {
            _useEmail = true;
            _identifierCtrl.clear();
          }),
        ),
        _SmallTab(
          label: 'Mobile',
          icon: Icons.phone_outlined,
          selected: !_useEmail,
          color: _T.accent,
          onTap: () => setState(() {
            _useEmail = false;
            _identifierCtrl.clear();
          }),
        ),
      ]),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _LoginField(
            controller: _identifierCtrl,
            focusNode: _identifierFocus,
            label: _isAdmin
                ? 'Admin Email'
                : (_useEmail ? 'Email Address' : 'Mobile Number'),
            icon: _isAdmin
                ? Icons.alternate_email
                : (_useEmail ? Icons.email_outlined : Icons.phone_outlined),
            accentColor: _activeColor,
            keyboardType: (!_isAdmin && !_useEmail)
                ? TextInputType.phone
                : TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onEditingComplete: () => _passwordFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'This field is required';
              if (_isAdmin || _useEmail) {
                if (!RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(v)) return 'Enter a valid email address';
              } else {
                if (!RegExp(r'^\+?[0-9]{10,15}$')
                    .hasMatch(v.replaceAll(RegExp(r'\s|-'), '')))
                  return 'Enter a valid mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _LoginField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            accentColor: _activeColor,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onEditingComplete: _signIn,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 20,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
            style: TextButton.styleFrom(
              foregroundColor: _activeColor,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Forgot Password?',
                style: _T.body(13,
                    color: _isAdmin ? _T.adminLt : _T.accentLt,
                    w: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Sign-In Button ──────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAdmin
                ? [_T.adminClr, const Color(0xFFCC3D5E)]
                : [_T.accent, const Color(0xFF5A4FE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _activeColor.withValues(alpha: 0.42),
              blurRadius: 22, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _signIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isAdmin ? Icons.admin_panel_settings_rounded : Icons.login_rounded,
                color: Colors.white, size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isAdmin ? 'Admin Sign In' : 'Sign In',
                style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── NEW: OTP Login Button ───────────────────────────────────────────────────
  Widget _buildOtpButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OtpLoginPage()),
        ),
        icon: const Icon(Icons.phonelink_lock_rounded,
            color: _T.accent, size: 18),
        label: Text(
          'Login with OTP',
          style: GoogleFonts.syne(
              fontSize: 15, fontWeight: FontWeight.w700, color: _T.accent),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _T.accent.withValues(alpha: 0.55), width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ── Divider ─────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(children: [
      Expanded(
          child: Divider(
              color: Colors.white.withValues(alpha: 0.10), thickness: 1, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('OR',
            style: _T.muted(11.5)
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      ),
      Expanded(
          child: Divider(
              color: Colors.white.withValues(alpha: 0.10), thickness: 1, height: 1)),
    ]);
  }

  // ── Bottom Link ─────────────────────────────────────────────────────────────
  Widget _buildBottomLink() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(
            text: _isAdmin
                ? "Don't have an admin account?  "
                : "Don't have an account?  ",
            style: _T.muted(14.5),
          ),
          TextSpan(
            text: 'Register',
            style: _T.body(14.5,
                color: _isAdmin ? _T.adminLt : _T.accentLt,
                w: FontWeight.w700),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.pushReplacementNamed(
                  context, _isAdmin ? '/admin-register' : '/register'),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP LOGIN PAGE
// Flow: Enter mobile → Send OTP → 6-box OTP entry → Verify → Navigate
// ─────────────────────────────────────────────────────────────────────────────
class OtpLoginPage extends StatefulWidget {
  const OtpLoginPage({super.key});
  @override
  State<OtpLoginPage> createState() => _OtpLoginPageState();
}

class _OtpLoginPageState extends State<OtpLoginPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _phoneCtrl  = TextEditingController();
  final _phoneFocus = FocusNode();
  final List<TextEditingController> _otpCtrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus =
  List.generate(6, (_) => FocusNode());

  // State
  bool    _codeSent   = false;
  bool    _isLoading  = false;
  bool    _resending  = false;
  int     _resendSecs = 60;
  Timer?  _timer;
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

  // ── Send OTP ────────────────────────────────────────────────────────────────
  Future<void> _sendOtp({bool resend = false}) async {
    final raw   = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s|-'), '');
    final phone = raw.startsWith('+') ? raw : '+91$raw';

    if (!RegExp(r'^\+[0-9]{10,15}$').hasMatch(phone)) {
      _toast('Enter a valid mobile number (e.g. +91XXXXXXXXXX)', isError: true);
      return;
    }

    setState(() => resend ? _resending = true : _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _forceResendToken,
      timeout: const Duration(seconds: 60),

      // Android auto-retrieval
      verificationCompleted: (PhoneAuthCredential cred) async {
        // Auto-fill OTP digit boxes if possible
        final sms = cred.smsCode;
        if (sms != null && sms.length == 6) {
          for (int i = 0; i < 6; i++) {
            _otpCtrls[i].text = sms[i];
          }
        }
        setState(() => _isLoading = false);
        await _signInWithCredential(cred);
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() { _isLoading = false; _resending = false; });
        _toast(_friendlyOtpError(e.code), isError: true);
      },

      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId   = verificationId;
          _forceResendToken = resendToken;
          _codeSent         = true;
          _isLoading        = false;
          _resending        = false;
          _resendSecs       = 60;
        });
        _startCountdown();
        _toast('OTP sent to $phone', isError: false);
        Future.delayed(
          const Duration(milliseconds: 350),
              () { if (mounted) _otpFocus[0].requestFocus(); },
        );
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Verify OTP ──────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6) {
      _toast('Enter the complete 6-digit OTP.', isError: true);
      return;
    }
    if (_verificationId == null) {
      _toast('Session expired. Please resend OTP.', isError: true);
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
      _toast(_friendlyOtpError(e.code), isError: true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Sign in with credential & route ─────────────────────────────────────────
  Future<void> _signInWithCredential(PhoneAuthCredential cred) async {
    final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
    final uid      = userCred.user!.uid;
    final phone    = userCred.user!.phoneNumber ?? '';

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc    = await docRef.get();

    if (!doc.exists) {
      // First-time OTP user — create Firestore record
      await docRef.set({
        'uid':       uid,
        'mobile':    phone,
        'name':      '',
        'email':     '',
        'age':       0,
        'role':      'user',
        'isActive':  true,
        'usage':     0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen':  FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({'lastSeen': FieldValue.serverTimestamp()});
    }

    final role = doc.data()?['role'] as String? ?? 'user';
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, role == 'admin' ? '/admin-dashboard' : '/home');
  }

  // ── Countdown timer ─────────────────────────────────────────────────────────
  void _startCountdown() {
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

  String _friendlyOtpError(String code) {
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
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 17,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: _T.body(13.5, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ]),
      backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: _T.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
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
          child: _GlowBlob(color: _T.accent.withValues(alpha: 0.18), size: 260),
        ),
        Positioned(
          bottom: 100, left: -55,
          child: _GlowBlob(color: _T.teal.withValues(alpha: 0.10), size: 200),
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildBackButton(),
                      const SizedBox(height: 28),
                      _buildOtpLogo(),
                      const SizedBox(height: 24),
                      _buildOtpHeading(),
                      const SizedBox(height: 36),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                begin: const Offset(0.06, 0),
                                end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
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
      ]),
    );
  }

  // ── Back button ─────────────────────────────────────────────────────────────
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(Icons.arrow_back_rounded,
            color: Colors.white.withValues(alpha: 0.7), size: 20),
      ),
    );
  }

  // ── OTP Logo ─────────────────────────────────────────────────────────────────
  Widget _buildOtpLogo() {
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
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 28),
    );
  }

  // ── OTP Heading ──────────────────────────────────────────────────────────────
  Widget _buildOtpHeading() {
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

  // ── Phase 1: Phone input ─────────────────────────────────────────────────────
  Widget _buildPhoneSection() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone field (reuses _LoginField style)
        _LoginField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          label: 'Mobile Number',
          icon: Icons.phone_rounded,
          accentColor: _T.accent,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onEditingComplete: _isLoading ? null : () => _sendOtp(),
          validator: null,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Include country code — e.g. +91XXXXXXXXXX',
            style: _T.muted(12),
          ),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Send OTP',
          icon: Icons.send_rounded,
          loading: _isLoading,
          onTap: _isLoading ? null : () => _sendOtp(),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.maybePop(context),
            style: TextButton.styleFrom(foregroundColor: _T.accentLt),
            child: Text('Login with Password instead',
                style: _T.body(13.5, color: _T.accentLt, w: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Phase 2: OTP input ───────────────────────────────────────────────────────
  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 6 digit boxes
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
                FocusScope.of(context).unfocus();
                _verifyOtp();
              }
            },
          )),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Verify & Sign In',
          icon: Icons.verified_rounded,
          loading: _isLoading,
          onTap: _isLoading ? null : _verifyOtp,
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
                      color: _T.accent, w: FontWeight.w700)),
            ]),
          )
              : TextButton(
            onPressed: _resending ? null : () => _sendOtp(resend: true),
            style: TextButton.styleFrom(foregroundColor: _T.accentLt),
            child: _resending
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: _T.accentLt, strokeWidth: 2))
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded,
                    color: _T.accentLt, size: 16),
                const SizedBox(width: 6),
                Text('Resend OTP',
                    style: _T.body(14,
                        color: _T.accentLt, w: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Primary CTA ──────────────────────────────────────────────────────────────
  Widget _buildPrimaryButton({
    required String        label,
    required IconData      icon,
    required bool          loading,
    required VoidCallback? onTap,
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
              blurRadius: 22, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP Box — single digit input cell
// ─────────────────────────────────────────────────────────────────────────────
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
    widget.focusNode
        .addListener(() => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46, height: 58,
      decoration: BoxDecoration(
        color: _focused
            ? widget.accentColor.withValues(alpha: 0.12)
            : filled
            ? widget.accentColor.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? widget.accentColor
              : filled
              ? widget.accentColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.09),
          width: _focused ? 1.8 : 1.0,
        ),
        boxShadow: _focused
            ? [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.22),
            blurRadius: 12, offset: const Offset(0, 4),
          )
        ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.syne(
            fontSize: 22, fontWeight: FontWeight.w700, color: widget.accentColor),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) {
          setState(() {});
          widget.onChanged(val);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Tab
// ─────────────────────────────────────────────────────────────────────────────
class _RoleTab extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 14, offset: const Offset(0, 4))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15,
                    color: selected ? Colors.white : Colors.white54),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small Tab (Email / Mobile)
// ─────────────────────────────────────────────────────────────────────────────
class _SmallTab extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;

  const _SmallTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10, offset: const Offset(0, 3))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14,
                    color: selected ? Colors.white : Colors.white54),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login Field — shared styled input
// ─────────────────────────────────────────────────────────────────────────────
class _LoginField extends StatefulWidget {
  final TextEditingController      controller;
  final FocusNode                  focusNode;
  final String                     label;
  final IconData                   icon;
  final Color                      accentColor;
  final bool                       obscureText;
  final Widget?                    suffix;
  final TextInputType?             keyboardType;
  final TextInputAction?           textInputAction;
  final VoidCallback?              onEditingComplete;
  final String? Function(String?)? validator;

  const _LoginField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.obscureText        = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,
    this.validator,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode
        .addListener(() => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:        widget.controller,
      focusNode:         widget.focusNode,
      obscureText:       widget.obscureText,
      keyboardType:      widget.keyboardType,
      textInputAction:   widget.textInputAction,
      onEditingComplete: widget.onEditingComplete,
      onChanged:         (_) => setState(() {}),
      style: GoogleFonts.dmSans(fontSize: 14.5, color: Colors.white),
      validator: widget.validator,
      inputFormatters: widget.keyboardType == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
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
          child: Icon(widget.icon,
              size: 19,
              color: _focused
                  ? widget.accentColor
                  : Colors.white.withValues(alpha: 0.35)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 14), child: widget.suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _focused
            ? widget.accentColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.055),
        contentPadding: const EdgeInsets.fromLTRB(0, 18, 18, 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: widget.accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        errorStyle:
        GoogleFonts.dmSans(color: const Color(0xFFFF5252), fontSize: 11.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative helpers
// ─────────────────────────────────────────────────────────────────────────────
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
            spreadRadius: size / 5,
          )
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.028);
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
