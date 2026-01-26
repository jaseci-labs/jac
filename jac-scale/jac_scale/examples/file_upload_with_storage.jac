"""File Upload Walker examples using Storage Abstraction."""
import from fastapi { UploadFile }
import from jac_scale.factories.storage_factory { StorageFactory }
import from jac_scale.abstractions.storage { Storage }
import from uuid { uuid4 }
import from datetime { datetime }
import from typing { Any }
import io;

glob storage: Storage = StorageFactory.get_default({'base_path': './uploads'});

"""Upload a file to storage."""
walker UploadFile {
    has file: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        file_ext = self.file.filename.rsplit('.', 1)[-1] if '.' in self.file.filename else '';
        unique_name = f"{uuid4()}.{file_ext}" if file_ext else str(uuid4());
        storage_path = f"{self.folder}/{unique_name}";

        storage.upload(self.file.file, storage_path);
        metadata = storage.get_metadata(storage_path);

        report {
            "success": True,
            "original_filename": self.file.filename,
            "storage_path": storage_path,
            "size": metadata['size'],
            "content_type": self.file.content_type,
            "url": storage.get_url(storage_path)
        };
    }
}

"""Upload an image with content type validation."""
walker UploadImage {
    has image: UploadFile;
    has alt_text: str = "";

    can process with `root entry {
        allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        if self.image.content_type not in allowed_types {
            report {"success": False, "error": f"Invalid image type: {self.image.content_type}"};
            return;
        }

        today = datetime.now().strftime('%Y/%m/%d');
        file_ext = self.image.filename.rsplit('.', 1)[-1] if '.' in self.image.filename else 'jpg';
        storage_path = f"images/{today}/{uuid4()}.{file_ext}";

        storage.upload(self.image.file, storage_path, {'alt_text': self.alt_text});

        report {
            "success": True,
            "original_filename": self.image.filename,
            "storage_path": storage_path,
            "url": storage.get_url(storage_path),
            "alt_text": self.alt_text
        };
    }
}

"""Download a file from storage."""
walker DownloadFile {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": f"File not found: {self.path}"};
            return;
        }
        metadata = storage.get_metadata(self.path);
        content = storage.download(self.path);
        report {
            "success": True,
            "path": self.path,
            "size": metadata['size'],
            "content_base64": __import__('base64').b64encode(content).decode('utf-8')
        };
    }
}

"""Delete a file from storage."""
walker DeleteFile {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": f"File not found: {self.path}"};
            return;
        }
        deleted = storage.delete(self.path);
        report {"success": deleted, "path": self.path};
    }
}

"""List files in storage."""
walker ListFiles {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for file_path in storage.list_files(self.folder, self.recursive) {
            try {
                metadata = storage.get_metadata(file_path);
                files.append({
                    "path": file_path,
                    "size": metadata['size'],
                    "modified": metadata['modified']
                });
            } except Exception {
                files.append({"path": file_path, "error": "Could not get metadata"});
            }
        }
        report {"success": True, "folder": self.folder, "files": files, "count": len(files)};
    }
}

"""Get storage info."""
walker StorageInfo {
    can process with `root entry {
        info = storage.get_info();
        info['available'] = storage.is_available();
        report info;
    }
}
