import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  _ScanQrScreenState createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool isProcessing = false;
  bool hasCameraPermission = false;
  bool isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission().then((_) {
      print('Camera permission check completed.');
    }).catchError((e) {
      print('Error in permission check: $e');
    });
  }

  Future<void> _requestCameraPermission() async {
    print('Requesting camera permission...');
    PermissionStatus status = await Permission.camera.status;
    print('Initial camera permission status: $status');

    if (status.isDenied || status.isPermanentlyDenied) {
      print('Permission denied or permanently denied. Requesting...');
      status = await Permission.camera.request();
      print('Camera permission status after request: $status');
    }

    if (status.isGranted) {
      print('Camera permission granted successfully.');
      setState(() {
        hasCameraPermission = true;
      });
    } else {
      print('Camera permission not granted: $status');
      setState(() {
        hasCameraPermission = false;
      });
      if (status.isPermanentlyDenied) {
        print('Permission permanently denied. Opening app settings...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('الرجاء منح إذن الكاميرا من إعدادات الجهاز'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    try {
      print('Initializing QRView...');
      this.controller = controller;
      setState(() {
        isCameraInitialized = true;
      });
      controller.scannedDataStream.listen((scanData) async {
        if (!isProcessing && scanData.code != null && hasCameraPermission) {
          print('QR Code scanned: ${scanData.code}');
          setState(() {
            result = scanData;
            isProcessing = true;
          });
          await processQrData(scanData.code!);
        }
      }, onError: (error) {
        print('Error scanning QR: $error');
        setState(() {
          isProcessing = false;
          isCameraInitialized = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تشغيل الكاميرا: $error')),
        );
      });
    } catch (e) {
      print('Error initializing QRView: $e');
      setState(() {
        isCameraInitialized = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تهيئة الكاميرا: $e')),
      );
    }
  }

  Future<void> processQrData(String qrData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        setState(() => isProcessing = false);
        controller?.resumeCamera();
        return;
      }

      print('Checking if QR code has been scanned before...');
      final historyRef = FirebaseFirestore.instance
          .collection('history')
          .where('userId', isEqualTo: user.uid)
          .where('qrCode', isEqualTo: qrData);
      final querySnapshot = await historyRef.get();

      if (querySnapshot.docs.isNotEmpty) {
        print('QR code already scanned.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح هذا الكود من قبل!')),
        );
        setState(() => isProcessing = false);
        controller?.resumeCamera();
        return;
      }

      print('Processing QR data: $qrData');
      final category = determineCategory(qrData);
      final points = await callAiModel(qrData);

      print('Updating user points: $points');
      await updateUserPoints(points);

      print('Saving to Firestore history...');
      await FirebaseFirestore.instance.collection('history').add({
        'userId': user.uid,
        'qrCode': qrData,
        'category': category,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('QR processing successful.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة $points نقطة بنجاح! الفئة: $category')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error processing QR data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
      setState(() => isProcessing = false);
      controller?.resumeCamera();
    }
  }

  String determineCategory(String qrData) {
    if (qrData.contains('plastic')) return 'Plastic Bottles';
    if (qrData.contains('paper')) return 'Paper';
    if (qrData.contains('glass')) return 'Glass';
    if (qrData.contains('metal')) return 'Metal Cans';
    return 'Unknown';
  }

  Future<int> callAiModel(String qrData) async {
    await Future.delayed(const Duration(seconds: 1));
    if (qrData.contains('plastic')) return 10;
    if (qrData.contains('paper')) return 5;
    if (qrData.contains('glass')) return 15;
    if (qrData.contains('metal')) return 20;
    return 0;
  }

  Future<void> updateUserPoints(int points) async {
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
    } else {
      throw Exception('المستخدم غير مسجل');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !hasCameraPermission
          ? const Center(
        child: Text(
          'الرجاء منح إذن الكاميرا',
          style: TextStyle(color: Colors.white),
        ),
      )
          : !isCameraInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.greenAccent,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Scan Waste QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}