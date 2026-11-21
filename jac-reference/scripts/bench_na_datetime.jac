"""Per-method microbenchmark for the bundled native datetime/calendar/zoneinfo.

Runs unchanged on both lanes: `jac run -b python` binds CPython's modules
(baseline) and `jac run -b native` binds na_stdlib. Each op is timed over a
fixed iteration count with datetime.now() (microsecond resolution via
clock_gettime on the native lane) and reported as us/op.
"""

import from datetime { date, datetime, timedelta, timezone }
import from calendar { isleap, leapdays, month, monthrange, timegm }
import from zoneinfo { ZoneInfo }


glob _best: dict[str, float] = {},
     _labels: list[str] = [];

def emit(label: str, n: int, t0: datetime) {
    us: float = ((datetime.now() - t0) as timedelta).total_seconds() * 1000000.0 / n;
    cur: (float | None) = _best.get(label);
    if cur is None {
        _labels.append(label);
        _best[label] = us;
    } elif us < cur {
        _best[label] = us;
    }
}


with entry {
    i: int = 0;
    t: datetime = datetime.now();
    d0: date = date(2020, 2, 29);
    dt0: datetime = datetime(2021, 7, 4, 12, 0, 0, 0, timezone.utc);
    td1: timedelta = timedelta(days=1, seconds=3661, microseconds=42);
    ny: ZoneInfo = ZoneInfo("America/New_York");
    aware: datetime = datetime(2021, 7, 4, 12, 0, 0, 0, ny);
    tup: any = d0.timetuple();

    round: int = 0;
    while round < 3 {
        i = 0;
        t = datetime.now();
        while i < 2000 {
            date(2020, 2, 29);
            i += 1;
        }
        emit("date.ctor", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 10000 {
            d0.toordinal();
            i += 1;
        }
        emit("date.toordinal", 10000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            date.fromordinal(738885);
            i += 1;
        }
        emit("date.fromordinal", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            d0.isoformat();
            i += 1;
        }
        emit("date.isoformat", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            d0.weekday();
            i += 1;
        }
        emit("date.weekday", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            d0.isocalendar();
            i += 1;
        }
        emit("date.isocalendar", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            d0.timetuple();
            i += 1;
        }
        emit("date.timetuple", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            d0.replace(month=3);
            i += 1;
        }
        emit("date.replace", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 2000 {
            timedelta(days=1, seconds=3661, microseconds=42);
            i += 1;
        }
        emit("timedelta.ctor", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            td1 + td1;
            i += 1;
        }
        emit("timedelta.add", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            td1 * 2;
            i += 1;
        }
        emit("timedelta.mul", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            td1 // timedelta(seconds=1);
            i += 1;
        }
        emit("timedelta.floordiv", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            td1.total_seconds();
            i += 1;
        }
        emit("timedelta.total_seconds", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            str(td1);
            i += 1;
        }
        emit("timedelta.str", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 1000 {
            datetime.now();
            i += 1;
        }
        emit("datetime.now", 1000, t);

        i = 0;
        t = datetime.now();
        while i < 2000 {
            datetime.fromtimestamp(1700000000.0, timezone.utc);
            i += 1;
        }
        emit("datetime.fromtimestamp", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            dt0.isoformat();
            i += 1;
        }
        emit("datetime.isoformat", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 2000 {
            datetime.fromisoformat("2020-02-29T13:45:07.123456+02:30");
            i += 1;
        }
        emit("datetime.fromisoformat", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 1000 {
            datetime.strptime("2020-02-29 13:45:07", "%Y-%m-%d %H:%M:%S");
            i += 1;
        }
        emit("datetime.strptime", 1000, t);

        i = 0;
        t = datetime.now();
        while i < 2000 {
            dt0.strftime("%Y-%m-%d %H:%M:%S");
            i += 1;
        }
        emit("datetime.strftime", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            dt0 + td1;
            i += 1;
        }
        emit("datetime.add", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            dt0 - dt0;
            i += 1;
        }
        emit("datetime.sub", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            dt0.replace(month=3);
            i += 1;
        }
        emit("datetime.replace", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 5000 {
            aware.utcoffset();
            i += 1;
        }
        emit("datetime.utcoffset+ZoneInfo", 5000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            aware.astimezone(timezone.utc);
            i += 1;
        }
        emit("datetime.astimezone", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 2000 {
            ZoneInfo("America/New_York");
            i += 1;
        }
        emit("ZoneInfo.ctor(cached)", 2000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            aware.tzname();
            i += 1;
        }
        emit("ZoneInfo.tzname", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            aware.dst();
            i += 1;
        }
        emit("ZoneInfo.dst", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 3000 {
            ny.fromutc(aware);
            i += 1;
        }
        emit("ZoneInfo.fromutc", 3000, t);

        i = 0;
        t = datetime.now();
        while i < 50000 {
            isleap(2020);
            i += 1;
        }
        emit("calendar.isleap", 50000, t);

        i = 0;
        t = datetime.now();
        while i < 20000 {
            leapdays(1900, 2021);
            i += 1;
        }
        emit("calendar.leapdays", 20000, t);

        i = 0;
        t = datetime.now();
        while i < 20000 {
            monthrange(2021, 2);
            i += 1;
        }
        emit("calendar.monthrange", 20000, t);

        i = 0;
        t = datetime.now();
        while i < 1000 {
            month(2021, 2);
            i += 1;
        }
        emit("calendar.month", 1000, t);

        i = 0;
        t = datetime.now();
        while i < 10000 {
            timegm(tup);
            i += 1;
        }
        emit("calendar.timegm", 10000, t);

        round += 1;
    }

    for label in _labels {
        print(label, "|", _best[label], "|us/op");
    }
}
