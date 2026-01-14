"""Language tools for the Jaclang project."""
import ast as py_ast;
import inspect;
import json;
import os;
import sys;
import from typing { ClassVar }
import jaclang.pycore.unitree as uni;
import from jaclang.compiler.passes.ecmascript { EsastGenPass, es_node_to_dict }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import from jaclang.compiler.passes.main { PyastBuildPass }
import from jaclang.compiler.passes.main.cfg_build_pass { cfg_dot_from_file }
import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
import from jaclang.pycore.unitree { UniScopeNode }
import from jaclang.pycore.program { JacProgram }
import from jaclang.pycore.helpers { auto_generate_refs, pascal_to_snake }
import from jaclang.runtimelib.utils { read_file_with_encoding }
"""Information about a kid."""
obj AstKidInfo {
    has name: str,
        typ: str,
        <>default: (str | None) = None;
}

"""Meta data about AST nodes."""
obj UniNodeInfo {
    has cls: type;

    with entry {
        type_map: ClassVar[dict[(str, type)]] = {};
    }

    def postinit -> None;
    def process(cls: type[uni.UniNode]) -> None;
}

"""Ast tools."""
obj AstTool {
    def init -> None;
    def pass_template -> str;
    def py_uni_nodes -> str;
    def ir(args: list[str]) -> str;
    def autodoc_uninode -> str;
    def automate_ref -> str;
}
