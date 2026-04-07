"""Tests for env_ops walker using filesystem state verification.

NOTE: result.reports not accessible in direct spawn tests.
Tests verify filesystem side effects (env files written) and graph state.
NOTE: Each file gets a fresh root. Tests within this file share root state.
"""

import os;
import shutil;
import tempfile;
import from services.ideServer { env_ops, me, UserProfile, Project }
import from services.project_manager { read_project_env }

test "env_ops does not create any graph nodes when project_id is empty" {
    count_before = len([root -->(?:UserProfile)]);
    root spawn env_ops(project_id="", action="list_project");
    count_after = len([root -->(?:UserProfile)]);
    assert count_after == count_before;
}

test "env_ops does not create profile when user profile not found" {
    uid = "env_ops_sentinel_u999";
    root ++> UserProfile(user_id=uid, display_name="Sentinel", created_at="now");
    count_with_sentinel = len([root -->(?:UserProfile)]);
    root spawn env_ops(project_id="prj_no_match_xyz", action="list_project");
    assert len([root -->(?:UserProfile)]) == count_with_sentinel;
}

test "env_ops save_project writes .env file to repo_path" {
    tmp_dir = tempfile.mkdtemp();
    try {
        root spawn me(display_name_hint="EnvTester");
        profile = [root -->(?:UserProfile)][0];
        profile ++> Project(
            id="prj_env1",
            name="Env Test",
            repo_path=tmp_dir,
            created_at="now",
            updated_at="now"
        );
        env_data = [
            {"key": "APP_SECRET", "value": "mysecret"},
            {"key": "PORT", "value": "8080"}
        ];
        root spawn env_ops(project_id="prj_env1", action="save_project", env_list=env_data);
        env_path = os.path.join(tmp_dir, ".env");
        assert os.path.exists(env_path);
        written = read_project_env(env_path);
        assert len(written) == 2;
        keys = [e["key"] for e in written];
        assert "APP_SECRET" in keys;
        assert "PORT" in keys;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "env_ops save_project then save again with different data overwrites file" {
    tmp_dir = tempfile.mkdtemp();
    try {
        profile = [root -->(?:UserProfile)][0];
        profile ++> Project(
            id="prj_env2",
            name="Env Test 2",
            repo_path=tmp_dir,
            created_at="now",
            updated_at="now"
        );
        root spawn env_ops(
            project_id="prj_env2",
            action="save_project",
            env_list=[{"key": "OLD_KEY", "value": "old"}]
        );
        root spawn env_ops(
            project_id="prj_env2",
            action="save_project",
            env_list=[{"key": "NEW_KEY", "value": "new"}]
        );
        written = read_project_env(os.path.join(tmp_dir, ".env"));
        keys = [e["key"] for e in written];
        assert "NEW_KEY" in keys;
        assert "OLD_KEY" not in keys;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "env_ops save_project with empty list produces empty .env file" {
    tmp_dir = tempfile.mkdtemp();
    try {
        profile = [root -->(?:UserProfile)][0];
        profile ++> Project(
            id="prj_env3",
            name="Env Test 3",
            repo_path=tmp_dir,
            created_at="now",
            updated_at="now"
        );
        root spawn env_ops(project_id="prj_env3", action="save_project", env_list=[]);
        result = read_project_env(os.path.join(tmp_dir, ".env"));
        assert result == [];
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "env_ops unknown action does not modify any env file" {
    tmp_dir = tempfile.mkdtemp();
    try {
        profile = [root -->(?:UserProfile)][0];
        profile ++> Project(
            id="prj_env4",
            name="Env Test 4",
            repo_path=tmp_dir,
            created_at="now",
            updated_at="now"
        );
        env_path = os.path.join(tmp_dir, ".env");
        root spawn env_ops(project_id="prj_env4", action="invalid_action");
        assert not os.path.exists(env_path);
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}
