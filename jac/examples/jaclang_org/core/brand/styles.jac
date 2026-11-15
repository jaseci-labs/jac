import from pathlib { Path }

def css(p: Colors) -> str;

with entry {
    dest = Path(__file__).resolve().parent.parent / "site" / "styles" / "brand.css";
    dest.write_text(
        ":root{" + css(light_palette()) + "}\n.dark{" + css(dark_palette()) + "}\n",
        encoding="utf-8"
    );
    logo = dest.parent.parent / "assets" / "jacyak-logo.svg";
    logo.write_text(logo_xml(), encoding="utf-8");
}
