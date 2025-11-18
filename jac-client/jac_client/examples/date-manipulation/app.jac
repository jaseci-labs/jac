
# Pages
cl import from react {useState}
cl import from "date-fns" {
    format,
    formatISO,
    addDays,
    subDays,
    addMonths,
    subMonths,
    addYears,
    subYears,
    addHours,
    addMinutes,
    startOfDay,
    endOfDay,
    startOfWeek,
    endOfWeek,
    startOfMonth,
    endOfMonth,
    differenceInDays,
    differenceInMonths,
    differenceInYears,
    differenceInHours,
    differenceInMinutes,
    isAfter,
    isBefore,
    isEqual,
    isSameDay,
    isSameMonth,
    isSameYear,
    isToday,
    isTomorrow,
    isYesterday,
    isWeekend,
    parseISO,
    formatDistance,
    formatDistanceToNow,
    formatRelative,
    getTime
}

cl {
    # Formatting Examples Component
    def FormattingExamples() -> any {
        let now = Date();

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>📅 Date Formatting</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <div><strong>ISO String:</strong> {formatISO(now)}</div>
                <div><strong>Timestamp:</strong> {getTime(now)}</div>
                <div><strong>yyyy-MM-dd:</strong> {format(now, "yyyy-MM-dd")}</div>
                <div><strong>MM/dd/yyyy:</strong> {format(now, "MM/dd/yyyy")}</div>
                <div><strong>dd/MM/yyyy:</strong> {format(now, "dd/MM/yyyy")}</div>
                <div><strong>Full Date:</strong> {format(now, "MMMM do, yyyy")}</div>
                <div><strong>Time 24h:</strong> {format(now, "HH:mm:ss")}</div>
                <div><strong>Time 12h:</strong> {format(now, "hh:mm:ss a")}</div>
                <div><strong>Full DateTime:</strong> {format(now, "PPpp")}</div>
                <div><strong>Weekday:</strong> {format(now, "EEEE")}</div>
            </div>
        </div>;
    }

    # Adding/Subtracting Dates Component
    def DateArithmeticExamples() -> any {
        let now = Date();

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>➕➖ Date Arithmetic</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <div><strong>Today:</strong> {format(now, "yyyy-MM-dd")}</div>
                <div></div>
                <div><strong>+5 Days:</strong> {format(addDays(now, 5), "yyyy-MM-dd")}</div>
                <div><strong>-5 Days:</strong> {format(subDays(now, 5), "yyyy-MM-dd")}</div>
                <div><strong>+2 Months:</strong> {format(addMonths(now, 2), "yyyy-MM-dd")}</div>
                <div><strong>-2 Months:</strong> {format(subMonths(now, 2), "yyyy-MM-dd")}</div>
                <div><strong>+1 Year:</strong> {format(addYears(now, 1), "yyyy-MM-dd")}</div>
                <div><strong>-1 Year:</strong> {format(subYears(now, 1), "yyyy-MM-dd")}</div>
                <div><strong>+6 Hours:</strong> {format(addHours(now, 6), "HH:mm")}</div>
                <div><strong>+30 Minutes:</strong> {format(addMinutes(now, 30), "HH:mm")}</div>
            </div>
        </div>;
    }

    # Start/End of Period Component
    def PeriodBoundariesExamples() -> any {
        let now = Date();

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>🎯 Period Boundaries</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <div><strong>Start of Day:</strong> {format(startOfDay(now), "yyyy-MM-dd HH:mm:ss")}</div>
                <div><strong>End of Day:</strong> {format(endOfDay(now), "yyyy-MM-dd HH:mm:ss")}</div>
                <div><strong>Start of Week:</strong> {format(startOfWeek(now), "yyyy-MM-dd")}</div>
                <div><strong>End of Week:</strong> {format(endOfWeek(now), "yyyy-MM-dd")}</div>
                <div><strong>Start of Month:</strong> {format(startOfMonth(now), "yyyy-MM-dd")}</div>
                <div><strong>End of Month:</strong> {format(endOfMonth(now), "yyyy-MM-dd")}</div>
            </div>
        </div>;
    }

    # Date Differences Component
    def DateDifferenceExamples() -> any {
        let now = Date();
        let futureDate = addMonths(addDays(now, 45), 2);
        let pastDate = subMonths(subDays(now, 15), 1);

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>📊 Date Differences</h2>
            <p><strong>Comparing:</strong> {format(now, "yyyy-MM-dd")} with {format(futureDate, "yyyy-MM-dd")}</p>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <div><strong>Days difference:</strong> {differenceInDays(futureDate, now)} days</div>
                <div><strong>Months difference:</strong> {differenceInMonths(futureDate, now)} months</div>
                <div><strong>Hours difference:</strong> {differenceInHours(futureDate, now)} hours</div>
                <div><strong>Minutes difference:</strong> {differenceInMinutes(futureDate, now)} minutes</div>
            </div>
            <p style={{"marginTop": "10px"}}><strong>Past date:</strong> {format(pastDate, "yyyy-MM-dd")} was {differenceInDays(now, pastDate)} days ago</p>
        </div>;
    }

    # Date Comparisons Component
    def DateComparisonExamples() -> any {
        let now = Date();
        let tomorrow = addDays(now, 1);
        let yesterday = subDays(now, 1);
        let sameDay = Date();

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>🔍 Date Comparisons</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <div><strong>Is After Tomorrow?</strong> {isAfter(tomorrow, now).toString()}</div>
                <div><strong>Is Before Yesterday?</strong> {isBefore(yesterday, now).toString()}</div>
                <div><strong>Is Same Day?</strong> {isSameDay(now, sameDay).toString()}</div>
                <div><strong>Is Same Month?</strong> {isSameMonth(now, tomorrow).toString()}</div>
                <div><strong>Is Same Year?</strong> {isSameYear(now, addMonths(now, 6)).toString()}</div>
                <div><strong>Is Today?</strong> {isToday(now).toString()}</div>
                <div><strong>Is Tomorrow?</strong> {isTomorrow(tomorrow).toString()}</div>
                <div><strong>Is Yesterday?</strong> {isYesterday(yesterday).toString()}</div>
                <div><strong>Is Weekend?</strong> {isWeekend(now).toString()}</div>
            </div>
        </div>;
    }

    # Relative Time Component
    def RelativeTimeExamples() -> any {
        let now = Date();
        let pastDate = subDays(now, 3);
        let futureDate = addDays(now, 7);
        let hourAgo = addHours(now, -1);

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>⏰ Relative Time Formatting</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr", "gap": "10px"}}>
                <div><strong>Distance:</strong> {formatDistance(pastDate, now)} (between {format(pastDate, "MMM dd")} and today)</div>
                <div><strong>Distance to Now:</strong> {formatDistanceToNow(futureDate)} (from today to {format(futureDate, "MMM dd")})</div>
                <div><strong>Distance with suffix:</strong> {formatDistanceToNow(hourAgo, {"addSuffix": true})}</div>
                <div><strong>Relative:</strong> {formatRelative(pastDate, now)}</div>
                <div><strong>Relative Future:</strong> {formatRelative(futureDate, now)}</div>
            </div>
        </div>;
    }

    # Interactive Date Calculator
    def DateCalculator() -> any {
        let initialDate=format(Date(), "yyyy-MM-dd");
        let [selectedDate, setSelectedDate] = useState(initialDate);
        let [daysToAdd, setDaysToAdd] = useState("0");


        let currentDate = parseISO(selectedDate);
        let resultDate = addDays(currentDate, (daysToAdd));

        let handleDateChange = lambda e: any -> None {
            setSelectedDate(e.target.value);
        };

        let handleDaysChange = lambda e: any -> None {
            setDaysToAdd(e.target.value);
        };

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>🧮 Interactive Date Calculator</h2>
            <div style={{"display": "flex", "gap": "15px", "marginBottom": "15px"}}>
                <div>
                    <label style={{"display": "block", "marginBottom": "5px"}}><strong>Select Date:</strong></label>
                    <input
                        type="date"
                        value={selectedDate}
                        onChange={handleDateChange}
                        style={{"padding": "8px", "fontSize": "14px", "borderRadius": "4px", "border": "1px solid #ccc"}}
                    />
                </div>
                <div>
                    <label style={{"display": "block", "marginBottom": "5px"}}><strong>Days to Add/Subtract:</strong></label>
                    <input
                        type="number"
                        value={daysToAdd}
                        onChange={handleDaysChange}
                        style={{"padding": "8px", "fontSize": "14px", "borderRadius": "4px", "border": "1px solid #ccc", "width": "100px"}}
                    />
                </div>
            </div>
            <div style={{"backgroundColor": "#f8f9fa", "padding": "15px", "borderRadius": "4px"}}>
                <p style={{"margin": "0 0 10px 0"}}><strong>Original Date:</strong> {format(currentDate, "EEEE, MMMM do, yyyy")}</p>
                <p style={{"margin": "0", "fontSize": "18px", "color": "#27ae60"}}><strong>Result Date:</strong> {format(resultDate, "EEEE, MMMM do, yyyy")}</p>
                <p style={{"margin": "10px 0 0 0", "color": "#7f8c8d"}}><em>({formatDistanceToNow(resultDate, {"addSuffix": true})})</em></p>
            </div>
        </div>;
    }

    # Parsing Examples Component
    def ParsingExamples() -> any {
        let isoString = "2024-12-25T10:30:00.000Z";
        let parsedDate = parseISO(isoString);

        return <div style={{"padding": "20px", "border": "1px solid #ddd", "marginBottom": "20px", "borderRadius": "8px"}}>
            <h2 style={{"color": "#2c3e50"}}>🔄 Parsing Dates</h2>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr", "gap": "10px"}}>
                <div><strong>ISO String:</strong> {isoString}</div>
                <div><strong>Parsed Date:</strong> {format(parsedDate, "PPpp")}</div>
                <div><strong>Weekday:</strong> {format(parsedDate, "EEEE")}</div>
                <div><strong>Time Until:</strong> {formatDistanceToNow(parsedDate)}</div>
            </div>
        </div>;
    }

    # Main App Component
    def app() -> any {
        return <div style={{"maxWidth": "1200px", "margin": "0 auto", "padding": "20px", "fontFamily": "Arial, sans-serif"}}>
            <h1 style={{"textAlign": "center", "color": "#34495e", "marginBottom": "30px"}}>
                🗓️ Date-fns Examples in OneLang
            </h1>

            <FormattingExamples />
            <DateArithmeticExamples />
            <PeriodBoundariesExamples />
            <DateDifferenceExamples />
            <DateComparisonExamples />
            <RelativeTimeExamples />
            <DateCalculator />
            <ParsingExamples />

            <div style={{"textAlign": "center", "marginTop": "30px", "padding": "20px", "backgroundColor": "#ecf0f1", "borderRadius": "8px"}}>
                <p style={{"margin": "0", "color": "#7f8c8d"}}>
                    <strong>All examples are live and running!</strong> Try the interactive calculator above.
                </p>
            </div>
        </div>;
    }
}
