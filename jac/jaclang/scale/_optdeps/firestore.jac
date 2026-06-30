"""Guarded re-exports for google-cloud-firestore (capability: storage.firebase).

Callers guard usage with `require_optional("google.cloud.firestore", "storage.firebase")`
from optional_deps, matching the pymongo/redis convention.
"""

with entry {
    try {
        import from google.cloud.firestore { Client as FirestoreClient }
        import from google.cloud.exceptions { NotFound }
        import from google.api_core.exceptions { AlreadyExists }
        HAS_FIRESTORE = True;
    } except ImportError {
        FirestoreClient = None;
        NotFound = None;
        AlreadyExists = None;
        HAS_FIRESTORE = False;
    }
}
