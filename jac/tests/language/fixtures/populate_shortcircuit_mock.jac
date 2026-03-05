"""Test that populate() is skipped for non-matching edge/node types on stubs.

This test creates a graph, converts edge anchors to stubs (simulating
the state of anchors loaded from storage), and verifies that the
type-filter short-circuit avoids calling populate() on stubs whose
arch_cls does not match the requested filter.
"""

node User {
    has name: str;
}

node Item {
    has label: str;
}

edge Likes {}
edge Owns {}

import from unittest.mock { call }
import from jaclang.jac0core.constructs { clear_typeref_registry, make_type_ref }

# Clear the TypeRef registry to prevent false-positive collisions from
# other test fixtures that may have registered types under __main__.
with entry {
    clear_typeref_registry();
}

glob u1 = User(name="Alice"),
     item1 = Item(label="Widget");

with entry {
    root +>: Likes :+> u1;
    root +>: Owns :+> item1;
}

# Grab the root's node anchor.
glob root_anch = root.__jac__;

# Verify we have 2 edges.
with entry {
    assert len(root_anch.edges) == 2 , f"Expected 2 edges, got {len(root_anch.edges)}";
}

# Convert edge anchors to stubs (simulates un-populated storage state).
glob orig_edges = list(
         root_anch.edges
     ),
     stub_edges = [e.make_stub() for e in orig_edges];

# Verify stubs have arch_cls set but are NOT populated.
with entry {
    for (orig, stub) in zip(orig_edges, stub_edges) {
        assert 'arch_cls' in stub.__dict__ , "Stub must have arch_cls in __dict__";
        # In-memory stubs created from populated anchors may still be populated
        # if make_stub returns self (when not populated). For our test we need
        # actual stubs, so verify they differ or are already unpopulated.
    }

    # Replace edges with stubs on the root anchor.
    root_anch.edges = stub_edges;
}

# Record which stub is which type.
glob likes_stub = None,
     owns_stub = None;

with entry {
    for s in stub_edges {
        cls_chain = s.__dict__.get('arch_cls');
        if make_type_ref(Likes) in cls_chain {
            likes_stub = s;
        } elif make_type_ref(Owns) in cls_chain {
            owns_stub = s;
        }
    }
    assert likes_stub is not None , "Could not find Likes stub";
    assert owns_stub is not None , "Could not find Owns stub";
}

# Now patch populate on the stubs to track calls.
glob likes_orig_pop = likes_stub.populate,
     owns_orig_pop = owns_stub.populate,
     likes_pop_count = [0],
     owns_pop_count = [0];

def likes_pop_spy {
    likes_pop_count[0] += 1;
    likes_orig_pop();
}

def owns_pop_spy {
    owns_pop_count[0] += 1;
    owns_orig_pop();
}

with entry {
    likes_stub.populate = likes_pop_spy;
    owns_stub.populate = owns_pop_spy;
}

# Filtered traversal: only Likes edges.
# The Owns stub should be skipped (arch_cls != Likes).
glob result_likes = [root->:Likes:->];
with entry {
    print("LIKES_RESULT", len(result_likes));
    print("LIKES_POP", likes_pop_count[0]);
    print("OWNS_POP_AFTER_LIKES", owns_pop_count[0]);

    # The Owns stub's populate should NOT have been called.
    assert owns_pop_count[0] == 0 , f"Owns populate should not be called for Likes filter, but was called {owns_pop_count[
        0
    ]} times";

    # Likes stub was populated exactly once (first attribute access triggers populate).
    assert likes_pop_count[0] == 1 , f"Likes populate should be called exactly once, but was called {likes_pop_count[
        0
    ]} times";

    # Reset counts.
    likes_pop_count[0] = 0;
    owns_pop_count[0] = 0;
}

# Now re-stub (since populate was called, anchors are now populated).
glob stub_edges2 = [
         e.make_stub() for e in root_anch.edges
     ];
with entry {
    root_anch.edges = stub_edges2;

    for s in stub_edges2 {
        cls_chain = s.__dict__.get('arch_cls');
        if make_type_ref(Likes) in cls_chain {
            likes_stub2 = s;
            likes_orig_pop2 = s.populate;
            likes_pop_count2 = [0];
            def likes_pop_spy2 {
                likes_pop_count2[0] += 1;
                likes_orig_pop2();
            }
            s.populate = likes_pop_spy2;
        } elif make_type_ref(Owns) in cls_chain {
            owns_stub2 = s;
            owns_orig_pop2 = s.populate;
            owns_pop_count2 = [0];
            def owns_pop_spy2 {
                owns_pop_count2[0] += 1;
                owns_orig_pop2();
            }
            s.populate = owns_pop_spy2;
        }
    }
}

# Filtered traversal: only Owns edges.
glob result_owns = [root->:Owns:->];
with entry {
    print("OWNS_RESULT", len(result_owns));
    print("LIKES_POP_AFTER_OWNS", likes_pop_count2[0]);
    print("OWNS_POP2", owns_pop_count2[0]);

    assert likes_pop_count2[0] == 0 , f"Likes populate should not be called for Owns filter, but was called {likes_pop_count2[
        0
    ]} times";
    assert owns_pop_count2[0] == 1 , f"Owns populate should be called exactly once, but was called {owns_pop_count2[
        0
    ]} times";

    print("SHORTCIRCUIT_TESTS_PASSED");
}
