import os;

def:pub build_id -> str {
    return os.environ.get("BUILD_ID", "");
}
