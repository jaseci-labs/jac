import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.native_iface { NativeIface, NativeExport }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;
import from jaclang.runtime.scalars { ScalarShape }

import from jaclang.compiler.frontend.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_MAGIC_SHIFT_BASE,
    HDR_RC_OFF,
    HDR_TAG_OFF,
    HDR_TOTAL,
    JACSTR_DESC_FIELDS,
    NativeFuncLayout,
    RC_SENTINEL,
    is_package_keyed_path,
    native_unit_identity,
    str_len_tag,
    STR_LEN_TAG_BIT,
    STR_LEN_TAG_SHIFT
}
import from jaclang.compiler.frontend.constant {
    CodeContext,
    OwnershipKind,
    SymbolAccess,
    Tokens as Tok
}
import from jaclang.compiler.frontend.diagnostics {
    DiagnosticInfo,
    E5026,
    E5060,
    E5088,
    E5089,
    E5090,
    E5091,
    E5092,
    E5095,
    E9001,
    E9002
}
import from jaclang.compiler.intrinsic_registry { IntrinsicEntry }
import from jaclang.compiler.passes.layout_pass {
    accessor_slot_name,
    ACCESSOR_SLOT_SUFFIX,
    archetype_accessors,
    ArchetypeLayout,
    EnumLayout,
    VTABLE_HEADER_SLOTS
}
import from jaclang.compiler.type_registry { JacTypeEntry }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.types.types {
    ClassType,
    ModuleType,
    Parameter,
    TypeBase,
    UnionType,
    FunctionType as SemanticFunctionType
}
import from jaclang.compiler.frontend.const_fold { fold_const }
import from jaclang.compiler.types.ct_value {
    CtBool,
    CtBytes,
    CtFloat,
    CtInt,
    CtNone,
    CtStr,
    CtValue,
    ct_iter,
    ct_mangle,
    ct_truthy
}
import type from jaclang.compiler.types.ct_eval { CtEvaluator }
import type from jaclang.compiler.passes.osp_analysis { OspSlot }
import from jaclang.runtime.osp_tag { stable_osp_tag }
import from jaclang.compiler.backends.native.na_constants {
    CLASS_DISPLAY_OFF,
    EXC_LINEAGE_BITS,
    EXC_LINEAGE_MIX,
    EXC_LINEAGE_SLOTS,
    JACVAL_ELLIPSIS_TAG,
    LIVE_NODE_NEXT_OFF,
    LIVE_NODE_RC_OFF,
    LIVE_NODE_SIZE,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_USER_OFF,
    NATIVE_CONTAINER_CODES,
    NATIVE_COPY_FUNCS,
    NATIVE_OS_FUNCS,
    NATIVE_OSPATH_FUNCS,
    NATIVE_RANDOM_FUNCS,
    NATIVE_STRUCT_FUNCS,
    RC_BUFFERED_BIT,
    RC_COLOR_BLACK,
    RC_COLOR_GRAY,
    RC_COLOR_PURPLE,
    RC_COLOR_SHIFT,
    RC_COLOR_WHITE,
    RC_CYCLE_PACE,
    RC_CYCLE_THRESHOLD,
    RC_UNTRACED_BIT
}

obj NativeLowering {
    has module: uni.Module,
        prog: JacProgram,
        ctx: CompileContext;

    def emit(
        diag: DiagnosticInfo,
        node_override: (uni.UniNode | None) = None,
        related: (list[tuple[str, uni.UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;
}

glob _READY: dict[int, NativeLowering] = {};

def take_native_lowering(
    module: uni.Module, prog: JacProgram, ctx: CompileContext
) -> NativeLowering;

walker NaLowerAnalysisPass(CompilerPass) {
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
}
