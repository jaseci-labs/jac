import from sqlite3 { sqlite_version as version }
import from sqlite3 { sqlite_version as middle }
import from sqlite3 { sqlite_version as version }

def number -> int {
    return int(version) * 10 + int(middle);
}

def local_number -> int {
    import from sqlite3 { sqlite_version as local }
    import from sqlite3.dbapi2 { sqlite_version as local }
    return int(local);
}
