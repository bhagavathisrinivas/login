import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dashboard_page.dart';
import 'profile_page.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
abstract class _T {
  static const Color canvas   = Color(0xFF080B14);
  static const Color surface  = Color(0xFF0F1626);
  static const Color elevated = Color(0xFF16213A);

  static const Color indigo   = Color(0xFF5B6EF5);
  static const Color indigoLt = Color(0xFF8B9BFF);
  static const Color indigoDim= Color(0xFF1E245C);

  static const Color teal     = Color(0xFF2DD4BF);
  static const Color amber    = Color(0xFFFBBF24);
  static const Color rose     = Color(0xFFF43F5E);

  static const Color mist     = Color(0xFFAAB4C8);
  static const Color border   = Color(0xFF1F2D47);
  static const Color success  = Color(0xFF34D399);
  static const Color error    = Color(0xFFFC6B68);

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
// HOME PAGE — navigation shell
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {

  int _current = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  // ── Nav definitions ─────────────────────────────────────────────────────────
  static const _navItems = [
    _NavDef(
      icon:   Icons.grid_view_outlined,
      filled: Icons.grid_view_rounded,
      label:  'Home',
    ),
    _NavDef(
      icon:   Icons.explore_outlined,
      filled: Icons.explore_rounded,
      label:  'Explore',
    ),
    _NavDef(
      icon:   Icons.person_outline_rounded,
      filled: Icons.person_rounded,
      label:  'Profile',
    ),
  ];

  // ── Screens — NON-const list so Firebase-backed widgets initialise correctly ─
  //    IndexedStack requires all children to be valid Widget instances;
  //    using `const` here caused the assertion crash you saw.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Build screens list once — NOT const
    _screens = [
      const DashboardPage(),
      const _ExplorePage(),
      const ProfilePage(),
    ];

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (i == _current) return;
    HapticFeedback.selectionClick();
    _fadeCtrl.forward(from: 0);
    setState(() => _current = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: FadeTransition(
        opacity: _fade,
        // _screens is built in initState — always exactly 3 children,
        // so _current (0/1/2) is always a valid index.
        child: IndexedStack(
          index: _current,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _BottomNav(
        current:  _current,
        items:    _navItems,
        onSelect: _switchTab,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────
class _NavDef {
  final IconData icon;
  final IconData filled;
  final String   label;
  const _NavDef({
    required this.icon,
    required this.filled,
    required this.label,
  });
}

class _BottomNav extends StatelessWidget {
  final int               current;
  final List<_NavDef>     items;
  final ValueChanged<int> onSelect;

  const _BottomNav({
    required this.current,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(top: BorderSide(color: _T.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
                  (i) => _NavTab(
                def:      items[i],
                selected: i == current,
                onTap:    () => onSelect(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final _NavDef      def;
  final bool         selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? _T.indigo.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: _T.indigo.withValues(alpha: 0.22))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? def.filled : def.icon,
                key: ValueKey(selected),
                size: 22,
                color: selected
                    ? _T.indigo
                    : _T.mist.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 4),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? _T.indigo
                    : _T.mist.withValues(alpha: 0.45),
              ),
              child: Text(def.label),
            ),
            const SizedBox(height: 4),
            // Pill pip — expands when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              width:  selected ? 16 : 4,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? _T.indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class _ExplorePage extends StatefulWidget {
  const _ExplorePage();
  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage>
    with SingleTickerProviderStateMixin {

  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  bool  _searchActive = false;

  late AnimationController     _entranceCtrl;
  late List<Animation<double>> _stagger;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _stagger = List.generate(4, (i) {
      final start = i * 0.10;
      return CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(
          start,
          (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );
    });
    _searchFocus.addListener(
            () => setState(() => _searchActive = _searchFocus.hasFocus));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: Stack(children: [
        // Ambient aurora
        Positioned(top: -80, right: -50,
            child: _GlowBlob(color: _T.teal.withValues(alpha: 0.09), size: 260)),
        Positioned(bottom: 80, left: -60,
            child: _GlowBlob(color: _T.indigo.withValues(alpha: 0.08), size: 200)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FadeSlide(anim: _stagger[0], child: _buildHeader()),
                        const SizedBox(height: 20),
                        _FadeSlide(anim: _stagger[0], child: _buildSearch()),
                        const SizedBox(height: 28),

                        _FadeSlide(anim: _stagger[1],
                            child: const _SectionLabel(text: 'Featured')),
                        const SizedBox(height: 14),
                        _FadeSlide(anim: _stagger[1], child: _buildFeatured()),
                        const SizedBox(height: 28),

                        _FadeSlide(anim: _stagger[2],
                            child: const _SectionLabel(text: 'Categories')),
                        const SizedBox(height: 14),
                        _FadeSlide(anim: _stagger[2], child: _buildCategories()),
                        const SizedBox(height: 28),

                        _FadeSlide(anim: _stagger[3],
                            child: const _SectionLabel(text: "What's new")),
                        const SizedBox(height: 14),
                        _FadeSlide(anim: _stagger[3], child: _buildWhatsNew()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Explore', style: _T.display(26)),
        const SizedBox(height: 3),
        Text('Discover features & updates', style: _T.label(13.5)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune_rounded, size: 14,
              color: _T.mist.withValues(alpha: 0.65)),
          const SizedBox(width: 5),
          Text('Filter',
              style: _T.body(12.5,
                  color: _T.mist.withValues(alpha: 0.65),
                  w: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  Widget _buildSearch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: _searchActive
            ? _T.indigo.withValues(alpha: 0.07)
            : _T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchActive ? _T.indigo : _T.border,
          width: _searchActive ? 1.3 : 1,
        ),
        boxShadow: _searchActive
            ? [BoxShadow(
            color: _T.indigo.withValues(alpha: 0.10),
            blurRadius: 12, offset: const Offset(0, 3))]
            : [],
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Icon(Icons.search_rounded, size: 19,
            color: _searchActive
                ? _T.indigo
                : _T.mist.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            focusNode:  _searchFocus,
            style:      _T.body(14.5),
            onChanged:  (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:  'Search features…',
              hintStyle: _T.label(14.5,
                  color: _T.mist.withValues(alpha: 0.35)),
              border:    InputBorder.none,
              isDense:   true,
            ),
          ),
        ),
        if (_searchCtrl.text.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _searchCtrl.clear()),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.close_rounded, size: 17,
                  color: _T.mist.withValues(alpha: 0.5)),
            ),
          ),
      ]),
    );
  }

  Widget _buildFeatured() {
    const features = [
      _FeatureDef(
        title: 'Real-time sync',
        desc:  'Your data updates instantly across every device.',
        icon:  Icons.sync_rounded,
        color: _T.indigo,
      ),
      _FeatureDef(
        title: 'Smart notifications',
        desc:  'Personalised alerts — only what matters to you.',
        icon:  Icons.notifications_active_rounded,
        color: _T.teal,
      ),
      _FeatureDef(
        title: 'End-to-end encrypted',
        desc:  'Zero-knowledge security. Your data stays yours.',
        icon:  Icons.shield_rounded,
        color: _T.amber,
      ),
    ];
    return Column(
      children: features.map((f) => _FeatureCard(def: f)).toList(),
    );
  }

  Widget _buildCategories() {
    const cats = [
      _CatDef(label: 'Analytics', icon: Icons.bar_chart_rounded,          color: _T.indigo),
      _CatDef(label: 'Security',  icon: Icons.verified_user_rounded,       color: _T.rose),
      _CatDef(label: 'Messages',  icon: Icons.chat_bubble_outline_rounded, color: _T.teal),
      _CatDef(label: 'Settings',  icon: Icons.settings_rounded,            color: _T.amber),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: cats.map((c) => _CatCard(def: c)).toList(),
    );
  }

  Widget _buildWhatsNew() {
    const items = [
      _NewsDef(
        tag:      'Update',
        tagColor: _T.success,
        title:    'OTP login is now live',
        subtitle: 'Sign in instantly with a one-time SMS code.',
        icon:     Icons.phonelink_lock_rounded,
      ),
      _NewsDef(
        tag:      'Coming soon',
        tagColor: _T.amber,
        title:    'Usage analytics dashboard',
        subtitle: 'Visualise your data consumption over time.',
        icon:     Icons.area_chart_rounded,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) => Column(children: [
          _NewsRow(
            def:     items[i],
            isFirst: i == 0,
            isLast:  i == items.length - 1,
          ),
          if (i < items.length - 1)
            Divider(color: _T.border, thickness: 1, height: 1),
        ])),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE CHILD WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureDef {
  final String   title;
  final String   desc;
  final IconData icon;
  final Color    color;
  const _FeatureDef({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureDef def;
  const _FeatureCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: def.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(def.icon, color: def.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.title, style: _T.body(14, w: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(def.desc, style: _T.label(12.5), maxLines: 2),
          ],
        )),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: _T.mist.withValues(alpha: 0.3)),
      ]),
    );
  }
}

class _CatDef {
  final String   label;
  final IconData icon;
  final Color    color;
  const _CatDef({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _CatCard extends StatelessWidget {
  final _CatDef def;
  const _CatCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(def.icon, color: def.color, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(def.label,
                style: _T.body(13, w: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _NewsDef {
  final String   tag;
  final Color    tagColor;
  final String   title;
  final String   subtitle;
  final IconData icon;
  const _NewsDef({
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _NewsRow extends StatelessWidget {
  final _NewsDef def;
  final bool     isFirst;
  final bool     isLast;
  const _NewsRow({
    required this.def,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 12, 16, isLast ? 16 : 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: def.tagColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(def.icon, color: def.tagColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: def.tagColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: def.tagColor.withValues(alpha: 0.25)),
              ),
              child: Text(def.tag,
                  style: _T.body(10.5,
                      color: def.tagColor, w: FontWeight.w600)),
            ),
            const SizedBox(height: 5),
            Text(def.title, style: _T.body(13.5, w: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(def.subtitle,
                style: _T.label(12.5), maxLines: 2),
          ],
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Section label — uppercase + hairline divider
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text.toUpperCase(),
          style: _T.label(10.5,
              color: _T.mist.withValues(alpha: 0.55))
              .copyWith(letterSpacing: 1.1)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: _T.border, thickness: 1, height: 1)),
    ]);
  }
}

/// Fade + translate entrance animation
class _FadeSlide extends StatelessWidget {
  final Animation<double> anim;
  final Widget            child;
  const _FadeSlide({required this.anim, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, ch) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: ch,
        ),
      ),
      child: child,
    );
  }
}

/// Ambient glow blob
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
          color: color,
          blurRadius: size / 1.2,
          spreadRadius: size / 5,
        )],
      ),
    );
  }
}

/// Dot grid painter
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022);
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_) => false;
}