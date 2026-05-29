import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameCtrl        = TextEditingController();
  final TextEditingController _ageCtrl         = TextEditingController();
  final TextEditingController _emailCtrl       = TextEditingController();
  final TextEditingController _mobileCtrl      = TextEditingController();
  final TextEditingController _passCtrl        = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  String? _selectedGender;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _accent = Color(0xFF7C6FFF);
  static const Color _teal   = Color(0xFF4ECDC4);

  static const List<String> _genders = <String>[
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Register logic ────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Check mobile uniqueness
      final QuerySnapshot<Map<String, dynamic>> mobileCheck =
      await FirebaseFirestore.instance
          .collection('users')
          .where('mobile', isEqualTo: _mobileCtrl.text.trim())
          .limit(1)
          .get();

      if (mobileCheck.docs.isNotEmpty) {
        _toast('This mobile number is already registered.');
        return;
      }

      // Create auth user
      final UserCredential cred =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      await cred.user!.updateDisplayName(_nameCtrl.text.trim());

      // Save profile to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(<String, dynamic>{
        'uid':       cred.user!.uid,
        'name':      _nameCtrl.text.trim(),
        'age':       int.tryParse(_ageCtrl.text.trim()) ?? 0,
        'gender':    _selectedGender ?? '',
        'email':     _emailCtrl.text.trim().toLowerCase(),
        'mobile':    _mobileCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e.code));
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Please check and retry.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
                center: Alignment(0.7, -0.7),
                radius: 1.3,
                colors: <Color>[Color(0xFF1A1040), Color(0xFF0A0A1A)],
              ),
            ),
          ),
          // Glow blobs
          Positioned(
            top: -60,
            left: -60,
            child: _Glow(color: _accent.withValues(alpha: 0.16), size: 240),
          ),
          Positioned(
            bottom: 80,
            right: -70,
            child: _Glow(color: _teal.withValues(alpha: 0.13), size: 200),
          ),
          // Dot grid
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _DotGridPainter(),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildStepIndicator(),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: <Widget>[
                            _buildPersonalInfo(),
                            const SizedBox(height: 14),
                            _buildContactInfo(),
                            const SizedBox(height: 14),
                            _buildPasswordInfo(),
                            const SizedBox(height: 32),
                            _buildRegisterButton(),
                            const SizedBox(height: 24),
                            _buildLoginLink(),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[_accent, Color(0xFF5A4FE0)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.person_add_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Join us — it only takes a minute',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    const List<String> steps = <String>['Personal', 'Contact', 'Security'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: List<Widget>.generate(steps.length * 2 - 1, (int i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: _accent.withValues(alpha: 0.3),
              ),
            );
          }
          final int idx = i ~/ 2;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent,
              border: Border.all(color: _accent, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${idx + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _accent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9D93FF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal info section ─────────────────────────────────────────────────
  Widget _buildPersonalInfo() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader('PERSONAL INFO', Icons.badge_outlined),
          _AppTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            prefixIcon: Icons.person_outline_rounded,
            validator: (String? v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              if (v.trim().length < 2) return 'Enter your full name';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _AppTextField(
                  controller: _ageCtrl,
                  label: 'Age',
                  prefixIcon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  validator: (String? v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final int? age = int.tryParse(v);
                    if (age == null || age < 1 || age > 120) {
                      return 'Enter valid age';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildGenderDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gender dropdown ───────────────────────────────────────────────────────
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: const Color(0xFF1A1040),
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF7C6FFF)),
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13.5,
        ),
        prefixIcon: const Icon(Icons.wc_outlined,
            color: Color(0xFF7C6FFF), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1,
          ),
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
      items: _genders.map((String g) {
        return DropdownMenuItem<String>(
          value: g,
          child: Text(g, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (String? v) => setState(() => _selectedGender = v),
      validator: (String? v) => v == null ? 'Select gender' : null,
    );
  }

  // ── Contact info section ──────────────────────────────────────────────────
  Widget _buildContactInfo() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader(
              'CONTACT INFO', Icons.contact_mail_outlined),
          _AppTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (String? v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AppTextField(
            controller: _mobileCtrl,
            label: 'Mobile Number',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (String? v) {
              if (v == null || v.isEmpty) return 'Mobile is required';
              if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v)) {
                return 'Enter a valid mobile number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── Password section ──────────────────────────────────────────────────────
  Widget _buildPasswordInfo() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader('SECURITY', Icons.shield_outlined),
          _AppTextField(
            controller: _passCtrl,
            label: 'Password',
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
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              if (!RegExp(r'[A-Z]').hasMatch(v)) {
                return 'Include at least one uppercase letter';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AppTextField(
            controller: _confirmPassCtrl,
            label: 'Confirm Password',
            prefixIcon: Icons.lock_reset_outlined,
            obscureText: _obscureConfirm,
            suffixWidget: GestureDetector(
              onTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
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
              if (v != _passCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordStrengthHint(),
        ],
      ),
    );
  }

  // ── Password strength chips ───────────────────────────────────────────────
  Widget _buildPasswordStrengthHint() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        _HintChip(
          label: '6+ chars',
          met: _passCtrl.text.length >= 6,
        ),
        _HintChip(
          label: 'Uppercase',
          met: RegExp(r'[A-Z]').hasMatch(_passCtrl.text),
        ),
        _HintChip(
          label: 'Number',
          met: RegExp(r'[0-9]').hasMatch(_passCtrl.text),
        ),
      ],
    );
  }

  // ── Register button ───────────────────────────────────────────────────────
  Widget _buildRegisterButton() {
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
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.2,
            ),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Login link ────────────────────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'Already have an account? ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14.5,
              ),
            ),
            TextSpan(
              text: 'Sign In',
              style: const TextStyle(
                color: Color(0xFF9D93FF),
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () =>
                    Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: child,
    );
  }
}

// ── Password Hint Chip ────────────────────────────────────────────────────────
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            met
                ? Icons.check_circle_outline_rounded
                : Icons.circle_outlined,
            size: 11,
            color: met ? _teal : Colors.white24,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: met ? _teal : Colors.white30,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Text Field ────────────────────────────────────────────────────────────
class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixWidget;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixWidget,
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
          fontSize: 13.5,
        ),
        prefixIcon:
        Icon(prefixIcon, color: const Color(0xFF7C6FFF), size: 20),
        suffixIcon: suffixWidget != null
            ? Padding(
          padding: const EdgeInsets.only(right: 14),
          child: suffixWidget,
        )
            : null,
        suffixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
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
            color: Colors.white.withValues(alpha: 0.09),
            width: 1,
          ),
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

// ── Decorative: Glow ──────────────────────────────────────────────────────────
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
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}

// ── Decorative: Dot Grid ──────────────────────────────────────────────────────
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