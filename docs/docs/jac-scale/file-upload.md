# File Upload Support

JAC Scale provides seamless file upload support through FastAPI's `UploadFile` type. When you define a walker with an `UploadFile` field, the endpoint automatically accepts multipart/form-data requests.

## Basic Usage

### Single File Upload

To create a walker that accepts file uploads, import `UploadFile` from FastAPI and use it as a field type:

```jac
import from fastapi { UploadFile }

walker ProcessDocument {
    has document: UploadFile;
    has description: str = "";

    can process with `root entry {
        print(f"Received: {self.document.filename}");
        print(f"Type: {self.document.content_type}");
        print(f"Size: {self.document.size} bytes");

        report {
            "filename": self.document.filename,
            "content_type": self.document.content_type,
            "size": self.document.size,
            "description": self.description
        };
    }
}
```

**API Request (using curl):**

```bash
curl -X POST "http://localhost:8000/walker/ProcessDocument" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "document=@/path/to/file.pdf" \
  -F "description=My document"
```

## UploadFile Properties and Methods

The `UploadFile` object provides the following properties and methods:

| Property/Method | Type | Description |
|----------------|------|-------------|
| `filename` | `str` | Original filename from the client |
| `content_type` | `str` | MIME type (e.g., `application/pdf`, `image/png`) |
| `size` | `int` | File size in bytes |
| `file` | `SpooledTemporaryFile` | The underlying file object |

## Form Data Handling

When a walker has `UploadFile` fields, all other body parameters are automatically converted to form fields. This means you send both files and data using multipart/form-data:

```jac
walker CreatePost {
    has title: str;           # Form field
    has content: str;         # Form field
    has image: UploadFile;    # File upload
    has tags: str = "";       # Form field with default

    can process with `root entry {
        # All fields available here
        report {
            "title": self.title,
            "content": self.content,
            "image_name": self.image.filename,
            "tags": self.tags
        };
    }
}
```

**Request:**

```bash
curl -X POST "http://localhost:8000/walker/CreatePost" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "title=My Post" \
  -F "content=This is the post content" \
  -F "image=@photo.jpg" \
  -F "tags=tech,news"
```

## Client Examples

### TypeScript/JavaScript (Using Fetch API)

Here's how to upload files from a TypeScript or JavaScript client:

**Single File Upload:**

```typescript
async function uploadDocument(file: File, description: string, token: string) {
  const formData = new FormData();
  formData.append("document", file);
  formData.append("description", description);

  const response = await fetch("http://localhost:8000/walker/ProcessDocument", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });

  return await response.json();
}

// Usage with file input
const fileInput = document.querySelector<HTMLInputElement>("#fileInput");
fileInput?.addEventListener("change", async (e) => {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (file) {
    const result = await uploadDocument(file, "My document", "YOUR_TOKEN");
    console.log(result);
  }
});
```

**File Upload with Additional Form Fields:**

```typescript
interface CreatePostParams {
  title: string;
  content: string;
  image: File;
  tags?: string;
}

async function createPost(params: CreatePostParams, token: string) {
  const formData = new FormData();
  formData.append("title", params.title);
  formData.append("content", params.content);
  formData.append("image", params.image);
  if (params.tags) {
    formData.append("tags", params.tags);
  }

  const response = await fetch("http://localhost:8000/walker/CreatePost", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`Upload failed: ${response.statusText}`);
  }

  return await response.json();
}

// Usage
const imageFile = new File(["..."], "photo.jpg", { type: "image/jpeg" });
const result = await createPost(
  {
    title: "My Post",
    content: "This is the post content",
    image: imageFile,
    tags: "tech,news",
  },
  "YOUR_TOKEN"
);
```

### React Example

```tsx
import { useState, ChangeEvent, FormEvent } from "react";

function FileUploadForm() {
  const [file, setFile] = useState<File | null>(null);
  const [description, setDescription] = useState("");
  const [uploading, setUploading] = useState(false);

  const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
    if (e.target.files?.[0]) {
      setFile(e.target.files[0]);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!file) return;

    setUploading(true);
    try {
      const formData = new FormData();
      formData.append("document", file);
      formData.append("description", description);

      const response = await fetch(
        "http://localhost:8000/walker/ProcessDocument",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${localStorage.getItem("token")}`,
          },
          body: formData,
        }
      );

      const result = await response.json();
      console.log("Upload successful:", result);
    } catch (error) {
      console.error("Upload failed:", error);
    } finally {
      setUploading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input type="file" onChange={handleFileChange} />
      <input
        type="text"
        value={description}
        onChange={(e) => setDescription(e.target.value)}
        placeholder="Description"
      />
      <button type="submit" disabled={!file || uploading}>
        {uploading ? "Uploading..." : "Upload"}
      </button>
    </form>
  );
}
```

### jac-client Example

When using jac-client for frontend development, you can upload files directly using the `spawn` syntax with `FormData`:

```jac
cl import from react {useState}

cl {
    def:pub FileUploader() -> any {
        [file, setFile] = useState(None);
        [uploading, setUploading] = useState(False);

        async def handleUpload() -> None {
            if not file { return; }

            setUploading(True);
            formData = new FormData();
            formData.append("document", file);
            formData.append("description", "Uploaded from jac-client");

            response = fetch("/walker/ProcessDocument", {
                "method": "POST",
                "headers": {
                    "Authorization": f"Bearer {localStorage.getItem('token')}"
                },
                "body": formData
            });

            result = response.json();
            console.log("Upload result:", result);
            setUploading(False);
        }

        return <div>
            <input
                type="file"
                onChange={lambda e: any -> None { setFile(e.target.files[0]); }}
            />
            <button onClick={handleUpload} disabled={uploading}>
                {uploading ? "Uploading..." : "Upload"}
            </button>
        </div>;
    }
}
```

## Storage Abstraction

JAC Scale provides a storage abstraction layer that allows you to easily store uploaded files to different backends (local filesystem, S3, etc.) using a consistent API.

### Using StorageFactory

The `StorageFactory` creates storage instances based on configuration:

```jac
import from jac_scale.factories.storage_factory { StorageFactory }

# Get default storage (reads JAC_STORAGE_TYPE env var, defaults to 'local')
storage = StorageFactory.get_default();

# Or create with specific configuration
storage = StorageFactory.create('local', {'base_path': './uploads'});
```

### Complete File Upload Example with Storage

```jac
import from fastapi { UploadFile }
import from jac_scale.factories.storage_factory { StorageFactory }
import:py from uuid { uuid4 }

# Initialize storage
glob storage = StorageFactory.get_default({'base_path': './uploads'});

walker UploadDocument {
    has document: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        # Generate unique filename
        file_ext = self.document.filename.rsplit('.', 1)[-1] if '.' in self.document.filename else '';
        unique_name = f"{uuid4()}.{file_ext}" if file_ext else str(uuid4());
        storage_path = f"{self.folder}/{unique_name}";

        # Upload to storage
        saved_path = storage.upload(self.document.file, storage_path);

        # Get metadata
        metadata = storage.get_metadata(storage_path);

        report {
            "success": True,
            "original_filename": self.document.filename,
            "storage_path": storage_path,
            "size": metadata['size'],
            "url": storage.get_url(storage_path)
        };
    }
}
```

### Storage API Methods

| Method | Description |
|--------|-------------|
| `upload(source, destination, metadata={})` | Upload a file to storage |
| `download(source, destination=None)` | Download a file (returns bytes if destination is None) |
| `delete(path)` | Delete a file |
| `exists(path)` | Check if file exists |
| `list_files(prefix="", recursive=False)` | List files in a directory |
| `get_metadata(path)` | Get file metadata (size, modified, etc.) |
| `get_url(path, expiry_seconds=3600)` | Get URL/path to access file |
| `copy(source, destination)` | Copy a file |
| `move(source, destination)` | Move a file |
| `is_available()` | Check if storage is available |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAC_STORAGE_TYPE` | Storage backend type | `local` |
| `JAC_STORAGE_LOCAL_PATH` | Base path for local storage | `./storage` |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories | `true` |

### Additional Walkers

```jac
"""List files in storage."""
walker ListFiles {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for file_path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(file_path);
            files.append({
                "path": file_path,
                "size": metadata['size']
            });
        }
        report {"files": files, "count": len(files)};
    }
}

"""Delete a file from storage."""
walker DeleteFile {
    has path: str;

    can process with `root entry {
        if storage.exists(self.path) {
            storage.delete(self.path);
            report {"success": True, "deleted": self.path};
        } else {
            report {"success": False, "error": "File not found"};
        }
    }
}
```
