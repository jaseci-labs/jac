import ast;

def host_parsed_module(source: str, path: str) -> ast_nodes.Module;

def lifted_node(source_node: ast.AST) -> any;

def lifted_value(value: any) -> any;

def lifted_constant(value: any) -> PyObj;
