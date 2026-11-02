glob _RN_BUILDERS_ANDROID = {"gradle", "eas"},
     _RN_BUILDERS_IOS = {"xcodebuild", "eas"};

def _to_bool(value: any, fallback: bool = False) -> bool;

def _resolve_rn_release(rn_cfg: dict[str, any]) -> bool;

def _resolve_rn_android_builder(rn_cfg: dict[str, any]) -> str;

def _resolve_rn_ios_builder(rn_cfg: dict[str, any]) -> str;

def _resolve_rn_eas_profile(rn_cfg: dict[str, any], release: bool) -> str;

def _resolve_rn_eas_update_enabled(rn_cfg: dict[str, any]) -> bool;

def _resolve_rn_eas_update_branch(rn_cfg: dict[str, any], release: bool) -> str;

def _resolve_rn_eas_update_message(rn_cfg: dict[str, any]) -> str;
