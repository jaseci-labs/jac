"""Implementation of Google Cloud Storage / Firebase Storage."""
import from datetime { timedelta }
import from google.cloud.exceptions { NotFound }
import from jac_scale._optdeps.gcs { StorageClient, require_google_cloud_storage }

impl GcsStorage.init(
    self: GcsStorage,
    bucket: str,
    prefix: str = "",
    public_read: bool = False,
    project_id: (str | None) = None
) -> None {
    require_google_cloud_storage();
    self.bucket = bucket;
    self.prefix = prefix.strip("/");
    self.public_read = public_read;
    self.project_id = project_id;

    kwargs = {};
    if project_id {
        kwargs["project"] = project_id;
    }
    self._client = StorageClient(**kwargs);
    self._bucket = self._client.bucket(bucket);
}

impl GcsStorage.upload(
    self: GcsStorage,
    source: (str | BinaryIO),
    destination: str,
    metadata: (dict[str, str] | None) = None
) -> str {
    key = self._resolve_key(destination);
    blob = self._bucket.blob(key);
    if metadata {
        blob.metadata = metadata;
    }

    if isinstance(source, str) {
        blob.upload_from_filename(source);
    } else {
        blob.upload_from_file(source, rewind=True);
    }

    if self.public_read {
        blob.make_public();
    }
    return key;
}

impl GcsStorage.download(
    self: GcsStorage, source: str, destination: (str | BinaryIO | None) = None
) -> (bytes | None) {
    key = self._resolve_key(source);
    blob = self._bucket.blob(key);
    # Match LocalStorage: a missing object surfaces as a predictable, standard
    # FileNotFoundError rather than leaking the vendor's NotFound exception.
    try {
        if destination is None {
            return blob.download_as_bytes();
        } elif isinstance(destination, str) {
            blob.download_to_filename(destination);
            return None;
        } else {
            blob.download_to_file(destination);
            return None;
        }
    } except NotFound {
        raise FileNotFoundError(f"Object not found in storage: {source}");
    }
}

impl GcsStorage.delete(self: GcsStorage, path: str) -> bool {
    key = self._resolve_key(path);
    try {
        self._bucket.blob(key).delete();
        return True;
    } except NotFound {
        return False;
    }
}

impl GcsStorage.exists(self: GcsStorage, path: str) -> bool {
    key = self._resolve_key(path);
    return self._bucket.blob(key).exists();
}

impl GcsStorage.list_files(
    self: GcsStorage, prefix: str = "", recursive: bool = False
) -> Generator[str, None, None] {
    full_prefix = self._resolve_key(prefix);
    if full_prefix and not full_prefix.endswith("/") {
        full_prefix += "/";
    }

    kwargs = {"prefix": full_prefix};
    if not recursive {
        kwargs["delimiter"] = "/";
    }

    for blob in self._bucket.list_blobs(**kwargs) {
        key = blob.name;
        if key.endswith("/") {
            continue;
        }
        yield self._strip_key_prefix(key);
    }
}

impl GcsStorage.get_metadata(self: GcsStorage, path: str) -> dict[str, Any] {
    key = self._resolve_key(path);
    blob = self._bucket.blob(key);
    # blob.reload() hits the GCS metadata API and raises NotFound when the object
    # is absent; translate it to the standard FileNotFoundError so callers get a
    # predictable signal instead of a vendor exception (parity with LocalStorage).
    try {
        blob.reload();
    } except NotFound {
        raise FileNotFoundError(f"Object not found in storage: {path}");
    }
    return {
        "size": blob.size,
        "modified": blob.updated,
        "content_type": blob.content_type,
        "metadata": blob.metadata or {},
        "name": key.split("/")[-1],
        "is_dir": False
    };
}

impl GcsStorage.copy(self: GcsStorage, source: str, destination: str) -> bool {
    src_key = self._resolve_key(source);
    dest_key = self._resolve_key(destination);
    src_blob = self._bucket.blob(src_key);
    if not src_blob.exists() {
        return False;
    }

    # copy_blob raises NotFound if the source is deleted between the exists()
    # check above and now (TOCTOU); treat that the same as a pre-check miss.
    try {
        new_blob = self._bucket.copy_blob(src_blob, self._bucket, new_name=dest_key);
    } except NotFound {
        return False;
    }
    if self.public_read {
        new_blob.make_public();
    }
    return True;
}

impl GcsStorage.get_url(
    self: GcsStorage, path: str, expires_in: (int | None) = 3600
) -> str {
    key = self._resolve_key(path);
    blob = self._bucket.blob(key);

    if self.public_read {
        return blob.public_url;
    }

    expiration = timedelta(seconds=expires_in if expires_in is not None else 3600);
    # Service-account JSON credentials sign V4 URLs locally. Application
    # Default Credentials in serverless runtimes (Cloud Run/GKE/Cloud
    # Functions) have no local private key, so blob-side signing raises
    # AttributeError — fall back to the IAM SignBlob API in that case.
    try {
        return blob.generate_signed_url(
            version="v4", expiration=expiration, method="GET"
        );
    } except AttributeError {
        return _gcs_signed_url_via_iam(blob, expiration);
    }
}

"""Sign a V4 GET URL via the IAM SignBlob API for ADC without a private key.

Delegates signing to the runtime service account's identity. Requires the
'Service Account Token Creator' role (iam.serviceAccounts.signBlob) on that
service account.
"""
def _gcs_signed_url_via_iam(blob: any, expiration: any) -> str {
    import google.auth;
    import from google.auth.transport.requests { Request as GoogleAuthRequest }
    (credentials, _) = google.auth.default();
    credentials.refresh(GoogleAuthRequest());
    # IAM SignBlob needs the runtime service account's email. User-account ADC
    # (e.g. `gcloud auth application-default login` in development) has no
    # service_account_email, so raise an actionable error instead of leaking a
    # bare AttributeError from the missing attribute.
    service_account_email = credentials?.service_account_email;
    if not service_account_email {
        raise RuntimeError(
            "Cannot generate a signed URL: Application Default Credentials are a "
            "user account with no associated service account. Run under a service "
            "account, set GOOGLE_APPLICATION_CREDENTIALS to a service-account key, "
            "or use `gcloud auth application-default login "
            "--impersonate-service-account=<sa-email>`."
        );
    }
    return blob.generate_signed_url(
        version="v4",
        expiration=expiration,
        method="GET",
        service_account_email=service_account_email,
        access_token=credentials.token
    );
}
