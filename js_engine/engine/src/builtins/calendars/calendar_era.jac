"""Era ID constants for int-only calendar field records."""

glob:pub ERA_NONE: int = 0,
     ERA_CE: int = 1,
     ERA_BCE: int = 2,
     ERA_BE: int = 3,
     ERA_AP: int = 4,
     ERA_AM: int = 5,
     ERA_AH: int = 6,
     ERA_SAKA: int = 7,
     ERA_ROC: int = 8,
     ERA_BROC: int = 9,
     ERA_MEIJI: int = 10,
     ERA_TAISHO: int = 11,
     ERA_SHOWA: int = 12,
     ERA_HEISEI: int = 13,
     ERA_REIWA: int = 14,
     ERA_CHINESE: int = 15,
     ERA_DANGI: int = 16,
     ERA_AA: int = 17,
     ERA_BH: int = 18;

# Indian national calendar era; name is "shaka"

# Amete Alem (ethiopic / ethioaa)
# Before Hijra (islamic family)
def:priv _era_lower_ascii(c: str) -> str {
    upper: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    lower: str = "abcdefghijklmnopqrstuvwxyz";
    i: int = 0;
    while i < 26 {
        if c == upper[i:i + 1] {
            return lower[i:i + 1];
        }
        i = i + 1;
    }
    return c;
}

def:priv _era_str_lower(s: str) -> str {
    out: str = "";
    i: int = 0;
    while i < len(s) {
        out = out + _era_lower_ascii(s[i:i + 1]);
        i = i + 1;
    }
    return out;
}

def:priv _era_str_eq_ci(a: str, b: str) -> bool {
    return _era_str_lower(a) == _era_str_lower(b);
}

def:pub calendar_era_id_from_name(s: str) -> int {
    if _era_str_eq_ci(s, "ce") {
        return ERA_CE;
    }
    if _era_str_eq_ci(s, "ad") {
        return ERA_CE;
    }
    if _era_str_eq_ci(s, "bce") {
        return ERA_BCE;
    }
    if _era_str_eq_ci(s, "bc") {
        return ERA_BCE;
    }
    if _era_str_eq_ci(s, "be") {
        return ERA_BE;
    }
    if _era_str_eq_ci(s, "ap") {
        return ERA_AP;
    }
    if _era_str_eq_ci(s, "am") {
        return ERA_AM;
    }
    if _era_str_eq_ci(s, "aa") {
        return ERA_AA;
    }
    if _era_str_eq_ci(s, "ah") {
        return ERA_AH;
    }
    if _era_str_eq_ci(s, "bh") {
        return ERA_BH;
    }
    # Spec / harness canonical name is "shaka"; accept legacy "saka" too.
    if _era_str_eq_ci(s, "shaka") {
        return ERA_SAKA;
    }
    if _era_str_eq_ci(s, "saka") {
        return ERA_SAKA;
    }
    if _era_str_eq_ci(s, "roc") {
        return ERA_ROC;
    }
    if _era_str_eq_ci(s, "broc") {
        return ERA_BROC;
    }
    if _era_str_eq_ci(s, "meiji") {
        return ERA_MEIJI;
    }
    if _era_str_eq_ci(s, "taisho") {
        return ERA_TAISHO;
    }
    if _era_str_eq_ci(s, "showa") {
        return ERA_SHOWA;
    }
    if _era_str_eq_ci(s, "heisei") {
        return ERA_HEISEI;
    }
    if _era_str_eq_ci(s, "reiwa") {
        return ERA_REIWA;
    }
    if _era_str_eq_ci(s, "chinese") {
        return ERA_CHINESE;
    }
    if _era_str_eq_ci(s, "dangi") {
        return ERA_DANGI;
    }
    return ERA_NONE;
}

def:pub calendar_era_name(era_id: int) -> str {
    if era_id == ERA_CE {
        return "ce";
    }
    if era_id == ERA_BCE {
        return "bce";
    }
    if era_id == ERA_BE {
        return "be";
    }
    if era_id == ERA_AP {
        return "ap";
    }
    if era_id == ERA_AM {
        return "am";
    }
    if era_id == ERA_AA {
        return "aa";
    }
    if era_id == ERA_AH {
        return "ah";
    }
    if era_id == ERA_BH {
        return "bh";
    }
    if era_id == ERA_SAKA {
        return "shaka";
    }
    if era_id == ERA_ROC {
        return "roc";
    }
    if era_id == ERA_BROC {
        return "broc";
    }
    if era_id == ERA_MEIJI {
        return "meiji";
    }
    if era_id == ERA_TAISHO {
        return "taisho";
    }
    if era_id == ERA_SHOWA {
        return "showa";
    }
    if era_id == ERA_HEISEI {
        return "heisei";
    }
    if era_id == ERA_REIWA {
        return "reiwa";
    }
    if era_id == ERA_CHINESE {
        return "chinese";
    }
    if era_id == ERA_DANGI {
        return "dangi";
    }
    return "";
}

def:pub calendar_month_code_str(ord_month: int, leap_month: bool) -> str {
    mc: str = "M";
    if ord_month < 10 {
        mc = mc + "0";
    }
    mc = mc + str(ord_month);
    if leap_month {
        mc = mc + "L";
    }
    return mc;
}
