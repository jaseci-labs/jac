"""Tests for node definitions, graph hierarchy, and dict converter helpers.

NOTE: Within one file, tests share the same root. Tests that add nodes to root
use unique IDs to avoid collision with other tests in this file.
"""

import from services.ideServer {
    UserProfile,
    Project,
    ProjectVersion,
    _project_to_dict,
    _userprofile_to_dict,
    _version_to_dict,
    _utc_now
}

test "utc_now returns ISO string ending with Z" {
    ts = _utc_now();
    assert ts.endswith("Z");
    assert "T" in ts;
    assert len(ts) > 10;
}

test "UserProfile node stores fields correctly" {
    profile = UserProfile(
        user_id="user-abc",
        display_name="Alice",
        created_at="2025-01-01T00:00:00Z"
    );
    assert profile.user_id == "user-abc";
    assert profile.display_name == "Alice";
    assert profile.created_at == "2025-01-01T00:00:00Z";
}

test "UserProfile has empty display_name by default" {
    profile = UserProfile(user_id="u-default", created_at="now");
    assert profile.display_name == "";
}

test "Project node stores all fields" {
    proj = Project(
        id="prj_fields",
        name="My App",
        template_id="preview-template",
        repo_path="/tmp/test",
        created_at="2025-01-01T00:00:00Z",
        updated_at="2025-01-01T00:00:00Z",
        active_branch="main",
        last_commit="abc123"
    );
    assert proj.id == "prj_fields";
    assert proj.name == "My App";
    assert proj.repo_path == "/tmp/test";
    assert proj.last_commit == "abc123";
}

test "Project node defaults are correct" {
    proj = Project(id="prj_defaults", name="Test");
    assert proj.template_id == "preview-template";
    assert proj.repo_path == "";
    assert proj.active_branch == "main";
    assert proj.last_commit == "";
}

test "ProjectVersion node stores all fields" {
    ver = ProjectVersion(
        id="ver_1",
        project_id="prj_1",
        commit_sha="abc123",
        jacpack_path="/tmp/snap.jacpack",
        created_at="2025-01-01T00:00:00Z",
        trigger="autosave"
    );
    assert ver.id == "ver_1";
    assert ver.project_id == "prj_1";
    assert ver.commit_sha == "abc123";
    assert ver.trigger == "autosave";
}

test "ProjectVersion defaults to autosave trigger" {
    ver = ProjectVersion(id="ver_default", project_id="prj_x");
    assert ver.trigger == "autosave";
    assert ver.commit_sha == "";
}

test "graph: Root to UserProfile connection" {
    root ++> UserProfile(user_id="u_graph_root", display_name="Bob", created_at="now");
    profiles = [root -->(?:UserProfile)];
    found = False;
    for p in profiles {
        if p.user_id == "u_graph_root" {
            assert p.display_name == "Bob";
            found = True;
        }
    }
    assert found == True;
}

test "graph: UserProfile to Project connection" {
    root ++> UserProfile(user_id="u_graph_proj", created_at="now");
    profile = None;
    for p in [root -->(?:UserProfile)] {
        if p.user_id == "u_graph_proj" {
            profile = p;
        }
    }
    assert profile is not None;
    profile ++> Project(id="prj_graph_t9", name="Test App", created_at="now", updated_at="now");
    projects = [profile -->(?:Project)];
    assert len(projects) == 1;
    assert projects[0].id == "prj_graph_t9";
}

test "graph: multiple projects under one profile" {
    uid = "u_graph_multi";
    root ++> UserProfile(user_id=uid, created_at="now");
    profile = None;
    for p in [root -->(?:UserProfile)] {
        if p.user_id == uid {
            profile = p;
        }
    }
    assert profile is not None;
    profile ++> Project(id="prj_multi_a", name="App A", created_at="now", updated_at="now");
    profile ++> Project(id="prj_multi_b", name="App B", created_at="now", updated_at="now");
    projects = [profile -->(?:Project)];
    assert len(projects) == 2;
    ids = [p.id for p in projects];
    assert "prj_multi_a" in ids;
    assert "prj_multi_b" in ids;
}

test "graph: ProjectVersion connected to Project" {
    uid = "u_graph_ver";
    root ++> UserProfile(user_id=uid, created_at="now");
    profile = None;
    for p in [root -->(?:UserProfile)] {
        if p.user_id == uid {
            profile = p;
        }
    }
    assert profile is not None;
    proj = profile ++> Project(id="prj_ver_graph", name="VerTest", created_at="now", updated_at="now");
    project_node = proj[0];
    project_node ++> ProjectVersion(id="ver_graph_1", project_id="prj_ver_graph");
    versions = [project_node -->(?:ProjectVersion)];
    ver_ids = [v.id for v in versions];
    assert "ver_graph_1" in ver_ids;
}

test "_userprofile_to_dict returns correct dict" {
    profile = UserProfile(user_id="u_dict", display_name="Alice", created_at="2025-01-01T00:00:00Z");
    d = _userprofile_to_dict(profile);
    assert d["user_id"] == "u_dict";
    assert d["display_name"] == "Alice";
    assert d["created_at"] == "2025-01-01T00:00:00Z";
}

test "_project_to_dict returns correct dict" {
    proj = Project(
        id="prj_dict",
        name="My App",
        template_id="preview-template",
        repo_path="/tmp/test",
        created_at="2025-01-01T00:00:00Z",
        updated_at="2025-02-01T00:00:00Z",
        active_branch="main",
        last_commit="sha123"
    );
    d = _project_to_dict(proj);
    assert d["id"] == "prj_dict";
    assert d["name"] == "My App";
    assert d["template_id"] == "preview-template";
    assert d["last_commit"] == "sha123";
}

test "_project_to_dict handles list input with one item" {
    proj = Project(id="prj_list_wrap", name="X", created_at="now", updated_at="now");
    d = _project_to_dict([proj]);
    assert d["id"] == "prj_list_wrap";
}

test "_project_to_dict returns empty dict for empty list" {
    d = _project_to_dict([]);
    assert d == {};
}

test "_version_to_dict returns correct dict" {
    ver = ProjectVersion(
        id="ver_dict",
        project_id="prj_1",
        commit_sha="abc123",
        jacpack_path="/tmp/snap.jacpack",
        created_at="2025-01-01T00:00:00Z",
        trigger="init"
    );
    d = _version_to_dict(ver);
    assert d["id"] == "ver_dict";
    assert d["project_id"] == "prj_1";
    assert d["commit_sha"] == "abc123";
    assert d["trigger"] == "init";
}
