import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../local/database_helper.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insert kategori baru
  Future<int> insertCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap());
  }

  // Get semua kategori berdasarkan type
  Future<List<Category>> getCategoriesByType(String type) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  // Get semua kategori
  Future<List<Category>> getAllCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  // Update kategori
  Future<int> updateCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // Delete kategori
  Future<int> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get kategori by ID
  Future<Category?> getCategoryById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  // Seed data kategori default
  Future<void> seedDefaultCategories() async {
    final List<Category> defaultCategories = [
      // Expense Categories
      Category(
        id: 'Makan',
        name: 'Makan',
        type: 'EXPENSE',
        icon: Icons.restaurant_rounded,
        color: Color(0xFFF4A285),
      ),
      Category(
        id: 'Transport',
        name: 'Transport',
        type: 'EXPENSE',
        icon: Icons.directions_bus_rounded,
        color: Color(0xFF81C784),
      ),
      Category(
        id: 'Belanja',
        name: 'Belanja',
        type: 'EXPENSE',
        icon: Icons.shopping_bag_rounded,
        color: Color(0xFF64B5F6),
      ),
      Category(
        id: 'Tagihan',
        name: 'Tagihan',
        type: 'EXPENSE',
        icon: Icons.receipt_long_rounded,
        color: Color(0xFFE57373),
      ),

      // Income Categories
      Category(
        id: 'Gaji',
        name: 'Gaji',
        type: 'INCOME',
        icon: Icons.work_rounded,
        color: Color(0xFF4CAF50),
      ),
      Category(
        id: 'Bonus',
        name: 'Bonus',
        type: 'INCOME',
        icon: Icons.celebration_rounded,
        color: Color(0xFF2196F3),
      ),
      Category(
        id: 'Investasi',
        name: 'Investasi',
        type: 'INCOME',
        icon: Icons.trending_up_rounded,
        color: Color(0xFF9C27B0),
      ),
      Category(
        id: 'Hadiah',
        name: 'Hadiah',
        type: 'INCOME',
        icon: Icons.card_giftcard_rounded,
        color: Color(0xFFFF9800),
      ),
    ];

    final db = await _dbHelper.database;
    final existingCategories = await getAllCategories();

    // Hanya insert jika belum ada
    if (existingCategories.isEmpty) {
      for (final category in defaultCategories) {
        await insertCategory(category);
      }
    }
  }
}
