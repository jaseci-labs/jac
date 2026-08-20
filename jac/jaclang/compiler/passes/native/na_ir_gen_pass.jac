import from jaclang.compiler.passes.native.na_ir_gen.arena { NaIRGenArena }
import from jaclang.compiler.passes.native.na_ir_gen.builtins { NaIRGenBuiltins }
import from jaclang.compiler.passes.native.na_ir_gen.bytearray_na { NaIRGenBytearrayNa }
import from jaclang.compiler.passes.native.na_ir_gen.bytes { NaIRGenBytes }
import from jaclang.compiler.passes.native.na_ir_gen.calls { NaIRGenCalls }
import from jaclang.compiler.passes.native.na_ir_gen.clib_abi { NaIRGenClibAbi }
import from jaclang.compiler.passes.native.na_ir_gen.clib_vtable { NaIRGenClibVtable }
import from jaclang.compiler.passes.native.na_ir_gen.closures { NaIRGenClosures }
import from jaclang.compiler.passes.native.na_ir_gen.comprehensions {
    NaIRGenComprehensions
}
import from jaclang.compiler.passes.native.na_ir_gen.container_helpers {
    NaIRGenContainerHelpers
}
import from jaclang.compiler.passes.native.na_ir_gen.context_mgr { NaIRGenContextMgr }
import from jaclang.compiler.passes.native.na_ir_gen.core { NaIRGenCore }
import from jaclang.compiler.passes.native.na_ir_gen.cycle_collector {
    NaIRGenCycleCollector
}
import from jaclang.compiler.passes.native.na_ir_gen.debug { NaIRGenDebug }
import from jaclang.compiler.passes.native.na_ir_gen.dicts { NaIRGenDicts }
import from jaclang.compiler.passes.native.na_ir_gen.enums { NaIRGenEnums }
import from jaclang.compiler.passes.native.na_ir_gen.exceptions { NaIRGenExceptions }
import from jaclang.compiler.passes.native.na_ir_gen.expr { NaIRGenExpr }
import from jaclang.compiler.passes.native.na_ir_gen.file_io { NaIRGenFileIo }
import from jaclang.compiler.passes.native.na_ir_gen.fmt { NaIRGenFmt }
import from jaclang.compiler.passes.native.na_ir_gen.func { NaIRGenFunc }
import from jaclang.compiler.passes.native.na_ir_gen.gc_debug { NaIRGenGcDebug }
import from jaclang.compiler.passes.native.na_ir_gen.generics { NaIRGenGenerics }
import from jaclang.compiler.passes.native.na_ir_gen.globals { NaIRGenGlobals }
import from jaclang.compiler.passes.native.na_ir_gen.hash_core { NaIRGenHashCore }
import from jaclang.compiler.passes.native.na_ir_gen.iterators { NaIRGenIterators }
import from jaclang.compiler.passes.native.na_ir_gen.lists { NaIRGenLists }
import from jaclang.compiler.passes.native.na_ir_gen.math { NaIRGenMath }
import from jaclang.compiler.passes.native.na_ir_gen.objects { NaIRGenObjects }
import from jaclang.compiler.passes.native.na_ir_gen.os { NaIRGenOs }
import from jaclang.compiler.passes.native.na_ir_gen.osp { NaIRGenOsp }
import from jaclang.compiler.passes.native.na_ir_gen.pyb_interop { NaIRGenPybInterop }
import from jaclang.compiler.passes.native.na_ir_gen.random { NaIRGenRandom }
import from jaclang.compiler.passes.native.na_ir_gen.refcount { NaIRGenRefcount }
import from jaclang.compiler.passes.native.na_ir_gen.repr { NaIRGenRepr }
import from jaclang.compiler.passes.native.na_ir_gen.sets { NaIRGenSets }
import from jaclang.compiler.passes.native.na_ir_gen.stmt { NaIRGenStmt }
import from jaclang.compiler.passes.native.na_ir_gen.struct { NaIRGenStruct }
import from jaclang.compiler.passes.native.na_ir_gen.time { NaIRGenTime }
import from jaclang.compiler.passes.native.na_ir_gen.trace_fn { NaIRGenTraceFn }
import from jaclang.compiler.passes.native.na_ir_gen.tuples { NaIRGenTuples }
import from jaclang.compiler.passes.native.na_ir_gen.types { NaIRGenTypes }
import from jaclang.compiler.passes.native.na_ir_gen.vtable { NaIRGenVtable }

obj NaIRGenPass(NaIRGenArena, NaIRGenBuiltins, NaIRGenBytearrayNa, NaIRGenBytes, NaIRGenCalls, NaIRGenClibAbi, NaIRGenClibVtable, NaIRGenClosures, NaIRGenComprehensions, NaIRGenContainerHelpers, NaIRGenContextMgr, NaIRGenCore, NaIRGenCycleCollector, NaIRGenDebug, NaIRGenDicts, NaIRGenEnums, NaIRGenExceptions, NaIRGenExpr, NaIRGenFileIo, NaIRGenFmt, NaIRGenFunc, NaIRGenGcDebug, NaIRGenGenerics, NaIRGenGlobals, NaIRGenHashCore, NaIRGenIterators, NaIRGenLists, NaIRGenMath, NaIRGenObjects, NaIRGenOs, NaIRGenOsp, NaIRGenPybInterop, NaIRGenRandom, NaIRGenRefcount, NaIRGenRepr, NaIRGenSets, NaIRGenStmt, NaIRGenStruct, NaIRGenTime, NaIRGenTraceFn, NaIRGenTuples, NaIRGenTypes, NaIRGenVtable) {
    static has REQUIRES: tuple = (
        'inference',
        'cfg',
        'ownership',
        'capability',
        'rc-facts'
    );
}
