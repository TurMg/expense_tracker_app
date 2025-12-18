import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tambahkan kolom type ke tabel transactions
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT "EXPENSE"');
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Tabel Kategori
    await db.execute('''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL, -- 'EXPENSE' atau 'INCOME'
      iconCode INTEGER NOT NULL,
      colorCode INTEGER NOT NULL
    )
    ''');

    // 2. Tabel Transaksi
    await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      amount REAL NOT NULL,
      categoryId TEXT NOT NULL,
      date TEXT NOT NULL, -- Simpan ISO8601 String
      note TEXT,
      receiptPath TEXT,
      type TEXT NOT NULL DEFAULT 'EXPENSE', -- 'EXPENSE' atau 'INCOME'
      FOREIGN KEY (categoryId) REFERENCES categories (id)
    )
    ''');

    // 3. Seed Data (Kategori Bawaan)
    // Kita isi nanti pas logic, biar file ini bersih.
  }

  // --- CRUD Helper Singkat ---
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await instance.database;
    return await db.query(table, orderBy: "date DESC");
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [List<Object?>? arguments]) async {
    final db = await instance.database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> update(String table, Map<String, dynamic> data,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await instance.database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }
}
