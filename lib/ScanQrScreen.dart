import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool isProcessing = false;
  String? scannedCode;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    print('Checking camera permission...');
    PermissionStatus status = await Permission.camera.status;
    print('Camera permission status: $status');

    if (status.isGranted) {
      print('Camera permission is already granted.');
      _scanQrCode();
    } else {
      print('Camera permission denied: $status');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              await openAppSettings();
            },
          ),
        ),
      );
    }
  }

  Future<void> _scanQrCode() async {
    try {
      print('Starting QR code scan...');
      var result = await BarcodeScanner.scan();
      print('Scan result: ${result.rawContent}');

      if (result.rawContent.isNotEmpty) {
        setState(() {
          scannedCode = result.rawContent;
          isProcessing = true;
        });
        await _processScannedData(scannedCode!);
      } else {
        print('No QR code scanned.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No QR Code scanned'),
            action: SnackBarAction(
              label: 'Retry Scan',
              onPressed: _scanQrCode,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error scanning QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during scan: $e'),
          action: SnackBarAction(
            label: 'Retry Scan',
            onPressed: _scanQrCode,
          ),
        ),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _processScannedData(String qrData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in first'),
            action: SnackBarAction(
              label: 'Retry Scan',
              onPressed: _scanQrCode,
            ),
          ),
        );
        return;
      }

      print('Checking if QR code already scanned: $qrData');
      final historyRef = FirebaseFirestore.instance
          .collection('history')
          .where('qrCode', isEqualTo: qrData);
      final existing = await historyRef.get();

      if (existing.docs.isNotEmpty) {
        print('QR code already exists in history: $qrData');
        for (var doc in existing.docs) {
          print('Existing QR Code in history: ${doc['qrCode']}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This QR Code has already been used!'),
            action: SnackBarAction(
              label: 'Retry Scan',
              onPressed: _scanQrCode,
            ),
          ),
        );
        return;
      }

      print('Processing QR data: $qrData');
      final category = _determineCategory(qrData);

      if (category == 'Unknown') {
        print('QR code category is unknown: $qrData');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This QR Code is unknown'),
            action: SnackBarAction(
              label: 'Retry Scan',
              onPressed: _scanQrCode,
            ),
          ),
        );
        return;
      }

      final points = await _callAiModel(qrData);

      print('Updating user points: $points');
      await _updateUserPoints(points);

      print('Saving to Firestore history...');
      await FirebaseFirestore.instance.collection('history').add({
        'userId': user.uid,
        'qrCode': qrData,
        'category': category,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Fetch total points from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      int totalPoints = userDoc.exists && userDoc['points'] != null ? userDoc['points'] : 0;

      // Fetch the number of items in the same category
      QuerySnapshot categoryItems = await FirebaseFirestore.instance
          .collection('history')
          .where('userId', isEqualTo: user.uid)
          .where('category', isEqualTo: category)
          .get();
      int categoryCount = categoryItems.docs.length;

      print('QR processing successful.');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scan Successful!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: $category'),
              Text('Points Added: $points'),
              Text('Total Points: $totalPoints'),
              Text('Items in $category: $categoryCount'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error processing QR data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error occurred: $e'),
          action: SnackBarAction(
            label: 'Retry Scan',
            onPressed: _scanQrCode,
          ),
        ),
      );
    }
  }

  String _determineCategory(String qrData) {
    if (qrData.contains('plastic') || qrData.contains('بلاستيك')) return 'Plastic';
    if (qrData.contains('metal') || qrData.contains('معدن')) return 'Metal';
    if (qrData.contains('cardboard') || qrData.contains('كرتون')) return 'Cardboard';
    if (qrData.contains('paper') || qrData.contains('ورق')) return 'Paper';
    if (qrData.contains('glass') || qrData.contains('زجاج')) return 'Glass';
    if (qrData.contains('trash') || qrData.contains('نفايات')) return 'Trash';
    return 'Unknown';
  }

  Future<int> _callAiModel(String qrData) async {
    await Future.delayed(const Duration(seconds: 1));
    if (qrData.contains('plastic') || qrData.contains('بلاستيك')) return 10;
    if (qrData.contains('metal') || qrData.contains('معدن')) return 20;
    if (qrData.contains('cardboard') || qrData.contains('كرتون')) return 8;
    if (qrData.contains('paper') || qrData.contains('ورق')) return 5;
    if (qrData.contains('glass') || qrData.contains('زجاج')) return 15;
    if (qrData.contains('trash') || qrData.contains('نفايات')) return 2;
    return 0;
  }

  Future<void> _updateUserPoints(int points) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set(
        {
          'points': FieldValue.increment(points),
          'last_updated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('Points updated successfully: $points');
    } else {
      throw Exception('User not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Waste QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E2E2E), Color(0xFF1A1A1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isProcessing
              ? const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 100,
                color: Colors.white70,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tap to scan QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 500),
                child: ElevatedButton(
                  onPressed: () async {
                    if (await Vibrate.canVibrate) {
                      Vibrate.feedback(FeedbackType.light);
                    }
                    _scanQrCode();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ensure the QR Code is clear and well-lit',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}