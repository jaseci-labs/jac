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
        days: int = total // 86400;
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
        return (self.epoch_day + 3) % 7;
    }

    def isoformat -> str {
        return (
            _padn(self.year, 4)
            + "-"
            + _padn(self.month, 2)
            + "-"
            + _padn(self.day, 2)
            + "T"
            + _padn(self.hour, 2)
            + ":"
            + _padn(self.minute, 2)
            + ":"
            + _padn(self.second, 2)
            + _offset_str(self.tz_offset_min)
        );
    }
}


def _padn(n: int, width: int) -> str {
    s = str(n);
    return "0" * (width - len(s)) + s;
}


def _offset_str(offset_min: int) -> str {
    o: int = offset_min;
    sign: str = "+";
    if o < 0 {
        sign = "-";
        o = -o;
    }
    return sign + _padn(o // 60, 2) + ":" + _padn(o % 60, 2);
}
