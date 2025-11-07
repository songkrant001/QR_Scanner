import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_scanner/db/color_provider.dart';
import 'package:qr_scanner/models/qr_item.dart';
import 'package:qr_scanner/pages/result_page.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

class CreateQrPage extends ConsumerStatefulWidget {
    final Function(Widget) onOpenResult;
  const CreateQrPage({super.key,required this.onOpenResult});

  @override
  ConsumerState<CreateQrPage> createState() => _CreateQrPageState();
}

class _CreateQrPageState extends ConsumerState<CreateQrPage> {
  String type = 'text';
  String qrData = '';
  final controller1 = TextEditingController();
  final controller2 = TextEditingController();
  final controller3 = TextEditingController();
  final GlobalKey globalKey = GlobalKey();
  final db = DatabaseHelper();
  final FocusNode focusNodeText = FocusNode();

  String generateQR() {
    switch (type) {
      case 'url':
        return qrData = controller1.text;

      case 'phone':
        return qrData = 'tel:${controller1.text}';

      case 'sms':
        return qrData = 'sms:${controller1.text}?body=${controller2.text}';

      case 'email':
        return qrData = 'mailto:${controller1.text}';

      case 'wifi':
        return qrData =
            'WIFI:T:WPA;S:${controller1.text};P:${controller2.text};;';

      case 'geo':
        return qrData = 'geo:${controller1.text},${controller2.text}';

      default:
        return qrData = controller1.text;
    }

    //setState(() {});
  }

  Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    // ✅ สำหรับ Android 13 (API 33) ขึ้นไป
    if (await Permission.photos.isDenied || await Permission.videos.isDenied) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();

      if (photos.isGranted || videos.isGranted) {
        print('✅ ได้รับสิทธิ์อ่านรูปภาพแล้ว');
        return true;
      } else {
        print('❌ ผู้ใช้ปฏิเสธสิทธิ์');
        return false;
      }
    }

    // ✅ สำหรับ Android ต่ำกว่า 13
    final status = await Permission.storage.request();
    if (status.isGranted) {
      print('✅ ได้รับสิทธิ์จัดเก็บไฟล์แล้ว');
      return true;
    } else {
      print('❌ ผู้ใช้ปฏิเสธสิทธิ์');
      return false;
    }
  }

  // iOS จะขอสิทธิ์อัตโนมัติเมื่อบันทึก
  return true;
}

  Future<String> _saveQrPng() async {
    try {
      // render RepaintBoundary to image
      RenderRepaintBoundary boundary =
          globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final filename = 'qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveToGallery(Uint8List bytes) async {
  // ✅ ขอสิทธิ์ก่อน
  final ok = await requestStoragePermission();
    if (!ok) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('⚠️ กรุณาอนุญาตให้เข้าถึงที่เก็บข้อมูล')),
   );
  return;
  }


  // ✅ เซฟรูป
   final result = await ImageGallerySaverPlus.saveImage(
    bytes,
    name: 'My_QR_${DateTime.now().millisecondsSinceEpoch}',
    isReturnImagePathOfIOS: true,
  );

  if (result['isSuccess'] == true) {
    print('✅ บันทึกสำเร็จ: ${result['filePath']}');
  } else {
    print('❌ บันทึกไม่สำเร็จ');
  }
}


  Future<void> _createAndSave(String text) async {
    //final text = _controller.text.trim();
    //if (text.isEmpty) {
    //ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter text')));
    //return;
    //}
     // ✅ สร้าง QR เป็นไฟล์ (ใน app directory)
    final path = await _saveQrPng();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final item = QRItem(
      text: text,
      type: 'created',
      date: now,
      imagePath: path,
    );
    await db.insertItem(item);    
    try {

        final bytes = await File(path).readAsBytes();
        await saveToGallery(bytes);

    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }


  }


  Future<void> _shareQr(String text) async {
    try {
      final path = await _saveQrPng();
      await Share.shareXFiles([XFile(path)], text: text);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
        final ColorSelect = ref.watch(colorProvider); 
    return Scaffold(
      resizeToAvoidBottomInset: false,     
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeButton('text', 'text',ColorSelect),
                _typeButton('URL', 'url',ColorSelect),
                _typeButton('Phone', 'phone',ColorSelect),
                _typeButton('SMS', 'sms',ColorSelect),
                _typeButton('Email', 'email',ColorSelect),
                _typeButton('Wi-Fi', 'wifi',ColorSelect),
                _typeButton('coordinate', 'geo',ColorSelect),
              ],
            ),
            const SizedBox(height: 5),

            _buildInputFields(),
            const SizedBox(height: 20),

            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: ColorSelect),
              icon: const Icon(Icons.qr_code,color: Colors.white),
              label: const Text('สร้าง QR Code',style: TextStyle(color: Colors.white)),

              onPressed: () async {
                final qrData = generateQR(); // สร้างข้อมูลจากช่องข้อความ
                 widget.onOpenResult(ResultPage(datatext: qrData,isCreate: true));
                //await QR_Creat(context, qrData);
                
              },
            ),

            const SizedBox(height: 30),            


          ],
        ),
      ),
    );
  }

  Widget _typeButton(String text, String value,Color ColorSelect) {
    final isSelected = type == value;
    
    return ChoiceChip(
      disabledColor: Colors.blue,
      selectedColor: ColorSelect,
      label: Text(text,style: TextStyle(color: isSelected ? Colors.white : Colors.black )),
      
      selected: isSelected,
      onSelected: (_) {
        FocusScope.of(context).unfocus(); 
        setState(() {        
        type = value;
        controller1.clear();
        controller2.clear();
        controller3.clear();
        qrData = '';
      });
       Future.delayed(const Duration(milliseconds: 100), () {
       focusNodeText.requestFocus(); // โฟกัสไปที่ TextField ใหม่
    });
      },
    );
  }

  Widget _buildInputFields() {
    switch (type) {
      case 'url':
        return TextField(
          autofocus: true,
           focusNode: focusNodeText,
          controller: controller1,
          decoration: const InputDecoration(
            labelText: "Enter a URL such as https://example.com",
          ),
        );
      case 'phone':
        return TextField(
          autofocus: true,
           focusNode: focusNodeText,
          controller: controller1,
          decoration: const InputDecoration(labelText: 'Telephone number'),
          keyboardType: TextInputType.phone,
        );
      case 'sms':
        return Column(
          children: [
            TextField(
              autofocus: true,
               focusNode: focusNodeText,
              controller: controller1,
              decoration: const InputDecoration(labelText: 'Telephone number'),
            ),
            TextField(
              controller: controller2,
              decoration: const InputDecoration(labelText: 'message'),
            ),
          ],
        );
      case 'email':
        return TextField(
          autofocus: true,
           focusNode: focusNodeText,
          controller: controller1,
          decoration: const InputDecoration(labelText: 'email'),
          keyboardType: TextInputType.emailAddress,
        );
      case 'wifi':
        return Column(
          children: [
            TextField(
               focusNode: focusNodeText,
              autofocus: true,
              controller: controller1,
              decoration: const InputDecoration(labelText: 'Wi-Fi name (SSID)'),
            ),
            TextField(
              controller: controller2,
              decoration: const InputDecoration(labelText: 'password'),
            ),
          ],
        );
      case 'geo':
        return Column(
          children: [
            TextField(
               focusNode: focusNodeText,
              controller: controller1,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'latitude'),
            ),
            TextField(
              controller: controller2,
              decoration: const InputDecoration(labelText: 'longitude'),
            ),
          ],
        );
      default:
        return TextField(         
           focusNode: focusNodeText,
          autofocus: true,
          controller: controller1,
          decoration: const InputDecoration(labelText: 'message'),
          minLines: 2,
          maxLines: 3,
        );
    }
  }

  Future<void> QR_Creat(BuildContext context, String qrData) async {
    // ✅ ปิดคีย์บอร์ดก่อนเปิด dialog
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

    return showDialog<void>(
      context: context,
      barrierDismissible: true, // กดด้านนอกเพื่อปิดได้
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Code ของคุณ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ ห่อด้วย SizedBox เพื่อไม่ให้ layout ค้าง
              RepaintBoundary(
                key: globalKey,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 120,
                  height: MediaQuery.of(context).size.width - 120,
                  child: QrImageView(
                    data: qrData,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                qrData,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
            TextButton(
              onPressed: () async {
                _shareQr(qrData);
              },
              child: const Text('แชร์ QR'),
            ),
            TextButton(
              onPressed: () async {
                _createAndSave(qrData);
              },
              child: const Text('บันทึก QR'),
            ),
          ],
        );
      },
    );
  }
}
