impl IllegalMonthError.init(month: int) {
    self.month = month;
}

impl IllegalMonthError.__str__ -> str {
    return "bad month number " + str(self.month) + "; must be 1-12";
}

impl IllegalWeekdayError.init(weekday: int) {
    self.weekday = weekday;
}

impl IllegalWeekdayError.__str__ -> str {
    return "bad weekday number "
        + str(self.weekday)
        + "; must be 0 (Monday) to 6 (Sunday)";
}

impl isleap(year: int) -> bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

impl leapdays(y1: int, y2: int) -> int {
    lo: int = y1 - 1;
    hi: int = y2 - 1;
    return (hi // 4 - lo // 4) - (hi // 100 - lo // 100) + (hi // 400 - lo // 400);
}

impl weekday(year: int, month: int, day: int) -> int {
    shown: int = year;
    if not (1 <= shown and shown <= 9999) {
        shown = 2000 + shown % 400;
    }
    return date(shown, month, day).weekday();
}

impl _validate_month(month: int) {
    if not (1 <= month and month <= 12) {
        raise IllegalMonthError(month);
    }
}

impl _monthlen(year: int, month: int) -> int {
    n: int = mdays[month];
    if month == 2 and isleap(year) {
        n += 1;
    }
    return n;
}

impl monthrange(year: int, month: int) -> tuple[(int, int)] {
    _validate_month(month);
    day1: int = weekday(year, month, 1);
    ndays: int = _monthlen(year, month);
    return (day1, ndays);
}

impl _prevmonth(year: int, month: int) -> tuple[(int, int)] {
    if month == 1 {
        return (year - 1, 12);
    }
    return (year, month - 1);
}

impl _nextmonth(year: int, month: int) -> tuple[(int, int)] {
    if month == 12 {
        return (year + 1, 1);
    }
    return (year, month + 1);
}

impl Calendar.init(firstweekday: int = 0) {
    self._firstweekday = firstweekday;
}

impl Calendar.getfirstweekday -> int {
    return self._firstweekday % 7;
}

impl Calendar.setfirstweekday(firstweekday: int) {
    self._firstweekday = firstweekday;
}

impl Calendar.iterweekdays -> list[int] {
    result: list[int] = [];
    i: int = self.getfirstweekday();
    while i < self.getfirstweekday() + 7 {
        result.append(i % 7);
        i += 1;
    }
    return result;
}

impl Calendar.itermonthdates(year: int, month: int) -> list[date] {
    result: list[date] = [];
    tups: list[tuple[(int, int, int)]] = self.itermonthdays3(year, month);
    for t in tups {
        (y, m, d) = t;
        result.append(date(y, m, d));
    }
    return result;
}

impl Calendar.itermonthdays(year: int, month: int) -> list[int] {
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

impl Calendar.itermonthdays2(year: int, month: int) -> list[tuple[(int, int)]] {
    result: list[tuple[(int, int)]] = [];
    days: list[int] = self.itermonthdays(year, month);
    i: int = self.getfirstweekday();
    for d in days {
        result.append((d, i % 7));
        i += 1;
    }
    return result;
}

impl Calendar.itermonthdays3(year: int, month: int) -> list[tuple[(int, int, int)]] {
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

impl Calendar.itermonthdays4(
    year: int, month: int
) -> list[tuple[(int, int, int, int)]] {
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

impl Calendar.monthdatescalendar(year: int, month: int) -> list[list[date]] {
    dates: list[date] = self.itermonthdates(year, month);
    result: list[list[date]] = [];
    i: int = 0;
    while i < len(dates) {
        result.append(dates[i:i + 7]);
        i += 7;
    }
    return result;
}

impl Calendar.monthdays2calendar(
    year: int, month: int
) -> list[list[tuple[(int, int)]]] {
    days: list[tuple[(int, int)]] = self.itermonthdays2(year, month);
    result: list[list[tuple[(int, int)]]] = [];
    i: int = 0;
    while i < len(days) {
        result.append(days[i:i + 7]);
        i += 7;
    }
    return result;
}

impl Calendar.monthdayscalendar(year: int, month: int) -> list[list[int]] {
    days: list[int] = self.itermonthdays(year, month);
    result: list[list[int]] = [];
    i: int = 0;
    while i < len(days) {
        result.append(days[i:i + 7]);
        i += 7;
    }
    return result;
}

impl Calendar.yeardatescalendar(
    year: int, width: int = 3
) -> list[list[list[list[date]]]] {
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

impl Calendar.yeardays2calendar(
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

impl Calendar.yeardayscalendar(
    year: int, width: int = 3
) -> list[list[list[list[int]]]] {
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

impl _center(s: str, width: int) -> str {
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

impl _rstrip(s: str) -> str {
    out: str = s;
    while len(out) > 0 and out[len(out) - 1] == " " {
        out = out[0:len(out) - 1];
    }
    return out;
}

impl _rep(s: str, n: int) -> str {
    out: str = "";
    i: int = 0;
    while i < n {
        out += s;
        i += 1;
    }
    return out;
}

impl TextCalendar.prweek(theweek: list[tuple[(int, int)]], width: int) {
    sys.stdout.write(self.formatweek(theweek, width));
}

impl TextCalendar.formatday(day: int, weekday: int, width: int) -> str {
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

impl TextCalendar.formatweek(theweek: list[tuple[(int, int)]], width: int) -> str {
    parts: list[str] = [];
    for t in theweek {
        (d, wd) = t;
        parts.append(self.formatday(d, wd, width));
    }
    return " ".join(parts);
}

impl TextCalendar.formatweekday(day: int, width: int) -> str {
    names: list[str] = day_name if width >= 9 else day_abbr;
    return _center(names[day][0:width], width);
}

impl TextCalendar.formatweekheader(width: int) -> str {
    parts: list[str] = [];
    for i in self.iterweekdays() {
        parts.append(self.formatweekday(i, width));
    }
    return " ".join(parts);
}

impl TextCalendar.formatmonthname(
    theyear: int, themonth: int, width: int, withyear: bool = True
) -> str {
    _validate_month(themonth);
    s: str = month_name[themonth];
    if withyear {
        s = s + " " + str(theyear);
    }
    return _center(s, width);
}

impl TextCalendar.prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0) {
    sys.stdout.write(self.formatmonth(theyear, themonth, w, l));
}

impl TextCalendar.formatmonth(
    theyear: int, themonth: int, w_in: int = 0, l_in: int = 0
) -> str {
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
    weeks: list[list[tuple[(int, int)]]] = self.monthdays2calendar(theyear, themonth);
    for week in weeks {
        s += _rstrip(self.formatweek(week, w));
        s += _rep("\n", l);
    }
    return s;
}

impl TextCalendar.formatyear(
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

impl TextCalendar.pryear(theyear: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3) {
    sys.stdout.write(self.formatyear(theyear, w, l, c, m));
}

impl formatstring(cols: list[str], colwidth: int = 20, spacing: int = 6) -> str {
    parts: list[str] = [];
    for cl in cols {
        parts.append(_center(cl, colwidth));
    }
    return _rep(" ", spacing).join(parts);
}

impl firstweekday -> int {
    return _c.getfirstweekday();
}

impl setfirstweekday(firstweekday: int) {
    if not (0 <= firstweekday and firstweekday <= 6) {
        raise IllegalWeekdayError(firstweekday);
    }
    _c.setfirstweekday(firstweekday);
}

impl monthcalendar(year: int, month: int) -> list[list[int]] {
    return _c.monthdayscalendar(year, month);
}

impl prweek(theweek: list[tuple[(int, int)]], width: int) {
    _c.prweek(theweek, width);
}

impl week(theweek: list[tuple[(int, int)]], width: int) -> str {
    return _c.formatweek(theweek, width);
}

impl weekheader(width: int) -> str {
    return _c.formatweekheader(width);
}

impl prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0) {
    _c.prmonth(theyear, themonth, w, l);
}

impl month(theyear: int, themonth: int, w: int = 0, l: int = 0) -> str {
    return _c.formatmonth(theyear, themonth, w, l);
}

impl calendar(theyear: int, w: int = 2, l: int = 1, c: int = 6, m: int = 3) -> str {
    return _c.formatyear(theyear, w, l, c, m);
}

impl prcal(theyear: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3) {
    _c.pryear(theyear, w, l, c, m);
}

impl timegm(`tuple: (list[int] | struct_time)) -> int {
    year: int;
    month: int;
    day: int;
    hour: int;
    minute: int;
    second: int;
    if isinstance(`tuple, struct_time) {
        st: struct_time = `tuple as struct_time;
        year = st.tm_year;
        month = st.tm_mon;
        day = st.tm_mday;
        hour = st.tm_hour;
        minute = st.tm_min;
        second = st.tm_sec;
    } else {
        lst: list[int] = `tuple as list[int];
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
