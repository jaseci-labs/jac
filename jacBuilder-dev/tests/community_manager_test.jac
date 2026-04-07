"""Tests for community_manager service functions."""

import os;
import shutil;
import tempfile;
import from services.community_manager {
    get_community_manifest,
    list_community_templates,
    get_community_template,
    get_community_jacpack_path,
    submit_community_template,
    increment_clone_count,
    remove_community_template
}

test "get_community_manifest returns a list" {
    result = get_community_manifest();
    assert isinstance(result, list);
}

test "list_community_templates returns a list" {
    result = list_community_templates();
    assert isinstance(result, list);
}

test "list_community_templates with search returns subset" {
    result = list_community_templates(search="___nonexistent_xyz_query___");
    assert result == [];
}

test "list_community_templates with tag filter returns subset" {
    result = list_community_templates(tag="___nonexistent_tag_xyz___");
    assert result == [];
}

test "get_community_template returns error for empty comm_id" {
    result = get_community_template("");
    assert result["success"] == False;
    assert "comm_id" in result["error"].lower();
}

test "get_community_template returns error for nonexistent id" {
    result = get_community_template("comm_nonexistent_999999");
    assert result["success"] == False;
    assert "not found" in result["error"].lower();
}

test "get_community_jacpack_path returns empty string for nonexistent id" {
    path = get_community_jacpack_path("comm_nonexistent_xyz");
    assert path == "";
}

test "submit_community_template returns error for missing jacpack file" {
    result = submit_community_template(
        "user1", "Alice", "Test Template",
        "A test", ["test"],
        "/nonexistent/path/fake.jacpack"
    );
    assert result["success"] == False;
    assert "not found" in result["error"].lower() or "jacpack" in result["error"].lower();
}

test "submit_community_template returns error for empty name" {
    tmp_dir = tempfile.mkdtemp();
    try {
        fake_pack = os.path.join(tmp_dir, "test.jacpack");
        with open(fake_pack, "w") as f {
            f.write("fake jacpack content");
        }
        result = submit_community_template("user1", "Alice", "", "desc", [], fake_pack);
        assert result["success"] == False;
        assert "name" in result["error"].lower();
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "submit_community_template creates entry and get retrieves it" {
    tmp_dir = tempfile.mkdtemp();
    comm_id = "";
    try {
        fake_pack = os.path.join(tmp_dir, "test.jacpack");
        with open(fake_pack, "wb") as f {
            f.write(b"PK\x03\x04fake jacpack data");
        }
        result = submit_community_template(
            "test-user-submit", "Test Author",
            "Test Submit Template", "A test template for unit tests",
            ["test", "unit"],
            fake_pack
        );
        assert result["success"] == True;
        item = result["item"];
        comm_id = item["id"];
        assert item["name"] == "Test Submit Template";
        assert item["display_name"] == "Test Author";
        assert item["user_id"] == "test-user-submit";
        assert "test" in item["tags"];
        assert item["clone_count"] == 0;
        assert item["is_active"] == True;
        assert comm_id.startswith("comm_");
        get_result = get_community_template(comm_id);
        assert get_result["success"] == True;
        assert get_result["item"]["id"] == comm_id;
    } finally {
        if comm_id {
            remove_community_template(comm_id, "test-user-submit");
        }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "increment_clone_count increases count by 1" {
    tmp_dir = tempfile.mkdtemp();
    comm_id = "";
    try {
        fake_pack = os.path.join(tmp_dir, "inc_test.jacpack");
        with open(fake_pack, "wb") as f {
            f.write(b"fake content");
        }
        submit_result = submit_community_template(
            "user-incr", "Incr Author", "Incr Test", "desc", [], fake_pack
        );
        comm_id = submit_result["item"]["id"];
        increment_clone_count(comm_id);
        item_result = get_community_template(comm_id);
        assert item_result["item"]["clone_count"] == 1;
        increment_clone_count(comm_id);
        item_result2 = get_community_template(comm_id);
        assert item_result2["item"]["clone_count"] == 2;
    } finally {
        if comm_id {
            remove_community_template(comm_id, "user-incr");
        }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "remove_community_template requires owner match" {
    tmp_dir = tempfile.mkdtemp();
    comm_id = "";
    try {
        fake_pack = os.path.join(tmp_dir, "rm_test.jacpack");
        with open(fake_pack, "wb") as f {
            f.write(b"fake content");
        }
        submit_result = submit_community_template(
            "real-owner", "Owner", "Remove Test", "desc", [], fake_pack
        );
        comm_id = submit_result["item"]["id"];
        removed_wrong = remove_community_template(comm_id, "wrong-user");
        assert removed_wrong == False;
        still_there = get_community_template(comm_id);
        assert still_there["success"] == True;
    } finally {
        if comm_id {
            remove_community_template(comm_id, "real-owner");
        }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "remove_community_template deletes item for correct owner" {
    tmp_dir = tempfile.mkdtemp();
    try {
        fake_pack = os.path.join(tmp_dir, "del_test.jacpack");
        with open(fake_pack, "wb") as f {
            f.write(b"fake content");
        }
        submit_result = submit_community_template(
            "owner-del", "Owner", "Delete Test", "desc", [], fake_pack
        );
        comm_id = submit_result["item"]["id"];
        removed = remove_community_template(comm_id, "owner-del");
        assert removed == True;
        not_found = get_community_template(comm_id);
        assert not_found["success"] == False;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "remove_community_template returns False for nonexistent id" {
    result = remove_community_template("comm_nonexistent_xyz_999", "any-user");
    assert result == False;
}

test "list_community_templates search is case-insensitive" {
    tmp_dir = tempfile.mkdtemp();
    comm_id = "";
    try {
        fake_pack = os.path.join(tmp_dir, "search_test.jacpack");
        with open(fake_pack, "wb") as f {
            f.write(b"fake content");
        }
        submit_result = submit_community_template(
            "search-user", "Search Author", "MyUniqueSearchableApp", "cool app", [], fake_pack
        );
        comm_id = submit_result["item"]["id"];
        upper_results = list_community_templates(search="MYUNIQUESEARCHABLEAPP");
        lower_results = list_community_templates(search="myuniquesearchableapp");
        assert len(upper_results) >= 1;
        assert len(lower_results) >= 1;
    } finally {
        if comm_id {
            remove_community_template(comm_id, "search-user");
        }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}
