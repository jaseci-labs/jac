"""Cross-platform path utility functions for the language server."""

import os;
import from pathlib { Path }
import from urllib.parse { unquote }
import from jaclang.vendor.pygls { uris }


"""Normalize a filesystem path to be platform-independent."""
def normalize_fs_path(path: str) -> str {
    # Handle empty paths
    if path == "" or path is None {
        return path;
    }
    
    # Convert backslashes to forward slashes for consistency
    normalized = path.replace('\\', '/');
    
    # Try to resolve using pathlib for better cross-platform handling
    try {
        path_obj = Path(normalized);
        # Only resolve if it's an absolute path or we want to keep it relative
        if path_obj.is_absolute() {
            resolved = path_obj.resolve();
            return str(resolved).replace('\\', '/');
        } else {
            # For relative paths, just normalize separators
            return normalized;
        }
    } except Exception {
        # If path resolution fails, just normalize separators
        return normalized;
    }
}


"""Convert URI to normalized filesystem path."""
def uri_to_fs_path(uri: str) -> str {
    if uri == "" or uri is None {
        return uri;
    }
    
    # Remove file:// prefix if present
    cleaned_uri = uri;
    if uri.startswith('file://') {
        cleaned_uri = uri[7:];  # Remove 'file://'
    }
    
    # URL decode to handle encoded characters like %3A for :
    decoded_path = unquote(cleaned_uri);
    
    # Handle Windows paths that start with /C: pattern
    if len(decoded_path) > 2 and decoded_path[0] == '/' and decoded_path[2] == ':' {
        decoded_path = decoded_path[1:];  # Remove leading /
    }
    
    return normalize_fs_path(decoded_path);
}


"""Convert filesystem path to URI."""
def fs_path_to_uri(path: str) -> str {
    if path == "" or path is None {
        return path;
    }
    
    # Handle Windows paths - detect if it's a Windows path even on Unix
    is_windows_path = len(path) > 1 and path[1] == ':';
    
    if is_windows_path {
        # For Windows paths, ensure proper format for URI conversion
        # Convert c:\path or c:/path to proper format
        clean_path = path.replace('\\', '/');
        if not clean_path.startswith('/') {
            clean_path = '/' + clean_path;
        }
        # Use pygls uris.from_fs_path but with the corrected path
        return uris.from_fs_path(clean_path[1:]);  # Remove the leading / we added
    } else {
        # For Unix paths, normalize and use pygls directly
        normalized_path = normalize_fs_path(path);
        return uris.from_fs_path(normalized_path);
    }
}


"""Check if two paths refer to the same file."""
def paths_equal(path1: str, path2: str) -> bool {
    if (path1 == "" or path1 is None) or (path2 == "" or path2 is None) {
        return path1 == path2;
    }
    
    # Convert both to normalized filesystem paths
    norm_path1 = uri_to_fs_path(path1) if path1.startswith('file://') else extract_fs_path(path1);
    norm_path2 = uri_to_fs_path(path2) if path2.startswith('file://') else extract_fs_path(path2);
    
    # Normalize both paths to handle Windows vs Unix differences
    # Convert both to a canonical format for comparison
    def canonicalize(p: str) -> str {
        # Normalize path separators
        canonical = p.replace('\\', '/');
        
        # Handle Windows drive letters consistently
        if len(canonical) > 1 and canonical[1] == ':' {
            # Windows path like c:/path -> /c:/path for comparison
            return '/' + canonical.lower();
        } elif len(canonical) > 2 and canonical[0] == '/' and canonical[2] == ':' {
            # Already in /c:/path format -> normalize to lowercase
            return canonical.lower();
        } else {
            # Unix path
            return canonical;
        }
    }
    
    canon1 = canonicalize(norm_path1);
    canon2 = canonicalize(norm_path2);
    
    # Compare normalized paths
    return canon1 == canon2;
}


"""Extract the actual filesystem path from various path formats."""
def extract_fs_path(path: str) -> str {
    if path == "" or path is None {
        return path;
    }
    
    if path.startswith('file://') {
        return uri_to_fs_path(path);
    } elif '%' in path {
        # Handle URL-encoded paths that don't have file:// prefix
        return uri_to_fs_path(path);
    } else {
        return normalize_fs_path(path);
    }
}
