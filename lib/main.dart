import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'firebase_options.dart'; // الملف flutterfire configure
import 'login.dart'; // Import login page
import 'signup_page.dart'; // Import signup page
import 'onboarding.dart'; // Import onboarding screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
      builder: (context, themeModel, child) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // تحديد الصفحة الرئيسية بناءً على حالة المستخدم
            Widget initialPage;
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                initialPage = const LoginPage(); // لو مسجل الدخول، ابقى في LoginPage
              } else {
                initialPage = const SplashScreen(); // لو مش مسجل، روح للشاشة الرئيسية
              }
            } else {
              initialPage = const SplashScreen(); // لو لسه بيتصل، ابقى في SplashScreen
            }

            return MaterialApp(
              title: 'Recycle App',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.grey,
                  brightness: Brightness.light,
                  primary: Colors.grey[800]!,
                  secondary: Colors.grey[300]!,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.grey[200],
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                  bodyMedium: TextStyle(color: Colors.black54, fontFamily: 'Roboto'),
                  headlineLarge: TextStyle(color: Colors.black87, fontFamily: 'Roboto', fontWeight: FontWeight.bold),
                  headlineMedium: TextStyle(color: Colors.black87, fontFamily: 'Roboto', fontWeight: FontWeight.bold),
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.grey,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.grey[900],
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                  bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Roboto'),
                  headlineLarge: TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.bold),
                  headlineMedium: TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.bold),
                ),
              ),
              themeMode: themeModel.themeMode,
              initialRoute: '/',
              routes: {
                '/': (context) => initialPage,
                '/login': (context) => const LoginPage(),
                '/signup': (context) => const SignupPage(),
              },
              onUnknownRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: Text('Page not found: ${settings.name}'),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Theme Model for state management
class ThemeModel with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode

  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}