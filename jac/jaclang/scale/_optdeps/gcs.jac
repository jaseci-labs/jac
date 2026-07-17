import from jaclang.scale._optdeps.optional_deps { require_optional }

with entry {
    try {
        import from google.cloud.storage { Client as StorageClient }
        import from google.cloud.exceptions { NotFound }
        HAS_GCS = True;
    } except ImportError {
        StorageClient = None;
        NotFound = None;
        HAS_GCS = False;
    }
}

def require_google_cloud_storage {
    require_optional("google.cloud.storage", "storage.gcs");
}
