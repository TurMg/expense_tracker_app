import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String type; // 'EXPENSE' atau 'INCOME'
  final IconData icon;
  final Color color;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  // Convert to Map untuk disimpan di database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'iconCode': icon.codePoint,
      'colorCode': color.value,
    };
  }

  // Convert dari Map (dari database)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorCode']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Category{id: $id, name: $name, type: $type}';
  }
}
