import from .base { BASE_ID, get_base_id }

glob EXTENDED_ID = BASE_ID + 1;

def get_extended_id -> str {
    return f"Base: {get_base_id()}, Extended: {EXTENDED_ID}";
}
