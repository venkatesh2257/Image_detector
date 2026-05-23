/// Showcase carousel: fixed icon size + SVG assets under [assets/SVG/].
///
/// **Design your SVGs at 96×96 px** (viewBox `0 0 96 96`).
/// Export from Illustrator with fills expanded / inline (not CSS classes only).
abstract final class ShowcaseSize {
  /// Illustrator / Figma artboard (exports scale up in the carousel).
  static const designArtboardPx = 96;

  /// Insets inside the white carousel card.
  static const iconPaddingTop = 12.0;
  static const iconPaddingSides = 10.0;
  static const iconPaddingBottom = 12.0;

}

abstract final class DairyShowcaseAssets {
  static const buffaloRear = 'assets/SVG/buffalo_1.svg';
  static const health = 'assets/SVG/baffalo.svg';
  static const cowRear = 'assets/SVG/Cow.svg';
  static const milking = 'assets/SVG/milk_Extraction.svg';
}

class DairyShowcaseItem {
  final String title;
  final String subtitle;
  final String? svgAsset;
  final String? svg;

  const DairyShowcaseItem({
    required this.title,
    required this.subtitle,
    this.svgAsset,
    this.svg,
  }) : assert(svgAsset != null || svg != null);

  static const List<DairyShowcaseItem> all = [
    DairyShowcaseItem(
      title: 'Buffalo rear',
      subtitle: 'Pin bone escutcheon',
      svgAsset: DairyShowcaseAssets.buffaloRear,
    ),
    DairyShowcaseItem(
      title: 'Cow rear',
      subtitle: 'Herd comparison',
      svgAsset: DairyShowcaseAssets.cowRear,
    ),
    DairyShowcaseItem(
      title: 'Milking',
      subtitle: 'Yield context',
      svgAsset: DairyShowcaseAssets.milking,
    ),
    DairyShowcaseItem(
      title: 'AI scanning',
      subtitle: 'Neural analysis',
      svg: _aiScan,
    ),
    DairyShowcaseItem(
      title: 'Health',
      subtitle: 'Condition check',
      svgAsset: DairyShowcaseAssets.health,
    ),
    DairyShowcaseItem(
      title: 'Lactation',
      subtitle: 'Stage & DIM',
      svg: _lactation,
    ),
    DairyShowcaseItem(
      title: 'Milk yield',
      subtitle: 'Liters per day',
      svgAsset: DairyShowcaseAssets.milking,
    ),
  ];

  static const _aiScan = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <rect x="18" y="22" width="60" height="52" rx="10" fill="#F6F4FF" stroke="#6C4DFF" stroke-width="2"/>
  <path d="M24 40 L72 40" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="5 3" opacity="0.7"/>
  <path d="M24 50 L72 50" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="5 3"/>
  <path d="M24 60 L72 60" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="5 3" opacity="0.8"/>
  <circle cx="48" cy="45" r="14" fill="none" stroke="#6C4DFF" stroke-width="2"/>
  <path d="M42 45 L46 49 L56 39" stroke="#10B981" stroke-width="2.5" fill="none" stroke-linecap="round"/>
</svg>''';

  static const _lactation = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <path d="M24 68 L24 36 Q48 20 72 36 L72 68" fill="none" stroke="#6C4DFF" stroke-width="2.5"/>
  <circle cx="24" cy="36" r="4" fill="#6C4DFF"/>
  <circle cx="48" cy="26" r="4" fill="#6C4DFF"/>
  <circle cx="72" cy="36" r="4" fill="#6C4DFF"/>
  <rect x="38" y="50" width="20" height="22" rx="5" fill="#6C4DFF" opacity="0.2"/>
</svg>''';
}
