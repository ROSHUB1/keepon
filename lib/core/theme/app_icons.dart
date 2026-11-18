/// KEEPON icon set, taken from the brand sheet (assets/icons/*.png).
/// Single-color icons are tinted by the theme. Icons in assets/icons/color/ keep their colors.
class AppIcons {
  AppIcons._();

  static const _p = 'assets/icons/';
  static const _c = 'assets/icons/color/';

  // Navigation
  static const home = '${_p}home.png';
  static const homeFilled = '${_p}home_filled.png';
  static const protection = '${_p}protection.png';
  static const protectionFilled = '${_p}protection.png';
  static const alerts = '${_p}alerts.png';
  static const history = '${_p}history.png';
  static const settings = '${_p}settings.png';
  static const account = '${_p}account.png';
  static const help = '${_p}help.png';
  static const recovery = '${_p}recovery.png';

  // Protection features
  static const motion = '${_p}motion.png';
  static const charger = '${_p}charger.png';
  static const headphones = '${_p}headphones.png';
  static const sim = '${_p}sim.png';
  static const device = '${_p}device.png';

  // Monitoring
  static const scan = '${_p}scan.png';
  static const live = '${_p}live.png';
  static const logs = '${_p}logs.png';
  static const network = '${_p}network.png';

  // Status & events (keep their own colors)
  static const protected = '${_c}protected.png';
  static const alert = '${_c}alert.png';
  static const critical = '${_c}critical.png';
  static const info = '${_c}info.png';
  static const ok = '${_c}ok.png';

  // Actions
  static const clean = '${_p}clean.png';
  static const backup = '${_p}backup.png';
  static const restore = '${_p}restore.png';
  static const share = '${_p}share.png';
  static const delete = '${_p}delete.png';

  // More
  static const search = '${_p}search.png';
  static const filter = '${_p}filter.png';
  static const sort = '${_p}sort.png';
  static const download = '${_p}download.png';
  static const upload = '${_p}upload.png';
  static const refresh = '${_p}refresh.png';
  static const edit = '${_p}edit.png';
  static const link = '${_p}link.png';
}
