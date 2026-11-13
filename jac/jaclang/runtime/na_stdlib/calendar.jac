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

    def init(month: int);
    def __str__ -> str;
}


obj:pub IllegalWeekdayError(ValueError) {
    has weekday: int = 0;

    def init(weekday: int);
    def __str__ -> str;
}


def:pub isleap(year: int) -> bool;


def:pub leapdays(y1: int, y2: int) -> int;


def:pub weekday(year: int, month: int, day: int) -> int;


def _validate_month(month: int);


def _monthlen(year: int, month: int) -> int;


def:pub monthrange(year: int, month: int) -> tuple[(int, int)];


def _prevmonth(year: int, month: int) -> tuple[(int, int)];


def _nextmonth(year: int, month: int) -> tuple[(int, int)];


obj:pub Calendar {
    has _firstweekday: int = 0;

    def init(firstweekday: int = 0);
    def getfirstweekday -> int;
    def setfirstweekday(firstweekday: int);
    def iterweekdays -> list[int];
    def itermonthdates(year: int, month: int) -> list[date];
    def itermonthdays(year: int, month: int) -> list[int];
    def itermonthdays2(year: int, month: int) -> list[tuple[(int, int)]];
    def itermonthdays3(year: int, month: int) -> list[tuple[(int, int, int)]];
    def itermonthdays4(year: int, month: int) -> list[tuple[(int, int, int, int)]];
    def monthdatescalendar(year: int, month: int) -> list[list[date]];
    def monthdays2calendar(year: int, month: int) -> list[list[tuple[(int, int)]]];
    def monthdayscalendar(year: int, month: int) -> list[list[int]];
    def yeardatescalendar(year: int, width: int = 3) -> list[list[list[list[date]]]];
    def yeardays2calendar(
        year: int, width: int = 3
    ) -> list[list[list[list[tuple[(int, int)]]]]];

    def yeardayscalendar(year: int, width: int = 3) -> list[list[list[list[int]]]];
}


def _center(s: str, width: int) -> str;


def _rstrip(s: str) -> str;


def _rep(s: str, n: int) -> str;


obj:pub TextCalendar(Calendar) {
    def prweek(theweek: list[tuple[(int, int)]], width: int);
    def formatday(day: int, weekday: int, width: int) -> str;
    def formatweek(theweek: list[tuple[(int, int)]], width: int) -> str;
    def formatweekday(day: int, width: int) -> str;
    def formatweekheader(width: int) -> str;
    def formatmonthname(
        theyear: int, themonth: int, width: int, withyear: bool = True
    ) -> str;

    def prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0);
    def formatmonth(theyear: int, themonth: int, w_in: int = 0, l_in: int = 0) -> str;
    def formatyear(
        theyear: int, w_in: int = 2, l_in: int = 1, c_in: int = 6, m: int = 3
    ) -> str;

    def pryear(theyear: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3);
}


def formatstring(cols: list[str], colwidth: int = 20, spacing: int = 6) -> str;


glob _c: TextCalendar = TextCalendar();


def:pub firstweekday -> int;


def:pub setfirstweekday(firstweekday: int);


def:pub monthcalendar(year: int, month: int) -> list[list[int]];


def:pub prweek(theweek: list[tuple[(int, int)]], width: int);


def:pub week(theweek: list[tuple[(int, int)]], width: int) -> str;


def:pub weekheader(width: int) -> str;


def:pub prmonth(theyear: int, themonth: int, w: int = 0, l: int = 0);


def:pub month(theyear: int, themonth: int, w: int = 0, l: int = 0) -> str;


def:pub calendar(theyear: int, w: int = 2, l: int = 1, c: int = 6, m: int = 3) -> str;


def:pub prcal(theyear: int, w: int = 0, l: int = 0, c: int = 6, m: int = 3);


glob:pub EPOCH: int = 1970;
glob _EPOCH_ORD: int = 719163;


def:pub timegm(`tuple: (list[int] | struct_time)) -> int;
