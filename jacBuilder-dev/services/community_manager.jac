"""Community gallery manager — disk I/O for shared JacPack submissions."""

import os;
import json;
import time;
import shutil;
import from pathlib {Path}
import from datetime {datetime}
import from threading {Lock}
import from uuid {uuid4}

glob COMMUNITY_ROOT: str = os.path.join(str(Path.home()), ".jac-ide", "community");
glob _community_lock = Lock();

"""UTC timestamp for metadata."""
def _utc_now() -> str {
    return datetime.utcnow().isoformat() + "Z";
}

"""Ensure community root directory exists."""
def _ensure_community_root() -> None {
    os.makedirs(COMMUNITY_ROOT, exist_ok=True);
}

"""Path to community manifest file."""
def _manifest_path() -> str {
    return os.path.join(COMMUNITY_ROOT, "manifest.json");
}

"""Read manifest without acquiring lock (internal use inside already-locked sections)."""
def _read_manifest_unlocked() -> list {
    _ensure_community_root();
    mp = _manifest_path();
    if not os.path.exists(mp) {
        return [];
    }
    try {
        with open(mp, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        return data if isinstance(data, list) else [];
    } except Exception {
        return [];
    }
}

"""Write manifest without acquiring lock (internal use inside already-locked sections)."""
def _write_manifest_unlocked(items: list) -> None {
    _ensure_community_root();
    with open(_manifest_path(), "w", encoding="utf-8") as f {
        json.dump(items, f, indent=2);
    }
}

"""Read community manifest, returns list of CommunityItem dicts."""
def get_community_manifest() -> list {
    _community_lock.acquire();
    try {
        return _read_manifest_unlocked();
    } finally {
        _community_lock.release();
    }
}

"""Write community manifest."""
def save_community_manifest(items: list) -> None {
    _community_lock.acquire();
    try {
        _write_manifest_unlocked(items);
    } finally {
        _community_lock.release();
    }
}

"""Submit a jacpack to community gallery. Copies file, updates manifest, returns item dict."""
def submit_community_template(
    user_id: str,
    display_name: str,
    name: str,
    description: str,
    tags: list,
    jacpack_path: str
) -> dict {
    try {
        if not jacpack_path or not os.path.exists(jacpack_path) {
            return {"success": False, "error": "JacPack file not found"};
        }
        if not name or not name.strip() {
            return {"success": False, "error": "Name is required"};
        }
        if len(name.strip()) > 100 {
            return {"success": False, "error": "Name must be 100 characters or less"};
        }
        if description and len(description.strip()) > 1000 {
            return {"success": False, "error": "Description must be 1000 characters or less"};
        }
        if len(tags) > 10 {
            return {"success": False, "error": "Maximum 10 tags allowed"};
        }
        _ensure_community_root();

        clean_tags: list = [];
        for tag in tags {
            t = tag.strip()[:50] if isinstance(tag, str) else "";
            if t {
                clean_tags.append(t);
            }
        }

        _community_lock.acquire();
        try {
            comm_id = "comm_" + str(uuid4()).replace("-", "")[:16];
            dest_filename = comm_id + ".jacpack";
            dest_path = os.path.join(COMMUNITY_ROOT, dest_filename);
            shutil.copy2(jacpack_path, dest_path);

            item: dict = {
                "id": comm_id,
                "user_id": user_id,
                "display_name": display_name or "anonymous",
                "name": name.strip(),
                "description": (description.strip() if description else ""),
                "tags": clean_tags,
                "filename": dest_filename,
                "clone_count": 0,
                "created_at": _utc_now(),
                "is_active": True
            };

            items = _read_manifest_unlocked();
            items.append(item);
            _write_manifest_unlocked(items);
        } finally {
            _community_lock.release();
        }

        return {"success": True, "item": _public_item(item)};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Strip internal fields from a community item for public responses."""
def _public_item(item: dict) -> dict {
    safe = dict(item);
    safe.pop("filename", None);
    return safe;
}

"""List community templates, optionally filtered by search query or tag."""
def list_community_templates(search: str = "", tag: str = "") -> list {
    items = get_community_manifest();
    result: list = [];
    for item in items {
        if not item.get("is_active", True) {
            continue;
        }
        if search {
            q = search.lower();
            name_match = q in item.get("name", "").lower();
            desc_match = q in item.get("description", "").lower();
            author_match = q in item.get("display_name", "").lower();
            if not (name_match or desc_match or author_match) {
                continue;
            }
        }
        if tag {
            item_tags: list = item.get("tags", []);
            tag_match = False;
            for t in item_tags {
                if t.lower() == tag.lower() {
                    tag_match = True;
                    break;
                }
            }
            if not tag_match {
                continue;
            }
        }
        result.append(_public_item(item));
    }
    result.sort(key=lambda i: i.get("created_at", ""), reverse=True);
    return result;
}

"""Get a single community item by id."""
def get_community_template(comm_id: str) -> dict {
    if not comm_id {
        return {"success": False, "error": "comm_id is required"};
    }
    items = get_community_manifest();
    for item in items {
        if item.get("id", "") == comm_id {
            return {"success": True, "item": _public_item(item)};
        }
    }
    return {"success": False, "error": "Community item not found"};
}

"""Return absolute path to a community jacpack file."""
def get_community_jacpack_path(comm_id: str) -> str {
    if not comm_id {
        return "";
    }
    items = get_community_manifest();
    for item in items {
        if item.get("id", "") == comm_id {
            filename = item.get("filename", "");
            if not filename {
                return "";
            }
            full_path = os.path.join(COMMUNITY_ROOT, filename);
            return full_path if os.path.exists(full_path) else "";
        }
    }
    return "";
}

"""Increment clone count for a community item."""
def increment_clone_count(comm_id: str) -> None {
    _community_lock.acquire();
    try {
        items = _read_manifest_unlocked();
        for item in items {
            if item.get("id", "") == comm_id {
                item["clone_count"] = item.get("clone_count", 0) + 1;
                break;
            }
        }
        _write_manifest_unlocked(items);
    } finally {
        _community_lock.release();
    }
}

"""Remove a community item (owner-only). Returns True on success."""
def remove_community_template(comm_id: str, user_id: str) -> bool {
    _community_lock.acquire();
    try {
        items = _read_manifest_unlocked();
        updated: list = [];
        found = False;
        for item in items {
            if item.get("id", "") == comm_id {
                if item.get("user_id", "") != user_id {
                    return False;
                }
                found = True;
                jacpack_file = os.path.join(COMMUNITY_ROOT, item.get("filename", ""));
                if os.path.exists(jacpack_file) {
                    try {
                        os.remove(jacpack_file);
                    } except Exception {
                    }
                }
            } else {
                updated.append(item);
            }
        }
        if found {
            _write_manifest_unlocked(updated);
        }
        return found;
    } finally {
        _community_lock.release();
    }
}
