class QRItem {
  final int? id;
  final String text;
  final String type; // "scan" or "created"
  final String date; // ISO string
  final String? imagePath; // optional saved QR image path

  QRItem({
    this.id,
    required this.text,
    required this.type,
    required this.date,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'date': date,
      'imagePath': imagePath,
    };
  }

  factory QRItem.fromMap(Map<String, dynamic> m) {
    return QRItem(
      id: m['id'] as int?,
      text: m['text'] as String,
      type: m['type'] as String,
      date: m['date'] as String,
      imagePath: m['imagePath'] as String?,
    );
  }
}