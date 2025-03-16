import 'package:flutter/material.dart';

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward().whenComplete(() {
      // الانتقال إلى صفحات التعريف بعد انتهاء الأنيميشن
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: const LogoContainer(),
            ),
          ),
        ],
      ),
    );
  }
}

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3; // عدد الصفحات (يمكنك تغييره)

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // الانتقال إلى WelcomeScreen بدلاً من LoginPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  void _skip() {
    // الانتقال إلى WelcomeScreen عند الضغط على Skip
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: const [
                    OnboardingPage(
                      imagePath: 'assets/planet.png',
                      title: 'Save our Planet!',
                      subtitle: 'Sort trash with others to protect our environment.',
                    ),
                    OnboardingPage(
                      imagePath: 'assets/community.png',
                      title: 'Join the Community!',
                      subtitle: 'Connect with users worldwide to make a difference.',
                    ),
                    OnboardingPage(
                      imagePath: 'assets/recycle.png',
                      title: 'Start Today!',
                      subtitle: 'Help save the planet for future generations.',
                    ),
                  ],
                ),
              ),
              // Dots Indicator and Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip Button
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Dots Indicator
                    Row(
                      children: List.generate(
                        _totalPages,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: _currentPage == index ? 12 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Next Button
                    TextButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage == _totalPages - 1 ? 'Finish' : 'Next',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Onboarding Page Widget
class OnboardingPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const OnboardingPage({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LogoContainer(imagePath: imagePath),
          const SizedBox(height: 30),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Welcome Screen
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title: Recycle
                Text(
                  'Recycle',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                // Recycle Logo
                Container(
                  width: 100,
                  height: 100,
                  child: Image.asset(
                    'assets/recycle_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.recycling,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Subtitle and Description
                Text(
                  "Let's get Started",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Never a better time than now to start.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // SignUp Now Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/signup');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C4B4), // لون الزر (مطابق للصورة: teal)
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'SignUp Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modified LogoContainer to accept imagePath
class LogoContainer extends StatelessWidget {
  final String imagePath;

  const LogoContainer({super.key, this.imagePath = 'assets/planet.png'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          color: Colors.white,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.image_not_supported,
            color: Colors.white,
            size: 50,
          ),
        ),
      ),
    );
  }
}

class AppTitleText extends StatelessWidget {
  const AppTitleText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Save our planet!', // النص الجديد من الصورة
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontSize: 28, // ضبط الحجم ليتناسب مع التصميم
      ),
    );
  }
}

class AppSubtitleText extends StatelessWidget {
  const AppSubtitleText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sort trash with other users and help save the planet for posterity', // النص الجديد من الصورة
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        shadows: const [
          Shadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
        fontSize: 16, // ضبط الحجم ليتناسب مع التصميم
      ),
      textAlign: TextAlign.center, // محاذاة النص في المنتصف
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget? child;

  const GradientBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}