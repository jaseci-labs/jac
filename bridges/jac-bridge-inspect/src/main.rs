//! Parse `.jac_bridge` metadata from a Rust bridge shared library.
//!
//! Usage: jac-bridge-inspect <lib.so>
//!
//! Reads the ELF/Mach-O/PE section that every jac-bridge-* crate embeds,
//! then pretty-prints types, functions, and parameters without executing
//! the library.  Exit codes: 0=ok, 1=parse error, 2=section not found.

use jac_bridge_schema::{
    ABI_VERSION, MAGIC,
    TAG_BOOL, TAG_STR, TAG_VOID, TAG_REF_BIT,
    KIND_OPAQUE, KIND_ERROR, FN_CTOR, FN_METHOD,
};
use object::{Object, ObjectSection};
use std::process;

fn main() {
    // Accept  "jac-bridge-inspect <path>"
    // or      "jac bridge inspect <path>"  (extra non-flag words ignored)
    let args: Vec<String> = std::env::args().collect();
    let path = args
        .iter()
        .skip(1)
        .find(|a| !["bridge", "inspect"].contains(&a.as_str()) && !a.starts_with('-'))
        .unwrap_or_else(|| {
            eprintln!("Usage: jac-bridge-inspect <lib.so>");
            process::exit(1);
        });

    let data = std::fs::read(path).unwrap_or_else(|e| {
        eprintln!("error: cannot read {path}: {e}");
        process::exit(1);
    });

    let obj = object::File::parse(&*data).unwrap_or_else(|e| {
        eprintln!("error: cannot parse {path} as an object file: {e}");
        process::exit(1);
    });

    // Section names per platform (lib.rs uses cfg_attr to pick).
    let section = obj
        .section_by_name(".jac_bridge")     // ELF (Linux)
        .or_else(|| obj.section_by_name("__jac_bridge"))  // Mach-O (macOS, segment stripped)
        .or_else(|| obj.section_by_name(".jacbrdg"));     // PE (Windows)

    let blob = match section {
        Some(s) => s.data().unwrap_or_else(|e| {
            eprintln!("error: cannot read section data: {e}");
            process::exit(1);
        }),
        None => {
            eprintln!("error: no .jac_bridge section found in {path}");
            eprintln!("       (expected one of: .jac_bridge, __jac_bridge, .jacbrdg)");
            process::exit(2);
        }
    };

    match parse_and_print(path, blob) {
        Ok(()) => {}
        Err(e) => {
            eprintln!("error: {e}");
            process::exit(1);
        }
    }
}


// ---- Primitive readers ------------------------------------------------------

fn u8_at(blob: &[u8], off: usize) -> Result<u8, String> {
    blob.get(off).copied().ok_or_else(|| format!("read u8 at {off}: out of bounds"))
}

fn u32_at(blob: &[u8], off: usize) -> Result<u32, String> {
    blob.get(off..off + 4)
        .map(|b| u32::from_le_bytes(b.try_into().unwrap()))
        .ok_or_else(|| format!("read u32 at {off}: out of bounds"))
}

/// Read a StrRef (offset: u32, len: u32) and return the referenced string.
fn str_ref<'a>(blob: &'a [u8], off: usize) -> Result<&'a str, String> {
    let abs = u32_at(blob, off)? as usize;
    let len = u32_at(blob, off + 4)? as usize;
    let bytes = blob
        .get(abs..abs + len)
        .ok_or_else(|| format!("StrRef at {off}: [{abs}..{}) out of bounds", abs + len))?;
    std::str::from_utf8(bytes).map_err(|e| format!("StrRef at {off}: invalid UTF-8: {e}"))
}

// ---- TypeTag formatter ------------------------------------------------------

fn fmt_tag(tag: u32, type_names: &[&str]) -> String {
    match tag {
        TAG_BOOL => "bool".into(),
        TAG_STR => "str".into(),
        TAG_VOID => "()".into(),
        t if t & TAG_REF_BIT != 0 => {
            let i = (t & !TAG_REF_BIT) as usize;
            type_names
                .get(i)
                .map(|&n| n.to_string())
                .unwrap_or_else(|| format!("type[{i}]"))
        }
        t => format!("tag(0x{t:08x})"),
    }
}

// ---- Main parser / printer --------------------------------------------------

fn parse_and_print(path: &str, blob: &[u8]) -> Result<(), String> {
    if blob.len() < 56 {
        return Err(format!("blob too short: {} bytes (need at least 56)", blob.len()));
    }

    // Header
    if &blob[0..8] != MAGIC.as_slice() {
        return Err(format!("bad magic: {:?}", &blob[0..8]));
    }

    let abi_version = u32_at(blob, 8)?;
    if abi_version != ABI_VERSION {
        return Err(format!("unsupported ABI version {abi_version} (expected {ABI_VERSION})"));
    }
    let blob_len = u32_at(blob, 16)? as usize;
    if blob.len() < blob_len {
        return Err(format!(
            "blob truncated: section has {} bytes, header says {blob_len}",
            blob.len()
        ));
    }

    let module_name = str_ref(blob, 24)?;
    let types_off = u32_at(blob, 40)? as usize;
    let types_count = u32_at(blob, 44)? as usize;
    let fns_off = u32_at(blob, 48)? as usize;
    let fns_count = u32_at(blob, 52)? as usize;

    println!("jac-bridge-inspect  {path}");
    println!();
    println!("  ABI version : {abi_version}");
    println!("  Module      : {module_name}");
    println!("  Blob length : {blob_len}");
    println!("  Types       : {types_count}");
    println!("  Functions   : {fns_count}");

    // Collect type names up front for TypeTag formatting.
    let mut type_names: Vec<&str> = Vec::with_capacity(types_count);
    let mut type_kinds: Vec<u8> = Vec::with_capacity(types_count);
    {
        let mut off = types_off;
        for _ in 0..types_count {
            let desc_size = u32_at(blob, off)? as usize;
            type_kinds.push(u8_at(blob, off + 4)?);
            type_names.push(str_ref(blob, off + 8)?);
            off += desc_size;
        }
    }

    // Types
    println!();
    println!("Types:");
    {
        let mut off = types_off;
        for i in 0..types_count {
            let desc_size = u32_at(blob, off)? as usize;
            let kind = u8_at(blob, off + 4)?;
            let name = str_ref(blob, off + 8)?;
            let drop_sym = str_ref(blob, off + 16)?;
            let kind_str = match kind {
                KIND_OPAQUE => "opaque",
                KIND_ERROR => "error",
                _ => "?",
            };
            println!("  [{i}]  {name:<14}  {kind_str:<6}  drop={drop_sym}");
            off += desc_size;
        }
    }

    // Functions
    println!();
    println!("Functions:");
    {
        let mut off = fns_off;
        for i in 0..fns_count {
            let desc_size = u32_at(blob, off)? as usize;
            let name = str_ref(blob, off + 4)?;
            let symbol = str_ref(blob, off + 12)?;
            let self_type = u32_at(blob, off + 20)?;
            let kind = u8_at(blob, off + 24)?;
            let throws = u32_at(blob, off + 28)?;
            let ret = u32_at(blob, off + 32)?;
            let params_off = u32_at(blob, off + 36)? as usize;
            let params_count = u32_at(blob, off + 40)? as usize;

            // Build parameter list.
            let mut param_parts: Vec<String> = Vec::new();
            let mut poff = params_off;
            for _ in 0..params_count {
                let pname = str_ref(blob, poff)?;
                let pty = u32_at(blob, poff + 8)?;
                param_parts.push(format!("{pname}: {}", fmt_tag(pty, &type_names)));
                poff += 12;
            }
            let params_str = param_parts.join(", ");

            let ret_str = fmt_tag(ret, &type_names);
            let sig = format!("{name}({params_str}) -> {ret_str}");

            let kind_str = match kind {
                FN_CTOR => "ctor  ",
                FN_METHOD => "method",
                _ => "?     ",
            };

            // Extra: self / sym / throws
            let mut extras: Vec<String> = Vec::new();
            if self_type != TAG_VOID {
                extras.push(format!("self={}", fmt_tag(TAG_REF_BIT | self_type, &type_names)));
            }
            extras.push(format!("sym={symbol}"));
            if throws != TAG_VOID {
                extras.push(format!("throws={}", fmt_tag(TAG_REF_BIT | throws, &type_names)));
            }

            println!("  [{i}]  {sig:<40}  {kind_str}  {}", extras.join("  "));
            off += desc_size;
        }
    }

    Ok(())
}

// ---- Unit tests (parse the regex bridge blob without dlopen) ----------------
//
// These tests run `cargo test` inside the workspace; they load the blob from
// the debug build output produced by `jac-bridge-regex`'s build script.

#[cfg(test)]
mod tests {
    use super::*;

    fn regex_blob() -> Vec<u8> {
        // The build script writes the blob to $OUT_DIR/jac_bridge_meta.bin.
        // We find it relative to the workspace target directory.
        let manifest = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        let ws = manifest.parent().unwrap(); // bridges/
        let blob_path = ws
            .join("target/debug/build")
            .read_dir()
            .expect("target/debug/build not found — run `cargo build` for jac-bridge-regex first")
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_string_lossy()
                    .starts_with("jac-bridge-regex-")
            })
            .find_map(|e| {
                let p = e.path().join("out/jac_bridge_meta.bin");
                p.exists().then_some(p)
            })
            .expect("jac_bridge_meta.bin not found; run: cargo build -p jac-bridge-regex");
        std::fs::read(blob_path).unwrap()
    }

    #[test]
    fn header_magic() {
        let blob = regex_blob();
        assert_eq!(&blob[0..8], b"JACBRDG1");
    }

    #[test]
    fn header_abi_version() {
        let blob = regex_blob();
        assert_eq!(u32_at(&blob, 8).unwrap(), 1);
    }

    #[test]
    fn header_blob_len() {
        let blob = regex_blob();
        let reported = u32_at(&blob, 16).unwrap() as usize;
        assert_eq!(reported, blob.len());
    }

    #[test]
    fn module_name() {
        let blob = regex_blob();
        assert_eq!(str_ref(&blob, 24).unwrap(), "regex");
    }

    #[test]
    fn type_names_and_kinds() {
        let blob = regex_blob();
        let td0 = u32_at(&blob, 40).unwrap() as usize;
        let count = u32_at(&blob, 44).unwrap() as usize;
        assert_eq!(count, 2);
        assert_eq!(str_ref(&blob, td0 + 8).unwrap(), "Regex");
        assert_eq!(u8_at(&blob, td0 + 4).unwrap(), KIND_OPAQUE);
        let td1 = td0 + u32_at(&blob, td0).unwrap() as usize;
        assert_eq!(str_ref(&blob, td1 + 8).unwrap(), "RegexError");
        assert_eq!(u8_at(&blob, td1 + 4).unwrap(), KIND_ERROR);
    }

    #[test]
    fn drop_symbols() {
        let blob = regex_blob();
        let td0 = u32_at(&blob, 40).unwrap() as usize;
        let td1 = td0 + u32_at(&blob, td0).unwrap() as usize;
        assert_eq!(str_ref(&blob, td0 + 16).unwrap(), "jac_regex_Regex_drop");
        assert_eq!(str_ref(&blob, td1 + 16).unwrap(), "jac_regex_error_drop");
    }

    #[test]
    fn fn_count_and_kinds() {
        let blob = regex_blob();
        let fd0 = u32_at(&blob, 48).unwrap() as usize;
        let count = u32_at(&blob, 52).unwrap() as usize;
        assert_eq!(count, 3);
        assert_eq!(str_ref(&blob, fd0 + 4).unwrap(), "new");
        assert_eq!(u8_at(&blob, fd0 + 24).unwrap(), FN_CTOR);
        let fd1 = fd0 + u32_at(&blob, fd0).unwrap() as usize;
        assert_eq!(str_ref(&blob, fd1 + 4).unwrap(), "is_match");
        assert_eq!(u8_at(&blob, fd1 + 24).unwrap(), FN_METHOD);
    }

    #[test]
    fn fn0_ret_is_type_ref_0() {
        let blob = regex_blob();
        let fd0 = u32_at(&blob, 48).unwrap() as usize;
        let ret = u32_at(&blob, fd0 + 32).unwrap();
        assert_eq!(ret, TAG_REF_BIT | 0, "new() must return TYPE_REF(0) = Regex");
    }

    #[test]
    fn fn1_self_is_type_ref_0() {
        let blob = regex_blob();
        let fd0 = u32_at(&blob, 48).unwrap() as usize;
        let fd1 = fd0 + u32_at(&blob, fd0).unwrap() as usize;
        let self_type = u32_at(&blob, fd1 + 20).unwrap();
        assert_eq!(self_type, 0, "is_match self_type must be index 0 (Regex)");
    }

    #[test]
    fn fn0_throws_is_type_ref_1() {
        let blob = regex_blob();
        let fd0 = u32_at(&blob, 48).unwrap() as usize;
        let throws = u32_at(&blob, fd0 + 28).unwrap();
        assert_eq!(throws, 1, "new() throws must be index 1 (RegexError)");
    }

    #[test]
    fn parse_and_print_smoke() {
        let blob = regex_blob();
        // Just assert it doesn't return an error.
        parse_and_print("(test)", &blob).unwrap();
    }
}
