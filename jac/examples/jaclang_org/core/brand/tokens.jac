obj Colors {
    has bg: str = "#171717",
        surface: str = "#262626",
        elevated: str = "#343434",
        border: str = "#3f3f3f",
        text: str = "#fafafa",
        muted: str = "#a3a3a3",
        accent: str = "#f97316",
        accentSoft: str = "rgba(249,115,22,0.16)",
        accentText: str = "#ffffff",
        like: str = "#f4548a",
        reply: str = "#4aa3ff",
        danger: str = "#ff5c5c",
        dangerSoft: str = "rgba(255,92,92,0.14)",
        field: str = "#262626",
        scrim: str = "rgba(0,0,0,0.65)";
}

obj Spacing {
    has xs: int = 4,
        sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 24,
        xxl: int = 32,
        huge: int = 48;
}

obj Radii {
    has sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 24,
        pill: int = 999;
}

obj Fonts {
    has xs: int = 12,
        sm: int = 14,
        md: int = 16,
        lg: int = 20,
        xl: int = 26,
        huge: int = 34;
}

def:pub dark_palette -> Colors {
    return Colors();
}

def:pub light_palette -> Colors {
    return Colors(
        bg="#ffffff",
        surface="#ffffff",
        elevated="#f5f5f5",
        border="#e5e5e5",
        text="#171717",
        muted="#737373",
        accent="#ea580c",
        field="#fafafa",
        accentSoft="rgba(234,88,12,0.12)"
    );
}

def:pub spacing -> Spacing {
    return Spacing();
}

def:pub radii -> Radii {
    return Radii();
}

def:pub fonts -> Fonts {
    return Fonts();
}

def:pub font_family -> str {
    return "Geist";
}
