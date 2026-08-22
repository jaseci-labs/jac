import os;

def mobui_module_exempt(mod_path: str, project_root: (str | None)) -> bool {
    if not project_root {
        return True;
    }
    real_mod = os.path.normcase(os.path.realpath(mod_path));
    real_root = os.path.normcase(os.path.realpath(project_root));
    return not real_mod.startswith(real_root + os.sep);
}

def mobui_enforced_in(mod_path: str, kind: str, project_root: (str | None)) -> bool {
    if kind != "mobui" {
        return False;
    }
    return not mobui_module_exempt(mod_path, project_root);
}
