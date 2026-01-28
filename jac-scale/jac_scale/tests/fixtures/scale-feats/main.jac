"""jac-scale features test fixture.

Demonstrates jac-scale specific features that require FastAPI:
- Storage abstraction with file uploads
- UploadFile handling
"""

import from fastapi { UploadFile }
import from uuid { uuid4 }

# Initialize storage with custom base path
glob storage = store(base_path="./uploads");

# ============================================================================
# Storage API Walkers
# ============================================================================

"""Upload a file to storage."""
walker:pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        # Generate unique filename
        ext = self.file.filename.rsplit(".", 1)[-1] if "." in self.file.filename else "";
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
            "size": metadata["size"],
            "content_type": self.file.content_type
        };
    }
}

"""List files in storage."""
walker:pub list_files {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata["size"],
                "modified": str(metadata["modified"])
            });
        }
        report {"files": files, "count": len(files)};
    }
}

"""Delete a file from storage."""
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

"""Download a file from storage."""
walker:pub download_file {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": "File not found"};
            return;
        }
        content = storage.download(self.path);
        metadata = storage.get_metadata(self.path);
        report {
            "success": True,
            "path": self.path,
            "size": metadata["size"],
            "content_length": len(content) if content else 0
        };
    }
}

"""Check if a file exists in storage."""
walker:pub file_exists {
    has path: str;

    can process with `root entry {
        exists = storage.exists(self.path);
        report {"path": self.path, "exists": exists};
    }
}

"""Copy a file within storage."""
walker:pub copy_file {
    has source: str;
    has destination: str;

    can process with `root entry {
        if not storage.exists(self.source) {
            report {"success": False, "error": "Source file not found"};
            return;
        }
        result = storage.copy(self.source, self.destination);
        report {"success": result, "source": self.source, "destination": self.destination};
    }
}

"""Move a file within storage."""
walker:pub move_file {
    has source: str;
    has destination: str;

    can process with `root entry {
        if not storage.exists(self.source) {
            report {"success": False, "error": "Source file not found"};
            return;
        }
        result = storage.move(self.source, self.destination);
        report {"success": result, "source": self.source, "destination": self.destination};
    }
}

# ============================================================================
# Health Check
# ============================================================================

"""Simple health check walker."""
walker:pub health {
    can check with `root entry {
        report {"status": "ok", "features": ["storage", "file_upload"]};
    }
}
