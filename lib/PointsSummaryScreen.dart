import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class PointsSummaryScreen extends StatefulWidget {
  const PointsSummaryScreen({super.key});

  @override
  _PointsSummaryScreenState createState() => _PointsSummaryScreenState();
}

class _PointsSummaryScreenState extends State<PointsSummaryScreen> {
  int totalPoints = 0;
  Map<String, int> categoryPoints = {
    'Plastic': 0,
    'Metal': 0,
    'Cardboard': 0,
    'Paper': 0,
    'Glass': 0,
    'Trash': 0,
  };
  Map<String, int> categoryCounts = {
    'Plastic': 0,
    'Metal': 0,
    'Cardboard': 0,
    'Paper': 0,
    'Glass': 0,
    'Trash': 0,
  };
  bool isLoading = true;
  String mostScannedCategory = 'No Data';
  int totalScannedItems = 0;

  @override
  void initState() {
    super.initState();
    fetchPointsData();
  }

  Future<void> fetchPointsData() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('User UID: ${user.uid}');

        // Fetch total points from the 'users' collection
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          totalPoints = userData['points'] ?? 0;
        } else {
          print('User document not found in Firestore');
          totalPoints = 0;
        }

        // Fetch history from the 'history' collection and calculate points and counts for each category
        QuerySnapshot historySnapshot = await FirebaseFirestore.instance
            .collection('history')
            .where('userId', isEqualTo: user.uid)
            .get();

        Map<String, int> tempCategoryPoints = {
          'Plastic': 0,
          'Metal': 0,
          'Cardboard': 0,
          'Paper': 0,
          'Glass': 0,
          'Trash': 0,
        };
        Map<String, int> tempCategoryCounts = {
          'Plastic': 0,
          'Metal': 0,
          'Cardboard': 0,
          'Paper': 0,
          'Glass': 0,
          'Trash': 0,
        };

        for (var doc in historySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? 'Unknown';
          int points = data['points']?.toInt() ?? 0;

          if (tempCategoryPoints.containsKey(category)) {
            tempCategoryPoints[category] = tempCategoryPoints[category]! + points;
            tempCategoryCounts[category] = tempCategoryCounts[category]! + 1;
          }
        }

        // Determine the most scanned category
        String mostScanned = 'No Data';
        int maxScans = 0;
        int totalItems = 0;
        tempCategoryCounts.forEach((category, count) {
          totalItems += count;
          if (count > maxScans) {
            maxScans = count;
            mostScanned = category;
          }
        });

        setState(() {
          categoryPoints = tempCategoryPoints;
          categoryCounts = tempCategoryCounts;
          mostScannedCategory = mostScanned;
          totalScannedItems = totalItems;
          isLoading = false;
        });
      } else {
        print('No user is currently logged in');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error fetching points data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Plastic':
        return Icons.local_drink;
      case 'Metal':
        return Icons.hardware;
      case 'Cardboard':
        return Icons.archive;
      case 'Paper':
        return Icons.description;
      case 'Glass':
        return Icons.local_bar;
      case 'Trash':
        return Icons.delete;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points Summary'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchPointsData,
            tooltip: 'Refresh Data',
          ),
        ],
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : AnimationLimiter(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 375),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: widget,
                    ),
                  ),
                  children: [
                    // Total Points
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: Colors.green[700]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[800]!,
                              Colors.grey[900]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.yellow, size: 40),
                                  const SizedBox(width: 15),
                                  Text(
                                    'Total Points: $totalPoints',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: totalPoints / 1000, // Target is 1000 points
                                backgroundColor: Colors.grey[600],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                minHeight: 8,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Your Progress Towards 1000 Points',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Points by Category Header
                    Text(
                      'Points by Category',
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
                    // Display Points for Each Category
                    ...categoryPoints.entries.map((entry) {
                      return Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: Colors.green[700]!.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[800]!,
                                Colors.grey[900]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getIconForCategory(entry.key),
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      entry.key,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Points: ${entry.value}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Items Count: ${categoryCounts[entry.key]}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                    // Additional Stats
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: Colors.green[700]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[800]!,
                              Colors.grey[900]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Additional Stats',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Most Scanned Category: $mostScannedCategory',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Total Scanned Items: $totalScannedItems',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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
  }
}