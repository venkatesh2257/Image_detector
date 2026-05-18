/// Inline SVG artwork for the dairy AI showcase carousel (purple enterprise theme).
abstract final class DairyShowcaseSvgs {
  static const buffaloRear = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="60" cy="72" rx="38" ry="28" fill="#2D1B4E" opacity="0.15"/>
  <path d="M38 45 Q60 28 82 45 L78 88 Q60 98 42 88 Z" fill="#3D2A5C"/>
  <ellipse cx="48" cy="52" rx="8" ry="10" fill="#4A3568"/>
  <ellipse cx="72" cy="52" rx="8" ry="10" fill="#4A3568"/>
  <ellipse cx="60" cy="78" rx="14" ry="10" fill="#6C4DFF" opacity="0.35"/>
  <circle cx="60" cy="38" r="6" fill="#6C4DFF"/>
</svg>''';

  static const cowRear = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="60" cy="74" rx="36" ry="26" fill="#6C4DFF" opacity="0.08"/>
  <path d="M40 48 Q60 32 80 48 L76 86 Q60 94 44 86 Z" fill="#8B7355"/>
  <ellipse cx="50" cy="55" rx="7" ry="9" fill="#A08060"/>
  <ellipse cx="70" cy="55" rx="7" ry="9" fill="#A08060"/>
  <path d="M52 70 Q60 82 68 70" stroke="#F5F3FF" stroke-width="3" fill="none"/>
  <rect x="54" y="34" width="12" height="8" rx="4" fill="#E8E0FF"/>
</svg>''';

  static const milking = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <rect x="28" y="40" width="64" height="52" rx="8" fill="#EDEBFF" stroke="#6C4DFF" stroke-width="2"/>
  <path d="M44 52 L76 52 L72 78 Q60 88 48 78 Z" fill="#6C4DFF" opacity="0.25"/>
  <line x1="60" y1="52" x2="60" y2="32" stroke="#6C4DFF" stroke-width="3"/>
  <ellipse cx="60" cy="30" rx="10" ry="6" fill="#4F35E8"/>
  <circle cx="38" cy="70" r="4" fill="#10B981"/>
  <circle cx="82" cy="70" r="4" fill="#10B981"/>
</svg>''';

  static const aiScan = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <rect x="22" y="28" width="76" height="64" rx="12" fill="#F6F4FF" stroke="#6C4DFF" stroke-width="2"/>
  <path d="M30 50 L90 50" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="6 4" opacity="0.6"/>
  <path d="M30 62 L90 62" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="6 4" opacity="0.8"/>
  <path d="M30 74 L90 74" stroke="#6C4DFF" stroke-width="2" stroke-dasharray="6 4"/>
  <circle cx="60" cy="56" r="18" fill="none" stroke="#6C4DFF" stroke-width="2"/>
  <path d="M52 56 L58 62 L70 50" stroke="#10B981" stroke-width="3" fill="none" stroke-linecap="round"/>
</svg>''';

  static const health = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <circle cx="60" cy="58" r="32" fill="#EDEBFF"/>
  <path d="M60 38 L60 78 M40 58 L80 58" stroke="#6C4DFF" stroke-width="4" stroke-linecap="round"/>
  <path d="M48 70 Q60 88 72 70" fill="none" stroke="#10B981" stroke-width="3"/>
  <circle cx="42" cy="42" r="6" fill="#10B981" opacity="0.8"/>
  <circle cx="78" cy="42" r="6" fill="#10B981" opacity="0.8"/>
</svg>''';

  static const lactation = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <path d="M30 85 L30 45 Q60 25 90 45 L90 85" fill="none" stroke="#6C4DFF" stroke-width="3"/>
  <circle cx="30" cy="45" r="5" fill="#6C4DFF"/>
  <circle cx="60" cy="32" r="5" fill="#6C4DFF"/>
  <circle cx="90" cy="45" r="5" fill="#6C4DFF"/>
  <rect x="48" y="62" width="24" height="28" rx="6" fill="#6C4DFF" opacity="0.2"/>
  <text x="60" y="82" text-anchor="middle" font-size="14" fill="#4F35E8" font-family="sans-serif">DIM</text>
</svg>''';

  static const yield = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <rect x="28" y="70" width="12" height="28" rx="4" fill="#6C4DFF" opacity="0.35"/>
  <rect x="44" y="52" width="12" height="46" rx="4" fill="#6C4DFF" opacity="0.55"/>
  <rect x="60" y="38" width="12" height="60" rx="4" fill="#6C4DFF" opacity="0.75"/>
  <rect x="76" y="48" width="12" height="50" rx="4" fill="#6C4DFF"/>
  <path d="M32 32 L88 32" stroke="#4F35E8" stroke-width="2"/>
  <text x="60" y="28" text-anchor="middle" font-size="11" fill="#6C4DFF" font-family="sans-serif">L/day</text>
</svg>''';
}

class DairyShowcaseItem {
  final String title;
  final String subtitle;
  final String badge;
  final String svg;

  const DairyShowcaseItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.svg,
  });

  static const List<DairyShowcaseItem> all = [
    DairyShowcaseItem(
      title: 'Buffalo rear',
      subtitle: 'Pin bone escutcheon',
      badge: 'Vision',
      svg: DairyShowcaseSvgs.buffaloRear,
    ),
    DairyShowcaseItem(
      title: 'Cow rear',
      subtitle: 'Herd comparison',
      badge: 'Species',
      svg: DairyShowcaseSvgs.cowRear,
    ),
    DairyShowcaseItem(
      title: 'Milking',
      subtitle: 'Yield context',
      badge: 'Dairy',
      svg: DairyShowcaseSvgs.milking,
    ),
    DairyShowcaseItem(
      title: 'AI scanning',
      subtitle: 'Neural analysis',
      badge: 'AI Core',
      svg: DairyShowcaseSvgs.aiScan,
    ),
    DairyShowcaseItem(
      title: 'Health',
      subtitle: 'Condition check',
      badge: 'Health',
      svg: DairyShowcaseSvgs.health,
    ),
    DairyShowcaseItem(
      title: 'Lactation',
      subtitle: 'Stage & DIM',
      badge: 'Stage',
      svg: DairyShowcaseSvgs.lactation,
    ),
    DairyShowcaseItem(
      title: 'Milk yield',
      subtitle: 'Liters per day',
      badge: 'Predict',
      svg: DairyShowcaseSvgs.yield,
    ),
  ];
}
