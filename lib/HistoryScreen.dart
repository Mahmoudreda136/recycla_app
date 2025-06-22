import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Stream<QuerySnapshot> historyStream;
  int totalScans = 0;
  String mostScannedCategory = 'No Data';
  String lastScanDate = 'No Data';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('User UID: ${user.uid}'); // Log to check the user UID
      historyStream = _buildHistoryStream(user.uid);
    } else {
      print('No user is currently logged in');
      historyStream = const Stream.empty();
    }
  }

  Stream<QuerySnapshot> _buildHistoryStream(String userId) {
    return FirebaseFirestore.instance
        .collection('history')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot historySnapshot = await FirebaseFirestore.instance
          .collection('history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      Map<String, int> categoryCounts = {
        'Plastic': 0,
        'Metal': 0,
        'Cardboard': 0,
        'Paper': 0,
        'Glass': 0,
        'Trash': 0,
      };
      int total = 0;
      String mostScanned = 'No Data';
      int maxScans = 0;
      String lastDate = 'No Data';

      if (historySnapshot.docs.isNotEmpty) {
        print('Number of records: ${historySnapshot.docs.length}');
        for (var doc in historySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? 'Unknown';
          print('Record: $data');
          total++;
          if (categoryCounts.containsKey(category)) {
            categoryCounts[category] = categoryCounts[category]! + 1;
          }
        }

        categoryCounts.forEach((category, count) {
          if (count > maxScans) {
            maxScans = count;
            mostScanned = category;
          }
        });

        final lastDoc = historySnapshot.docs.first;
        final lastTimestamp = (lastDoc['timestamp'] as Timestamp?)?.toDate();
        lastDate = lastTimestamp != null
            ? DateFormat('dd MMMM yyyy, hh:mm a').format(lastTimestamp)
            : 'No Data';
      } else {
        print('No records found in Firestore');
      }

      setState(() {
        totalScans = total;
        mostScannedCategory = mostScanned;
        lastScanDate = lastDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Quick Stats
          FutureBuilder(
            future: _fetchStats(),
            builder: (context, snapshot) {
              return Card(
                elevation: 8,
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: Colors.green[700]!.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Stats',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                        'Total Scans: $totalScans',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        'Most Scanned Category: $mostScannedCategory',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        'Last Scan Date: $lastScanDate',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // History List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: historyStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No history found.', style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final isRewardRedemption = data['type'] == 'reward_redemption';

                    print('سجل [$index]: $data');

                    if (isRewardRedemption) {
                      // عرض سجلات المكافآت المستخدمة
                      final rewardTitle = data['rewardTitle'] ?? 'غير معروف';
                      final pointsDeducted = data['pointsDeducted']?.toString() ?? '0';
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                      final formattedDate = timestamp != null
                          ? DateFormat('dd MMMM yyyy, hh:mm a').format(timestamp)
                          : 'غير متاح';

                      return Card(
                        color: Colors.grey[800],
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(
                            rewardTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'point used : $pointsDeducted',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'date : $formattedDate',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // عرض سجلات المسح (QR codes) زي الأصلي
                      return Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            'QR Code: ${data['qrCode'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category: ${data['category'] ?? 'Unknown'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Points: ${data['points']?.toString() ?? '0'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Date: ${data['timestamp']?.toDate().toString() ?? 'N/A'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}