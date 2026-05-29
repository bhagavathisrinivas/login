import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Pages ─────────────────────────────────────────────────────────────────────
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/admin_register_page.dart';
import 'pages/admin_dashboard_page.dart';

// ─── Global Navigator Key ─────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Main ─────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      statusBarBrightness:      Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

// ─── App ──────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuthApp',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // ── Theme ───────────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF7C6FFF),
          secondary: Color(0xFF4ECDC4),
          surface:   Color(0xFF12122A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B1E),
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // ── Home ────────────────────────────────────────────────────────────────
      home: const AuthGate(),

      // ── Routes ──────────────────────────────────────────────────────────────
      routes: {
        '/login':            (_) => const LoginPage(),
        '/register':         (_) => const RegisterPage(),
        '/home':             (_) => const HomePage(),
        '/dashboard':        (_) => const DashboardPage(),
        '/forgot-password':  (_) => const ForgotPasswordPage(),
        '/admin-register':   (_) => const AdminRegisterPage(),
        '/admin-dashboard':  (_) => const AdminDashboardPage(),
      },

      // ── Dynamic routes (need arguments) ────────────────────────────────────
      onGenerateRoute: (settings) {
        if (settings.name == '/reset-password') {
          final oobCode = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => ResetPasswordPage(oobCode: oobCode),
          );
        }
        return null;
      },
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────────────────
// Checks Firebase auth state AND Firestore role → routes accordingly
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {

        // ── Loading ───────────────────────────────────────────────────────────
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // ── Not logged in ─────────────────────────────────────────────────────
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginPage();
        }

        // ── Logged in — check role from Firestore ─────────────────────────────
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnap.data!.uid)
              .get(),
          builder: (context, roleSnap) {

            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            // Role not found — send to login
            if (!roleSnap.hasData || !roleSnap.data!.exists) {
              return const LoginPage();
            }

            final data = roleSnap.data!.data() as Map<String, dynamic>?;
            final role = data?['role'] as String? ?? 'user';

            // Route by role
            if (role == 'admin') {
              return const AdminDashboardPage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C6FFF), Color(0xFF5A4FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C6FFF).withValues(alpha: 0.40),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF7C6FFF)),
                strokeWidth: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}