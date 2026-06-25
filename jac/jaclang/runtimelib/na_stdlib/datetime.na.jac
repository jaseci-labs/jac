"""Bundled native `datetime` (UTC, no tz database) -- pure-Jac Mechanism-B
standard library (issues #6940 / #6951).

On the native (na) pathway `import from datetime { datetime, timezone }` resolves
to this module through the shared bundled-stdlib resolver; on the sv/Python
pathway the identical import binds CPython's real `datetime`. The two are held
congruent by the tri-backend equivalence suite (prim_datetime.jac).

This rides the static-method + class-attribute capability added for #6951:
`timezone.utc` is a class attribute (`static has`) and `datetime.now` /
`datetime.fromtimestamp` are class-level constructors (`static def`). The civil
date is computed from the POSIX epoch with Howard Hinnant's days->civil
algorithm over the existing `time` intercept, so it is exact and deterministic
for a fixed timestamp.

SCOPE: UTC (and fixed-offset `timezone`) only -- there is no tz database, no
DST, and no leap seconds, matching the workload's needs (#6940). `now()` returns
whole-second precision (no microseconds).
"""

import time;


"""A fixed UTC offset in minutes. `timezone.utc` is the zero-offset singleton."""
obj timezone {
    has offset_min: int = 0;
    static has utc: timezone = timezone(offset_min=0);
}


"""A timezone-aware civil datetime. Construct via `now`/`fromtimestamp`; fields
mirror CPython's `datetime` (year/month/day/hour/minute/second)."""
obj datetime {
    has year: int = 1970,
        month: int = 1,
        day: int = 1,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        tz_offset_min: int = 0,
        epoch_day: int = 0;

    """Civil datetime for POSIX timestamp `ts` in timezone `tz` (datetime.
    fromtimestamp). UTC when `tz` is `timezone.utc`."""
    static def fromtimestamp(ts: float, tz: timezone) -> datetime {
        total: int = int(ts) + tz.offset_min * 60;
        days: int = total // 86400;
        sod: int = total - days * 86400;  # seconds of the (local) day, 0..86399
        h: int = sod // 3600;
        mi: int = (sod // 60) % 60;
        s: int = sod % 60;
        # days -> civil (year, month, day). Hinnant's algorithm, shifting the
        # era to start 0000-03-01 so leap days fall at the end of the era.
        z: int = days + 719468;
        era: int = z // 146097;
        doe: int = z - era * 146097;  # day-of-era, 0..146096
        yoe: int = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365;
        y: int = yoe + era * 400;
        doy: int = doe - (365 * yoe + yoe // 4 - yoe // 100);  # day-of-year (Mar 1)
        mp: int = (5 * doy + 2) // 153;  # month shifted so March = 0
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

    """Current civil datetime in timezone `tz` (datetime.now), whole seconds."""
    static def now(tz: timezone) -> datetime {
        return datetime.fromtimestamp(time.time(), tz);
    }

    """Day of week, Monday=0 .. Sunday=6 (datetime.weekday). 1970-01-01 was a
    Thursday (epoch day 0 -> 3)."""
    def weekday -> int {
        return (self.epoch_day + 3) % 7;
    }

    """ISO 8601 string `YYYY-MM-DDThh:mm:ss+/-hh:mm` (datetime.isoformat)."""
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


"""`n` (>= 0) as a two-digit zero-padded string."""
def _pad2(n: int) -> str {
    if n < 10 {
        return "0" + str(n);
    }
    return str(n);
}


"""`n` (>= 0) as a four-digit zero-padded string."""
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


"""Format a fixed UTC offset (in minutes) as `+/-hh:mm` (CPython's aware-datetime
isoformat suffix; `+00:00` for UTC)."""
def _offset_str(offset_min: int) -> str {
    o: int = offset_min;
    sign: str = "+";
    if o < 0 {
        sign = "-";
        o = -o;
    }
    return sign + _pad2(o // 60) + ":" + _pad2(o % 60);
}
