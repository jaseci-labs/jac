"""Datetime: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import from datetime { datetime, timezone }


def datetime_py() -> dict[any, any] {
    dt = datetime.fromtimestamp(1700000000.0, timezone.utc);
    # A pre-1970 (negative) POSIX timestamp pins the floor-division/modulo path:
    # 1969-12-30T23:59:59 UTC, a Tuesday (weekday 1).
    dt_neg = datetime.fromtimestamp(-86401.0, timezone.utc);
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
        "neg_year": dt_neg.year,
        "neg_month": dt_neg.month,
        "neg_day": dt_neg.day,
        "neg_hour": dt_neg.hour,
        "neg_minute": dt_neg.minute,
        "neg_second": dt_neg.second,
        "neg_weekday": dt_neg.weekday(),
        "neg_iso": dt_neg.isoformat(),
        "now_year_ok": 1 if now.year >= 2024 else 0,
        "now_month_ok": 1 if now.month >= 1 and now.month <= 12 else 0,
        "now_day_ok": 1 if now.day >= 1 and now.day <= 31 else 0,
        "now_hour_ok": 1 if now.hour >= 0 and now.hour <= 23 else 0,
        "now_minute_ok": 1 if now.minute >= 0 and now.minute <= 59 else 0,
        "now_second_ok": 1 if now.second >= 0 and now.second <= 59 else 0,
        "now_weekday_ok": 1 if now.weekday() >= 0 and now.weekday() <= 6 else 0,

    };
}


def datetime_cl() -> dict[any, any] {
    return {};
}


def datetime_na() -> dict[str, any] {
    dt: datetime = datetime.fromtimestamp(1700000000.0, timezone.utc);
    dt_neg: datetime = datetime.fromtimestamp(-86401.0, timezone.utc);
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
        "neg_year": dt_neg.year,
        "neg_month": dt_neg.month,
        "neg_day": dt_neg.day,
        "neg_hour": dt_neg.hour,
        "neg_minute": dt_neg.minute,
        "neg_second": dt_neg.second,
        "neg_weekday": dt_neg.weekday(),
        "neg_iso": dt_neg.isoformat(),
        "now_year_ok": 1 if now.year >= 2024 else 0,
        "now_month_ok": 1 if now.month >= 1 and now.month <= 12 else 0,
        "now_day_ok": 1 if now.day >= 1 and now.day <= 31 else 0,
        "now_hour_ok": 1 if now.hour >= 0 and now.hour <= 23 else 0,
        "now_minute_ok": 1 if now.minute >= 0 and now.minute <= 59 else 0,
        "now_second_ok": 1 if now.second >= 0 and now.second <= 59 else 0,
        "now_weekday_ok": 1 if now.weekday() >= 0 and now.weekday() <= 6 else 0,

    };
}
