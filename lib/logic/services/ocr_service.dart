import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<double?> scanReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return _parseTotalAmount(recognizedText);
    } catch (e) {
      print("Error OCR: $e");
      return null;
    }
  }

  double? _parseTotalAmount(RecognizedText text) {
    List<String> lines = [];

    // 1. Ratakan teks jadi list baris
    for (var block in text.blocks) {
      for (var line in block.lines) {
        lines.add(line.text);
      }
    }

    // --- LEVEL 1: STRATEGI SNIPER (Cari Label "Total") ---
    // Cari baris yang JELAS ada tulisan Total/Jumlah/Bayar
    for (int i = 0; i < lines.length; i++) {
      if (_isTotalLabel(lines[i])) {
        // Cek baris ini
        double? amount = _extractPriceFromLine(lines[i]);
        if (amount != null) return amount;

        // Cek baris bawahnya (karena kadang layoutnya: Total [enter] Rp 50.000)
        if (i + 1 < lines.length) {
          double? nextAmount = _extractPriceFromLine(lines[i + 1]);
          if (nextAmount != null) return nextAmount;
        }
      }
    }

    // --- LEVEL 2: STRATEGI SAPU JAGAT (Cari Angka Terbesar) ---
    // Kalau Sniper gagal, kita cari angka terbesar TAPI dengan filter super ketat
    double maxAmount = 0;

    for (String line in lines) {
      // FILTER MAUT: Kalau baris ini bau-bau tanggal/hp/member, BUANG.
      if (_isForbiddenLine(line)) continue;

      double? amount = _extractPriceFromLine(line);
      if (amount != null) {
        // Validasi Logika:
        // 1. Minimal 500 perak (masa belanja 11 perak)
        // 2. Maksimal 20 Juta (Biar 19-05-2017 gak masuk sbg 19jt)
        if (amount > 500 && amount < 20000000) {
          if (amount > maxAmount) {
            maxAmount = amount;
          }
        }
      }
    }

    return maxAmount > 0 ? maxAmount : null;
  }

  // --- CEK LABEL TOTAL ---
  bool _isTotalLabel(String line) {
    String lower = line.toLowerCase();

    // Harus ada kata kunci sakti
    bool hasKeyword = lower.contains('total') ||
        lower.contains('jumlah') ||
        lower.contains('item') ||
        lower.contains('bayar') ||
        lower.contains('tagihan') ||
        lower.contains('grand');

    // Tapi GAK BOLEH ada kata "Subtotal" atau "Diskon" (Kita mau bayaran akhir)
    bool isTrap = lower.contains('subtotal') ||
        lower.contains('sub-total') ||
        lower.contains('diskon') ||
        lower.contains('diskon') ||
        lower.contains('tunai') ||
        lower.contains('cash') ||
        lower.contains('discount');

    return hasKeyword && !isTrap;
  }

  // --- BLACKLIST BARIS (THE KILLER) ---
  bool _isForbiddenLine(String line) {
    String lower = line.toLowerCase();

    // 1. Blacklist Kata Kunci (Kalau ada ini, skip satu baris!)
    // 'tgl'/'date' -> Biar gak ambil tanggal struk (19-05-2017)
    // 'telp'/'sms'/'fax'/'call' -> Biar gak ambil no HP
    // 'member'/'id' -> Biar gak ambil ID member
    if (lower.contains('tgl') ||
        lower.contains('tanggal') ||
        lower.contains('date') ||
        lower.contains('telp') ||
        lower.contains('sms') ||
        lower.contains('hp') ||
        lower.contains('fax') ||
        lower.contains('call') ||
        lower.contains('hub') ||
        lower.contains('poin') ||
        lower.contains('care') || // Customer Care
        lower.contains('member') ||
        lower.contains('tunai') ||
        lower.contains('cash') ||
        lower.contains('-') ||
        lower.contains(':') ||
        lower.contains('kembalian') ||
        lower.contains('kritik') ||
        lower.contains('saran') ||
        lower.contains('kembali')) {
      return true;
    }

    // 2. Blacklist Regex Tanggal (XX-XX-XXXX)
    if (RegExp(r'\d{1,2}[- /.]\d{1,2}[- /.]\d{2,4}').hasMatch(line))
      return true;

    // 3. Blacklist Regex No HP (08xx...)
    // Hapus spasi dan simbol biar deteksinya gampang
    String clean = line.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('08') && clean.length >= 10) return true;
    if (clean.startsWith('628') && clean.length >= 11) return true;

    return false;
  }

  double? _extractPriceFromLine(String line) {
    // Bersih-bersih
    String cleanLine = line
        .toUpperCase()
        .replaceAll('RP', '')
        .replaceAll('IDR', '')
        .replaceAll('O', '0')
        .replaceAll('L', '1');

    // Pecah jadi kata
    List<String> words = cleanLine.split(' ');

    // Cari dari KANAN (Harga biasanya di kanan)
    for (var word in words.reversed) {
      // Bersihkan simbol mata uang, sisa angka, titik, koma
      String candidate = word.replaceAll(RegExp(r'[^0-9.,]'), '');

      if (candidate.isNotEmpty) {
        // Cek Digit Murni:
        // Harus minimal 3 digit (Ratusan). "1" dibuang.
        String justDigits = candidate.replaceAll('.', '').replaceAll(',', '');
        if (justDigits.length < 3) continue;

        double? amount = _parseToDouble(candidate);
        if (amount != null) return amount;
      }
    }
    return null;
  }

  double? _parseToDouble(String rawNumber) {
    try {
      String clean = rawNumber;
      // Logic Rupiah: Titik=Ribuan, Koma=Desimal
      // Kecuali kalau koma ada di akhir banget (cth: ,00), baru dianggap desimal
      if (clean.contains(',') && clean.lastIndexOf(',') > clean.length - 4) {
        clean = clean.replaceAll('.', '');
        clean = clean.replaceAll(',', '.');
      } else {
        clean = clean.replaceAll('.', '').replaceAll(',', '');
      }
      return double.parse(clean);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
