// lib/db/database_helper.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/qr_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'qr_notes.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE qr_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT,
            type TEXT,
            date TEXT,
            imagePath TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertItem(QRItem item) async {
    final db = await database;
    return await db.insert('qr_items', item.toMap());
  }

  Future<List<QRItem>> getAllItems() async {
    final db = await database;
    final res = await db.query('qr_items', orderBy: 'date DESC');
    return res.map((m) => QRItem.fromMap(m)).toList();
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete('qr_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('qr_items');
  }
}
