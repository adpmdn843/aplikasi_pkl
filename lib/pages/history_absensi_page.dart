// ignore_for_file: unused_local_variable

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HistoryAbsensiPage extends StatefulWidget {
  final String idPkl;
  final String nama;

  const HistoryAbsensiPage({
    super.key,
    required this.idPkl,
    required this.nama,
  });

  @override
  State<HistoryAbsensiPage> createState() =>
      _HistoryAbsensiPageState();
}

class _HistoryAbsensiPageState
    extends State<HistoryAbsensiPage> {
  // ============================================================
  // API
  // ============================================================

  static const String apiUrl =
      'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _history = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        '$apiUrl?action=riwayatAbsensi'
        '&id_pkl=${Uri.encodeComponent(widget.idPkl)}',
      );

      debugPrint('==========================================');
      debugPrint('HISTORY ABSENSI');
      debugPrint('ID PKL : ${widget.idPkl}');
      debugPrint('URL    : $uri');

      final response = await http.get(uri);

      debugPrint('STATUS : ${response.statusCode}');
      debugPrint('BODY   : ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Server mengembalikan status ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Format response server tidak valid.',
        );
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Gagal mengambil riwayat absensi.',
        );
      }

      final dynamic rawData = decoded['data'];

      final List<Map<String, dynamic>> history = [];

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) {
            history.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      // ==========================================================
      // URUTKAN TANGGAL TERBARU
      // ==========================================================

      history.sort((a, b) {
        final dateA = _parseDate(
          a['tanggal']?.toString(),
        );

        final dateB = _parseDate(
          b['tanggal']?.toString(),
        );

        if (dateA == null && dateB == null) {
          return 0;
        }

        if (dateA == null) {
          return 1;
        }

        if (dateB == null) {
          return -1;
        }

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR HISTORY: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final text = value.trim();

    final isoMatch = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})',
    ).firstMatch(text);

    if (isoMatch != null) {
      return DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
      );
    }

    final slashMatch = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})',
    ).firstMatch(text);

    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(3)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(1)!),
      );
    }

    final dashMatch = RegExp(
      r'^(\d{1,2})-(\d{1,2})-(\d{4})',
    ).firstMatch(text);

    if (dashMatch != null) {
      return DateTime(
        int.parse(dashMatch.group(3)!),
        int.parse(dashMatch.group(2)!),
        int.parse(dashMatch.group(1)!),
      );
    }

    return DateTime.tryParse(text);
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(String? value) {
    final date = _parseDate(value);

    if (date == null) {
      return value ?? '-';
    }

    const months = [
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
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty ||
        text == 'null' ||
        text == '-') {
      return '-';
    }

    if (RegExp(
      r'^\d{1,2}:\d{2}$',
    ).hasMatch(text)) {
      final parts = text.split(':');

      return '${parts[0].padLeft(2, '0')}:'
          '${parts[1]}';
    }

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?',
    ).firstMatch(text);

    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:'
          '${match.group(2)}';
    }

    return text;
  }

  // ============================================================
  // TELAT
  // ============================================================

  String _getTelat(Map<String, dynamic> item) {
    dynamic value;

    if (item.containsKey('Telat')) {
      value = item['Telat'];
    } else if (item.containsKey('telat')) {
      value = item['telat'];
    }

    if (value == null) {
      return '00:00';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '00:00';
    }

    if (text == '0' ||
        text == '0:00' ||
        text == '00:00' ||
        text == '0:00:00' ||
        text == '00:00:00') {
      return '00:00';
    }

    final formatted = _formatTime(text);

    if (formatted == '-') {
      return '00:00';
    }

    return formatted;
  }

  // ============================================================
  // CEK JAM MASUK
  //
  // PENTING:
  // Fungsi ini TIDAK memanggil _isAlfa()
  // agar tidak terjadi recursive loop / Stack Overflow.
  // ============================================================

  bool _hasMasuk(Map<String, dynamic> item) {
    final serverStatus =
        item['status']?.toString().trim().toLowerCase() ?? '';

    // Alfa otomatis memiliki 00:00.
    if (serverStatus == 'alfa') {
      return false;
    }

    final jamMasuk =
        item['jam_masuk']?.toString().trim() ?? '';

    if (jamMasuk.isEmpty ||
        jamMasuk == '-' ||
        jamMasuk == 'null' ||
        jamMasuk == '0:00' ||
        jamMasuk == '00:00' ||
        jamMasuk == '0:00:00' ||
        jamMasuk == '00:00:00') {
      return false;
    }

    return true;
  }

  // ============================================================
  // CEK JAM PULANG
  //
  // PENTING:
  // Fungsi ini langsung membaca jam_pulang.
  // Tidak memanggil _isAlfa(), _getStatus(), atau fungsi
  // status lainnya.
  //
  // Ini yang menentukan:
  //
  // Hadir + jam pulang ada    = Hadir
  // Hadir + jam pulang kosong = Kurang
  // ============================================================

  bool _hasPulang(Map<String, dynamic> item) {
    final serverStatus =
        item['status']?.toString().trim().toLowerCase() ?? '';

    // Alfa otomatis memiliki 00:00.
    if (serverStatus == 'alfa') {
      return false;
    }

    final jamPulang =
        item['jam_pulang']?.toString().trim() ?? '';

    if (jamPulang.isEmpty ||
        jamPulang == '-' ||
        jamPulang == 'null' ||
        jamPulang == '0:00' ||
        jamPulang == '00:00' ||
        jamPulang == '0:00:00' ||
        jamPulang == '00:00:00') {
      return false;
    }

    return true;
  }

  // ============================================================
  // STATUS TAMPILAN
  //
  // STATUS ASLI SERVER TIDAK DIUBAH.
  //
  // Kalau:
  // server = Hadir
  // jam_pulang = kosong / 00:00
  //
  // Flutter menampilkan:
  // Kurang
  //
  // "Kurang" hanya status tampilan di Flutter.
  // ============================================================

  String _getStatus(Map<String, dynamic> item) {
    final serverStatus =
        item['status']?.toString().trim() ?? '';

    if (serverStatus.isEmpty) {
      return '-';
    }

    final normalized =
        serverStatus.toLowerCase();

    // ==========================================================
    // HADIR + TIDAK ADA JAM PULANG = KURANG
    // ==========================================================

    if (normalized == 'hadir') {
      if (!_hasPulang(item)) {
        return 'Kurang';
      }

      return 'Hadir';
    }

    // ==========================================================
    // STATUS LAIN TETAP MENGIKUTI SERVER
    // ==========================================================

    return serverStatus;
  }

  // ============================================================
  // NORMALIZED STATUS
  // ============================================================

  String _normalizedStatus(
    Map<String, dynamic> item,
  ) {
    return _getStatus(item)
        .trim()
        .toLowerCase();
  }

  // ============================================================
  // STATUS CHECK
  // ============================================================

  bool _isHadir(Map<String, dynamic> item) {
    return _normalizedStatus(item) == 'hadir';
  }

  bool _isKurang(Map<String, dynamic> item) {
    return _normalizedStatus(item) == 'kurang';
  }

  bool _isAlfa(Map<String, dynamic> item) {
    // Langsung cek status asli server.
    // Jangan menggunakan _normalizedStatus()
    // agar tidak membuat hubungan berulang.

    final status =
        item['status']?.toString().trim().toLowerCase() ?? '';

    return status == 'alfa';
  }

  bool _isIzin(Map<String, dynamic> item) {
    final status =
        item['status']?.toString().trim().toLowerCase() ?? '';

    return status == 'izin';
  }

  bool _isSakit(Map<String, dynamic> item) {
    final status =
        item['status']?.toString().trim().toLowerCase() ?? '';

    return status == 'sakit';
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    Map<String, dynamic> item,
  ) {
    final status = _normalizedStatus(item);

    if (status == 'hadir') {
      return const Color(0xFF16A34A);
    }

    if (status == 'kurang') {
      return const Color(0xFFF59E0B);
    }

    if (status == 'alfa') {
      return const Color(0xFFDC2626);
    }

    if (status == 'izin') {
      return const Color(0xFF2563EB);
    }

    if (status == 'sakit') {
      return const Color(0xFF7C3AED);
    }

    return const Color(0xFF6B7280);
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(
    Map<String, dynamic> item,
  ) {
    final status = _normalizedStatus(item);

    if (status == 'hadir') {
      return Icons.check_circle_rounded;
    }

    if (status == 'kurang') {
      return Icons.warning_rounded;
    }

    if (status == 'alfa') {
      return Icons.cancel_rounded;
    }

    if (status == 'izin') {
      return Icons.assignment_turned_in_rounded;
    }

    if (status == 'sakit') {
      return Icons.health_and_safety_rounded;
    }

    return Icons.info_rounded;
  }

  // ============================================================
  // STATISTIK
  // ============================================================

  int get _jumlahHadir {
    return _history.where(
      (item) => _isHadir(item),
    ).length;
  }

  int get _jumlahKurang {
    return _history.where(
      (item) => _isKurang(item),
    ).length;
  }

  int get _jumlahIzinSakit {
    return _history.where(
      (item) =>
          _isIzin(item) ||
          _isSakit(item),
    ).length;
  }

  // ============================================================
  // SHOW DETAIL
  // ============================================================

  void _showDetail(
    Map<String, dynamic> item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildDetailSheet(item);
      },
    );
  }

  // ============================================================
  // DETAIL SHEET
  // ============================================================

  Widget _buildDetailSheet(
    Map<String, dynamic> item,
  ) {
    final masuk = _hasMasuk(item);
    final pulang = _hasPulang(item);

    final status = _getStatus(item);
    final statusColor = _statusColor(item);

    final isHadir = _isHadir(item);
    final isKurang = _isKurang(item);
    final isAlfa = _isAlfa(item);
    final isIzin = _isIzin(item);
    final isSakit = _isSakit(item);

    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // HANDLE
              // ==================================================

              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          statusColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _statusIcon(item),
                      color: statusColor,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Absensi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(
                            item['tanggal']
                                ?.toString(),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color:
                                Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildStatusBadge(item),
                ],
              ),

              const SizedBox(height: 24),

              // ==================================================
              // STATUS
              // ==================================================

              _buildAttendanceSummary(item),

              const SizedBox(height: 14),

              // ==================================================
              // ABSEN MASUK
              // ==================================================

              if ((isHadir || isKurang) &&
                  masuk) ...[
                _buildEventCard(
                  title: 'Absen Masuk',
                  icon: Icons.login_rounded,
                  time: _formatTime(
                    item['jam_masuk'],
                  ),
                  photo: item['foto_masuk'],
                ),
                const SizedBox(height: 14),
              ],

              // ==================================================
              // ABSEN PULANG
              // ==================================================

              if ((isHadir || isKurang) &&
                  pulang) ...[
                _buildEventCard(
                  title: 'Absen Pulang',
                  icon: Icons.logout_rounded,
                  time: _formatTime(
                    item['jam_pulang'],
                  ),
                  photo: item['foto_pulang'],
                ),
                const SizedBox(height: 14),
              ],

              // ==================================================
              // HADIR / KURANG DATA BELUM LENGKAP
              // ==================================================

              if ((isHadir || isKurang) &&
                  masuk != pulang) ...[
                _buildMissingAttendance(
                  masuk: masuk,
                  pulang: pulang,
                ),
                const SizedBox(height: 14),
              ],

              // ==================================================
              // ALFA
              // ==================================================

              if (isAlfa)
                _buildInfoSection(
                  'Keterangan',
                  _getKeterangan(
                    item,
                    fallback:
                        'Tidak melakukan absensi.',
                  ),
                  Icons.event_busy_rounded,
                ),

              // ==================================================
              // IZIN
              // ==================================================

              if (isIzin)
                _buildInfoSection(
                  'Keterangan Izin',
                  _getKeterangan(
                    item,
                    fallback:
                        'Tidak ada keterangan izin.',
                  ),
                  Icons.assignment_turned_in_rounded,
                ),

              // ==================================================
              // SAKIT
              // ==================================================

              if (isSakit)
                _buildInfoSection(
                  'Keterangan Sakit',
                  _getKeterangan(
                    item,
                    fallback:
                        'Tidak ada keterangan sakit.',
                  ),
                  Icons.health_and_safety_rounded,
                ),

              // ==================================================
              // KETERANGAN TAMBAHAN
              // ==================================================

              if (!isAlfa &&
                  !isIzin &&
                  !isSakit &&
                  (item['keterangan'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoSection(
                  'Keterangan',
                  item['keterangan']
                      .toString(),
                  Icons.notes_rounded,
                ),
              ],

              const SizedBox(height: 20),

              // ==================================================
              // TUTUP
              // ==================================================

              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFF374151),
                    side: const BorderSide(
                      color:
                          Color(0xFFE5E7EB),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KETERANGAN
  // ============================================================

  String _getKeterangan(
    Map<String, dynamic> item, {
    required String fallback,
  }) {
    final value =
        item['keterangan']?.toString().trim() ?? '';

    if (value.isEmpty) {
      return fallback;
    }

    return value;
  }

  // ============================================================
  // ATTENDANCE SUMMARY
  // ============================================================

  Widget _buildAttendanceSummary(
    Map<String, dynamic> item,
  ) {
    final status = _getStatus(item);
    final color = _statusColor(item);
    final telat = _getTelat(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(item),
              color: color,
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Absensi',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              const Text(
                'Telat',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                telat,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  color: telat == '00:00'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EVENT CARD
  // ============================================================

  Widget _buildEventCard({
    required String title,
    required IconData icon,
    required String time,
    dynamic photo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(0xFF2563EB),
                  size: 20,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xFF111827),
                  ),
                ),
              ),

              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF2563EB),
                ),
              ),
            ],
          ),

          if (photo != null &&
              photo.toString().trim().isNotEmpty &&
              photo.toString().trim() !=
                  'Foto sedang diproses') ...[
            const SizedBox(height: 14),
            _buildPhotoPreview(
              photo.toString(),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MISSING ATTENDANCE
  // ============================================================

  Widget _buildMissingAttendance({
    required bool masuk,
    required bool pulang,
  }) {
    final String message;

    if (!masuk && pulang) {
      message = 'Jam masuk tidak tercatat.';
    } else if (masuk && !pulang) {
      message = 'Jam pulang belum tercatat.';
    } else {
      message = 'Data absensi belum lengkap.';
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHOTO
  // ============================================================

  Widget _buildPhotoPreview(
    String fileId,
  ) {
    final imageUrl =
        'https://drive.google.com/thumbnail?id='
        '${Uri.encodeComponent(fileId)}&sz=w800';

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        height: 190,
        width: double.infinity,
        color:
            const Color(0xFFE5E7EB),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons
                        .image_not_supported_outlined,
                    size: 32,
                    color:
                        Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Foto tidak dapat ditampilkan',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(
    Map<String, dynamic> item,
  ) {
    final color = _statusColor(item);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _getStatus(item),
        style: TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // INFO SECTION
  // ============================================================

  Widget _buildInfoSection(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color:
                const Color(0xFF6B7280),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _buildHistoryCard(
    Map<String, dynamic> item,
  ) {
    final masuk = _hasMasuk(item);
    final pulang = _hasPulang(item);

    final status = _getStatus(item);
    final statusColor = _statusColor(item);

    return InkWell(
      borderRadius:
          BorderRadius.circular(22),
      onTap: () =>
          _showDetail(item),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
          border: Border.all(
            color:
                const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.06,
              ),
              blurRadius: 20,
              offset:
                  const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color:
                        statusColor
                            .withValues(
                      alpha: 0.11,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(15),
                  ),
                  child: Icon(
                    _statusIcon(item),
                    color:
                        statusColor,
                    size: 25,
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
                      Text(
                        _formatDate(
                          item['tanggal']
                              ?.toString(),
                        ),
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(0xFF111827),
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              statusColor
                                  .withValues(
                            alpha: 0.09,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(20),
                        ),
                        child: Text(
                          status,
                          style:
                              TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Color(0xFF9CA3AF),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            const Divider(
              height: 1,
              color:
                  Color(0xFFF0F1F3),
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // JAM MASUK / PULANG
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                      _buildTimeInfo(
                    icon:
                        Icons.login_rounded,
                    title:
                        'Masuk',
                    value:
                        _formatTime(
                      item[
                          'jam_masuk'],
                    ),
                    active:
                        masuk,
                  ),
                ),

                Container(
                  width: 1,
                  height: 36,
                  color:
                      const Color(
                    0xFFE5E7EB,
                  ),
                ),

                Expanded(
                  child:
                      _buildTimeInfo(
                    icon:
                        Icons.logout_rounded,
                    title:
                        'Pulang',
                    value:
                        _formatTime(
                      item[
                          'jam_pulang'],
                    ),
                    active:
                        pulang,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // TELAT
            // ==================================================

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFFF9FAFB,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 17,
                    color:
                        Color(0xFF6B7280),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  const Expanded(
                    child: Text(
                      'Telat',
                      style:
                          TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Text(
                    _getTelat(item),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          _getTelat(item) ==
                                  '00:00'
                              ? const Color(
                                  0xFF16A34A,
                                )
                              : const Color(
                                  0xFFF59E0B,
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIME INFO
  // ============================================================

  Widget _buildTimeInfo({
    required IconData icon,
    required String title,
    required String value,
    required bool active,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: active
              ? const Color(0xFF2563EB)
              : const Color(0xFFD1D5DB),
        ),

        const SizedBox(
          width: 8,
        ),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 11,
                color:
                    Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
                color: active
                    ? const Color(
                        0xFF374151,
                      )
                    : const Color(
                        0xFF9CA3AF,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white
              .withValues(alpha: 0.12),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white
                .withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER HISTORY
  // ============================================================

  Widget _buildHistoryHeader() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF2563EB)
                    .withValues(
              alpha: 0.20,
            ),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  border: Border.all(
                    color: Colors.white
                        .withValues(
                      alpha: 0.16,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Absensi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.nama.trim().isEmpty
                          ? widget.idPkl
                          : widget.nama,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.white70,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            '${_history.length} data absensi tercatat',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          // ==================================================
          // STATISTIK
          // ==================================================

          Row(
            children: [
              _buildStatCard(
                title: 'Hadir',
                value: _jumlahHadir,
                icon:
                    Icons.check_circle_rounded,
                color:
                    const Color(0xFF22C55E),
              ),

              const SizedBox(width: 8),

              _buildStatCard(
                title: 'Kurang',
                value: _jumlahKurang,
                icon:
                    Icons.warning_rounded,
                color:
                    const Color(0xFFF59E0B),
              ),

              const SizedBox(width: 8),

              _buildStatCard(
                title: 'Izin / Sakit',
                value: _jumlahIzinSakit,
                icon:
                    Icons.assignment_rounded,
                color:
                    const Color(0xFF60A5FA),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFEFF6FF),
                borderRadius:
                    BorderRadius.circular(
                  28,
                ),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 44,
                color:
                    Color(0xFF2563EB),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Belum Ada Riwayat',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color:
                    Color(0xFF111827),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Riwayat absensi kamu akan muncul di sini setelah melakukan absensi.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color:
                    Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFFEF2F2),
                borderRadius:
                    BorderRadius.circular(
                  25,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color:
                    Color(0xFFDC2626),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Gagal Memuat Riwayat',
              style: TextStyle(
                fontSize: 19,
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
              _errorMessage ??
                  'Terjadi kesalahan.',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color:
                    Color(0xFF6B7280),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            SizedBox(
              height: 46,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _loadHistory,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Coba Lagi',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF2563EB,
                  ),
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 20,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(

      body: RefreshIndicator(
        onRefresh: _loadHistory,

        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height:
                            MediaQuery.of(context)
                                    .size
                                    .height *
                                0.28,
                      ),
                      _buildErrorState(),
                    ],
                  )
                : _history.isEmpty
                    ? ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height:
                                MediaQuery.of(context)
                                        .size
                                        .height *
                                    0.28,
                          ),
                          _buildEmptyState(),
                        ],
                      )
                    : ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          18,
                          18,
                          30,
                        ),
                        children: [
                          // ==================================================
                          // HEADER
                          // ==================================================

                          _buildHistoryHeader(),

                          const SizedBox(
                            height: 22,
                          ),

                          // ==================================================
                          // JUDUL
                          // ==================================================

                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Daftar Absensi',
                                  style:
                                      TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color:
                                        Color(
                                      0xFF111827,
                                    ),
                                  ),
                                ),
                              ),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFEFF6FF,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child: Text(
                                  '${_history.length} Hari',
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    color:
                                        Color(
                                      0xFF2563EB,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // HISTORY
                          // ==================================================

                          ..._history.map(
                            _buildHistoryCard,
                          ),
                        ],
                      ),
      ),
    );
  }
}