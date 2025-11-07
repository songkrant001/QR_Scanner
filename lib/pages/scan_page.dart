// lib/pages/scan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeFormat;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_scanner/db/color_provider.dart';
import 'package:qr_scanner/pages/result_page.dart';
import '../db/database_helper.dart';
import '../models/qr_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';


class ScanPage extends ConsumerStatefulWidget {
  final Function(Widget) onOpenResult; // ✅ รับ callback จาก MainPage
  const ScanPage({Key? key,required this.onOpenResult}) : super(key: key);
  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  final db = DatabaseHelper();
  late String datatext ;

  void _handleBarcode(BarcodeCapture capture) async {
    print("okkkkk");
    print(_isProcessing);
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    setState(() => _isProcessing = true);

    // บันทึกลงฐานข้อมูล (scan)
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final item = QRItem(text: raw, type: 'scan', date: now, imagePath: null);
    await db.insertItem(item);

    // แสดง dialog กับปุ่ม
    //if (!mounted) return;
    widget.onOpenResult(ResultPage(datatext: raw,isCreate: false));


    await Future.delayed(const Duration(milliseconds: 400));
    _isProcessing = false;

  }

   // ฟังก์ชันสแกนจากรูปใน gallery โดยใช้ ML Kit
  Future<void> _scanFromGallery() async {
    if (_isProcessing) return;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isProcessing = true);

      final path = picked.path;
      final inputImage = mlkit.InputImage.fromFilePath(path);

      final barcodeScanner = mlkit.BarcodeScanner(
        formats: mlkit.BarcodeFormat.values.toList() // รองรับทุกรูปแบบที่ ML Kit มี
      );

      final List<mlkit.Barcode> barcodes = await barcodeScanner.processImage(inputImage);

      await barcodeScanner.close();

      if (barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ QR/Barcode ในภาพ')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      // ใช้ตัวแรก (หรือวนเป็นรายการได้)
      final raw = barcodes.first.rawValue ?? '';
      if (raw.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อ่านข้อมูลไม่สำเร็จ')),
        );
        setState(() => _isProcessing = false);
        return;
      }

       datatext = raw;
      // บันทึกลง DB (ตัวอย่าง)
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final item = QRItem(text: raw, type: 'scan', date: now, imagePath: path);
      await db.insertItem(item);

      // แสดง dialog ผลลัพธ์ + ปุ่มแชร์
      if (!mounted) return;
       widget.onOpenResult(ResultPage(datatext: datatext,isCreate: false,path: path));
       print(path);
    } catch (e, st) {
      debugPrint('scanFromGallery error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }


  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final ColorSelect = ref.watch(colorProvider); 
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: 
            _handleBarcode,
          ),
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'flash',
              onPressed: () => cameraController.toggleTorch(),
              child: const Icon(Icons.flash_on),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'switch',
              onPressed: () => cameraController.switchCamera(),
              child: const Icon(Icons.cameraswitch),
            ),
          ),

                    Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                heroTag: 'gallery',
                backgroundColor: ColorSelect,
                icon: const Icon(Icons.photo_library,color: Colors.white),
                label: Text(_isProcessing ? 'กำลังสแกน...' : 'เลือกรูปจากคลัง',style: TextStyle(color: Colors.white),),
                onPressed: _isProcessing ? null : _scanFromGallery,
              ),
            ),
          ),

          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
