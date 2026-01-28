# File Storage

Handle file uploads, downloads, and storage operations in your Jac full-stack application.

> **Prerequisites**
>
> - Completed: [Backend Integration](backend.md)
> - Required: `jac-scale` plugin (for multipart file uploads)
> - Time: ~25 minutes

---

## Overview

Jac provides a storage abstraction layer through `store()`. By default, files are stored locally, but with `jac-scale` you can configure cloud backends (S3, GCS, Azure).

```
┌─────────────┐     multipart      ┌─────────────┐     storage     ┌─────────────┐
│  Frontend   │ ─────────────────→ │   Walker    │ ───────────────→ │   Storage   │
│  FormData   │     POST file      │   upload    │   store()  │   Backend   │
└─────────────┘                    └─────────────┘                  └─────────────┘
```

---

## Setup

### Install jac-scale

```bash
pip install jac-scale
```

### Configure Storage

In `jac.toml`:

```toml
[storage]
type = "local"
base_path = "./uploads"
create_dirs = true
```

Or use environment variables:

```bash
export JAC_STORAGE_TYPE=local
export JAC_STORAGE_PATH=./uploads
export JAC_STORAGE_CREATE_DIRS=true
```

---

## Backend: Upload Walker

Create a walker that handles file uploads:

```jac
import from fastapi { UploadFile }
import from uuid { uuid4 }

glob storage = store({'base_path': './uploads'});

walker:pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        # Generate unique filename
        ext = self.file.filename.rsplit('.', 1)[-1] if '.' in self.file.filename else '';
        unique_name = f"{uuid4()}.{ext}" if ext else str(uuid4());
        path = f"{self.folder}/{unique_name}";

        # Upload file to storage
        storage.upload(self.file.file, path);

        # Get metadata
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "original_filename": self.file.filename,
            "storage_path": path,
            "size": metadata['size'],
            "content_type": self.file.content_type
        };
    }
}
```

---

## Backend: List and Delete

```jac
glob storage = store({'base_path': './uploads'});

walker:pub list_files {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata['size'],
                "modified": str(metadata['modified'])
            });
        }
        report {"files": files, "count": len(files)};
    }
}

walker:pub delete_file {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": "File not found"};
            return;
        }
        deleted = storage.delete(self.path);
        report {"success": deleted, "path": self.path};
    }
}
```

---

## Frontend: Upload Component

Since file uploads use multipart/form-data, use `fetch()` directly:

```jac
cl {
    def:pub FileUploader() -> any {
        has selectedFile: any = None;
        has uploading: bool = False;
        has result: dict = {};

        async def handleUpload() -> None {
            if not selectedFile {
                return;
            }

            uploading = True;

            # Get auth token
            token = localStorage.getItem("token");

            # Create FormData
            formData = Reflect.construct(FormData, []);
            formData.append("file", selectedFile);
            formData.append("folder", "documents");

            # Send multipart request
            response = await fetch("/walker/upload_file", {
                "method": "POST",
                "headers": {
                    "Authorization": "Bearer " + token
                },
                "body": formData
            });

            data = await response.json();
            result = data.reports[0][0];
            uploading = False;
        }

        def handleFileChange(event: any) -> None {
            selectedFile = event.target.files[0];
        }

        return <div>
            <input
                type="file"
                onChange={lambda e: any -> None { handleFileChange(e); }}
            />
            <button
                onClick={lambda -> None { handleUpload(); }}
                disabled={uploading or not selectedFile}
            >
                {("Uploading..." if uploading else "Upload")}
            </button>

            {result.success and (
                <div>
                    <p>Uploaded: {result.original_filename}</p>
                    <p>Size: {result.size} bytes</p>
                </div>
            )}
        </div>;
    }
}
```

---

## Frontend: File List

```jac
cl {
    def:pub FileList() -> any {
        has files: list = [];
        has loading: bool = False;

        async def loadFiles() -> None {
            loading = True;
            token = localStorage.getItem("token");

            response = await fetch("/walker/list_files", {
                "method": "POST",
                "headers": {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + token
                },
                "body": JSON.stringify({"folder": "", "recursive": True})
            });

            data = await response.json();
            files = data.reports[0][0].files;
            loading = False;
        }

        async def deleteFile(path: str) -> None {
            token = localStorage.getItem("token");

            await fetch("/walker/delete_file", {
                "method": "POST",
                "headers": {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + token
                },
                "body": JSON.stringify({"path": path})
            });

            await loadFiles();
        }

        async can with entry {
            await loadFiles();
        }

        return <div>
            <h3>Uploaded Files</h3>
            {loading and <p>Loading...</p>}

            <ul>
                {files.map(lambda f: any -> any {
                    return <li key={f.path}>
                        {f.path} ({f.size} bytes)
                        <button onClick={lambda -> None { deleteFile(f.path); }}>
                            Delete
                        </button>
                    </li>;
                })}
            </ul>

            <button onClick={lambda -> None { loadFiles(); }}>
                Refresh
            </button>
        </div>;
    }
}
```

---

## Image Upload with Validation

```jac
import from fastapi { UploadFile }
import from uuid { uuid4 }
import from datetime { datetime }

glob storage = store({'base_path': './uploads'});

walker:pub upload_image {
    has image: UploadFile;

    can process with `root entry {
        # Validate content type
        allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        if self.image.content_type not in allowed {
            report {"success": False, "error": "Invalid image type"};
            return;
        }

        # Organize by date
        today = datetime.now().strftime('%Y/%m/%d');
        ext = self.image.filename.rsplit('.', 1)[-1] if '.' in self.image.filename else 'jpg';
        path = f"images/{today}/{uuid4()}.{ext}";

        storage.upload(self.image.file, path);

        report {
            "success": True,
            "path": path
        };
    }
}
```

---

## Storage API Reference

| Method | Description | Returns |
|--------|-------------|---------|
| `store(config?)` | Get storage instance | Storage |
| `storage.upload(source, dest)` | Upload file | path string |
| `storage.download(source, dest?)` | Download file | bytes or None |
| `storage.delete(path)` | Delete file | bool |
| `storage.exists(path)` | Check existence | bool |
| `storage.list_files(prefix, recursive?)` | List files | Generator |
| `storage.get_metadata(path)` | Get file info | dict |
| `storage.copy(src, dest)` | Copy file | bool |
| `storage.move(src, dest)` | Move file | bool |

**Metadata dict keys:** `size`, `modified`, `created`, `is_dir`, `name`

---

## Configuration Options

### jac.toml

```toml
[storage]
type = "local"       # local, s3, gcs, azure (cloud with jac-scale)
base_path = "./storage"
create_dirs = true
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAC_STORAGE_TYPE` | Backend type | `local` |
| `JAC_STORAGE_PATH` | Base path | `./storage` |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create dirs | `true` |

---

## Complete Example

```jac
# main.jac
import from fastapi { UploadFile }
import from uuid { uuid4 }

glob storage = store({'base_path': './uploads'});

# Backend walkers
walker:pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        ext = self.file.filename.rsplit('.', 1)[-1] if '.' in self.file.filename else '';
        unique_name = f"{uuid4()}.{ext}" if ext else str(uuid4());
        path = f"{self.folder}/{unique_name}";

        storage.upload(self.file.file, path);
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "filename": self.file.filename,
            "path": path,
            "size": metadata['size']
        };
    }
}

walker:pub list_files {
    has folder: str = "";

    can process with `root entry {
        files = [];
        for path in storage.list_files(self.folder, True) {
            metadata = storage.get_metadata(path);
            files.append({"path": path, "size": metadata['size']});
        }
        report {"files": files};
    }
}

# Frontend
cl {
    def:pub app() -> any {
        has files: list = [];
        has selectedFile: any = None;
        has message: str = "";

        async def upload() -> None {
            if not selectedFile { return; }

            token = localStorage.getItem("token");
            formData = Reflect.construct(FormData, []);
            formData.append("file", selectedFile);

            response = await fetch("/walker/upload_file", {
                "method": "POST",
                "headers": {"Authorization": "Bearer " + token},
                "body": formData
            });

            data = await response.json();
            result = data.reports[0][0];
            message = "Uploaded: " + result.filename;
            await loadFiles();
        }

        async def loadFiles() -> None {
            token = localStorage.getItem("token");
            response = await fetch("/walker/list_files", {
                "method": "POST",
                "headers": {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + token
                },
                "body": JSON.stringify({"folder": ""})
            });
            data = await response.json();
            files = data.reports[0][0].files;
        }

        async can with entry {
            await loadFiles();
        }

        return <div style={{"padding": "2rem"}}>
            <h1>File Manager</h1>

            <div>
                <input
                    type="file"
                    onChange={lambda e: any -> None { selectedFile = e.target.files[0]; }}
                />
                <button onClick={lambda -> None { upload(); }}>
                    Upload
                </button>
            </div>

            {message and <p>{message}</p>}

            <h2>Files</h2>
            <ul>
                {files.map(lambda f: any -> any {
                    return <li key={f.path}>{f.path} ({f.size} bytes)</li>;
                })}
            </ul>
        </div>;
    }
}
```

---

## Key Takeaways

| Concept | Usage |
|---------|-------|
| Get storage | `storage = store({'base_path': './uploads'})` |
| Upload file | `storage.upload(file_obj, 'path/to/file')` |
| File parameter | `has file: UploadFile` in walker |
| Frontend upload | Use `FormData` with `fetch()` |
| Requires | `jac-scale` for multipart support |

---

## Next Steps

- [Authentication](auth.md) - Secure your file uploads
- [Build a Todo App](todo-app.md) - Complete full-stack example

**Reference:**

- [Storage API](../../jac-scale/storage.md) - Complete storage documentation
- [jac-scale Plugin](../../reference/plugins/jac-scale.md) - Cloud storage configuration
