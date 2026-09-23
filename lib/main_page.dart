import 'dart:convert';

import 'package:aplikasi_pkl/pages/perizinan_page.dart' as perizinan;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/absensi_page.dart';
import 'pages/history_absensi_page.dart';
import 'pages/menu_bar.dart';

// ============================================================
// API CONFIGURATION
// ============================================================

const String apiUrl =
    'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

// ============================================================
// MAIN PAGE
//
// Pusat session + navigasi aplikasi.
//
// Alur:
//
// MainPage
//   ├── LoginPage
//   └── Aplikasi
//        ├── Dashboard
//        ├── Absensi
//        ├── Perizinan
//        ├── History
//        └── Saku
//
// MenuBarPKL hanya berada di MainPage.
// ============================================================

class MainPage extends StatefulWidget {
  final Map<String, dynamic>? initialUserData;

  const MainPage({
    super.key,
    this.initialUserData,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Map<String, dynamic>? _userData;

  bool _loading = true;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    if (widget.initialUserData != null) {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        widget.initialUserData!,
      );

      if (!mounted) return;

      setState(() {
        _userData = data;
        _currentIndex = 0;
        _loading = false;
      });

      return;
    }

    await _checkLoginSession();
  }

  // ============================================================
  // CHECK LOGIN SESSION
  // ============================================================

  Future<void> _checkLoginSession() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isLoggedIn =
        prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      _showLogin();
      return;
    }

    final String idPKL =
        prefs.getString('id_pkl')?.trim() ?? '';

    if (idPKL.isEmpty) {
      debugPrint(
        'SESSION TIDAK VALID: ID PKL KOSONG',
      );

      await clearLoginSession(prefs);

      _showLogin();
      return;
    }

    final SessionCheckResult session =
        await checkSessionFromServer(idPKL);

    debugPrint(
      '========================================',
    );

    debugPrint('HASIL CHECK SESSION');

    debugPrint(
      'VALID       : ${session.valid}',
    );

    debugPrint(
      'STATUS      : ${session.status}',
    );

    debugPrint(
      'STATUS KERJA: ${session.data?['status_kerja']}',
    );

    debugPrint(
      'ID JADWAL   : ${session.data?['id_jadwal']}',
    );

    debugPrint(
      'SERVER ERROR: ${session.serverError}',
    );

    debugPrint(
      'MESSAGE     : ${session.message}',
    );

    debugPrint(
      '========================================',
    );

    // ==========================================================
    // AKUN SUDAH TIDAK AKTIF
    // ==========================================================

    if (session.accountInvalid) {
      debugPrint(
        'AUTO LOGOUT: AKUN SUDAH TIDAK AKTIF / TIDAK DITEMUKAN',
      );

      await clearLoginSession(prefs);

      _showLogin();
      return;
    }

    // ==========================================================
    // SERVER / INTERNET ERROR
    // ==========================================================

    if (session.serverError) {
      debugPrint(
        'SERVER / INTERNET ERROR.',
      );

      debugPrint(
        'SESSION LOKAL TETAP DIPERTAHANKAN.',
      );

      final Map<String, dynamic> userData =
          getLocalUserData(prefs);

      _showMainApp(userData);
      return;
    }

    // ==========================================================
    // SESSION VALID
    // ==========================================================

    if (session.valid) {
      final String serverStatus =
          session.status.trim();

      if (session.data != null) {
        await saveServerUserData(
          prefs,
          session.data!,
        );
      }

      await prefs.setString(
        'status',
        serverStatus,
      );

      final Map<String, dynamic> userData =
          getLocalUserData(prefs);

      userData['status'] = serverStatus;

      debugPrint(
        '========================================',
      );

      debugPrint('SESSION VALID');
      debugPrint('ID PKL: $idPKL');
      debugPrint('STATUS SERVER: $serverStatus');

      debugPrint(
        'STATUS KERJA: ${userData['status_kerja']}',
      );

      debugPrint(
        'ID JADWAL: ${userData['id_jadwal']}',
      );

      debugPrint('MASUK APLIKASI');

      debugPrint(
        '========================================',
      );

      _showMainApp(userData);
      return;
    }

    // ==========================================================
    // FALLBACK
    // ==========================================================

    debugPrint(
      'CHECK SESSION TIDAK DAPAT MEMASTIKAN STATUS.',
    );

    debugPrint(
      'SESSION LOKAL DIPERTAHANKAN.',
    );

    final Map<String, dynamic> userData =
        getLocalUserData(prefs);

    _showMainApp(userData);
  }

  // ============================================================
  // SHOW LOGIN
  // ============================================================

  void _showLogin() {
    if (!mounted) return;

    setState(() {
      _userData = null;
      _currentIndex = 0;
      _loading = false;
    });
  }

  // ============================================================
  // SHOW MAIN APP
  // ============================================================

  void _showMainApp(
    Map<String, dynamic> userData,
  ) {
    if (!mounted) return;

    setState(() {
      _userData =
          Map<String, dynamic>.from(userData);

      _currentIndex = 0;
      _loading = false;
    });
  }

  // ============================================================
  // MENU TAP
  // ============================================================

  void _onMenuTap(int index) {
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
    });
  }

  // ============================================================
  // BUILD CURRENT PAGE
  // ============================================================

  Widget _buildCurrentPage() {
    final Map<String, dynamic> userData =
        _userData ?? {};

    switch (_currentIndex) {
      // ========================================================
      // HOME
      // ========================================================

      case 0:
        return DashboardPage(
          key: const ValueKey('dashboard'),
          userData: userData,
        );

      // ========================================================
      // ABSENSI
      // ========================================================

      case 1:
        return AbsensiPage(
          key: const ValueKey('absensi'),
          userData: userData,
        );

      // ========================================================
      // PERIZINAN
      // ========================================================

      case 2:
        return perizinan.PerizinanPage(
          key: const ValueKey('perizinan'),
          userData: userData,
        );

      // ========================================================
      // HISTORY
      // ========================================================

      case 3:
        return HistoryAbsensiPage(
          key: const ValueKey('history'),
          idPkl:
              userData['id_pkl']?.toString() ?? '',
          nama:
              userData['nama_siswa']?.toString() ?? '',
        );

      // ========================================================
      // SAKU
      // ========================================================

      case 4:
        return const SakuDevelopmentPage(
          key: ValueKey('saku'),
        );

      // ========================================================
      // DEFAULT
      // ========================================================

      default:
        return DashboardPage(
          key: const ValueKey('dashboard'),
          userData: userData,
        );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ==========================================================
    // LOGIN
    // ==========================================================

    if (_userData == null) {
      return const LoginPage();
    }

    // ==========================================================
    // MAIN APPLICATION
    // ==========================================================

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),

      body: _buildCurrentPage(),

      bottomNavigationBar: MenuBarPKL(
        currentIndex: _currentIndex,
        onTap: _onMenuTap,
      ),
    );
  }
}

// ============================================================
// SAKU - DALAM PENGEMBANGAN
//
// Belum membutuhkan saku_page.dart.
//
// Nanti ketika fitur Saku sudah dibuat, bagian ini tinggal
// diganti menjadi:
//
// return SakuPage(
//   userData: userData,
// );
//
// ============================================================

class SakuDevelopmentPage extends StatelessWidget {
  const SakuDevelopmentPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8FAFC),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                // ==================================================
                // ICON
                // ==================================================

                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius:
                        BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 46,
                    color: Color(0xFF2563EB),
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // TITLE
                // ==================================================

                const Text(
                  'Saku',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // STATUS
                // ==================================================

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFF7ED),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Dalam Pengembangan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                const Text(
                  'Fitur Saku sedang dipersiapkan.\n'
                  'Nantinya halaman ini dapat digunakan '
                  'untuk melihat informasi uang saku PKL.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF6B7280),
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // INFO CARD
                // ==================================================

                Container(
                  width: double.infinity,
                  constraints:
                      const BoxConstraints(
                    maxWidth: 420,
                  ),
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(
                        0xFFE5E7EB,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(
                          alpha: 0.04,
                        ),
                        blurRadius: 14,
                        offset:
                            const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 22,
                        color:
                            Color(0xFF2563EB),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Menu Saku sudah terpasang di '
                          'aplikasi. Fungsinya akan '
                          'ditambahkan pada pembaruan '
                          'berikutnya.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color:
                                Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SESSION CHECK RESULT
// ============================================================

class SessionCheckResult {
  final bool valid;
  final String status;
  final String message;
  final bool accountInvalid;
  final bool serverError;
  final Map<String, dynamic>? data;

  const SessionCheckResult({
    required this.valid,
    required this.status,
    required this.message,
    required this.accountInvalid,
    required this.serverError,
    this.data,
  });
}

// ============================================================
// CHECK SESSION FROM SERVER
// ============================================================

Future<SessionCheckResult> checkSessionFromServer(
  String idPKL,
) async {
  try {
    final Uri uri =
        Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'checkSession',
        'id_pkl': idPKL,
        '_t': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
      },
    );

    debugPrint(
      '========================================',
    );

    debugPrint('CHECK SESSION');
    debugPrint('ID PKL: $idPKL');
    debugPrint('URL: $uri');

    debugPrint(
      '========================================',
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        )
        .timeout(
          const Duration(seconds: 15),
        );

    debugPrint(
      'HTTP STATUS: ${response.statusCode}',
    );

    debugPrint(
      'RESPONSE: ${response.body}',
    );

    // ==========================================================
    // HTTP ERROR
    // ==========================================================

    if (response.statusCode != 200) {
      return const SessionCheckResult(
        valid: false,
        status: '',
        message:
            'Server tidak dapat dihubungi.',
        accountInvalid: false,
        serverError: true,
      );
    }

    final String body =
        response.body.trim();

    // ==========================================================
    // EMPTY RESPONSE
    // ==========================================================

    if (body.isEmpty) {
      return const SessionCheckResult(
        valid: false,
        status: '',
        message:
            'Response server kosong.',
        accountInvalid: false,
        serverError: true,
      );
    }

    // ==========================================================
    // JSON DECODE
    // ==========================================================

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (e) {
      debugPrint(
        'JSON ERROR: $e',
      );

      return const SessionCheckResult(
        valid: false,
        status: '',
        message:
            'Response server bukan JSON yang valid.',
        accountInvalid: false,
        serverError: true,
      );
    }

    // ==========================================================
    // RESPONSE FORMAT
    // ==========================================================

    if (decoded is! Map) {
      return const SessionCheckResult(
        valid: false,
        status: '',
        message:
            'Format response server tidak valid.',
        accountInvalid: false,
        serverError: true,
      );
    }

    final Map<String, dynamic> result =
        Map<String, dynamic>.from(
      decoded,
    );

    // ==========================================================
    // STATUS
    // ==========================================================

    String status =
        result['status']
                ?.toString()
                .trim() ??
            '';

    // ==========================================================
    // SERVER DATA
    // ==========================================================

    Map<String, dynamic>? serverData;

    if (result['data'] is Map) {
      serverData =
          Map<String, dynamic>.from(
        result['data'],
      );

      if (status.isEmpty) {
        status =
            serverData['status']
                    ?.toString()
                    .trim() ??
                '';
      }
    }

    // ==========================================================
    // SUCCESS
    // ==========================================================

    final bool success =
        result['success'] == true;

    final String message =
        result['message']
                ?.toString()
                .trim() ??
            '';

    // ==========================================================
    // SERVER RETURN FALSE
    // ==========================================================

    if (!success) {
      final String lowerMessage =
          message.toLowerCase();

      final String lowerStatus =
          status.toLowerCase();

      final bool akunTidakAktif =
          lowerMessage.contains(
            'tidak aktif',
          ) ||
          lowerStatus == 'nonaktif';

      final bool akunTidakDitemukan =
          lowerMessage.contains(
            'tidak ditemukan',
          ) ||
          lowerMessage.contains(
            'dihapus',
          );

      // ========================================================
      // ACCOUNT INVALID
      // ========================================================

      if (akunTidakAktif ||
          akunTidakDitemukan) {
        return SessionCheckResult(
          valid: false,
          status: status,
          message: message.isNotEmpty
              ? message
              : 'Akun PKL tidak aktif.',
          accountInvalid: true,
          serverError: false,
          data: serverData,
        );
      }

      // ========================================================
      // OTHER SERVER ERROR
      // ========================================================

      return SessionCheckResult(
        valid: false,
        status: status,
        message: message.isNotEmpty
            ? message
            : 'Server gagal memeriksa session.',
        accountInvalid: false,
        serverError: true,
        data: serverData,
      );
    }

    // ==========================================================
    // EMPTY STATUS
    // ==========================================================

    if (status.isEmpty) {
      return const SessionCheckResult(
        valid: false,
        status: '',
        message:
            'Status akun tidak diterima dari server.',
        accountInvalid: false,
        serverError: true,
      );
    }

    // ==========================================================
    // STATUS NOT ACTIVE
    // ==========================================================

    if (status.toLowerCase() != 'aktif') {
      return SessionCheckResult(
        valid: false,
        status: status,
        message:
            'Akun PKL tidak aktif.',
        accountInvalid: true,
        serverError: false,
        data: serverData,
      );
    }

    // ==========================================================
    // VALID
    // ==========================================================

    return SessionCheckResult(
      valid: true,
      status: status,
      message: message.isNotEmpty
          ? message
          : 'Session masih aktif.',
      accountInvalid: false,
      serverError: false,
      data: serverData,
    );
  }

  // ============================================================
  // HTTP CLIENT ERROR
  // ============================================================

  on http.ClientException catch (e) {
    debugPrint(
      'HTTP CLIENT ERROR: $e',
    );

    return const SessionCheckResult(
      valid: false,
      status: '',
      message:
          'Tidak dapat terhubung ke server.',
      accountInvalid: false,
      serverError: true,
    );
  }

  // ============================================================
  // GENERAL ERROR
  // ============================================================

  catch (e) {
    debugPrint(
      'CHECK SESSION ERROR: $e',
    );

    return const SessionCheckResult(
      valid: false,
      status: '',
      message:
          'Gagal memeriksa session ke server.',
      accountInvalid: false,
      serverError: true,
    );
  }
}

// ============================================================
// GET LOCAL USER DATA
// ============================================================

Map<String, dynamic> getLocalUserData(
  SharedPreferences prefs,
) {
  return {
    'id_pkl':
        prefs.getString('id_pkl') ?? '',

    'nama_siswa':
        prefs.getString('nama_siswa') ?? '',

    'asal_sekolah':
        prefs.getString('asal_sekolah') ?? '',

    'jurusan':
        prefs.getString('jurusan') ?? '',

    'jenis_kelamin':
        prefs.getString('jenis_kelamin') ?? '',

    'kelas':
        prefs.getString('kelas') ?? '',

    'divisi':
        prefs.getString('divisi') ?? '',

    'bagian':
        prefs.getString('bagian') ?? '',

    'date_join':
        prefs.getString('date_join') ?? '',

    'foto':
        prefs.getString('foto') ?? '',

    'status':
        prefs.getString('status') ?? '',

    'email':
        prefs.getString('email') ?? '',

    'status_kerja':
        prefs.getString('status_kerja') ?? '',

    'id_jadwal':
        prefs.getString('id_jadwal') ?? '',
  };
}

// ============================================================
// SAVE SERVER USER DATA
// ============================================================

Future<void> saveServerUserData(
  SharedPreferences prefs,
  Map<String, dynamic> data,
) async {
  Future<void> saveString(
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      return;
    }

    final String text =
        value.toString().trim();

    if (text.isEmpty) {
      return;
    }

    await prefs.setString(
      key,
      text,
    );
  }

  await saveString(
    'id_pkl',
    data['id_pkl'],
  );

  await saveString(
    'nama_siswa',
    data['nama_siswa'],
  );

  await saveString(
    'asal_sekolah',
    data['asal_sekolah'],
  );

  await saveString(
    'jurusan',
    data['jurusan'],
  );

  await saveString(
    'jenis_kelamin',
    data['jenis_kelamin'],
  );

  await saveString(
    'kelas',
    data['kelas'],
  );

  await saveString(
    'divisi',
    data['divisi'],
  );

  await saveString(
    'bagian',
    data['bagian'],
  );

  await saveString(
    'date_join',
    data['date_join'],
  );

  await saveString(
    'foto',
    data['foto'],
  );

  await saveString(
    'email',
    data['email'],
  );

  await saveString(
    'status',
    data['status'],
  );

  await saveString(
    'status_kerja',
    data['status_kerja'],
  );

  await saveString(
    'id_jadwal',
    data['id_jadwal'],
  );
}

// ============================================================
// CLEAR LOGIN SESSION
// ============================================================

Future<void> clearLoginSession(
  SharedPreferences prefs,
) async {
  try {
    await prefs.remove(
      'isLoggedIn',
    );

    await prefs.remove(
      'id_pkl',
    );

    await prefs.remove(
      'nama_siswa',
    );

    await prefs.remove(
      'asal_sekolah',
    );

    await prefs.remove(
      'jurusan',
    );

    await prefs.remove(
      'jenis_kelamin',
    );

    await prefs.remove(
      'kelas',
    );

    await prefs.remove(
      'divisi',
    );

    await prefs.remove(
      'bagian',
    );

    await prefs.remove(
      'date_join',
    );

    await prefs.remove(
      'foto',
    );

    await prefs.remove(
      'status',
    );

    await prefs.remove(
      'email',
    );

    await prefs.remove(
      'status_kerja',
    );

    await prefs.remove(
      'id_jadwal',
    );

    debugPrint(
      'SESSION LOGIN DIHAPUS.',
    );
  } catch (e) {
    debugPrint(
      'Gagal menghapus session: $e',
    );
  }
}