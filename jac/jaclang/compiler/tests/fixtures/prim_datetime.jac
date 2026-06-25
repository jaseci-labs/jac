"""Bundled native `datetime` cross-backend equivalence fixture (#6940 / #6951).

The SAME `import from datetime { datetime, timezone }` binds CPython's `datetime`
on the sv (Python) backend and the bundled `na_stdlib/datetime.na.jac` Mechanism-B
module on the na (native LLVM) backend. This is the consumer that exercises the
static-method (`datetime.fromtimestamp` / `datetime.now`) + class-attribute
(`timezone.utc`) capability from #6951.

A fixed timestamp pins the civil-from-epoch conversion EXACTLY (date, time,
weekday, isoformat). `now()` is non-deterministic, so only structural invariants
(sane calendar ranges) are compared, like the time fixture. ES/JS opts out.
"""

import from datetime { datetime, timezone }


def datetime_py() -> dict {
    dt = datetime.fromtimestamp(1700000000.0, timezone.utc);
    now = datetime.now(timezone.utc);
    return {
        "year": dt.year,
        "month": dt.month,
        "day": dt.day,
        "hour": dt.hour,
        "minute": dt.minute,
        "second": dt.second,
        "weekday": dt.weekday(),
        "iso": dt.isoformat(),
        "now_year_ok": 1 if now.year >= 2024 else 0,
        "now_month_ok": 1 if now.month >= 1 and now.month <= 12 else 0,
        "now_day_ok": 1 if now.day >= 1 and now.day <= 31 else 0,
        "now_hour_ok": 1 if now.hour >= 0 and now.hour <= 23 else 0,
        "now_minute_ok": 1 if now.minute >= 0 and now.minute <= 59 else 0,
        "now_second_ok": 1 if now.second >= 0 and now.second <= 59 else 0,
        "now_weekday_ok": 1 if now.weekday() >= 0 and now.weekday() <= 6 else 0,

    };
}


cl def datetime_cl() -> dict {
    return {};
}


na {
    def datetime_na() -> dict[str, any] {
        dt: datetime = datetime.fromtimestamp(1700000000.0, timezone.utc);
        now: datetime = datetime.now(timezone.utc);
        return {
            "year": dt.year,
            "month": dt.month,
            "day": dt.day,
            "hour": dt.hour,
            "minute": dt.minute,
            "second": dt.second,
            "weekday": dt.weekday(),
            "iso": dt.isoformat(),
            "now_year_ok": 1 if now.year >= 2024 else 0,
            "now_month_ok": 1 if now.month >= 1 and now.month <= 12 else 0,
            "now_day_ok": 1 if now.day >= 1 and now.day <= 31 else 0,
            "now_hour_ok": 1 if now.hour >= 0 and now.hour <= 23 else 0,
            "now_minute_ok": 1 if now.minute >= 0 and now.minute <= 59 else 0,
            "now_second_ok": 1 if now.second >= 0 and now.second <= 59 else 0,
            "now_weekday_ok": 1 if now.weekday() >= 0 and now.weekday() <= 6 else 0,

        };
    }
}
