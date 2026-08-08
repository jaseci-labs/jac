import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.collector { IntentCollector }
import from jaclang.compiler.passes.ecmascript.intent.session { IntentSession }
import from jaclang.compiler.passes.compose.compose_leaf_converter {
    ComposeLeafConverter
}
import from jaclang.compiler.passes.compose.compose_intent_adapter {
    ComposeIntentAdapter
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_view_builder { ComposeViewBuilder }

obj ComposeGenPass(UniPass) {
    has model: ComposeModule = ComposeModule(),
        collector: IntentCollector = IntentCollector(),
        intent_session: (IntentSession | None) = None,
        converter: (ComposeLeafConverter | None) = None,
        lowerer: JacToKotlin = JacToKotlin(),
        view_builder: ComposeViewBuilder = ComposeViewBuilder(),
        reactive_vars: set[str] = set();

    def before_pass -> None;
    def after_pass -> None;
    def _session -> IntentSession;
    def enter_ability(nd: uni.Ability) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_assignment(nd: uni.Assignment) -> None;
    def exit_import(nd: uni.Import) -> None;
    def _sync_lowerer_reactive_vars -> None;
}

def run_compose_gen_pass(
    mod: uni.Module, prog: any = None, into: (ComposeModule | None) = None
) -> ComposeModule;
