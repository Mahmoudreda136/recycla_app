import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // للمصادقة
import 'package:cloud_firestore/cloud_firestore.dart'; // لتخزين البيانات في Firestore
import 'login.dart'; // استيراد LoginPage للانتقال السلس

// تعريف Widget EmailVerificationScreen بشكل صحيح
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isSendingVerification = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _checkEmailVerified();
  }

  // التحقق من حالة البريد
  Future<void> _checkEmailVerified() async {
    _user = _auth.currentUser;
    await _user?.reload();
    if (_user != null && _user!.emailVerified) {
      setState(() {
        _isVerified = true;
      });
    }
  }

  // إرسال رابط التحقق
  Future<void> _sendEmailVerification() async {
    if (_user != null && !_user!.emailVerified) {
      setState(() {
        _isSendingVerification = true;
      });
      try {
        await _user!.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رابط التحقق إلى بريدك')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      } finally {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  // تسجيل خروج
  Future<void> _signOut() async {
    await _auth.signOut();
    setState(() {
      _user = null;
      _isVerified = false;
    });
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحقق من البريد الإلكتروني'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_user != null)
              Text(
                'البريد: ${_user!.email}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 20),
            if (_user != null && !_isVerified)
              ElevatedButton(
                onPressed: _isSendingVerification ? null : _sendEmailVerification,
                child: _isSendingVerification
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال رابط التحقق'),
              ),
            if (_isVerified)
              const Text(
                'تم التحقق من البريد الإلكتروني!',
                style: TextStyle(fontSize: 18, color: Colors.green),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signOut,
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  double _buttonScale = 1.0; // لتأثير الضغط على الزر

  // دالة للتحقق من صحة الإيميل
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // دالة للتحقق من صحة رقم الهاتف
  bool _isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$'); // يقبل أرقام مثل +201234567890 أو 0123456789
    return phoneRegex.hasMatch(phone);
  }

  // دالة التسجيل مع إضافة التحقق من البريد
  Future<void> _signup(BuildContext context) async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // التحقق من الحقول
    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage("All fields are required!", Theme.of(context).colorScheme.error);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage("Please enter a valid email address.", Theme.of(context).colorScheme.error);
      return;
    }

    if (!_isValidPhone(phone)) {
      _showMessage("Please enter a valid phone number (e.g., +201234567890).", Theme.of(context).colorScheme.error);
      return;
    }

    if (password.length < 8) {
      _showMessage("Password must be at least 8 characters long.", Theme.of(context).colorScheme.error);
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match!", Theme.of(context).colorScheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // إنشاء حساب جديد باستخدام Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // تحديث ملف تعريف المستخدم باسم (Firebase Auth يدعم الاسم فقط)
        try {
          await userCredential.user!.updateDisplayName(name);
          print("Display name updated successfully: $name");
        } catch (e) {
          print("Error updating display name: $e");
          _showMessage("Failed to update display name: $e", Theme.of(context).colorScheme.error);
        }

        // إرسال رابط التحقق من البريد الإلكتروني
        try {
          await userCredential.user!.sendEmailVerification();
          print("Verification email sent to: $email");
          _showMessage("تم إرسال رابط التحقق إلى بريدك الإلكتروني. تحقق من بريدك!", Theme.of(context).colorScheme.primary);
        } catch (e) {
          print("Error sending verification email: $e");
          _showMessage("فشل إرسال رابط التحقق: $e", Theme.of(context).colorScheme.error);
        }

        // حفظ البيانات في Firestore باستخدام UID كمعرف فريد
        try {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'name': name,
            'phone': phone,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print("User data saved to Firestore: name=$name, phone=$phone, email=$email");
        } catch (e) {
          print("Error saving to Firestore: $e");
          _showMessage("Failed to save data to Firestore: $e", Theme.of(context).colorScheme.error);
          setState(() => _isLoading = false);
          return; // توقف العملية لو فشل التخزين في Firestore
        }

        // إذا نجحت كل العمليات، اعرض رسالة نجاح وانتقل إلى صفحة تسجيل الدخول
        setState(() => _isLoading = false);
        _showMessage("Account created successfully! تحقق من بريدك للتفعيل.", Theme.of(context).colorScheme.primary);
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = "An error occurred!";
      if (e.code == 'weak-password') {
        message = "The password provided is too weak.";
      } else if (e.code == 'email-already-in-use') {
        message = "An account already exists with that email.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }
      _showMessage(message, Theme.of(context).colorScheme.error);
      print("FirebaseAuthException: ${e.code} - ${e.message}");
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("An unexpected error occurred: $e", Theme.of(context).colorScheme.error);
      print("Unexpected error: $e");
    }
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
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: bgColor,
      ),
    );
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
                  // أيقونة رمزية
                  Icon(
                    Icons.person_add,
                    size: 60,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 20),
                  // عنوان احترافي
                  Text(
                    "Create Account",
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
                    "Join us today",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 50),
                  // حقل الاسم
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Name",
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
                        Icons.person,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                  ),
                  const SizedBox(height: 20),
                  // حقل الهاتف
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      hintText: "Phone (e.g., +201234567890)",
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
                        Icons.phone,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  // حقل البريد الإلكتروني
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
                  // حقل كلمة المرور
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
                  const SizedBox(height: 20),
                  // حقل تأكيد كلمة المرور
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
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
                  const SizedBox(height: 40),
                  // زر إنشاء الحساب مع تأثير تفاعلي
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
                      _signup(context);
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
                        child: Text(
                          "Create Account",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // رابط تسجيل الدخول
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        child: Text(
                          "Log In",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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