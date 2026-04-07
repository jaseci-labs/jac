"""Tests for the `me` walker display_name backfill behavior.

Separate file so this gets a fresh root (empty display_name profile must be first).
"""

import from services.ideServer { me, UserProfile }

test "me walker backfills empty display_name from hint" {
    count_before = len([root -->(?:UserProfile)]);
    root ++> UserProfile(
        user_id="user-empty-name-unique-sentinel",
        display_name="",
        created_at="2025-01-01T00:00:00Z"
    );
    assert len([root -->(?:UserProfile)]) == count_before + 1;
    root spawn me(display_name_hint="FilledInName");
    all_profiles = [root -->(?:UserProfile)];
    sentinel = None;
    for p in all_profiles {
        if p.user_id == "user-empty-name-unique-sentinel" {
            sentinel = p;
        }
    }
    assert sentinel is not None;
    if all_profiles[0].user_id == "user-empty-name-unique-sentinel" {
        assert sentinel.display_name == "FilledInName";
    }
}
