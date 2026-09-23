import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const String apiUrl =
    'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

// ============================================================
// KOORDINAT PERUSAHAAN
// HARUS SAMA DENGAN CODE.GS
// ============================================================

const double companyLatitude = -6.137643;
const double companyLongitude = 106.804286;
const double allowedRadius = 100.0;

// ============================================================
// STATUS PENGIRIMAN ABSENSI
// ============================================================

enum _AttendanceSendState {
  success,
  rejected,
  uncertain,
}

class _AttendanceSendOutcome {
  final _AttendanceSendState state;
  final String message;

  const _AttendanceSendOutcome({
    required this.state,
    required this.message,
  });

  factory _AttendanceSendOutcome.success() {
    return const _AttendanceSendOutcome(
      state: _AttendanceSendState.success,
      message: 'Absensi berhasil.',
    );
  }

  factory _AttendanceSendOutcome.rejected(
    String message,
  ) {
    return _AttendanceSendOutcome(
      state: _AttendanceSendState.rejected,
      message: message,
    );
  }

  factory _AttendanceSendOutcome.uncertain(
    String message,
  ) {
    return _AttendanceSendOutcome(
      state: _AttendanceSendState.uncertain,
      message: message,
    );
  }
}

// ============================================================
// STATUS ABSENSI HARI INI
// ============================================================

class _TodayAttendanceStatus {
  final bool masuk;
  final bool pulang;
  final bool bolehAbsenPulang;
  final String statusKerja;
  final String jadwalPulangId;
  final String mulaiAbsenPulang;
  final String maksimalAbsenPulang;
  final String pesanAbsenPulang;

  const _TodayAttendanceStatus({
    required this.masuk,
    required this.pulang,
    required this.bolehAbsenPulang,
    required this.statusKerja,
    required this.jadwalPulangId,
    required this.mulaiAbsenPulang,
    required this.maksimalAbsenPulang,
    required this.pesanAbsenPulang,
  });
}

// ============================================================
// HALAMAN ABSENSI
// ============================================================

class AbsensiPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AbsensiPage({
    super.key,
    required this.userData,
  });

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final ImagePicker _picker = ImagePicker();

  // ==========================================================
  // DATA USER
  // ==========================================================

  String get idPKL {
    return widget.userData['id_pkl']
            ?.toString()
            .trim() ??
        '';
  }

  String get nama {
    return widget.userData['nama_siswa']
            ?.toString()
            .trim() ??
        '';
  }

  String get sekolah {
    return widget.userData['asal_sekolah']
            ?.toString()
            .trim() ??
        '';
  }

  String get jurusan {
    return widget.userData['jurusan']
            ?.toString()
            .trim() ??
        '';
  }

  String get kelas {
    return widget.userData['kelas']
            ?.toString()
            .trim() ??
        '';
  }

  String get divisi {
    return widget.userData['divisi']
            ?.toString()
            .trim() ??
        '';
  }

  String get bagian {
    return widget.userData['bagian']
            ?.toString()
            .trim() ??
        '';
  }

  String get foto {
    return widget.userData['foto']
            ?.toString()
            .trim() ??
        '';
  }

  // ==========================================================
  // STATUS KERJA
  //
  // Sumber utama:
  // Code.gs -> kolom Q -> status_kerja
  //
  // Nilai:
  // Off
  // Online
  // Offline
  // ==========================================================

  String get statusKerja {
    if (_liveStatusKerja.trim().isNotEmpty) {
      return _liveStatusKerja.trim();
    }

    final dynamic value =
        widget.userData['status_kerja'] ??
        widget.userData['STATUS KERJA'] ??
        widget.userData['STATUS_KERJA'] ??
        widget.userData['status kerja'] ??
        widget.userData['statusKerja'] ??
        '';

    return value.toString().trim();
  }

  bool get isOff {
    return statusKerja.toLowerCase() == 'off';
  }

  bool get isOnline {
    return statusKerja.toLowerCase() == 'online';
  }

  bool get isOffline {
    return statusKerja.toLowerCase() == 'offline';
  }

  String get fotoUrl {
    if (foto.isEmpty) {
      return '';
    }

    return 'https://drive.google.com/uc?export=view&id=$foto';
  }

  // ==========================================================
  // STATE
  // ==========================================================

  bool _isLoading = false;

  bool _isCheckingAttendance = true;

  bool _hasCheckedInToday = false;

  bool _hasCheckedOutToday = false;

  // Status izin pulang berasal langsung dari Code.gs.
  // Ini bukan sekadar berdasarkan sudah absen masuk.
  bool _bolehAbsenPulang = false;

  String _jadwalPulangId = '';
  String _mulaiAbsenPulang = '';
  String _maksimalAbsenPulang = '';
  String _pesanAbsenPulang = '';

  bool _statusCheckFailed = false;

  bool _attendanceNeedsVerification = false;

  bool _actionLocked = false;

  String? _statusMessage;

  // ==========================================================
  // REFRESH DATABASE OTOMATIS
  // ==========================================================

  String _liveStatusKerja = '';

  Timer? _databaseRefreshTimer;

  bool _isRefreshingDatabase = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _liveStatusKerja = _getInitialStatusKerja();

    _loadTodayAttendance();

    _databaseRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _refreshFromDatabase();
      },
    );
  }

  String _getInitialStatusKerja() {
    final dynamic value =
        widget.userData['status_kerja'] ??
        widget.userData['STATUS KERJA'] ??
        widget.userData['STATUS_KERJA'] ??
        widget.userData['status kerja'] ??
        widget.userData['statusKerja'] ??
        '';

    return value.toString().trim();
  }

  Future<void> _refreshFromDatabase() async {
    if (!mounted || _isLoading || _isRefreshingDatabase) {
      return;
    }

    _isRefreshingDatabase = true;

    try {
      final status = await _getTodayStatus(
        timeout: const Duration(seconds: 5),
      );

      if (!mounted) return;

      final newStatus = status.statusKerja.trim();
      final oldStatus = statusKerja.trim();

      if (newStatus.isEmpty) {
        setState(() {
          _hasCheckedInToday = status.masuk;
          _hasCheckedOutToday = status.pulang;
          _bolehAbsenPulang = status.bolehAbsenPulang;
          _jadwalPulangId = status.jadwalPulangId;
          _mulaiAbsenPulang = status.mulaiAbsenPulang;
          _maksimalAbsenPulang = status.maksimalAbsenPulang;
          _pesanAbsenPulang = status.pesanAbsenPulang;
          _isCheckingAttendance = false;
          _statusCheckFailed = false;
        });
        return;
      }

      final statusChanged =
          oldStatus.toLowerCase() != newStatus.toLowerCase();
      final newIsOff = newStatus.toLowerCase() == 'off';

      setState(() {
        _liveStatusKerja = newStatus;
        _hasCheckedInToday = newIsOff ? false : status.masuk;
        _hasCheckedOutToday = newIsOff ? false : status.pulang;
        _bolehAbsenPulang = newIsOff ? false : status.bolehAbsenPulang;
        _jadwalPulangId = newIsOff ? '' : status.jadwalPulangId;
        _mulaiAbsenPulang = newIsOff ? '' : status.mulaiAbsenPulang;
        _maksimalAbsenPulang = newIsOff ? '' : status.maksimalAbsenPulang;
        _pesanAbsenPulang = newIsOff ? status.pesanAbsenPulang : status.pesanAbsenPulang;
        _isCheckingAttendance = false;
        _statusCheckFailed = false;

        if (newIsOff) {
          _attendanceNeedsVerification = false;
          _actionLocked = true;
          _statusMessage = null;
        } else if (statusChanged) {
          _attendanceNeedsVerification = false;
          _actionLocked = false;
          _statusMessage = null;
        }
      });
    } catch (_) {
      // Pertahankan status terakhir jika koneksi sementara gagal.
    } finally {
      _isRefreshingDatabase = false;
    }
  }

  @override
  void dispose() {
    _databaseRefreshTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // LOAD STATUS ABSENSI HARI INI
  // ==========================================================

  Future<void> _loadTodayAttendance({
    bool showLoader = true,
  }) async {
    if (_isLoading) {
      return;
    }

    // ========================================================
    // CEK STATUS DARI DATABASE
    // Status Off tetap dicek ke server agar perubahan Off ->
    // Online/Offline dapat terdeteksi otomatis.
    // ========================================================

    // ========================================================
    // ONLINE / OFFLINE
    // LANJUT CEK STATUS SEPERTI BIASA
    // ========================================================

    if (mounted) {
      setState(() {
        if (showLoader) {
          _isCheckingAttendance = true;
        }

        _statusCheckFailed = false;
      });
    }

    try {
      final status = await _getTodayStatus(
        timeout: const Duration(
          seconds: 8,
        ),
      );

      if (!mounted) return;

      final liveStatus = status.statusKerja.trim();

      setState(() {
        if (liveStatus.isNotEmpty) {
          _liveStatusKerja = liveStatus;
        }

        final currentIsOff = isOff;

        _hasCheckedInToday =
            currentIsOff ? false : status.masuk;

        _hasCheckedOutToday =
            currentIsOff ? false : status.pulang;

        _bolehAbsenPulang =
            currentIsOff ? false : status.bolehAbsenPulang;

        _jadwalPulangId =
            currentIsOff ? '' : status.jadwalPulangId;

        _mulaiAbsenPulang =
            currentIsOff ? '' : status.mulaiAbsenPulang;

        _maksimalAbsenPulang =
            currentIsOff ? '' : status.maksimalAbsenPulang;

        _pesanAbsenPulang =
            status.pesanAbsenPulang;

        _isCheckingAttendance = false;

        _statusCheckFailed = false;

        _attendanceNeedsVerification = false;

        _actionLocked = currentIsOff;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isCheckingAttendance = false;

        _statusCheckFailed = true;

        _actionLocked = true;
      });
    }
  }

  // ==========================================================
  // GET STATUS ABSENSI
  // ==========================================================

  Future<_TodayAttendanceStatus> _getTodayStatus({
    Duration timeout =
        const Duration(seconds: 8),
  }) async {
    final id = idPKL.trim();

    if (id.isEmpty) {
      throw Exception(
        'ID PKL tidak ditemukan.',
      );
    }

    final uri = Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'statusAbsensiHariIni',
        'id_pkl': id,
      },
    );

    final response =
        await http.get(uri).timeout(
              timeout,
            );

    if (response.statusCode != 200) {
      throw Exception(
        'Server mengembalikan status '
        '${response.statusCode}.',
      );
    }

    if (response.body.trim().isEmpty) {
      throw Exception(
        'Respons server kosong.',
      );
    }

    final decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map) {
      throw Exception(
        'Format respons server tidak valid.',
      );
    }

    final result =
        Map<String, dynamic>.from(
      decoded,
    );

    if (result['success'] == false) {
      throw Exception(
        result['message']?.toString() ??
            'Gagal mengambil status absensi.',
      );
    }

    final dynamic rawData =
        result['data'];

    Map<String, dynamic> data;

    if (rawData is Map) {
      data =
          Map<String, dynamic>.from(
        rawData,
      );
    } else {
      data = result;
    }

    // ========================================================
    // STATUS MASUK
    // ========================================================

    dynamic statusMasuk = _findValue(
      data,
      result,
      [
        'status_masuk',
        'sudah_masuk',
        'has_checked_in',
      ],
    );

    // ========================================================
    // STATUS PULANG
    // ========================================================

    dynamic statusPulang = _findValue(
      data,
      result,
      [
        'status_pulang',
        'sudah_pulang',
        'has_checked_out',
      ],
    );

    // ========================================================
    // FALLBACK BOLEH ABSEN MASUK
    // ========================================================

    if (statusMasuk == null) {
      final bolehMasuk =
          _findValue(
        data,
        result,
        [
          'boleh_absen_masuk',
        ],
      );

      if (bolehMasuk != null) {
        statusMasuk =
            !_toBool(bolehMasuk);
      }
    }

    // ========================================================
    // FALLBACK BOLEH ABSEN PULANG
    // ========================================================

    if (statusPulang == null) {
      final bolehPulang =
          _findValue(
        data,
        result,
        [
          'boleh_absen_pulang',
        ],
      );

      if (bolehPulang != null) {
        statusPulang =
            !_toBool(bolehPulang);
      }
    }

    final dynamic rawBolehAbsenPulang = _findValue(
      data,
      result,
      [
        'boleh_absen_pulang',
      ],
    );

    final dynamic rawJadwalPulangId = _findValue(
      data,
      result,
      [
        'jadwal_pulang_id',
      ],
    );

    final dynamic rawMulaiAbsenPulang = _findValue(
      data,
      result,
      [
        'mulai_absen_pulang',
      ],
    );

    final dynamic rawMaksimalAbsenPulang = _findValue(
      data,
      result,
      [
        'maksimal_absen_pulang',
      ],
    );

    final dynamic rawPesanAbsenPulang = _findValue(
      data,
      result,
      [
        'pesan_absen_pulang',
      ],
    );

    final dynamic rawStatusKerja = _findValue(
      data,
      result,
      [
        'status_kerja',
        'STATUS KERJA',
        'STATUS_KERJA',
        'status kerja',
        'statusKerja',
      ],
    );

    final bool bolehAbsenPulang =
        rawBolehAbsenPulang != null
            ? _toBool(rawBolehAbsenPulang)
            : false;

    return _TodayAttendanceStatus(
      masuk: _toBool(statusMasuk),
      pulang: _toBool(statusPulang),
      bolehAbsenPulang: bolehAbsenPulang,
      statusKerja: rawStatusKerja?.toString().trim() ?? '',
      jadwalPulangId: rawJadwalPulangId?.toString().trim() ?? '',
      mulaiAbsenPulang: rawMulaiAbsenPulang?.toString().trim() ?? '',
      maksimalAbsenPulang: rawMaksimalAbsenPulang?.toString().trim() ?? '',
      pesanAbsenPulang: rawPesanAbsenPulang?.toString().trim() ?? '',
    );
  }

  // ==========================================================
  // CARI VALUE
  // ==========================================================

  dynamic _findValue(
    Map<String, dynamic> data,
    Map<String, dynamic> fallback,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data.containsKey(key)) {
        return data[key];
      }

      if (fallback.containsKey(key)) {
        return fallback[key];
      }
    }

    return null;
  }

  // ==========================================================
  // KONVERSI KE BOOLEAN
  // ==========================================================

  bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'ya' ||
        text == 'sudah' ||
        text == 'aktif';
  }

  // ==========================================================
  // MULAI ABSENSI
  // ==========================================================

  Future<void> _startAttendance(
    String action,
  ) async {
    // ========================================================
    // PENGAMAN UTAMA STATUS OFF
    //
    // TIDAK BOLEH ABSEN MASUK / PULANG
    // ========================================================

    if (isOff) {
      _showError(
        'Status kerja Anda Off. '
        'Absensi tidak tersedia.',
      );

      return;
    }

    // ========================================================
    // PENGAMAN
    // ========================================================

    if (_isLoading ||
        _actionLocked ||
        _isCheckingAttendance ||
        _statusCheckFailed ||
        _attendanceNeedsVerification) {
      return;
    }

    // ========================================================
    // VALIDASI ABSEN MASUK
    // ========================================================

    if (action == 'masuk' &&
        _hasCheckedInToday) {
      _showError(
        'Anda sudah melakukan absen masuk hari ini.',
      );

      return;
    }

    // ========================================================
    // VALIDASI ABSEN PULANG
    // ========================================================

    if (action == 'pulang' &&
        !_hasCheckedInToday) {
      _showError(
        'Anda belum melakukan absen masuk.',
      );

      return;
    }

    if (action == 'pulang' &&
        _hasCheckedOutToday) {
      _showError(
        'Anda sudah melakukan absen pulang hari ini.',
      );

      return;
    }

    bool keepLocked = false;

    setState(() {
      _isLoading = true;

      _actionLocked = true;

      _statusMessage = null;
    });

    try {
      // ======================================================
      // 1. AMBIL FOTO
      // ======================================================

      final XFile? image =
          await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 55,
        maxWidth: 960,
        maxHeight: 960,
        preferredCameraDevice:
            CameraDevice.front,
      );

      if (image == null) {
        throw Exception(
          'Pengambilan foto dibatalkan.',
        );
      }

      if (!mounted) return;

      // ======================================================
      // 2. GPS
      // ======================================================

      final position =
          await _getCurrentPosition();

      if (!mounted) return;

      // ======================================================
      // 3. AKURASI GPS
      // ======================================================

      if (!position.accuracy.isFinite) {
        throw Exception(
          'Akurasi lokasi tidak dapat ditentukan.',
        );
      }

      if (position.accuracy >
          allowedRadius) {
        throw Exception(
          'Akurasi GPS terlalu rendah '
          '(${position.accuracy.toStringAsFixed(0)} m). '
          'Silakan coba lagi di tempat terbuka.',
        );
      }

      // ======================================================
      // 4. HITUNG JARAK
      // ======================================================

      final distance =
          Geolocator.distanceBetween(
        companyLatitude,
        companyLongitude,
        position.latitude,
        position.longitude,
      );

      // ======================================================
      // 5. VALIDASI RADIUS
      // ======================================================

      if (distance >
          allowedRadius) {
        throw Exception(
          'Anda berada di luar area absensi. '
          'Jarak Anda sekitar '
          '${distance.toStringAsFixed(0)} meter.',
        );
      }

      // ======================================================
      // 6. BACA FOTO
      // ======================================================

      final bytes =
          await image.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception(
          'Foto tidak dapat dibaca.',
        );
      }

      // ======================================================
      // 7. BASE64
      // ======================================================

      final fotoBase64 =
          base64Encode(bytes);

      // ======================================================
      // 8. KIRIM KE SERVER
      // ======================================================

      final outcome =
          await _sendAttendance(
        action: action,
        idPKL: idPKL.trim(),
        fotoBase64: fotoBase64,
        latitude: position.latitude,
        longitude: position.longitude,
        jarak: distance,
      );

      if (!mounted) return;

      // ======================================================
      // 9. BERHASIL
      // ======================================================

      if (outcome.state ==
          _AttendanceSendState.success) {
        setState(() {
          if (action == 'masuk') {
            _hasCheckedInToday = true;
          } else {
            _hasCheckedOutToday = true;
          }

          _attendanceNeedsVerification =
              false;

          _statusCheckFailed = false;

          _actionLocked = false;

          _statusMessage =
              action == 'masuk'
                  ? 'Absen masuk berhasil dicatat.'
                  : 'Absen pulang berhasil dicatat.';
        });

        _showSuccess(
          action == 'masuk'
              ? 'Absen masuk berhasil.'
              : 'Absen pulang berhasil.',
        );

        // Setelah absen masuk, ambil aturan pulang terbaru dari Code.gs.
        // Ini membuat tombol pulang mengikuti jadwal database secara real-time.
        await _loadTodayAttendance(showLoader: false);

        return;
      }

      // ======================================================
      // 10. DITOLAK SERVER
      // ======================================================

      if (outcome.state ==
          _AttendanceSendState.rejected) {
        setState(() {
          _attendanceNeedsVerification =
              false;

          _actionLocked = false;
        });

        _showError(
          outcome.message,
        );

        // Cek ulang status setelah server
        // menolak permintaan.
        try {
          final status =
              await _getTodayStatus(
            timeout:
                const Duration(seconds: 5),
          );

          if (!mounted) return;

          setState(() {
            if (status.statusKerja.trim().isNotEmpty) {
              _liveStatusKerja = status.statusKerja.trim();
            }

            final currentIsOff = isOff;

            _hasCheckedInToday =
                currentIsOff ? false : status.masuk;

            _hasCheckedOutToday =
                currentIsOff ? false : status.pulang;

            _bolehAbsenPulang =
                currentIsOff ? false : status.bolehAbsenPulang;

            _jadwalPulangId =
                currentIsOff ? '' : status.jadwalPulangId;

            _mulaiAbsenPulang =
                currentIsOff ? '' : status.mulaiAbsenPulang;

            _maksimalAbsenPulang =
                currentIsOff ? '' : status.maksimalAbsenPulang;

            _pesanAbsenPulang =
                status.pesanAbsenPulang;
          });
        } catch (_) {}

        return;
      }

      // ======================================================
      // 11. TIDAK PASTI
      // ======================================================

      if (outcome.state ==
          _AttendanceSendState.uncertain) {
        keepLocked = true;

        setState(() {
          _attendanceNeedsVerification =
              true;

          _actionLocked = true;
        });

        _showWarning(
          'Absensi belum dapat dikonfirmasi. '
          'Jangan melakukan absensi lagi. '
          'Tekan "Cek Status" terlebih dahulu.',
        );
      }
    } on TimeoutException {
      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (!mounted) return;

      if (verified) {
        setState(() {
          if (action == 'masuk') {
            _hasCheckedInToday = true;
          } else {
            _hasCheckedOutToday = true;
          }

          _attendanceNeedsVerification =
              false;

          _actionLocked = false;

          _statusMessage =
              'Absensi berhasil dicatat.';
        });

        _showSuccess(
          'Absensi berhasil dicatat.',
        );

        return;
      }

      keepLocked = true;

      setState(() {
        _attendanceNeedsVerification =
            true;

        _actionLocked = true;
      });

      _showWarning(
        'Koneksi terlalu lama. '
        'Status absensi belum dapat dipastikan. '
        'Tekan "Cek Status" sebelum mencoba lagi.',
      );
    } on SocketException {
      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (!mounted) return;

      if (verified) {
        setState(() {
          if (action == 'masuk') {
            _hasCheckedInToday = true;
          } else {
            _hasCheckedOutToday = true;
          }

          _attendanceNeedsVerification =
              false;

          _actionLocked = false;

          _statusMessage =
              'Absensi berhasil dicatat.';
        });

        _showSuccess(
          'Absensi berhasil dicatat.',
        );

        return;
      }

      keepLocked = true;

      setState(() {
        _attendanceNeedsVerification =
            true;

        _actionLocked = true;
      });

      _showWarning(
        'Koneksi internet bermasalah. '
        'Status absensi belum dapat dipastikan. '
        'Tekan "Cek Status" sebelum mencoba lagi.',
      );
    } catch (e) {
      if (!mounted) return;

      final message = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      setState(() {
        _attendanceNeedsVerification =
            false;

        _actionLocked = false;
      });

      _showError(
        message.isEmpty
            ? 'Terjadi kesalahan.'
            : message,
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        if (!keepLocked) {
          _actionLocked = false;
        }
      });
    }
  }

  // ==========================================================
  // GPS
  // ==========================================================

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'GPS/lokasi sedang tidak aktif. '
        'Silakan aktifkan lokasi terlebih dahulu.',
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
        'Aktifkan izin lokasi dari pengaturan aplikasi.',
      );
    }

    final position =
        await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException(
          'GPS terlalu lama mendapatkan lokasi.',
        );
      },
    );

    return position;
  }

  // ==========================================================
  // KIRIM ABSENSI
  // ==========================================================

  Future<_AttendanceSendOutcome>
      _sendAttendance({
    required String action,
    required String idPKL,
    required String fotoBase64,
    required double latitude,
    required double longitude,
    required double jarak,
  }) async {
    final payload = {
      'action': action == 'masuk'
          ? 'absensiMasuk'
          : 'absensiPulang',
      'id_pkl': idPKL,
      'foto': fotoBase64,
      'latitude': latitude,
      'longitude': longitude,
      'jarak': jarak,
    };

    final client = HttpClient();

    client.connectionTimeout =
        const Duration(seconds: 10);

    try {
      final request =
          await client
              .postUrl(
                Uri.parse(apiUrl),
              )
              .timeout(
                const Duration(seconds: 10),
              );

      request.followRedirects = false;

      request.headers.contentType =
          ContentType.json;

      request.headers.set(
        'Accept',
        'application/json',
      );

      request.write(
        jsonEncode(payload),
      );

      final response =
          await request
              .close()
              .timeout(
                const Duration(seconds: 20),
              );

      final statusCode =
          response.statusCode;

      // ======================================================
      // RESPONSE 200
      // ======================================================

      if (statusCode == 200) {
        final body =
            await utf8.decoder
                .bind(response)
                .join()
                .timeout(
                  const Duration(seconds: 5),
                );

        if (body.trim().isEmpty) {
          final verified =
              await _verifyAttendanceAfterUncertain(
            action,
          );

          if (verified) {
            return _AttendanceSendOutcome
                .success();
          }

          return _AttendanceSendOutcome
              .uncertain(
            'Respons server kosong.',
          );
        }

        try {
          final decoded =
              jsonDecode(body);

          if (decoded is! Map) {
            final verified =
                await _verifyAttendanceAfterUncertain(
              action,
            );

            if (verified) {
              return _AttendanceSendOutcome
                  .success();
            }

            return _AttendanceSendOutcome
                .uncertain(
              'Respons server tidak valid.',
            );
          }

          final result =
              Map<String, dynamic>.from(
            decoded,
          );

          if (result['success'] ==
              true) {
            return _AttendanceSendOutcome
                .success();
          }

          return _AttendanceSendOutcome
              .rejected(
            result['message']
                    ?.toString() ??
                'Absensi ditolak oleh server.',
          );
        } catch (_) {
          final verified =
              await _verifyAttendanceAfterUncertain(
            action,
          );

          if (verified) {
            return _AttendanceSendOutcome
                .success();
          }

          return _AttendanceSendOutcome
              .uncertain(
            'Respons server tidak dapat dibaca.',
          );
        }
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

        final verified =
            await _verifyAttendanceAfterUncertain(
          action,
        );

        if (verified) {
          return _AttendanceSendOutcome
              .success();
        }

        return _AttendanceSendOutcome
            .uncertain(
          'Absensi sedang diproses, '
          'tetapi belum dapat dikonfirmasi.',
        );
      }

      // ======================================================
      // ERROR SERVER
      // ======================================================

      await response.drain();

      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (verified) {
        return _AttendanceSendOutcome
            .success();
      }

      return _AttendanceSendOutcome
          .uncertain(
        'Server mengembalikan kode '
        '$statusCode.',
      );
    } on TimeoutException {
      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (verified) {
        return _AttendanceSendOutcome
            .success();
      }

      return _AttendanceSendOutcome
          .uncertain(
        'Koneksi terlalu lama.',
      );
    } on SocketException {
      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (verified) {
        return _AttendanceSendOutcome
            .success();
      }

      return _AttendanceSendOutcome
          .uncertain(
        'Koneksi internet bermasalah.',
      );
    } catch (_) {
      final verified =
          await _verifyAttendanceAfterUncertain(
        action,
      );

      if (verified) {
        return _AttendanceSendOutcome
            .success();
      }

      return _AttendanceSendOutcome
          .uncertain(
        'Terjadi kesalahan saat '
        'mengirim absensi.',
      );
    } finally {
      client.close(
        force: true,
      );
    }
  }

  // ==========================================================
  // VERIFIKASI ABSENSI SETELAH RESPONSE TIDAK PASTI
  // ==========================================================

  Future<bool>
      _verifyAttendanceAfterUncertain(
    String action,
  ) async {
    // Jangan melakukan verifikasi kalau ternyata
    // user berstatus Off.
    if (isOff) {
      return false;
    }

    for (
      int attempt = 0;
      attempt < 3;
      attempt++
    ) {
      try {
        final status =
            await _getTodayStatus(
          timeout:
              const Duration(seconds: 4),
        );

        if (status.statusKerja.trim().isNotEmpty && mounted) {
          setState(() {
            _liveStatusKerja = status.statusKerja.trim();
            _hasCheckedInToday = status.masuk;
            _hasCheckedOutToday = status.pulang;
            _bolehAbsenPulang = status.bolehAbsenPulang;
            _jadwalPulangId = status.jadwalPulangId;
            _mulaiAbsenPulang = status.mulaiAbsenPulang;
            _maksimalAbsenPulang = status.maksimalAbsenPulang;
            _pesanAbsenPulang = status.pesanAbsenPulang;
          });
        }

        final confirmed =
            status.statusKerja.trim().toLowerCase() == 'off'
                ? false
                : action == 'masuk'
                    ? status.masuk
                    : status.pulang;

        if (confirmed) {
          return true;
        }
      } catch (_) {}

      if (attempt < 2) {
        await Future.delayed(
          const Duration(
            milliseconds: 700,
          ),
        );
      }
    }

    return false;
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
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
          backgroundColor:
              const Color(0xFF16A34A),
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
  // ERROR
  // ==========================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
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
          backgroundColor:
              const Color(0xFFDC2626),
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
  // WARNING
  // ==========================================================

  void _showWarning(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 5),
          content: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
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
          backgroundColor:
              const Color(0xFFD97706),
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
        MediaQuery.sizeOf(context);

    final isSmallHeight =
        size.height < 700;

    final isTablet =
        size.width >= 600;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F8FC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFFF3F6FB),
        surfaceTintColor:
            Colors.transparent,

        title: const Text(
          'Absensi',
          style: TextStyle(
            color:
                Color(0xFF111827),
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Refresh status',

            onPressed:
                isOff ||
                        _isLoading ||
                        _isCheckingAttendance
                    ? null
                    : () =>
                        _loadTodayAttendance(),

            icon: const Icon(
              Icons.refresh_rounded,
              color:
                  Color(0xFF2563EB),
            ),
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              _loadTodayAttendance(),

          child:
              SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),

            padding:
                EdgeInsets.symmetric(
              horizontal:
                  isTablet ? 40 : 20,

              vertical:
                  isSmallHeight
                      ? 16
                      : 24,
            ),

            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(
                  maxWidth:
                      isTablet
                          ? 600
                          : 500,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,

                  children: [
                    _buildHeader(
                      isSmallHeight:
                          isSmallHeight,
                    ),

                    SizedBox(
                      height:
                          isSmallHeight
                              ? 18
                              : 24,
                    ),

                    _buildUserCard(),

                    SizedBox(
                      height:
                          isSmallHeight
                              ? 16
                              : 20,
                    ),

                    _buildAttendanceCard(),

                    SizedBox(
                      height:
                          isSmallHeight
                              ? 16
                              : 20,
                    ),

                    _buildInfoCard(),

                    SizedBox(
                      height:
                          isSmallHeight
                              ? 18
                              : 28,
                    ),

                    _buildFooter(),
                  ],
                ),
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

  Widget _buildHeader({
    required bool isSmallHeight,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallHeight ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallHeight ? 58 : 64,
            height: isSmallHeight ? 58 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              Icons.fact_check_rounded,
              color: Colors.white,
              size: isSmallHeight ? 31 : 35,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Absensi PKL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Catat kehadiran Anda hari ini',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFDCE8FF),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // USER CARD
  // ==========================================================
  // ==========================================================
  // USER CARD
  // ==========================================================

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOff
                    ? const [Color(0xFFE5E7EB), Color(0xFFF3F4F6)]
                    : const [Color(0xFFEFF6FF), Color(0xFFDDEBFF)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOff ? Icons.person_off_rounded : Icons.person_rounded,
              color: isOff ? const Color(0xFF9CA3AF) : const Color(0xFF2563EB),
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nama.isEmpty ? 'Peserta PKL' : nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (statusKerja.isNotEmpty) _buildWorkStatusBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  idPKL.isEmpty ? bagian : '$idPKL  •  $bagian',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                if (sekolah.isNotEmpty || kelas.isNotEmpty || jurusan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    [sekolah, kelas, jurusan].where((e) => e.isNotEmpty).join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BADGE STATUS KERJA
  // ==========================================================
  // ==========================================================
  // BADGE STATUS KERJA
  // ==========================================================

  Widget _buildWorkStatusBadge() {
    if (isOff) {
      return _badge(
        'OFF',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      );
    }

    if (isOnline) {
      return _badge(
        'ONLINE',
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
      );
    }

    if (isOffline) {
      return _badge(
        'OFFLINE',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      );
    }

    return _badge(
      statusKerja.toUpperCase(),
      const Color(0xFFF9FAFB),
      const Color(0xFF6B7280),
    );
  }

  // ==========================================================
  // ATTENDANCE CARD
  // ==========================================================

  Widget _buildAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF2563EB),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Kehadiran',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pantau status absensi hari ini',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              _buildTodayStatusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: isOff ? const Color(0xFFF3F4F6) : const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isOff ? const Color(0xFFE5E7EB) : const Color(0xFFE5EDFF),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOff ? Icons.block_rounded : Icons.location_on_rounded,
                  size: 18,
                  color: isOff ? const Color(0xFF6B7280) : const Color(0xFF2563EB),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    isOff
                        ? 'Status kerja Anda Off. Absensi tidak tersedia.'
                        : 'Foto dan lokasi akan dicatat saat melakukan absensi.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isOff ? const Color(0xFF6B7280) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isOff)
            _buildOffAttendance()
          else if (_isCheckingAttendance)
            _buildCheckingStatus()
          else if (_statusCheckFailed)
            _buildStatusCheckFailed()
          else if (_attendanceNeedsVerification)
            _buildVerificationRequired()
          else ...[
            _buildAttendanceButton(
              icon: Icons.login_rounded,
              title: 'Absen Masuk',
              subtitle: _hasCheckedInToday
                  ? 'Sudah tercatat hari ini'
                  : 'Ambil foto dan kirim lokasi',
              enabled: !_hasCheckedInToday && !_isLoading && !_actionLocked,
              loading: _isLoading && !_hasCheckedInToday,
              onPressed: () => _startAttendance('masuk'),
            ),
            const SizedBox(height: 12),
            _buildAttendanceButton(
              icon: Icons.logout_rounded,
              title: 'Absen Pulang',
              subtitle: !_hasCheckedInToday
                  ? 'Lakukan absen masuk terlebih dahulu'
                  : _hasCheckedOutToday
                      ? 'Sudah tercatat hari ini'
                      : _bolehAbsenPulang
                          ? 'Waktu pulang tersedia • ${_jadwalPulangId.isNotEmpty ? _jadwalPulangId : 'tanpa jadwal'}\nJadwal: ${_mulaiAbsenPulang.isNotEmpty ? _mulaiAbsenPulang : '--:--'} - ${_maksimalAbsenPulang.isNotEmpty ? _maksimalAbsenPulang : '--:--'}'
                          : (_pesanAbsenPulang.isNotEmpty
                              ? '$_pesanAbsenPulang\nJadwal: ${_mulaiAbsenPulang.isNotEmpty ? _mulaiAbsenPulang : '--:--'} - ${_maksimalAbsenPulang.isNotEmpty ? _maksimalAbsenPulang : '--:--'}'
                              : 'Jadwal pulang: ${_mulaiAbsenPulang.isNotEmpty ? _mulaiAbsenPulang : '--:--'} - ${_maksimalAbsenPulang.isNotEmpty ? _maksimalAbsenPulang : '--:--'}'),
              enabled: _hasCheckedInToday && !_hasCheckedOutToday && _bolehAbsenPulang && !_isLoading && !_actionLocked,
              loading: _isLoading && _hasCheckedInToday && !_hasCheckedOutToday,
              onPressed: () => _startAttendance('pulang'),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 15),
            _buildStatusMessage(),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // OFF ATTENDANCE
  // ==========================================================
  // ==========================================================
  // OFF ATTENDANCE
  // ==========================================================

  Widget _buildOffAttendance() {
    return Column(
      children: [
        _buildDisabledAttendanceButton(
          icon:
              Icons.login_rounded,

          title:
              'Absen Masuk',

          subtitle:
              'Tidak tersedia karena status kerja Off',
        ),

        const SizedBox(
          height: 12,
        ),

        _buildDisabledAttendanceButton(
          icon:
              Icons.logout_rounded,

          title:
              'Absen Pulang',

          subtitle:
              'Tidak tersedia karena status kerja Off',
        ),

        const SizedBox(
          height: 14,
        ),

        Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.all(13),

          decoration:
              BoxDecoration(
            color:
                const Color(0xFFF3F4F6),

            borderRadius:
                BorderRadius.circular(13),

            border: Border.all(
              color:
                  const Color(0xFFE5E7EB),
            ),
          ),

          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.block_rounded,
                color:
                    Color(0xFF6B7280),
                size: 19,
              ),

              SizedBox(
                width: 9,
              ),

              Expanded(
                child: Text(
                  'Status kerja Anda saat ini adalah Off. '
                  'Anda tidak dapat melakukan absensi pada hari ini.',

                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DISABLED BUTTON OFF
  // ==========================================================

  Widget _buildDisabledAttendanceButton({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF9CA3AF), size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), height: 1.25)),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: Color(0xFF9CA3AF), size: 19),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS BADGE
  // ==========================================================

  Widget _buildTodayStatusBadge() {
    // OFF SELALU PRIORITAS
    if (isOff) {
      return _badge(
        'OFF',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      );
    }

    if (_isCheckingAttendance) {
      return _badge(
        'Memuat...',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      );
    }

    if (_statusCheckFailed) {
      return _badge(
        'Tidak diketahui',
        const Color(0xFFFEF2F2),
        const Color(0xFFDC2626),
      );
    }

    if (_attendanceNeedsVerification) {
      return _badge(
        'Perlu dicek',
        const Color(0xFFFFF7ED),
        const Color(0xFFD97706),
      );
    }

    if (_hasCheckedOutToday) {
      return _badge(
        'Selesai',
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
      );
    }

    if (_hasCheckedInToday) {
      return _badge(
        'Sudah Masuk',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      );
    }

    return _badge(
      'Belum Absen',
      const Color(0xFFF9FAFB),
      const Color(0xFF6B7280),
    );
  }

  // ==========================================================
  // BADGE
  // ==========================================================

  Widget _badge(
    String text,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            background,

        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Text(
        text,

        style: TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
          color:
              foreground,
        ),
      ),
    );
  }

  // ==========================================================
  // CHECKING
  // ==========================================================

  Widget _buildCheckingStatus() {
    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF9FAFB),

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,

            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
              color:
                  Color(0xFF2563EB),
            ),
          ),

          SizedBox(
            width: 13,
          ),

          Expanded(
            child: Text(
              'Memeriksa status absensi...',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS ERROR
  // ==========================================================

  Widget _buildStatusCheckFailed() {
    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFEF2F2),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              const Color(0xFFFECACA),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.cloud_off_rounded,
                color:
                    Color(0xFFDC2626),
                size: 22,
              ),

              SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  'Status absensi belum dapat diverifikasi.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Tombol absensi dikunci untuk mencegah data ganda. '
            'Periksa koneksi kemudian coba lagi.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color:
                  Color(0xFF7F1D1D),
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          SizedBox(
            height: 44,

            child:
                ElevatedButton.icon(
              onPressed:
                  _isLoading
                      ? null
                      : () =>
                          _loadTodayAttendance(),

              icon: const Icon(
                Icons.refresh_rounded,
                size: 19,
              ),

              label: const Text(
                'Periksa Lagi',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFDC2626),

                foregroundColor:
                    Colors.white,

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // VERIFICATION REQUIRED
  // ==========================================================

  Widget _buildVerificationRequired() {
    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF7ED),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              const Color(0xFFFED7AA),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.warning_amber_rounded,
                color:
                    Color(0xFFD97706),
                size: 23,
              ),

              SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  'Absensi belum dapat dipastikan.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Jangan menekan tombol absensi lagi. '
            'Periksa status server terlebih dahulu '
            'untuk menghindari data absensi ganda.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color:
                  Color(0xFF92400E),
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          SizedBox(
            height: 44,

            child:
                ElevatedButton.icon(
              onPressed:
                  _isLoading
                      ? null
                      : () =>
                          _loadTodayAttendance(),

              icon: const Icon(
                Icons.refresh_rounded,
                size: 19,
              ),

              label: const Text(
                'Cek Status Sekarang',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFD97706),

                foregroundColor:
                    Colors.white,

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ATTENDANCE BUTTON
  // ==========================================================

  Widget _buildAttendanceButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    final bool isPulang = icon == Icons.logout_rounded;
    final bool isCompleted = subtitle == 'Sudah tercatat hari ini';

    final Color accent = isPulang ? const Color(0xFF0F766E) : const Color(0xFF2563EB);
    final Color lightAccent = isPulang ? const Color(0xFFF0FDFA) : const Color(0xFFEFF6FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 82,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, isPulang ? const Color(0xFF115E59) : const Color(0xFF1D4ED8)],
              )
            : null,
        color: enabled ? null : (isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF5F6F8)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? Colors.transparent
              : (isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
        ),
        boxShadow: enabled
            ? [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 8))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: enabled ? Colors.white.withValues(alpha: 0.16) : lightAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Icon(icon, size: 24, color: enabled ? Colors.white : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loading ? 'Memproses...' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: enabled ? Colors.white : (isCompleted ? const Color(0xFF166534) : const Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading ? 'Mohon tunggu, jangan tutup aplikasi' : subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.8,
                          height: 1.25,
                          color: enabled ? Colors.white.withValues(alpha: 0.80) : (isCompleted ? const Color(0xFF4D7C0F) : const Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!loading)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: enabled ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : (enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded),
                      size: isCompleted ? 19 : 15,
                      color: enabled ? Colors.white : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STATUS MESSAGE
  // ==========================================================

  Widget _buildStatusMessage() {
    return Container(
      padding:
          const EdgeInsets.all(13),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF0FDF4),

        borderRadius:
            BorderRadius.circular(13),

        border: Border.all(
          color:
              const Color(0xFFBBF7D0),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 19,
            color:
                Color(0xFF16A34A),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              _statusMessage!,

              style:
                  const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INFO
  // ==========================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOff
              ? const [Color(0xFFF3F4F6), Color(0xFFEFF0F2)]
              : const [Color(0xFFF7FAFF), Color(0xFFEEF5FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOff ? const Color(0xFFE5E7EB) : const Color(0xFFDCE8FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOff ? const Color(0xFFE5E7EB) : Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isOff ? Icons.block_rounded : Icons.verified_user_rounded,
              size: 20,
              color: isOff ? const Color(0xFF6B7280) : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOff ? 'Absensi dinonaktifkan' : 'Catatan keamanan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isOff ? const Color(0xFF6B7280) : const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOff
                      ? 'Status kerja Anda Off. Tombol absensi dinonaktifkan.'
                      : 'Pastikan berada di area perusahaan, GPS aktif, dan foto terlihat jelas. Foto serta lokasi akan disimpan bersama data absensi.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isOff ? const Color(0xFF6B7280) : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FOOTER
  // ==========================================================

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE3EF),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'THANU SMART  •  ABSENSI PKL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '© 2026  •  Sistem Informasi PKL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: Color(0xFFB0B7C3),
          ),
        ),
      ],
    );
  }
}
