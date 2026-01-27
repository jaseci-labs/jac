# Storage Abstraction

Jac provides a storage abstraction layer for managing file uploads and storage operations. The `get_storage()` builtin returns a `Storage` instance configured from your project settings, and plugins like jac-scale can override it to provide cloud backends.

## Quick Start

```jac
with entry {
    # Get storage (uses jac.toml / env vars / defaults)
    storage = get_storage({'base_path': './uploads'});

    # Upload a file
    storage.upload('/path/to/file.txt', 'documents/file.txt');

    # Download a file
    content = storage.download('documents/file.txt');

    # Check if file exists
    if storage.exists('documents/file.txt') {
        print("File exists!");
    }

    # Delete a file
    storage.delete('documents/file.txt');
}
```

## Getting a Storage Instance

The recommended way to get storage is via the `get_storage()` builtin, which respects your project configuration:

```jac
with entry {
    # Default storage (reads jac.toml, then env vars, then defaults to local)
    storage = get_storage();

    # With explicit config
    storage = get_storage({'base_path': './uploads', 'create_dirs': True});
}
```

You can also create `LocalStorage` directly:

```jac
import from jaclang.runtimelib.storage { LocalStorage }

with entry {
    storage = LocalStorage(base_path='/data/uploads');
}
```

## Storage API

All storage implementations provide these methods:

### upload

Upload a file to storage.

```jac
with entry {
    storage = get_storage();

    # From file path
    storage.upload('/tmp/myfile.txt', 'documents/myfile.txt');

    # With metadata
    storage.upload('/tmp/file.txt', 'path/file.txt', {'author': 'john'});
}
```

**Parameters:**

- `source`: File path (str) or file-like object
- `destination`: Path in storage
- `metadata`: Optional metadata dict

**Returns:** Path where file was stored

### download

Download a file from storage.

```jac
with entry {
    storage = get_storage();

    # Get file content as bytes
    content = storage.download('documents/file.txt');

    # Download to a file path
    storage.download('documents/file.txt', '/tmp/downloaded.txt');
}
```

**Parameters:**

- `source`: Path in storage
- `destination`: File path, file object, or None

**Returns:** Bytes if destination is None, otherwise None

### delete

Delete a file from storage.

```jac
with entry {
    storage = get_storage();
    deleted = storage.delete('documents/file.txt');
    if deleted {
        print("File deleted");
    }
}
```

**Returns:** True if file was deleted, False if it didn't exist

### exists

Check if a file exists.

```jac
with entry {
    storage = get_storage();
    if storage.exists('documents/file.txt') {
        print("File exists");
    }
}
```

**Returns:** True if file exists

### list_files

List files in a directory.

```jac
with entry {
    storage = get_storage();

    # List files in a folder
    for file in storage.list_files('documents/') {
        print(file);
    }

    # List recursively
    for file in storage.list_files('documents/', recursive=True) {
        print(file);
    }
}
```

**Parameters:**

- `prefix`: Directory/prefix to list
- `recursive`: Whether to list recursively (default: False)

**Returns:** Generator of file paths

### get_metadata

Get file metadata.

```jac
with entry {
    storage = get_storage();
    metadata = storage.get_metadata('documents/file.txt');
    print(f"Size: {metadata['size']} bytes");
    print(f"Modified: {metadata['modified']}");
}
```

**Returns:** Dict with keys: `size`, `modified`, `created`, `is_dir`, `name`

### copy / move

Copy or move files within storage.

```jac
with entry {
    storage = get_storage();

    # Copy a file
    storage.copy('documents/file.txt', 'backup/file.txt');

    # Move a file
    storage.move('documents/old.txt', 'archive/old.txt');
}
```

**Returns:** True if successful, False otherwise

## File Upload Walker Example

Here's a complete example of a file upload walker using the storage abstraction:

```jac
import from fastapi { UploadFile }
import from uuid { uuid4 }

glob storage = get_storage({'base_path': './uploads'});

walker upload_document {
    has document: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        # Generate unique filename
        ext = self.document.filename.rsplit('.', 1)[-1] if '.' in self.document.filename else '';
        unique_name = f"{uuid4()}.{ext}" if ext else str(uuid4());
        path = f"{self.folder}/{unique_name}";

        # Upload file
        storage.upload(self.document.file, path);

        # Get metadata
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "original_filename": self.document.filename,
            "storage_path": path,
            "size": metadata['size']
        };
    }
}
```

**API Request:**

```bash
curl -X POST "http://localhost:8000/walker/upload_document" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "document=@/path/to/file.pdf" \
  -F "folder=reports"
```

## Image Upload with Validation

```jac
import from fastapi { UploadFile }
import from uuid { uuid4 }
import from datetime { datetime }

glob storage = get_storage({'base_path': './uploads'});

walker upload_image {
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

## List and Delete Files

```jac
glob storage = get_storage({'base_path': './uploads'});

walker list_files {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata['size']
            });
        }
        report {"files": files, "count": len(files)};
    }
}

walker delete_file {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": "File not found"};
            return;
        }
        deleted = storage.delete(self.path);
        report {"success": deleted};
    }
}
```

## Configuration

### jac.toml

```toml
[storage]
type = "local"
base_path = "./storage"
create_dirs = true
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAC_STORAGE_PATH` | Base path for local storage | `./storage` |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories | `true` |

### Direct Construction

```jac
import from jaclang.runtimelib.storage { LocalStorage }

with entry {
    storage = LocalStorage(base_path='/data/uploads', create_dirs=True);
}
```

## TypeScript Client Example

```typescript
async function uploadFile(file: File, folder: string, token: string) {
  const formData = new FormData();
  formData.append("document", file);
  formData.append("folder", folder);

  const response = await fetch("http://localhost:8000/walker/upload_document", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: formData,
  });

  return await response.json();
}

async function listFiles(folder: string, token: string) {
  const response = await fetch("http://localhost:8000/walker/list_files", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ folder, recursive: true }),
  });

  return await response.json();
}
```

## Best Practices

1. **Use unique filenames** - Generate UUIDs to avoid collisions
2. **Organize by date** - Use date-based folder structures for large volumes
3. **Validate uploads** - Check content types and file sizes before storing
4. **Handle errors** - Always check if files exist before operations
5. **Clean up** - Delete temporary files after processing
