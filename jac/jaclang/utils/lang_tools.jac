"""Language tools for the Jaclang project."""
import ast as py_ast;
import inspect;
import json;
import os;
import sys;
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
class AstKidInfo {
    def init(
        self: AstKidInfo, name: str, typ: str, <>default: (str | None) = None
    ) -> None;
}

"""Meta data about AST nodes."""
class UniNodeInfo {
    with entry {
        type_map: dict[(str, type)] = {};
    }

    def init(self: UniNodeInfo, cls: type) -> None;
    def process(self: UniNodeInfo, cls: type[uni.UniNode]) -> None;
}

"""Ast tools."""
class AstTool {
    def init(self: AstTool) -> None;
    def pass_template(self: AstTool) -> str;
    def py_uni_nodes(self: AstTool) -> str;
    def ir(self: AstTool, args: list[str]) -> str;
    def autodoc_uninode(self: AstTool) -> str;
    def automate_ref(self: AstTool) -> str;
}
