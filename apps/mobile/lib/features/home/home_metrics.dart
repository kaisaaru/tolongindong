/// Ukuran beranda, diukur per piksel dari desain Figma (frame Android
/// Compact, lebar 412 dp) lalu dikonversi ke dp. Semua angka di satu tempat
/// supaya penyetelan tidak perlu menyisir widget satu per satu.
///
/// Header di desain dihitung dari status bar setinggi 52 dp. Di perangkat
/// lain, jarak dihitung dari tepi bawah status bar perangkat itu sendiri,
/// jadi proporsinya tetap sama walau tinggi status bar berbeda.
class HomeMetrics {
  const HomeMetrics._();

  // ── Header ────────────────────────────────────────────────────────────
  static const headerPadding = 22.0;
  static const headerTopGap = 24.0; // status bar -> avatar
  static const avatarSize = 48.0;
  static const avatarTextGap = 19.0;
  static const greetingSize = 15.5;
  static const greetingPillGap = 7.0;
  static const locationSize = 11.5;
  static const bellSize = 34.0;

  /// Lonceng di desain 9 dp lebih tinggi dari garis tengah avatar.
  static const bellRaise = 9.4;

  static const headerBottomGap = 46.0; // avatar -> tepi lembar putih

  /// Posisi tepi lembar putih di desain, dipakai untuk menggeser pita header
  /// supaya hubungannya dengan tepi lembar tetap sama di semua perangkat.
  static const designSheetTop = 169.7;

  // ── Lembar putih ──────────────────────────────────────────────────────
  static const sheetRadius = 36.0;
  static const bodyPadding = 35.0;

  // ── Search ────────────────────────────────────────────────────────────
  static const searchTopGap = 20.4;
  static const searchSideInset = 33.6;
  static const searchHeight = 38.4;
  static const searchRadius = 10.0;
  static const searchBorder = 1.2;
  static const searchTextSize = 11.0;

  // ── Grid kategori ─────────────────────────────────────────────────────
  static const gridTopGap = 24.0;
  static const tileSize = 69.0;
  static const tileGap = 20.5;
  static const tileRadius = 14.0;
  static const tileLabelGap = 13.0;
  static const tileLabelSize = 12.0;
  static const tileRowGap = 21.2;

  // ── Seksi ─────────────────────────────────────────────────────────────
  static const sectionTitleSize = 14.0;
  static const promoTopGap = 29.8; // label grid -> judul Penawaran Spesial
  static const titleToBanner = 17.8;
  static const foodTopGap = 28.6; // banner -> judul Makanan Favorit
  static const titleToCards = 15.8;

  // ── Banner promo ──────────────────────────────────────────────────────
  static const bannerWidth = 340.0;
  static const bannerHeight = 139.5;
  static const bannerRadius = 16.0;
  static const bannerGap = 14.4;

  // ── Kartu makanan ─────────────────────────────────────────────────────
  static const foodCardWidth = 138.0;
  static const foodCardHeight = 184.0;
  static const foodCardGap = 13.3;
  static const foodCardPadding = 5.5;
  static const foodImageHeight = 93.6;

  // ── Navigasi bawah ────────────────────────────────────────────────────
  static const navWidth = 316.0;
  static const navHeight = 56.0;
  static const navBottomGap = 31.0; // minimal; ikut safe area kalau lebih besar
  static const navFabSize = 46.0;

  /// Pusat tiap ikon relatif terhadap pusat bilah: Beranda, Cari Helper,
  /// (tombol +), Percakapan, Profil.
  static const navIconOffsets = [-132.0, -72.0, 72.0, 130.0];
}
