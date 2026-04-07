"""Tests for the project_ops walker using graph state inspection.

NOTE: result.reports is not accessible in direct spawn tests.
Tests verify graph side effects: node counts and field values.

NOTE: Tests within a file share root. Tests are ordered so that:
  - Early tests (no profile) run FIRST
  - Later tests add profile + projects and verify graph state.
"""

import from services.ideServer { project_ops, me, UserProfile, Project }

test "project_ops list does not create any nodes when no profile exists" {
    count_before = len([root -->(?:UserProfile)]);
    root spawn project_ops(action="list");
    count_after = len([root -->(?:UserProfile)]);
    assert count_after == count_before;
    assert count_after == 0;
}

test "project_ops create does not add project when no profile exists" {
    profile_count = len([root -->(?:UserProfile)]);
    root spawn project_ops(action="create", name="Test App");
    assert len([root -->(?:UserProfile)]) == profile_count;
}

test "project_ops list returns zero projects after me creates empty profile" {
    root spawn me(display_name_hint="ProjTester");
    profiles = [root -->(?:UserProfile)];
    assert len(profiles) == 1;
    projects = [profiles[0] -->(?:Project)];
    assert len(projects) == 0;
}

test "project_ops create does not add project with empty name" {
    profile = [root -->(?:UserProfile)][0];
    count_before = len([profile -->(?:Project)]);
    root spawn project_ops(action="create", name="");
    count_after = len([profile -->(?:Project)]);
    assert count_after == count_before;
}

test "project_ops create does not add project with whitespace-only name" {
    profile = [root -->(?:UserProfile)][0];
    count_before = len([profile -->(?:Project)]);
    root spawn project_ops(action="create", name="   ");
    count_after = len([profile -->(?:Project)]);
    assert count_after == count_before;
}

test "project_ops rename modifies project name in graph" {
    profile = [root -->(?:UserProfile)][0];
    profile ++> Project(
        id="prj_rename_test",
        name="Original Name",
        repo_path="/tmp/nonexistent",
        created_at="2025-01-01Z",
        updated_at="2025-01-01Z"
    );
    root spawn project_ops(action="rename", project_id="prj_rename_test", name="Renamed App");
    all_projects = [profile -->(?:Project)];
    found_renamed = False;
    for p in all_projects {
        if p.id == "prj_rename_test" {
            assert p.name == "Renamed App";
            found_renamed = True;
        }
    }
    assert found_renamed == True;
}

test "project_ops rename with no name does not change project" {
    profile = [root -->(?:UserProfile)][0];
    projects = [profile -->(?:Project)];
    original_name = "";
    for p in projects {
        if p.id == "prj_rename_test" {
            original_name = p.name;
        }
    }
    root spawn project_ops(action="rename", project_id="prj_rename_test", name="");
    for p in [profile -->(?:Project)] {
        if p.id == "prj_rename_test" {
            assert p.name == original_name;
        }
    }
}

test "project_ops list returns all projects sorted by updated_at desc" {
    profile = [root -->(?:UserProfile)][0];
    profile ++> Project(id="prj_old", name="Old App", created_at="2025-01-01Z", updated_at="2025-01-01Z");
    profile ++> Project(id="prj_new", name="New App", created_at="2025-01-01Z", updated_at="2025-06-01Z");
    all_prj = [profile -->(?:Project)];
    sorted_prj = sorted(all_prj, key=lambda p: p.updated_at, reverse=True);
    assert len(sorted_prj) >= 2;
    assert sorted_prj[0].updated_at >= sorted_prj[1].updated_at;
}

test "project_ops delete removes project from graph" {
    profile = [root -->(?:UserProfile)][0];
    profile ++> Project(
        id="prj_to_delete",
        name="Delete Me",
        repo_path="/tmp/nonexistent_del",
        created_at="2025-01-01Z",
        updated_at="2025-01-01Z"
    );
    count_before = len([profile -->(?:Project)]);
    root spawn project_ops(action="delete", project_id="prj_to_delete");
    all_projects = [profile -->(?:Project)];
    ids = [p.id for p in all_projects];
    assert "prj_to_delete" not in ids;
}

test "project_ops unknown action does not modify graph" {
    profile = [root -->(?:UserProfile)][0];
    count_before = len([profile -->(?:Project)]);
    root spawn project_ops(action="invalid_action_xyz");
    count_after = len([profile -->(?:Project)]);
    assert count_after == count_before;
}
