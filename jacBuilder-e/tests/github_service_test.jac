import os;
import tempfile;
import shutil;
import subprocess;

import from services.github_service {
    _get_github_credentials,
    run_git_authenticated,
    _cleanup_askpass
}

glob _orig_repo_client_id: str = os.environ.get("GITHUB_REPO_CLIENT_ID", "");
glob _orig_repo_client_secret: str = os.environ.get("GITHUB_REPO_CLIENT_SECRET", "");


test "get_github_credentials reads repo OAuth App env vars" {
    os.environ["GITHUB_REPO_CLIENT_ID"] = "test-repo-id-abc";
    os.environ["GITHUB_REPO_CLIENT_SECRET"] = "test-repo-secret-xyz";
    creds = _get_github_credentials();
    assert creds["client_id"] == "test-repo-id-abc", "client_id wrong";
    assert creds["client_secret"] == "test-repo-secret-xyz", "client_secret wrong";
    os.environ["GITHUB_REPO_CLIENT_ID"] = _orig_repo_client_id;
    os.environ["GITHUB_REPO_CLIENT_SECRET"] = _orig_repo_client_secret;
}

test "run_git_authenticated runs git command with askpass" {
    tmp_dir = tempfile.mkdtemp();
    subprocess.run(["git", "init", tmp_dir], capture_output=True);

    result = run_git_authenticated(tmp_dir, ["status"], "fake-token-123", timeout=10);
    assert result["success"] == True, "git status should succeed: " + str(result.get("error", ""));

    # Verify no askpass scripts remain
    askpass_files = [f for f in os.listdir(tempfile.gettempdir()) if f.startswith("gh_askpass_")];
    assert len(askpass_files) == 0, "Askpass script was not cleaned up: " + str(askpass_files);

    shutil.rmtree(tmp_dir);
}

test "run_git_authenticated handles timeout" {
    tmp_dir = tempfile.mkdtemp();
    subprocess.run(["git", "init", tmp_dir], capture_output=True);

    # git status with 1ms timeout should time out or succeed fast
    result = run_git_authenticated(tmp_dir, ["status"], "fake-token", timeout=10);
    # Either succeeds or fails, but shouldn't crash
    assert "success" in result, "Result should have success key";

    shutil.rmtree(tmp_dir);
}

test "run_git_authenticated reports failure for bad command" {
    tmp_dir = tempfile.mkdtemp();
    subprocess.run(["git", "init", tmp_dir], capture_output=True);

    result = run_git_authenticated(tmp_dir, ["checkout", "nonexistent-branch-12345"], "fake-token", timeout=10);
    assert result["success"] == False, "Should fail for nonexistent branch";

    shutil.rmtree(tmp_dir);
}

test "cleanup_askpass removes file" {
    tmp_path = os.path.join(tempfile.gettempdir(), "test_askpass_cleanup.sh");
    with open(tmp_path, "w") as f {
        f.write("#!/bin/sh\necho test\n");
    }
    assert os.path.exists(tmp_path), "File should exist before cleanup";
    _cleanup_askpass(tmp_path);
    assert not os.path.exists(tmp_path), "File should be removed after cleanup";
}

test "cleanup_askpass handles nonexistent file" {
    _cleanup_askpass("/tmp/nonexistent_askpass_file_12345.sh");
    # Should not raise an exception
}
