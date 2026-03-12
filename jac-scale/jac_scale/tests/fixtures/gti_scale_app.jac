"""Fixture app for GTI Redis topology tests.

Nodes use inheritance (PostNode extends BaseContent) to exercise MRO fan-out.
All walkers are :pub so they are reachable via HTTP during test runs.
"""

node BaseContent {
    has val: int = 0;
}

node PostNode(BaseContent) {
    has val: int = 0;
}

node OtherNode {
    has val: int = 0;
}

"""Build a typed graph rooted at Root.

n_post PostNodes and n_other OtherNodes are connected to Root.
Returns the counts so tests can assert on them.
"""
walker:pub BuildGraph {
    has n_post: int = 8,
        n_other: int = 8;

    can build with Root entry {
        for i in range(self.n_post) {
            here ++> PostNode(val=i);
        }
        for i in range(self.n_other) {
            here ++> OtherNode(val=i);
        }
        report {"n_post": self.n_post, "n_other": self.n_other};
    }
}

"""Typed traversal via BaseContent — exercises GTI MRO fan-out.

Returns the count of matching nodes. OtherNode must NOT appear.
"""
walker:pub QueryByBase {
    can query with Root entry {
        results = [-->(?:BaseContent)];
        report {"count": len(results)};
    }
}

"""Remove the first PostNode edge from Root, leaving n_post-1 edges."""
walker:pub DeleteFirstPost {
    can del_first with Root entry {
        posts = [-->(?:PostNode)];
        if posts {
            here del --> posts[0];
            report {"deleted": True};
        } else {
            report {"deleted": False};
        }
    }
}

"""Call migrate_to_qualified_types on the current context memory.

Returns the migration result dict so tests can inspect backend and counts.
"""
walker:pub RunMigration {
    can migrate with Root entry {
        import from jaclang { JacRuntime as Jac }
        import from jaclang.runtimelib.sam_gti { migrate_to_qualified_types }
        ctx = Jac.get_context();
        result = migrate_to_qualified_types(ctx.mem);
        report result;
    }
}
