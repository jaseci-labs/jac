"""Link native evaluator IR with its target-configured C ABI expressions.

Invoked by the candidate build after CPython configure, never by the source
migration editor. Whole-module optimization removes expression-adapter calls
before object emission, including on Mach-O targets without linker LTO.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

root, artifacts = (Path(value).resolve() for value in sys.argv[1:3])
output = Path(sys.argv[3]).resolve()
adapters = [Path(value).resolve() for value in sys.argv[4:]]
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
module = llvm.parse_assembly((artifacts / 'evaluator_entry.ll').read_text())
exports = json.loads((artifacts / 'evaluator_entry.exports.json').read_text())
for adapter in adapters:
    module.link_in(llvm.parse_assembly(adapter.read_text()))
internalize_native_implementation(module, exports)
module.verify()
machine = llvm.Target.from_triple(module.triple).create_target_machine(
    opt=3, reloc='pic', codemodel='small',
)
with llvm.create_pipeline_tuning_options(speed_level=3) as tuning:
    with llvm.create_pass_builder(machine, tuning) as passes:
        with passes.getModulePassManager() as manager:
            manager.run(module, passes)
module.verify()
# These symbols are specific to generated ABI expressions. Runtime API calls
# stay external, but an expression thunk must never survive into dispatch.
for function in module.functions:
    if function.name.startswith(('jacpy_abi_', 'jacpy_config_')):
        raise RuntimeError('Evaluator adapter did not inline: ' + function.name)
    if function.name.startswith('__jac_'):
        raise RuntimeError('Evaluator retains Jac runtime machinery: ' + function.name)
code = machine.emit_object(module)
output.write_bytes(code)
(artifacts / 'evaluator_entry.sha256').write_text(hashlib.sha256(code).hexdigest() + '\n')
provenance_path = artifacts / 'evaluator-provenance.json'
provenance = json.loads(provenance_path.read_text())
unit = next(unit for unit in provenance['units'] if unit['object'] == 'evaluator_entry.o')
unit['object_sha256'] = hashlib.sha256(code).hexdigest()
unit['optimized_ir_sha256'] = hashlib.sha256(str(module).encode()).hexdigest()
unit['abi_ir_inputs'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in adapters}
unit['emission'] = 'native Jac and target-configured ABI IR linked before optimization'
provenance_path.write_text(json.dumps(provenance, indent=2, sort_keys=True) + '\n')
# Avoid compiler graph teardown in this completed build helper.
sys.stdout.flush()
sys.stderr.flush()
os._exit(0)
