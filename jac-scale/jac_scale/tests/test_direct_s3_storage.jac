"""Integration tests for S3 storage using LocalStack testcontainer."""
import os;
import boto3;
import io;
import from testcontainers.localstack { LocalStackContainer }
import from jac_scale.storage.s3_storage { S3Storage }
import from jaclang.runtimelib.storage.local_storage { LocalStorage }

# Session-scoped container created as a global
glob _s3_container = LocalStackContainer(
         "localstack/localstack:latest"
     ).with_services(
         "s3"
     ),
     S3_ENDPOINT: str = "",
     TEST_BUCKET: str = "direct-test-bucket";

# Start the container
with entry {
    _s3_container.start();
}

glob S3_ENDPOINT = _s3_container.get_url();

# Configure environment for store() builtin to use LocalStack
with entry {
    os.environ["JAC_STORAGE_TYPE"] = "s3";
    os.environ["JAC_STORAGE_S3_BUCKET"] = TEST_BUCKET;
    os.environ["JAC_STORAGE_S3_ENDPOINT_URL"] = S3_ENDPOINT;
    os.environ["JAC_STORAGE_S3_REGION"] = "us-east-1";
    os.environ["AWS_ACCESS_KEY_ID"] = "test";
    os.environ["AWS_SECRET_ACCESS_KEY"] = "test";
}

# Create the bucket in LocalStack
glob s3_client = boto3.client(
         "s3",
         endpoint_url=S3_ENDPOINT,
         region_name="us-east-1",
         aws_access_key_id="test",
         aws_secret_access_key="test"
     );

with entry {
    s3_client.create_bucket(Bucket=TEST_BUCKET);
}


test "native store builtin resolves to localstack s3" {
    s = store();
    assert isinstance(s, S3Storage);
    assert s.bucket == TEST_BUCKET;
    assert s.endpoint_url == S3_ENDPOINT;
}

test "s3 container upload and download" {
    s = store();
    content = "Hello from LocalStack!";
    s.upload(io.BytesIO(content.encode()), "hello.txt");

    assert s.exists("hello.txt");

    downloaded = s.download("hello.txt");
    assert downloaded.read().decode() == content;
}

test "s3 container metadata and public urls" {
    s = store();
    s.upload(io.BytesIO(b"metadata test"), "meta.txt");

    meta = s.get_metadata("meta.txt");
    assert meta["size"] > 0;
    assert "meta.txt" in meta["name"];

    # Check pre-signed URL generation
    url = s.get_url("meta.txt");
    assert "http" in url;
    assert TEST_BUCKET in url;
    assert "meta.txt" in url;
}

test "s3 container copy and move" {
    s = store();
    s.upload(io.BytesIO(b"shuttle"), "source.txt");

    # Test Copy
    s.copy("source.txt", "copy.txt");
    assert s.exists("source.txt");
    assert s.exists("copy.txt");

    # Test Move
    s.move("copy.txt", "moved.txt");
    assert not s.exists("copy.txt");
    assert s.exists("moved.txt");
}

test "s3 container list and delete" {
    s = store();
    s.upload(io.BytesIO(b"f1"), "dir/file1.txt");
    s.upload(io.BytesIO(b"f2"), "dir/file2.txt");

    files = s.list_files("dir/");
    assert len(files) == 2;
    assert "dir/file1.txt" in files;

    s.delete("dir/file1.txt");
    assert not s.exists("dir/file1.txt");
    assert s.exists("dir/file2.txt");
}
