// Generates the D2 metadata blob for the regex bridge at compile time.
// The blob is written to $OUT_DIR/meta.rs and included verbatim into lib.rs.
//
// Layout (all LE, all offsets from blob start, no NUL termination anywhere):
//
//  0   Header      56 bytes
//  56  TypeDesc[0] Regex       32 bytes
//  88  TypeDesc[1] RegexError  32 bytes
//  120 FnDesc[0]   new         44 bytes
//  164 FnDesc[1]   is_match    44 bytes
//  208 FnDesc[2]   message     44 bytes
//  252 ParamDesc[0] pattern    12 bytes
//  264 ParamDesc[1] text       12 bytes
//  276 String pool             155 bytes
//  431 end

use jac_bridge_schema::{
    ABI_VERSION, MAGIC,
    TAG_BOOL, TAG_STR, TAG_REF_BIT, TAG_VOID,
    KIND_OPAQUE, KIND_ERROR, FN_CTOR, FN_METHOD,
};
use std::{collections::HashMap, fmt::Write as FmtWrite};

fn main() {
    let blob = build_blob();
    let out = std::env::var("OUT_DIR").unwrap();

    // Binary blob for external tooling (section parser, cross-compile test).
    std::fs::write(format!("{out}/jac_bridge_meta.bin"), &blob).unwrap();

    // Rust source embedding the blob as a `const` array so lib.rs can use it
    // in a #[link_section] static without any runtime allocation.
    let len = blob.len();
    let mut src = format!("pub const META_LEN: usize = {len};\n");
    src.push_str("#[allow(clippy::all)]\n");
    src.push_str(&format!("pub const META_DATA: [u8; META_LEN] = [\n"));
    for chunk in blob.chunks(16) {
        src.push_str("    ");
        for b in chunk {
            write!(src, "0x{b:02x},").unwrap();
        }
        src.push('\n');
    }
    src.push_str("];\n");
    std::fs::write(format!("{out}/meta.rs"), src).unwrap();

    println!("cargo:rerun-if-changed=build.rs");
}


// ---- Simple string pool -------------------------------------------------

struct Strings {
    pool: Vec<u8>,
    map: HashMap<String, u32>, // string → byte offset within pool
}

impl Strings {
    fn new() -> Self {
        Strings { pool: Vec::new(), map: HashMap::new() }
    }

    /// Intern a string; returns (pool_offset, len).
    fn intern(&mut self, s: &str) -> (u32, u32) {
        let off = if let Some(&o) = self.map.get(s) {
            o
        } else {
            let o = self.pool.len() as u32;
            self.map.insert(s.to_string(), o);
            self.pool.extend_from_slice(s.as_bytes());
            o
        };
        (off, s.len() as u32)
    }
}

// ---- Byte writer --------------------------------------------------------

struct W {
    buf: Vec<u8>,
}

impl W {
    fn new() -> Self { W { buf: Vec::new() } }
    fn u8(&mut self, v: u8) { self.buf.push(v); }
    fn pad(&mut self, n: usize) { for _ in 0..n { self.buf.push(0); } }
    fn u32(&mut self, v: u32) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn u64(&mut self, v: u64) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn pos(&self) -> usize { self.buf.len() }
    /// Write a StrRef: absolute blob offset + byte length (both u32 LE).
    fn str_ref(&mut self, pool_base: u32, pool_off: u32, len: u32) {
        self.u32(pool_base + pool_off);
        self.u32(len);
    }
}

// ---- Blob construction --------------------------------------------------

fn build_blob() -> Vec<u8> {
    let mut strings = Strings::new();

    // Intern every string in the order that determines pool layout.
    // Absolute offsets = pool_base(276) + pool_offset below.
    let s_module      = strings.intern("regex");                    // pool[0..5]   abs 276
    let s_name_regex  = strings.intern("Regex");                    // pool[5..10]  abs 281
    let s_drop_regex  = strings.intern("jac_regex_Regex_drop");     // pool[10..30] abs 286
    let s_name_regerr = strings.intern("RegexError");               // pool[30..40] abs 306
    let s_drop_regerr = strings.intern("jac_regex_error_drop");     // pool[40..60] abs 316
    let s_fn_new      = strings.intern("new");                      // pool[60..63] abs 336
    let s_sym_new     = strings.intern("jac_regex_Regex_new");      // pool[63..82] abs 339
    let s_fn_ism      = strings.intern("is_match");                 // pool[82..90] abs 358
    let s_sym_ism     = strings.intern("jac_regex_Regex_is_match"); // pool[90..114] abs 366
    let s_fn_msg      = strings.intern("message");                  // pool[114..121] abs 390
    let s_sym_msg     = strings.intern("jac_regex_error_message");  // pool[121..144] abs 397
    let s_p_pattern   = strings.intern("pattern");                  // pool[144..151] abs 420
    let s_p_text      = strings.intern("text");                     // pool[151..155] abs 427

    assert_eq!(strings.pool.len(), 155, "string pool size changed");

    let pool_base: u32 = 276;
    let total = pool_base as usize + strings.pool.len(); // 431
    assert_eq!(total, 431);

    let mut w = W::new();

    // ===== Header (0..56, 56 bytes) =====
    w.buf.extend_from_slice(MAGIC);              // magic       u64
    w.u32(ABI_VERSION);                          // abi_version u32
    w.u32(56);                                   // header_size u32
    w.u32(total as u32);                         // blob_len    u32
    w.u32(0);                                    // blob_crc32  u32  (M0: not computed)
    w.str_ref(pool_base, s_module.0, s_module.1); // module_name StrRef
    w.u64(0);                                    // api_checksum u64 (M0: not computed)
    w.u32(56);  w.u32(2);                        // types {offset, count}
    w.u32(120); w.u32(3);                        // fns   {offset, count}
    assert_eq!(w.pos(), 56, "header size mismatch");

    // ===== TypeDesc[0]: Regex (opaque) at 56, 32 bytes =====
    w.u32(32);                    // desc_size
    w.u8(KIND_OPAQUE); w.pad(3);  // kind + pad
    w.str_ref(pool_base, s_name_regex.0, s_name_regex.1);   // name
    w.str_ref(pool_base, s_drop_regex.0, s_drop_regex.1);   // drop_symbol
    w.u32(0); w.u32(0);           // members {offset=0, count=0}
    assert_eq!(w.pos(), 88, "TypeDesc[0] size mismatch");

    // ===== TypeDesc[1]: RegexError (error) at 88, 32 bytes =====
    w.u32(32);
    w.u8(KIND_ERROR); w.pad(3);
    w.str_ref(pool_base, s_name_regerr.0, s_name_regerr.1);
    w.str_ref(pool_base, s_drop_regerr.0, s_drop_regerr.1);
    w.u32(0); w.u32(0);
    assert_eq!(w.pos(), 120, "TypeDesc[1] size mismatch");

    // ===== FnDesc[0]: Regex_new (ctor) at 120, 44 bytes =====
    //   kind=CTOR  self_type=NONE  throws=1(RegexError)  ret=TYPE_REF(0)
    //   params[252..252+12]: [{pattern, STR}]
    w.u32(44);
    w.str_ref(pool_base, s_fn_new.0, s_fn_new.1);    // name (Jac-visible)
    w.str_ref(pool_base, s_sym_new.0, s_sym_new.1);  // symbol (C ABI)
    w.u32(TAG_VOID);                                   // self_type
    w.u8(FN_CTOR); w.pad(3);
    w.u32(1);                                          // throws = type index 1
    w.u32(TAG_REF_BIT | 0);                           // ret = Regex (index 0)
    w.u32(252); w.u32(1);                             // params {offset, count}
    assert_eq!(w.pos(), 164, "FnDesc[0] size mismatch");

    // ===== FnDesc[1]: Regex_is_match (method) at 164, 44 bytes =====
    //   kind=METHOD  self_type=0(Regex)  throws=NONE  ret=BOOL
    //   params[264..264+12]: [{text, STR}]
    w.u32(44);
    w.str_ref(pool_base, s_fn_ism.0, s_fn_ism.1);
    w.str_ref(pool_base, s_sym_ism.0, s_sym_ism.1);
    w.u32(0);                     // self_type = Regex
    w.u8(FN_METHOD); w.pad(3);
    w.u32(TAG_VOID);              // throws = NONE
    w.u32(TAG_BOOL);              // ret = bool
    w.u32(264); w.u32(1);
    assert_eq!(w.pos(), 208, "FnDesc[1] size mismatch");

    // ===== FnDesc[2]: error_message (method on RegexError) at 208, 44 bytes =====
    //   kind=METHOD  self_type=1(RegexError)  throws=NONE  ret=STR (via JacBuf)
    //   params: none
    w.u32(44);
    w.str_ref(pool_base, s_fn_msg.0, s_fn_msg.1);
    w.str_ref(pool_base, s_sym_msg.0, s_sym_msg.1);
    w.u32(1);                     // self_type = RegexError
    w.u8(FN_METHOD); w.pad(3);
    w.u32(TAG_VOID);
    w.u32(TAG_STR);               // ret = str (returned as JacBuf out-param)
    w.u32(0); w.u32(0);           // params: none
    assert_eq!(w.pos(), 252, "FnDesc[2] size mismatch");

    // ===== ParamDesc[0]: {pattern: str} at 252, 12 bytes =====
    w.str_ref(pool_base, s_p_pattern.0, s_p_pattern.1); // name
    w.u32(TAG_STR);                                      // ty
    assert_eq!(w.pos(), 264, "ParamDesc[0] size mismatch");

    // ===== ParamDesc[1]: {text: str} at 264, 12 bytes =====
    w.str_ref(pool_base, s_p_text.0, s_p_text.1);
    w.u32(TAG_STR);
    assert_eq!(w.pos(), 276, "ParamDesc[1] size mismatch");

    // ===== String pool at 276, 155 bytes =====
    w.buf.extend_from_slice(&strings.pool);
    assert_eq!(w.pos(), total, "total blob size mismatch");

    w.buf
}
