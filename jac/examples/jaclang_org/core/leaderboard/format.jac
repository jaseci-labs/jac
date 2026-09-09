glob BELT_BADGE: dict[str, str] = {
         "white": "bg-stone-200 text-stone-900",
         "yellow": "bg-yellow-400 text-yellow-950",
         "orange": "bg-orange-500 text-white",
         "green": "bg-emerald-500 text-emerald-950",
         "brown": "bg-amber-800 text-amber-50",
         "black": "bg-neutral-950 text-white border border-white/25"
     };

def:pub belt_class(belt: str) -> str {
    return BELT_BADGE.get(belt) or "bg-muted";
}

def:pub belt_label(belt: str) -> str {
    if belt == "" {
        return "";
    }
    return belt[0].upper() + belt[1:] + " Belt";
}

def:pub time_ago(stamp: str) -> str {
    if stamp == "" {
        return "";
    }
    ms = new(Date).getTime() - new(Date, stamp).getTime();  # jac:ignore[E1053]
    days = ms / 86400000.0;
    if days < 1.0 {
        return "today";
    }
    if days < 30.0 {
        return str(Math.floor(days)) + "d ago";
    }
    return str(Math.floor(days / 30.0)) + "mo ago";
}
