import from jaclang.compiler.analysis.interfaces.facts { InterfaceProduct }
import from jaclang.compiler.pipeline.contracts { CompilationProduct, ProductKey }
import from jaclang.compiler.analysis.placement.products {
    PlacementSpaces,
    NativeEligibility
}
import from jaclang.compiler.analysis.placement.summary { PlacementSummary }
import from jaclang.compiler.analysis.boundaries.facts { ServingFacts }

glob SPACES: ProductKey[PlacementSpaces] = ProductKey(
         CompilationProduct.SPACES, PlacementSpaces
     ),
     PLACEMENT_SUMMARY: ProductKey[PlacementSummary] = ProductKey(
         CompilationProduct.PLACEMENT_SUMMARY, PlacementSummary
     ),
     NATIVE_ELIGIBILITY: ProductKey[NativeEligibility] = ProductKey(
         CompilationProduct.NATIVE_ELIGIBILITY, NativeEligibility
     ),
     INTERFACE: ProductKey[InterfaceProduct] = ProductKey(
         CompilationProduct.INTERFACE, InterfaceProduct
     ),
     SERVING: ProductKey[ServingFacts] = ProductKey(
         CompilationProduct.SERVING, ServingFacts
     );
