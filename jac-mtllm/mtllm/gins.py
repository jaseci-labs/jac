"""
Gins thread module for Jac runtime.

This module provides the GinSThread class, which can be attached to the Jac machine state
when run with the --gins option. The GinSThread is currently a placeholder and not yet fully implemented.
"""

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass


class GetAssertNodes(UniPass):
    """Fetch code pass."""

    def before_pass(self) -> None:
        """Before pass."""
        self.assert_nodes: list[uni.AssertStmt] = []

    def enter_assert_stmt(self, node: uni.AssertStmt) -> None:
        """Enter assert statement."""
        self.assert_nodes.append(node)


def fetch_altering_code(
    node: uni.UniCFGNode, symbol: uni.Symbol
) -> tuple[list[uni.UniCFGNode], list[uni.Symbol]]:
    """Fetch all nodes that alter the symbol from the start node."""
    code_nodes = []
    new_symbols = []
    # print(f"Node: {node} with {symbol.parent_tab}")
    for use in symbol.uses:
        node_i = use.parent_of_type(uni.UniCFGNode)
        if node == node_i:
            current_use = use
            node_use = node_i
            break
    for i, defn in enumerate(symbol.defn):
        if len(symbol.defn) != i + 1:
            if current_use.loc.first_line < symbol.defn[i + 1].loc.first_line:
                current_defn = defn
                break
        else:
            current_defn = defn
            break

    # print(f"Symbol: {symbol} with {current_use} and {current_defn}")
    node_defn = current_defn.parent_of_type(uni.UniCFGNode)
    if node_use not in code_nodes:
        code_nodes.append(node_use)
    if node_defn not in code_nodes:
        code_nodes.append(node_defn)

    # print(f"Node Use: {node_use.unparse()} and Node Defn: {node_defn.unparse()}")

    def_sym_list = list(node_defn.sym_tab.names_in_scope.values())
    for sym in def_sym_list:
        for use in sym.uses:
            if (
                use.parent_of_type(uni.UniCFGNode) == node_defn
                and node_defn != node_use
            ):
                new_symbols.append(sym)
                break

    # print (f"Definition node: {node_defn} and Use Node: {node_use}")

    if new_symbols != []:
        for sym in new_symbols:
            nodes, _ = fetch_altering_code(
                node=node_defn,
                symbol=sym,
            )
            for n in nodes:
                if n not in code_nodes:
                    code_nodes.append(n)
    return code_nodes, []


def format_code_dict_printable(code_dict: dict) -> str:
    """Format code_dict into a printable format with line numbers and code snippets.

    Args:
        code_dict: Dictionary with mod_path as keys and list of UniCFGNode as values

    Returns:
        Formatted string representation of the code dict
    """
    output_lines = []

    for mod_path, code_items in code_dict.items():
        output_lines.append(f"\n{mod_path}")

        # Sort code items by line number for better readability
        sorted_items = sorted(code_items, key=lambda item: item.loc.first_line)

        # Group consecutive lines to show context
        if not sorted_items:
            continue

        current_group = [sorted_items[0]]

        for item in sorted_items[1:]:
            # If the current item is within 3 lines of the last item in current group,
            # add it to the current group, otherwise start a new group
            if item.loc.first_line - current_group[-1].loc.last_line <= 3:
                current_group.append(item)
            else:
                # Process current group
                _add_group_to_output(output_lines, current_group)
                current_group = [item]

        # Process the last group
        _add_group_to_output(output_lines, current_group)

    return "\n".join(output_lines)


def _add_group_to_output(output_lines: list[str], group: list) -> None:
    """Add a group of code items to output lines."""
    if not group:
        return

    output_lines.append("    ...")

    for item in group:
        # Get the unparsed code
        unparsed_code = item.unparse()

        # Handle multi-line code by splitting and numbering each line
        code_lines = unparsed_code.split("\n")
        start_line = item.loc.first_line

        for i, code_line in enumerate(code_lines):
            line_num = start_line + i
            # Right-align line numbers for better formatting
            output_lines.append(f"  {line_num:3d} | {code_line}")

    output_lines.append("")
