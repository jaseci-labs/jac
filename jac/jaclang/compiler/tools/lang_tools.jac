import ast as py_ast;
import inspect;
import json;
import os;
import sys;

obj AstKidInfo {
    has name: str,
        typ: str,
        `default: (str | None) = None;
}

obj UniNodeInfo {
    has cls: type,
        name: str = '',
        doc: (str | None) = None,
        init_sig: inspect.Signature = inspect.Signature(),
        kids: list[AstKidInfo] = [];

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
