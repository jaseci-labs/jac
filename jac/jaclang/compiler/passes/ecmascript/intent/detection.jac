import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.ecmascript.intent.leaf_converter { LeafConverter }
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateField,
    RefField,
    StateUpdate,
    Effect
}

glob JSX_COMPONENT_TYPES: Sequence[str] = ('JsxElement', 'JsxPage', 'JsxLayout'),
     COMPOSE_COMPONENT_TYPES: Sequence[str] = (
         'Composable',
         'JsxElement',
         'JsxPage',
         'JsxLayout'
     ),
     HOME_COMPONENT_NAMES: Sequence[str] = ("app", "App", "__root__"),
     ASSIGNMENT_AUG_OPS: dict[str, str] = {
         Tok.ADD_EQ.name: '+',
         Tok.SUB_EQ.name: '-',
         Tok.MUL_EQ.name: '*',
         Tok.DIV_EQ.name: '/',
         Tok.MOD_EQ.name: '%'
     },
     ASSIGNMENT_KT_OPS: dict[str, str] = {
         Tok.ADD_EQ.name: '+=',
         Tok.SUB_EQ.name: '-=',
         Tok.MUL_EQ.name: '*=',
         Tok.DIV_EQ.name: '/=',
         Tok.MOD_EQ.name: '%='
     };

obj ArchHasScanResult {
    has state_fields: list[StateField] = [],
        ref_fields: list[RefField] = [],
        typed_ref_only: list[uni.HasVar] = [];
}

def ref_head_name(expr: (uni.UniNode | None)) -> (str | None);
def arch_has_owner(nd: uni.ArchHas) -> (uni.UniNode | None);
def arch_has_applicable(nd: uni.ArchHas, strict_client: bool = False) -> bool;
def is_ref_field(has_var: uni.HasVar) -> tuple[bool, bool];
def assignment_aug_op(nd: uni.Assignment) -> (str | None);
def assignment_kt_op(nd: uni.Assignment) -> str;
def return_type_includes(rt: uni.Expr, component_types: Sequence[str]) -> bool;

def return_type_route_role(rt: uni.Expr) -> (str | None);
def screen_meta_for_component(
    name: str, return_type: (uni.Expr | None)
) -> tuple[bool, (str | None)];

def component_name_from_ability(
    nd: uni.Ability, component_types: Sequence[str]
) -> (str | None);

def unwrap_ability_body(nd: uni.Ability) -> (list[uni.UniNode] | None);
def scan_arch_has(
    nd: uni.ArchHas, skip_existing: set[str], conv: LeafConverter
) -> ArchHasScanResult;

def scan_state_update(
    nd: uni.Assignment,
    conv: LeafConverter,
    convert_value:
        (Callable[[uni.Expr | uni.YieldExpr], (IntentLeaf | None)] | None) = None
) -> (StateUpdate | None);

def effect_from_ability(
    nd: uni.Ability, body: list[IntentLeaf], deps: list[IntentLeaf]
) -> Effect;
