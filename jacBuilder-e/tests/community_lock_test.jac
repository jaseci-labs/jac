"""Concurrency tests for community_manager lock protection."""

import os;
import json;
import time;
import from threading {Thread}
import from services.community_manager {
    COMMUNITY_ROOT,
    get_community_manifest,
    save_community_manifest,
    submit_community_template,
    increment_clone_count,
    remove_community_template,
    _manifest_path
}

glob _original_manifest: list = [];

"""Save original manifest before tests."""
def _backup_manifest() -> None {
    _original_manifest = get_community_manifest();
}

"""Restore original manifest after tests."""
def _restore_manifest() -> None {
    save_community_manifest(_original_manifest);
}

"""Create a dummy jacpack file for submit tests."""
def _create_dummy_jacpack(label: str) -> str {
    os.makedirs(COMMUNITY_ROOT, exist_ok=True);
    path = os.path.join(COMMUNITY_ROOT, "dummy_" + label + ".jacpack");
    with open(path, "w") as f {
        f.write("dummy");
    }
    return path;
}

test "concurrent submits do not lose entries" {
    _backup_manifest();
    try {
        save_community_manifest([]);

        num_threads = 20;
        jacpacks: list = [];
        for i in range(num_threads) {
            jacpacks.append(_create_dummy_jacpack("submit_" + str(i)));
        }

        threads: list = [];
        for i in range(num_threads) {
            t = Thread(
                target=submit_community_template,
                args=("user_" + str(i), "User " + str(i), "App " + str(i), "desc", ["test"], jacpacks[i])
            );
            threads.append(t);
        }

        for t in threads {
            t.start();
        }
        for t in threads {
            t.join();
        }

        items = get_community_manifest();
        assert len(items) == num_threads,
            "Expected " + str(num_threads) + " entries but got " + str(len(items)) + " — concurrent submits lost data!";

        for jp in jacpacks {
            if os.path.exists(jp) {
                os.remove(jp);
            }
        }
    } finally {
        _restore_manifest();
    }
}

test "concurrent clone count increments are all counted" {
    _backup_manifest();
    try {
        seed_item: dict = {
            "id": "comm_lock_test_clone",
            "user_id": "owner",
            "display_name": "owner",
            "name": "Clone Test",
            "description": "",
            "tags": [],
            "filename": "nonexistent.jacpack",
            "clone_count": 0,
            "created_at": "2025-01-01Z",
            "is_active": True
        };
        save_community_manifest([seed_item]);

        num_threads = 50;
        threads: list = [];
        for i in range(num_threads) {
            t = Thread(
                target=increment_clone_count,
                args=("comm_lock_test_clone",)
            );
            threads.append(t);
        }

        for t in threads {
            t.start();
        }
        for t in threads {
            t.join();
        }

        items = get_community_manifest();
        assert len(items) == 1, "Manifest should still have 1 item";
        final_count = items[0].get("clone_count", 0);
        assert final_count == num_threads,
            "Expected clone_count=" + str(num_threads) + " but got " + str(final_count) + " — increments lost!";
    } finally {
        _restore_manifest();
    }
}

test "concurrent removes do not corrupt manifest" {
    _backup_manifest();
    try {
        num_items = 20;
        seed_items: list = [];
        for i in range(num_items) {
            seed_items.append({
                "id": "comm_remove_test_" + str(i),
                "user_id": "owner",
                "display_name": "owner",
                "name": "Item " + str(i),
                "description": "",
                "tags": [],
                "filename": "nonexistent_" + str(i) + ".jacpack",
                "clone_count": 0,
                "created_at": "2025-01-01Z",
                "is_active": True
            });
        }
        save_community_manifest(seed_items);

        ids_to_remove: list = [];
        for i in range(10) {
            ids_to_remove.append("comm_remove_test_" + str(i));
        }

        threads: list = [];
        for rid in ids_to_remove {
            t = Thread(
                target=remove_community_template,
                args=(rid, "owner")
            );
            threads.append(t);
        }

        for t in threads {
            t.start();
        }
        for t in threads {
            t.join();
        }

        items_after = get_community_manifest();
        assert len(items_after) == 10,
            "Expected 10 remaining items but got " + str(len(items_after));

        remaining_ids: list = [];
        for item in items_after {
            remaining_ids.append(item["id"]);
        }
        for rid in ids_to_remove {
            assert rid not in remaining_ids, "Removed item " + rid + " should not be in manifest";
        }

        mp = _manifest_path();
        with open(mp, "r") as f {
            data = json.load(f);
        }
        assert isinstance(data, list), "Manifest JSON is corrupted — not a list";
    } finally {
        _restore_manifest();
    }
}
