#this file is part of formatter tests and is not meant to be run
class SemTokManager {
    """Initialize semantic token manager."""
    def init(self: SemTokManager, ir: uni.Module) -> None {
        self.aaaaastatic_sem_tokens:
            List[Tuple[lspt.Position, int, int, uni.AstSymbolNode]] = self.gen_sem_tok_node(
            ir
        );
    }
}


def walrus_example() {
    if ((x := 10) > 5) {
        print(x);
        b = a(
            11111111111111111111111111111111111111111111111111111111111111111111111111
        );
    }
}


with entry {
    c = (
        a()
        if 1
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        else (
            999
            if isinstance(a, int)
            and isinstance(a, int)
            and isinstance(a, int)
            and isinstance(4, bool)
            else 7
        )
    );
    print("""This is a long
        line of code.""");
}


class ModuleManager {
    def clear_alerts_for_file(self: ModuleManager, file_path_fs: str) -> None {
        #list comprehension example
        self.warnings_had = [
            w
            for w in self.program
            if w.loc.mod_path != file_path_fs
        ];
        self.program.errors_had = [
            e
            for e in self.program.errors_haddddddddd
            if e.loc.mod_path != file_path_fs
        ];
        self.program.errors_had = [
            e
            for e in self.program.errors_haddddddddddddddddddddddddddddddddddddddddd
            if e.loc.mod_path != file_path_fs
        ];
        # dict comprehension example
        squares_dict = {x : x ** 2 for x in numbers};
        squares_dict = {
            x : x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssss
        };
        squares_dict = {
            x : x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        };
        # set comprehension example
        squares_set = {x ** 2 for x in numbers};
        squares_set = {
            x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssssss
        };
        squares_set = {
            x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        };
        # generator comprehension example
        squares_gen = (x ** 2 for x in numbers);
        squares_gen = (
            x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssssssssss
        );
        squares_gen = (
            x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        );
    }
}


## expr as item extra space issue
with entry {
    with open(f"Apple{apple}.txt") as f {
        # Fix syntax highlighting
        print(
            f.read()
        );
    }
}


def func_with_very_long_params(
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa: int,
    bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: int,
) -> None {
    print(
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,
    );
}


def func_with_long_params(
    aaaaaaaaaaaaaaaaaaaaaa: int, bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: int,
) -> None {
    print(
        aaaaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb, 1111111111111
    );
}


def func_with_short_params(a: int, b: int) -> None {
    print(a + b + c[5:]);
}


with entry {
    if (
        node_selected
        and node_selected.find_parent_of_type(uni.Archetype)
        or node_selected.find_parent_of_type(uni.ImplDef)
    ) {
        self_symbol = [
            lspt.CompletionItem(label='self', kind=lspt.CompletionItemKind.Variable)
        ];
    } else {
        self_symbol = [];
    }
    x = (
        1222222222
        and 2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
    );
    a = 4 if True else 4;
}


import from typing { Any, Awaitable, Callable, Coroutine, Optional, ParamSpec, TypeVar }

import from jaclang.compiler.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType,
}


"""Return diagnostics."""
def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic] {
    if (
        isinstance(node_selected, uni.Name)
        and node_selected.parent
        and isinstance(node_selected.parent, uni.ModulePath)
    ) {
        node_selected = node_selected.name_of;
    } elif (
        isinstance(node_selected, uni.Name)
        and node_selected.parent
        and isinstance(node_selected.parent, uni.ModulePath)
    ) {
        spec = node_selected.parent.parent.abs_path;
    }
}


@decorator
def x() {
    assert gg == 7;
}


@decorator()
class KK {}


# kkk
import pygame, random, math;


# fff
with entry {
    # gg
    a = 9;
}


# kkk
class X {}


# comment
@decorator
def xxx() { }


# ddd
glob a = 7;
def get_node_info(self: JacLangServer, sym_node: uni.AstSymbolNode) -> Optional[str] {
    try {
        if isinstance(sym_node, uni.NameAtom) {
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"'('{(access if access else '')}{sym_node.sym_category.value}') '{sym_node.sym_name}";
        if sym_node.name_spec.clean_type {
            node_info += f"': '{sym_node.name_spec.clean_type}";
        }
        if (
            isinstance(sym_node, uni.AstSymbolNode)
            and isinstance(sym_node.name_spec.type, ClassType)
        ) {
            node_info += f"': '{sym_node.name_spec.type.shared.class_name}";
        }
        if (isinstance(sym_node, uni.AstDocNode) and sym_node.doc) {
            node_info += f"'\n'{sym_node.doc.value}";
        }
        if (isinstance(sym_node, uni.Ability) and sym_node.signature) {
            node_info += f"'\n'{sym_node.signature.unparse()}";
        }
    } except AttributeError as e {
        self.log_warning(f"'Attribute error when accessing node attributes: '{e}");
    }
    return node_info.strip();
}


class foo {
    """Get information about a node."""
    def get_node_info(
        self: JacLangServer, sym_node: uni.AstSymbolNode
    ) -> Optional[str] {
        if isinstance(sym_node, uni.AstVarNode) {
            var_name = sym_node.name;
            var_type = sym_node.var_type if sym_node.var_type else 'unknown';
            return f" 'Variable: ' {var_name} ', Type: ' {var_type} ";
        } elif isinstance(sym_node, uni.AstFuncNode) {
            func_name = sym_node.name;
            params = ', '.join(
                [f" {p.name} ': ' {p.param_type} " for p in sym_node.params]
            );
            return f" 'Function: ' {func_name} '(' {params} ')' ";
        }
    }
}


def x3() {
    if dest_type.is_class_instance() and src_type.is_class_instance() {
        print("x");
    }
    if (
        dest_type.is_class_instance()
        and src_type.is_class_instance()
        and src_type.is_class_instance()
    ) {
        print("x");
    }
    if (dest_type.is_class_instance() and src_type.is_class_instance()) {
        print("x");
    }
}


class HH {
    def test()  -> Optional[str] {
        a = """!
hello
hru
""";
    }
}


# ===== Part 4: Implementation Blocks =====
# Implement forward-declared methods using impl
impl AbstractCalculator.process(value: float) -> float {
    return value * 1.5;
}
