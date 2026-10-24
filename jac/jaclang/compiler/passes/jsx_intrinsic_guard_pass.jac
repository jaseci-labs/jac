glob _GENERIC_SUGGESTION: str = "an @jac/mobui component",
     _tag_suggestions: (dict[str, str] | None) = None;

def _suggestion_for(tag: str) -> str;

walker JsxIntrinsicGuardPass(TreePass) {
    static has contract: PassContract = PassContract(kernel_safe=True);
    has _enforced_root: (str | None) = None,
        _exempt_paths: dict[str, bool] = {};

    can prepare with entry;
    can enter_module with Module entry;
    can enter_jsx_element with JsxElement entry;
    def _check_element(el: JsxElement);
    def _resolves_in_scope(el: JsxElement, first: UniNode) -> bool;
    def _is_exempt(mod_path: str) -> bool;
}
