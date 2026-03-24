import 'package:intl/intl.dart';

class Meal {
  final String id;
  final String foodName;
  final String portionSize;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime timestamp;
  final String? imagePath;
  final String confidence;
  final String notes;

  const Meal({
    required this.id,
    required this.foodName,
    required this.portionSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timestamp,
    this.imagePath,
    required this.confidence,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'foodName': foodName,
        'portionSize': portionSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
        'confidence': confidence,
        'notes': notes,
      };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String,
        foodName: json['foodName'] as String,
        portionSize: json['portionSize'] as String? ?? '',
        calories: (json['calories'] as num).toInt(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        imagePath: json['imagePath'] as String?,
        confidence: json['confidence'] as String? ?? 'medium',
        notes: json['notes'] as String? ?? '',
      );

  String get formattedTime => DateFormat('h:mm a').format(timestamp);

  /// Use [clearImage] = true to explicitly set imagePath to null.
  Meal copyWith({
    String? foodName,
    String? portionSize,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? imagePath,
    bool clearImage = false,
  }) =>
      Meal(
        id: id,
        foodName: foodName ?? this.foodName,
        portionSize: portionSize ?? this.portionSize,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        timestamp: timestamp,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        confidence: confidence,
        notes: notes,
      );
}
