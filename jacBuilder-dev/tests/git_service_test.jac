"""Tests for services/git_service.jac — the new git operations module."""

import os;
import shutil;
import tempfile;
import subprocess;
import from services.git_service {
    is_git_repo,
    git_status,
    git_branches,
    git_create_branch,
    git_checkout,
    git_diff,
    git_diff_working,
    git_diff_staged,
    git_diff_last_commit,
    git_commit,
    git_stage_file,
    git_unstage_file,
    git_commit_staged,
    git_push,
    git_pull,
    git_log,
    git_remote_add,
    git_remote_remove,
    git_remotes,
    git_create_checkpoint,
    git_restore_checkpoint,
    git_checkpoint_diff,
    git_delete_branch,
    git_revert_to_commit,
    git_merge
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
# is_git_repo
# ===========================================================================

test "is_git_repo returns true for valid repo" {
    repo = _make_repo();
    try {
        assert is_git_repo(repo) == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "is_git_repo returns false for plain directory" {
    tmp = tempfile.mkdtemp();
    try {
        assert is_git_repo(tmp) == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===========================================================================
# git_status
# ===========================================================================

test "git_status returns success with branch and clean state" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_status(repo);
        assert result["success"] == True;
        assert result["is_repo"] == True;
        assert result["branch"] == "main";
        assert result["dirty"] == False;
        assert result["files"] == [];
        assert result["has_remote"] == False;
        assert result["last_commit"] is not None;
        assert len(result["last_commit"]["sha"]) == 40;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_status reports dirty files" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "new.txt"), "w") as f {
            f.write("change\n");
        }
        result = git_status(repo);
        assert result["success"] == True;
        assert result["dirty"] == True;
        assert len(result["files"]) > 0;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_status returns error for non-repo" {
    tmp = tempfile.mkdtemp();
    try {
        result = git_status(tmp);
        assert result["success"] == False;
        assert result["is_repo"] == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===========================================================================
# git_branches
# ===========================================================================

test "git_branches lists branches with current marker" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_branches(repo);
        assert result["success"] == True;
        assert result["current"] == "main";
        assert len(result["branches"]) >= 1;
        found = False;
        for b in result["branches"] {
            if b["name"] == "main" and b["current"] == True {
                found = True;
            }
        }
        assert found;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_create_branch / git_checkout
# ===========================================================================

test "git_create_branch creates and checks out new branch" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_create_branch(repo, "feature-x");
        assert result["success"] == True;
        branches = git_branches(repo);
        assert branches["current"] == "feature-x";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_checkout switches to existing branch" {
    repo = _make_repo();
    try {
        _commit(repo);
        git_create_branch(repo, "dev");
        git_checkout(repo, "main");
        branches = git_branches(repo);
        assert branches["current"] == "main";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_diff / git_diff_working / git_diff_staged
# ===========================================================================

test "git_diff_working returns empty for clean repo" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_diff_working(repo);
        assert result["success"] == True;
        assert result["diff_text"] == "";
        assert result["files"] == [];
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_diff_working returns changes for modified file" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "file.txt"), "w") as f {
            f.write("changed\n");
        }
        result = git_diff_working(repo);
        assert result["success"] == True;
        assert len(result["diff_text"]) > 0;
        assert len(result["files"]) == 1;
        assert result["files"][0]["path"] == "file.txt";
        assert "additions" in result["files"][0];
        assert "deletions" in result["files"][0];
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_diff_staged returns staged changes with numstat" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "staged.txt"), "w") as f {
            f.write("staged content\n");
        }
        subprocess.run(["git", "add", "staged.txt"], cwd=repo, capture_output=True);
        result = git_diff_staged(repo);
        assert result["success"] == True;
        assert len(result["diff_text"]) > 0;
        assert len(result["files"]) == 1;
        assert result["files"][0]["path"] == "staged.txt";
        assert result["files"][0]["additions"] > 0;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_diff_staged returns empty when nothing staged" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_diff_staged(repo);
        assert result["success"] == True;
        assert result["diff_text"] == "";
        assert result["files"] == [];
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_diff between two refs shows changes" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "first\n", "first commit");
        sha1_res = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True);
        sha1 = sha1_res.stdout.strip();
        _commit(repo, "b.txt", "second\n", "second commit");
        result = git_diff(repo, sha1, "HEAD");
        assert result["success"] == True;
        assert len(result["files"]) >= 1;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_commit
# ===========================================================================

test "git_commit stages and commits all changes" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "new.txt"), "w") as f {
            f.write("new file\n");
        }
        result = git_commit(repo, "add new file");
        assert result["success"] == True;
        assert len(result["sha"]) == 40;
        assert result["message"] == "add new file";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_commit returns error when nothing to commit" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_commit(repo, "empty commit");
        assert result["success"] == False;
        assert "Nothing to commit" in result.get("error", "");
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_commit requires message" {
    repo = _make_repo();
    try {
        result = git_commit(repo, "");
        assert result["success"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_log
# ===========================================================================

test "git_log returns commit history" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "a\n", "first");
        _commit(repo, "b.txt", "b\n", "second");
        result = git_log(repo, 10);
        assert result["success"] == True;
        assert len(result["commits"]) == 2;
        assert result["commits"][0]["message"] == "second";
        assert result["commits"][1]["message"] == "first";
        assert len(result["commits"][0]["sha"]) == 40;
        assert "author" in result["commits"][0];
        assert "date" in result["commits"][0];
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_remotes
# ===========================================================================

test "git_remote_add adds origin and git_remotes lists it" {
    repo = _make_repo();
    try {
        _commit(repo);
        add_result = git_remote_add(repo, "https://github.com/test/repo.git");
        assert add_result["success"] == True;
        list_result = git_remotes(repo);
        assert list_result["success"] == True;
        assert len(list_result["remotes"]) >= 1;
        found = False;
        for r in list_result["remotes"] {
            if r["name"] == "origin" { found = True; }
        }
        assert found;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_remote_add updates existing remote url" {
    repo = _make_repo();
    try {
        _commit(repo);
        git_remote_add(repo, "https://old-url.com/repo.git");
        git_remote_add(repo, "https://new-url.com/repo.git");
        list_result = git_remotes(repo);
        found_new = False;
        for r in list_result["remotes"] {
            if "new-url" in r["url"] { found_new = True; }
        }
        assert found_new;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_remote_remove removes a remote" {
    repo = _make_repo();
    try {
        _commit(repo);
        git_remote_add(repo, "https://example.com/repo.git");
        rm_result = git_remote_remove(repo);
        assert rm_result["success"] == True;
        list_result = git_remotes(repo);
        assert len(list_result["remotes"]) == 0;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# Checkpoints
# ===========================================================================

test "git_create_checkpoint returns ref for clean repo" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_create_checkpoint(repo);
        assert result["success"] == True;
        assert len(result["checkpoint_ref"]) == 40;
        assert result["stash_ref"] == "";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_diff_last_commit shows changes from previous commit" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "first\n", "first commit");
        _commit(repo, "b.txt", "second\n", "second commit");
        result = git_diff_last_commit(repo);
        assert result["success"] == True;
        assert len(result["files"]) >= 1;
        assert result["files"][0]["path"] == "b.txt";
        assert len(result["diff_text"]) > 0;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_status includes last_commit_files for clean repo" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "content\n", "initial");
        _commit(repo, "b.txt", "more\n", "add b");
        result = git_status(repo);
        assert result["success"] == True;
        assert result["dirty"] == False;
        assert len(result["last_commit_files"]) >= 1;
        found_b = False;
        for f in result["last_commit_files"] {
            if f["path"] == "b.txt" { found_b = True; }
        }
        assert found_b;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_create_checkpoint stashes uncommitted changes" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "dirty.txt"), "w") as f {
            f.write("uncommitted\n");
        }
        result = git_create_checkpoint(repo);
        assert result["success"] == True;
        assert len(result["stash_ref"]) > 0;
        # Working tree should be clean after stash
        status = git_status(repo);
        assert status["dirty"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# Selective staging: git_stage_file / git_unstage_file
# ===========================================================================

test "git_stage_file stages a single file" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "a.txt"), "w") as f {
            f.write("aaa\n");
        }
        with open(os.path.join(repo, "b.txt"), "w") as f {
            f.write("bbb\n");
        }
        result = git_stage_file(repo, "a.txt");
        assert result["success"] == True;
        # Check that a.txt is staged but b.txt is not
        status = git_status(repo);
        a_staged = False;
        b_staged = False;
        for f in status["files"] {
            if f["path"] == "a.txt" and f["staged"] { a_staged = True; }
            if f["path"] == "b.txt" and f["staged"] { b_staged = True; }
        }
        assert a_staged == True;
        assert b_staged == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_unstage_file removes a file from staging" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "a.txt"), "w") as f {
            f.write("aaa\n");
        }
        subprocess.run(["git", "add", "a.txt"], cwd=repo, capture_output=True);
        # Verify it's staged
        status_before = git_status(repo);
        staged_before = False;
        for f in status_before["files"] {
            if f["path"] == "a.txt" and f["staged"] { staged_before = True; }
        }
        assert staged_before == True;
        # Unstage
        result = git_unstage_file(repo, "a.txt");
        assert result["success"] == True;
        # Verify it's no longer staged
        status_after = git_status(repo);
        staged_after = False;
        for f in status_after["files"] {
            if f["path"] == "a.txt" and f["staged"] { staged_after = True; }
        }
        assert staged_after == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_stage_file requires file_path" {
    repo = _make_repo();
    try {
        result = git_stage_file(repo, "");
        assert result["success"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_commit_staged
# ===========================================================================

test "git_commit_staged commits only staged files" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "staged.txt"), "w") as f {
            f.write("staged content\n");
        }
        with open(os.path.join(repo, "unstaged.txt"), "w") as f {
            f.write("unstaged content\n");
        }
        # Stage only staged.txt
        git_stage_file(repo, "staged.txt");
        result = git_commit_staged(repo, "commit staged only");
        assert result["success"] == True;
        assert len(result["sha"]) == 40;
        # unstaged.txt should still be dirty
        status = git_status(repo);
        assert status["dirty"] == True;
        found_unstaged = False;
        for f in status["files"] {
            if f["path"] == "unstaged.txt" { found_unstaged = True; }
        }
        assert found_unstaged == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_commit_staged fails when nothing staged" {
    repo = _make_repo();
    try {
        _commit(repo);
        with open(os.path.join(repo, "file.txt"), "w") as f {
            f.write("modified\n");
        }
        # Don't stage anything
        result = git_commit_staged(repo, "should fail");
        assert result["success"] == False;
        assert "Nothing staged" in result.get("error", "");
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_delete_branch
# ===========================================================================

test "git_delete_branch deletes a non-current branch" {
    repo = _make_repo();
    try {
        _commit(repo);
        git_create_branch(repo, "feature");
        git_checkout(repo, "main");
        result = git_delete_branch(repo, "feature");
        assert result["success"] == True;
        branches = git_branches(repo);
        found = False;
        for b in branches["branches"] {
            if b["name"] == "feature" { found = True; }
        }
        assert found == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_delete_branch requires branch name" {
    repo = _make_repo();
    try {
        result = git_delete_branch(repo, "");
        assert result["success"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_status enhanced: staged/unstaged fields
# ===========================================================================

test "git_status includes staged and unstaged fields" {
    repo = _make_repo();
    try {
        _commit(repo);
        # Create a file, stage it
        with open(os.path.join(repo, "new.txt"), "w") as f {
            f.write("new\n");
        }
        subprocess.run(["git", "add", "new.txt"], cwd=repo, capture_output=True);
        # Create another file, don't stage
        with open(os.path.join(repo, "other.txt"), "w") as f {
            f.write("other\n");
        }
        status = git_status(repo);
        assert status["success"] == True;
        new_file = None;
        other_file = None;
        for f in status["files"] {
            if f["path"] == "new.txt" { new_file = f; }
            if f["path"] == "other.txt" { other_file = f; }
        }
        assert new_file is not None;
        assert new_file["staged"] == True;
        assert other_file is not None;
        assert other_file["unstaged"] == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_revert_to_commit
# ===========================================================================

test "git_revert_to_commit reverts to earlier commit and stays on branch" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "original\n", "first commit");
        sha1_res = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True);
        sha1 = sha1_res.stdout.strip();
        _commit(repo, "a.txt", "modified\n", "second commit");
        _commit(repo, "b.txt", "new file\n", "third commit");
        # Revert to first commit
        result = git_revert_to_commit(repo, sha1);
        assert result["success"] == True;
        assert len(result.get("commit_sha", "")) == 40;
        # Should still be on main branch (not detached HEAD)
        branch = git_branches(repo);
        assert branch["current"] == "main";
        # a.txt should have original content
        with open(os.path.join(repo, "a.txt"), "r") as f {
            content = f.read();
        }
        assert content == "original\n";
        # b.txt should not exist (reverted to state before it was created)
        assert not os.path.exists(os.path.join(repo, "b.txt"));
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_revert_to_commit returns no_changes when already at target" {
    repo = _make_repo();
    try {
        _commit(repo, "a.txt", "content\n", "first commit");
        sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True).stdout.strip();
        result = git_revert_to_commit(repo, sha);
        assert result["success"] == True;
        assert result.get("no_changes") == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_revert_to_commit validates SHA format" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_revert_to_commit(repo, "not-a-valid-sha!");
        assert result["success"] == False;
        assert "Invalid SHA" in result.get("error", "");
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_revert_to_commit fails for nonexistent ref" {
    repo = _make_repo();
    try {
        _commit(repo);
        result = git_revert_to_commit(repo, "0000000000000000000000000000000000000000");
        assert result["success"] == False;
        assert "not found" in result.get("error", "");
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}


# ===========================================================================
# git_merge
# ===========================================================================

test "git_merge merges branch into current" {
    repo = _make_repo();
    try {
        _commit(repo, "base.txt", "base\n", "initial");
        git_create_branch(repo, "feature");
        _commit(repo, "feature.txt", "feature work\n", "feature commit");
        git_checkout(repo, "main");
        result = git_merge(repo, "feature");
        assert result["success"] == True;
        assert os.path.exists(os.path.join(repo, "feature.txt"));
        with open(os.path.join(repo, "feature.txt"), "r") as f {
            content = f.read();
        }
        assert content == "feature work\n";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_merge detects conflict and aborts" {
    repo = _make_repo();
    try {
        _commit(repo, "shared.txt", "original\n", "initial");
        git_create_branch(repo, "conflict-branch");
        _commit(repo, "shared.txt", "conflict branch change\n", "conflict commit");
        git_checkout(repo, "main");
        _commit(repo, "shared.txt", "main branch change\n", "main commit");
        result = git_merge(repo, "conflict-branch");
        assert result["success"] == False;
        assert result.get("conflicts") == True;
        assert "conflict" in result.get("error", "").lower();
        status = git_status(repo);
        assert status["dirty"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}
