"""Project files: reading package.json and enumerating workspaces."""

import from engine.src.pm.fsx { fsx_read_bytes, fsx_is_file, fsx_scandir, FsxDir }
import from engine.src.pm.json {
    JsonDoc,
    json_parse_bytes,
    JVal,
    jv_get,
    jv_is_obj,
    jv_str_list
}
import from engine.src.pm.bytes { ByteBuf, bytebuf_free }

obj:pub PkgJson {
    has ok: bool = False,
        error: str = "",
        path: str = "",
        json: JVal = JVal(),
        text: str = "";
}

"""Read and parse a package.json (comments / trailing commas tolerated)."""
def:pub pm_read_package_json(path: str) -> PkgJson {
    m: PkgJson = PkgJson(path=path);
    b: ByteBuf = fsx_read_bytes(path);
    if b.len < 0 {
        m.error = "not found";
        return m;
    }
    doc: JsonDoc = json_parse_bytes(b.ptr, b.len);
    if b.len > 0 {
        raw: str = b.ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        m.text = raw + "";
    }
    bytebuf_free(b);
    if not doc.ok {
        m.error = doc.error + " (line " + str(doc.line) + ")";
        return m;
    }
    if not jv_is_obj(doc.value) {
        m.error = "expected an object";
        return m;
    }
    m.json = doc.value;
    m.ok = True;
    return m;
}

"""Workspace directories named by package.json "workspaces" (array, or
{ "packages": [...] }); supports literal paths and a trailing "/*" or "/**".
Sorted, relative to `root_dir`."""
def:pub pm_workspace_dirs(root_dir: str, pj: JVal) -> list[str] {
    ws: JVal = jv_get(pj, "workspaces");
    if jv_is_obj(ws) {
        ws = jv_get(ws, "packages");
    }
    out: list[str] = [];
    for raw in jv_str_list(ws) {
        pat: str = raw;
        while pat.startswith("./") {
            pat = pat[2:];
        }
        while pat.endswith("/") {
            pat = pat[0:len(pat) - 1];
        }
        if pat == "" {
            continue;
        }
        if pat.endswith("/*") or pat.endswith("/**") {
            base: str = pat[0:pat.rfind("/")];
            d: FsxDir = fsx_scandir(root_dir + "/" + base);
            i: int = 0;
            while i < len(d.names) {
                if d.kinds[i] == 2 or d.kinds[i] == 3 {
                    cand: str = base + "/" + d.names[i];
                    if fsx_is_file(root_dir + "/" + cand + "/package.json")
                        and not (cand in out) {
                        out.append(cand);
                    }
                }
                i = i + 1;
            }
        } elif pat.find("*") < 0 {
            if fsx_is_file(root_dir + "/" + pat + "/package.json")
                and not (pat in out) {
                out.append(pat);
            }
        }
    }
    out.sort();
    return out;
}
