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
        if 1 and
        isinstance(a, int) and
        isinstance(a, int) and
        isinstance(a, int) and
        isinstance(a, int) and
        isinstance(a, int)
        else (
            999
            if isinstance(a, int) and
            isinstance(a, int) and
            isinstance(a, int) and
            isinstance(4, bool)
            else 7
        )
    );
    print(
        """This is a long
        line of code."""
    );
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
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa: int,
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
        node_selected and
        node_selected.find_parent_of_type(uni.Archetype) or
        node_selected.find_parent_of_type(uni.ImplDef)
    ) {
        self_symbol = [
            lspt.CompletionItem(label='self', kind=lspt.CompletionItemKind.Variable)
        ];
    } else {
        self_symbol = [];
    }
    x = (
        1222222222 and
        2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
    );
    a = 4 if True else 4;
}


"""Return diagnostics."""
def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic] {
    if (
        isinstance(node_selected, uni.Name) and
        node_selected.parent and
        isinstance(node_selected.parent, uni.ModulePath)
    ) {
        node_selected = node_selected.name_of;
    } elif (
        isinstance(node_selected, uni.Name) and
        node_selected.parent and
        isinstance(node_selected.parent, uni.ModulePath)
    ) {
        spec = node_selected.parent.parent.abs_path;
    }
}


@decorator
def x() { }


@decorator()
class KK {}
