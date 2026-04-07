"""Tests for the `me` walker using graph state inspection.

NOTE: result.reports is not accessible in direct spawn tests (Jac limitation).
Tests verify observable graph side effects instead.

NOTE: When run with `jac test -d`, prior test files may have already created
profiles. Tests are designed to be state-independent: they check relative counts
and specific IDs rather than assuming a clean slate.
"""

import from services.ideServer { me, UserProfile }

test "me walker returns a profile that exists in the graph" {
    count_before = len([root -->(?:UserProfile)]);
    root spawn me(display_name_hint="MeTestHint");
    profiles_after = [root -->(?:UserProfile)];
    assert len(profiles_after) >= 1;
    if count_before == 0 {
        assert len(profiles_after) == 1;
    }
}

test "me walker reuses existing profile — does not create duplicate on second spawn" {
    count_before = len([root -->(?:UserProfile)]);
    root spawn me(display_name_hint="ShouldNotAdd");
    count_after = len([root -->(?:UserProfile)]);
    assert count_after == count_before;
}

test "me walker does not overwrite existing non-empty display_name with hint" {
    profiles_before = [root -->(?:UserProfile)];
    assert len(profiles_before) >= 1;
    original_display = profiles_before[0].display_name;
    root spawn me(display_name_hint="TryToOverwrite");
    profiles_after = [root -->(?:UserProfile)];
    assert profiles_after[0].display_name == original_display;
}

test "me walker creates profile with UUID-formatted user_id" {
    all_profiles = [root -->(?:UserProfile)];
    uuid_found = False;
    for p in all_profiles {
        parts = p.user_id.split("-");
        if len(parts) == 5 and len(p.user_id) == 36 {
            uuid_found = True;
        }
    }
    assert uuid_found == True;
}

test "me walker profile has all expected fields" {
    uuid_profiles = [];
    for p in [root -->(?:UserProfile)] {
        parts = p.user_id.split("-");
        if len(parts) == 5 and len(p.user_id) == 36 {
            uuid_profiles.append(p);
        }
    }
    assert len(uuid_profiles) >= 1;
    p = uuid_profiles[0];
    assert isinstance(p.user_id, str);
    assert isinstance(p.display_name, str);
    assert isinstance(p.created_at, str);
    assert p.created_at.endswith("Z");
}
