import from jaclang.compiler.passes.context { CompilerPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.jsx_intrinsic_guard_pass { JsxIntrinsicGuardPass }

glob EARLY_PASSES: tuple[type[CompilerPass], ...] = (
         GraphLoweringPass,
         ASTValidationPass,
         SymTabBuildPass,
         DeclImplMatchPass,
         SemanticAnalysisPass,
         SemDefMatchPass,
         CFGBuildPass,
         JsxIntrinsicGuardPass
     );
