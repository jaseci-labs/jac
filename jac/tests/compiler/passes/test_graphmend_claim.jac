"""Automatic import claiming with no scope configured: what seeds it, how far
the closure runs, and where it stops. Fixtures are generated at test time; the
repository does not accept new Python files."""
import ast;
import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob SEED_SRC = '''
import torch

from .util import reachable_helper


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''',
     DEP_SRC = '''
import torch


def reachable_helper(x):
    print("IN-HELPER", x)
    return x * 2
''';

"""Write `name` under `tmp` and return its absolute path."""
def _write(tmp: str, name: str, src: str) -> str {
    path = os.path.join(tmp, name);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as fh {
        fh.write(src);
    }
    return path;
}

"""Compile `path` in `prog` and return its generated Python source."""
def _src(prog: JacProgram, path: str) -> str {
    prog.invalidate_module(path);
    mod = prog.compile(file_path=path, options=CompileOptions(graphmend=True));
    pa = mod.gen.py_ast;
    mod_ast: any = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""The facts carrier recorded on the compiled module for `path` in `prog`."""
def _mod_facts(prog: JacProgram, path: str) -> any {
    mod = prog.mod.hub.get(os.path.realpath(path));
    return mod.gen.graphmend_facts if (mod is not None) else None;
}

"""Lay out a package whose seed module imports one in-package helper."""
def _seed_pkg(tmp: str) -> tuple[str, str] {
    _write(tmp, os.path.join("pkg", "__init__.py"), "");
    seed = _write(tmp, os.path.join("pkg", "model.py"), SEED_SRC);
    dep = _write(tmp, os.path.join("pkg", "util.py"), DEP_SRC);
    return (seed, dep);
}

test "an importer claims its dependency with no scope configured" {
    # The dependency holds no entry of its own; it is claimed only because the
    # seed that imports it is compiled first.
    with tempfile.TemporaryDirectory() as tmp {
        (seed, dep) = _seed_pkg(tmp);
        prog = JacProgram();
        seed_src = _src(prog, seed);
        assert os.path.realpath(seed) in prog.graphmend_claimed , (
            "the seed must claim itself"
        );
        assert os.path.realpath(dep) in prog.graphmend_claimed , (
            "an eager in-package import of a seed must be claimed"
        );
        dep_src = _src(prog, dep);
        assert "__jac_se_emit__(print," in dep_src , (
            "the claimed dependency was not transformed"
        );
    }
}

glob TC_SEED_SRC = '''
import torch

from typing import TYPE_CHECKING

from .eager import eager_helper

if TYPE_CHECKING:
    from .typeonly import TypeOnly


class Net(torch.nn.Module):
    def forward(self, x):
        return eager_helper(torch.relu(x))
''',
     PLAIN_DEP_SRC = '''
import torch


def eager_helper(x):
    print("EAGER", x)
    return x * 2
''',
     TYPE_ONLY_SRC = '''
import torch


class TypeOnly:
    pass
''';

test "a type-checking guarded import does not extend the claim" {
    # Type-only edges never run, and a package hub carries enough of them to
    # pull in the whole package.
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, os.path.join("pkg", "__init__.py"), "");
        seed = _write(tmp, os.path.join("pkg", "model.py"), TC_SEED_SRC);
        eager = _write(tmp, os.path.join("pkg", "eager.py"), PLAIN_DEP_SRC);
        type_only = _write(tmp, os.path.join("pkg", "typeonly.py"), TYPE_ONLY_SRC);
        prog = JacProgram();
        _src(prog, seed);
        assert os.path.realpath(eager) in prog.graphmend_claimed , (
            "an eager import must still be claimed"
        );
        assert os.path.realpath(type_only) not in prog.graphmend_claimed , (
            "a TYPE_CHECKING-guarded import must not extend the claim"
        );
    }
}

glob OUTSIDE_SEED_SRC = '''
import torch

import otherpkg.thing

from .util import reachable_helper


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''',
     OUTSIDE_SRC = '''
def thing(x):
    print("OUTSIDE", x)
    return x
''';

test "the claim stops at the seeding module's top level package" {
    # Without this bound the closure follows every module-level third-party
    # import.
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, os.path.join("pkg", "__init__.py"), "");
        seed = _write(tmp, os.path.join("pkg", "model.py"), OUTSIDE_SEED_SRC);
        _write(tmp, os.path.join("pkg", "util.py"), DEP_SRC);
        _write(tmp, os.path.join("otherpkg", "__init__.py"), "");
        outside = _write(tmp, os.path.join("otherpkg", "thing.py"), OUTSIDE_SRC);
        prog = JacProgram();
        _src(prog, seed);
        assert os.path.realpath(outside) not in prog.graphmend_claimed , (
            "the closure must not leave the seeding module's top-level package"
        );
    }
}

glob NOT_A_MODULE_SRC = '''
import torch


class Bookkeeper:
    def forward(self, x):
        if x.sum() > 0:
            y = x * 2.0
        else:
            y = x * 3.0
        return y
''';

test "a plain class with a forward method is not a seed" {
    # The seed proof is the base binding, never the name.
    with tempfile.TemporaryDirectory() as tmp {
        path = _write(tmp, "bookkeeper.py", NOT_A_MODULE_SRC);
        prog = JacProgram();
        src = _src(prog, path);
        assert os.path.realpath(path) not in prog.graphmend_claimed , (
            "a class that only spells forward must not seed GraphMend"
        );
        assert "torch.where(" not in src;
        assert "if x.sum() > 0" in src;
    }
}

glob GUARD_ENTRY_SRC = '''
import torch

from .checks import verify


class Net(torch.nn.Module):
    def forward(self, x, mask):
        verify(mask)
        return torch.relu(x)
''',
     GUARD_WRAP_ENTRY_SRC = '''
import torch

from .checks import verify


class Net(torch.nn.Module):
    def forward(self, x, mask):
        verify(mask)
        return torch.relu(x)


model = torch.compile(Net())
''',
     GUARD_DEP_SRC = '''
import torch


def verify(mask: torch.Tensor):
    if not mask.all():
        raise ValueError("mask must be all true")
''';

"""Compile the importer, then its guard-holding dependency; return the
dependency's generated source."""
def _guard_pkg_src(tmp: str, entry_src: str) -> str {
    _write(tmp, os.path.join("pkg", "__init__.py"), "");
    `entry = _write(tmp, os.path.join("pkg", "entry.py"), entry_src);
    checks = _write(tmp, os.path.join("pkg", "checks.py"), GUARD_DEP_SRC);
    prog = JacProgram();
    _src(prog, `entry);
    return _src(prog, checks);
}

test "a guard with no boundary in reach declines instead of marking" {
    # Only the trap boundary decodes the marker, and nothing here is wrapped or
    # decorated, so lowering would surface the raw marker text to the caller.
    with tempfile.TemporaryDirectory() as tmp {
        dep_src = _guard_pkg_src(tmp, GUARD_ENTRY_SRC);
        assert "torch._assert_async(" not in dep_src , (
            "a guard with no boundary must not emit an undecodable marker"
        );
        assert "raise ValueError" in dep_src;
        assert "GM-TRAP" not in dep_src;
    }
}

test "a guard lowers once the importer wraps the model at a call site" {
    # The wrap assignment carries the boundary that decodes the marker at the
    # outermost eager frame.
    with tempfile.TemporaryDirectory() as tmp {
        dep_src = _guard_pkg_src(tmp, GUARD_WRAP_ENTRY_SRC);
        assert (
            "torch._assert_async(mask.all(), "
            "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
            in dep_src
        );
        assert "raise ValueError" not in dep_src;
    }
}

glob WRAP_ENTRY_SRC = '''
import torch

from .net import Net

model = torch.compile(Net())
''',
     WRAP_NET_SRC = '''
import torch


def scale(x):
    print("SCALE", x)
    return x * 2


class Net(torch.nn.Module):
    def forward(self, x, mask: torch.Tensor):
        if not mask.all():
            raise ValueError("mask must be all true")
        return scale(torch.relu(x))
''';

test "an imported class wrapped at the importer's call site registers as an entry" {
    # Users import their model class and wrap it, so the entry has to resolve
    # through the import binding; a symbol-table lookup alone lands on the
    # import and registers nothing at all.
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, os.path.join("pkg", "__init__.py"), "");
        `entry = _write(tmp, os.path.join("pkg", "entry.py"), WRAP_ENTRY_SRC);
        net = _write(tmp, os.path.join("pkg", "net.py"), WRAP_NET_SRC);
        prog = JacProgram();
        _src(prog, `entry);
        entry_facts = _mod_facts(prog, `entry);
        assert (entry_facts is not None) and entry_facts.wrapped_keys , (
            "the cross-module wrap registered no entry"
        );
        net_src = _src(prog, net);
        assert "__jac_se_emit__(print," in net_src , (
            "the wrapped forward's call chain was not transformed"
        );
        assert "torch._assert_async(mask.all(), " in net_src , (
            "the importer's boundary does not cover the guard"
        );
    }
}

glob CHAIN_ENTRY_SRC = '''
import torch

from .net import Net

model = torch.compile(Net())
''',
     CHAIN_NO_WRAP_SRC = '''
import torch

from .net import Net

model = Net()
''',
     CHAIN_NET_SRC = '''
import torch

from .deep import verify


class Net(torch.nn.Module):
    def forward(self, x, mask):
        verify(mask)
        return torch.relu(x)
''',
     CHAIN_DEEP_SRC = '''
import torch


def verify(mask: torch.Tensor):
    if not mask.all():
        raise ValueError("mask must be all true")
''';

"""Lay out entry -> net -> deep, compile importer-first, and return the deep
module's generated source together with its facts carrier."""
def _chain_src(tmp: str, entry_src: str) -> tuple[str, any] {
    _write(tmp, os.path.join("pkg", "__init__.py"), "");
    `entry = _write(tmp, os.path.join("pkg", "entry.py"), entry_src);
    _write(tmp, os.path.join("pkg", "net.py"), CHAIN_NET_SRC);
    deep = _write(tmp, os.path.join("pkg", "deep.py"), CHAIN_DEEP_SRC);
    prog = JacProgram();
    _src(prog, `entry);
    deep_src = _src(prog, deep);
    return (deep_src, _mod_facts(prog, deep));
}

test "a guard two hops down the claim chain lowers under the entry's wrap" {
    # The guard's module is claimed through the model module, which is claimed
    # through the entry; the wrap at the entry is what decodes its marker.
    with tempfile.TemporaryDirectory() as tmp {
        (deep_src, facts) = _chain_src(tmp, CHAIN_ENTRY_SRC);
        assert (
            "torch._assert_async(mask.all(), "
            "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
            in deep_src
        );
        assert facts is not None;
        covering = [
            `entry
            for (guard, `entry) in facts.covered_by.items()
            if str(guard).endswith("::verify")
        ];
        assert covering , "no covering entry was recorded for the guard";
        assert covering[0].endswith("::Net.forward") , (
            f"unexpected covering entry: {covering[0]}"
        );
    }
}

test "the same guard declines when the entry does not wrap the model" {
    # Identical claim chain, no torch.compile anywhere: nothing would decode
    # the marker, so the derivation must not invent a boundary.
    with tempfile.TemporaryDirectory() as tmp {
        (deep_src, facts) = _chain_src(tmp, CHAIN_NO_WRAP_SRC);
        assert "torch._assert_async(" not in deep_src;
        assert "raise ValueError" in deep_src;
        assert (facts is None) or (not facts.covered_by) , (
            "no entry can cover anything in a program with no boundary"
        );
    }
}

glob FS_CALLS: list[str] = [],
     REAL_ISFILE = os.path.isfile,
     REAL_REALPATH = os.path.realpath;

"""Count and delegate an os.path.isfile call."""
def _counting_isfile(path: any) -> bool {
    FS_CALLS.append("isfile");
    return REAL_ISFILE(path);
}

"""Count and delegate an os.path.realpath call."""
def _counting_realpath(path: any, *args: any, **kwargs: any) -> any {
    FS_CALLS.append("realpath");
    return REAL_REALPATH(path, *args, **kwargs);
}

test "a torch-free import is answered without touching the filesystem" {
    # The torch gate sits above the syscalls: with nothing claimed and torch
    # unloaded the probe costs two membership tests, while a registered claim
    # is still honored once the set is non-empty.
    import sys;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.meta_importer { _graphmend_claims }
    import from jaclang.project.config { JacConfig }
    import jaclang.project.config as config_mod;
    prog = Jac.get_program();
    prev_claimed = set(prog.graphmend_claimed);
    old_config = config_mod._config;
    saved_torch = sys.modules.pop("torch", None);
    with tempfile.TemporaryDirectory() as tmp {
        path = _write(tmp, "thirdparty.py", "x = 1\n");
        real = REAL_REALPATH(path);
        FS_CALLS.clear();
        setattr(os.path, 'isfile', _counting_isfile);
        setattr(os.path, 'realpath', _counting_realpath);
        try {
            config_mod._config = JacConfig.from_toml_str(
                "[run]\ngraphmend_claim_imports = true\n"
            );
            prog.graphmend_claimed.clear();
            assert _graphmend_claims("thirdparty", path) is False;
            assert FS_CALLS == [] , (
                f"a torch-free import must not stat anything, saw {FS_CALLS}"
            );
            prog.graphmend_claimed.add(real);
            assert _graphmend_claims("thirdparty", path) is True , (
                "a registered claim must still be honored"
            );
            assert "realpath" in FS_CALLS , "the claimed lookup must still run";
        } finally {
            os.path.isfile = REAL_ISFILE;
            os.path.realpath = REAL_REALPATH;
            if saved_torch is not None {
                sys.modules["torch"] = saved_torch;
            }
            config_mod._config = old_config;
            cur = Jac.get_program();
            cur.graphmend_claimed.clear();
            cur.graphmend_claimed.update(prev_claimed);
        }
    }
}

test "the run manifest carries no graphmend scope argument" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("run");
    assert meta is not None;
    by_name = {a.name: a for a in meta.args};
    assert "graphmend_scope" not in by_name , (
        "claiming is automatic; there is no scope flag to configure"
    );
    assert by_name["graphmend_disable"].config_key == "run.graphmend_disable";
}
