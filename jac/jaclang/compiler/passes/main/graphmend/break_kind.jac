"""GraphMend break-kind tags: the typed contract between the detection pass and
the transformation passes that consume the `_gm_break_kind` node tag.

Modeled as a string-valued enum (same idiom as `symbol_utils.CallKind`) so the
tag is type-checked at every set/compare site -- no magic strings shared across
the four GraphMend PRs -- while the stored value is still a readable string when
a node is inspected or unparsed. Each kind names the single transform allowed to
lower it:

  - VAL_GUARD   : data-dependent guard `raise` -> TrapLoweringPass
  - DYN_CTRL_FL : data-dependent if/else        -> PredicateCtrlFlowPass
  - SIDE_EFFECT : print / logger call           -> DeferSideEffectPass
"""

enum BreakKind {
    VAL_GUARD = "val_guard",  # data-dependent `if not C: raise` guard
    DYN_CTRL_FL = "dyn_ctrl_fl",  # data-dependent if/else
    SIDE_EFFECT = "side_effect"  # print / logger call
}
