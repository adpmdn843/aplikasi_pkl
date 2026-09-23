import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // ==========================================================
  // INFORMASI APLIKASI
  // ==========================================================

  static const String appName = 'Garis Satu';

  static const String appSubtitle =
      'Absensi PKL';

  static const String appVersion =
      'Thanu V.1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FB),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,
        foregroundColor:
            const Color(0xFF111827),

        title: const Text(
          'Tentang Aplikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        centerTitle: false,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // LOGO / JUDUL
            // ==================================================

            Center(
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,

                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xFFE8F0FF),
                      shape:
                          BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons
                          .location_history_rounded,
                      size: 44,
                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  const Text(
                    appName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  const Text(
                    appSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // PENGEMBANG APLIKASI
            // ==================================================

            _buildSectionTitle(
              icon:
                  Icons.groups_rounded,
              title:
                  'Pendukung Aplikasi',
            ),

            const SizedBox(
              height: 14,
            ),

            _buildDevelopers(),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // TENTANG APLIKASI
            // ==================================================

            _buildSectionTitle(
              icon:
                  Icons.info_outline_rounded,
              title:
                  'Tentang Garis Satu',
            ),

            const SizedBox(
              height: 10,
            ),

            _buildCard(
              child: const Text(
                'Garis Satu merupakan aplikasi Absensi PKL '
                'yang dirancang untuk membantu proses '
                'pencatatan kehadiran peserta PKL secara '
                'lebih mudah, terstruktur, dan praktis.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color:
                      Color(0xFF4B5563),
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // FITUR
            // ==================================================

            _buildSectionTitle(
              icon:
                  Icons.auto_awesome_rounded,
              title:
                  'Fitur Aplikasi',
            ),

            const SizedBox(
              height: 10,
            ),

            _buildFeature(
              icon:
                  Icons.login_rounded,
              title:
                  'Login Peserta PKL',
              description:
                  'Peserta dapat masuk menggunakan '
                  'ID PKL dan password yang telah terdaftar.',
            ),

            _buildFeature(
              icon:
                  Icons.location_on_rounded,
              title:
                  'Absensi PKL',
              description:
                  'Membantu proses pencatatan kehadiran '
                  'peserta PKL.',
            ),

            _buildFeature(
              icon:
                  Icons.history_rounded,
              title:
                  'Riwayat Absensi',
              description:
                  'Menampilkan riwayat kehadiran '
                  'peserta PKL.',
            ),

            _buildFeature(
              icon:
                  Icons.description_rounded,
              title:
                  'Laporan PKL',
              description:
                  'Mendukung pencatatan laporan kegiatan '
                  'selama pelaksanaan PKL.',
            ),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // VERSI APLIKASI
            // ==================================================

            _buildSectionTitle(
              icon:
                  Icons.system_update_rounded,
              title:
                  'Versi Aplikasi',
            ),

            const SizedBox(
              height: 10,
            ),

            _buildCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE8F0FF,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),

                    child: const Icon(
                      Icons.apps_rounded,
                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Garis Satu',
                          style:
                              TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Color(
                              0xFF111827,
                            ),
                          ),
                        ),

                        SizedBox(
                          height: 3,
                        ),

                        Text(
                          'Versi terbaru',
                          style:
                              TextStyle(
                            fontSize: 13,
                            color:
                                Color(
                              0xFF6B7280,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE8F0FF,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),

                    child: const Text(
                      appVersion,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            Color(
                          0xFF2563EB,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // FOOTER
            // ==================================================

            Center(
              child: Column(
                children: [
                  const Text(
                    'Garis Satu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF374151),
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    'Absensi • $appVersion',
                    style: const TextStyle(
                      fontSize: 12,
                      color:
                          Color(0xFF9CA3AF),
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  const Text(
                    '© 2026',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          Color(0xFF9CA3AF),
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

  // ==========================================================
  // BAGIAN 3 PENGEMBANG
  // ==========================================================

  Widget _buildDevelopers() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        22,
        16,
        20,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 15,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),

      child: Column(
        children: [
          // ==================================================
          // PENGEMBANG 1 - FOTO BESAR
          // ==================================================

          _buildDeveloperPhoto(
            imagePath:
                'assets/images/garis_satu_1.jpg',
            name:
                'Nanang Iriwanto',
            role:
                'MR',
            size: 125,
          ),

          const SizedBox(
            height: 22,
          ),

          // ==================================================
          // PENGEMBANG 2 & 3
          // ==================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Expanded(
                child:
                    _buildDeveloperPhoto(
                  imagePath:
                      'assets/images/garis_satu_2.jpg',
                  name:
                      'Ardi Primadani',
                  role:
                      'Developer',
                  size: 90,
                ),
              ),

              const SizedBox(
                width: 20,
              ),

              Expanded(
                child:
                    _buildDeveloperPhoto(
                  imagePath:
                      'assets/images/garis_satu_3.jpg',
                  name:
                      'Nabil Raissa Putra',
                  role:
                      'Support',
                  size: 90,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FOTO PENGEMBANG
  // ==========================================================

  Widget _buildDeveloperPhoto({
    required String imagePath,
    required String name,
    required String role,
    required double size,
  }) {
    return Column(
      children: [
        // ------------------------------------------------------
        // FOTO LINGKARAN
        // ------------------------------------------------------

        Container(
          width: size + 8,
          height: size + 8,

          padding:
              const EdgeInsets.all(
            4,
          ),

          decoration:
              const BoxDecoration(
            color:
                Color(0xFFE8F0FF),
            shape:
                BoxShape.circle,
          ),

          child: ClipOval(
            child: Image.asset(
              imagePath,

              width: size,
              height: size,

              fit: BoxFit.cover,

              errorBuilder:
                  (
                    context,
                    error,
                    stackTrace,
                  ) {
                return Container(
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(0xFFF3F4F6),
                    shape:
                        BoxShape.circle,
                  ),

                  child: Icon(
                    Icons
                        .person_rounded,
                    size:
                        size * 0.45,
                    color:
                        const Color(
                      0xFF9CA3AF,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        // ------------------------------------------------------
        // NAMA
        // ------------------------------------------------------

        Text(
          name,
          textAlign:
              TextAlign.center,

          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w700,
            color:
                Color(0xFF111827),
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        // ------------------------------------------------------
        // ROLE
        // ------------------------------------------------------

        Text(
          role,
          textAlign:
              TextAlign.center,

          style:
              const TextStyle(
            fontSize: 12,
            color:
                Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color:
              const Color(0xFF2563EB),
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.w700,
            color:
                Color(0xFF111827),
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
          16,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
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

      child: child,
    );
  }

  // ==========================================================
  // FEATURE
  // ==========================================================

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(
        15,
      ),

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
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ----------------------------------------------------
          // ICON
          // ----------------------------------------------------

          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE8F0FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),

            child: Icon(
              icon,
              size: 21,
              color:
                  const Color(
                0xFF2563EB,
              ),
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          // ----------------------------------------------------
          // TEXT
          // ----------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(
                      0xFF111827,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  description,
                  style:
                      const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color:
                        Color(
                      0xFF6B7280,
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
}