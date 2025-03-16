import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';
import 'home_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController resetEmailController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  double _buttonScale = 1.0;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isBiometricEnabled = false;
  String _biometricStatusMessage = '';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // دالة للتحقق من توفر المصادقة البيومترية
  Future<void> _checkBiometrics() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isDeviceSupported;
        _biometricStatusMessage = _canCheckBiometrics
            ? "Biometric authentication is supported on this device."
            : "Biometric authentication is NOT supported on this device.";
      });

      if (_canCheckBiometrics) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            setState(() {
              _isBiometricEnabled = doc['biometricEnabled'] ?? false;
              _biometricStatusMessage = _isBiometricEnabled
                  ? "Biometric is enabled for this user."
                  : "Biometric is supported but not enabled.";
            });
          } else {
            setState(() {
              _biometricStatusMessage = "No user data found in Firestore.";
            });
          }
        } else {
          setState(() {
            _biometricStatusMessage = "No authenticated user found.";
          });
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          _isBiometricEnabled = prefs.getBool('biometricEnabled') ?? _isBiometricEnabled;
          _biometricStatusMessage = _isBiometricEnabled
              ? "Biometric is enabled (SharedPreferences)."
              : _biometricStatusMessage;
        });
      }
    } catch (e) {
      setState(() {
        _biometricStatusMessage = "Error checking biometrics: $e";
      });
    }
  }

  // دالة للمصادقة البيومترية
  Future<void> _authenticateWithBiometrics() async {
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or face to log in',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? storedEmail = prefs.getString('lastLoggedInEmail');
        String? storedPassword = await _secureStorage.read(key: 'securePassword');
        if (storedEmail != null && storedPassword != null) {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: storedEmail,
            password: storedPassword,
          );
          if (userCredential.user != null && userCredential.user!.emailVerified) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            _showMessage("يرجى تفعيل بريدك الإلكتروني أولاً!", Theme.of(context).colorScheme.error);
          }
        } else {
          _showMessage("No secure credentials found. Please log in manually.", Theme.of(context).colorScheme.error);
        }
      }
    } catch (e) {
      _showMessage("Authentication failed: $e", Theme.of(context).colorScheme.error);
    }
  }

  // دالة لتفعيل/تعطيل البصمة مع تحديث Firestore
  Future<void> _toggleBiometric(bool enable) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', enable);
    if (enable) {
      await prefs.setString('lastLoggedInEmail', emailController.text.trim());
      await _secureStorage.write(key: 'securePassword', value: passwordController.text.trim());
    } else {
      await prefs.remove('lastLoggedInEmail');
      await _secureStorage.delete(key: 'securePassword');
    }

    // تحديث Firestore بحالة المصادقة البيومترية
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'biometricEnabled': enable,
          },
          SetOptions(merge: true),
        );
        print("Firestore updated successfully: biometricEnabled = $enable");
      } catch (e) {
        print("Error updating Firestore: $e");
        _showMessage("Failed to update Firestore: $e", Theme.of(context).colorScheme.error);
      }
    } else {
      print("No authenticated user found to update Firestore.");
      _showMessage("No authenticated user found to update Firestore.", Theme.of(context).colorScheme.error);
    }

    setState(() {
      _isBiometricEnabled = enable;
      _biometricStatusMessage = _isBiometricEnabled
          ? "Biometric enabled successfully."
          : "Biometric disabled.";
    });
    _showMessage("Biometric ${enable ? 'enabled' : 'disabled'} successfully.", Theme.of(context).colorScheme.primary);
  }

  // دالة لعرض رسائل التنبيه
  void _showMessage(String msg, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              bgColor == Theme.of(context).colorScheme.error ? Icons.error : Icons.check,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(msg),
          ],
        ),
        backgroundColor: bgColor,
      ),
    );
  }

  // دالة إعادة تعيين كلمة المرور
  Future<void> _resetPassword() async {
    String email = resetEmailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Please enter your email!", Theme.of(context).colorScheme.error);
      return;
    }

    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email)) {
      _showMessage("Please enter a valid email address!", Theme.of(context).colorScheme.error);
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage("تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك!", Theme.of(context).colorScheme.primary);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred!";
      if (e.code == 'user-not-found') {
        message = "No user found with this email.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }
      _showMessage(message, Theme.of(context).colorScheme.error);
    } catch (e) {
      _showMessage("An unexpected error occurred: $e", Theme.of(context).colorScheme.error);
    } finally {
      setState(() {
        _isResettingPassword = false;
      });
    }
  }

  // دالة لعرض نافذة إعادة تعيين كلمة المرور
  void _showResetPasswordDialog() {
    resetEmailController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your email to receive a password reset link:"),
              const SizedBox(height: 10),
              TextField(
                controller: resetEmailController,
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onBackground,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.email,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _isResettingPassword ? null : _resetPassword,
              child: _isResettingPassword
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send Reset Link"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login(BuildContext context) async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    print("Attempting login with email: $email");

    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email)) {
      _showMessage("Please enter a valid email address!", Theme.of(context).colorScheme.error);
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Email and Password are required!", Theme.of(context).colorScheme.error);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        if (!userCredential.user!.emailVerified) {
          setState(() => _isLoading = false);
          _showMessage("يرجى تفعيل بريدك الإلكتروني أولاً! تحقق من بريدك.", Theme.of(context).colorScheme.error);
          await FirebaseAuth.instance.signOut();
          return;
        }

        setState(() {
          _isLoading = false;
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastLoggedInEmail', email);
        await _secureStorage.write(key: 'securePassword', value: password);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      String message = "An error occurred!";
      if (e.code == 'user-not-found') {
        message = "No user found with this email.";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format. Please check your input.";
      } else {
        message = e.message ?? "An unknown error occurred!";
      }
      _showMessage(message, Theme.of(context).colorScheme.error);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Unexpected error: $e");
      _showMessage("An unexpected error occurred: $e", Theme.of(context).colorScheme.error);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.onBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  Icon(
                    Icons.recycling,
                    size: 60,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome Back",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Log in to continue",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _biometricStatusMessage,
                    style: TextStyle(
                      color: _canCheckBiometrics ? Colors.green : Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_canCheckBiometrics && _isBiometricEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: ElevatedButton(
                        onPressed: _authenticateWithBiometrics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Login with Biometrics",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: "Email",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onBackground,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.email,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onBackground,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showResetPasswordDialog();
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_canCheckBiometrics)
                    SwitchListTile(
                      title: const Text('Enable Biometric Login'),
                      value: _isBiometricEnabled,
                      onChanged: (bool value) {
                        _toggleBiometric(value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  )
                      : GestureDetector(
                    onTapDown: (_) => setState(() => _buttonScale = 0.95),
                    onTapUp: (_) {
                      setState(() => _buttonScale = 1.0);
                      _login(context);
                    },
                    onTapCancel: () => setState(() => _buttonScale = 1.0),
                    child: AnimatedScale(
                      scale: _buttonScale,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Log In",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// افتراض أن MyLocation هي كلاس خارجي لجلب الموقع
class MyLocation {
  Future<void> getCurrentLocation() async {
    // تنفيذ منطق جلب الموقع هنا (مثل استخدام geolocator package)
  }

  Future<double> getLatitude() async {
    return 0.0; // استبدل بمنطق حقيقي
  }

  Future<double> getLongitude() async {
    return 0.0; // استبدل بمنطق حقيقي
  }
}