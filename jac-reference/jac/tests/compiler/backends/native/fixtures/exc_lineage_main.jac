"""`except Base` catches user-defined subclasses of `Base` on the native backend."""

import from exc_lineage_base { LibError, LibDetail, raise_detail, guard }

obj AppError(Exception) {}

obj StoreError(AppError) {}

obj BindError(StoreError) {}

obj OtherError(Exception) {}

obj DiskError(OSError) {}

obj PluginError(LibError) {}

def raise_bind(n: int) -> int {
    if n > 0 {
        raise BindError("bind " + str(n));
    }
    return n;
}

def plugin(n: int) -> int {
    if n > 0 {
        raise PluginError("plugin " + str(n));
    }
    return n;
}

def same_frame -> int {
    try {
        raise StoreError("store");
    } except AppError {
        return 1;
    }
    return 0;
}

def two_levels -> int {
    try {
        raise_bind(2);
    } except AppError {
        return 2;
    }
    return 0;
}

def builtin_base -> int {
    try {
        raise DiskError("disk");
    } except OSError {
        return 3;
    }
    return 0;
}

def imported_name -> int {
    try {
        raise_detail(4);
    } except LibDetail {
        return 4;
    }
    return 0;
}

def imported_base -> int {
    try {
        raise_detail(4);
    } except LibError {
        return 4;
    }
    return 0;
}

def unseen_subclass -> int {
    return guard(plugin, 5);
}

def falls_through -> int {
    try {
        raise_bind(6);
    } except OtherError {
        return -6;
    } except StoreError {
        return 6;
    }
    return 0;
}
