import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
abstract class _T {
  static const Color bg         = Color(0xFF0B0B1E);
  static const Color accent     = Color(0xFF7C6FFF);  // user color
  static const Color accentLt   = Color(0xFF9D93FF);
  static const Color adminClr   = Color(0xFFFF6B8A);  // admin color
  static const Color adminLt    = Color(0xFFFF9DB3);
  static const Color teal       = Color(0xFF4ECDC4);

  static TextStyle display(double sz, {Color c = Colors.white}) =>
      GoogleFonts.syne(fontSize: sz, fontWeight: FontWeight.w800, color: c);

  static TextStyle body(double sz,
      {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.dmSans(fontSize: sz, fontWeight: w,
          color: color ?? Colors.white);

  static TextStyle muted(double sz) => GoogleFonts.dmSans(
      fontSize: sz, color: Colors.white.withValues(alpha: 0.45));
}

// ─── Login Page ───────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _identifierCtrl  = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus   = FocusNode();

  // ── Roles ──────────────────────────────────────────────────────────────────
  bool _isAdmin    = false;   // false = user, true = admin
  bool _useEmail   = true;    // email or mobile (user only)
  bool _isLoading  = false;
  bool _obscure    = true;

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

  // ─── Sign In ───────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isAdmin) {
        await _adminSignIn();
      } else {
        await _userSignIn();
      }
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code), isError: true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── User Login ─────────────────────────────────────────────────────────────
  Future<void> _userSignIn() async {
    String email = _identifierCtrl.text.trim();

    if (!_useEmail) {
      // Lookup email by mobile
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

    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: _passwordCtrl.text.trim());

    // Verify it's a user role
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(cred.user!.uid)
        .get();

    final role = doc.data()?['role'] as String? ?? 'user';
    if (role == 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception(
          'This account is an admin account. Please use admin login.');
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  // ── Admin Login ────────────────────────────────────────────────────────────
  Future<void> _adminSignIn() async {
    final email = _identifierCtrl.text.trim();

    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: _passwordCtrl.text.trim());

    // Verify role is admin in Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(cred.user!.uid)
        .get();

    final role = doc.data()?['role'] as String? ?? 'user';
    if (role != 'admin') {
      await FirebaseAuth.instance.signOut();
      throw Exception(
          'Access denied. This account does not have admin privileges.');
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/admin-dashboard');
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':        return 'No account found with this email.';
      case 'wrong-password':        return 'Incorrect password. Please try again.';
      case 'too-many-requests':     return 'Too many attempts. Try again later.';
      case 'network-request-failed':return 'Check your internet connection.';
      default:                      return 'Sign-in failed. Check your credentials.';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          // Background gradient changes by role
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
            child: _GlowBlob(
                color: _activeColor.withValues(alpha: 0.18), size: 260),
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
        ],
      ),
    );
  }

  // ─── Role Toggle (User / Admin) ────────────────────────────────────────────
  Widget _buildRoleToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _RoleTab(
            label: 'User Login',
            icon: Icons.person_outline_rounded,
            selected: !_isAdmin,
            color: _T.accent,
            onTap: () {
              setState(() {
                _isAdmin = false;
                _identifierCtrl.clear();
                _passwordCtrl.clear();
                _formKey.currentState?.reset();
              });
            },
          ),
          _RoleTab(
            label: 'Admin Login',
            icon: Icons.admin_panel_settings_outlined,
            selected: _isAdmin,
            color: _T.adminClr,
            onTap: () {
              setState(() {
                _isAdmin = true;
                _identifierCtrl.clear();
                _passwordCtrl.clear();
                _formKey.currentState?.reset();
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── Logo ──────────────────────────────────────────────────────────────────
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
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(
        _isAdmin ? Icons.admin_panel_settings_rounded : Icons.bolt_rounded,
        color: Colors.white, size: 30,
      ),
    );
  }

  // ─── Heading ───────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _isAdmin ? 'Admin ' : 'Welcome Back 👋',
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

  // ─── Email / Mobile Toggle (User only) ────────────────────────────────────
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
      child: Row(
        children: [
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
        ],
      ),
    );
  }

  // ─── Form ──────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Identifier field
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
                if (!RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
                  return 'Enter a valid email address';
                }
              } else {
                if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v.replaceAll(RegExp(r'\s|-'), ''))) {
                  return 'Enter a valid mobile number';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          // Password field
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
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
          // Forgot password
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/forgot-password'),
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

  // ─── Sign In Button ────────────────────────────────────────────────────────
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
                blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _signIn,
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
              Icon(
                _isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.login_rounded,
                color: Colors.white, size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isAdmin ? 'Admin Sign In' : 'Sign In',
                style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: Colors.white.withValues(alpha: 0.10),
                thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR',
              style: _T.muted(11.5).copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        Expanded(
            child: Divider(
                color: Colors.white.withValues(alpha: 0.10),
                thickness: 1, height: 1)),
      ],
    );
  }

  // ─── Bottom Link ───────────────────────────────────────────────────────────
  Widget _buildBottomLink() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
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
                ..onTap = () {
                  Navigator.pushReplacementNamed(
                    context,
                    _isAdmin ? '/admin-register' : '/register',
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Role Tab ─────────────────────────────────────────────────────────────────
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
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                        selected ? Colors.white : Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small Tab (Email/Mobile) ─────────────────────────────────────────────────
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
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? Colors.white : Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Login Field ──────────────────────────────────────────────────────────────
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
    widget.focusNode.addListener(
            () => setState(() => _focused = widget.focusNode.hasFocus));
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
        prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffix != null
            ? Padding(
            padding: const EdgeInsets.only(right: 14),
            child: widget.suffix)
            : null,
        suffixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
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
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: widget.accentColor, width: 1.5),
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