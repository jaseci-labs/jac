"""Test that type-filtered traversals return correct results.

Creates a graph with mixed edge/node types and verifies that
type-filtered traversals return only matching edge/node combinations.
"""

node Profile {
    has name: str;
}

node Post {
    has title: str;
}

node Comment {
    has text: str;
}

edge Follow {}
edge Authored {}
edge Replied {}

# Build a small heterogeneous graph off root:
#   root -Follow-> p1(Profile)
#   root -Follow-> p2(Profile)
#   root -Authored-> post1(Post)
#   root -Replied-> c1(Comment)
glob p1 = Profile(name="Alice"),
     p2 = Profile(name="Bob"),
     post1 = Post(title="Hello"),
     c1 = Comment(text="Nice");

with entry {
    root +>: Follow :+> p1;
    root +>: Follow :+> p2;
    root +>: Authored :+> post1;
    root +>: Replied :+> c1;
}

# Unfiltered: should get all 4 nodes
glob all_nodes = [root-->];

with entry {
    print("ALL_COUNT", len(all_nodes));
    assert len(all_nodes) == 4 , f"Expected 4, got {len(all_nodes)}";
}

# Filter by edge type Follow: should get 2 Profile nodes
glob follow_nodes = [root->:Follow:->];

with entry {
    print("FOLLOW_COUNT", len(follow_nodes));
    assert len(follow_nodes) == 2 , f"Expected 2, got {len(follow_nodes)}";
    for n in follow_nodes {
        assert isinstance(n, Profile) , f"Expected Profile, got {type(n)}";
    }
}

# Filter by edge type Follow AND node type Profile
glob follow_profile = [root->:Follow:->(?:Profile)];

with entry {
    print("FOLLOW_PROFILE_COUNT", len(follow_profile));
    assert len(follow_profile) == 2 , f"Expected 2, got {len(follow_profile)}";
}

# Filter by edge type Authored
glob authored_nodes = [root->:Authored:->];

with entry {
    print("AUTHORED_COUNT", len(authored_nodes));
    assert len(authored_nodes) == 1;
    assert isinstance(authored_nodes[0], Post);
}

# Filter by node type Post (no edge filter)
glob post_nodes = [root-->(?:Post)];

with entry {
    print("POST_COUNT", len(post_nodes));
    assert len(post_nodes) == 1;
}

# Filter by node type Comment
glob comment_nodes = [root-->(?:Comment)];

with entry {
    print("COMMENT_COUNT", len(comment_nodes));
    assert len(comment_nodes) == 1;

    # Chained: Follow edges to Profile, then Authored from Profile
    p1 +>: Authored :+> Post(title="P1 Post");
}

glob chained = [root->:Follow:->->:Authored:->];

with entry {
    print("CHAINED_COUNT", len(chained));
    assert len(chained) == 1;

    print("FUNCTIONAL_TESTS_PASSED");
}
