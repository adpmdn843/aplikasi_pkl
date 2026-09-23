import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardPage({
    super.key,
    required this.userData,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ============================================================
  // API
  // ============================================================

  static const String apiUrl =
      'https://script.google.com/macros/s/AKfycbz9RpGz2yKPdHkQ19Z_7aew9PuaCtPm7OpYPi8ROJJKO3qJA70tkKP8wjgj3qxlGknk/exec';

  // ============================================================
  // COLOR
  // ============================================================

  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFEFF6FF);

  static const Color textDark = Color(0xFF111827);
  static const Color textMedium = Color(0xFF374151);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  static const Color backgroundColor = Color(0xFFF6F8FC);
  static const Color borderColor = Color(0xFFE7EAF0);

  static const Color greenColor = Color(0xFF16A34A);
  static const Color orangeColor = Color(0xFFF59E0B);
  static const Color redColor = Color(0xFFDC2626);

  // ============================================================
  // USER DATA
  // ============================================================

  String get idPKL =>
      widget.userData['id_pkl']?.toString().trim() ?? '';

  // ============================================================
  // ID JADWAL
  // DATABASE APLIKASI PKL -> PKL -> P
  // ============================================================

  String get idJadwal {
    final value =
        widget.userData['id_jadwal'] ??
        widget.userData['ID JADWAL'] ??
        widget.userData['Id Jadwal'] ??
        widget.userData['ID_JADWAL'] ??
        widget.userData['id jadwal'] ??
        '';

    return value.toString().trim();
  }

  String get nama =>
      widget.userData['nama_siswa']?.toString().trim() ?? '';

  String get sekolah =>
      widget.userData['asal_sekolah']?.toString().trim() ?? '';

  String get jurusan =>
      widget.userData['jurusan']?.toString().trim() ?? '';

  String get kelas =>
      widget.userData['kelas']?.toString().trim() ?? '';

  String get divisi =>
      widget.userData['divisi']?.toString().trim() ?? '';

  String get bagian =>
      widget.userData['bagian']?.toString().trim() ?? '';

  String get jenisKelamin =>
      widget.userData['jenis_kelamin']?.toString().trim() ?? '';

  String get telepon {
    final value =
        widget.userData['telepon'] ??
        widget.userData['Telepon'] ??
        widget.userData['TELEPON'] ??
        widget.userData['no_telepon'] ??
        widget.userData['No Telepon'] ??
        widget.userData['no_hp'] ??
        widget.userData['No HP'] ??
        widget.userData['nomor_telepon'] ??
        widget.userData['Nomor Telepon'] ??
        widget.userData['phone'] ??
        widget.userData['Phone'] ??
        widget.userData['hp'] ??
        widget.userData['HP'] ??
        '';

    return value.toString().trim();
  }

  // ============================================================
  // DATE JOIN
  // ============================================================

  String get dateJoin {
    final value =
        widget.userData['date_join']?.toString().trim() ?? '';

    if (value.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.year}';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // FOTO
  // ============================================================

  String get foto =>
      widget.userData['foto']?.toString().trim() ?? '';

  String get fotoUrl {
    if (foto.isEmpty) {
      return '';
    }

    return 'https://drive.google.com/uc?export=view&id=$foto';
  }

  // ============================================================
  // STATISTIK
  // ============================================================

  int _jumlahHadir = 0;
  int _jumlahTidakHadir = 0;
  int _jumlahTelat = 0;

  bool _loadingStatistik = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadStatistik();
  }

  // ============================================================
  // REFRESH USER
  // ============================================================

  Future<void> _refreshUserData() async {
    if (idPKL.isEmpty) {
      return;
    }

    try {
      final client = HttpClient();

      try {
        final uri = Uri.parse(
          '$apiUrl?action=checkSessionPKL'
          '&id_pkl=${Uri.encodeComponent(idPKL)}',
        );

        final request = await client.getUrl(uri);

        request.followRedirects = false;

        final response = await request.close();

        String body = '';

        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          body = await response
              .transform(utf8.decoder)
              .join();
        } else if (response.isRedirect) {
          final location =
              response.headers.value('location');

          if (location != null &&
              location.isNotEmpty) {
            final redirectRequest =
                await client.getUrl(
              Uri.parse(location),
            );

            redirectRequest.followRedirects = false;

            final redirectResponse =
                await redirectRequest.close();

            if (redirectResponse.statusCode == 200 ||
                redirectResponse.statusCode == 201) {
              body = await redirectResponse
                  .transform(utf8.decoder)
                  .join();
            }
          }
        }

        if (body.isEmpty) {
          throw Exception(
            'Response data user kosong.',
          );
        }

        final result = jsonDecode(body);

        if (result is! Map) {
          throw Exception(
            'Format response user tidak valid.',
          );
        }

        if (result['success'] == false) {
          throw Exception(
            result['message']?.toString() ??
                'Gagal mengambil data user.',
          );
        }

        dynamic rawData = result['data'];

        if (rawData is Map &&
            rawData['data'] is Map) {
          rawData = rawData['data'];
        }

        if (rawData is! Map) {
          throw Exception(
            'Data user tidak ditemukan.',
          );
        }

        final newUserData =
            Map<String, dynamic>.from(rawData);

        if (!mounted) {
          return;
        }

        setState(() {
          widget.userData.clear();
          widget.userData.addAll(newUserData);
        });
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint(
        'Gagal refresh data user: $e',
      );
    }
  }

  // ============================================================
  // LOAD STATISTIK
  // ============================================================

  Future<void> _loadStatistik() async {
    if (idPKL.isEmpty) {
      if (mounted) {
        setState(() {
          _jumlahHadir = 0;
          _jumlahTidakHadir = 0;
          _jumlahTelat = 0;
          _loadingStatistik = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _loadingStatistik = true;
      });
    }

    await _refreshUserData();

    try {
      final client = HttpClient();

      try {
        final uri = Uri.parse(
          '$apiUrl?action=riwayatAbsensi'
          '&id_pkl=${Uri.encodeComponent(idPKL)}',
        );

        final request = await client.getUrl(uri);

        request.followRedirects = false;

        final response = await request.close();

        String body = '';

        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          body = await response
              .transform(utf8.decoder)
              .join();
        } else if (response.isRedirect) {
          final location =
              response.headers.value('location');

          if (location != null &&
              location.isNotEmpty) {
            final redirectRequest =
                await client.getUrl(
              Uri.parse(location),
            );

            redirectRequest.followRedirects = false;

            final redirectResponse =
                await redirectRequest.close();

            if (redirectResponse.statusCode == 200 ||
                redirectResponse.statusCode == 201) {
              body = await redirectResponse
                  .transform(utf8.decoder)
                  .join();
            }
          }
        }

        if (body.isEmpty) {
          throw Exception(
            'Response riwayatAbsensi kosong.',
          );
        }

        final result = jsonDecode(body);

        if (result is! Map) {
          throw Exception(
            'Response bukan object JSON.',
          );
        }

        if (result['success'] == false) {
          throw Exception(
            result['message']?.toString() ??
                'riwayatAbsensi gagal.',
          );
        }

        dynamic rawData = result['data'];

        if (rawData is Map) {
          rawData =
              rawData['data'] ??
              rawData['rows'] ??
              rawData['riwayat'] ??
              rawData['absensi'];
        }

        if (rawData is! List) {
          if (mounted) {
            setState(() {
              _jumlahHadir = 0;
              _jumlahTidakHadir = 0;
              _jumlahTelat = 0;
              _loadingStatistik = false;
            });
          }

          return;
        }

        int hadir = 0;
        int tidakHadir = 0;
        int telat = 0;

        for (final rawItem in rawData) {
          if (rawItem is! Map) {
            continue;
          }

          final item =
              Map<String, dynamic>.from(rawItem);

          final status =
              _getStringFromMap(
            item,
            [
              'status',
              'Status',
              'STATUS',
            ],
          ).toLowerCase();

          final nilaiTelat =
              _getStringFromMap(
            item,
            [
              'Telat',
              'telat',
              'TELAT',
              'terlambat',
              'Terlambat',
              'TERLAMBAT',
              'keterlambatan',
              'Keterlambatan',
              'jam_telat',
              'Jam Telat',
              'jam terlambat',
              'Jam Terlambat',
            ],
          );

          if (status == 'hadir') {
            hadir++;
          }

          if (status == 'izin' ||
              status == 'sakit' ||
              status == 'alfa' ||
              status == 'libur') {
            tidakHadir++;
          }

          if (_isTelat(nilaiTelat)) {
            telat++;
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _jumlahHadir = hadir;
          _jumlahTidakHadir = tidakHadir;
          _jumlahTelat = telat;
          _loadingStatistik = false;
        });
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil statistik absensi: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _jumlahHadir = 0;
        _jumlahTidakHadir = 0;
        _jumlahTelat = 0;
        _loadingStatistik = false;
      });
    }
  }

  // ============================================================
  // GET STRING
  // ============================================================

  String _getStringFromMap(
    Map<String, dynamic> item,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = item[key];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null') {
        return text;
      }
    }

    for (final entry in item.entries) {
      final entryKey =
          entry.key.toString().trim().toLowerCase();

      for (final key in keys) {
        if (entryKey == key.trim().toLowerCase()) {
          final value = entry.value;

          if (value == null) {
            continue;
          }

          final text = value.toString().trim();

          if (text.isNotEmpty &&
              text.toLowerCase() != 'null') {
            return text;
          }
        }
      }
    }

    return '';
  }

  // ============================================================
  // CEK TELAT
  // ============================================================

  bool _isTelat(dynamic value) {
    if (value == null) {
      return false;
    }

    final text = value.toString().trim();

    if (text.isEmpty ||
        text == '-' ||
        text == '0' ||
        text == '0.0' ||
        text == '0:00' ||
        text == '00:00' ||
        text == '0:00:00' ||
        text == '00:00:00' ||
        text == '0:00:00.000' ||
        text == '00:00:00.000') {
      return false;
    }

    final match =
        RegExp(
      r'^(\d+):(\d{2}):(\d{2})',
    ).firstMatch(text);

    if (match != null) {
      final jam =
          int.tryParse(match.group(1)!) ?? 0;

      final menit =
          int.tryParse(match.group(2)!) ?? 0;

      final detik =
          int.tryParse(match.group(3)!) ?? 0;

      return jam > 0 ||
          menit > 0 ||
          detik > 0;
    }

    final shortMatch =
        RegExp(
      r'^(\d+):(\d{2})$',
    ).firstMatch(text);

    if (shortMatch != null) {
      final jam =
          int.tryParse(shortMatch.group(1)!) ?? 0;

      final menit =
          int.tryParse(shortMatch.group(2)!) ?? 0;

      return jam > 0 ||
          menit > 0;
    }

    final number =
        double.tryParse(text);

    if (number != null) {
      return number > 0;
    }

    return true;
  }

  // ============================================================
  // TOTAL ABSENSI
  // ============================================================

  int get _totalAbsensi =>
      _jumlahHadir +
      _jumlahTidakHadir;

  double get _persentaseHadir {
    if (_totalAbsensi <= 0) {
      return 0;
    }

    return (_jumlahHadir /
            _totalAbsensi)
        .clamp(0.0, 1.0);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor,

      body: SafeArea(
        bottom: false,

        child: RefreshIndicator(
          color: primaryColor,

          backgroundColor:
              Colors.white,

          onRefresh:
              _loadStatistik,

          child:
              CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),

            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildHeader(),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  35,
                ),

                sliver:
                    SliverList(
                  delegate:
                      SliverChildListDelegate([
                    _buildGreeting(),

                    const SizedBox(
                      height: 22,
                    ),

                    _buildSectionTitle(
                      title:
                          'Ringkasan Absensi',
                      subtitle:
                          'Pantau kehadiran kamu',
                    ),

                    const SizedBox(
                      height: 13,
                    ),

                    _buildStatistikAbsensi(),

                    const SizedBox(
                      height: 14,
                    ),

                    _buildAttendanceOverview(),

                    const SizedBox(
                      height: 22,
                    ),

                    _buildLogoutButton(),

                    const SizedBox(
                      height: 32,
                    ),

                    _buildFooter(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        4,
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            padding:
                const EdgeInsets.all(6),

            decoration:
                BoxDecoration(
              color:
                  Colors.white,

              borderRadius:
                  BorderRadius.circular(
                15,
              ),

              border:
                  Border.all(
                color:
                    borderColor,
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black
                          .withValues(
                    alpha: 0.035,
                  ),
                  blurRadius: 14,
                  offset:
                      const Offset(
                    0,
                    5,
                  ),
                ),
              ],
            ),

            child:
                ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),

              child:
                  Image.asset(
                'assets/images/Logo.jpg',
                fit:
                    BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    const Text(
                      'Satu Garis',

                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            textDark,
                        letterSpacing:
                            -0.5,
                      ),
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            primarySoft,

                        borderRadius:
                            BorderRadius
                                .circular(
                          6,
                        ),
                      ),

                      child:
                          const Text(
                        'PKL',
                        style:
                            TextStyle(
                          fontSize: 7.5,
                          fontWeight:
                              FontWeight.w900,
                          color:
                              primaryColor,
                          letterSpacing:
                              0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 2,
                ),

                const Text(
                  'Sistem Informasi PKL',

                  style:
                      TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        textGray,
                  ),
                ),
              ],
            ),
          ),

          _buildNotificationButton(),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATION BUTTON
  // ============================================================

  Widget _buildNotificationButton() {
    return Material(
      color:
          Colors.white,

      borderRadius:
          BorderRadius.circular(
        15,
      ),

      child:
          InkWell(
        onTap:
            _showNotification,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        child:
            Container(
          width: 46,
          height: 46,

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              15,
            ),

            border:
                Border.all(
              color:
                  borderColor,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha: 0.025,
                ),
                blurRadius: 10,
                offset:
                    const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),

          child:
              const Icon(
            Icons
                .notifications_none_rounded,
            size: 22,
            color:
                textMedium,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    return Material(
      color:
          Colors.transparent,

      borderRadius:
          BorderRadius.circular(
        26,
      ),

      child:
          InkWell(
        onTap:
            _showProfile,

        borderRadius:
            BorderRadius.circular(
          26,
        ),

        child:
            Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.all(
            18,
          ),

          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFF2563EB),
                Color(0xFF1D4ED8),
                Color(0xFF1E40AF),
              ],
            ),

            borderRadius:
                BorderRadius.circular(
              26,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    primaryColor
                        .withValues(
                  alpha: 0.22,
                ),
                blurRadius: 25,
                offset:
                    const Offset(
                  0,
                  11,
                ),
              ),
            ],
          ),

          child:
              Stack(
            children: [
              Positioned(
                right: -40,
                top: -48,

                child:
                    Container(
                  width: 125,
                  height: 125,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.055,
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 30,
                bottom: -65,

                child:
                    Container(
                  width: 110,
                  height: 110,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.035,
                    ),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.12,
                      ),

                      border:
                          Border.all(
                        color:
                            Colors.white
                                .withValues(
                          alpha: 0.75,
                        ),
                        width: 2,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black
                                  .withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 12,
                          offset:
                              const Offset(
                            0,
                            5,
                          ),
                        ),
                      ],
                    ),

                    child:
                        ClipOval(
                      child:
                          fotoUrl.isNotEmpty
                              ? Image.network(
                                  fotoUrl,
                                  fit:
                                      BoxFit.cover,
                                  errorBuilder:
                                      (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return const Icon(
                                      Icons
                                          .person_rounded,
                                      size: 33,
                                      color:
                                          Colors.white,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons
                                      .person_rounded,
                                  size: 33,
                                  color:
                                      Colors.white,
                                ),
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'SELAMAT DATANG 👋',

                          style:
                              TextStyle(
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Colors.white70,
                            letterSpacing:
                                0.5,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          nama.isNotEmpty
                              ? nama
                              : 'Peserta PKL',

                          maxLines:
                              1,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                            color:
                                Colors.white,
                            letterSpacing:
                                -0.3,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Row(
                          children: [
                            if (idPKL
                                .isNotEmpty)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.white
                                          .withValues(
                                    alpha:
                                        0.13,
                                  ),

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    6,
                                  ),
                                ),

                                child:
                                    Text(
                                  idPKL,

                                  style:
                                      const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Colors.white,
                                  ),
                                ),
                              ),

                            if (idPKL
                                .isNotEmpty)
                              const SizedBox(
                                width: 7,
                              ),

                            const Text(
                              'Peserta PKL',

                              style:
                                  TextStyle(
                                fontSize: 9,
                                fontWeight:
                                    FontWeight.w500,
                                color:
                                    Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 14,
                    color:
                        Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,

      children: [
        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      textDark,
                  letterSpacing:
                      -0.2,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                subtitle,

                style:
                    const TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      textGray,
                ),
              ),
            ],
          ),
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
                primarySoft,

            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),

          child:
              const Row(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons
                    .analytics_outlined,
                size: 13,
                color:
                    primaryColor,
              ),

              SizedBox(
                width: 4,
              ),

              Text(
                'STATISTIK',
                style:
                    TextStyle(
                  fontSize: 7.5,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      primaryColor,
                  letterSpacing:
                      0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTIK CARD
  // ============================================================

  Widget _buildStatistikAbsensi() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Expanded(
          child:
              _buildStatCard(
            title:
                'Hadir',
            subtitle:
                'Kehadiran',
            value:
                _jumlahHadir,
            icon:
                Icons
                    .check_circle_rounded,
            iconColor:
                greenColor,
            backgroundColor:
                const Color(
              0xFFF0FDF4,
            ),
          ),
        ),

        const SizedBox(
          width: 9,
        ),

        Expanded(
          child:
              _buildStatCard(
            title:
                'Tidak Hadir',
            subtitle:
                'Izin • Sakit • Alfa',
            value:
                _jumlahTidakHadir,
            icon:
                Icons
                    .event_busy_rounded,
            iconColor:
                orangeColor,
            backgroundColor:
                const Color(
              0xFFFFFBEB,
            ),
          ),
        ),

        const SizedBox(
          width: 9,
        ),

        Expanded(
          child:
              _buildStatCard(
            title:
                'Telat',
            subtitle:
                'Keterlambatan',
            value:
                _jumlahTelat,
            icon:
                Icons
                    .schedule_rounded,
            iconColor:
                primaryColor,
            backgroundColor:
                primarySoft,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required int value,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 143,
      ),

      padding:
          const EdgeInsets.fromLTRB(
        12,
        12,
        10,
        11,
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
              borderColor,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha: 0.025,
            ),
            blurRadius: 13,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration:
                BoxDecoration(
              color:
                  backgroundColor,

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                Icon(
              icon,
              size: 19,
              color:
                  iconColor,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _loadingStatistik
              ? SizedBox(
                  height: 27,

                  child:
                      Align(
                    alignment:
                        Alignment.centerLeft,

                    child:
                        SizedBox(
                      width: 19,
                      height: 19,

                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2.2,
                        color:
                            iconColor,
                      ),
                    ),
                  ),
                )
              : Text(
                  value.toString(),

                  style:
                      const TextStyle(
                    fontSize: 25,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        textDark,
                  ),
                ),

          const SizedBox(
            height: 7,
          ),

          Text(
            title,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style:
                const TextStyle(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w800,
              color:
                  textMedium,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            subtitle,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style:
                const TextStyle(
              fontSize: 8,
              fontWeight:
                  FontWeight.w500,
              color:
                  textLight,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE OVERVIEW
  // ============================================================

  Widget _buildAttendanceOverview() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
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
              borderColor,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha: 0.018,
            ),
            blurRadius: 12,
            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,

                decoration:
                    BoxDecoration(
                  color:
                      primarySoft,

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .donut_large_rounded,
                  color:
                      primaryColor,
                  size: 19,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Persentase Kehadiran',

                      style:
                          TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            textDark,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      _totalAbsensi > 0
                          ? 'Berdasarkan $_totalAbsensi data absensi'
                          : 'Belum ada data absensi',

                      style:
                          const TextStyle(
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            textGray,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${(_persentaseHadir * 100).toStringAsFixed(0)}%',

                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),

            child:
                LinearProgressIndicator(
              value:
                  _loadingStatistik
                      ? 0
                      : _persentaseHadir,

              minHeight:
                  9,

              backgroundColor:
                  const Color(
                0xFFEFF2F6,
              ),

              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primaryColor,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _buildMiniAttendance(
                  icon:
                      Icons
                          .check_circle_rounded,
                  label:
                      'Hadir',
                  value:
                      _jumlahHadir,
                  color:
                      greenColor,
                ),
              ),

              _buildVerticalDivider(),

              Expanded(
                child:
                    _buildMiniAttendance(
                  icon:
                      Icons
                          .event_busy_rounded,
                  label:
                      'Tidak Hadir',
                  value:
                      _jumlahTidakHadir,
                  color:
                      orangeColor,
                ),
              ),

              _buildVerticalDivider(),

              Expanded(
                child:
                    _buildMiniAttendance(
                  icon:
                      Icons
                          .schedule_rounded,
                  label:
                      'Telat',
                  value:
                      _jumlahTelat,
                  color:
                      primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MINI ATTENDANCE
  // ============================================================

  Widget _buildMiniAttendance({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 17,
          color:
              color,
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value.toString(),

          style:
              const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w900,
            color:
                textDark,
          ),
        ),

        const SizedBox(
          height: 1,
        ),

        Text(
          label,

          maxLines: 1,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            fontSize: 8,
            fontWeight:
                FontWeight.w600,
            color:
                textGray,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VERTICAL DIVIDER
  // ============================================================

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 48,
      color:
          borderColor,
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton() {
    return Material(
      color:
          Colors.white,

      borderRadius:
          BorderRadius.circular(
        18,
      ),

      child:
          InkWell(
        onTap:
            _logout,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        child:
            Container(
          padding:
              const EdgeInsets.all(
            13,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border:
                Border.all(
              color:
                  borderColor,
            ),
          ),

          child:
              Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFEF2F2,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .logout_rounded,
                  size: 19,
                  color:
                      redColor,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Keluar dari Akun',

                      style:
                          TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            textDark,
                      ),
                    ),

                    SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Keluar dari akun Satu Garis',

                      style:
                          TextStyle(
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            textLight,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                size: 21,
                color:
                    textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          width: 34,
          height: 3,

          decoration:
              BoxDecoration(
            color:
                primaryColor
                    .withValues(
              alpha: 0.18,
            ),

            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        const Text(
          'Satu Garis',

          style:
              TextStyle(
            fontSize: 10.5,
            fontWeight:
                FontWeight.w800,
            color:
                textMedium,
          ),
        ),

        const SizedBox(
          height: 2,
        ),

        const Text(
          'Satu Garis V.1 • 2026',

          style:
              TextStyle(
            fontSize: 8.5,
            fontWeight:
                FontWeight.w500,
            color:
                textLight,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _showProfile() async {
    await _refreshUserData();

    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,

      isScrollControlled:
          true,

      backgroundColor:
          Colors.transparent,

      builder:
          (context) {
        return Container(
          constraints:
              BoxConstraints(
            maxHeight:
                MediaQuery.of(context)
                    .size
                    .height *
                0.90,
          ),

          decoration:
              const BoxDecoration(
            color:
                Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                30,
              ),
            ),
          ),

          child:
              SafeArea(
            top: false,

            child:
                SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                30,
              ),

              child:
                  Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFD1D5DB,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildProfileHeader(),

                  const SizedBox(
                    height: 25,
                  ),

                  const Align(
                    alignment:
                        Alignment.centerLeft,

                    child:
                        Text(
                      'Informasi Peserta',

                      style:
                          TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            textDark,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 11,
                  ),

                  // ==================================================
                  // ID JADWAL
                  // DATABASE APLIKASI PKL -> PKL -> P
                  // ==================================================

                  _buildProfileDetail(
                    icon:
                        Icons
                            .calendar_today_outlined,
                    label:
                        'ID Jadwal',
                    value:
                        idJadwal,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons.school_outlined,
                    label:
                        'Sekolah',
                    value:
                        sekolah,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons
                            .menu_book_outlined,
                    label:
                        'Jurusan',
                    value:
                        jurusan,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons.wc_outlined,
                    label:
                        'Jenis Kelamin',
                    value:
                        jenisKelamin,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons.class_outlined,
                    label:
                        'Kelas',
                    value:
                        kelas,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons
                            .account_tree_outlined,
                    label:
                        'Divisi',
                    value:
                        divisi,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons
                            .work_outline_rounded,
                    label:
                        'Bagian',
                    value:
                        bagian,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons.phone_outlined,
                    label:
                        'Telepon',
                    value:
                        telepon,
                  ),

                  _buildProfileDetail(
                    icon:
                        Icons
                            .calendar_month_outlined,
                    label:
                        'Tanggal Masuk',
                    value:
                        dateJoin,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
            Color(0xFF1E40AF),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          23,
        ),

        boxShadow: [
          BoxShadow(
            color:
                primaryColor
                    .withValues(
              alpha: 0.18,
            ),
            blurRadius: 20,
            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child:
          Row(
        children: [
          Container(
            width: 74,
            height: 74,

            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,

              color:
                  Colors.white
                      .withValues(
                alpha: 0.10,
              ),

              border:
                  Border.all(
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.80,
                ),
                width: 2.5,
              ),
            ),

            child:
                ClipOval(
              child:
                  fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Icon(
                              Icons
                                  .person_rounded,
                              size: 39,
                              color:
                                  Colors.white,
                            );
                          },
                        )
                      : const Icon(
                          Icons
                              .person_rounded,
                          size: 39,
                          color:
                              Colors.white,
                        ),
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'PESERTA PKL',

                  style:
                      TextStyle(
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Colors.white70,
                    letterSpacing:
                        1.2,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  nama.isNotEmpty
                      ? nama
                      : 'Peserta PKL',

                  maxLines:
                      2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Colors.white,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                if (idPKL.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withValues(
                        alpha:
                            0.12,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        7,
                      ),
                    ),

                    child:
                        Text(
                      idPKL,

                      style:
                          const TextStyle(
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Colors.white,
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

  // ============================================================
  // PROFILE DETAIL
  // ============================================================

  Widget _buildProfileDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width:
          double.infinity,

      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF8FAFC,
        ),

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        border:
            Border.all(
          color:
              borderColor,
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width: 37,
            height: 37,

            decoration:
                BoxDecoration(
              color:
                  primarySoft,

              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),

            child:
                Icon(
              icon,
              size: 18,
              color:
                  primaryColor,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style:
                      const TextStyle(
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        textLight,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value.isNotEmpty
                      ? value
                      : '-',

                  maxLines:
                      2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        textMedium,
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
  // NOTIFICATION
  // ============================================================

  void _showNotification() {
    showModalBottomSheet(
      context:
          context,

      backgroundColor:
          Colors.transparent,

      builder:
          (context) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),

          decoration:
              const BoxDecoration(
            color:
                Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                28,
              ),
            ),
          ),

          child:
              SafeArea(
            top: false,

            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                Container(
                  width: 42,
                  height: 4,

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFD1D5DB,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Container(
                  width: 58,
                  height: 58,

                  decoration:
                      BoxDecoration(
                    color:
                        primarySoft,

                    shape:
                        BoxShape.circle,
                  ),

                  child:
                      const Icon(
                    Icons
                        .notifications_none_rounded,
                    size: 29,
                    color:
                        primaryColor,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                const Text(
                  'Notifikasi',

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        textDark,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                const Text(
                  'Belum ada notifikasi baru.',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        textGray,
                  ),
                ),

                const SizedBox(
                  height: 21,
                ),

                SizedBox(
                  width:
                      double.infinity,

                  child:
                      FilledButton(
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          primaryColor,

                      foregroundColor:
                          Colors.white,

                      minimumSize:
                          const Size(
                        double.infinity,
                        48,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },

                    child:
                        const Text(
                      'Tutup',

                      style:
                          TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (context) {
        return AlertDialog(
          backgroundColor:
              Colors.white,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              23,
            ),
          ),

          title:
              Row(
            children: [
              Container(
                width: 38,
                height: 38,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFEF2F2,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .logout_rounded,
                  color:
                      redColor,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Expanded(
                child:
                    Text(
                  'Keluar dari akun?',

                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        textDark,
                  ),
                ),
              ),
            ],
          ),

          content:
              const Text(
            'Apakah kamu yakin ingin keluar dari aplikasi Satu Garis?',

            style:
                TextStyle(
              fontSize: 12,
              height: 1.45,
              color:
                  textGray,
            ),
          ),

          actionsPadding:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            15,
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
                  const Text(
                'Batal',

                style:
                    TextStyle(
                  color:
                      textGray,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    redColor,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
              ),

              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
                  const Text(
                'Keluar',

                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove(
      'isLoggedIn',
    );

    await prefs.remove(
      'id_pkl',
    );

    await prefs.remove(
      'userData',
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
      (route) => false,
    );
  }
}