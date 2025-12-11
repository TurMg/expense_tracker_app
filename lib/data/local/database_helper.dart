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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
}
