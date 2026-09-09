import os;

def mobui_module_exempt(mod_path: str, enforced_root: (str | None)) -> bool {
    if not enforced_root {
        return True;
    }
    real_mod = os.path.normcase(os.path.realpath(mod_path));
    real_root = os.path.normcase(os.path.realpath(enforced_root));
    return not real_mod.startswith(real_root + os.sep);
}
