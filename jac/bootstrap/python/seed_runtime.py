"""Load the embedded JacPython bytecode image without compiling source.

The native adapter supplies ``image`` and executes this precompiled module in
an interpreter-local namespace. Jac's public package remains available to the
ordinary importer; this private copy exists only to implement Python's APIs.
"""
import builtins
import sys
from _frozen_importlib import ModuleSpec

_prefix = "_jacpython_seed."
if "modules_by_optimization" in image:
    image["modules"] = image["modules_by_optimization"][sys.flags.optimize]
_original_import = builtins.__import__
_seed_builtins = dict(vars(builtins))


def _seed_import(name, globals=None, locals=None, fromlist=(), level=0):
    if level == 0 and (name == "jaclang" or name.startswith("jaclang.")):
        result = _original_import(_prefix + name, globals, locals, fromlist, 0)
        return result if fromlist else sys.modules[_prefix + "jaclang"]
    return _original_import(name, globals, locals, fromlist, level)


_seed_builtins["__import__"] = _seed_import


class _SeedLoader:
    def find_spec(self, fullname, path=None, target=None):
        if not fullname.startswith(_prefix):
            return None
        name = fullname[len(_prefix):]
        record = image["modules"].get(name)
        if record is None:
            raise ImportError("Missing JacPython seed module: " + name)
        spec = ModuleSpec(fullname, self, is_package=record[1])
        spec.origin = "<jacpython-seed/" + name.replace(".", "/") + ">"
        return spec

    def create_module(self, spec):
        return None

    def exec_module(self, module):
        code, package = image["modules"][module.__name__[len(_prefix):]]
        module.__file__ = module.__spec__.origin
        module.__builtins__ = _seed_builtins
        if code is not None:
            exec(code, module.__dict__)


__path__ = []
sys.meta_path.insert(0, _SeedLoader())
from _jacpython_seed.jaclang.compiler.backends.py.jacpython.code_object import compile_python
from _jacpython_seed.jaclang.compiler.frontend.python.compiler_symtable import mangle_name
from _jacpython_seed.jaclang.runtime.python.opcode_meta import stack_effect
from _jacpython_seed.jaclang.runtime.python.symtable import symtable
from _jacpython_seed.jaclang.runtime.python.tokenize import TokenizerIter

# Exercise the compiler's lazy imports before retiring the bootstrap lookup.
compile_python("pass", "<jacpython-seed-warmup>", "exec")
if not image.get("preparing", False):
    sys._jacpython_compile = compile_python
    sys._jacpython_symtable = symtable
    sys._jacpython_tokenize = TokenizerIter
    sys._jacpython_mangle = mangle_name
    sys._jacpython_stack_effect = stack_effect
