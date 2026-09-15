"""Inline a checked native uop and its ABI expressions into a JIT patch stencil.

The retained CPython relocation/patch machinery consumes the resulting object.
This build helper is not an interpreted execution path or a C-body fallback.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

root, native, template, output = (Path(value).resolve() for value in sys.argv[1:5])
symbol = sys.argv[5]
compile_args = json.loads(sys.argv[6])
sys.path.insert(0, str(root))
os.environ['JAC_NO_DEV_SOURCE'] = '1'
os.environ['JAC_COMPILER_LIB'] = 'off'
os.environ['JAC_STUBCAT_BUILDING'] = '1'
import jaclang
import jaclang.compiler.backends.native.llvm.binding as llvm
from jaclang.compiler.backends.native.shared_emit import (
    init_object_codegen, internalize_native_implementation,
)

init_object_codegen()
module = llvm.parse_assembly(template.read_text())
body = llvm.parse_assembly(native.read_text())
# The configured stencil target supplies the platform ABI and relocation model.
body.triple = module.triple
body.data_layout = module.data_layout
module.link_in(body)
module.get_function(symbol).add_function_attribute('alwaysinline')
internalize_native_implementation(module, ['_JIT_ENTRY'])
module.verify()
# Keep the stencil target's relocation constraints. In particular, upstream
# x86-64 ELF uses the medium model and absolute data references, whereas ARM64
# ELF and Mach-O use PIC. Function target attributes and module flags preserve
# the frontend's remaining architecture settings through the IR link.
relocation = 'pic' if 'apple' in module.triple else 'static'
code_model = 'small'
for argument in compile_args:
    if argument in {'-fpic', '-fPIC', '-fpie', '-fPIE'}:
        relocation = 'pic'
    elif argument in {'-fno-pic', '-fno-PIC', '-fno-pie', '-fno-PIE'}:
        relocation = 'static'
    elif argument.startswith('-mcmodel='):
        code_model = argument.split('=', 1)[1]
machine = llvm.Target.from_triple(module.triple).create_target_machine(
    opt=3, reloc=relocation, codemodel=code_model,
)
with llvm.create_pipeline_tuning_options(speed_level=3) as tuning:
    with llvm.create_pass_builder(machine, tuning) as passes:
        with passes.getModulePassManager() as manager:
            manager.run(module, passes)
module.verify()
for function in module.functions:
    if function.name == symbol or function.name.startswith(('jacpy_abi_', 'jacpy_config_', '__jac_')):
        raise RuntimeError('Native JIT body or adapter did not inline: ' + function.name)
output.write_bytes(machine.emit_object(module))
# Per-stencil records are independent files; concurrent builds never update one
# shared manifest. The caller folds these records into the stencil provenance.
output.with_suffix('.provenance.json').write_text(json.dumps({
    'native_ir_sha256': hashlib.sha256(native.read_bytes()).hexdigest(),
    'abi_ir_sha256': hashlib.sha256(template.read_bytes()).hexdigest(),
    'optimized_ir_sha256': hashlib.sha256(str(module).encode()).hexdigest(),
    'object_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'body': symbol, 'entry': '_JIT_ENTRY', 'calling_convention': 'preserve_none',
    'relocation_model': relocation, 'code_model': code_model,
}, sort_keys=True) + '\n')
sys.stdout.flush()
sys.stderr.flush()
os._exit(0)
