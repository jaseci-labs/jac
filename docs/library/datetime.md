---
description: The native datetime and zoneinfo modules, as CPython's, with where time zones come from on each platform.
keywords: datetime, zoneinfo, datetime.datetime, datetime.date, datetime.time, datetime.timedelta, datetime.timezone, datetime.tzinfo, datetime.UTC, datetime.MINYEAR, datetime.MAXYEAR, zoneinfo.ZoneInfo, ZoneInfo, ZoneInfoNotFoundError, zoneinfo.TZPATH, zoneinfo.reset_tzpath, zoneinfo.available_timezones, PYTHONTZPATH, strftime, strptime, isoformat, fromisoformat
---
# datetime and zoneinfo

`datetime` has the date and time types of CPython's `datetime` (`date`, `time`, `datetime`,
`timedelta`, `tzinfo`, `timezone`, `UTC`, `MINYEAR`, `MAXYEAR`), and `zoneinfo` the IANA time
zones of CPython's `zoneinfo`, with CPython's arithmetic, text forms, exceptions and messages.
Both are native (see [The library](index.md), `jac docs library`).

```jac
import datetime;
import from datetime { date, timedelta, timezone }
import from zoneinfo { ZoneInfo }

with entry {
    d = date(2026, 11, 12);
    print(d, d.weekday(), d + timedelta(days=30), d.strftime("%A %d %B %Y"));
    t = datetime.datetime(2026, 3, 8, 1, 30, tzinfo=timezone.utc);
    print(t, t.timestamp(), t.isoformat());
    ny = t.astimezone(ZoneInfo("America/New_York"));
    print(ny, ny.tzname());
    print(datetime.datetime.strptime("2026-01-02 03:04", "%Y-%m-%d %H:%M"));
    print(datetime.datetime.fromisoformat("2026-05-06T07:08:09+05:30"));
    span = timedelta(hours=36, minutes=5);
    print(span, span.total_seconds(), span // timedelta(hours=1), timedelta(seconds=-1));
    held: date = t;
    print(held == d, held != d);
    try {
        print(held < d);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
2026-11-12 3 2026-12-12 Thursday 12 November 2026
2026-03-08 01:30:00+00:00 1772933400.0 2026-03-08T01:30:00+00:00
2026-03-07 20:30:00-05:00 EST
2026-01-02 03:04:00
2026-05-06 07:08:09+05:30
1 day, 12:05:00 129900.0 36 -1 day, 23:59:59
False True
TypeError: '<' not supported between instances of 'datetime.datetime' and 'datetime.date'
```

A `datetime` is a `date`, and compares as CPython's does with a plain one: never equal, and
ordering the two raises `TypeError`, whichever the variable's declared type.

The example needs the system's time-zone database, which Linux and macOS have (see
[Time zones](#time-zones) for Windows).

## What is there

All of CPython's interface (`scripts/stdlib_surface.py` counts every name of the stub):

- `date`: `today`, `fromtimestamp`, `fromordinal`, `fromisoformat`, `fromisocalendar`,
  `strptime`, `replace`, `toordinal`, `weekday`, `isoweekday`, `isocalendar`, `isoformat`,
  `strftime`, `ctime`, `timetuple`, arithmetic with `timedelta`, comparison, `min`, `max`.
- `time` and `datetime`: the same where they apply, and `now`, `utcnow`, `combine`,
  `timestamp`, `astimezone`, `utcoffset`, `dst`, `tzname`, `fold`.
- `timedelta`: `days`, `seconds`, `microseconds`, `total_seconds`, arithmetic with ints, floats
  and other timedeltas, negative values normalized as CPython does (`-1 day, 23:59:59`).
- `timezone(offset, name=None)`, `timezone.utc`, `UTC`; a fixed offset is named `UTC+05:30`.
  Aware datetimes in different zones compare and subtract by the instant they name: 12:00 UTC
  equals 13:00 at UTC+01:00.
- `strftime` and `strptime` take `%Y %m %d %H %M %S %f %j %a %b %A %B %I %p %y %z %Z %%`, in
  English, as the C locale has them.

## Time zones

`ZoneInfo(key)` reads a compiled zone (a TZif file) from the first directory of `zoneinfo.TZPATH`
that has it, and applies its transitions, its rule for later years and `fold` for ambiguous
times, as CPython does. `ZoneInfo.no_cache`, `ZoneInfo.clear_cache`, `reset_tzpath`,
`available_timezones` and `ZoneInfoNotFoundError` are CPython's.

`TZPATH` comes from the `PYTHONTZPATH` environment variable (absolute directories, separated by
`os.pathsep`), else from the default search path:

| Platform | Default search path |
|---|---|
| Linux, macOS | `/usr/share/zoneinfo`, `/usr/lib/zoneinfo`, `/usr/share/lib/zoneinfo`, `/etc/zoneinfo` |
| Windows | None. Windows has no tz database, as CPython's Windows build has none: set `PYTHONTZPATH`, or `reset_tzpath([...])`, to a directory of TZif files |

A key that is found nowhere raises `ZoneInfoNotFoundError` (a `KeyError`); a key that would
escape the search path, or a relative directory in `TZPATH`, raises `ValueError`. CPython's
`tzdata` package, its fallback when no directory has the zone, is not available natively.

## Differences from CPython

- **`timedelta / timedelta` is typed `timedelta | float`**, since the same operator divides a
  timedelta by a number. Give the quotient a type where it is used, by assigning it to an
  annotated name or with `as`:

```jac
import from datetime { timedelta }

with entry {
    quarters: float = timedelta(days=1) / timedelta(hours=6);
    thirds = (timedelta(hours=1) / timedelta(minutes=20)) as float;
    print(quarters, thirds + 1.0);
}
```

```output
4.0 4.0
```

- **No warnings**: `utcnow()` and `utcfromtimestamp()` run without CPython's
  `DeprecationWarning`, as no module issues warnings (see [The library](index.md)).
