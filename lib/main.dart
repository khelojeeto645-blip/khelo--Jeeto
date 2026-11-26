import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
  runApp(const KheloJeetoApp());
}

class KheloJeetoApp extends StatefulWidget {
  const KheloJeetoApp({super.key});

  @override
  State<KheloJeetoApp> createState() => _KheloJeetoAppState();
}

class _KheloJeetoAppState extends State<KheloJeetoApp> {
  bool _darkMode = false;

  void _toggleTheme(bool isDark) {
    setState(() => _darkMode = isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khelo & Jeeto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF059669),
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return HomeScreen(darkMode: _darkMode, onThemeChanged: _toggleTheme);
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
