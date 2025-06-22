import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  _RewardsScreenState createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  int userPoints = 0;
  int totalPoints = 0;
  int paperPoints = 0; // Paper and Cardboard points
  int userLevel = 1;
  bool isLoading = true;
  String selectedCategory = 'All';
  late ConfettiController _confettiController;
  late TabController _tabController;
  late Stream<QuerySnapshot> historyStream;
  final Map<String, String> _countdowns = {};

  final List<Map<String, dynamic>> rewards = [
    {
      'title': '500 EGP Voucher',
      'points': 1000,
      'description': 'Redeem 1000 points for a 500 EGP Fawry voucher, valid for one week.',
      'image': 'assets/image/pound.png',
      'icon': Icons.monetization_on,
      'isFeatured': true,
      'category': 'Vouchers',
      'minLevel': 2,
      'limitedTime': true,
      'expiryDate': DateTime.now().add(const Duration(hours: 48)),
    },
    {
      'title': 'Starbucks Drink',
      'points': 300,
      'description': 'Redeem 300 points for a Starbucks drink voucher.',
      'image': 'assets/image/starbucks.jpg',
      'icon': Icons.local_cafe,
      'isFeatured': false,
      'category': 'Drinks',
      'minLevel': 1,
      'limitedTime': false,
    },
    {
      'title': 'Kamal Saad sketch',
      'points': 120,
      'paperPoints': 50, // Paper points
      'description': 'Redeem 50 paper points for a Kamal Saad sketch.',
      'image': 'assets/image/sketch.jpeg',
      'icon': Icons.book,
      'isFeatured': false,
      'category': 'Paper',
      'minLevel': 1,
      'limitedTime': false,
    },
    {
      'title': 'Small Water Bottle',
      'points': 55,
      'description': 'Redeem 55 points for a small water bottle from any supermarket.',
      'image': 'assets/image/smallbottel.png',
      'icon': Icons.local_drink,
      'isFeatured': false,
      'category': 'Drinks',
      'minLevel': 1,
      'limitedTime': false,
    },
    {
      'title': 'Large Water Bottle',
      'points': 100,
      'description': 'Redeem 100 points for a large water bottle from any supermarket.',
      'image': 'assets/image/largewater.png',
      'icon': Icons.local_drink,
      'isFeatured': false,
      'category': 'Drinks',
      'minLevel': 1,
      'limitedTime': false,
    },
    {
      'title': 'Pepsi Can',
      'points': 100,
      'description': 'Redeem 100 points for a Pepsi can from any supermarket.',
      'image': 'assets/image/pepsi.png',
      'icon': Icons.local_drink,
      'isFeatured': false,
      'category': 'Drinks',
      'minLevel': 1,
      'limitedTime': true,
      'expiryDate': DateTime.now().add(const Duration(hours: 24)),
    },
    {
      'title': 'Recycled Notebook',
      'points': 150,
      'paperPoints': 70, // Paper points
      'description': 'Redeem 70 paper points for a notebook made from recycled paper.',
      'image': 'assets/image/nootbook.jpg',
      'icon': Icons.recycling,
      'isFeatured': false,
      'category': 'Paper',
      'minLevel': 1,
      'limitedTime': false,
    },
    {
      'title': 'Paper Folder',
      'points': 80,
      'paperPoints': 40, // Paper points
      'description': 'Redeem 40 paper points for an eco-friendly paper folder.',
      'image': 'assets/image/paperfolder.webp',
      'icon': Icons.folder,
      'isFeatured': false,
      'category': 'Paper',
      'minLevel': 1,
      'limitedTime': false,
    },
  ];

  List<String> get categories => ['All', 'Vouchers', 'Drinks', 'Paper'];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _tabController = TabController(length: 2, vsync: this);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('Fetching user ID: ${user.uid}');
      historyStream = FirebaseFirestore.instance
          .collection('history')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'reward_redemption')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      print('No user is currently logged in');
      historyStream = const Stream.empty();
    }
    fetchUserPoints();
    _startCountdownTimers();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startCountdownTimers() {
    for (var reward in rewards.where((r) => r['limitedTime'] == true)) {
      final expiryDate = reward['expiryDate'] as DateTime;
      _countdowns[reward['title']] = _formatCountdown(expiryDate.difference(DateTime.now()));
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _countdowns[reward['title']] = _formatCountdown(expiryDate.difference(DateTime.now()));
          });
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> fetchUserPoints() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Fetching user points: ${user.uid}');
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          print('User data: $data');
          setState(() {
            userPoints = data['points'] ?? 0;
            totalPoints = data['totalPoints'] ?? 0;
            paperPoints = data['paperPoints'] ?? 0;
            userLevel = calculateLevel(totalPoints);
            isLoading = false;
          });
        } else {
          print('User document not found, creating new document');
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'points': 0,
            'totalPoints': 0,
            'paperPoints': 0,
          }, SetOptions(merge: true));
          setState(() {
            isLoading = false;
            userPoints = 0;
            totalPoints = 0;
            paperPoints = 0;
            userLevel = 1;
          });
        }
      } else {
        print('No user is currently logged in');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error fetching user points: $e');
      setState(() {
        isLoading = false;
        userPoints = 0;
        totalPoints = 0;
        paperPoints = 0;
        userLevel = 1;
      });
    }
  }

  Future<void> updateTotalPoints(int newPoints, {bool isPaperPoints = false}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Updating points: $newPoints for user: ${user.uid}, paper: $isPaperPoints');
        Map<String, dynamic> updateData = {};
        if (isPaperPoints) {
          updateData['paperPoints'] = FieldValue.increment(newPoints);
        } else {
          updateData['points'] = FieldValue.increment(newPoints);
          updateData['totalPoints'] = FieldValue.increment(newPoints);
        }
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);
        setState(() {
          if (isPaperPoints) {
            paperPoints += newPoints;
            print('Updated paper points: paperPoints=$paperPoints');
          } else {
            userPoints += newPoints;
            totalPoints += newPoints;
            userLevel = calculateLevel(totalPoints);
            print('Updated regular points: userPoints=$userPoints, totalPoints=$totalPoints, userLevel=$userLevel');
          }
        });
      } else {
        print('No user is currently logged in');
      }
    } catch (e) {
      print('Error updating points: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating points: $e')),
      );
    }
  }

  int calculateLevel(int totalPoints) {
    return (totalPoints ~/ 200) + 1;
  }

  double calculateProgress() {
    if (totalPoints == 0) return 0.0;
    double progress = (totalPoints % 200) / 200;
    return progress == 0 ? 1.0 : progress;
  }

  int pointsNeededForNextLevel() {
    if (totalPoints == 0) return 200;
    return 200 - (totalPoints % 200);
  }

  String _generateRandomCode(String rewardTitle) {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    String randomPart = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    String prefix = rewardTitle.toUpperCase().replaceAll(' ', '-');
    return '$prefix-$randomPart-EXP7D';
  }

  Future<void> _redeemReward(int requiredPoints, String rewardTitle, int minLevel, {int? requiredPaperPoints}) async {
    if (userLevel < minLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to be at least level $minLevel to redeem this reward')),
      );
      return;
    }

    if (requiredPaperPoints != null) {
      if (paperPoints < requiredPaperPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You don\'t have enough paper points to redeem this reward')),
        );
        return;
      }
    } else {
      if (userPoints < requiredPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You don\'t have enough points to redeem this reward')),
        );
        return;
      }
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you want to redeem ${requiredPaperPoints ?? requiredPoints} ${requiredPaperPoints != null ? 'paper' : ''} points for $rewardTitle?'),
            const SizedBox(height: 10),
            Text(requiredPaperPoints != null
                ? 'Current paper points: $paperPoints'
                : 'Current points: $userPoints'),
            Text(requiredPaperPoints != null
                ? 'Paper points after redemption: ${paperPoints - requiredPaperPoints}'
                : 'Points after redemption: ${userPoints - requiredPoints}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String code = _generateRandomCode(rewardTitle);
          print('Redeeming reward: $rewardTitle with ${requiredPaperPoints ?? requiredPoints} ${requiredPaperPoints != null ? 'paper' : ''} points');

          Map<String, dynamic> updateData = {};
          if (requiredPaperPoints != null) {
            updateData['paperPoints'] = FieldValue.increment(-requiredPaperPoints);
          } else {
            updateData['points'] = FieldValue.increment(-requiredPoints);
            updateData['totalPoints'] = FieldValue.increment(requiredPoints);
          }
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);

          await FirebaseFirestore.instance.collection('history').add({
            'userId': user.uid,
            'rewardTitle': rewardTitle,
            'pointsDeducted': requiredPaperPoints ?? requiredPoints,
            'code': code,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'reward_redemption',
          });

          setState(() {
            if (requiredPaperPoints != null) {
              paperPoints -= requiredPaperPoints;
              print('Deducted paper points: paperPoints=$paperPoints');
            } else {
              userPoints -= requiredPoints;
              totalPoints += requiredPoints;
              userLevel = calculateLevel(totalPoints);
              print('Deducted regular points: userPoints=$userPoints, totalPoints=$totalPoints, userLevel=$userLevel');
            }
          });

          print('Points after redemption - userPoints: $userPoints, paperPoints: $paperPoints');

          _confettiController.play();

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reward Redeemed!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your code for $rewardTitle:'),
                  const SizedBox(height: 10),
                  Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('This code is valid for one week.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          print('No user is currently logged in during redemption');
        }
      } catch (e) {
        print('Error redeeming reward: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error redeeming reward: $e')),
        );
      }
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) return 'Expired';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours}h ${minutes}m ${seconds}s';
  }

  void _showPointsSystemInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Points and Rewards System'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to the Rewards System!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                'The app is designed to encourage recycling and protect the environment by rewarding you for every step you take!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 15),
              Text(
                '1. How to Earn Points?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '• Regular Points: Earn points by scanning QR codes for recyclable materials (like plastic, metal, or glass) or completing daily tasks in the app, such as answering environmental questions or attending recycling events.\n'
                    '• Paper Points (Paper/Cardboard): Earn paper points by recycling paper or cardboard. Each time you scan a QR code for paper or cardboard, you’ll earn dedicated paper points.',
              ),
              SizedBox(height: 15),
              Text(
                '2. How to Redeem Rewards?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '• In the "Available Rewards" tab, choose the reward you want (e.g., voucher, drink, or paper product).\n'
                    '• For regular rewards (like a 500 EGP voucher), you’ll need regular points. For paper rewards (like a recycled notebook), you’ll need paper points.\n'
                    '• Tap the reward, and if you have enough points, confirm the redemption. You’ll get a code valid for one week to use when claiming the reward.',
              ),
              SizedBox(height: 15),
              Text(
                '3. Level System',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '• Every 200 regular points increase your level (e.g., 200 points for Level 2, 400 points for Level 3, and so on).\n'
                    '• Higher levels unlock exclusive rewards, like the 500 EGP voucher that requires Level 2.\n'
                    '• Paper points don’t affect your level but are used to redeem paper products.',
              ),
              SizedBox(height: 15),
              Text(
                '4. Paper Products',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '• Paper products (like notebooks or folders) are made from recycled materials to support the environment.\n'
                    '• Redeem these products with paper points (Paper/Cardboard) earned from recycling paper or cardboard.\n'
                    '• Examples: Kamal Saad Notebook (50 paper points), Paper Folder (40 paper points).',
              ),
              SizedBox(height: 15),
              Text(
                '5. Why Recycling Matters?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '• Recycling paper and cardboard reduces waste and conserves natural resources like trees.\n'
                    '• The app encourages you to contribute to a cleaner environment through rewards that motivate you to recycle more.\n'
                    '• Every paper point you earn is a step toward a greener planet!',
              ),
              SizedBox(height: 15),
              Text(
                'Start Now!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                'Scan QR codes, complete tasks, and start earning regular and paper points. Redeem them for awesome rewards and help protect the environment!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showPointsSystemInfo,
            tooltip: 'Points System Info',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: 'Available Rewards'),
            Tab(text: 'Used Rewards'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                // Available Rewards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Level Section
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Level $userLevel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: calculateProgress(),
                              backgroundColor: Colors.grey[600],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Current Points: $userPoints | Total Points: $totalPoints',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              pointsNeededForNextLevel() > 0
                                  ? 'Points Needed for Next Level: ${pointsNeededForNextLevel()}'
                                  : 'You’ve reached the highest level!',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Category Filter
                      DropdownButton<String>(
                        value: selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value!;
                          });
                        },
                        items: categories
                            .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                            .toList(),
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        iconEnabledColor: Colors.white,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Available Rewards',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: AnimationLimiter(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 0.65,
                            ),
                            itemCount: rewards
                                .where((reward) =>
                            selectedCategory == 'All' || reward['category'] == selectedCategory)
                                .length,
                            itemBuilder: (context, index) {
                              final reward = rewards
                                  .where((reward) =>
                              selectedCategory == 'All' || reward['category'] == selectedCategory)
                                  .toList()[index];
                              final bool isFeatured = reward['isFeatured'] ?? false;
                              final bool isLimitedTime = reward['limitedTime'] ?? false;
                              final DateTime? expiryDate = reward['expiryDate'];
                              final bool isPaperReward = reward['category'] == 'Paper';
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                columnCount: 2,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: GestureDetector(
                                      onTap: () {
                                        _redeemReward(
                                          reward['points'],
                                          reward['title'],
                                          reward['minLevel'],
                                          requiredPaperPoints: reward['paperPoints'],
                                        );
                                      },
                                      child: Card(
                                        elevation: isFeatured ? 12 : 8,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          side: BorderSide(
                                            color: isFeatured
                                                ? Colors.greenAccent.withOpacity(0.5)
                                                : Colors.green[700]!.withOpacity(0.3),
                                            width: isFeatured ? 2 : 1,
                                          ),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isFeatured
                                                  ? [Colors.green[900]!, Colors.green[700]!]
                                                  : [Colors.grey[800]!, Colors.grey[900]!],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(15),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isFeatured
                                                    ? Colors.greenAccent.withOpacity(0.5)
                                                    : Colors.black26,
                                                blurRadius: isFeatured ? 15 : 5,
                                                spreadRadius: isFeatured ? 5 : 0,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(10.0),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (isFeatured)
                                                      Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          Container(
                                                            height: 80,
                                                            width: 80,
                                                            child: CircularProgressIndicator(
                                                              value: userPoints >= 1000
                                                                  ? 1.0
                                                                  : userPoints / 1000,
                                                              backgroundColor: Colors.grey[600],
                                                              valueColor: const AlwaysStoppedAnimation<
                                                                  Color>(Colors.greenAccent),
                                                              strokeWidth: 8,
                                                            ),
                                                          ),
                                                          Container(
                                                            height: 60,
                                                            width: 60,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(15),
                                                              border: Border.all(
                                                                  color: Colors.white12, width: 2),
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(15),
                                                              child: Image.asset(
                                                                reward['image'],
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (context, error, stackTrace) {
                                                                  return Container(
                                                                    color: Colors.grey,
                                                                    child: const Center(
                                                                      child: Text(
                                                                        'Failed to load image',
                                                                        style: TextStyle(color: Colors.white),
                                                                        textAlign: TextAlign.center,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    else
                                                      Container(
                                                        height: 80,
                                                        width: 80,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(15),
                                                          border:
                                                          Border.all(color: Colors.white12, width: 2),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(15),
                                                          child: Image.asset(
                                                            reward['image'],
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                color: Colors.grey,
                                                                child: const Center(
                                                                  child: Text(
                                                                    'Failed to load image',
                                                                    style: TextStyle(color: Colors.white),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          reward['icon'],
                                                          color: Colors.white70,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          reward['title'],
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            shadows: [
                                                              Shadow(
                                                                color: Colors.black26,
                                                                offset: Offset(1, 1),
                                                                blurRadius: 3,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      reward['description'],
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      isPaperReward
                                                          ? '${reward['paperPoints']} Paper Points'
                                                          : '${reward['points']} Points',
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (isPaperReward)
                                                      const Text(
                                                        'Important: Paper Points Only',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          color: Colors.white60,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    if (isLimitedTime && expiryDate != null)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8.0),
                                                        child: Text(
                                                          'Expires in: ${_countdowns[reward['title']] ?? 'Loading...'}',
                                                          style: const TextStyle(
                                                            color: Colors.redAccent,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (isLimitedTime)
                                                Positioned(
                                                  top: 10,
                                                  right: 10,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.redAccent,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Text(
                                                      'Limited Offer',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Used Rewards
                StreamBuilder<QuerySnapshot>(
                  stream: historyStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      print('Error fetching used rewards history: ${snapshot.error}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Error fetching reward history. Try again later.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {});
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      print('No used rewards found in Firestore');
                      return const Center(
                        child: Text(
                          'No rewards used yet',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final history = snapshot.data!.docs;
                    print('Number of used rewards records: ${history.length}');

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final data = history[index].data() as Map<String, dynamic>;
                        final rewardTitle = data['rewardTitle'] ?? 'Unknown';
                        final pointsDeducted = data['pointsDeducted']?.toString() ?? '0';
                        final code = data['code'] ?? 'Not Available';
                        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                        final formattedDate = timestamp != null
                            ? DateFormat('dd MMMM yyyy, hh:mm a').format(timestamp)
                            : 'Not Available';

                        print('Reward record [$index]: $data');

                        return Card(
                          color: Colors.grey[800],
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              'Reward: $rewardTitle',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Points Used: $pointsDeducted',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  'Code: $code',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  'Date: $formattedDate',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }
}