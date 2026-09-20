def add -> int {
    import from operator { add as calculate }
    return calculate(7, 3);
}

def subtract -> int {
    import from operator { sub as calculate }
    return calculate(7, 3);
}

def local_binding -> bool {
    import from sqlite3 { sqlite_version as version }
    return version is version;
}

def unused_binding -> int {
    import from sqlite3 { sqlite_version as unused }
    return 42;
}

def conditional_binding(execute: bool) -> int {
    if execute {
        import from sqlite3 { sqlite_version as version }
    }
    return int(version);
}

def binding_before_statement -> int {
    value = int(version);
    import from sqlite3 { sqlite_version as version }
    return value;
}
