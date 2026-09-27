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
