/// Ukuran beranda, diukur per piksel dari desain Figma (frame Android
/// Compact, lebar 412 dp) lalu dikonversi ke dp. Semua angka di satu tempat
/// supaya penyetelan tidak perlu menyisir widget satu per satu.
///
/// Header di desain dihitung dari status bar setinggi 52 dp. Di perangkat
/// lain, jarak dihitung dari tepi bawah status bar perangkat itu sendiri,
/// jadi proporsinya tetap sama walau tinggi status bar berbeda.
class HomeMetrics {
  const HomeMetrics._();

  /// Lebar frame desain.
  static const designWidth = 412.0;

  // ── Header ────────────────────────────────────────────────────────────
  static const headerPadding = 22.0;
  static const headerTopGap = 24.0; // status bar -> avatar
  static const avatarSize = 48.0;
  static const avatarTextGap = 19.0;
  static const greetingSize = 15.5;
  static const greetingPillGap = 7.0;
  static const locationSize = 12.0; // Regular
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
  static const tileLabelGap = 12.4;
  static const tileLabelSize = 12.0;

  // ── Seksi ─────────────────────────────────────────────────────────────
  static const sectionTitleSize = 14.0;
  static const sectionTopGap = 29.8; // akhir seksi -> judul seksi berikutnya
  static const titleToContent = 17.8; // judul seksi -> isinya

  // ── Kartu jasa (Jasa tersedia) ────────────────────────────────────────
  // Diukur dari frame desain Android Compact (412 dp).
  static const offerCardWidth = 245.0;
  static const offerCardHeight = 156.0;
  static const offerCardGap = 15.0;
  static const offerCardPadding = 5.5;
  static const offerCardRadius = 15.0;
  static const offerPanelHeight = 106.0;
  static const offerPanelRadius = 10.0;
  static const offerTitleSize = 18.0; // SemiBold
  static const offerMetaSize = 10.0; // Regular
  static const offerPriceSize = 12.5;

  // ── Banner promo ──────────────────────────────────────────────────────
  static const bannerWidth = 340.0;
  static const bannerHeight = 139.5;
  static const bannerRadius = 16.0;
  static const bannerGap = 14.4;

  // ── Navigasi bawah ────────────────────────────────────────────────────
  static const navHeight = 64.0;
  static const navIconSize = 30.0;
  static const navLabelGap = 4.0;
  static const navLabelSize = 11.0;
}
