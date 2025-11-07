import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_scanner/db/database_helper.dart';
import 'package:qr_scanner/main.dart';
import 'package:qr_scanner/models/qr_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ResultPage extends StatefulWidget {
  String datatext;
  bool isCreate;
  String? path ;

  ResultPage({required this.datatext, required this.isCreate,this.path, super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final GlobalKey globalKey = GlobalKey();
  final db = DatabaseHelper();
  
  

  void searchInBrowser(String query) async {
  final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
  if (await canLaunchUrl(url)) {
     await launchUrl(url,mode: LaunchMode.externalApplication);
  } else {
    // กรณีเปิดไม่ได้
    ScaffoldMessenger.of(context,
          ).showSnackBar(SnackBar(content: Text('ไม่สามารถเปิด: ${url}')));
  }
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // ✅ สำหรับ Android 13 (API 33) ขึ้นไป
      if (await Permission.photos.isDenied ||
          await Permission.videos.isDenied) {
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

  Future<void> _shareQr(String text) async {
    try {
      print(widget.isCreate);
      if (widget.isCreate == true) {
        final path = await _saveQrPng();
        await Share.shareXFiles([XFile(path)], text: text);
      } else {
        await Share.share(text);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        //color: Colors.amber[50],
        child: Column(
          children: [
            SizedBox(height: 10),
            widget.isCreate
                ? Column(
                  children: [
                    RepaintBoundary(
                      key: globalKey,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 50,
                        height: MediaQuery.of(context).size.width - 50,
                        child: QrImageView(
                          data: widget.datatext,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    linkText(widget.datatext)
                  ],
                )
                : Padding(
                  padding: const EdgeInsets.only(top: 30,bottom: 30),
                  child: Center(
                    child: linkText(widget.datatext)
                  ),
                ),
              
            //SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iCons(Icons.search_outlined, "Search",const ui.Color.fromARGB(255, 149, 96, 219),
                   () {
                    searchInBrowser(widget.datatext);
                   }),
              
                  iCons(Icons.copy_outlined, "Copy",Colors.green, () {
                    Clipboard.setData(ClipboardData(text: widget.datatext));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('📋 Copy!')));
                  }),
              
                  iCons(Icons.share, "Share",Colors.blueAccent, () async {
                    _shareQr(widget.datatext);
                  }),
              
                  if (widget.isCreate)
                    iCons(Icons.save_alt_outlined, "Save",Colors.orangeAccent, () async {
                      _createAndSave(widget.datatext);
                    }),
                ],
              ),
            ),
           if (widget.isCreate != true)         
             if (widget.path != null)             
               Image.file(File(widget.path!), height: 200, fit: BoxFit.cover),
              
          ],
        ),
      ),
    );
  }

  Widget iCons(IconData icons, String iconsName,Color color, void Function() onPressed) {
    return Material(
      //borderRadius: BorderRadius.circular(50),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        focusColor: Colors.amber,
        hoverColor: Colors.blue,
        //highlightColor: Colors.grey,
        splashColor: Colors.grey,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(      
                  height: MediaQuery.of(context).size.width / 6, width: MediaQuery.of(context).size.width / 6,            
                  decoration: BoxDecoration(
                    boxShadow:[
                      BoxShadow(blurRadius: 3)

                    ],                    
                    color: color,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(icons, size: 35, color: Colors.white)),
                Text(iconsName, style: TextStyle(fontSize: 18)),
              ],

            ),
          ),
        ),
      ),
    );
  }

  Widget linkText(String data) {
    return Linkify(
      text: data,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, color: Colors.black),
      linkStyle: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      onOpen: (link) async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ไม่สามารถเปิด: ${link.url}')));
        }
      },
    );
  }


}
