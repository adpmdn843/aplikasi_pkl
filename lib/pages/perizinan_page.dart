import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PerizinanPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PerizinanPage({
    super.key,
    required this.userData,
  });

  @override
  State<PerizinanPage> createState() => _PerizinanPageState();
}

class _PerizinanPageState extends State<PerizinanPage> {
  // ==========================================================
  // API
  // ==========================================================

  static const String apiUrl =
      'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

  // ==========================================================
  // KOORDINAT PERUSAHAAN
  // ==========================================================

  static const double companyLatitude = -6.130788;
  static const double companyLongitude = 106.796369;

  // ==========================================================
  // CONTROLLER
  // ==========================================================

  final TextEditingController _keteranganController =
      TextEditingController();

  // ==========================================================
  // STATE
  // ==========================================================

  String _status = 'Izin';

  Position? _position;
  double? _jarak;

  bool _isGettingLocation = false;
  bool _isSubmitting = false;

  // ==========================================================
  // STATUS KERJA LIVE
  // ==========================================================

  String _liveStatusKerja = '';

  Timer? _databaseRefreshTimer;

  bool _isRefreshingDatabase = false;

  // ==========================================================
  // GET STATUS KERJA
  // ==========================================================

  String get _statusKerja {
    final dynamic value = _liveStatusKerja.trim().isNotEmpty
        ? _liveStatusKerja
        : (widget.userData['status_kerja'] ??
            widget.userData['STATUS KERJA'] ??
            widget.userData['STATUS_KERJA'] ??
            widget.userData['status kerja'] ??
            widget.userData['statusKerja'] ??
            '');

    return value.toString().trim().toLowerCase();
  }

  bool get _isOff => _statusKerja == 'off';

  // ==========================================================
  // DATA USER
  // ==========================================================

  String get _idPKL {
    return (widget.userData['id_pkl'] ??
            widget.userData['ID PKL'] ??
            widget.userData['ID_PKL'] ??
            '')
        .toString()
        .trim();
  }

  String get _namaSiswa {
    return (widget.userData['nama_siswa'] ??
            widget.userData['Nama Siswa'] ??
            widget.userData['nama'] ??
            widget.userData['Nama'] ??
            '-')
        .toString()
        .trim();
  }

  String get _bagian {
    return (widget.userData['bagian'] ??
            widget.userData['Bagian'] ??
            '-')
        .toString()
        .trim();
  }

  // ==========================================================
  // TANGGAL HARI INI
  // ==========================================================

  DateTime get _tanggalHariIni {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  // ==========================================================
  // INITIAL STATUS
  // ==========================================================

  String _getInitialStatusKerja() {
    final dynamic value = widget.userData['status_kerja'] ??
        widget.userData['STATUS KERJA'] ??
        widget.userData['STATUS_KERJA'] ??
        widget.userData['status kerja'] ??
        widget.userData['statusKerja'] ??
        '';

    return value.toString().trim();
  }

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _liveStatusKerja = _getInitialStatusKerja();

    _refreshFromDatabase();

    _databaseRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _refreshFromDatabase();
      },
    );
  }

  // ==========================================================
  // REFRESH DATABASE
  // ==========================================================

  Future<void> _refreshFromDatabase() async {
    if (!mounted) return;

    if (_isRefreshingDatabase) return;

    if (_idPKL.isEmpty) return;

    _isRefreshingDatabase = true;

    try {
      final newStatus = await _getStatusKerjaFromDatabase();

      if (!mounted) return;

      if (newStatus.trim().isEmpty) {
        return;
      }

      final oldStatus = _statusKerja;

      final normalizedNew =
          newStatus.trim().toLowerCase();

      if (oldStatus == normalizedNew) {
        return;
      }

      setState(() {
        _liveStatusKerja = newStatus.trim();
      });

      if (normalizedNew == 'off') {
        _showMessage(
          'STATUS KERJA berubah menjadi Off. '
          'Pengajuan Izin/Sakit tidak tersedia.',
        );
      }
    } catch (error) {
      debugPrint(
        'REFRESH STATUS KERJA PERIZINAN GAGAL: $error',
      );
    } finally {
      _isRefreshingDatabase = false;
    }
  }

  // ==========================================================
  // GET STATUS KERJA DARI SERVER
  // ==========================================================

  Future<String> _getStatusKerjaFromDatabase() async {
    final uri = Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'statusAbsensiHariIni',
        'id_pkl': _idPKL,
      },
    );

    final client = HttpClient();

    client.connectionTimeout =
        const Duration(seconds: 5);

    try {
      final request = await client.getUrl(uri);

      request.followRedirects = true;
      request.maxRedirects = 5;

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response = await request.close();

      if (response.statusCode != 200) {
        await response.drain();

        throw HttpException(
          'Status server ${response.statusCode}.',
        );
      }

      final body =
          await response.transform(utf8.decoder).join();

      if (body.trim().isEmpty) {
        throw Exception(
          'Respons server kosong.',
        );
      }

      String cleanBody = body.trim();

      if (cleanBody.startsWith('\uFEFF')) {
        cleanBody =
            cleanBody.substring(1).trim();
      }

      final decoded = jsonDecode(cleanBody);

      if (decoded is! Map) {
        throw const FormatException(
          'Format respons server tidak valid.',
        );
      }

      final result =
          Map<String, dynamic>.from(decoded);

      if (result['success'] == false) {
        throw Exception(
          result['message']?.toString() ??
              'Gagal mengambil status kerja.',
        );
      }

      final rawData = result['data'];

      final Map<String, dynamic> data =
          rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : result;

      for (final key in [
        'status_kerja',
        'STATUS KERJA',
        'STATUS_KERJA',
        'status kerja',
        'statusKerja',
      ]) {
        if (data.containsKey(key)) {
          return data[key]?.toString().trim() ?? '';
        }

        if (result.containsKey(key)) {
          return result[key]?.toString().trim() ?? '';
        }
      }

      return '';
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _databaseRefreshTimer?.cancel();

    _keteranganController.dispose();

    super.dispose();
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String _formatDate(DateTime date) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ==========================================================
  // FORMAT TANGGAL INDONESIA
  // ==========================================================

  String _formatTanggalIndonesia(DateTime date) {
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} '
        '${bulan[date.month - 1]} '
        '${date.year}';
  }

  // ==========================================================
  // HITUNG JARAK
  // ==========================================================

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;

    final dLat =
        _degreesToRadians(lat2 - lat1);

    final dLon =
        _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) *
                math.sin(dLat / 2) +
            math.cos(
                  _degreesToRadians(lat1),
                ) *
                math.cos(
                  _degreesToRadians(lat2),
                ) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c = 2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadius * c;
  }

  double _degreesToRadians(double degree) {
    return degree * math.pi / 180;
  }

  // ==========================================================
  // GET LOCATION
  // ==========================================================

  Future<void> _getLocation() async {
    if (_isOff) {
      _showMessage(
        'STATUS KERJA Anda adalah Off. '
        'Pengajuan Izin/Sakit tidak tersedia.',
      );

      return;
    }

    if (_isGettingLocation ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'GPS/lokasi pada perangkat belum aktif.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        throw Exception(
          'Izin lokasi ditolak.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi ditolak permanen. '
          'Silakan aktifkan izin lokasi dari '
          'pengaturan perangkat.',
        );
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        companyLatitude,
        companyLongitude,
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _jarak = distance;
        _isGettingLocation = false;
      });

      _showMessage(
        'Lokasi berhasil diperbarui.',
        success: true,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      _showMessage(
        error.toString()
            .replaceFirst('Exception: ', ''),
      );
    }
  }

  // ==========================================================
  // SUBMIT PERIZINAN
  // ==========================================================

  Future<void> _submitPerizinan() async {
    if (_isSubmitting) {
      return;
    }

    if (_isOff) {
      _showMessage(
        'STATUS KERJA Anda adalah Off. '
        'Pengajuan Izin/Sakit tidak tersedia.',
      );

      return;
    }

    final keterangan =
        _keteranganController.text.trim();

    if (keterangan.isEmpty) {
      _showMessage(
        'Keterangan wajib diisi.',
      );

      return;
    }

    if (keterangan.length < 3) {
      _showMessage(
        'Keterangan terlalu singkat.',
      );

      return;
    }

    if (_position == null ||
        _jarak == null) {
      _showMessage(
        'Silakan ambil lokasi terlebih dahulu.',
      );

      return;
    }

    final idPKL = _idPKL;

    if (idPKL.isEmpty) {
      _showMessage(
        'ID PKL tidak ditemukan pada data pengguna.',
      );

      return;
    }

    final tanggalPengajuan =
        _formatDate(_tanggalHariIni);

    setState(() {
      _isSubmitting = true;
    });

    String? existingStatus;

    bool checkSucceeded = false;

    try {
      existingStatus =
          await _checkTanggalSudahAda(
        idPKL: idPKL,
        tanggal: tanggalPengajuan,
      ).timeout(
        const Duration(seconds: 8),
      );

      checkSucceeded = true;
    } catch (error) {
      debugPrint(
        'CEK TANGGAL PERIZINAN GAGAL: $error',
      );
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!checkSucceeded) {
      _showMessage(
        'Tanggal belum dapat diverifikasi. '
        'Periksa koneksi internet kemudian coba lagi.',
      );

      return;
    }

    if (existingStatus != null) {
      final statusTersimpan =
          existingStatus.isEmpty
              ? 'data absensi'
              : 'status $existingStatus';

      _showMessage(
        'Tidak dapat mengajukan $_status. '
        'Tanggal $tanggalPengajuan sudah memiliki '
        '$statusTersimpan. Satu tanggal hanya boleh '
        'memiliki satu data absensi.',
      );

      return;
    }

    // Cek ulang status kerja terbaru
    await _refreshFromDatabase();

    if (!mounted) return;

    if (_isOff) {
      _showMessage(
        'STATUS KERJA Anda berubah menjadi Off. '
        'Pengajuan Izin/Sakit dibatalkan.',
      );

      return;
    }

    final confirmed =
        await _showConfirmationDialog();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    HttpClient? client;

    try {
      final tanggal =
          _formatDate(_tanggalHariIni);

      final body = {
        'action':
            'absensiKetidakhadiran',
        'id_pkl': idPKL,
        'tanggal': tanggal,
        'status': _status,
        'keterangan': keterangan,
        'latitude':
            _position!.latitude.toString(),
        'longitude':
            _position!.longitude.toString(),
        'jarak':
            _jarak!.toStringAsFixed(2),
      };

      debugPrint(
        '==========================================',
      );

      debugPrint(
        'PENGAJUAN PERIZINAN',
      );

      debugPrint(
        'REQUEST: ${jsonEncode(body)}',
      );

      debugPrint(
        '==========================================',
      );

      client = HttpClient();

      client.connectionTimeout =
          const Duration(seconds: 20);

      final request =
          await client.postUrl(
        Uri.parse(apiUrl),
      );

      request.followRedirects = false;

      request.headers.contentType =
          ContentType.json;

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      request.write(
        jsonEncode(body),
      );

      final response =
          await request.close();

      final statusCode =
          response.statusCode;

      debugPrint(
        'HTTP STATUS AWAL: $statusCode',
      );

      // ======================================================
      // HTTP 200
      // ======================================================

      if (statusCode == 200) {
        final responseBody =
            await response
                .transform(utf8.decoder)
                .join();

        debugPrint(
          '==========================================',
        );

        debugPrint(
          'RESPONSE SERVER:',
        );

        debugPrint(
          responseBody,
        );

        debugPrint(
          '==========================================',
        );

        if (responseBody
            .trim()
            .isNotEmpty) {
          String cleanResponse =
              responseBody.trim();

          if (cleanResponse
              .startsWith('\uFEFF')) {
            cleanResponse =
                cleanResponse
                    .substring(1)
                    .trim();
          }

          try {
            final decoded =
                jsonDecode(cleanResponse);

            if (decoded is Map) {
              final result =
                  Map<String, dynamic>
                      .from(decoded);

              if (result['success'] ==
                  true) {
                await _finishSubmitSuccess(
                  result['message']
                          ?.toString() ??
                      '$_status berhasil diajukan.',
                );

                return;
              }

              final message =
                  result['message']
                      ?.toString()
                      .trim();

              if (message != null &&
                  message.isNotEmpty) {
                throw Exception(
                  message,
                );
              }
            }
          } on FormatException {
            debugPrint(
              'Response HTTP 200 bukan JSON yang valid.',
            );
          }
        }

        // Response tidak cukup jelas
        // -> verifikasi langsung ke database
        final verified =
            await _verifyPerizinanAfterUncertain(
          idPKL: idPKL,
          tanggal: tanggal,
          status: _status,
          keterangan: keterangan,
        );

        if (verified) {
          await _finishSubmitSuccess(
            '$_status berhasil diajukan.',
          );

          return;
        }

        throw Exception(
          'Respons server tidak dapat dikonfirmasi.',
        );
      }

      // ======================================================
      // REDIRECT APPS SCRIPT
      // ======================================================

      if (statusCode == 301 ||
          statusCode == 302 ||
          statusCode == 303 ||
          statusCode == 307 ||
          statusCode == 308) {
        await response.drain();

        debugPrint(
          'Apps Script mengembalikan '
          'redirect $statusCode.',
        );

        final verified =
            await _verifyPerizinanAfterUncertain(
          idPKL: idPKL,
          tanggal: tanggalPengajuan,
          status: _status,
          keterangan: keterangan,
        );

        if (verified) {
          await _finishSubmitSuccess(
            '$_status berhasil diajukan.',
          );

          return;
        }

        throw Exception(
          'Pengajuan $_status belum dapat dipastikan tersimpan. '
          'Silakan coba lagi.',
        );
      }

      // ======================================================
      // STATUS SERVER LAIN
      // ======================================================

      await response.drain();

      final verified =
          await _verifyPerizinanAfterUncertain(
        idPKL: idPKL,
        tanggal: tanggalPengajuan,
        status: _status,
        keterangan: keterangan,
      );

      if (verified) {
        await _finishSubmitSuccess(
          '$_status berhasil diajukan.',
        );

        return;
      }

      throw HttpException(
        'Server mengembalikan HTTP $statusCode.',
      );
    } on SocketException {
      final verified =
          await _verifyPerizinanAfterUncertain(
        idPKL: idPKL,
        tanggal: _formatDate(
          _tanggalHariIni,
        ),
        status: _status,
        keterangan: keterangan,
      );

      if (verified) {
        await _finishSubmitSuccess(
          '$_status berhasil diajukan.',
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        'Koneksi internet bermasalah. '
        'Data belum dapat dikonfirmasi.',
      );
    } on TimeoutException {
      final verified =
          await _verifyPerizinanAfterUncertain(
        idPKL: idPKL,
        tanggal: _formatDate(
          _tanggalHariIni,
        ),
        status: _status,
        keterangan: keterangan,
      );

      if (verified) {
        await _finishSubmitSuccess(
          '$_status berhasil diajukan.',
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        'Koneksi terlalu lama. '
        'Data belum dapat dikonfirmasi.',
      );
    } on HttpException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        'Kesalahan server: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        error.toString()
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      client?.close(force: true);
    }
  }

  // ==========================================================
  // VERIFIKASI SETELAH RESPONSE TIDAK PASTI
  // ==========================================================

  Future<bool> _verifyPerizinanAfterUncertain({
    required String idPKL,
    required String tanggal,
    required String status,
    required String keterangan,
  }) async {
    for (int attempt = 0;
        attempt < 3;
        attempt++) {
      try {
        final verified =
            await _checkPerizinanSaved(
          idPKL: idPKL,
          tanggal: tanggal,
          status: status,
          keterangan: keterangan,
        ).timeout(
          const Duration(seconds: 5),
        );

        if (verified) {
          debugPrint(
            'VERIFIKASI PERIZINAN BERHASIL '
            'pada percobaan ${attempt + 1}',
          );

          return true;
        }
      } catch (error) {
        debugPrint(
          'VERIFIKASI PERIZINAN GAGAL '
          'percobaan ${attempt + 1}: $error',
        );
      }

      if (attempt < 2) {
        await Future.delayed(
          const Duration(seconds: 2),
        );
      }
    }

    return false;
  }

  // ==========================================================
  // CEK TANGGAL SUDAH ADA
  // ==========================================================

  Future<String?> _checkTanggalSudahAda({
    required String idPKL,
    required String tanggal,
  }) async {
    final uri = Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'riwayatAbsensi',
        'id_pkl': idPKL,
      },
    );

    final client = HttpClient();

    client.connectionTimeout =
        const Duration(seconds: 5);

    try {
      final request =
          await client.getUrl(uri);

      request.followRedirects = true;
      request.maxRedirects = 5;

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response =
          await request.close();

      if (response.statusCode != 200) {
        await response.drain();

        throw HttpException(
          'Status riwayat ${response.statusCode}.',
        );
      }

      final body =
          await response
              .transform(utf8.decoder)
              .join();

      if (body.trim().isEmpty) {
        throw Exception(
          'Respons riwayat kosong.',
        );
      }

      String cleanBody =
          body.trim();

      if (cleanBody
          .startsWith('\uFEFF')) {
        cleanBody =
            cleanBody
                .substring(1)
                .trim();
      }

      final decoded =
          jsonDecode(cleanBody);

      if (decoded is! Map) {
        throw const FormatException(
          'Format riwayat tidak valid.',
        );
      }

      final result =
          Map<String, dynamic>
              .from(decoded);

      if (result['success'] != true) {
        throw Exception(
          result['message']
                  ?.toString() ??
              'Gagal membaca riwayat absensi.',
        );
      }

      final rawData =
          result['data'];

      if (rawData is! List) {
        return null;
      }

      for (final item in rawData) {
        if (item is! Map) {
          continue;
        }

        final row =
            Map<String, dynamic>
                .from(item);

        final rowTanggal =
            _normalizeDateValue(
          row['tanggal'],
        );

        if (rowTanggal !=
            tanggal) {
          continue;
        }

        return row['status']
                ?.toString()
                .trim() ??
            '';
      }

      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================
  // CEK DATA TERSIMPAN
  // ==========================================================

  Future<bool> _checkPerizinanSaved({
    required String idPKL,
    required String tanggal,
    required String status,
    required String keterangan,
  }) async {
    final uri = Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'riwayatAbsensi',
        'id_pkl': idPKL,
      },
    );

    final client = HttpClient();

    client.connectionTimeout =
        const Duration(seconds: 5);

    try {
      final request =
          await client.getUrl(uri);

      request.followRedirects = true;
      request.maxRedirects = 5;

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response =
          await request.close();

      if (response.statusCode != 200) {
        await response.drain();

        throw HttpException(
          'Status riwayat ${response.statusCode}.',
        );
      }

      final body =
          await response
              .transform(utf8.decoder)
              .join();

      if (body.trim().isEmpty) {
        throw Exception(
          'Respons riwayat kosong.',
        );
      }

      String cleanBody =
          body.trim();

      if (cleanBody
          .startsWith('\uFEFF')) {
        cleanBody =
            cleanBody
                .substring(1)
                .trim();
      }

      final decoded =
          jsonDecode(cleanBody);

      if (decoded is! Map) {
        throw const FormatException(
          'Format riwayat tidak valid.',
        );
      }

      final result =
          Map<String, dynamic>
              .from(decoded);

      if (result['success'] != true) {
        throw Exception(
          result['message']
                  ?.toString() ??
              'Gagal membaca riwayat absensi.',
        );
      }

      final rawData =
          result['data'];

      if (rawData is! List) {
        return false;
      }

      for (final item in rawData) {
        if (item is! Map) {
          continue;
        }

        final row =
            Map<String, dynamic>
                .from(item);

        final rowTanggal =
            _normalizeDateValue(
          row['tanggal'],
        );

        final rowStatus =
            row['status']
                    ?.toString()
                    .trim() ??
                '';

        final rowKeterangan =
            row['keterangan']
                    ?.toString()
                    .trim() ??
                '';

        if (rowTanggal !=
            tanggal) {
          continue;
        }

        if (rowStatus.toLowerCase() !=
            status.toLowerCase()) {
          continue;
        }

        if (rowKeterangan !=
            keterangan) {
          continue;
        }

        return true;
      }

      return false;
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================================
  // NORMALIZE DATE
  // ==========================================================

  String _normalizeDateValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return '';
    }

    final yyyyMmDd =
        RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (yyyyMmDd.hasMatch(text)) {
      return text;
    }

    try {
      final parsed =
          DateTime.tryParse(text);

      if (parsed != null) {
        return _formatDate(
          parsed.toLocal(),
        );
      }
    } catch (_) {}

    return text;
  }

  // ==========================================================
  // SELESAI SUBMIT
  // ==========================================================

  Future<void> _finishSubmitSuccess(
    String message,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    await _showSuccessDialog(
      message,
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
      true,
    );
  }

  // ==========================================================
  // DIALOG KONFIRMASI
  // ==========================================================

  Future<bool> _showConfirmationDialog() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Text(
            'Konfirmasi Perizinan',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'Anda akan mengajukan '
            '$_status untuk tanggal '
            '${_formatTanggalIndonesia(_tanggalHariIni)}.\n\n'
            'Pastikan data yang dimasukkan '
            'sudah benar.',
            style: const TextStyle(
              height: 1.5,
              color:
                  Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF2563EB,
                ),
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              child:
                  const Text('Kirim'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ==========================================================
  // DIALOG SUKSES
  // ==========================================================

  Future<void> _showSuccessDialog(
    String message,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color:
                      Color(0xFF16A34A),
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              const Text(
                'Berhasil',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color:
                      Color(0xFF6B7280),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                width:
                    double.infinity,
                height: 46,
                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF2563EB,
                    ),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'Selesai',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // SNACKBAR
  // ==========================================================

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success
                    ? Icons
                        .check_circle_rounded
                    : Icons
                        .error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
          backgroundColor: success
              ? const Color(
                  0xFF16A34A,
                )
              : const Color(
                  0xFFDC2626,
                ),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final size =
        MediaQuery.of(context).size;

    final isTablet =
        size.width >= 600;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        foregroundColor:
            const Color(0xFF111827),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Perizinan',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              EdgeInsets.symmetric(
            horizontal:
                isTablet ? 40 : 20,
            vertical: 24,
          ),
          child: Center(
            child:
                ConstrainedBox(
              constraints:
                  BoxConstraints(
                maxWidth:
                    isTablet ? 560 : 500,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  _buildHeader(),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildUserCard(),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildStatusSelector(),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildDateCard(),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildLocationCard(),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildKeteranganCard(),

                  const SizedBox(
                    height: 24,
                  ),

                  _buildSubmitButton(),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildInformation(),

                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    final isOff = _isOff;

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: isOff
              ? const [
                  Color(0xFF6B7280),
                  Color(0xFF4B5563),
                ]
              : const [
                  Color(0xFF2563EB),
                  Color(0xFF1D4ED8),
                ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF1D4ED8)
                    .withValues(alpha:0.16),
            blurRadius: 22,
            offset:
                const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(alpha:0.22),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              isOff
                  ? Icons
                      .block_rounded
                  : Icons
                      .event_note_rounded,
              color:
                  Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengajuan Perizinan',
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Halo, $_namaSiswa',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFFDCE7FF),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                _buildWorkStatusBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS BADGE
  // ==========================================================

  Widget _buildWorkStatusBadge() {
    final isOff = _isOff;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withValues(alpha:0.16),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color:
              Colors.white
                  .withValues(alpha:0.22),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            isOff
                ? Icons.block_rounded
                : Icons
                    .verified_user_rounded,
            size: 14,
            color:
                Colors.white,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            'Status Kerja: '
            '${_statusKerja.isEmpty ? '-' : _statusKerja.toUpperCase()}',
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // USER CARD
  // ==========================================================

  Widget _buildUserCard() {
    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEFF6FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color:
                  Color(0xFF2563EB),
              size: 26,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _namaSiswa,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xFF111827),
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '$_idPKL • $_bagian',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          if (_isOff)
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF3F4F6,
                ),
                borderRadius:
                    BorderRadius.circular(
                  30,
                ),
              ),
              child:
                  const Text(
                'OFF',
                style:
                    TextStyle(
                  color:
                      Color(0xFF4B5563),
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS SELECTOR
  // ==========================================================

  Widget _buildStatusSelector() {
    return _buildCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon:
                Icons.assignment_rounded,
            title:
                'Jenis Perizinan',
            subtitle:
                'Pilih jenis pengajuan untuk hari ini',
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _buildStatusButton(
                  value: 'Izin',
                  icon:
                      Icons.event_available_rounded,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    _buildStatusButton(
                  value: 'Sakit',
                  icon:
                      Icons.medical_services_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS BUTTON
  // ==========================================================

  Widget _buildStatusButton({
    required String value,
    required IconData icon,
  }) {
    final selected =
        _status == value;

    final disabled =
        _isSubmitting || _isOff;

    return InkWell(
      onTap: disabled
          ? null
          : () {
              setState(() {
                _status = value;
              });
            },
      borderRadius:
          BorderRadius.circular(15),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          vertical: 15,
          horizontal: 12,
        ),
        decoration:
            BoxDecoration(
          color: disabled
              ? const Color(
                  0xFFF3F4F6,
                )
              : selected
                  ? const Color(
                      0xFFEFF6FF,
                    )
                  : const Color(
                      0xFFF9FAFB,
                    ),
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border:
              Border.all(
            color: disabled
                ? const Color(
                    0xFFD1D5DB,
                  )
                : selected
                    ? const Color(
                        0xFF2563EB,
                      )
                    : const Color(
                        0xFFE5E7EB,
                      ),
            width:
                selected && !disabled
                    ? 1.5
                    : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: disabled
                  ? const Color(
                      0xFF9CA3AF,
                    )
                  : selected
                      ? const Color(
                          0xFF2563EB,
                        )
                      : const Color(
                          0xFF6B7280,
                        ),
            ),

            const SizedBox(
              width: 9,
            ),

            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
                color: disabled
                    ? const Color(
                        0xFF9CA3AF,
                      )
                    : selected
                        ? const Color(
                            0xFF1D4ED8,
                          )
                        : const Color(
                            0xFF4B5563,
                          ),
              ),
            ),

            if (selected &&
                !disabled) ...[
              const SizedBox(
                width: 7,
              ),
              const Icon(
                Icons
                    .check_circle_rounded,
                size: 17,
                color:
                    Color(0xFF2563EB),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DATE CARD
  // ==========================================================

  Widget _buildDateCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon:
                Icons.calendar_month_rounded,
            title:
                'Tanggal Perizinan',
            subtitle:
                'Pengajuan hanya dapat dilakukan untuk hari ini',
          ),

          const SizedBox(
            height: 12,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF9FAFB,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFE5E7EB,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFEFF6FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .today_rounded,
                    color:
                        Color(
                      0xFF2563EB,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Tanggal pengajuan',
                        style:
                            TextStyle(
                          fontSize: 11,
                          color:
                              Color(
                            0xFF9CA3AF,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        _formatTanggalIndonesia(
                          _tanggalHariIni,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(
                            0xFF111827,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .lock_outline_rounded,
                  color:
                      Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LOCATION CARD
  // ==========================================================

  Widget _buildLocationCard() {
    final hasLocation =
        _position != null &&
            _jarak != null;

    return _buildCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon:
                Icons.location_on_rounded,
            title:
                'Lokasi Pengajuan',
            subtitle:
                'Lokasi perangkat dicatat saat pengajuan',
            trailing:
                hasLocation
                    ? const Icon(
                        Icons
                            .check_circle_rounded,
                        color:
                            Color(
                          0xFF16A34A,
                        ),
                        size: 20,
                      )
                    : null,
          ),

          const SizedBox(
            height: 12,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color: hasLocation
                  ? const Color(
                      0xFFF0FDF4,
                    )
                  : const Color(
                      0xFFF9FAFB,
                    ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color: hasLocation
                    ? const Color(
                        0xFFBBF7D0,
                      )
                    : const Color(
                        0xFFE5E7EB,
                      ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color: hasLocation
                        ? const Color(
                            0xFFDCFCE7,
                          )
                        : const Color(
                            0xFFEFF6FF,
                          ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    hasLocation
                        ? Icons
                            .location_on_rounded
                        : Icons
                            .location_searching_rounded,
                    color: hasLocation
                        ? const Color(
                            0xFF16A34A,
                          )
                        : const Color(
                            0xFF2563EB,
                          ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: hasLocation
                      ? Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Lokasi berhasil didapat',
                              style:
                                  TextStyle(
                                fontSize:
                                    13,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color:
                                    Color(
                                  0xFF166534,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Jarak dari perusahaan: '
                              '${_formatDistance(_jarak!)}',
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Color(
                                  0xFF4B5563,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Lokasi belum diambil',
                          style:
                              TextStyle(
                            fontSize:
                                13,
                            color:
                                Color(
                              0xFF6B7280,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 48,
            child:
                OutlinedButton.icon(
              onPressed:
                  _isGettingLocation ||
                          _isSubmitting ||
                          _isOff
                      ? null
                      : _getLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2.2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .my_location_rounded,
                    ),
              label: Text(
                _isGettingLocation
                    ? 'Mengambil lokasi...'
                    : hasLocation
                        ? 'Perbarui Lokasi'
                        : 'Ambil Lokasi',
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF2563EB,
                ),
                disabledForegroundColor:
                    const Color(
                  0xFF9CA3AF,
                ),
                side:
                    BorderSide(
                  color: _isOff
                      ? const Color(
                          0xFFD1D5DB,
                        )
                      : const Color(
                          0xFF2563EB,
                        ),
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // KETERANGAN CARD
  // ==========================================================

  Widget _buildKeteranganCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon:
                Icons.notes_rounded,
            title:
                'Keterangan',
            subtitle:
                _status == 'Sakit'
                    ? 'Jelaskan kondisi atau alasan sakit'
                    : 'Jelaskan alasan pengajuan izin',
          ),

          const SizedBox(
            height: 12,
          ),

          TextField(
            controller:
                _keteranganController,
            enabled:
                !_isSubmitting &&
                    !_isOff,
            maxLines: 5,
            maxLength: 500,
            textInputAction:
                TextInputAction.newline,
            decoration:
                InputDecoration(
              hintText:
                  _status == 'Sakit'
                      ? 'Contoh: Sakit dan sedang berobat...'
                      : 'Contoh: Ada keperluan keluarga...',
              hintStyle:
                  const TextStyle(
                color:
                    Color(0xFF9CA3AF),
                fontSize: 13,
              ),
              filled: true,
              fillColor:
                  const Color(
                0xFFF9FAFB,
              ),
              contentPadding:
                  const EdgeInsets.all(
                14,
              ),
              counterStyle:
                  const TextStyle(
                fontSize: 10,
                color:
                    Color(0xFF9CA3AF),
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
              disabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFD1D5DB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SUBMIT BUTTON
  // ==========================================================

  Widget _buildSubmitButton() {
    return SizedBox(
      width:
          double.infinity,
      height: 55,
      child:
          ElevatedButton(
        onPressed:
            _isSubmitting || _isOff
                ? null
                : _submitPerizinan,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(
            0xFF2563EB,
          ),
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              const Color(
            0xFFCBD5E1,
          ),
          disabledForegroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
        child:
            AnimatedSwitcher(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  key: ValueKey(
                    'loading',
                  ),
                  width: 23,
                  height: 23,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color:
                        Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey(
                    'submit',
                  ),
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      _isOff
                          ? Icons
                              .block_rounded
                          : Icons
                              .send_rounded,
                      size: 20,
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    Text(
                      _isOff
                          ? 'Perizinan Tidak Tersedia'
                          : 'Ajukan $_status',
                      style:
                          const TextStyle(
                        fontSize:
                            15.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================
  // INFORMATION
  // ==========================================================

  Widget _buildInformation() {
    if (_isOff) {
      return Container(
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFFF3F4F6,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border:
              Border.all(
            color:
                const Color(
              0xFFD1D5DB,
            ),
          ),
        ),
        child: const Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Icon(
              Icons
                  .block_rounded,
              size: 19,
              color:
                  Color(
                0xFF6B7280,
              ),
            ),

            SizedBox(
              width: 9,
            ),

            Expanded(
              child: Text(
                'STATUS KERJA Anda adalah Off. '
                'Pengajuan Izin dan Sakit tidak tersedia.',
                style:
                    TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color:
                      Color(
                    0xFF4B5563,
                  ),
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF0F7FF,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFD9EAFE,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Icon(
            Icons
                .info_outline_rounded,
            size: 19,
            color:
                Color(
              0xFF2563EB,
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              _status == 'Sakit'
                  ? 'Untuk pengajuan sakit, foto tidak diperlukan. '
                    'Surat dokter diberikan langsung kepada pembimbing atau supervisor.'
                  : 'Lokasi GPS tetap dicatat sebagai lokasi pengajuan izin. '
                    'Foto tidak diperlukan.',
              style:
                  const TextStyle(
                fontSize: 12,
                height: 1.45,
                color:
                    Color(
                  0xFF1E40AF,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFEFF6FF,
            ),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            color:
                const Color(
              0xFF2563EB,
            ),
            size: 19,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(
                    0xFF1F2937,
                  ),
                ),
              ),

              if (subtitle != null) ...[
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color:
                        Color(
                      0xFF9CA3AF,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CARD
  // ==========================================================

  Widget _buildCard({
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(alpha:0.08),
            blurRadius: 22,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  // ==========================================================
  // FORMAT JARAK
  // ==========================================================

  String _formatDistance(
    double distance,
  ) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(1)} meter';
    }

    return '${(distance / 1000).toStringAsFixed(2)} km';
  }
}