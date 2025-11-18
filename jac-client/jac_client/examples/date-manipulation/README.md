# 🗓️ Date-fns Examples in OneLang

A comprehensive guide to using the `date-fns` library in OneLang/Jac for powerful date manipulation and formatting.

## 📚 What is date-fns?

`date-fns` is a modern JavaScript library for working with dates. It provides simple, consistent functions for:

- Formatting dates in any format you need
- Adding/subtracting time periods
- Comparing dates
- Calculating differences between dates
- Parsing date strings
- And much more!

Unlike built-in JavaScript `Date` object, `date-fns` is:

- **Modular** - Import only what you need
- **Immutable** - Functions don't modify original dates
- **Pure** - Same input always gives same output
- **Type-safe** - Great TypeScript support

## 🚀 Quick Start

### Installation

```bash
npm install date-fns
```

### Basic Import in OneLang

```jac
cl import from "date-fns" {format, addDays, subDays}

cl {
    def MyComponent() -> any {
        let today = Date();
        let tomorrow = addDays(today, 1);

        return <div>
            <p>Today: {format(today, "yyyy-MM-dd")}</p>
            <p>Tomorrow: {format(tomorrow, "yyyy-MM-dd")}</p>
        </div>;
    }
}
```

## 📖 Complete Examples

This example demonstrates 8 major categories of date-fns functionality:

### 1️⃣ Date Formatting

Transform dates into any format you need. **Important:** OneLang doesn't support JavaScript Date methods like `.toString()` or `.toISOString()` - always use date-fns functions!

```jac
cl import from "date-fns" {format, formatISO, getTime}

let now = Date();

# ISO and timestamp formats (replaces .toISOString() and .getTime())
formatISO(now)                      # 2024-11-18T14:30:45-05:00
getTime(now)                        # 1700334645000 (timestamp)

# Different date formats
format(now, "yyyy-MM-dd")           # 2024-11-18
format(now, "MM/dd/yyyy")           # 11/18/2024
format(now, "dd/MM/yyyy")           # 18/11/2024
format(now, "MMMM do, yyyy")        # November 18th, 2024

# Time formats
format(now, "HH:mm:ss")             # 14:30:45 (24-hour)
format(now, "hh:mm:ss a")           # 02:30:45 PM (12-hour)

# Combined formats
format(now, "PPpp")                 # Nov 18, 2024, 2:30:45 PM
format(now, "EEEE")                 # Monday
```

**Essential date-fns Functions (Replaces JS Date Methods):**

- `formatISO(date)` - Replaces `.toISOString()`
- `getTime(date)` - Replaces `.getTime()` (returns timestamp)
- `format(date, formatString)` - Replaces `.toString()` and custom formatting

**Common Format Tokens:**

- `yyyy` - Full year (2024)
- `MM` - Month number (01-12)
- `dd` - Day of month (01-31)
- `MMMM` - Full month name (November)
- `MMM` - Short month name (Nov)
- `EEEE` - Full weekday name (Monday)
- `HH` - Hour 24-hour (00-23)
- `hh` - Hour 12-hour (01-12)
- `mm` - Minutes (00-59)
- `ss` - Seconds (00-59)
- `a` - AM/PM

### 2️⃣ Date Arithmetic

Add or subtract time from dates:

```jac
cl import from "date-fns" {addDays, subDays, addMonths, subMonths, addYears, addHours}

let now = Date();

# Days
let nextWeek = addDays(now, 7);
let lastWeek = subDays(now, 7);

# Months
let twoMonthsLater = addMonths(now, 2);
let twoMonthsAgo = subMonths(now, 2);

# Years
let nextYear = addYears(now, 1);

# Time
let sixHoursLater = addHours(now, 6);
```

**Available Functions:**

- `addDays(date, amount)` / `subDays(date, amount)`
- `addMonths(date, amount)` / `subMonths(date, amount)`
- `addYears(date, amount)` / `subYears(date, amount)`
- `addHours(date, amount)` / `subHours(date, amount)`
- `addMinutes(date, amount)` / `subMinutes(date, amount)`
- `addSeconds(date, amount)` / `subSeconds(date, amount)`

### 3️⃣ Period Boundaries

Get the start or end of any time period:

```jac
cl import from "date-fns" {startOfDay, endOfDay, startOfWeek, endOfWeek, startOfMonth, endOfMonth}

let now = Date();

# Day boundaries
let dayStart = startOfDay(now);     # Today at 00:00:00
let dayEnd = endOfDay(now);         # Today at 23:59:59

# Week boundaries
let weekStart = startOfWeek(now);   # Sunday of this week
let weekEnd = endOfWeek(now);       # Saturday of this week

# Month boundaries
let monthStart = startOfMonth(now); # 1st day of month
let monthEnd = endOfMonth(now);     # Last day of month
```

**Use Cases:**

- Date range queries (get all records from start of month)
- Scheduling (book until end of day)
- Analytics (group by week)

### 4️⃣ Date Differences

Calculate the difference between two dates:

```jac
cl import from "date-fns" {differenceInDays, differenceInMonths, differenceInYears, differenceInHours}

let startDate = Date("2024-01-01");
let endDate = Date("2024-11-18");

let days = differenceInDays(endDate, startDate);       # 322 days
let months = differenceInMonths(endDate, startDate);   # 10 months
let years = differenceInYears(endDate, startDate);     # 0 years
let hours = differenceInHours(endDate, startDate);     # 7728 hours
```

**Available Functions:**

- `differenceInYears(laterDate, earlierDate)`
- `differenceInMonths(laterDate, earlierDate)`
- `differenceInWeeks(laterDate, earlierDate)`
- `differenceInDays(laterDate, earlierDate)`
- `differenceInHours(laterDate, earlierDate)`
- `differenceInMinutes(laterDate, earlierDate)`
- `differenceInSeconds(laterDate, earlierDate)`

### 5️⃣ Date Comparisons

Check relationships between dates:

```jac
cl import from "date-fns" {
    isAfter,
    isBefore,
    isEqual,
    isSameDay,
    isSameMonth,
    isToday,
    isTomorrow,
    isYesterday,
    isWeekend
}

let date1 = Date("2024-11-18");
let date2 = Date("2024-11-20");

# Comparisons
isAfter(date2, date1);        # true
isBefore(date1, date2);       # true
isEqual(date1, date1);        # true

# Same period checks
isSameDay(date1, Date());     # true if date1 is today
isSameMonth(date1, date2);    # true (both November)
isSameYear(date1, date2);     # true (both 2024)

# Convenience checks
isToday(Date());              # true
isTomorrow(addDays(Date(), 1)); # true
isYesterday(subDays(Date(), 1)); # true
isWeekend(Date());            # true if Saturday or Sunday
```

**Common Use Cases:**

- Validation (is deadline before today?)
- Filtering (show only weekend events)
- Conditional logic (if birthday is today, show message)

### 6️⃣ Relative Time Formatting

Display human-friendly relative times:

```jac
cl import from "date-fns" {formatDistance, formatDistanceToNow, formatRelative}

let now = Date();
let threeDaysAgo = subDays(now, 3);
let nextWeek = addDays(now, 7);

# Distance between dates
formatDistance(threeDaysAgo, now);           # "3 days"
formatDistance(now, nextWeek);               # "7 days"

# Distance from now
formatDistanceToNow(threeDaysAgo);           # "3 days"
formatDistanceToNow(nextWeek);               # "7 days"

# With suffix
formatDistanceToNow(threeDaysAgo, {"addSuffix": true});  # "3 days ago"
formatDistanceToNow(nextWeek, {"addSuffix": true});      # "in 7 days"

# Relative formatting
formatRelative(threeDaysAgo, now);           # "last Friday at 2:30 PM"
formatRelative(nextWeek, now);               # "next Monday at 2:30 PM"
```

**Perfect For:**

- Social media timestamps ("2 hours ago")
- Notifications ("in 5 minutes")
- Activity feeds ("yesterday at 3:45 PM")

### 7️⃣ Parsing Dates

Convert strings to Date objects:

```jac
cl import from "date-fns" {parseISO, parse}

# Parse ISO 8601 strings
let date1 = parseISO("2024-11-18");                    # From date string
let date2 = parseISO("2024-11-18T14:30:00.000Z");     # From ISO datetime

# Use the parsed dates
format(date1, "MMMM dd, yyyy");   # "November 18, 2024"
```

**ISO 8601 Format Examples:**

- `2024-11-18` - Date only
- `2024-11-18T14:30:00` - Date and time
- `2024-11-18T14:30:00.000Z` - UTC time
- `2024-11-18T14:30:00-05:00` - With timezone offset

### 8️⃣ Interactive Date Calculator

Build dynamic date tools with state:

```jac
cl import from react {useState}
cl import from "date-fns" {parseISO, addDays, format}

def DateCalculator() -> any {
    let [selectedDate, setSelectedDate] = useState(format(Date(), "yyyy-MM-dd"));
    let [daysToAdd, setDaysToAdd] = useState("0");

    let currentDate = parseISO(selectedDate);
    let resultDate = addDays(currentDate, int(daysToAdd));

    let handleDateChange = lambda e: any -> None {
        setSelectedDate(e.target.value);
    };

    let handleDaysChange = lambda e: any -> None {
        setDaysToAdd(e.target.value);
    };

    return <div>
        <input
            type="date"
            value={selectedDate}
            onChange={handleDateChange}
        />
        <input
            type="number"
            value={daysToAdd}
            onChange={handleDaysChange}
        />
        <p>Result: {format(resultDate, "EEEE, MMMM do, yyyy")}</p>
    </div>;
}
```

## 🎯 Common Patterns

### Pattern 1: Birthday Countdown

```jac
cl import from "date-fns" {parseISO, differenceInDays, formatDistanceToNow}

def BirthdayCountdown() -> any {
    let birthday = parseISO("2025-05-15");
    let daysUntil = differenceInDays(birthday, Date());
    let timeUntil = formatDistanceToNow(birthday, {"addSuffix": true});

    return <div>
        <p>{daysUntil} days until birthday!</p>
        <p>That's {timeUntil}</p>
    </div>;
}
```

### Pattern 2: Event Status

```jac
cl import from "date-fns" {parseISO, isAfter, isBefore, formatRelative}

def EventStatus(eventDateStr: str) -> any {
    let now = Date();
    let eventDate = parseISO(eventDateStr);

    let status = "";
    if isBefore(eventDate, now) {
        status = "Past Event";
    } elif isAfter(eventDate, now) {
        status = "Upcoming Event";
    } else {
        status = "Happening Now!";
    }

    return <div>
        <p>Status: {status}</p>
        <p>{formatRelative(eventDate, now)}</p>
    </div>;
}
```

### Pattern 3: Date Range Filter

```jac
cl import from "date-fns" {startOfMonth, endOfMonth, format}

def MonthRangePicker() -> any {
    let now = Date();
    let monthStart = startOfMonth(now);
    let monthEnd = endOfMonth(now);

    return <div>
        <p>From: {format(monthStart, "yyyy-MM-dd")}</p>
        <p>To: {format(monthEnd, "yyyy-MM-dd")}</p>
    </div>;
}
```

### Pattern 4: Age Calculator

```jac
cl import from "date-fns" {parseISO, differenceInYears, differenceInMonths}

def AgeCalculator(birthDateStr: str) -> any {
    let birthDate = parseISO(birthDateStr);
    let now = Date();

    let years = differenceInYears(now, birthDate);
    let months = differenceInMonths(now, birthDate) % 12;

    return <div>
        <p>Age: {years} years and {months} months</p>
    </div>;
}
```

## 💡 Key Concepts

### Immutability

All date-fns functions return **new dates** - they never modify the original:

```jac
let original = Date();
let modified = addDays(original, 5);

# original is unchanged!
# modified is a new date 5 days later
```

### Timezone Handling

date-fns works with local time by default. For UTC or specific timezones, use `date-fns-tz`:

```bash
npm install date-fns-tz
```

### Performance

Import only what you need for better bundle size:

```jac
# Good - specific imports
cl import from "date-fns" {format, addDays}

# Avoid - imports everything
cl import from "date-fns" *
```

## 🚨 Important Notes for OneLang

### No JavaScript Date Instance Methods

OneLang doesn't support JavaScript Date instance methods like `.toString()`, `.toISOString()`, `.getTime()`, etc. **Always use date-fns functions instead:**

```jac
# ❌ Wrong - JavaScript methods don't work
let date = Date();
date.toString()        # Doesn't work
date.toISOString()     # Doesn't work
date.getTime()         # Doesn't work

# ✅ Correct - Use date-fns functions
cl import from "date-fns" {format, formatISO, getTime}

let date = Date();
format(date, "PPpp")   # Works! "Nov 18, 2024, 2:30:45 PM"
formatISO(date)        # Works! "2024-11-18T14:30:45-05:00"
getTime(date)          # Works! 1700334645000
```

### Event Handlers

Define lambda functions separately for event handlers:

```jac
# ✅ Correct
let handleChange = lambda e: any -> None {
    setValue(e.target.value);
};

<input onChange={handleChange} />

# ❌ Wrong - inline lambdas don't work in JSX
<input onChange={lambda e: any -> None { setValue(e.target.value); }} />
```

### Type Conversions

Convert strings to numbers for arithmetic:

```jac
let daysStr = "5";
let result = addDays(Date(), int(daysStr));  # Convert to int first
```

### Boolean Display

Booleans display automatically in JSX without conversion:

```jac
# Both work fine in OneLang
<p>Is Today? {isToday(Date())}</p>           # Shows "true" or "false"
<p>Is Today? {isToday(Date()).toString()}</p> # Also works
```

## 🎨 Styling Tips

Date-fns is purely for logic - combine with good UI:

```jac
# Highlight overdue dates
def DueDateDisplay(dueDate: any) -> any {
    let isOverdue = isBefore(dueDate, Date());
    let style = {
        "color": isOverdue ? "#e74c3c" : "#27ae60",
        "fontWeight": "bold"
    };

    return <span style={style}>
        {format(dueDate, "MMM dd, yyyy")}
    </span>;
}
```

## 🎓 Try This!

1. **Build a Deadline Tracker** - Show days remaining until project deadlines
2. **Create a Meeting Scheduler** - Calculate available time slots
3. **Make a Date Picker** - With weekend highlighting and date restrictions
4. **Build a Time Logger** - Track hours worked per day/week/month
5. **Create an Event Calendar** - Display events grouped by month

## 📚 More Resources

- [date-fns Documentation](https://date-fns.org/docs/)
- [Format String Reference](https://date-fns.org/docs/format)
- [All Available Functions](https://date-fns.org/docs/Getting-Started)

## 🏃 Running This Example

```bash
# Install dependencies (if not already done)
npm install

# Run development server with Jac
jac serve app.jac
```

Open your browser and explore all 8 categories of date-fns functionality!

---

**Happy Date Manipulation! 🎉**
