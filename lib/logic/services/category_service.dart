import 'package:flutter/material.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/models/category_model.dart';

class CategoryService {
  final CategoryRepository _repository = CategoryRepository();

  // Initialize dengan seed data
  Future<void> initialize() async {
    await _repository.seedDefaultCategories();
  }

  // Get semua kategori berdasarkan type
  Future<List<Category>> getCategoriesByType(String type) async {
    return await _repository.getCategoriesByType(type);
  }

  // Get semua kategori
  Future<List<Category>> getAllCategories() async {
    return await _repository.getAllCategories();
  }

  // Add kategori baru
  Future<int> addCategory(Category category) async {
    return await _repository.insertCategory(category);
  }

  // Update kategori
  Future<int> updateCategory(Category category) async {
    return await _repository.updateCategory(category);
  }

  // Delete kategori
  Future<int> deleteCategory(String id) async {
    return await _repository.deleteCategory(id);
  }

  // Get kategori by ID
  Future<Category?> getCategoryById(String id) async {
    return await _repository.getCategoryById(id);
  }

  // Helper untuk mendapatkan icon dan color berdasarkan kategori ID (untuk kompatibilitas dengan kode existing)
  static Map<String, dynamic> getCategoryStyle(String categoryId) {
    // Default values
    IconData icon = Icons.shopping_bag_rounded;
    Color bgColor = const Color(0xFFE3F2FD);
    Color iconColor = const Color(0xFF2196F3);

    // Tentukan icon dan warna berdasarkan kategori
    switch (categoryId) {
      case 'Makan':
        icon = Icons.restaurant_rounded;
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFFFA726);
        break;
      case 'Transport':
        icon = Icons.directions_bus_rounded;
        bgColor = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFFAB47BC);
        break;
      case 'Belanja':
        icon = Icons.shopping_bag_rounded;
        bgColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF2196F3);
        break;
      case 'Tagihan':
        icon = Icons.receipt_long_rounded;
        bgColor = const Color(0xFFFFEBEE);
        iconColor = const Color(0xFFF44336);
        break;
      case 'Gaji':
        icon = Icons.work_rounded;
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'Bonus':
        icon = Icons.celebration_rounded;
        bgColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF2196F3);
        break;
      case 'Investasi':
        icon = Icons.trending_up_rounded;
        bgColor = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFF9C27B0);
        break;
      case 'Hadiah':
        icon = Icons.card_giftcard_rounded;
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFFF9800);
        break;
    }

    return {
      'icon': icon,
      'bgColor': bgColor,
      'iconColor': iconColor,
    };
  }
}
