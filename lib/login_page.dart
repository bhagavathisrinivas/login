import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
abstract class _T {
  // Base surfaces
  static const Color canvas   = Color(0xFF080B14); // deep navy-black
  static const Color surface  = Color(0xFF0F1626); // card surface
  static const Color elevated = Color(0xFF16213A); // slightly lifted

  // Accent — electric indigo (user)
  static const Color indigo   = Color(0xFF5B6EF5);
  static const Color indigoLt = Color(0xFF8B9BFF);
  static const Color indigoDim= Color(0xFF2A3580);

  // Accent — rose-gold (admin)
  static const Color rose     = Color(0xFFF25C87);
  static const Color roseLt   = Color(0xFFFF8FAF);
  static const Color roseDim  = Color(0xFF6B1A36);

  // Utility
  static const Color mist     = Color(0xFFAAB4C8); // muted text
  static const Color border   = Color(0xFF1F2D47); // subtle lines
  static const Color success  = Color(0xFF34D399);
  static const Color error    = Color(0xFFFC6B68);

  // Typography
  static TextStyle display(double sz, {Color? color, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: sz,
        fontWeight: w,
        color: color ?? Colors.white,
        letterSpacing: -0.5,
      );

  static TextStyle body(double sz, {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: sz,
        fontWeight: w,
        color: color ?? Colors.white,
      );

  static TextStyle label(double sz, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: sz,
        fontWeight: FontWeight.w500,
        color: color ?? mist,
        letterSpacing: 0.1,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _identifierCtrl  = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus   = FocusNode();

  bool _isAdmin   = false;
  bool _useEmail  = true;
  bool _isLoading = false;
  bool _obscure   = true;

  late AnimationController _entranceCtrl;
  late AnimationController _switchCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;
  late Animation<double>   _switchFade;

  Color get _accent   => _isAdmin ? _T.rose   : _T.indigo;
  Color get _accentLt => _isAdmin ? _T.roseLt : _T.indigoLt;
  Color get _accentDim=> _isAdmin ? _T.roseDim: _T.indigoDim;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _switchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _entranceFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _switchFade = CurvedAnimation(parent: _switchCtrl, curve: Curves.easeInOut);

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _switchCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchRole(bool toAdmin) {
    if (_isAdmin == toAdmin) return;
    _switchCtrl.forward(from: 0);
    setState(() {
      _isAdmin = toAdmin;
      _identifierCtrl.clear();
      _passwordCtrl.clear();
      _formKey.currentState?.reset();
    });
  }

  // ── Auth ────────────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      _isAdmin ? await _adminSignIn() : await _userSignIn();
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyError(e.code), isError: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
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
          .limit(1).get();
      if (snap.docs.isEmpty) throw Exception('No user found for this number.');
      email = snap.docs.first.data()['email'] as String;
    }
    final cred = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: _passwordCtrl.text.trim());
    final doc  = await FirebaseFirestore.instance
        .collection('users').doc(cred.user!.uid).get();
    final role = doc.data()?['role'] as String? ?? 'user';
    if (role == 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception('Admin account — use admin login.');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _adminSignIn() async {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _identifierCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );
    final doc  = await FirebaseFirestore.instance
        .collection('users').doc(cred.user!.uid).get();
    if ((doc.data()?['role'] as String? ?? 'user') != 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception('Access denied — no admin privileges.');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/admin-dashboard');
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':         return 'No account found with these credentials.';
      case 'wrong-password':         return 'Incorrect password — try again.';
      case 'too-many-requests':      return 'Too many attempts. Wait a moment.';
      case 'network-request-failed': return 'Check your internet connection.';
      default:                       return 'Sign-in failed — check your details.';
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: _T.body(13.5, color: Colors.white),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        backgroundColor: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // Background aurora
        Positioned.fill(child: _AuroraBg(accent: _accent)),

        SafeArea(
          child: FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      _buildBrand(),
                      const SizedBox(height: 32),
                      _buildRoleToggle(),
                      const SizedBox(height: 36),
                      _buildHeading(),
                      const SizedBox(height: 28),
                      if (!_isAdmin) ...[
                        _buildIdentifierToggle(),
                        const SizedBox(height: 20),
                      ],
                      _buildForm(),
                      const SizedBox(height: 24),
                      _buildSignInButton(),
                      if (!_isAdmin) ...[
                        const SizedBox(height: 14),
                        _buildOtpButton(),
                      ],
                      const SizedBox(height: 36),
                      _buildFooter(),
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

  // ── Brand mark ──────────────────────────────────────────────────────────────
  Widget _buildBrand() {
    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _accentDim,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            _isAdmin
                ? Icons.shield_rounded
                : Icons.electric_bolt_rounded,
            key: ValueKey(_isAdmin),
            color: _accentLt,
            size: 22,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text('Nexus', style: _T.display(20, w: FontWeight.w800)),
    ]);
  }

  // ── Role Toggle ─────────────────────────────────────────────────────────────
  Widget _buildRoleToggle() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        _RoleTab(
          label: 'Member',
          icon: Icons.person_rounded,
          selected: !_isAdmin,
          accent: _T.indigo,
          onTap: () => _switchRole(false),
        ),
        _RoleTab(
          label: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
          selected: _isAdmin,
          accent: _T.rose,
          onTap: () => _switchRole(true),
        ),
      ]),
    );
  }

  // ── Heading ─────────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: Text(
          _isAdmin ? 'login' : 'Welcome back',
          key: ValueKey(_isAdmin),
          style: _T.display(30),
        ),
      ),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: Text(
          _isAdmin
              ? 'Restricted access — authorised personnel only.'
              : 'Sign in to continue where you left off.',
          key: ValueKey('sub$_isAdmin'),
          style: _T.label(14.5),
        ),
      ),
    ]);
  }

  // ── Email / Mobile toggle ────────────────────────────────────────────────────
  Widget _buildIdentifierToggle() {
    return Row(children: [
      _ChipToggle(
        label: 'Email',
        icon: Icons.alternate_email_rounded,
        selected: _useEmail,
        accent: _T.indigo,
        onTap: () => setState(() { _useEmail = true; _identifierCtrl.clear(); }),
      ),
      const SizedBox(width: 8),
      _ChipToggle(
        label: 'Mobile',
        icon: Icons.phone_iphone_rounded,
        selected: !_useEmail,
        accent: _T.indigo,
        onTap: () => setState(() { _useEmail = false; _identifierCtrl.clear(); }),
      ),
    ]);
  }

  // ── Form ─────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(children: [
        _InputField(
          controller: _identifierCtrl,
          focusNode: _identifierFocus,
          accent: _accent,
          label: _isAdmin
              ? 'Admin email'
              : (_useEmail ? 'Email address' : 'Mobile number'),
          hint: _isAdmin || _useEmail
              ? 'you@example.com'
              : '+91 98765 43210',
          prefixIcon: _isAdmin || _useEmail
              ? Icons.alternate_email_rounded
              : Icons.phone_iphone_rounded,
          keyboardType: (!_isAdmin && !_useEmail)
              ? TextInputType.phone
              : TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onEditingComplete: () => _passwordFocus.requestFocus(),
          inputFormatters: (!_isAdmin && !_useEmail)
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))]
              : null,
          validator: (v) {
            if (v == null || v.isEmpty) return 'This field is required.';
            if (_isAdmin || _useEmail) {
              if (!RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                  .hasMatch(v)) return 'Enter a valid email address.';
            } else {
              final raw = v.replaceAll(RegExp(r'\s|-'), '');
              if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(raw))
                return 'Enter a valid mobile number.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          accent: _accent,
          label: 'Password',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onEditingComplete: _signIn,
          suffixWidget: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 19,
              color: _T.mist,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required.';
            if (v.length < 6) return 'At least 6 characters.';
            return null;
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/forgot-password'),
            child: Text(
              'Forgot password?',
              style: _T.body(13, color: _accentLt, w: FontWeight.w500),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Sign In Button ───────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return _PrimaryButton(
      label: _isAdmin ? 'Sign in to admin' : 'Sign in',
      accent: _accent,
      loading: _isLoading,
      onTap: _isLoading ? null : _signIn,
    );
  }

  // ── OTP Button ───────────────────────────────────────────────────────────────
  Widget _buildOtpButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OtpLoginPage()),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _T.indigoLt,
          side: BorderSide(color: _T.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          backgroundColor: _T.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phonelink_lock_rounded, size: 16, color: _T.indigoLt),
            const SizedBox(width: 8),
            Text('Continue with OTP',
                style: _T.body(14.5, color: _T.indigoLt, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(children: [
      // Divider with text
      Row(children: [
        Expanded(child: Divider(color: _T.border, thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text("No account?", style: _T.label(12.5)),
        ),
        Expanded(child: Divider(color: _T.border, thickness: 1, height: 1)),
      ]),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(
          context,
          _isAdmin ? '/admin-register' : '/register',
        ),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Create an account',
                  style: _T.body(14.5, color: Colors.white, w: FontWeight.w600)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 15, color: _accentLt),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP LOGIN PAGE
// ─────────────────────────────────────────────────────────────────────────────
class OtpLoginPage extends StatefulWidget {
  const OtpLoginPage({super.key});
  @override
  State<OtpLoginPage> createState() => _OtpLoginPageState();
}

class _OtpLoginPageState extends State<OtpLoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl  = TextEditingController();
  final _phoneFocus = FocusNode();
  final List<TextEditingController> _otpCtrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
  List.generate(6, (_) => FocusNode());

  bool    _codeSent   = false;
  bool    _isLoading  = false;
  bool    _resending  = false;
  int     _resendSecs = 60;
  Timer?  _timer;
  String? _verificationId;
  int?    _forceResendToken;

  late AnimationController _entranceCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    final raw   = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s|-'), '');
    final phone = raw.startsWith('+') ? raw : '+91$raw';
    if (!RegExp(r'^\+[0-9]{10,15}$').hasMatch(phone)) {
      _showSnack('Enter a valid number (e.g. +91XXXXXXXXXX)', isError: true);
      return;
    }
    setState(() => resend ? _resending = true : _isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _forceResendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        final sms = cred.smsCode;
        if (sms != null && sms.length == 6) {
          for (int i = 0; i < 6; i++) _otpCtrls[i].text = sms[i];
        }
        setState(() => _isLoading = false);
        await _signInWithCredential(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() { _isLoading = false; _resending = false; });
        _showSnack(_otpError(e.code), isError: true);
      },
      codeSent: (String vid, int? token) {
        setState(() {
          _verificationId   = vid;
          _forceResendToken = token;
          _codeSent         = true;
          _isLoading        = false;
          _resending        = false;
          _resendSecs       = 60;
        });
        _startCountdown();
        _showSnack('OTP sent to $phone', isError: false);
        Future.delayed(const Duration(milliseconds: 300),
                () { if (mounted) _otpFocusNodes[0].requestFocus(); });
      },
      codeAutoRetrievalTimeout: (String vid) => _verificationId = vid,
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6) {
      _showSnack('Enter the complete 6-digit code.', isError: true);
      return;
    }
    if (_verificationId == null) {
      _showSnack('Session expired — tap Resend.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: otp);
      await _signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      _showSnack(_otpError(e.code), isError: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential cred) async {
    final uc  = await FirebaseAuth.instance.signInWithCredential(cred);
    final uid = uc.user!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uid': uid, 'mobile': uc.user!.phoneNumber ?? '',
        'name': '', 'email': '', 'age': 0, 'role': 'user',
        'isActive': true, 'usage': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen':  FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'lastSeen': FieldValue.serverTimestamp()});
    }
    final role = doc.data()?['role'] as String? ?? 'user';
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, role == 'admin' ? '/admin-dashboard' : '/home');
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSecs <= 1) { t.cancel(); setState(() => _resendSecs = 0); }
      else                  { setState(() => _resendSecs--); }
    });
  }

  String _otpError(String code) {
    switch (code) {
      case 'invalid-verification-code': return 'Incorrect code — try again.';
      case 'session-expired':           return 'Code expired — tap Resend.';
      case 'too-many-requests':         return 'Too many attempts. Wait a moment.';
      case 'invalid-phone-number':      return 'Invalid phone number format.';
      case 'network-request-failed':    return 'Check your internet connection.';
      default:                          return 'Verification failed — try again.';
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: _T.body(13.5, color: Colors.white),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        backgroundColor: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(child: _AuroraBg(accent: _T.indigo)),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _buildTopBar(),
                      const SizedBox(height: 40),
                      _buildStepIndicator(),
                      const SizedBox(height: 32),
                      _buildOtpHeading(),
                      const SizedBox(height: 36),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: _codeSent
                            ? _buildOtpSection()
                            : _buildPhoneSection(),
                      ),
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

  Widget _buildTopBar() {
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
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _T.border),
        ),
        child: Icon(Icons.arrow_back_rounded,
            color: Colors.white.withValues(alpha: 0.8), size: 18),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(children: [
      _StepDot(active: true, done: _codeSent, accent: _T.indigo),
      Expanded(child: _StepLine(filled: _codeSent, accent: _T.indigo)),
      _StepDot(active: _codeSent, done: false, accent: _T.indigo),
    ]);
  }

  Widget _buildOtpHeading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          _codeSent ? 'Check your phone' : 'OTP sign in',
          key: ValueKey(_codeSent),
          style: _T.display(28),
        ),
      ),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          _codeSent
              ? 'Enter the 6-digit code sent to ${_phoneCtrl.text.trim()}'
              : 'Enter your mobile number to receive a one-time code.',
          key: ValueKey('sub$_codeSent'),
          style: _T.label(14.5),
        ),
      ),
    ]);
  }

  Widget _buildPhoneSection() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InputField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          accent: _T.indigo,
          label: 'Mobile number',
          hint: '+91 98765 43210',
          prefixIcon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onEditingComplete: _isLoading ? null : () => _sendOtp(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
        ),
        const SizedBox(height: 6),
        Text('Include country code, e.g. +91 for India',
            style: _T.label(12)),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Send code',
          accent: _T.indigo,
          loading: _isLoading,
          onTap: _isLoading ? null : () => _sendOtp(),
          icon: Icons.send_rounded,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Text('Use password instead',
                style: _T.body(13.5, color: _T.indigoLt, w: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpDigitBox(
            controller: _otpCtrls[i],
            focusNode: _otpFocusNodes[i],
            accent: _T.indigo,
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
              if (val.isEmpty   && i > 0) _otpFocusNodes[i - 1].requestFocus();
              if (_otpCtrls.every((c) => c.text.isNotEmpty)) {
                FocusScope.of(context).unfocus();
                _verifyOtp();
              }
            },
          )),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Verify & sign in',
          accent: _T.indigo,
          loading: _isLoading,
          onTap: _isLoading ? null : _verifyOtp,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: 24),
        Center(
          child: _resendSecs > 0
              ? Text.rich(TextSpan(children: [
            TextSpan(text: 'Resend in ', style: _T.label(13.5)),
            TextSpan(
              text: '${_resendSecs}s',
              style: _T.body(13.5, color: _T.indigoLt, w: FontWeight.w700),
            ),
          ]))
              : GestureDetector(
            onTap: _resending ? null : () => _sendOtp(resend: true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_resending)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: _T.indigoLt, strokeWidth: 2),
                  )
                else
                  Icon(Icons.refresh_rounded,
                      size: 15, color: _T.indigoLt),
                const SizedBox(width: 6),
                Text('Resend code',
                    style: _T.body(14, color: _T.indigoLt, w: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widget Library
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width primary action button
class _PrimaryButton extends StatelessWidget {
  final String        label;
  final Color         accent;
  final bool          loading;
  final VoidCallback? onTap;
  final IconData?     icon;

  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.loading,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: onTap != null
              ? [BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 20, offset: const Offset(0, 6))]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            splashColor: Colors.white.withValues(alpha: 0.08),
            child: Center(
              child: loading
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2))
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: _T.display(15,
                          color: Colors.white, w: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Role selector tab
class _RoleTab extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final Color        accent;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label, required this.icon,
    required this.selected, required this.accent, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14,
                  color: selected ? Colors.white : _T.mist),
              const SizedBox(width: 6),
              Text(label,
                  style: _T.body(13,
                      color: selected ? Colors.white : _T.mist,
                      w: selected ? FontWeight.w700 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip-style selector for email/mobile
class _ChipToggle extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final Color        accent;
  final VoidCallback onTap;

  const _ChipToggle({
    required this.label, required this.icon,
    required this.selected, required this.accent, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : _T.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : _T.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: selected ? accent : _T.mist),
            const SizedBox(width: 5),
            Text(label,
                style: _T.body(13,
                    color: selected ? accent : _T.mist,
                    w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Shared text input field
class _InputField extends StatefulWidget {
  final TextEditingController      controller;
  final FocusNode                  focusNode;
  final Color                      accent;
  final String                     label;
  final String                     hint;
  final IconData                   prefixIcon;
  final bool                       obscureText;
  final Widget?                    suffixWidget;
  final TextInputType?             keyboardType;
  final TextInputAction?           textInputAction;
  final VoidCallback?              onEditingComplete;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>?  inputFormatters;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText       = false,
    this.suffixWidget,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,
    this.validator,
    this.inputFormatters,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
            () => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _focused
            ? widget.accent.withValues(alpha: 0.07)
            : _T.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused ? widget.accent : _T.border,
          width: _focused ? 1.3 : 1,
        ),
        boxShadow: _focused
            ? [BoxShadow(
            color: widget.accent.withValues(alpha: 0.12),
            blurRadius: 16, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller:        widget.controller,
        focusNode:         widget.focusNode,
        obscureText:       widget.obscureText,
        keyboardType:      widget.keyboardType,
        textInputAction:   widget.textInputAction,
        onEditingComplete: widget.onEditingComplete,
        onChanged:         (_) => setState(() {}),
        inputFormatters:   widget.inputFormatters,
        style:             _T.body(14.5),
        validator:         widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: _T.label(13.5,
              color: _focused ? widget.accent : _T.mist),
          hintStyle: _T.label(14,
              color: Colors.white.withValues(alpha: 0.2)),
          floatingLabelStyle: _T.body(11,
              color: _focused ? widget.accent : _T.mist,
              w: FontWeight.w600),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(widget.prefixIcon,
                size: 18,
                color: _focused
                    ? widget.accent
                    : Colors.white.withValues(alpha: 0.3)),
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.suffixWidget != null
              ? Padding(
              padding: const EdgeInsets.only(right: 16),
              child: widget.suffixWidget)
              : null,
          suffixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: false,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.fromLTRB(0, 18, 18, 14),
          errorStyle: GoogleFonts.inter(
              color: _T.error, fontSize: 11.5),
        ),
      ),
    );
  }
}

/// Single OTP digit cell
class _OtpDigitBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final Color                 accent;
  final ValueChanged<String>  onChanged;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_OtpDigitBox> createState() => _OtpDigitBoxState();
}

class _OtpDigitBoxState extends State<_OtpDigitBox> {
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
      duration: const Duration(milliseconds: 160),
      width: 46, height: 58,
      decoration: BoxDecoration(
        color: _focused
            ? widget.accent.withValues(alpha: 0.1)
            : filled
            ? _T.surface
            : _T.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused
              ? widget.accent
              : filled
              ? widget.accent.withValues(alpha: 0.5)
              : _T.border,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [BoxShadow(
            color: widget.accent.withValues(alpha: 0.18),
            blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode:  widget.focusNode,
        textAlign:  TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength:    1,
        style: _T.display(22, color: widget.accent, w: FontWeight.w700),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) { setState(() {}); widget.onChanged(val); },
      ),
    );
  }
}

/// Step indicator dot for OTP flow
class _StepDot extends StatelessWidget {
  final bool  active;
  final bool  done;
  final Color accent;

  const _StepDot({required this.active, required this.done, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: done ? 28 : (active ? 24 : 10),
      height: 10,
      decoration: BoxDecoration(
        color: active || done ? accent : _T.border,
        borderRadius: BorderRadius.circular(5),
      ),
      child: done
          ? Icon(Icons.check_rounded, color: Colors.white, size: 7)
          : null,
    );
  }
}

/// Step indicator connector line
class _StepLine extends StatelessWidget {
  final bool  filled;
  final Color accent;

  const _StepLine({required this.filled, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 2,
        decoration: BoxDecoration(
          color: filled ? accent : _T.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aurora Background — subtle animated gradient blobs
// ─────────────────────────────────────────────────────────────────────────────
class _AuroraBg extends StatefulWidget {
  final Color accent;
  const _AuroraBg({required this.accent});

  @override
  State<_AuroraBg> createState() => _AuroraBgState();
}

class _AuroraBgState extends State<_AuroraBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return CustomPaint(
          painter: _AuroraPainter(t: t, accent: widget.accent),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final Color  accent;

  const _AuroraPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle noise-dot grid
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022);
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }

    // Blob 1 — top right
    final blob1 = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.85 + 0.08 * math.sin(t * math.pi)),
          size.height * (0.04 + 0.04 * math.cos(t * math.pi)),
        ),
        radius: size.width * 0.55,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blob1);

    // Blob 2 — bottom left (teal)
    final blob2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0EA5E9).withValues(alpha: 0.10),
          Colors.transparent
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.05 + 0.04 * math.cos(t * math.pi)),
          size.height * (0.85 + 0.04 * math.sin(t * math.pi)),
        ),
        radius: size.width * 0.6,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blob2);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.accent != accent;
}