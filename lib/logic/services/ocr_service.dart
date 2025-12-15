import 'dart:io';
import 'dart:math'; 
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptResult {
  final double? amount; // THE ONE AND ONLY (Pemenang tunggal)
  final DateTime? date;

  ReceiptResult({this.amount, this.date});
}

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptResult> scanReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return _processText(recognizedText);
    } catch (e) {
      print("Error OCR: $e");
      return ReceiptResult();
    }
  }

  ReceiptResult _processText(RecognizedText text) {
    List<TextLine> allLines = [];
    for (var block in text.blocks) {
      allLines.addAll(block.lines);
    }
    // Sortir visual dari atas ke bawah
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    List<String> stringLines = allLines.map((e) => e.text).toList();
    DateTime? date = _findDate(stringLines);

    double? finalAmount;

    // --- TAHAP 1: CARI LABEL "TOTAL" (METODE PALING AKURAT) ---
    // Kita cari angka yang nempel sama tulisan Total. Kalau ketemu, LANGSUNG AMBIL.
    // Kita abaikan angka-angka lain yang bertebaran di struk.
    List<double> highConfidenceMatches = [];

    for (var line in allLines) {
      if (_isTotalLabelFuzzy(line.text)) {
        double? val = _findPriceByPosition(line, allLines);
        if (val != null) highConfidenceMatches.add(val);
      }
    }

    if (highConfidenceMatches.isNotEmpty) {
      // Kalau ada beberapa kandidat (misal Total & Grand Total), ambil yang TERBESAR.
      highConfidenceMatches.sort((a, b) => b.compareTo(a));
      finalAmount = highConfidenceMatches.first;
    } else {
      // --- TAHAP 2: SAPU JAGAT (BACKUP PLAN) ---
      // Jalan hanya kalau Tahap 1 GAGAL TOTAL (gak nemu tulisan 'Total').
      // Kita cari angka terbesar yang valid di seluruh struk.
      List<double> allNumbers = [];
      for (var line in allLines) {
        String textContent = line.text;
        if (_isForbiddenLineFuzzy(textContent)) continue;

        double? val = _extractPriceFromLine(textContent);
        if (val != null && val >= 1000 && val < 50000000) {
           if (val >= 2019 && val <= 2030) continue; // Filter tahun
           allNumbers.add(val);
        }
      }

      if (allNumbers.isNotEmpty) {
        allNumbers.sort((a, b) => b.compareTo(a));
        finalAmount = allNumbers.first;
      }
    }

    return ReceiptResult(
      amount: finalAmount,
      date: date,
    );
  }

  // --- LOGIC POSISI (SAMA SEPERTI SEBELUMNYA) ---
  double? _findPriceByPosition(TextLine labelLine, List<TextLine> allLines) {
    final labelRect = labelLine.boundingBox;
    double? candidatePrice;
    double minDistance = double.infinity;

    for (var otherLine in allLines) {
      if (otherLine == labelLine) continue;
      if (_isForbiddenLineFuzzy(otherLine.text)) continue;

      final otherRect = otherLine.boundingBox;

      // 1. Cek Kanan (Satu Baris)
      double verticalOverlap = max(0, min(labelRect.bottom, otherRect.bottom) - max(labelRect.top, otherRect.top));
      bool isSameRow = verticalOverlap > (labelRect.height * 0.5);
      bool isToTheRight = otherRect.left > labelRect.left; 

      // 2. Cek Bawah (Baris Berikutnya)
      bool isBelow = otherRect.top >= labelRect.bottom && 
                     otherRect.top <= (labelRect.bottom + labelRect.height * 3);
      bool isAligned = (otherRect.left >= labelRect.left - 100) && 
                       (otherRect.right <= labelRect.right + 200);

      if ((isSameRow && isToTheRight) || (isBelow && isAligned)) {
        double? extracted = _extractPriceFromLine(otherLine.text);
        if (extracted != null) {
           // Cari yang jaraknya paling dekat
           double distance = (otherRect.left - labelRect.right).abs() + (otherRect.top - labelRect.top).abs();
           if (distance < minDistance) {
             minDistance = distance;
             candidatePrice = extracted;
           }
        }
      }
    }
    return candidatePrice;
  }

  // --- FUZZY & BLACKLIST (SAMA) ---
  bool _isTotalLabelFuzzy(String line) {
    bool hasKeyword = _fuzzyContains(line, ['total', 'jumlah', 'bayar', 'grand', 'tagihan', 'belanja']);
    bool isTrap = _fuzzyContains(line, ['subtotal', 'diskon', 'disc', 'tax', 'pajak', 'ppn', 'dpp', 'item']);
    return hasKeyword && !isTrap;
  }

  bool _isForbiddenLineFuzzy(String line) {
    bool isBlacklisted = _fuzzyContains(line, [
      'kembalian', 'change', 'kritik', 'saran', 'diskon', 'disc',
      'ppn', 'dpp', 'pajak', 'tax', 'npwp', 'whatsapp', 
    ]);
    if (isBlacklisted) return true;

    String lower = line.toLowerCase();
    if (lower.contains(' sms ') || lower.startsWith('sms')) return true;
    if (lower.contains(' member ') || lower.startsWith('member')) return true;
    if (lower.contains(' kembali ') || lower.startsWith('kembali')) return true;
    if (lower.contains(' tunai ') || lower.startsWith('tunai')) return true;
    if (lower.contains(' total item ') || lower.startsWith('total')) return true;
    if (lower.endsWith(' item ')) return true;
    if (lower.startsWith(' total ') || lower.endsWith(' item ')) return true;
    if (lower.contains(':')) return true;
    if (lower.startsWith('v.') || lower.startsWith('ver ') || lower.contains('version')) return true;
    if (lower.contains(' wa ') || lower.contains('wa:') || lower.startsWith('wa')) return true;
    
    bool hasTunai = _fuzzyContains(line, ['tunai', 'cash']);
    bool hasTotal = _fuzzyContains(line, ['total', 'jumlah', 'grand']);
    if (hasTunai && !hasTotal) return true;

    if (_fuzzyContains(line, ['telp', 'phone', 'hubungi'])) return true;
    if (lower.contains('tgl') || lower.contains('date')) return true; 

    String clean = line.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('08') && clean.length >= 10) return true;
    if (clean.startsWith('628') && clean.length >= 11) return true;

    return false;
  }

  bool _fuzzyContains(String line, List<String> keywords) {
    List<String> wordsInLine = line.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '').split(RegExp(r'\s+'));             
    for (String word in wordsInLine) {
      if (word.isEmpty) continue;
      for (String key in keywords) {
        if (key.length <= 3) {
           if (word == key) return true;
        } else {
           int maxEdits = key.length > 6 ? 2 : 1;
           if (_levenshtein(word, key) <= maxEdits) return true;
        }
      }
    }
    return false;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  double? _extractPriceFromLine(String line) {
    String cleanLine = line.toUpperCase().replaceAll('RP', '').replaceAll('IDR', '').replaceAll('O', '0').replaceAll('L', '1');
    List<String> words = cleanLine.split(' ');
    for (var word in words.reversed) {
      String numberStr = word.replaceAll(RegExp(r'[^0-9.,]'), '');
      if (numberStr.length < 3) continue;
      try {
        if (numberStr.indexOf('.') != numberStr.lastIndexOf('.')) {
             List<String> parts = numberStr.split('.');
             for (int i = 1; i < parts.length - 1; i++) {
               if (parts[i].length != 3) throw Exception("Bukan format harga");
             }
        }
        if (numberStr.contains(',') && numberStr.lastIndexOf(',') > numberStr.length - 4) {
          numberStr = numberStr.replaceAll('.', '').replaceAll(',', '.');
        } else {
          numberStr = numberStr.replaceAll('.', '').replaceAll(',', '');
        }
        return double.parse(numberStr);
      } catch (e) { continue; }
    }
    return null;
  }

  DateTime? _findDate(List<String> lines) {
    final dateRegex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b|\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    for (String line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          String dateStr = match.group(0)!.replaceAll('/', '-').replaceAll('.', '-');
          List<String> parts = dateStr.split('-');
          int d, m, y;
          if (parts[0].length == 4) {
            y = int.parse(parts[0]); m = int.parse(parts[1]); d = int.parse(parts[2]);
          } else {
            d = int.parse(parts[0]); m = int.parse(parts[1]); y = int.parse(parts[2]);
            if (y < 100) y += 2000;
          }
          return DateTime(y, m, d);
        } catch (e) { continue; }
      }
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}