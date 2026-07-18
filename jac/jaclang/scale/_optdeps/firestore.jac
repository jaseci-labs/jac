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
