import sqlite3;

def answer -> int {
    connection = sqlite3.connect(":memory:");
    cursor = connection.execute("select 42");
    row = cursor.fetchone();
    connection.close();
    return row[0];
}

def caught -> int {
    connection = sqlite3.connect(":memory:");
    try {
        connection.execute("select " + str(42) + ", missing_column");
    } except sqlite3.OperationalError {
        connection.close();
        return 7;
    }
    return 0;
}

def failed -> int {
    connection = sqlite3.connect(":memory:");
    try {
        connection.execute("select missing_column");
    } finally {
        connection.close();
    }
    return 0;
}

def aliased -> int {
    import from sqlite3 { connect as open_database }
    connection = open_database(":memory:");
    try {
        return connection.execute("select 17").fetchone()[0];
    } finally {
        connection.close();
    }
}

def large_integer -> int {
    import from operator { pow as power }
    value = power(2, 200);
    return value.bit_length();
}

def overflowing_integer -> int {
    import from operator { pow as power }
    return power(2, 200);
}

def arithmetic -> bool {
    import from operator { pow as power }
    large = power(2, 100);
    value = ((large + 1) * 3 - 2) // 2;
    if value <= large {
        return False;
    }
    if -large >= 0 {
        return False;
    }
    if (~large & large) != 0 {
        return False;
    }
    return (large ** 2).bit_length() == 201;
}

def identity_and_truth -> bool {
    import from operator { pow as power }
    large = power(2, 100);
    alias = large;
    if alias is not large {
        return False;
    }
    if not large {
        return False;
    }
    zero = power(0, 1);
    if zero {
        return False;
    }
    return zero is not None;
}

def membership -> bool {
    connection = sqlite3.connect(":memory:");
    row = connection.execute("select 42, 17").fetchone();
    closed = connection.close();
    if closed is not None {
        return False;
    }
    if 42 not in row {
        return False;
    }
    return 3 not in row;
}

def comparison_error -> bool {
    import from operator { pow as power }
    return power(2, 100) < "incomparable";
}

def short_circuit -> bool {
    import from operator { pow as power }
    large = power(2, 100);
    zero = power(0, 1);
    if (large or power(2, -1000)) is not large {
        return False;
    }
    if (zero and (large / zero)) is not zero {
        return False;
    }
    if (zero or 42) != 42 {
        return False;
    }
    if large < zero < (large / zero) {
        return False;
    }
    return zero < large < (large + 1);
}

def iterate(early: bool) -> int {
    connection = sqlite3.connect(":memory:");
    total = 0;
    try {
        for row in connection.execute("select 17 union all select 25") {
            total += int(row[0]);
            if early {
                break;
            }
        }
    } finally {
        connection.close();
    }
    return total;
}

def iterator_failure -> int {
    connection = sqlite3.connect(":memory:");
    cursor = connection.execute("select 42");
    connection.close();
    for row in cursor {
        return row[0];
    }
    return 0;
}

def builtin_protocols -> bool {
    connection = sqlite3.connect(":memory:");
    try {
        cursor = connection.execute("select 42, 17");
        row = next(cursor);
        if len(row) != 2 or str(row[0]) != "42" {
            return False;
        }
        if list(row)[1] != 17 or next(cursor, None) is not None {
            return False;
        }
        return int(str(row[0])) == 42;
    } finally {
        connection.close();
    }
}
