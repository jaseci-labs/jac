"""Tests for git operations in project_manager: _run_git, _git_head, _git_branch, commit_all_changes."""

import os;
import shutil;
import tempfile;
import subprocess;
import from services.project_manager { _run_git, _git_head, _git_branch, commit_all_changes, get_project_status }

def _make_git_repo() -> str {
    tmp_dir = tempfile.mkdtemp();
    subprocess.run(["git", "init"], cwd=tmp_dir, capture_output=True);
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_dir, capture_output=True);
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_dir, capture_output=True);
    subprocess.run(["git", "checkout", "-B", "main"], cwd=tmp_dir, capture_output=True);
    return tmp_dir;
}

def _make_initial_commit(repo_path: str) -> None {
    with open(os.path.join(repo_path, "README.md"), "w") as f {
        f.write("# Test\n");
    }
    subprocess.run(["git", "add", "-A"], cwd=repo_path, capture_output=True);
    subprocess.run(["git", "commit", "-m", "init"], cwd=repo_path, capture_output=True);
}

test "run_git returns success for valid git status command" {
    repo = _make_git_repo();
    try {
        result = _run_git(repo, ["status"], check=False);
        assert result["success"] == True;
        assert "stdout" in result;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "run_git returns failure for unknown git command" {
    repo = _make_git_repo();
    try {
        result = _run_git(repo, ["not_a_real_command_xyz"], check=False);
        assert result["success"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "run_git returns failure for bad path" {
    result = _run_git("/nonexistent/path/xyz", ["status"], check=False);
    assert result["success"] == False;
}

test "git_head returns empty string for repo with no commits" {
    repo = _make_git_repo();
    try {
        head = _git_head(repo);
        assert head == "";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_head returns commit SHA after first commit" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        head = _git_head(repo);
        assert len(head) == 40;
        assert head.isalnum();
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "git_branch returns branch name after checkout" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        branch = _git_branch(repo);
        assert branch == "main";
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "commit_all_changes skips when nothing to commit" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        commit_all_changes(repo, "setup: ensure gitignore is committed");
        result = commit_all_changes(repo, "should skip");
        assert result["success"] == True;
        assert result.get("skipped", False) == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "commit_all_changes creates new commit when files changed" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        with open(os.path.join(repo, "new_file.txt"), "w") as f {
            f.write("new content\n");
        }
        result = commit_all_changes(repo, "add new file");
        assert result["success"] == True;
        assert result.get("skipped", False) == False;
        assert len(result.get("commit", "")) == 40;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "commit_all_changes returns failure for non-git directory" {
    tmp = tempfile.mkdtemp();
    try {
        result = commit_all_changes(tmp, "should fail");
        assert result["success"] == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "get_project_status returns success for valid git repo" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        result = get_project_status(repo);
        assert result["success"] == True;
        assert "active_branch" in result;
        assert "last_commit" in result;
        assert "dirty" in result;
        assert result["active_branch"] == "main";
        assert len(result["last_commit"]) == 40;
        assert result["dirty"] == False;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "get_project_status reports dirty when file modified" {
    repo = _make_git_repo();
    try {
        _make_initial_commit(repo);
        with open(os.path.join(repo, "dirty.txt"), "w") as f {
            f.write("uncommitted change\n");
        }
        result = get_project_status(repo);
        assert result["success"] == True;
        assert result["dirty"] == True;
    } finally {
        shutil.rmtree(repo, ignore_errors=True);
    }
}
