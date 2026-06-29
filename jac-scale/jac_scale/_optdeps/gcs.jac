"""Guarded re-exports for google-cloud-storage (install group: [firebase])."""

import from jac_scale._optdeps.optional_deps { require_optional }

with entry {
    try {
        import from google.cloud.storage { Client as StorageClient }
        HAS_GCS = True;
    } except ImportError {
        StorageClient = None;
        HAS_GCS = False;
    }
}

"""Raise a helpful error if google-cloud-storage is missing."""
def require_google_cloud_storage {
    require_optional("google.cloud.storage", "firebase");
}
