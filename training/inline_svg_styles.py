"""Inline Illustrator CSS classes into SVG fill attributes (for flutter_svg)."""
import re
from pathlib import Path

SVG_DIR = Path(__file__).resolve().parents[1] / "assets" / "SVG"
SKIP = {"buffalo_showcase.svg"}


def inline_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if 'class="st' not in text:
        return False
    styles: dict[str, str] = {}
    for m in re.finditer(r"\.(st\d+)\s*\{\s*fill:\s*([^;}\s]+)", text):
        styles[m.group(1)] = m.group(2).strip()

    def sub_class(m: re.Match[str]) -> str:
        cls = m.group(1)
        return f'fill="{styles[cls]}"' if cls in styles else m.group(0)

    text = re.sub(r'class="(st\d+)"', sub_class, text)
    text = re.sub(r"<style>.*?</style>\s*", "", text, flags=re.DOTALL)
    path.write_text(text, encoding="utf-8")
    n_fills = text.count('fill="')
    print(f"  {path.name}: {len(styles)} classes -> {n_fills} fills")
    return True


def main() -> None:
    for path in sorted(SVG_DIR.glob("*.svg")):
        if path.name in SKIP:
            continue
        inline_file(path)


if __name__ == "__main__":
    main()
