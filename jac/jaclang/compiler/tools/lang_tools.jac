import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.products { require_product }
import from jaclang.compiler.pipeline.contracts { CompilationProduct }
import from jaclang.cli.console { console }
import from jaclang.compiler.tools.unparse_pass { unparse_module }
import from jaclang.compiler.tools.treeprinter {
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree
}
import ast as py_ast;
import inspect;
import json;
import os;
import sys;
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.backends.es { EsastGenPass, es_node_to_dict }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.backends.es.estree { Node as EsNode }
import from jaclang.compiler.frontend.pyast_load_pass { PyastBuildPass }
import from jaclang.compiler.analysis.flow.cfg_build_pass { cfg_dot_from_file }
import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
import from jaclang.compiler.ir.schema { UniScopeNode }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.frontend.source_io {
    pascal_to_snake,
    read_file_with_encoding
}

obj AstKidInfo {
    has name: str,
        typ: str,
        `default: (str | None) = None;
}

obj UniNodeInfo {
    has cls: type,
        name: str = '',
        doc: (str | None) = None,
        class_name_snake: str = '',
        init_sig: inspect.Signature = inspect.Signature(),
        kids: list[AstKidInfo] = [];

    with entry {
        type_map: ClassVar[dict[(str, type)]] = {};
    }

    def postinit -> None;
    def process(cls: type[uni.UniNode]) -> None;
}

obj AstTool {
    has ast_classes: list[UniNodeInfo] = [];

    def init -> None;
    def py_uni_nodes -> str;
    def ir(args: list[str]) -> str;
    def autodoc_uninode -> str;
}
