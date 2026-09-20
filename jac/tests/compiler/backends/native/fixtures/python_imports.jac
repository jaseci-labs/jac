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
