glob _current_db: str = "";

def connect(db_name: str) -> str {
    return f"Connected to {db_name}";
}

def disconnect -> str {
    return "Disconnected";
}

def is_connected -> bool {
    return _current_db != "";
}
