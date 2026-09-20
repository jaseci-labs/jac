import from sqlite3 { sqlite_version as version }
import from sqlite3 { sqlite_version as alias }

def stable -> bool {
    return version is version;
}

def aliases -> bool {
    return version is alias;
}

def number -> int {
    return int(version);
}

def unused -> int {
    return 42;
}
