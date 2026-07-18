import boto3;
import from botocore.exceptions { ClientError }
import from botocore.config { Config }
import from botocore { UNSIGNED }
import from io { BytesIO }

impl S3Storage.init(
    self: S3Storage,
    bucket: str,
    prefix: str = "",
    region: str = "us-east-1",
    endpoint_url: (str | None) = None,
    public_read: bool = False
) -> None {
    self.bucket = bucket;
    self.prefix = prefix.strip("/");
    self.region = region;
    self.endpoint_url = endpoint_url;
    self.public_read = public_read;

    self._client = boto3.client(
        "s3",
        region_name=self.region,
        endpoint_url=self.endpoint_url,
        config=Config(signature_version="s3v4")
    );

    self._public_client = boto3.client(
        "s3",
        region_name=self.region,
        endpoint_url=self.endpoint_url,
        config=Config(signature_version=UNSIGNED)
    );
}

impl S3Storage.upload(
    self: S3Storage,
    source: (str | BinaryIO),
    destination: str,
    metadata: (dict[str, str] | None) = None
) -> str {
    key = self._resolve_key(destination);
    extra_args = {};
    if self.public_read {
        extra_args["ACL"] = "public-read";
    }
    if metadata {
        extra_args["Metadata"] = metadata;
    }

    if isinstance(source, str) {
        self._client.upload_file(source, self.bucket, key, ExtraArgs=extra_args);
    } else {
        self._client.upload_fileobj(source, self.bucket, key, ExtraArgs=extra_args);
    }
    return key;
}

impl S3Storage.download(
    self: S3Storage, source: str, destination: (str | BinaryIO | None) = None
) -> (bytes | None) {
    key = self._resolve_key(source);
    if destination is None {
        buf = BytesIO();
        self._client.download_fileobj(self.bucket, key, buf);
        return buf.getvalue();
    } elif isinstance(destination, str) {
        self._client.download_file(self.bucket, key, destination);
        return None;
    } else {
        self._client.download_fileobj(self.bucket, key, destination);
        return None;
    }
}

impl S3Storage.delete(self: S3Storage, path: str) -> bool {
    key = self._resolve_key(path);

    self._client.delete_object(Bucket=self.bucket, Key=key);
    return True;
}

impl S3Storage.exists(self: S3Storage, path: str) -> bool {
    key = self._resolve_key(path);
    try {
        self._client.head_object(Bucket=self.bucket, Key=key);
        return True;
    } except ClientError as e {
        if e.response["Error"]["Code"] == "404" {
            return False;
        }
        raise e;
    }
}

impl S3Storage.list_files(
    self: S3Storage, prefix: str = "", recursive: bool = False
) -> Generator[str, None, None] {
    full_prefix = self._resolve_key(prefix);
    if full_prefix and not full_prefix.endswith("/") {
        full_prefix += "/";
    }

    paginator = self._client.get_paginator("list_objects_v2");
    kwargs = {"Bucket": self.bucket, "Prefix": full_prefix};
    if not recursive {
        kwargs["Delimiter"] = "/";
    }

    for page in paginator.paginate(**kwargs) {
        if "Contents" in page {
            for obj in page["Contents"] {
                yield self._strip_key_prefix(obj["Key"]);
            }
        }
    }
}

impl S3Storage.get_metadata(self: S3Storage, path: str) -> dict[str, Any] {
    key = self._resolve_key(path);
    resp = self._client.head_object(Bucket=self.bucket, Key=key);
    return {
        "size": resp["ContentLength"],
        "modified": resp["LastModified"],
        "content_type": resp["ContentType"],
        "metadata": resp.get("Metadata", {}),
        "name": key.split("/")[-1],
        "is_dir": False
    };
}

impl S3Storage.copy(self: S3Storage, source: str, destination: str) -> bool {
    src_key = self._resolve_key(source);
    dest_key = self._resolve_key(destination);
    copy_source = {"Bucket": self.bucket, "Key": src_key};
    try {
        self._client.copy(copy_source, self.bucket, dest_key);
        return True;
    } except ClientError as e {
        if e.response["Error"]["Code"] in ["404", "NoSuchKey"] {
            return False;
        }
        raise e;
    }
}

impl S3Storage.get_url(
    self: S3Storage, path: str, expires_in: (int | None) = 3600
) -> str {
    key = self._resolve_key(path);

    client = self._public_client if self.public_read else self._client;

    return client.generate_presigned_url(
        "get_object", Params={"Bucket": self.bucket, "Key": key}, ExpiresIn=expires_in
    );
}
