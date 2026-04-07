"""Tests for worktree operations (git_service) and thread CRUD helpers (ideServer)."""

import os;
import shutil;
import tempfile;
import subprocess;
import from services.git_service {
    git_create_worktree,
    git_remove_worktree,
    git_list_worktrees,
    git_branches,
    git_create_branch
}


def _make_repo() -> str {
    tmp = tempfile.mkdtemp();
    subprocess.run(["git", "init"], cwd=tmp, capture_output=True);
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp, capture_output=True);
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp, capture_output=True);
    subprocess.run(["git", "checkout", "-B", "main"], cwd=tmp, capture_output=True);
    return tmp;
}


def _commit(repo: str, filename: str = "file.txt", content: str = "hello\n", msg: str = "init") -> None {
    with open(os.path.join(repo, filename), "w") as f {
        f.write(content);
    }
    subprocess.run(["git", "add", "-A"], cwd=repo, capture_output=True);
    subprocess.run(["git", "commit", "-m", msg], cwd=repo, capture_output=True);
}


# ===========================================================================
# git_create_worktree
# ===========================================================================

test "create_worktree succeeds with valid repo and branch" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_create_worktree(repo, "main", "test-wt-branch-1");
        assert result.get("success") == True,
            "Expected success but got: " + str(result);
        assert result.get("worktree_path", "") != "",
            "Expected worktree_path in result";
        assert result.get("branch", "") == "test-wt-branch-1",
            "Expected branch name test-wt-branch-1";
        # Verify the worktree directory exists
        wt_path = result.get("worktree_path", "");
        assert os.path.isdir(wt_path),
            "Worktree directory should exist: " + wt_path;
        # Verify it has the repo contents
        assert os.path.isfile(os.path.join(wt_path, "file.txt")),
            "Worktree should contain file.txt from main branch";
    } finally {
        # Clean up worktree first, then repo
        if result.get("worktree_path") {
            git_remove_worktree(repo, result["worktree_path"], force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


test "create_worktree fails with nonexistent base branch" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_create_worktree(repo, "nonexistent-branch", "test-wt-bad-base");
        assert result.get("success") == False,
            "Expected failure for nonexistent base branch";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


test "create_worktree fails with empty repo (no commits)" {
    repo = _make_repo();
    try {
        result = git_create_worktree(repo, "main", "test-wt-empty");
        assert result.get("success") == False,
            "Expected failure for repo with no commits";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_remove_worktree
# ===========================================================================

test "remove_worktree cleans up created worktree" {
    repo = _make_repo();
    wt_path = "";
    try {
        _commit(repo);
        create_result = git_create_worktree(repo, "main", "test-wt-remove-1");
        assert create_result.get("success") == True;
        wt_path = create_result.get("worktree_path", "");
        assert os.path.isdir(wt_path);

        # Now remove it
        remove_result = git_remove_worktree(repo, wt_path, force=True);
        assert remove_result.get("success") == True,
            "Expected successful removal but got: " + str(remove_result);
        # Directory should be gone
        assert not os.path.isdir(wt_path),
            "Worktree directory should not exist after removal";
    } finally {
        if wt_path and os.path.isdir(wt_path) {
            git_remove_worktree(repo, wt_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


test "remove_worktree with empty path returns error" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_remove_worktree(repo, "", force=True);
        assert result.get("success") == False,
            "Expected failure for empty worktree path";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_list_worktrees
# ===========================================================================

test "list_worktrees shows main worktree for fresh repo" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_list_worktrees(repo);
        assert result.get("success") == True;
        wts = result.get("worktrees", []);
        assert len(wts) >= 1,
            "Should have at least the main worktree";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


test "list_worktrees shows created worktree" {
    repo = _make_repo();
    wt_path = "";
    try {
        _commit(repo);
        create_result = git_create_worktree(repo, "main", "test-wt-list-1");
        assert create_result.get("success") == True;
        wt_path = create_result.get("worktree_path", "");

        result = git_list_worktrees(repo);
        assert result.get("success") == True;
        wts = result.get("worktrees", []);
        assert len(wts) >= 2,
            "Should have main + created worktree, got " + str(len(wts));

        # Find our worktree in the list
        found = False;
        for wt in wts {
            if wt.get("branch", "") == "test-wt-list-1" {
                found = True;
                break;
            }
        }
        assert found, "Created worktree branch not found in list";
    } finally {
        if wt_path and os.path.isdir(wt_path) {
            git_remove_worktree(repo, wt_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


test "list_worktrees after removal excludes removed worktree" {
    repo = _make_repo();
    wt_path = "";
    try {
        _commit(repo);
        create_result = git_create_worktree(repo, "main", "test-wt-list-rm");
        assert create_result.get("success") == True;
        wt_path = create_result.get("worktree_path", "");

        git_remove_worktree(repo, wt_path, force=True);
        wt_path = "";

        result = git_list_worktrees(repo);
        assert result.get("success") == True;
        wts = result.get("worktrees", []);
        for wt in wts {
            assert wt.get("branch", "") != "test-wt-list-rm",
                "Removed worktree should not appear in list";
        }
    } finally {
        if wt_path and os.path.isdir(wt_path) {
            git_remove_worktree(repo, wt_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# Worktree isolation — changes in worktree don't affect main
# ===========================================================================

test "worktree is isolated from main repo" {
    repo = _make_repo();
    wt_path = "";
    try {
        _commit(repo);
        create_result = git_create_worktree(repo, "main", "test-wt-isolation");
        assert create_result.get("success") == True;
        wt_path = create_result.get("worktree_path", "");

        # Create a new file in the worktree
        with open(os.path.join(wt_path, "worktree_only.txt"), "w") as f {
            f.write("this file only exists in worktree");
        }

        # Main repo should NOT have this file
        assert not os.path.isfile(os.path.join(repo, "worktree_only.txt")),
            "File created in worktree should not appear in main repo";

        # Main repo should still have original file
        assert os.path.isfile(os.path.join(repo, "file.txt")),
            "Main repo should still have its original files";
    } finally {
        if wt_path and os.path.isdir(wt_path) {
            git_remove_worktree(repo, wt_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# Multiple worktrees from same repo
# ===========================================================================

test "multiple worktrees can coexist" {
    repo = _make_repo();
    wt1_path = "";
    wt2_path = "";
    try {
        _commit(repo);
        r1 = git_create_worktree(repo, "main", "test-wt-multi-1");
        assert r1.get("success") == True;
        wt1_path = r1.get("worktree_path", "");

        r2 = git_create_worktree(repo, "main", "test-wt-multi-2");
        assert r2.get("success") == True;
        wt2_path = r2.get("worktree_path", "");

        assert wt1_path != wt2_path,
            "Two worktrees should have different paths";

        result = git_list_worktrees(repo);
        wts = result.get("worktrees", []);
        branch_names: list = [];
        for wt in wts {
            branch_names.append(wt.get("branch", ""));
        }
        assert "test-wt-multi-1" in branch_names,
            "First worktree branch should be in list";
        assert "test-wt-multi-2" in branch_names,
            "Second worktree branch should be in list";
    } finally {
        if wt1_path and os.path.isdir(wt1_path) {
            git_remove_worktree(repo, wt1_path, force=True);
        }
        if wt2_path and os.path.isdir(wt2_path) {
            git_remove_worktree(repo, wt2_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# Worktree with branch from different base
# ===========================================================================

test "worktree from feature branch has correct content" {
    repo = _make_repo();
    wt_path = "";
    try {
        _commit(repo, "main_file.txt", "main content", "main commit");
        git_create_branch(repo, "feature");
        _commit(repo, "feature_file.txt", "feature content", "feature commit");

        result = git_create_worktree(repo, "feature", "test-wt-from-feature");
        assert result.get("success") == True;
        wt_path = result.get("worktree_path", "");

        # Worktree should have both main and feature files
        assert os.path.isfile(os.path.join(wt_path, "main_file.txt")),
            "Worktree from feature should have main_file.txt";
        assert os.path.isfile(os.path.join(wt_path, "feature_file.txt")),
            "Worktree from feature should have feature_file.txt";
    } finally {
        if wt_path and os.path.isdir(wt_path) {
            git_remove_worktree(repo, wt_path, force=True);
        }
        shutil.rmtree(repo, ignore_errors=True);
    }
}
