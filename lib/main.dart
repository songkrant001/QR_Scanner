// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_scanner/db/color_provider.dart';
import 'package:qr_scanner/pages/CreateQrPage.dart';
import 'package:qr_scanner/pages/result_page.dart';
import 'pages/scan_page.dart';
import 'pages/history_page.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Note',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home:  HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {

  const HomeScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int index  = 0;
  bool showResultPage = false; // ✅ ใช้ควบคุมว่าจะแสดง ResultPage หรือไม่
  Widget? resultPage; // ✅ เก็บ widget ที่จะเอามาแสดง



  void openResultPage(Widget page) {
    // ✅ เรียกเมื่ออยากเปิดหน้า ResultPage
    setState(() {
      resultPage = page;
      showResultPage = true;
    });
  }

  void closeResultPage() {
    // ✅ เรียกเมื่ออยากกลับไปหน้าหลัก
    setState(() {
      showResultPage = false;
      resultPage = null;
    });
  }

 

  @override
  Widget build(BuildContext context) {
    final ColorSelect = ref.watch(colorProvider); // 🎨 ดูค่าสีปัจจุบัน

    final _pages =  [
    ScanPage(onOpenResult: openResultPage),
    CreateQrPage(onOpenResult: openResultPage), 
    HistoryPage(onOpenResult: openResultPage)
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: theme(ColorSelect),
          )
        ],
        backgroundColor: ColorSelect,
        title: Text(showResultPage ? 'Result' : 'QR Note'),
        centerTitle: true,
        leading: showResultPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: closeResultPage,
              )
            : null,
          ),
      body: AnimatedSwitcher(
         duration: const Duration(milliseconds: 300),
         child: showResultPage
            ? resultPage // ✅ แสดง ResultPage ถ้ามี
            : _pages[index], // ✅ แสดงหน้าหลักตาม NavigationBar
      ),
      bottomNavigationBar: SafeArea(child: navBar(ColorSelect))
    );

  }

  Widget navBar(Color ColorSelect){
    return CircleNavBar(
        activeIcons: const [
          Icon(Icons.qr_code_scanner, color: Colors.white),
          Icon(Icons.qr_code, color: Colors.white),
          Icon(Icons.history, color: Colors.white),
        ],
        inactiveIcons: const [
          Column(children: 
            [
              Icon(Icons.qr_code_scanner,color: Colors.white),
              Text("Scan",style: TextStyle(color:  Colors.white)),
            ],
          ),
          Column(children: 
            [
              Icon(Icons.qr_code,color: Colors.white,),
              Text("Create",style: TextStyle(color:  Colors.white)),
            ],
          ),
          Column(
            children: [
              Icon(Icons.history,color: Colors.white),
              Text("History",style: TextStyle(color:  Colors.white)),
            ],
          )          
        ],
        color: ColorSelect,
        
        height: 60,
        circleWidth: 60,
        activeIndex: index,
        onTap: (i) {
          setState(() 
          {
            index = i;
            showResultPage = false;
          });
        },
        padding: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.zero,
          topRight: Radius.zero,
          bottomRight: Radius.zero,
          bottomLeft: Radius.zero,
        ),
        //shadowColor: Colors.deepPurple,
        elevation: 10,
      );
  }

  Widget theme(Color ColorSelect){
    return Material(
      color: Colors.transparent,
      child: InkWell(
        //highlightColor: Colors.white,
        //splashColor: Colors.white,
        onTap: () async {
                      final newColor = await showDialog<Color>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('เลือกสี'),
                          content: Wrap(
                            spacing: 8,
                            children: [
                              Colors.red,
                              Colors.green,
                              Colors.blue,
                              Colors.orange,
                              Colors.purple,                             
                            ].map((c) {
                              return GestureDetector(
                                onTap: () => Navigator.pop(context, c),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: c,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
          
                      if (newColor != null) {
                        ref.read(colorProvider.notifier).setColor(newColor);
                      }
                    },
        child: Container(
          width: 40,height: 40,
        decoration: BoxDecoration(
          color: ColorSelect,
        border: Border.all(color: Colors.white, width: 2), // กำหนดสีและความหนาของขอบ // ถ้าต้องการให้ขอบโค้งมน
          ),
          
        ),
      
      ),
    );
  }

}
