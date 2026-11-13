"""Edges of the native unit cache: products that must not outlive the lowering
that made them, Python-lane invalidation that must not take native products
with it, references to units that cannot be found, and two units that would
share one symbol prefix."""
import os;
import sys;
import tempfile;
import jaclang;
import from jaclang.compiler.driver.jir {
    NativeStamp,
    SEC_BYTECODE,
    SEC_CLIENT,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SECTIONS_MAGIC,
    HEADER_SIZE,
    drop_python_lane_products,
    get_module_cache_path,
    merge_native_sections,
    native_section_payload,
    read_sections,
    write_module_cache
}
import from jaclang.compiler.driver.native_iface { resolve_native_unit_ref }
import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
import from jaclang.compiler.backends.native.link_plan {
    LinkPlanError,
    LinkUnit,
    check_prefix_collisions
}
import from jaclang.compiler.driver.native_iface { NativeIface }

glob STAMP = NativeStamp(compiler_digest="c", codegen_identity="g", triple="t");

def sections_of(path: str) -> dict[int, bytes] {
    data = get_module_cache_path(path).read_bytes();
    pos = data.find(SECTIONS_MAGIC, HEADER_SIZE);
    return read_sections(data, pos + len(SECTIONS_MAGIC));
}

def temp_source(text: str) -> str {
    directory = tempfile.mkdtemp(prefix="jac_native_edges_");
    path = os.path.join(directory, "unit.jac");
    with open(path, "w") as handle {
        handle.write(text);
    }
    return path;
}

test "relowering a unit without bitcode drops the bitcode and object it replaces" {
    existing = {
        SEC_NIFACE: STAMP.pack(b"iface-a"),
        SEC_NBITCODE: STAMP.pack(b"body-a"),
        SEC_NOBJ: STAMP.pack(b"obj-a")
    };
    merged = merge_native_sections(existing, {SEC_NIFACE: STAMP.pack(b"iface-b")});
    assert native_section_payload(merged.get(SEC_NIFACE), STAMP) == b"iface-b";
    assert native_section_payload(merged.get(SEC_NBITCODE), STAMP) is None;
    assert native_section_payload(merged.get(SEC_NOBJ), STAMP) is None;
}

test "rewriting the same interface keeps the bitcode compiled against it" {
    existing = {
        SEC_NIFACE: STAMP.pack(b"iface-a"),
        SEC_NBITCODE: STAMP.pack(b"body-a"),
        SEC_NOBJ: STAMP.pack(b"obj-a")
    };
    merged = merge_native_sections(existing, {SEC_NIFACE: STAMP.pack(b"iface-a")});
    assert native_section_payload(merged.get(SEC_NBITCODE), STAMP) == b"body-a";
    assert native_section_payload(merged.get(SEC_NOBJ), STAMP) == b"obj-a";
}

test "dropping the Python-lane products keeps the stamped native sections" {
    path = temp_source("glob kept = 1;\n");
    assert write_module_cache(
        path, b"bytecode", {SEC_CLIENT: b"client", SEC_NIFACE: STAMP.pack(b"iface")}
    );
    drop_python_lane_products(path);
    kept = sections_of(path);
    assert SEC_BYTECODE not in kept and SEC_CLIENT not in kept , sorted(kept);
    assert native_section_payload(kept.get(SEC_NIFACE), STAMP) == b"iface";
}

test "dropping the Python-lane products of a unit with no native sections removes it" {
    path = temp_source("glob gone = 1;\n");
    assert write_module_cache(path, b"bytecode", {SEC_CLIENT: b"client"});
    drop_python_lane_products(path);
    assert not get_module_cache_path(path).exists();
}

test "a unit reference found under no root never resolves against the working directory" {
    ref = "no_such_root_jac/unit.jac";
    resolved = resolve_native_unit_ref(ref);
    assert os.path.isabs(resolved) , resolved;
    assert not os.path.exists(resolved) , resolved;
}

test "a unit reference to an installed package resolves through the import path" {
    site = tempfile.mkdtemp(prefix="jac_native_site_");
    checkout = os.path.join(site, "checkout-b");
    os.makedirs(checkout);
    with open(os.path.join(checkout, "jac.toml"), "w") as handle {
        handle.write('["project"]\n"name" = "edgepkg"\n');
    }
    target = os.path.join(checkout, "unit.jac");
    with open(target, "w") as handle {
        handle.write("glob x = 1;\n");
    }
    sys.path.append(site);
    try {
        assert resolve_native_unit_ref("edgepkg/unit.jac") == target;
        assert native_unit_identity(target) == "edgepkg/unit.jac";

        scoped = os.path.join(site, "checkout-scoped");
        os.makedirs(scoped);
        with open(os.path.join(scoped, "jac.toml"), "w") as handle {
            handle.write('[project]\nname = "acme/math"\n');
        }
        scoped_target = os.path.join(scoped, "unit.jac");
        with open(scoped_target, "w") as handle {
            handle.write("glob y = 1;\n");
        }
        assert native_unit_identity(scoped_target) == "acme/math/unit.jac";
        assert resolve_native_unit_ref("acme/math/unit.jac") == scoped_target;
        assert resolve_native_unit_ref("acme/math/unit.jac", scoped_target)
            == scoped_target;
    } finally {
        sys.path.remove(site);
    }

    parent = os.path.join(site, "parent");
    nested = os.path.join(parent, "nested");
    os.makedirs(nested);
    with open(os.path.join(parent, "jac.toml"), "w") as handle {
        handle.write('[project]\nname = "outer"\n');
    }
    with open(os.path.join(nested, "jac.toml"), "w") as handle {
        handle.write('["project"]\n"name" = "nested"\n');
    }
    nested_unit = os.path.join(nested, "unit.jac");
    with open(nested_unit, "w") as handle {
        handle.write("glob x = 1;\n");
    }
    assert native_unit_identity(nested_unit) == "nested/unit.jac";

    named_jaclang = os.path.join(site, "named-jaclang");
    os.makedirs(named_jaclang);
    with open(os.path.join(named_jaclang, "jac.toml"), "w") as handle {
        handle.write('["project"]\n"name" = "jaclang"\n');
    }
    own_unit = os.path.join(named_jaclang, "unit.jac");
    with open(own_unit, "w") as handle {
        handle.write("glob x = 2;\n");
    }
    resolved_own_unit = resolve_native_unit_ref("jaclang/unit.jac", own_unit);
    assert os.path.realpath(resolved_own_unit) == os.path.realpath(own_unit) , (
        resolved_own_unit
    );
    bundled_runtime = resolve_native_unit_ref(
        "jaclang/runtime/region_native.jac", own_unit
    );
    expected_runtime = os.path.join(
        os.path.dirname(jaclang.__file__), "runtime", "region_native.jac"
    );
    assert os.path.realpath(bundled_runtime) == os.path.realpath(expected_runtime) , (
        bundled_runtime
    );
}

test "a unit reference prefers the owner's selected package mount" {
    site = tempfile.mkdtemp(prefix="jac_native_mounts_");
    owner = os.path.join(site, "owner");
    old_version = os.path.join(site, "edgepkg-old");
    selected_version = os.path.join(site, "edgepkg-selected");
    os.makedirs(owner);
    os.makedirs(old_version);
    os.makedirs(selected_version);
    for root in [old_version, selected_version] {
        with open(os.path.join(root, "jac.toml"), "w") as handle {
            handle.write('[project]\nname = "edgepkg"\n');
        }
        with open(os.path.join(root, "unit.jac"), "w") as handle {
            handle.write("glob version = 1;\n");
        }
    }
    with open(os.path.join(owner, "jac.toml"), "w") as handle {
        handle.write('[project]\nname = "edgeowner"\n');
    }
    anchor = os.path.join(owner, "main.jac");
    with open(anchor, "w") as handle {
        handle.write("glob x = 1;\n");
    }
    mounts = os.path.join(owner, ".jac", "packages");
    os.makedirs(mounts);
    os.symlink(
        selected_version, os.path.join(mounts, "edgepkg"), target_is_directory=True
    );
    assert resolve_native_unit_ref("edgepkg/unit.jac", anchor)
        == os.path.join(selected_version, "unit.jac");
}

test "two units sharing a symbol prefix are refused by name" {
    first = LinkUnit(
        path="/a/app/main.jac", prefix="main_1", iface=NativeIface(), digest="1"
    );
    second = LinkUnit(
        path="/b/app/main.jac", prefix="main_1", iface=NativeIface(), digest="2"
    );
    check_prefix_collisions([first]);
    try {
        check_prefix_collisions([first, second]);
    } except LinkPlanError as err {
        assert "/a/app/main.jac" in str(err) and "/b/app/main.jac" in str(err);
        return;
    }
    assert False , "the shared prefix was not refused";
}
