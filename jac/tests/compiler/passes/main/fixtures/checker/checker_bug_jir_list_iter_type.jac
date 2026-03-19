"""Test that list iteration types survive JIR cache round-trip."""

import from jaclang.jac0core.archetype { NodeAnchor, EdgeAnchor }

def test_list_iter_type(nanch: NodeAnchor) -> None {
    for anchor in nanch.edges {
        aid = anchor.id;  # <-- Ok: EdgeAnchor.id (was Unknown before fix)
    }
}
