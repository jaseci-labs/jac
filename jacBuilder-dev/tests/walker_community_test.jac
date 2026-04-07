"""Tests for community_ops and community_submit walkers.

NOTE: result.reports not accessible in direct spawn tests.
Tests verify side effects on the community manifest (filesystem state) and graph.
"""

import os;
import shutil;
import tempfile;
import base64;
import from services.ideServer { community_ops, community_submit, me, UserProfile }
import from services.community_manager { get_community_manifest, get_community_template, remove_community_template }

test "community_ops list does not modify community manifest" {
    manifest_before = get_community_manifest();
    count_before = len(manifest_before);
    root spawn community_ops(action="list");
    count_after = len(get_community_manifest());
    assert count_after == count_before;
}

test "community_ops list with search does not create graph nodes" {
    count_before = len([root -->(?:UserProfile)]);
    root spawn community_ops(action="list", search="___no_match_xyz___");
    count_after = len([root -->(?:UserProfile)]);
    assert count_after == count_before;
}

test "community_ops get for nonexistent id does not modify manifest" {
    count_before = len(get_community_manifest());
    root spawn community_ops(action="get", comm_id="comm_nonexistent_xyz_9999");
    count_after = len(get_community_manifest());
    assert count_after == count_before;
}

test "community_submit does not add profile when not authenticated" {
    count_before = len([root -->(?:UserProfile)]);
    manifest_before = len(get_community_manifest());
    root spawn community_submit(action="submit", name="App", jacpack_content_base64="dGVzdA==");
    count_after = len([root -->(?:UserProfile)]);
    assert count_after == count_before;
    manifest_after = get_community_manifest();
    if len(manifest_after) > manifest_before {
        for item in manifest_after {
            if item.get("name", "") == "App" and item.get("display_name", "") == "ProjTester" {
                remove_community_template(item["id"], item.get("user_id", ""));
                break;
            }
        }
    }
}

test "community_submit with valid base64 jacpack adds entry to community manifest" {
    comm_id = "";
    try {
        fake_bytes = b"PK\x03\x04fake jacpack bytes for walker test";
        encoded = base64.b64encode(fake_bytes).decode("ascii");
        root spawn me(display_name_hint="CommTester");
        profile = [root -->(?:UserProfile)][0];
        count_before = len(get_community_manifest());
        root spawn community_submit(
            action="submit",
            name="Walker Community Test App",
            description="Test submission via walker",
            tags=["test", "walker"],
            jacpack_content_base64=encoded
        );
        manifest_after = get_community_manifest();
        count_after = len(manifest_after);
        assert count_after == count_before + 1;
        found = None;
        for item in manifest_after {
            if item.get("name", "") == "Walker Community Test App" {
                found = item;
            }
        }
        assert found is not None;
        comm_id = found["id"];
        assert isinstance(found["display_name"], str);
        assert len(found["display_name"]) > 0;
        assert "test" in found["tags"];
        assert found["clone_count"] == 0;
    } finally {
        if comm_id {
            remove_community_template(comm_id, profile.user_id);
        }
    }
}

test "community_submit remove with wrong user does not delete entry" {
    comm_id = "";
    original_user_id = "";
    profile = None;
    try {
        fake_bytes = b"PK\x03\x04fake jacpack to remove test";
        encoded = base64.b64encode(fake_bytes).decode("ascii");
        profile = [root -->(?:UserProfile)][0];
        original_user_id = profile.user_id;
        root spawn community_submit(
            action="submit",
            name="To Be Kept",
            description="Should not be removed",
            tags=[],
            jacpack_content_base64=encoded
        );
        manifest = get_community_manifest();
        for item in manifest {
            if item.get("name", "") == "To Be Kept" {
                comm_id = item["id"];
            }
        }
        assert comm_id != "";
        profile.user_id = "wrong-user-id-999";
        root spawn community_submit(action="remove", comm_id=comm_id);
        still_there = get_community_template(comm_id);
        assert still_there["success"] == True;
    } finally {
        if profile and original_user_id {
            profile.user_id = original_user_id;
        }
        if comm_id {
            for item in get_community_manifest() {
                if item.get("id", "") == comm_id {
                    remove_community_template(comm_id, item.get("user_id", ""));
                }
            }
        }
    }
}

test "community_submit unknown action does not add nodes or manifest entries" {
    profile = [root -->(?:UserProfile)][0];
    count_before = len(get_community_manifest());
    node_count_before = len([root -->(?:UserProfile)]);
    root spawn community_submit(action="invalid_action_xyz");
    assert len(get_community_manifest()) == count_before;
    assert len([root -->(?:UserProfile)]) == node_count_before;
}
