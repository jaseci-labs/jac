import from ctypes { c_bool, c_int, c_size_t, POINTER, Structure, byref, c_char_p }
import from collections { namedtuple }
import from enum { IntFlag }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
def create_new_module_pass_manager() -> object {
    return ModulePassManager();
}
def create_new_function_pass_manager() -> object {
    return FunctionPassManager();
}
def create_pass_builder(tm: Any, pto: Any) -> object {
    return PassBuilder(tm, pto);
}
def create_pipeline_tuning_options(
    speed_level: Any = 2, size_level: Any = 0
) -> object {
    return PipelineTuningOptions(speed_level, size_level);
}
with entry {
    _prunestats = namedtuple('PruneStats', 'basicblock diamond fanout fanout_raise');
}
""" Holds statistics from reference count pruning.
    """
class PruneStats(_prunestats) {
    def __add__(self: PruneStats, other: Any) -> object {
        if not isinstance(other, PruneStats) {
            msg = 'PruneStats can only be added to another PruneStats, got {}.';
            raise TypeError(msg.format(`type(other)));
        }
        return PruneStats(
            (self.basicblock + other.basicblock),
            (self.diamond + other.diamond),
            (self.fanout + other.fanout),
            (self.fanout_raise + other.fanout_raise)
        );
    }
    def __sub__(self: PruneStats, other: Any) -> object {
        if not isinstance(other, PruneStats) {
            msg = 'PruneStats can only be subtracted from another PruneStats, '
            'got {}.';
            raise TypeError(msg.format(`type(other)));
        }
        return PruneStats(
            (self.basicblock - other.basicblock),
            (self.diamond - other.diamond),
            (self.fanout - other.fanout),
            (self.fanout_raise - other.fanout_raise)
        );
    }
}

class _c_PruneStats(Structure) {
    with entry {
        _fields_ = [
            ('basicblock', c_size_t),
            ('diamond', c_size_t),
            ('fanout', c_size_t),
            ('fanout_raise', c_size_t)
        ];
    }
}
""" Returns a namedtuple containing the current values for the refop pruning
    statistics. If kwarg `printout` is True the stats are printed to stderr,
    default is False.
    """
def dump_refprune_stats(printout: Any = False) -> object {
    stats = _c_PruneStats(0, 0, 0, 0);
    do_print = c_bool(printout);
    ffi.lib.LLVMPY_DumpRefPruneStats(byref(stats), do_print);
    return PruneStats(
        stats.basicblock, stats.diamond, stats.fanout, stats.fanout_raise
    );
}

"""Enable or disable the pass timers.

    Parameters
    ----------
    enable : bool
        Set to True to enable the pass timers.
        Set to False to disable the pass timers.
    """
def set_time_passes(enable: Any) -> object {
    ffi.lib.LLVMPY_SetTimePasses(c_bool(enable));
}

"""Returns the pass timings report and resets the LLVM internal timers.

    Pass timers are enabled by ``set_time_passes()``. If the timers are not
    enabled, this function will return an empty string.

    Returns
    -------
    res : str
        LLVM generated timing report.
    """
def report_and_reset_timings() -> object {
    with ffi.OutputString() as buf {
        ffi.lib.LLVMPY_ReportAndResetTimings(buf);
        return str(buf);
    }
}

class RefPruneSubpasses(IntFlag) {
    with entry {
        PER_BB = 1;
        DIAMOND = 2;
        FANOUT = 4;
        FANOUT_RAISE = 8;
        ALL = PER_BB | DIAMOND | FANOUT | FANOUT_RAISE;
    }
}
class NewPassManager {
    def init(self: NewPassManager) -> object {
        if (`type(self) is NewPassManager) {
            raise TypeError("Cannot instantiate NewPassManager directly");
        }
    }
    def run(self: NewPassManager, IR: Any, pb: Any) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_RunNewModulePassManager(self, IR, pb);
        } else {
            ffi.lib.LLVMPY_RunNewFunctionPassManager(self, IR, pb);
        }
    }
    def add_aa_eval_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddAAEvaluator(self);
        } else {
            ffi.lib.LLVMPY_function_AddAAEvaluator(self);
        }
    }
    def add_simplify_cfg_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddSimplifyCFGPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddSimplifyCFGPass(self);
        }
    }
    def add_loop_unroll_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopUnrollPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopUnrollPass(self);
        }
    }
    def add_instruction_combine_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddInstCombinePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddInstCombinePass(self);
        }
    }
    def add_jump_threading_pass(self: NewPassManager, threshold: Any = -1) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_AddJumpThreadingPass_module(self, threshold);
        } else {
            ffi.lib.LLVMPY_AddJumpThreadingPass_function(self, threshold);
        }
    }
    def add_cfg_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddCFGPrinterPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddCFGPrinterPass(self);
        }
    }
    def add_cfg_only_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddCFGOnlyPrinterPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddCFGOnlyPrinterPass(self);
        }
    }
    def add_dom_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDomPrinter(self);
        } else {
            ffi.lib.LLVMPY_function_AddDomPrinter(self);
        }
    }
    def add_dom_only_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDomOnlyPrinter(self);
        } else {
            ffi.lib.LLVMPY_function_AddDomOnlyPrinter(self);
        }
    }
    def add_post_dom_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddPostDomPrinter(self);
        } else {
            ffi.lib.LLVMPY_function_AddPostDomPrinter(self);
        }
    }
    def add_post_dom_only_printer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddPostDomOnlyPrinter(self);
        } else {
            ffi.lib.LLVMPY_function_AddPostDomOnlyPrinter(self);
        }
    }
    def add_dom_viewer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDomViewer(self);
        } else {
            ffi.lib.LLVMPY_function_AddDomViewer(self);
        }
    }
    def add_dom_only_viewer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDomOnlyViewer(self);
        } else {
            ffi.lib.LLVMPY_function_AddDomOnlyViewer(self);
        }
    }
    def add_post_dom_viewer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddPostDomViewer(self);
        } else {
            ffi.lib.LLVMPY_function_AddPostDomViewer(self);
        }
    }
    def add_post_dom_only_viewer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddPostDomOnlyViewer(self);
        } else {
            ffi.lib.LLVMPY_function_AddPostDomOnlyViewer(self);
        }
    }
    def add_lint_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLintPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLintPass(self);
        }
    }
    def add_aggressive_dce_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddADCEPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddADCEPass(self);
        }
    }
    def add_break_critical_edges_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddBreakCriticalEdgesPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddBreakCriticalEdgesPass(self);
        }
    }
    def add_dead_store_elimination_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDSEPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddDSEPass(self);
        }
    }
    def add_dead_code_elimination_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddDCEPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddDCEPass(self);
        }
    }
    def add_aggressive_instcombine_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddAggressiveInstCombinePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddAggressiveInstCombinePass(self);
        }
    }
    def add_lcssa_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLCSSAPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLCSSAPass(self);
        }
    }
    def add_new_gvn_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddNewGVNPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddNewGVNPass(self);
        }
    }
    def add_loop_simplify_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopSimplifyPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopSimplifyPass(self);
        }
    }
    def add_loop_unroll_and_jam_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopUnrollAndJamPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopUnrollAndJamPass(self);
        }
    }
    def add_sccp_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddSCCPPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddSCCPPass(self);
        }
    }
    def add_lower_atomic_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLowerAtomicPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLowerAtomicPass(self);
        }
    }
    def add_lower_invoke_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLowerInvokePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLowerInvokePass(self);
        }
    }
    def add_lower_switch_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLowerSwitchPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLowerSwitchPass(self);
        }
    }
    def add_mem_copy_opt_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddMemCpyOptPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddMemCpyOptPass(self);
        }
    }
    def add_unify_function_exit_nodes_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddUnifyFunctionExitNodesPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddUnifyFunctionExitNodesPass(self);
        }
    }
    def add_reassociate_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddReassociatePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddReassociatePass(self);
        }
    }
    def add_register_to_memory_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddRegToMemPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddRegToMemPass(self);
        }
    }
    def add_sroa_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddSROAPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddSROAPass(self);
        }
    }
    def add_sinking_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddSinkingPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddSinkingPass(self);
        }
    }
    def add_tail_call_elimination_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddTailCallElimPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddTailCallElimPass(self);
        }
    }
    def add_instruction_namer_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddInstructionNamerPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddInstructionNamerPass(self);
        }
    }
    def add_loop_deletion_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopDeletionPass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopDeletionPass(self);
        }
    }
    def add_loop_strength_reduce_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopStrengthReducePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopStrengthReducePass(self);
        }
    }
    def add_loop_rotate_pass(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_module_AddLoopRotatePass(self);
        } else {
            ffi.lib.LLVMPY_function_AddLoopRotatePass(self);
        }
    }
    def _dispose(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_DisposeNewModulePassManger(self);
        } else {
            ffi.lib.LLVMPY_DisposeNewFunctionPassManger(self);
        }
    }
}
class ModulePassManager(ffi.ObjectRef, NewPassManager) {
    def init(self: ModulePassManager, ptr: Any = None) -> object {
        if (ptr is None) {
            ptr = ffi.lib.LLVMPY_CreateNewModulePassManager();
        }
        super.init(ptr);
    }
    def add_verifier(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddVerifierPass(self);
    }
    def add_constant_merge_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddConstantMergePass(self);
    }
    def add_dead_arg_elimination_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddDeadArgumentEliminationPass(self);
    }
    def add_dot_call_graph_printer_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddCallGraphDOTPrinterPass(self);
    }
    def add_module_debug_info_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddModuleDebugInfoPrinterPass(self);
    }
    def add_always_inliner_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddAlwaysInlinerPass(self);
    }
    def add_rpo_function_attrs_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddReversePostOrderFunctionAttrsPass(self);
    }
    def add_global_dead_code_eliminate_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddGlobalDCEPass(self);
    }
    def add_global_opt_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddGlobalOptPass(self);
    }
    def add_ipsccp_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddIPSCCPPass(self);
    }
    def add_internalize_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddInternalizePass(self);
    }
    def add_loop_extract_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddLoopExtractorPass(self);
    }
    def add_merge_functions_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddMergeFunctionsPass(self);
    }
    def add_partial_inliner_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddPartialInlinerPass(self);
    }
    def add_strip_symbols_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddStripSymbolsPass(self);
    }
    def add_strip_dead_debug_info_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddStripDeadDebugInfoPass(self);
    }
    def add_strip_dead_prototype_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddStripDeadPrototypesPass(self);
    }
    def add_strip_debug_declare_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddStripDebugDeclarePass(self);
    }
    def add_strip_non_debug_symbols_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddStripNonDebugSymbolsPass(self);
    }
    def add_argument_promotion_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddArgumentPromotionPass(self);
    }
    def add_post_order_function_attributes_pass(self: ModulePassManager) -> object {
        ffi.lib.LLVMPY_module_AddPostOrderFunctionAttrsPass(self);
    }
    """Add Numba specific Reference count pruning pass.

        Parameters
        ----------
        subpasses_flags : RefPruneSubpasses
            A bitmask to control the subpasses to be enabled.
        subgraph_limit : int
            Limit the fanout pruners to working on a subgraph no bigger than
            this number of basic-blocks to avoid spending too much time in very
            large graphs. Default is 1000. Subject to change in future
            versions.
        """
    def add_refprune_pass(
        self: ModulePassManager,
        subpasses_flags: Any = RefPruneSubpasses.ALL,
        subgraph_limit: Any = 1000
    ) -> object {
        iflags = RefPruneSubpasses(subpasses_flags);
        ffi.lib.LLVMPY_AddRefPrunePass_module(self, iflags, subgraph_limit);
    }
}

class FunctionPassManager(ffi.ObjectRef, NewPassManager) {
    def init(self: FunctionPassManager, ptr: Any = None) -> object {
        if (ptr is None) {
            ptr = ffi.lib.LLVMPY_CreateNewFunctionPassManager();
        }
        super.init(ptr);
    }
    """Add Numba specific Reference count pruning pass.

        Parameters
        ----------
        subpasses_flags : RefPruneSubpasses
            A bitmask to control the subpasses to be enabled.
        subgraph_limit : int
            Limit the fanout pruners to working on a subgraph no bigger than
            this number of basic-blocks to avoid spending too much time in very
            large graphs. Default is 1000. Subject to change in future
            versions.
        """
    def add_refprune_pass(
        self: FunctionPassManager,
        subpasses_flags: Any = RefPruneSubpasses.ALL,
        subgraph_limit: Any = 1000
    ) -> object {
        iflags = RefPruneSubpasses(subpasses_flags);
        ffi.lib.LLVMPY_AddRefPrunePass_function(self, iflags, subgraph_limit);
    }
}

class PipelineTuningOptions(ffi.ObjectRef) {
    def init(
        self: PipelineTuningOptions, speed_level: Any = 2, size_level: Any = 0
    ) -> object {
        self._speed_level = None;
        self._size_level = None;
        self.speed_level = speed_level;
        self.size_level = size_level;
        super.init(ffi.lib.LLVMPY_CreatePipelineTuningOptions());
    }
    @property
    def speed_level(self: PipelineTuningOptions) -> object {
        return self._speed_level;
    }
    @speed_level.setter
    def speed_level(self: PipelineTuningOptions, value: Any) -> object {
        if not (0 <= value <= 3) {
            raise ValueError("Optimization level for speed should be 0, 1, 2, or 3");
        }
        self._speed_level = value;
    }
    @property
    def size_level(self: PipelineTuningOptions) -> object {
        return self._size_level;
    }
    @size_level.setter
    def size_level(self: PipelineTuningOptions, value: Any) -> object {
        if not (0 <= value <= 2) {
            raise ValueError("Optimization level for size should be 0, 1, or 2");
        }
        if ((value != 0) and (self.speed_level != 2)) {
            raise ValueError(
                "Optimization for size should be encoded with speed level == 2"
            );
        }
        self._size_level = value;
    }
    @property
    def loop_interleaving(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopInterleaving(self);
    }
    @loop_interleaving.setter
    def loop_interleaving(self: PipelineTuningOptions, value: Any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopInterleaving(self, value);
    }
    @property
    def loop_vectorization(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopVectorization(self);
    }
    @loop_vectorization.setter
    def loop_vectorization(self: PipelineTuningOptions, value: Any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopVectorization(self, value);
    }
    @property
    def slp_vectorization(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetSLPVectorization(self);
    }
    @slp_vectorization.setter
    def slp_vectorization(self: PipelineTuningOptions, value: Any) -> object {
        ffi.lib.LLVMPY_PTOSetSLPVectorization(self, value);
    }
    @property
    def loop_unrolling(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopUnrolling(self);
    }
    @loop_unrolling.setter
    def loop_unrolling(self: PipelineTuningOptions, value: Any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopUnrolling(self, value);
    }
    @property
    def inlining_threshold(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetInlinerThreshold(self);
    }
    @inlining_threshold.setter
    def inlining_threshold(self: PipelineTuningOptions, value: Any) -> object {
        ffi.lib.LLVMPY_PTOSetInlinerThreshold(self, value);
    }
    def _dispose(self: PipelineTuningOptions) -> object {
        ffi.lib.LLVMPY_DisposePipelineTuningOptions(self);
    }
}
class TimePassesHandler(ffi.ObjectRef) {
    def init(self: TimePassesHandler) -> object {
        super.init(ffi.lib.LLVMPY_CreateTimePassesHandler());
    }
    def _dispose(self: TimePassesHandler) -> object {
        ffi.lib.LLVMPY_DisposeTimePassesHandler(self);
    }
}
class PassBuilder(ffi.ObjectRef) {
    def init(self: PassBuilder, tm: Any, pto: Any) -> object {
        super.init(ffi.lib.LLVMPY_CreatePassBuilder(tm, pto));
        self._pto = pto;
        self._tm = tm;
        self._time_passes_handler = None;
    }
    def getModulePassManager(self: PassBuilder) -> object {
        return ModulePassManager(
            ffi.lib.LLVMPY_buildPerModuleDefaultPipeline(
                self, self._pto.speed_level, self._pto.size_level
            )
        );
    }
    def getFunctionPassManager(self: PassBuilder) -> object {
        return FunctionPassManager(
            ffi.lib.LLVMPY_buildFunctionSimplificationPipeline(
                self, self._pto.speed_level, self._pto.size_level
            )
        );
    }
    """Enable the pass timers.

        Raises
        ------
        RuntimeError
            If pass timing is already enabled.
        """
    def start_pass_timing(self: PassBuilder) -> object {
        if self._time_passes_handler {
            raise RuntimeError("Pass timing can only be done once");
        }
        self._time_passes_handler = TimePassesHandler();
        ffi.lib.LLVMPY_EnableTimePasses(self, self._time_passes_handler);
    }

    """Returns the pass timings report and disables the LLVM internal
        timers. Pass timers are enabled by ``start_pass_timing()``. If the
        timers are not enabled, this function will return an empty string.

        Returns
        -------
        res : str
            LLVM generated timing report.
        """
    def finish_pass_timing(self: PassBuilder) -> object {
        if not self._time_passes_handler {
            raise RuntimeError("Pass timing is not enabled");
        }
        with ffi.OutputString() as buf {
            ffi.lib.LLVMPY_ReportAndDisableTimePasses(self._time_passes_handler, buf);
            return str(buf);
        }
    }

    def _dispose(self: PassBuilder) -> object {
        ffi.lib.LLVMPY_DisposePassBuilder(self);
    }
}

with entry {
    ffi.lib.LLVMPY_DumpRefPruneStats.argtypes = [POINTER(_c_PruneStats), c_bool];
    ffi.lib.LLVMPY_SetTimePasses.argtypes = [c_bool];
    ffi.lib.LLVMPY_ReportAndResetTimings.argtypes = [POINTER(c_char_p)];
    ffi.lib.LLVMPY_CreateNewModulePassManager.restype = ffi.LLVMModulePassManagerRef;
    ffi.lib.LLVMPY_RunNewModulePassManager.argtypes = [
        ffi.LLVMModulePassManagerRef,
        ffi.LLVMModuleRef,
        ffi.LLVMPassBuilderRef
    ];
    ffi.lib.LLVMPY_module_AddVerifierPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddAAEvaluator.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddSimplifyCFGPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopUnrollPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopRotatePass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddInstCombinePass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_AddJumpThreadingPass_module.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddCFGPrinterPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddCFGOnlyPrinterPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddDomPrinter.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddDomOnlyPrinter.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddPostDomPrinter.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddPostDomOnlyPrinter.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddDomViewer.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddDomOnlyViewer.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddPostDomViewer.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddPostDomOnlyViewer.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddLintPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddADCEPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddBreakCriticalEdgesPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddDSEPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddDCEPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddAggressiveInstCombinePass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddLCSSAPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddNewGVNPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopSimplifyPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopUnrollAndJamPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddSCCPPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLowerAtomicPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLowerInvokePass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLowerSwitchPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddMemCpyOptPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddUnifyFunctionExitNodesPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddReassociatePass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddRegToMemPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddSROAPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddSinkingPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddTailCallElimPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddInstructionNamerPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddLoopDeletionPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopStrengthReducePass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddConstantMergePass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddDeadArgumentEliminationPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddCallGraphDOTPrinterPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddModuleDebugInfoPrinterPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddAlwaysInlinerPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddReversePostOrderFunctionAttrsPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddGlobalDCEPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddGlobalOptPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddIPSCCPPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddInternalizePass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddLoopExtractorPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddMergeFunctionsPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddPartialInlinerPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddStripSymbolsPass.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_module_AddStripDeadDebugInfoPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddStripDeadPrototypesPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddStripDebugDeclarePass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddStripNonDebugSymbolsPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddArgumentPromotionPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_module_AddPostOrderFunctionAttrsPass.argtypes = [
        ffi.LLVMModulePassManagerRef
    ];
    ffi.lib.LLVMPY_DisposeNewModulePassManger.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_AddRefPrunePass_module.argtypes = [
        ffi.LLVMModulePassManagerRef,
        c_int,
        c_size_t
    ];
    ffi.lib.LLVMPY_CreateNewFunctionPassManager.restype = ffi.LLVMFunctionPassManagerRef;
    ffi.lib.LLVMPY_RunNewFunctionPassManager.argtypes = [
        ffi.LLVMFunctionPassManagerRef,
        ffi.LLVMValueRef,
        ffi.LLVMPassBuilderRef
    ];
    ffi.lib.LLVMPY_function_AddAAEvaluator.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddSimplifyCFGPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLoopUnrollPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddInstCombinePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_AddJumpThreadingPass_function.argtypes = [
        ffi.LLVMFunctionPassManagerRef,
        c_int
    ];
    ffi.lib.LLVMPY_function_AddCFGPrinterPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddCFGOnlyPrinterPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddDomPrinter.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddDomOnlyPrinter.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddPostDomPrinter.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddPostDomOnlyPrinter.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddDomViewer.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddDomOnlyViewer.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddPostDomViewer.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddPostDomOnlyViewer.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLintPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddADCEPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddBreakCriticalEdgesPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddDSEPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddDCEPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddAggressiveInstCombinePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLCSSAPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddNewGVNPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddLoopSimplifyPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLoopUnrollAndJamPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddSCCPPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddLowerAtomicPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLowerInvokePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLowerSwitchPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddMemCpyOptPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddUnifyFunctionExitNodesPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddReassociatePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddRegToMemPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddSROAPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddSinkingPass.argtypes = [ffi.LLVMFunctionPassManagerRef];
    ffi.lib.LLVMPY_function_AddTailCallElimPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddInstructionNamerPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLoopRotatePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLoopDeletionPass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_function_AddLoopStrengthReducePass.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_DisposeNewFunctionPassManger.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_AddRefPrunePass_function.argtypes = [
        ffi.LLVMFunctionPassManagerRef,
        c_int,
        c_size_t
    ];
    ffi.lib.LLVMPY_CreatePipelineTuningOptions.restype = ffi.LLVMPipelineTuningOptionsRef;
    ffi.lib.LLVMPY_PTOGetLoopInterleaving.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopInterleaving.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetLoopInterleaving.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetLoopVectorization.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_PTOSetLoopVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetSLPVectorization.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetSLPVectorization.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetSLPVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetLoopUnrolling.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopUnrolling.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetLoopUnrolling.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetInlinerThreshold.restype = c_int;
    ffi.lib.LLVMPY_PTOSetInlinerThreshold.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_int
    ];
    ffi.lib.LLVMPY_DisposePipelineTuningOptions.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_CreatePassBuilder.restype = ffi.LLVMPassBuilderRef;
    ffi.lib.LLVMPY_CreatePassBuilder.argtypes = [
        ffi.LLVMTargetMachineRef,
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_DisposePassBuilder.argtypes = [ffi.LLVMPassBuilderRef];
    ffi.lib.LLVMPY_CreateTimePassesHandler.restype = ffi.LLVMTimePassesHandlerRef;
    ffi.lib.LLVMPY_DisposeTimePassesHandler.argtypes = [ffi.LLVMTimePassesHandlerRef];
    ffi.lib.LLVMPY_EnableTimePasses.argtypes = [
        ffi.LLVMPassBuilderRef,
        ffi.LLVMTimePassesHandlerRef
    ];
    ffi.lib.LLVMPY_ReportAndDisableTimePasses.argtypes = [
        ffi.LLVMTimePassesHandlerRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_buildPerModuleDefaultPipeline.restype = ffi.LLVMModulePassManagerRef;
    ffi.lib.LLVMPY_buildPerModuleDefaultPipeline.argtypes = [
        ffi.LLVMPassBuilderRef,
        c_int,
        c_int
    ];
    ffi.lib.LLVMPY_buildFunctionSimplificationPipeline.restype = ffi.LLVMFunctionPassManagerRef;
    ffi.lib.LLVMPY_buildFunctionSimplificationPipeline.argtypes = [
        ffi.LLVMPassBuilderRef,
        c_int,
        c_int
    ];
}

