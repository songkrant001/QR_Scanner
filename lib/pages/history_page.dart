// lib/pages/history_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/qr_item.dart';
import 'package:share_plus/share_plus.dart';

class HistoryPage extends StatefulWidget {
  final Function(Widget) onOpenResult; 
  const HistoryPage({Key? key,required this.onOpenResult}) : super(key: key);
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final db = DatabaseHelper();
  late Future<List<QRItem>> _itemsFuture;

@override
  void initState() {
    super.initState();
    _itemsFuture = db.getAllItems(); // กำหนด Future ครั้งเดียว
  }

  // เรียกเมื่ออยากรีโหลด (เช่นหลังลบ)
  void _reload() {
    if (!mounted) return;
    setState(() {
      _itemsFuture = db.getAllItems();
    });
  }

  Widget _buildTile(QRItem item) {
    final dt = (() {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item.date));
      } catch (_) {
        return item.date;
      }
    })();

    Widget leadingWidget() {
      if (item.imagePath != null && File(item.imagePath!).existsSync()) {
        // ใช้ cacheWidth/cacheHeight เพื่อลดการ decode ขนาดเต็ม
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(item.imagePath!),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            // ถ้าใช้เวอร์ชัน Flutter ที่รองรับ cacheWidth/cacheHeight ให้ใส่ไว้:
            cacheWidth: 160,
            cacheHeight: 160,
          ),
        );
      }
      return const Icon(Icons.qr_code, size: 48);
    }

    return ListTile(
      leading: leadingWidget(),
      title: Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.type} • $dt'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'share') {
            if (item.imagePath != null && File(item.imagePath!).existsSync()) {
              await Share.shareXFiles([XFile(item.imagePath!)], text: item.text);
            } else {
              await Share.share(item.text);
            }
          } else if (v == 'delete') {
            if (item.id != null) await db.deleteItem(item.id!);
            _reload();
          }
        },
        itemBuilder: (c) => const [
          PopupMenuItem(value: 'share', child: Text('Share')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () {
        // แสดง dialog แบบ async — ไม่ decode รูปใหญ่ใน build หลัก
        _showDetailsDialog(item);
      },
    );
  }

  Future<void> _showDetailsDialog(QRItem item) async {
    final dt = (() {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item.date));
      } catch (_) {
        return item.date;
      }
    })();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.imagePath != null && File(item.imagePath!).existsSync())
                  // เลือกขนาดแสดงจำกัด และใช้ cacheWidth เพื่อไม่ให้ decode ใหญ่
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: Image.file(
                        File(item.imagePath!),
                        fit: BoxFit.contain,
                        // ใช้ cacheWidth เพื่อ decode ภาพขนาดพอเหมาะ (ปรับตามต้องการ)
                        cacheWidth: (MediaQuery.of(context).size.width * 0.8).toInt(),
                      ),
                    ),
                  ),
                SelectableText(item.text),
                const SizedBox(height: 8),
                Text('Type: ${item.type}'),
                Text('Date: $dt'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () {
                Share.share(item.text);
                Navigator.pop(context);
              },
              child: const Text('Share text'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QRItem>>(
      future: _itemsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(child: Text('No history yet', style: Theme.of(context).textTheme.bodyLarge));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildTile(items[index]),
        );
      },
    );
  }
}