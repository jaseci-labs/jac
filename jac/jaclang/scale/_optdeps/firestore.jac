"""Guarded re-exports for google-cloud-firestore (capability: storage.firebase).

Callers guard usage with `require_optional("google.cloud.firestore", "storage.firebase")`
from optional_deps, matching the pymongo/redis convention.
"""

with entry {
    try {
        import from google.cloud.firestore { Client as FirestoreClient }
        HAS_FIRESTORE = True;
    } except ImportError {
        FirestoreClient = None;
        HAS_FIRESTORE = False;
    }
}
