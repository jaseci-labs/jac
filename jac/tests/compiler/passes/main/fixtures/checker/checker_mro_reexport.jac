"""Test: MRO with import through Python __init__.py re-export.

This tests that when a class is imported through a Python __init__.py
that re-exports from a Jac module, the base class type resolves correctly
and the MRO is properly computed.
"""

import from mro_reexport_pkg { Node, NodeContainer }

class FinalContainer(NodeContainer) {
    def get_data(self: FinalContainer) -> Node;
}

impl FinalContainer.get_data(self: FinalContainer) -> Node {
    return self.data;  # Should resolve through MRO to BaseContainer.data
}
