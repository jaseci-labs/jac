import sys;
import from datetime { date, struct_time }

glob:pub JANUARY: int = 1,
     FEBRUARY: int = 2,
     MARCH: int = 3,
     APRIL: int = 4,
     MAY: int = 5,
     JUNE: int = 6,
     JULY: int = 7,
     AUGUST: int = 8,
     SEPTEMBER: int = 9,
     OCTOBER: int = 10,
     NOVEMBER: int = 11,
     DECEMBER: int = 12,
     MONDAY: int = 0,
     TUESDAY: int = 1,
     WEDNESDAY: int = 2,
     THURSDAY: int = 3,
     FRIDAY: int = 4,
     SATURDAY: int = 5,
     SUNDAY: int = 6;

glob mdays: list[int] = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

glob:pub month_name: list[str] = [
         "",
         "January",
         "February",
         "March",
         "April",
         "May",
         "June",
         "July",
         "August",
         "September",
         "October",
         "November",
         "December"
     ],
     month_abbr: list[str] = [
         "",
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     day_name: list[str] = [
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday",
         "Sunday"
     ],
     day_abbr: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];


obj:pub IllegalMonthError(ValueError) {
    has month: int = 0;

    def init(month: int) {
        self.month = month;
    }

    def __str__ -> str {
        return "bad month number " + str(self.month) + "; must be 1-12";
    }
}


obj:pub IllegalWeekdayError(ValueError) {
    has weekday: int = 0;

    def init(weekday: int) {
        self.weekday = weekday;
    }

    def __str__ -> str {
        return "bad weekday number "
            + str(self.weekday)
            + "; must be 0 (Monday) to 6 (Sunday)";
    }
}


def:pub isleap(year: int) -> bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}


def:pub leapdays(y1_in: int, y2_in: int) -> int {
    y1: int = y1_in - 1;
    y2: int = y2_in - 1;
    return (y2 // 4 - y1 // 4) - (y2 // 100 - y1 // 100) + (y2 // 400 - y1 // 400);
}


def:pub weekday(year_in: int, month: int, day: int) -> int {
    year: int = year_in;
    if not (1 <= year and year <= 9999) {
        year = 2000 + year % 400;
    }
    return date(year, month, day).weekday();
}


def _validate_month(month: int) {
    if not (1 <= month and month <= 12) {
        raise IllegalMonthError(month);
    }
}


def _monthlen(year: int, month: int) -> int {
    n: int = mdays[month];
    if month == 2 and isleap(year) {
        n += 1;
    }
    return n;
}


def:pub monthrange(year: int, month: int) -> tuple[(int, int)] {
    _validate_month(month);
    day1: int = weekday(year, month, 1);
    ndays: int = _monthlen(year, month);
    return (day1, ndays);
}


def _prevmonth(year: int, month: int) -> tuple[(int, int)] {
    if month == 1 {
        return (year - 1, 12);
    }
    return (year, month - 1);
}


def _nextmonth(year: int, month: int) -> tuple[(int, int)] {
    if month == 12 {
        return (year + 1, 1);
    }
    return (year, month + 1);
}


obj:pub Calendar {
    has _firstweekday: int = 0;

    def init(firstweekday: int = 0) {
        self._firstweekday = firstweekday;
    }

    def getfirstweekday -> int {
        return self._firstweekday % 7;
    }

    def setfirstweekday(firstweekday: int) {
        self._firstweekday = firstweekday;
    }

    def iterweekdays -> list[int] {
        result: list[int] = [];
        i: int = self.getfirstweekday();
        while i < self.getfirstweekday() + 7 {
            result.append(i % 7);
            i += 1;
        }
        return result;
    }

    def itermonthdates(year: int, month: int) -> list[date] {
        result: list[date] = [];
        tups: list[tuple[(int, int, int)]] = self.itermonthdays3(year, month);
        for t in tups {
            (y, m, d) = t;
            result.append(date(y, m, d));
        }
        return result;
    }

    def itermonthdays(year: int, month: int) -> list[int] {
        (day1, ndays) = monthrange(year, month);
        days_before: int = (day1 - self.getfirstweekday()) % 7;
        days_after: int = (self.getfirstweekday() - day1 - ndays) % 7;
        result: list[int] = [];
        i: int = 0;
        while i < days_before {
            result.append(0);
            i += 1;
        }
        d: int = 1;
        while d <= ndays {
            result.append(d);
            d += 1;
        }
        i = 0;
        while i < days_after {
            result.append(0);
            i += 1;
        }
        return result;
    }

    def itermonthdays2(year: int, month: int) -> list[tuple[(int, int)]] {
        result: list[tuple[(int, int)]] = [];
        days: list[int] = self.itermonthdays(year, month);
        i: int = self.getfirstweekday();
        for d in days {
            result.append((d, i % 7));
            i += 1;
        }
        return result;
    }

    def itermonthdays3(year: int, month: int) -> list[tuple[(int, int, int)]] {
        (day1, ndays) = monthrange(year, month);
        days_before: int = (day1 - self.getfirstweekday()) % 7;
        days_after: int = (self.getfirstweekday() - day1 - ndays) % 7;
        result: list[tuple[(int, int, int)]] = [];
        (py, pm) = _prevmonth(year, month);
        pend: int = _monthlen(py, pm) + 1;
        d: int = pend - days_before;
        while d < pend {
            result.append((py, pm, d));
            d += 1;
        }
        d = 1;
        while d <= ndays {
            result.append((year, month, d));
            d += 1;
        }
        (ny, nm) = _nextmonth(year, month);
        d = 1;
        while d <= days_after {
            result.append((ny, nm, d));
            d += 1;
        }
        return result;
    }

    def itermonthdays4(year: int, month: int) -> list[tuple[(int, int, int, int)]] {
        result: list[tuple[(int, int, int, int)]] = [];
        tups: list[tuple[(int, int, int)]] = self.itermonthdays3(year, month);
        i: int = 0;
        for t in tups {
            (y, m, d) = t;
            result.append((y, m, d, (self.getfirstweekday() + i) % 7));
            i += 1;
        }
        return result;
    }

    def monthdatescalendar(year: int, month: int) -> list[list[date]] {
        dates: list[date] = self.itermonthdates(year, month);
        result: list[list[date]] = [];
        i: int = 0;
        while i < len(dates) {
            result.append(dates[i:i + 7]);
            i += 7;
        }
        return result;
    }

    def monthdays2calendar(year: int, month: int) -> list[list[tuple[(int, int)]]] {
        days: list[tuple[(int, int)]] = self.itermonthdays2(year, month);
        result: list[list[tuple[(int, int)]]] = [];
        i: int = 0;
        while i < len(days) {
            result.append(days[i:i + 7]);
            i += 7;
        }
        return result;
    }

    def monthdayscalendar(year: int, month: int) -> list[list[int]] {
        days: list[int] = self.itermonthdays(year, month);
        result: list[list[int]] = [];
        i: int = 0;
        while i < len(days) {
            result.append(days[i:i + 7]);
            i += 7;
        }
        return result;
    }

    def yeardatescalendar(year: int, width: int = 3) -> list[list[list[list[date]]]] {
        months: list[list[list[date]]] = [];
        m: int = 1;
        while m <= 12 {
            months.append(self.monthdatescalendar(year, m));
            m += 1;
        }
        result: list[list[list[list[date]]]] = [];
        i: int = 0;
        while i < 12 {
            result.append(months[i:i + width]);
            i += width;
        }
        return result;
    }

    def yeardays2calendar(
        year: int, width: int = 3
    ) -> list[list[list[list[tuple[(int, int)]]]]] {
        months: list[list[list[tuple[(int, int)]]]] = [];
        m: int = 1;
        while m <= 12 {
            months.append(self.monthdays2calendar(year, m));
            m += 1;
        }
        result: list[list[list[list[tuple[(int, int)]]]]] = [];
        i: int = 0;
        while i < 12 {
            result.append(months[i:i + width]);
            i += width;
        }
        return result;
    }

    def yeardayscalendar(year: int, width: int = 3) -> list[list[list[list[int]]]] {
        months: list[list[list[int]]] = [];
        m: int = 1;
        while m <= 12 {
            months.append(self.monthdayscalendar(year, m));
            m += 1;
        }
        result: list[list[list[list[int]]]] = [];
        i: int = 0;
        while i < 12 {
            result.append(months[i:i + width]);
            i += width;
        }
        return result;
    }
}


def _center(s: str, width: int) -> str {
    if len(s) >= width {
        return s;
    }
    total: int = width - len(s);
    left: int = total // 2 + (1 if total % 2 == 1 and width % 2 == 1 else 0);
    out: str = s;
    i: int = 0;
    while i < left {
        out = " " + out;
        i += 1;
    }
    while len(out) < width {
        out += " ";
    }
    return out;
}


def _rstrip(s: str) -> str {
    out: str = s;
    while len(out) > 0 and out[len(out) - 1] == " " {
        out = out[0:len(out) - 1];
    }
    return out;
}


def _rep(s: str, n: int) -> str {
    out: str = "";
    i: int = 0;
    while i < n {
        out += s;
        i += 1;
    }
    return out;
}


obj:pub TextCalendar(Calendar) {
    def prweek(theweek: list[tuple[(int, int)]], width: int) {
        sys.stdout.write(self.formatweek(theweek, width));
    }

    def formatday(day: int, weekday: int, width: int) -> str {
        s: str = "";
        if day != 0 {
            if day < 10 {
                s = " " + str(day);
            } else {
                s = str(day);
            }
        }
        return _center(s, width);
    }

    def formatweek(theweek: list[tuple[(int, int)]], width: int) -> str {
        parts: list[str] = [];
        for t in theweek {
            (d, wd) = t;
            parts.append(self.formatday(d, wd, width));
        }
        return " ".join(parts);
    }

    def formatweekday(day: int, width: int) -> str {
        names: list[str] = day_name if width >= 9 else day_abbr;
        return _center(names[day][0:width], width);
    }

    def formatweekheader(width: int) -> str {
        parts: list[str] = [];
        for i in self.iterweekdays() {
            parts.append(self.formatweekday(i, width));
        }
        return " ".join(parts);
    }

    def formatmonthname(
        theyear: int, themonth: int, width: int, withyear: bool = True
    ) -> str {
        _validate_month(themonth);
        s: str = month_name[themonth];
        if withyear {
            s = s + " " + str(theyear);
        }
        return _center(s, width);
    }

    def prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0) {
        sys.stdout.write(self.formatmonth(theyear, themonth, w, l));
    }

    def formatmonth(theyear: int, themonth: int, w_in: int = 0, l_in: int = 0) -> str {
        w: int = w_in;
        if w < 2 {
            w = 2;
        }
        l: int = l_in;
        if l < 1 {
            l = 1;
        }
        s: str = self.formatmonthname(theyear, themonth, 7 * (w + 1) - 1);
        s = _rstrip(s);
        s += _rep("\n", l);
        s += _rstrip(self.formatweekheader(w));
        s += _rep("\n", l);
        weeks: list[list[tuple[(int, int)]]] = self.monthdays2calendar(
            theyear, themonth
        );
        for week in weeks {
            s += _rstrip(self.formatweek(week, w));
            s += _rep("\n", l);
        }
        return s;
    }

    def formatyear(
        theyear: int, w_in: int = 2, l_in: int = 1, c_in: int = 6, m: int = 3
    ) -> str {
        w: int = w_in;
        if w < 2 {
            w = 2;
        }
        l: int = l_in;
        if l < 1 {
            l = 1;
        }
        c: int = c_in;
        if c < 2 {
            c = 2;
        }
        colwidth: int = (w + 1) * 7 - 1;
        v: list[str] = [];
        v.append(_rstrip(_center(str(theyear), colwidth * m + c * (m - 1))));
        v.append(_rep("\n", l));
        header: str = self.formatweekheader(w);
        rows: list[list[list[list[tuple[(int, int)]]]]] = self.yeardays2calendar(
            theyear, m
        );
        i: int = 0;
        for row in rows {
            months: list[int] = [];
            k: int = m * i + 1;
            mend: int = m * (i + 1) + 1;
            if mend > 13 {
                mend = 13;
            }
            while k < mend {
                months.append(k);
                k += 1;
            }
            v.append(_rep("\n", l));
            names: list[str] = [];
            for k2 in months {
                names.append(self.formatmonthname(theyear, k2, colwidth, False));
            }
            v.append(_rstrip(formatstring(names, colwidth, c)));
            v.append(_rep("\n", l));
            headers: list[str] = [];
            for k2 in months {
                headers.append(header);
            }
            v.append(_rstrip(formatstring(headers, colwidth, c)));
            v.append(_rep("\n", l));
            height: int = 0;
            for cal in row {
                if len(cal) > height {
                    height = len(cal);
                }
            }
            j: int = 0;
            while j < height {
                weeks: list[str] = [];
                for cal in row {
                    if j >= len(cal) {
                        weeks.append("");
                    } else {
                        weeks.append(self.formatweek(cal[j], w));
                    }
                }
                v.append(_rstrip(formatstring(weeks, colwidth, c)));
                v.append(_rep("\n", l));
                j += 1;
            }
            i += 1;
        }
        return "".join(v);
    }

    def pryear(theyear: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3) {
        sys.stdout.write(self.formatyear(theyear, w, l, c, m));
    }
}


def formatstring(cols: list[str], colwidth: int = 20, spacing: int = 6) -> str {
    parts: list[str] = [];
    for cl in cols {
        parts.append(_center(cl, colwidth));
    }
    return _rep(" ", spacing).join(parts);
}


glob _c: TextCalendar = TextCalendar();


def:pub firstweekday -> int {
    return _c.getfirstweekday();
}


def:pub setfirstweekday(firstweekday: int) {
    if not (0 <= firstweekday and firstweekday <= 6) {
        raise IllegalWeekdayError(firstweekday);
    }
    _c.setfirstweekday(firstweekday);
}


def:pub monthcalendar(year: int, month: int) -> list[list[int]] {
    return _c.monthdayscalendar(year, month);
}


def:pub prweek(theweek: list[tuple[(int, int)]], width: int) {
    _c.prweek(theweek, width);
}


def:pub week(theweek: list[tuple[(int, int)]], width: int) -> str {
    return _c.formatweek(theweek, width);
}


def:pub weekheader(width: int) -> str {
    return _c.formatweekheader(width);
}


def:pub prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0) {
    _c.prmonth(theyear, themonth, w, l);
}


def:pub month(theyear: int, themonth: int, w: int = 0, l: int = 0) -> str {
    return _c.formatmonth(theyear, themonth, w, l);
}


def:pub calendar(year: int, w: int = 2, l: int = 1, c: int = 6, m: int = 3) -> str {
    return _c.formatyear(year, w, l, c, m);
}


def:pub prcal(year: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3) {
    _c.pryear(year, w, l, c, m);
}


glob:pub EPOCH: int = 1970;
glob _EPOCH_ORD: int = 719163;


def:pub timegm(t: (list[int] | struct_time)) -> int {
    year: int;
    month: int;
    day: int;
    hour: int;
    minute: int;
    second: int;
    if isinstance(t, struct_time) {
        st: struct_time = t as struct_time;
        year = st.tm_year;
        month = st.tm_mon;
        day = st.tm_mday;
        hour = st.tm_hour;
        minute = st.tm_min;
        second = st.tm_sec;
    } else {
        lst: list[int] = t as list[int];
        year = lst[0];
        month = lst[1];
        day = lst[2];
        hour = lst[3];
        minute = lst[4];
        second = lst[5];
    }
    days: int = date(year, month, 1).toordinal() - _EPOCH_ORD + day - 1;
    return ((days * 24 + hour) * 60 + minute) * 60 + second;
}
