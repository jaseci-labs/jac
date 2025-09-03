"""AdHocPass

"""


import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass



class AdHocPass(UniPass):
    """Sanitize pass for JacLang."""


    def before_pass(self) -> None:
        """Initialize the AdHoc pass."""
        self.prog.mod.hub.popitem()
        return super().before_pass()

    def enter_node(self, node):
        super().enter_node(node)
        if isinstance(node, uni.Expr):
            node.type = None
            if isinstance(node, uni.NameAtom):
                node.sym = None
