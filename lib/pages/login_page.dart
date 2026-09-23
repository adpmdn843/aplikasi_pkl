import 'dart:convert';

import 'package:aplikasi_pkl/pages/about_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ==========================================================
  // CONTROLLER
  // ==========================================================

  final TextEditingController _idController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  // ==========================================================
  // STATE
  // ==========================================================

  bool _isLoading = false;

  bool _obscurePassword = true;

  // ==========================================================
  // URL API GOOGLE APPS SCRIPT
  // ==========================================================

  static const String apiUrl =
      'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ==========================================================
  // HAPUS SESSION LOGIN
  // ==========================================================

  Future<void> _clearLoginSession() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('isLoggedIn');
    await prefs.remove('id_pkl');
    await prefs.remove('nama_siswa');
    await prefs.remove('asal_sekolah');
    await prefs.remove('jurusan');
    await prefs.remove('jenis_kelamin');
    await prefs.remove('kelas');
    await prefs.remove('divisi');
    await prefs.remove('bagian');
    await prefs.remove('date_join');
    await prefs.remove('foto');
    await prefs.remove('status');
    await prefs.remove('email');
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<void> _login() async {
    final String idPKL =
        _idController.text.trim();

    final String password =
        _passwordController.text.trim();

    // ========================================================
    // VALIDASI ID
    // ========================================================

    if (idPKL.isEmpty) {
      _showMessage(
        'ID PKL wajib diisi.',
      );

      return;
    }

    // ========================================================
    // VALIDASI PASSWORD
    // ========================================================

    if (password.isEmpty) {
      _showMessage(
        'Password wajib diisi.',
      );

      return;
    }

    // ========================================================
    // LOADING
    // ========================================================

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // ======================================================
      // AMBIL PREFERENCES
      // ======================================================

      final prefs =
          await SharedPreferences.getInstance();

      // ======================================================
      // HAPUS SESSION LAMA
      // ======================================================

      await _clearLoginSession();

      // ======================================================
      // REQUEST LOGIN
      // ======================================================

      final Uri url =
          Uri.parse(apiUrl).replace(
        queryParameters: {
          'action': 'login',
          'id_pkl': idPKL,
          'password': password,
          '_t': DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
        },
      );

      // ======================================================
      // DEBUG
      // ======================================================

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LOGIN REQUEST',
      );

      debugPrint(
        'ID PKL: $idPKL',
      );

      debugPrint(
        'URL: $url',
      );

      debugPrint(
        '================================================',
      );

      // ======================================================
      // REQUEST KE GOOGLE APPS SCRIPT
      // ======================================================

      final response = await http
          .get(
            url,
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(
              seconds: 15,
            ),
          );

      // ======================================================
      // DEBUG RESPONSE
      // ======================================================

      debugPrint(
        'LOGIN STATUS CODE: ${response.statusCode}',
      );

      debugPrint(
        'LOGIN RESPONSE: ${response.body}',
      );

      // ======================================================
      // CEK HTTP STATUS
      // ======================================================

      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          _showMessage(
            'HTTP 404: URL Google Apps Script tidak ditemukan.',
          );
        } else {
          _showMessage(
            'Server tidak dapat dihubungi. '
            'Kode: ${response.statusCode}',
          );
        }

        return;
      }

      // ======================================================
      // RESPONSE KOSONG
      // ======================================================

      final String responseBody =
          response.body.trim();

      if (responseBody.isEmpty) {
        _showMessage(
          'Server memberikan data kosong.',
        );

        return;
      }

      // ======================================================
      // CEK RESPONSE HTML
      // ======================================================

      if (responseBody.startsWith(
            '<!DOCTYPE',
          ) ||
          responseBody.startsWith(
            '<html',
          ) ||
          responseBody.startsWith(
            '<HTML',
          )) {
        debugPrint(
          'LOGIN ERROR: Server mengembalikan HTML.',
        );

        _showMessage(
          'Server mengembalikan halaman yang tidak valid.',
        );

        return;
      }

      // ======================================================
      // PARSE JSON
      // ======================================================

      final dynamic decoded =
          jsonDecode(responseBody);

      if (decoded is! Map) {
        _showMessage(
          'Format data dari server tidak valid.',
        );

        return;
      }

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(
        decoded,
      );

      // ======================================================
      // DEBUG HASIL SERVER
      // ======================================================

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LOGIN RESULT',
      );

      debugPrint(
        'SUCCESS : ${result['success']}',
      );

      debugPrint(
        'MESSAGE : ${result['message']}',
      );

      debugPrint(
        'STATUS  : ${result['status']}',
      );

      debugPrint(
        '================================================',
      );

      // ======================================================
      // CEK SUCCESS
      // ======================================================

      if (result['success'] != true) {
        final dynamic rawMessage =
            result['message'];

        final String message =
            rawMessage != null &&
                    rawMessage
                        .toString()
                        .trim()
                        .isNotEmpty
                ? rawMessage
                    .toString()
                    .trim()
                : 'Login gagal.';

        _showMessage(
          message,
        );

        return;
      }

      // ======================================================
      // AMBIL DATA USER
      // ======================================================

      final dynamic rawData =
          result['data'];

      if (rawData is! Map) {
        _showMessage(
          'Data akun dari server tidak valid.',
        );

        return;
      }

      final Map<String, dynamic> userData =
          Map<String, dynamic>.from(
        rawData,
      );

      // ======================================================
      // CEK ID PKL DARI SERVER
      // ======================================================

      final String serverIdPKL =
          userData['id_pkl']
                  ?.toString()
                  .trim() ??
              '';

      if (serverIdPKL.isEmpty) {
        _showMessage(
          'ID PKL dari server tidak ditemukan.',
        );

        return;
      }

      // ======================================================
      // CEK STATUS DARI SERVER
      // ======================================================

      final String serverStatus =
          userData['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      debugPrint(
        '================================================',
      );

      debugPrint(
        'CEK STATUS LOGIN',
      );

      debugPrint(
        'ID SERVER : $serverIdPKL',
      );

      debugPrint(
        'STATUS    : $serverStatus',
      );

      debugPrint(
        '================================================',
      );

      // ======================================================
      // STATUS HARUS AKTIF
      // ======================================================

      if (serverStatus != 'aktif') {
        await _clearLoginSession();

        _showMessage(
          'Akun PKL tidak aktif.',
        );

        return;
      }

      // ======================================================
      // CEK ID SERVER VS ID INPUT
      // ======================================================

      if (serverIdPKL.toUpperCase() !=
          idPKL.toUpperCase()) {
        await _clearLoginSession();

        _showMessage(
          'Data akun tidak sesuai.',
        );

        return;
      }

      // ======================================================
      // SIMPAN SESSION
      // ======================================================

      await prefs.setBool(
        'isLoggedIn',
        true,
      );

      await prefs.setString(
        'id_pkl',
        serverIdPKL,
      );

      await prefs.setString(
        'nama_siswa',
        userData['nama_siswa']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'asal_sekolah',
        userData['asal_sekolah']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'jurusan',
        userData['jurusan']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'jenis_kelamin',
        userData['jenis_kelamin']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'kelas',
        userData['kelas']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'divisi',
        userData['divisi']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'bagian',
        userData['bagian']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'date_join',
        userData['date_join']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'foto',
        userData['foto']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'status',
        'Aktif',
      );

      await prefs.setString(
        'email',
        userData['email']
                ?.toString() ??
            '',
      );

      // ======================================================
      // CEK WIDGET
      // ======================================================

      if (!mounted) {
        return;
      }

      // ======================================================
      // DEBUG LOGIN BERHASIL
      // ======================================================

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LOGIN BERHASIL',
      );

      debugPrint(
        'ID      : $serverIdPKL',
      );

      debugPrint(
        'NAMA    : ${userData['nama_siswa']}',
      );

      debugPrint(
        'STATUS  : ${userData['status']}',
      );

      debugPrint(
        '================================================',
      );

      // ======================================================
      // MASUK KEMBALI KE MAIN PAGE
      //
      // MainPage akan menerima userData ini sehingga tidak
      // perlu checkSession ke server untuk kedua kalinya.
      // ======================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainPage(
            initialUserData: userData,
          ),
        ),
      );
    }

    // ========================================================
    // ERROR JSON
    // ========================================================

    on FormatException catch (e) {
      debugPrint(
        'LOGIN JSON ERROR: $e',
      );

      _showMessage(
        'Data dari server tidak dapat dibaca.',
      );
    }

    // ========================================================
    // ERROR LAIN
    // ========================================================

    catch (e) {
      debugPrint(
        'LOGIN ERROR: $e',
      );

      _showMessage(
        'Terjadi kesalahan koneksi.',
      );
    }

    // ========================================================
    // STOP LOADING
    // ========================================================

    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // SHOW MESSAGE
  // ==========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          behavior:
              SnackBarBehavior.floating,

          margin:
              const EdgeInsets.all(18),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),

          duration:
              const Duration(
            seconds: 3,
          ),
        ),
      );
  }

  // ==========================================================
  // BUKA ABOUT PAGE
  // ==========================================================

  void _openAboutPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const AboutPage(),
      ),
    );
  }

  // ==========================================================
  // DECORATIVE CIRCLE
  // ==========================================================

  Widget _buildDecorativeCircle({
    required double size,
    required double opacity,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2563EB)
              .withValues(
            alpha: opacity,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LOGO
  // ==========================================================

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding:
              const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.08,
                ),
                blurRadius: 25,
                offset:
                    const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/Logo.jpg',
              fit: BoxFit.contain,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const Icon(
                  Icons
                      .image_not_supported_outlined,
                  size: 40,
                  color:
                      Color(0xFF9CA3AF),
                );
              },
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        const Text(
          'Satu Garis',
          style: TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.7,
            color:
                Color(0xFF111827),
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        const Text(
          'Sistem Absensi PKL',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight:
                FontWeight.w500,
            letterSpacing: 0.2,
            color:
                Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // INPUT FIELD
  // ==========================================================

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController
        controller,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction?
        textInputAction,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight:
                FontWeight.w700,
            color:
                Color(0xFF374151),
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        TextField(
          controller: controller,
          obscureText:
              obscureText,
          textInputAction:
              textInputAction,
          textCapitalization:
              textCapitalization,
          onSubmitted:
              onSubmitted == null
                  ? null
                  : (_) =>
                      onSubmitted(),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight:
                FontWeight.w500,
            color:
                Color(0xFF111827),
          ),
          cursorColor:
              const Color(0xFF2563EB),
          decoration:
              InputDecoration(
            hintText: hint,

            hintStyle:
                const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w400,
              color:
                  Color(0xFF9CA3AF),
            ),

            prefixIcon:
                Icon(
              icon,
              size: 21,
              color:
                  const Color(
                0xFF6B7280,
              ),
            ),

            suffixIcon:
                suffixIcon,

            filled: true,

            fillColor:
                const Color(
              0xFFF8FAFC,
            ),

            contentPadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 16,
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFFE5E7EB),
                width: 1,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFF2563EB),
                width: 1.5,
              ),
            ),

            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFFE5E7EB),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // LOGIN CARD
  // ==========================================================

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              const Color(0xFFEFF2F7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.07,
            ),
            blurRadius: 35,
            offset:
                const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Selamat Datang 👋',
            style: TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.3,
              color:
                  Color(0xFF111827),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Masuk menggunakan akun PKL kamu untuk melanjutkan.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color:
                  Color(0xFF6B7280),
            ),
          ),

          const SizedBox(
            height: 26,
          ),

          _buildInputField(
            label: 'ID PKL',
            hint: 'Contoh: PKL001',
            controller:
                _idController,
            icon:
                Icons.badge_outlined,
            textInputAction:
                TextInputAction.next,
            textCapitalization:
                TextCapitalization
                    .characters,
          ),

          const SizedBox(
            height: 18,
          ),

          _buildInputField(
            label: 'Password',
            hint:
                'Masukkan password',
            controller:
                _passwordController,
            icon:
                Icons.lock_outline_rounded,
            obscureText:
                _obscurePassword,
            textInputAction:
                TextInputAction.done,
            onSubmitted:
                _login,
            suffixIcon:
                IconButton(
              tooltip:
                  _obscurePassword
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons
                        .visibility_outlined
                    : Icons
                        .visibility_off_outlined,
                size: 21,
                color:
                    const Color(
                  0xFF6B7280,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 26,
          ),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : _login,
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    const Color(
                  0xFF2563EB,
                ),
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    const Color(
                  0xFF93B4F4,
                ),
                disabledForegroundColor:
                    Colors.white,
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
                child: _isLoading
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
                    : const Row(
                        key: ValueKey(
                          'login',
                        ),
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Text(
                            'Masuk',
                            style:
                                TextStyle(
                              fontSize:
                                  15.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                          SizedBox(
                            width: 9,
                          ),
                          Icon(
                            Icons
                                .arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF8FAFC,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons
                      .verified_user_outlined,
                  size: 17,
                  color:
                      Color(0xFF64748B),
                ),
                SizedBox(
                  width: 9,
                ),
                Expanded(
                  child: Text(
                    'Gunakan akun PKL yang telah terdaftar.',
                    style:
                        TextStyle(
                      fontSize: 11.5,
                      color:
                          Color(
                        0xFF64748B,
                      ),
                    ),
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
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Size screenSize =
        MediaQuery.sizeOf(context);

    final bool isWide =
        screenSize.width >= 850;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),

      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // BACKGROUND
            // ==================================================

            Positioned(
              top: -100,
              left: -100,
              child: _buildDecorativeCircle(
                size: 280,
                opacity: 0.035,
              ),
            ),

            Positioned(
              bottom: -130,
              right: -90,
              child: _buildDecorativeCircle(
                size: 330,
                opacity: 0.035,
              ),
            ),

            Positioned(
              top: screenSize.height * 0.25,
              right: -170,
              child: _buildDecorativeCircle(
                size: 360,
                opacity: 0.018,
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 20,
                  vertical: 50,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),

                      const SizedBox(
                        height: 30,
                      ),

                      _buildLoginCard(),

                      const SizedBox(
                        height: 24,
                      ),

                      const Text(
                        'Satu Garis V.1',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      const Text(
                        '© 2026 Sistem Absensi PKL',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFB0B7C3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================================
            // ABOUT
            // HARUS PALING BELAKANG DI STACK
            // ==================================================

            Positioned(
              top: 16,
              right: 18,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(
                  alpha: 0.08,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                child: InkWell(
                  onTap: _openAboutPage,
                  borderRadius: BorderRadius.circular(13),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 22,
                      color: Color(0xFF2563EB),
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
}