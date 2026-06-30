"""Guarded re-exports for firebase-admin (install group: [firebase])."""

with entry {
    try {
        import firebase_admin;
        import from firebase_admin { auth, credentials }
        HAS_FIREBASE_ADMIN = True;
    } except ImportError {
        firebase_admin = None;
        auth = None;
        credentials = None;
        HAS_FIREBASE_ADMIN = False;
    }
}
