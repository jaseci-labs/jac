import time;


obj timezone {
    has offset_min: int = 0;
    static has utc: timezone = timezone(offset_min=0);
}


obj datetime {
    has year: int = 1970,
        month: int = 1,
        day: int = 1,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        tz_offset_min: int = 0,
        epoch_day: int = 0;

    static def fromtimestamp(ts: float, tz: timezone) -> datetime {
        total: int = int(ts) + tz.offset_min * 60;
        days: int = _fdiv(total, 86400);
        sod: int = total - days * 86400;
        h: int = sod // 3600;
        mi: int = (sod // 60) % 60;
        s: int = sod % 60;

        z: int = days + 719468;
        era: int = z // 146097;
        doe: int = z - era * 146097;
        yoe: int = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365;
        y: int = yoe + era * 400;
        doy: int = doe - (365 * yoe + yoe // 4 - yoe // 100);
        mp: int = (5 * doy + 2) // 153;
        d: int = doy - (153 * mp + 2) // 5 + 1;
        m: int = mp + 3 if mp < 10 else mp - 9;
        yy: int = y + 1 if m <= 2 else y;
        return datetime(
            year=yy,
            month=m,
            day=d,
            hour=h,
            minute=mi,
            second=s,
            tz_offset_min=tz.offset_min,
            epoch_day=days
        );
    }

    static def now(tz: timezone) -> datetime {
        return datetime.fromtimestamp(time.time(), tz);
    }

    def weekday -> int {
        return _fmod(self.epoch_day + 3, 7);
    }

    def isoformat -> str {
        return (
            _pad4(self.year) + "-" + _pad2(self.month) + "-" + _pad2(self.day) + "T" + _pad2(
                self.hour
            ) + ":" + _pad2(self.minute) + ":" + _pad2(self.second) + _offset_str(
                self.tz_offset_min
            )
        );
    }
}


def _fdiv(a: int, b: int) -> int {
    q: int = a // b;
    if a % b != 0 and a < 0 {
        q = q - 1;
    }
    return q;
}


def _fmod(a: int, b: int) -> int {
    return (a % b + b) % b;
}


def _pad2(n: int) -> str {
    if n < 10 {
        return "0" + str(n);
    }
    return str(n);
}


def _pad4(n: int) -> str {
    if n < 10 {
        return "000" + str(n);
    }
    if n < 100 {
        return "00" + str(n);
    }
    if n < 1000 {
        return "0" + str(n);
    }
    return str(n);
}


def _offset_str(offset_min: int) -> str {
    o: int = offset_min;
    sign: str = "+";
    if o < 0 {
        sign = "-";
        o = -o;
    }
    return sign + _pad2(o // 60) + ":" + _pad2(o % 60);
}
