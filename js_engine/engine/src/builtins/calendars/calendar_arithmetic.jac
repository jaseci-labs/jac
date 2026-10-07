"""Calendar-aware Temporal date arithmetic — CalendarDateAdd / CalendarDateUntil.

Routes year/month arithmetic through the calendar field space so non-ISO
calendars (islamic, hebrew, chinese, coptic, …) add/subtract correctly.
ISO day arithmetic is calendar-agnostic and stays on the ISO path.
"""

import from engine.src.runtime.error {
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_iso {
    iso_add_days,
    iso_add_months,
    iso_days_from_ymd,
    iso_ymd_from_days,
    iso_days_in_month
}
import from engine.src.builtins.calendars.calendar_dispatch {
    calendar_iso_to_fields,
    calendar_fields_to_iso,
    calendar_months_in_year,
    calendar_days_in_month,
    calendar_id_normalize
}
import from engine.src.builtins.calendars.calendar_gregory {
    CF_YEAR,
    CF_MONTH,
    CF_DAY,
    CF_ERA,
    CF_ERA_YEAR,
    CF_MONTH_CODE,
    CF_IS_LEAP_MONTH
}
import from engine.src.builtins.calendars.calendar_chinese { chinese_leap_month }

def:priv _cal_is_iso_family(cal: str) -> bool {
    id: str = calendar_id_normalize(cal);
    return id == "iso8601" or id == "gregory";
}

"""Constrain or reject a calendar (year, month, day) per overflow mode.
Returns [y, m, d] in calendar field space. On reject failure, throws RangeError.
`m` must be the Temporal numeric/ordinal month (1..monthsInYear)."""
def:pub calendar_regulate(
    cal: str, y: int, m: int, d: int, overflow: str
) -> list[int] {
    miy: int = calendar_months_in_year(cal, y);
    if m < 1 {
        if overflow == "reject" {
            vm_throw_native(make_range_error("invalid date"));
            return [y, m, d];
        }
        m = 1;
    }
    if m > miy {
        if overflow == "reject" {
            vm_throw_native(make_range_error("invalid date"));
            return [y, m, d];
        }
        m = miy;
    }
    dim: int = calendar_days_in_month(cal, y, m);
    if d < 1 {
        if overflow == "reject" {
            vm_throw_native(make_range_error("invalid date"));
            return [y, m, d];
        }
        d = 1;
    }
    if d > dim {
        if overflow == "reject" {
            vm_throw_native(make_range_error("invalid date"));
            return [y, m, d];
        }
        d = dim;
    }
    return [y, m, d];
}

"""Build a minimal fields record for calendar_fields_to_iso from y/m/d."""
def:priv _cal_fields_from_ymd(
    y: int, m: int, d: int, era: int, era_y: int, leap_m: int
) -> list[int] {
    # Layout matches calendar_gregory CF_*. CF_MONTH_CODE = 0 signals that
    # `m` is already a Temporal numeric/ordinal month (arithmetic path) so
    # fields_to_iso must not re-apply monthCode→numeric remapping.
    return [y, m, 0, d, era, era_y, 0, 0, 0, 0, 0, leap_m];
}

"""Add years/months/weeks/days to an ISO date in the given calendar.
Returns [iso_y, iso_m, iso_d]. overflow is "constrain" or "reject"."""
def:pub calendar_date_add(
    iso_y: int,
    iso_m: int,
    iso_d: int,
    calendar_id: str,
    years: int,
    months: int,
    weeks: int,
    days: int,
    overflow: str
) -> list[int] {
    cal: str = calendar_id_normalize(calendar_id);
    if len(cal) == 0 {
        cal = "iso8601";
    }

    # Fast path: ISO-family calendars share Gregorian month structure.
    if _cal_is_iso_family(cal) {
        y: int = iso_y;
        m: int = iso_m;
        d: int = iso_d;
        delta_m: int = months + years * 12;
        if delta_m != 0 {
            orig_d: int = d;
            bal: list[int] = iso_add_months(y, m, d, delta_m);
            y = bal[0];
            m = bal[1];
            d = bal[2];
            if overflow == "reject" and orig_d > iso_days_in_month(y, m) {
                vm_throw_native(make_range_error("invalid date"));
                return [iso_y, iso_m, iso_d];
            }
        }
        day_delta: int = days + weeks * 7;
        if day_delta != 0 {
            bal2: list[int] = iso_add_days(y, m, d, day_delta);
            y = bal2[0];
            m = bal2[1];
            d = bal2[2];
        }
        return [y, m, d];
    }

    # Calendar-field path for non-ISO calendars.
    fields: list[int] = calendar_iso_to_fields(iso_y, iso_m, iso_d, cal);
    cy: int = fields[CF_YEAR];
    cm: int = fields[CF_MONTH];
    cd: int = fields[CF_DAY];
    mc_ord: int = fields[CF_MONTH_CODE];
    leap_m: int = 0;
    if len(fields) > CF_IS_LEAP_MONTH {
        leap_m = fields[CF_IS_LEAP_MONTH];
    }
    # Preserve monthCode across year adds (hebrew/chinese/dangi leap months).
    # Year units are applied first so leap-month reject runs even for P1Y1M.
    if years != 0 {
        cy = cy + years;
        if cal == "hebrew" {
            miy2: int = calendar_months_in_year(cal, cy);
            if leap_m != 0 {
                # M05L → month 6 (Adar I). Reject if destination year is common.
                if miy2 <= 12 {
                    if overflow == "reject" {
                        vm_throw_native(make_range_error("invalid date"));
                        return [iso_y, iso_m, iso_d];
                    }
                    cm = 6;
                    leap_m = 0;
                } else {
                    cm = 6;
                    leap_m = 1;
                }
            } else {
                # Re-resolve monthCode in destination year before any month add
                # (P1Y12M must not keep the source year's ordinal).
                if mc_ord <= 5 {
                    cm = mc_ord;
                } elif mc_ord == 6 {
                    if miy2 > 12 {
                        cm = 7;
                    } else {
                        cm = 6;
                    }
                } else {
                    if miy2 > 12 {
                        cm = mc_ord + 1;
                    } else {
                        cm = mc_ord;
                    }
                }
            }
        } elif cal == "chinese" or cal == "dangi" {
            dest_leap: int = chinese_leap_month(cy);
            if leap_m != 0 {
                if dest_leap == mc_ord and dest_leap > 0 {
                    cm = mc_ord + 1;
                    leap_m = 1;
                } else {
                    if overflow == "reject" {
                        vm_throw_native(make_range_error("invalid date"));
                        return [iso_y, iso_m, iso_d];
                    }
                    # Constrain leap monthCode to non-leap same code.
                    if dest_leap > 0 and mc_ord > dest_leap {
                        cm = mc_ord + 1;
                    } else {
                        cm = mc_ord;
                    }
                    leap_m = 0;
                }
            } else {
                # Map monthCode to ordinal in destination year (also before P1YnM).
                if dest_leap > 0 and mc_ord > dest_leap {
                    cm = mc_ord + 1;
                } else {
                    cm = mc_ord;
                }
            }
        }
    }

    # Add months in calendar space, carrying into years.
    if months != 0 {
        leap_m = 0;
        cm = cm + months;
        # Normalize month into [1, monthsInYear], adjusting year.
        # Loop to handle calendars whose monthsInYear varies by year.
        guard: int = 0;
        while guard < 10000 {
            miy: int = calendar_months_in_year(cal, cy);
            if cm >= 1 and cm <= miy {
                break;
            }
            if cm > miy {
                cm = cm - miy;
                cy = cy + 1;
            } else {
                # cm < 1: step back a year
                cy = cy - 1;
                prev_miy: int = calendar_months_in_year(cal, cy);
                cm = cm + prev_miy;
            }
            guard = guard + 1;
        }
    }

    # Regulate day against the new year/month (constrain or reject).
    reg: list[int] = calendar_regulate(cal, cy, cm, cd, overflow);
    if vm_has_native_exc() {
        return [iso_y, iso_m, iso_d];
    }
    cy = reg[0];
    cm = reg[1];
    cd = reg[2];

    # Convert via CF_YEAR (era=0): roc/japanese fields_to_iso otherwise trusts
    # a stale eraYear. Era is recomputed from the resulting ISO date if needed.
    iso_parts: list[int] = calendar_fields_to_iso(
        _cal_fields_from_ymd(cy, cm, cd, 0, 0, leap_m), cal
    );
    y2: int = iso_parts[0];
    m2: int = iso_parts[1];
    d2: int = iso_parts[2];
    day_delta2: int = days + weeks * 7;
    if day_delta2 != 0 {
        bal3: list[int] = iso_add_days(y2, m2, d2, day_delta2);
        y2 = bal3[0];
        m2 = bal3[1];
        d2 = bal3[2];
    }
    return [y2, m2, d2];
}

"""Difference between two ISO dates in calendar field space.
largest_unit is "year", "month", "week", or "day".
Returns [years, months, weeks, days] as signed ints (sign encoded in values)."""
def:pub calendar_date_until(
    iso_y1: int,
    iso_m1: int,
    iso_d1: int,
    iso_y2: int,
    iso_m2: int,
    iso_d2: int,
    calendar_id: str,
    largest_unit: str
) -> list[int] {
    cal: str = calendar_id_normalize(calendar_id);
    if len(cal) == 0 {
        cal = "iso8601";
    }

    # Day-level (and week-of-days) difference is calendar-agnostic.
    days_total: int = iso_days_from_ymd(iso_y2, iso_m2, iso_d2)
        - iso_days_from_ymd(iso_y1, iso_m1, iso_d1);

    if largest_unit == "day" {
        return [0, 0, 0, days_total];
    }
    if largest_unit == "week" {
        # Truncate toward zero (Jac // floors for negatives).
        if days_total >= 0 {
            w: int = days_total // 7;
            rem: int = days_total - w * 7;
            return [0, 0, w, rem];
        }
        abs_d: int = -days_total;
        w2: int = abs_d // 7;
        rem2: int = abs_d - w2 * 7;
        return [0, 0, -w2, -rem2];
    }

    # year / month largest unit. Sign of the overall difference (date1 → date2).
    sign: int = 1;
    if days_total < 0 {
        sign = -1;
    }
    if days_total == 0 {
        return [0, 0, 0, 0];
    }

    # DifferenceISODate (ECMA-402/Temporal). Compute DIRECTIONALLY from date1 → date2,
    # NOT via a reversed positive frame — the day-remainder depends on the length of the
    # month adjacent to date2 in the travel direction, so 2021-07-15 → 1997-07-16 must
    # borrow from June (30d) giving …-11M -30D, whereas the reverse frame borrows a
    # different month and is off by one. `sign` is +1 forward, -1 backward; every step
    # adds `count*sign` and we shrink the magnitude until the intermediate does not pass
    # date2 in the travel direction.
    end_days: int = iso_days_from_ymd(iso_y2, iso_m2, iso_d2);
    # Calendar fields for both endpoints (calendar year/month for non-iso8601).
    f1: list[int] = calendar_iso_to_fields(iso_y1, iso_m1, iso_d1, cal);
    f2: list[int] = calendar_iso_to_fields(iso_y2, iso_m2, iso_d2, cal);
    cy1: int = f1[CF_YEAR];
    cm1: int = f1[CF_MONTH];
    cy2: int = f2[CF_YEAR];
    cm2: int = f2[CF_MONTH];

    years: int = 0;
    months: int = 0;

    if largest_unit == "year" {
        years = cy2 - cy1;
        # Shrink years while adding `years*sign` overshoots date2 (passes it in the
        # travel direction). `overshoot` = sign * (intermediate_days - end_days) > 0.
        if years != 0 {
            trial: list[int] = calendar_date_add(
                iso_y1, iso_m1, iso_d1, cal, years, 0, 0, 0, "constrain"
            );
            if sign * (iso_days_from_ymd(trial[0], trial[1], trial[2]) - end_days)
                > 0 {
                years = years - sign;
            }
        }
        mid: list[int] = calendar_date_add(
            iso_y1, iso_m1, iso_d1, cal, years, 0, 0, 0, "constrain"
        );
        mf: list[int] = calendar_iso_to_fields(mid[0], mid[1], mid[2], cal);
        my: int = mf[CF_YEAR];
        mm: int = mf[CF_MONTH];
        months = (cy2 - my) * 12 + (cm2 - mm);
        if months != 0 {
            trial_m: list[int] = calendar_date_add(
                mid[0], mid[1], mid[2], cal, 0, months, 0, 0, "constrain"
            );
            if sign * (iso_days_from_ymd(trial_m[0], trial_m[1], trial_m[2]) - end_days)
                > 0 {
                months = months - sign;
            }
        }
        mid2: list[int] = calendar_date_add(
            mid[0], mid[1], mid[2], cal, 0, months, 0, 0, "constrain"
        );
        rem_days: int = end_days - iso_days_from_ymd(mid2[0], mid2[1], mid2[2]);
        return [years, months, 0, rem_days];
    }

    # largest_unit == "month"
    months = (cy2 - cy1) * 12 + (cm2 - cm1);
    if months != 0 {
        trial3: list[int] = calendar_date_add(
            iso_y1, iso_m1, iso_d1, cal, 0, months, 0, 0, "constrain"
        );
        if sign * (iso_days_from_ymd(trial3[0], trial3[1], trial3[2]) - end_days) > 0 {
            months = months - sign;
        }
    }
    mid3: list[int] = calendar_date_add(
        iso_y1, iso_m1, iso_d1, cal, 0, months, 0, 0, "constrain"
    );
    rem_d: int = end_days - iso_days_from_ymd(mid3[0], mid3[1], mid3[2]);
    return [0, months, 0, rem_d];
}
