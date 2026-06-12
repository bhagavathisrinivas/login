import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens (same as login) ───────────────────────────────────────────
abstract class _T {
  static const Color canvas   = Color(0xFF080B14);
  static const Color surface  = Color(0xFF0F1626);
  static const Color elevated = Color(0xFF16213A);

  static const Color indigo   = Color(0xFF5B6EF5);
  static const Color indigoLt = Color(0xFF8B9BFF);
  static const Color indigoDim= Color(0xFF1E245C);

  static const Color mist     = Color(0xFFAAB4C8);
  static const Color border   = Color(0xFF1F2D47);
  static const Color success  = Color(0xFF34D399);
  static const Color error    = Color(0xFFFC6B68);
  static const Color warning  = Color(0xFFFBBF24);

  static TextStyle display(double sz,
      {Color? color, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: sz, fontWeight: w,
        color: color ?? Colors.white, letterSpacing: -0.4,
      );

  static TextStyle body(double sz,
      {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: sz, fontWeight: w, color: color ?? Colors.white,
      );

  static TextStyle label(double sz, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: sz, fontWeight: FontWeight.w500,
        color: color ?? mist, letterSpacing: 0.1,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _mobileCtrl = TextEditingController();

  // ── Focus nodes ─────────────────────────────────────────────────────────────
  final _nameFocus   = FocusNode();
  final _emailFocus  = FocusNode();
  final _mobileFocus = FocusNode();

  // ── State ────────────────────────────────────────────────────────────────────
  bool   _isLoading       = true;
  bool   _isSaving        = false;
  bool   _isUploadingAvatar = false;
  bool   _hasChanges      = false;
  String _avatarUrl       = '';
  File?  _pendingAvatar;

  // Original values for dirty-tracking
  String _origName   = '';
  String _origEmail  = '';
  String _origMobile = '';

  late AnimationController _entranceCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _loadProfile();

    for (final ctrl in [_nameCtrl, _emailCtrl, _mobileCtrl]) {
      ctrl.addListener(_checkDirty);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  // ── Load ────────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(_uid).get();
      final data = doc.data() ?? {};
      final name   = data['name']   as String? ?? '';
      final email  = data['email']  as String? ?? '';
      final mobile = data['mobile'] as String? ?? '';
      final avatar = data['avatarUrl'] as String? ?? '';

      _nameCtrl.text   = name;
      _emailCtrl.text  = email;
      _mobileCtrl.text = mobile;
      _origName   = name;
      _origEmail  = email;
      _origMobile = mobile;

      setState(() { _avatarUrl = avatar; _isLoading = false; });
      _entranceCtrl.forward();
    } catch (_) {
      setState(() => _isLoading = false);
      _entranceCtrl.forward();
    }
  }

  void _checkDirty() {
    final dirty = _nameCtrl.text   != _origName   ||
        _emailCtrl.text  != _origEmail  ||
        _mobileCtrl.text != _origMobile ||
        _pendingAvatar   != null;
    if (dirty != _hasChanges) setState(() => _hasChanges = dirty);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final name   = _nameCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    if (name.isEmpty) { _showSnack('Name cannot be empty.', isError: true); return; }
    if (email.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(email)) {
      _showSnack('Enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? newAvatarUrl;
      if (_pendingAvatar != null) {
        final ref = FirebaseStorage.instance
            .ref('avatars/$_uid.jpg');
        await ref.putFile(_pendingAvatar!);
        newAvatarUrl = await ref.getDownloadURL();
      }

      final updates = <String, dynamic>{
        'name':      name,
        'email':     email,
        'mobile':    mobile,
        'lastSeen':  FieldValue.serverTimestamp(),
      };
      if (newAvatarUrl != null) updates['avatarUrl'] = newAvatarUrl;

      await FirebaseFirestore.instance
          .collection('users').doc(_uid).update(updates);

      // Update Firebase Auth display name
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      setState(() {
        _origName   = name;
        _origEmail  = email;
        _origMobile = mobile;
        if (newAvatarUrl != null) _avatarUrl = newAvatarUrl;
        _pendingAvatar = null;
        _hasChanges    = false;
      });
      _showSnack('Profile saved.', isError: false);
    } catch (e) {
      _showSnack('Could not save — try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Avatar picker ────────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AvatarSourceSheet(),
    );
    if (src == null) return;

    final picked = await picker.pickImage(
        source: src, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;

    setState(() {
      _pendingAvatar = File(picked.path);
      _hasChanges    = true;
    });
  }

  // ── Discard ──────────────────────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _DiscardDialog(),
    );
    return result ?? false;
  }

  // ── Snack ────────────────────────────────────────────────────────────────────
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
          Expanded(child: Text(msg,
              style: _T.body(13.5, color: Colors.white),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        backgroundColor: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: _T.canvas,
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          // Ambient aurora
          Positioned(top: -100, right: -60,
              child: _GlowBlob(color: _T.indigo.withValues(alpha: 0.14), size: 280)),
          Positioned(bottom: 80, left: -50,
              child: _GlowBlob(color: const Color(0xFF0EA5E9).withValues(alpha: 0.08), size: 220)),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _T.indigo, strokeWidth: 2))
          else
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Column(children: [
                      _buildAppBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 28),
                              _buildAvatarSection(),
                              const SizedBox(height: 36),
                              _buildSectionLabel('Personal info'),
                              const SizedBox(height: 14),
                              _buildInfoFields(),
                              const SizedBox(height: 32),
                              _buildSectionLabel('Security'),
                              const SizedBox(height: 14),
                              _buildSecuritySection(),
                              const SizedBox(height: 36),
                              _buildDangerSection(),
                            ],
                          ),
                        ),
                      ),
                      // Save bar — slides up when dirty
                      AnimatedSlide(
                        offset: _hasChanges ? Offset.zero : const Offset(0, 1),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _hasChanges ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: _buildSaveBar(),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(children: [
        _IconBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () async {
            if (await _confirmDiscard()) Navigator.maybePop(context);
          },
        ),
        const SizedBox(width: 14),
        Text('Profile', style: _T.display(20)),
        const Spacer(),
        _IconBtn(
          icon: Icons.logout_rounded,
          onTap: _confirmSignOut,
          color: _T.error.withValues(alpha: 0.8),
        ),
      ]),
    );
  }

  // ── Avatar ───────────────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    final name    = _nameCtrl.text.trim();
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Column(children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.indigoDim,
                  border: Border.all(
                    color: _pendingAvatar != null
                        ? _T.indigo
                        : _T.border,
                    width: _pendingAvatar != null ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _T.indigo.withValues(alpha: 0.25),
                      blurRadius: 20, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _pendingAvatar != null
                      ? Image.file(_pendingAvatar!, fit: BoxFit.cover)
                      : _avatarUrl.isNotEmpty
                      ? Image.network(
                    _avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initialsWidget(initials),
                  )
                      : _initialsWidget(initials),
                ),
              ),

              // Camera badge
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _T.indigo,
                    shape: BoxShape.circle,
                    border: Border.all(color: _T.canvas, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 14),
                ),
              ),

              // Uploading overlay
              if (_isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text(
          _pendingAvatar != null ? 'New photo selected' : 'Tap to change photo',
          style: _T.label(13, color: _pendingAvatar != null ? _T.indigoLt : _T.mist),
        ),

        if (_pendingAvatar != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() { _pendingAvatar = null; _checkDirty(); }),
            child: Text('Remove',
                style: _T.body(12.5,
                    color: _T.error.withValues(alpha: 0.8),
                    w: FontWeight.w500)),
          ),
        ],
      ]),
    );
  }

  Widget _initialsWidget(String initials) {
    return Center(
      child: Text(initials,
          style: _T.display(32, color: _T.indigoLt)),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Row(children: [
      Text(text.toUpperCase(),
          style: _T.label(11,
              color: _T.mist.withValues(alpha: 0.6))
              .copyWith(letterSpacing: 1.1)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: _T.border, thickness: 1, height: 1)),
    ]);
  }

  // ── Info fields ───────────────────────────────────────────────────────────────
  Widget _buildInfoFields() {
    return Column(children: [
      _ProfileField(
        controller: _nameCtrl,
        focusNode: _nameFocus,
        label: 'Full name',
        hint: 'Your display name',
        icon: Icons.person_outline_rounded,
        nextFocus: _emailFocus,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 10),
      _ProfileField(
        controller: _emailCtrl,
        focusNode: _emailFocus,
        label: 'Email address',
        hint: 'you@example.com',
        icon: Icons.alternate_email_rounded,
        nextFocus: _mobileFocus,
        keyboardType: TextInputType.emailAddress,
        helperText: 'Used for notifications and recovery.',
      ),
      const SizedBox(height: 10),
      _ProfileField(
        controller: _mobileCtrl,
        focusNode: _mobileFocus,
        label: 'Mobile number',
        hint: '+91 98765 43210',
        icon: Icons.phone_iphone_rounded,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        helperText: 'Used for OTP sign-in.',
      ),
    ]);
  }

  // ── Security section ──────────────────────────────────────────────────────────
  Widget _buildSecuritySection() {
    return Column(children: [
      _ActionTile(
        icon: Icons.lock_reset_rounded,
        iconColor: _T.indigo,
        title: 'Change password',
        subtitle: 'Update your sign-in password',
        onTap: () => _showChangePasswordSheet(),
      ),
      const SizedBox(height: 8),
      _ActionTile(
        icon: Icons.devices_rounded,
        iconColor: _T.indigoLt.withValues(alpha: 0.8),
        title: 'Active sessions',
        subtitle: 'View and revoke signed-in devices',
        onTap: () => _showSnack('Coming soon.', isError: false),
        trailing: _PillBadge(label: 'Soon'),
      ),
    ]);
  }

  // ── Danger zone ──────────────────────────────────────────────────────────────
  Widget _buildDangerSection() {
    return Column(children: [
      _buildSectionLabel('Danger zone'),
      const SizedBox(height: 14),
      _ActionTile(
        icon: Icons.no_accounts_rounded,
        iconColor: _T.error,
        title: 'Delete account',
        subtitle: 'Permanently remove your data',
        onTap: _confirmDeleteAccount,
        destructive: true,
      ),
    ]);
  }

  // ── Save bar ──────────────────────────────────────────────────────────────────
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(top: BorderSide(color: _T.border)),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _isSaving
                ? null
                : () {
              _nameCtrl.text   = _origName;
              _emailCtrl.text  = _origEmail;
              _mobileCtrl.text = _origMobile;
              setState(() { _pendingAvatar = null; _hasChanges = false; });
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _T.canvas,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _T.border),
              ),
              child: Center(
                child: Text('Discard',
                    style: _T.body(14.5, color: _T.mist, w: FontWeight.w600)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              decoration: BoxDecoration(
                color: _T.indigo,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: _T.indigo.withValues(alpha: 0.35),
                    blurRadius: 16, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.2))
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 17),
                    const SizedBox(width: 7),
                    Text('Save changes',
                        style: _T.display(14.5,
                            color: Colors.white, w: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Change Password Sheet ─────────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSuccess: () => _showSnack('Password updated.', isError: false),
      ),
    );
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────
  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sign out?',
        body: 'You\'ll need to sign in again to access your account.',
        confirmLabel: 'Sign out',
        destructive: false,
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────────
  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete account?',
        body: 'All your data will be permanently removed. This cannot be undone.',
        confirmLabel: 'Delete account',
        destructive: true,
      ),
    );
    if (ok != true) return;
    try {
      final uid = _uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await FirebaseAuth.instance.currentUser?.delete();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnack(
          'Re-authenticate and try again — recent sign-in required.',
          isError: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANGE PASSWORD SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePasswordSheet({required this.onSuccess});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  // Password strength
  int get _strength {
    final p = _newCtrl.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[^a-zA-Z0-9]'))) s++;
    return s;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 0:
      case 1: return _T.error;
      case 2: return _T.warning;
      case 3: return const Color(0xFF60A5FA);
      default: return _T.success;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 0:
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      default: return 'Strong';
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user  = FirebaseAuth.instance.currentUser!;
      final cred  = EmailAuthProvider.credential(
          email: user.email!, password: _currentCtrl.text.trim());
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newCtrl.text.trim());
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':    msg = 'Current password is incorrect.'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try later.'; break;
        default:                  msg = 'Could not update password — try again.';
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(msg, style: _T.body(13.5, color: Colors.white)),
          backgroundColor: const Color(0xFF991B1B),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _T.border),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 28 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _T.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Change password', style: _T.display(20)),
            const SizedBox(height: 4),
            Text('You\'ll be signed in with the new password next time.',
                style: _T.label(13.5)),
            const SizedBox(height: 24),

            // Current password
            _SheetField(
              controller: _currentCtrl,
              label: 'Current password',
              obscure: _obscureCurrent,
              onToggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Required.' : null,
            ),
            const SizedBox(height: 10),

            // New password
            _SheetField(
              controller: _newCtrl,
              label: 'New password',
              obscure: _obscureNew,
              onToggleObscure: () =>
                  setState(() => _obscureNew = !_obscureNew),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required.';
                if (v.length < 8) return 'At least 8 characters.';
                return null;
              },
            ),

            // Strength meter
            if (_newCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                ...List.generate(4, (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < _strength ? _strengthColor : _T.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
                const SizedBox(width: 10),
                Text(_strengthLabel,
                    style: _T.body(11.5,
                        color: _strengthColor, w: FontWeight.w600)),
              ]),
            ],

            const SizedBox(height: 10),

            // Confirm
            _SheetField(
              controller: _confirmCtrl,
              label: 'Confirm new password',
              obscure: _obscureConfirm,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              textInputAction: TextInputAction.done,
              onEditingComplete: _isLoading ? null : _changePassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required.';
                if (v != _newCtrl.text) return 'Passwords don\'t match.';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _T.indigo,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(
                      color: _T.indigo.withValues(alpha: 0.3),
                      blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: TextButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.2))
                      : Text('Update password',
                      style: _T.display(15,
                          color: Colors.white, w: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Editable profile field
class _ProfileField extends StatefulWidget {
  final TextEditingController     controller;
  final FocusNode                 focusNode;
  final String                    label;
  final String                    hint;
  final IconData                  icon;
  final FocusNode?                nextFocus;
  final TextInputType?            keyboardType;
  final TextInputAction?          textInputAction;
  final TextCapitalization        textCapitalization;
  final String?                   helperText;
  final List<TextInputFormatter>? inputFormatters;

  const _ProfileField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.nextFocus,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.inputFormatters,
  });

  @override
  State<_ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<_ProfileField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode
        .addListener(() => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _focused
                ? _T.indigo.withValues(alpha: 0.07)
                : _T.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _focused ? _T.indigo : _T.border,
              width: _focused ? 1.3 : 1,
            ),
            boxShadow: _focused
                ? [BoxShadow(
                color: _T.indigo.withValues(alpha: 0.10),
                blurRadius: 12, offset: const Offset(0, 3))]
                : [],
          ),
          child: TextFormField(
            controller:          widget.controller,
            focusNode:           widget.focusNode,
            keyboardType:        widget.keyboardType,
            textInputAction:     widget.textInputAction,
            textCapitalization:  widget.textCapitalization,
            inputFormatters:     widget.inputFormatters,
            style:               _T.body(14.5),
            onEditingComplete: widget.nextFocus != null
                ? () => widget.nextFocus!.requestFocus()
                : null,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText:  widget.hint,
              labelStyle: _T.label(13.5,
                  color: _focused ? _T.indigo : _T.mist),
              hintStyle:  _T.label(14,
                  color: Colors.white.withValues(alpha: 0.2)),
              floatingLabelStyle: _T.body(11,
                  color: _focused ? _T.indigo : _T.mist,
                  w: FontWeight.w600),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(widget.icon, size: 18,
                    color: _focused
                        ? _T.indigo
                        : Colors.white.withValues(alpha: 0.28)),
              ),
              prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(0, 18, 18, 14),
              errorStyle: GoogleFonts.inter(
                  color: _T.error, fontSize: 11.5),
            ),
          ),
        ),
        if (widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 5),
            child: Text(widget.helperText!,
                style: _T.label(11.5,
                    color: _T.mist.withValues(alpha: 0.55))),
          ),
      ],
    );
  }
}

/// Sheet password field
class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final bool                  obscure;
  final VoidCallback          onToggleObscure;
  final TextInputAction?      textInputAction;
  final VoidCallback?         onEditingComplete;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggleObscure,
    this.textInputAction,
    this.onEditingComplete,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:        controller,
      obscureText:       obscure,
      textInputAction:   textInputAction,
      onEditingComplete: onEditingComplete,
      onChanged:         onChanged,
      style:             _T.body(14.5),
      validator:         validator,
      autovalidateMode:  AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _T.label(13.5),
        floatingLabelStyle: _T.body(11, w: FontWeight.w600, color: _T.indigo),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: _T.canvas,
        suffixIcon: GestureDetector(
          onTap: onToggleObscure,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: _T.mist,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.indigo, width: 1.3)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.error, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.error, width: 1.3)),
        contentPadding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
        errorStyle: GoogleFonts.inter(color: _T.error, fontSize: 11.5),
      ),
    );
  }
}

/// Action tile for security / danger rows
class _ActionTile extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    subtitle;
  final VoidCallback onTap;
  final bool      destructive;
  final Widget?   trailing;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        splashColor: iconColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: destructive
                ? _T.error.withValues(alpha: 0.05)
                : _T.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: destructive
                  ? _T.error.withValues(alpha: 0.2)
                  : _T.border,
            ),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _T.body(14,
                          color: destructive ? _T.error : Colors.white,
                          w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _T.label(12.5)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else
              Icon(Icons.chevron_right_rounded,
                  color: _T.mist.withValues(alpha: 0.5), size: 20),
          ]),
        ),
      ),
    );
  }
}

/// Icon button
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color?   color;

  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _T.border),
        ),
        child: Icon(icon,
            color: color ?? Colors.white.withValues(alpha: 0.75),
            size: 18),
      ),
    );
  }
}

/// "Soon" badge
class _PillBadge extends StatelessWidget {
  final String label;
  const _PillBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _T.mist.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Text(label,
          style: _T.label(11, color: _T.mist.withValues(alpha: 0.7))),
    );
  }
}

/// Avatar source picker sheet
class _AvatarSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _T.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('Choose photo source', style: _T.display(17)),
          const SizedBox(height: 20),
          _SourceTile(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _SourceTile(
            icon: Icons.photo_library_rounded,
            label: 'Photo library',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 10),
          _SourceTile(
            icon: Icons.close_rounded,
            label: 'Cancel',
            destructive: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     destructive;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? _T.error : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _T.elevated,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _T.border),
        ),
        child: Row(children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 19),
          const SizedBox(width: 14),
          Text(label, style: _T.body(15, color: color, w: FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Confirm dialog (sign out / delete)
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final bool   destructive;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _T.display(19)),
            const SizedBox(height: 10),
            Text(body, style: _T.label(14).copyWith(height: 1.55)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _T.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text('Cancel',
                      style: _T.body(14, w: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: destructive ? _T.error : _T.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(confirmLabel,
                      style: _T.body(14, w: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Discard changes dialog
class _DiscardDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ConfirmDialog(
      title: 'Discard changes?',
      body: 'You have unsaved edits. Leave without saving?',
      confirmLabel: 'Discard',
      destructive: false,
    );
  }
}

/// Ambient glow blob (same as login)
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
        boxShadow: [BoxShadow(
            color: color, blurRadius: size / 1.2, spreadRadius: size / 5)],
      ),
    );
  }
}
