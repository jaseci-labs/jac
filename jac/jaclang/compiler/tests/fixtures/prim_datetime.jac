"""Bundled native `datetime` cross-backend equivalence fixture (#6940 / #6951).

The SAME `import from datetime { datetime, timezone }` binds CPython's `datetime`
on the sv (Python) backend and the bundled `na_stdlib/datetime.jac` Mechanism-B
module on the na (native LLVM) backend. This is the consumer that exercises the
static-method (`datetime.fromtimestamp` / `datetime.now`) + class-attribute
(`timezone.utc`) capability from #6951.

A fixed timestamp pins the civil-from-epoch conversion EXACTLY (date, time,
weekday, isoformat). `now()` is non-deterministic, so only structural invariants
(sane calendar ranges) are compared, like the time fixture. ES/JS opts out.
"""

import from datetime { MINYEAR, UTC, date, datetime, time, timedelta, timezone }
import from calendar { isleap, leapdays, month, monthrange, timegm }
import from zoneinfo { ZoneInfo }


def datetime_py -> dict[any, any] {
    dt = datetime.fromtimestamp(1700000000.0, timezone.utc);
    # A pre-1970 (negative) POSIX timestamp pins the floor-division/modulo path:
    # 1969-12-30T23:59:59 UTC, a Tuesday (weekday 1).
    dt_neg = datetime.fromtimestamp(-86401.0, timezone.utc);
    now = datetime.now(timezone.utc);
    td = timedelta(days=1, seconds=3661, microseconds=42);
    d = date(2020, 2, 29);
    parsed = datetime.strptime("2020-02-29 13:45:07", "%Y-%m-%d %H:%M:%S");
    iso = datetime.fromisoformat("2020-02-29T13:45:07.123456+02:30");
    ny = ZoneInfo("America/New_York");
    aware = datetime(2021, 7, 4, 12, 0, 0, 0, ny);
    ioff = iso.utcoffset();
    aoff = aware.utcoffset();
    adst = aware.dst();
    ioff_s = ioff.seconds if ioff is not None else -1;
    aoff_s = (aoff.seconds + aoff.days * 86400) if aoff is not None else 0;
    adst_s = adst.seconds if adst is not None else -1;
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
        "td_str": str(td),
        "td_add": str(dt + td),
        "td_div": td // timedelta(seconds=1),
        "td_mul": str(td * 2),
        "date_ord": d.toordinal(),
        "date_iso": date.fromisocalendar(2020, 53, 5).isoformat(),
        "date_replace": d.replace(month=3).isoformat(),
        "iso_week": d.isocalendar().week,
        "strptime": parsed.isoformat(),
        "strptime_z": datetime.strptime("2020-02-29 +0130", "%Y-%m-%d %z").isoformat(),
        "fromiso": ioff_s,
        "fromiso_naive": datetime.fromisoformat("2020-02-29 13:45:07").isoformat(),
        "strftime_full": dt.strftime("%Y-%m-%d %H:%M:%S"),
        "strftime_names": d.strftime("%A %B %j"),
        "minyear": MINYEAR,
        "utc_eq": 1 if str(UTC) == str(timezone.utc) else 0,
        "cal_leap": 1 if isleap(2020) else 0,
        "cal_leapdays": leapdays(1900, 2021),
        "cal_range": monthrange(2021, 2)[1],
        "cal_month": month(2021, 2),
        "cal_timegm": timegm(d.timetuple()),
        "zi_off": aoff_s,
        "zi_name": aware.tzname(),
        "zi_dst": adst_s,
        "zi_key": ny.key,
        "zi_utc_conv": aware.astimezone(timezone.utc).isoformat(),
        "zi_tokyo": aware.astimezone(ZoneInfo("Asia/Tokyo")).isoformat(),
        "naive_ts": datetime.fromtimestamp(1700000000.0).isoformat(),
        "naive_neg_ts": datetime.fromtimestamp(-86401.0).isoformat(),

    };
}


def datetime_cl -> dict[any, any] {
    return {};
}


def datetime_na -> dict[str, any] {
    dt: datetime = datetime.fromtimestamp(1700000000.0, timezone.utc);
    dt_neg: datetime = datetime.fromtimestamp(-86401.0, timezone.utc);
    now: datetime = datetime.now(timezone.utc);
    td: timedelta = timedelta(days=1, seconds=3661, microseconds=42);
    d: date = date(2020, 2, 29);
    parsed: datetime = datetime.strptime("2020-02-29 13:45:07", "%Y-%m-%d %H:%M:%S");
    iso: datetime = datetime.fromisoformat("2020-02-29T13:45:07.123456+02:30");
    ny: ZoneInfo = ZoneInfo("America/New_York");
    aware: datetime = datetime(2021, 7, 4, 12, 0, 0, 0, ny);
    ioff: (timedelta | None) = iso.utcoffset();
    aoff: (timedelta | None) = aware.utcoffset();
    adst: (timedelta | None) = aware.dst();
    ioff_s: int = ioff.seconds if ioff is not None else -1;
    aoff_s: int = (aoff.seconds + aoff.days * 86400) if aoff is not None else 0;
    adst_s: int = adst.seconds if adst is not None else -1;
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
        "td_str": str(td),
        "td_add": str(dt + td),
        "td_div": td // timedelta(seconds=1),
        "td_mul": str(td * 2),
        "date_ord": d.toordinal(),
        "date_iso": date.fromisocalendar(2020, 53, 5).isoformat(),
        "date_replace": d.replace(month=3).isoformat(),
        "iso_week": d.isocalendar().week,
        "strptime": parsed.isoformat(),
        "strptime_z": datetime.strptime("2020-02-29 +0130", "%Y-%m-%d %z").isoformat(),
        "fromiso": ioff_s,
        "fromiso_naive": datetime.fromisoformat("2020-02-29 13:45:07").isoformat(),
        "strftime_full": dt.strftime("%Y-%m-%d %H:%M:%S"),
        "strftime_names": d.strftime("%A %B %j"),
        "minyear": MINYEAR,
        "utc_eq": 1 if str(UTC) == str(timezone.utc) else 0,
        "cal_leap": 1 if isleap(2020) else 0,
        "cal_leapdays": leapdays(1900, 2021),
        "cal_range": monthrange(2021, 2)[1],
        "cal_month": month(2021, 2),
        "cal_timegm": timegm(d.timetuple()),
        "zi_off": aoff_s,
        "zi_name": aware.tzname(),
        "zi_dst": adst_s,
        "zi_key": ny.key,
        "zi_utc_conv": aware.astimezone(timezone.utc).isoformat(),
        "zi_tokyo": aware.astimezone(ZoneInfo("Asia/Tokyo")).isoformat(),
        "naive_ts": datetime.fromtimestamp(1700000000.0).isoformat(),
        "naive_neg_ts": datetime.fromtimestamp(-86401.0).isoformat(),

    };
}
