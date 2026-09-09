import from core.brand.logo { logo_xml }
import from pathlib { Path }
import from core.brand.tokens {
    Colors,
    dark_palette,
    light_palette,
    spacing,
    radii,
    fonts,
    font_family
}

def css(p: Colors) -> str {
    return "--background:"
        + p.bg
        + ";--foreground:"
        + p.text
        + ";--card:"
        + p.surface
        + ";--card-foreground:"
        + p.text
        + ";--primary:"
        + p.accent
        + ";--primary-foreground:"
        + p.accentText
        + ";--muted:"
        + p.elevated
        + ";--muted-foreground:"
        + p.muted
        + ";--border:"
        + p.border
        + ";--input:"
        + p.field
        + ";--like:"
        + p.like
        + ";--reply:"
        + p.reply
        + ";--destructive:"
        + p.danger
        + ";--radius:"
        + str(radii().sm)
        + "px;--spacing:"
        + str(spacing().xs)
        + "px;--font-sans:"
        + font_family()
        + ",sans-serif;--font-display:"
        + font_family()
        + ",sans-serif;";
}

with entry {
    dest = Path(__file__).resolve().parent.parent / "site" / "styles" / "brand.css";
    dest.write_text(
        ":root{" + css(light_palette()) + "}\n.dark{" + css(dark_palette()) + "}\n",
        encoding="utf-8"
    );
    logo = dest.parent.parent / "assets" / "jacyak-logo.svg";
    logo.write_text(logo_xml(), encoding="utf-8");
}
