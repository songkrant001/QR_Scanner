import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider สำหรับเก็บสถานะสี
final colorProvider = StateNotifierProvider<ColorNotifier, Color>((ref) {
    return ColorNotifier();
  },
);

class ColorNotifier extends StateNotifier<Color> {
  ColorNotifier() : super(Colors.blue) {
    _loadColor(); // โหลดสีจาก SharedPreferences ตอนเริ่มต้น
  }

  /// โหลดค่าจาก SharedPreferences
  Future<void> _loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    final intColor = prefs.getInt('selected_color');
    if (intColor != null) {
      state = Color(intColor);
    }
  }

  /// เปลี่ยนสี และบันทึกลง SharedPreferences
  Future<void> setColor(Color newColor) async {
    state = newColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_color', newColor.value);
  }
}
