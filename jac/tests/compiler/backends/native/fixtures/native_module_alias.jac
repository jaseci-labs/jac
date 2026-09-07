import bare_import_helper as helper;

def module_alias_probe -> int {
    return helper.fn() + helper.COUNT + helper.twice(2);
}

import math as arithmetic;
import os as operating;

obj LocalHelper {
    def fn -> int {
        return 9;
    }
}

def shadowed_module_alias(helper: LocalHelper) -> int {
    return helper.fn();
}

def module_alias_shadow_probe -> int {
    return shadowed_module_alias(LocalHelper());
}

def standard_module_alias_probe -> int {
    return int(arithmetic.sqrt(81.0)) + len(operating.path.basename("a/b/file"));
}

def module_member_shadow_probe -> int {
    def fn -> int {
        return 99;
    }
    return helper.fn() + fn();
}
