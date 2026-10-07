import from enum { Enum }

import from types { MethodType }

glob CHOICE = "choice",
     NOUL = "noul",
     SCORE = "score";

glob MODE_ENUM = "enum",
     MODE_BOOL = "bool",
     MODE_ENUM_LIST = "enum_list",
     MODE_RECORD = "record";

glob ANSWER_KEY = "value";

glob SYSTEMONE_PREFIX = "systemone:",
     DEFAULT_PROVIDER = "typesafe";

glob ROUTE_SELECT_ATTR = "_systemone_select";


obj ProviderCaps {
    has base_url: str = "",
        key_env: str = "",
        model: str = "",
        max_choice_options: int = 255,
        max_state_chars: int = 120000,
        supports_batch: bool = True,
        route: str = "/v1/systemone",
        key_env_aliases: list[str] = [];
}


obj Question {
    has kind: str,
        instructions: str,
        criteria: (dict[str, any] | list[any] | None) = None;

    def to_wire -> dict[str, any];
}


obj SystemOneSpec {
    has state: dict[str, any],
        questions: dict[str, Question],
        mode: str,
        resp_type: (type | None) = None,
        as_list: bool = False,
        wrap_decision: bool = False,
        select: any = "all";

    def to_payload(model: str) -> dict[str, any];
}


obj Decision {
    has value: any = None,
        confidence: float = 0.0,
        probabilities: dict[str, any] = {},
        answered_by: str = "systemone";

    static has _views: dict[int, type] = {};

    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type {
        key = id(elem);
        cached = Decision._views.get(key);
        if cached is None {
            name = getattr(elem, "__name__", str(elem));
            cached = `type(f"Decision[{name}]", (Decision, ), {"_jac_inner": elem});
            Decision._views[key] = cached;
        }
        return cached;
    }
}


def default_caps -> ProviderCaps;

def enum_info_of(resp_type: object, info: object) -> (EnumInfo | None);

def return_info_of(mt_run: MTRuntime) -> object;

def instructions_of(mt_run: MTRuntime) -> str;

def build_state(mt_run: MTRuntime) -> (dict[str, any] | None);

def lower(
    mt_run: MTRuntime, caps: (ProviderCaps | None) = None
) -> (SystemOneSpec | None);

def assemble(spec: SystemOneSpec, answers: dict[str, any]) -> tuple[object, float];


def providers -> dict[str, ProviderCaps];

def caps_for(provider: str) -> ProviderCaps;

def resolve_model_name(name: str) -> tuple[str, str];

def resolve_api_key(caps: ProviderCaps, explicit: str = "") -> str;

def distribution(spec: SystemOneSpec, answers: dict[str, any]) -> dict[str, any];

def wrap_result(
    spec: SystemOneSpec, value: object, confidence: float, probs: dict[str, any]
) -> object;
