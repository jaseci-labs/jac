"""Tests for single-directory architecture — verify no /tmp copy, cleanup safety."""

import os;
import time;
import tempfile;
import shutil;

import from services.preview_manager {
    setup_preview,
    cleanup_preview,
    _staging_dirs,
    _preview_key,
    get_preview_dir
}


test "test_setup_preview_uses_source_dir_directly" {
    user_id = "test_sd_" + str(int(time.time() * 1000));
    project_id = "proj_sd_setup";
    source_dir = tempfile.mkdtemp();

    try {
        # Create a test file in source dir
        with open(os.path.join(source_dir, "main.jac"), "w") as f {
            f.write("with entry { print(42); }");
        }

        result = setup_preview(user_id, project_id, source_dir);
        assert result["success"] == True, "setup should succeed";
        assert result["dir"] == source_dir, "staging dir should BE the source dir, got: " + str(result["dir"]);

        # Verify _staging_dirs points to source, not /tmp
        key = _preview_key(user_id, project_id);
        staging = _staging_dirs.get(key, "");
        assert staging == source_dir, "staging should be source dir, got: " + staging;
        assert not staging.startswith("/tmp/jac-preview"), "should NOT be a /tmp copy";

        cleanup_preview(user_id, project_id);
    } finally {
        shutil.rmtree(source_dir, ignore_errors=True);
    }
}

test "test_cleanup_does_not_delete_source_dir" {
    user_id = "test_sd_" + str(int(time.time() * 1000));
    project_id = "proj_sd_clean";
    source_dir = tempfile.mkdtemp();

    try {
        with open(os.path.join(source_dir, "main.jac"), "w") as f {
            f.write("# test");
        }

        setup_preview(user_id, project_id, source_dir);
        cleanup_preview(user_id, project_id);

        # Source dir should still exist (not deleted)
        assert os.path.isdir(source_dir), "source dir should NOT be deleted by cleanup";
        assert os.path.isfile(os.path.join(source_dir, "main.jac")), "files should still be there";
    } finally {
        shutil.rmtree(source_dir, ignore_errors=True);
    }
}

test "test_get_preview_dir_returns_source_dir" {
    user_id = "test_sd_" + str(int(time.time() * 1000));
    project_id = "proj_sd_getdir";
    source_dir = tempfile.mkdtemp();

    try {
        setup_preview(user_id, project_id, source_dir);

        preview_dir = get_preview_dir(user_id, project_id);
        assert preview_dir == source_dir, "get_preview_dir should return source dir, got: " + str(preview_dir);

        cleanup_preview(user_id, project_id);
    } finally {
        shutil.rmtree(source_dir, ignore_errors=True);
    }
}

test "test_no_tmp_copy_created" {
    user_id = "test_sd_notmp_" + str(int(time.time() * 1000));
    project_id = "proj_sd_notmp";
    source_dir = tempfile.mkdtemp();

    try {
        setup_preview(user_id, project_id, source_dir);

        # Check that no /tmp/jac-preview-* dir was created for this project
        tmp_pattern = "/tmp/jac-preview-" + user_id + "-" + project_id;
        assert not os.path.exists(tmp_pattern), "should NOT create /tmp copy: " + tmp_pattern;

        cleanup_preview(user_id, project_id);
    } finally {
        shutil.rmtree(source_dir, ignore_errors=True);
    }
}

test "test_setup_idempotent" {
    user_id = "test_sd_" + str(int(time.time() * 1000));
    project_id = "proj_sd_idemp";
    source_dir = tempfile.mkdtemp();

    try {
        r1 = setup_preview(user_id, project_id, source_dir);
        assert r1["success"] == True;

        r2 = setup_preview(user_id, project_id, source_dir);
        assert r2["success"] == True;
        assert r2["dir"] == source_dir;

        cleanup_preview(user_id, project_id);
    } finally {
        shutil.rmtree(source_dir, ignore_errors=True);
    }
}
