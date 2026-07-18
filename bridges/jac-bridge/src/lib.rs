use jac_bridge_schema as schema;
use proc_macro::TokenStream;
use proc_macro2::{Literal, Span, TokenStream as TS2};
use quote::{format_ident, quote};
use syn::{
    parse_macro_input, Attribute, Error, Fields, FnArg, GenericArgument, Ident,
    ImplItem, Item, ItemMod, LitStr, Pat, PathArguments, ReturnType, Token,
    Type, parse::Parse, parse::ParseStream, spanned::Spanned,
};

// ─── data model ───────────────────────────────────────────────────────────────

#[derive(Clone, Copy, PartialEq, Eq)]
enum TypeKind { Opaque, Error }

struct TypeDef { name: Ident, kind: TypeKind }

/// Whether a typed wide record is a plain struct (fields are `name: value` map
/// entries) or a serde enum (each "field" is a variant: name + payload tag).
#[derive(Clone, Copy, PartialEq, Eq)]
enum RecordKind { Struct, Enum }

impl RecordKind {
    fn as_u32(self) -> u32 {
        match self {
            RecordKind::Struct => schema::RECORD_KIND_STRUCT,
            RecordKind::Enum => schema::RECORD_KIND_ENUM,
        }
    }
}

/// A typed wide record (2.9): a `#[jac_record]`-marked struct the binder emits for
/// an `#[automatically_derived]` serde type whose rustdoc fields ARE the msgpack
/// wire shape. Collected by [`analyze`] into the blob record table (name + field
/// tags); never a real opaque `TypeDef`. Field order == declaration order ==
/// msgpack map key order.
// For a struct record, `fields` are `(field_name, field_tag)` in declaration order
// (== msgpack map key order). For an enum record, each entry is a VARIANT:
// `(variant_name, payload_tag)` where the payload tag is `Tag::Void` for a unit
// variant, else the tag of the single newtype-variant field.
struct RecordDef { name: Ident, kind: RecordKind, fields: Vec<(String, Tag)> }

#[derive(Clone, PartialEq, Eq)]
enum Tag { Bool, Int, Uint, F64, Str, Bytes, Void, Ref(usize), Opt(Box<Tag>), Callback, Map(Box<Tag>), List(Box<Tag>), Wide(u32) }

impl Tag {
    fn as_u32(&self) -> u32 {
        match self {
            Tag::Bool     => schema::TAG_BOOL,
            Tag::Int      => schema::TAG_INT,
            Tag::Uint     => schema::TAG_UINT,
            Tag::F64      => schema::TAG_F64,
            Tag::Str      => schema::TAG_STR,
            Tag::Bytes    => schema::TAG_BYTES,
            Tag::Void     => schema::TAG_VOID,
            Tag::Ref(i)   => schema::TAG_REF_BIT | (*i as u32),
            Tag::Opt(inner) => schema::TAG_OPT_BIT | inner.as_u32(),
            Tag::Callback => schema::TAG_FN,
            Tag::Map(value) => schema::TAG_MAP_BIT | value.as_u32(),
            Tag::List(elem) => schema::TAG_LIST_BIT | elem.as_u32(),
            // The serde wide lane: any `Serialize`/`Deserialize` type crosses as a
            // self-describing MessagePack payload behind ONE tag. Composition
            // (Option/nesting/containers) lives INSIDE the payload, so the wire is
            // one msgpack blob regardless. The optional 1-based RECORD ID (2.9)
            // rides the tag's upper bits: 0 = dynamic document, else it indexes the
            // blob record table so the loader synthesizes a typed object.
            Tag::Wide(id)   => schema::TAG_WIDE | (id << schema::TAG_WIDE_REC_SHIFT),
        }
    }
}

/// Map a Rust integer type name to its boundary tag, if it is one.  All widths
/// cross as a single 64-bit slot; only the sign discipline (`TAG_INT` vs
/// `TAG_UINT`) is preserved so the loader decodes correctly.
fn int_tag_for(name: &str) -> Option<Tag> {
    match name {
        "i8" | "i16" | "i32" | "i64" | "isize" => Some(Tag::Int),
        "u8" | "u16" | "u32" | "u64" | "usize" => Some(Tag::Uint),
        _ => None,
    }
}

/// Map a Rust float type name to its boundary tag, if it is one.  Both widths
/// cross as a single 64-bit slot carrying the `f64` bit pattern (an `f32` is
/// widened to `f64` first), so only [`TAG_F64`](schema::TAG_F64) is needed.
fn float_tag_for(name: &str) -> Option<Tag> {
    match name {
        "f32" | "f64" => Some(Tag::F64),
        _ => None,
    }
}

struct Param {
    name:       String,
    tag:        Tag,
    is_str_ref: bool, // &str (ptr+len at boundary) vs String (single ptr)
    /// For an integer param, the concrete Rust type (`u32`, `i64`, …) the u64
    /// boundary slot must be cast back to before the call.  `None` otherwise.
    int_ty:     Option<String>,
    /// For a float param, the concrete Rust type (`f32`, `f64`) the reconstructed
    /// `f64` must be narrowed to before the call.  `None` otherwise.
    float_ty:   Option<String>,
}

/// Ownership class of an opaque-handle return (Phase S, Track B).  Rides the
/// `Ref` return tag as append-only high bits; the default (`Owned`) is the frozen
/// v1 behaviour and emits no bit, so every existing bridge stays byte-identical.
///
/// `Shared` is RETIRED as a producer (Phase 1.2.4) — no macro path constructs it
/// (see [`parse_ownership`]).  The variant and `TAG_SHARED_BIT` stay defined so the
/// ABI bit remains reserved/frozen (append-only) and the loader's shared branch is
/// still pinned by the `test_shared_identity_retain` loader fixture; a co-owned
/// handle is now produced only by a `&Self` return (self-identity), never a bit.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Ownership { Owned, #[allow(dead_code)] Shared, Borrowed }

impl Ownership {
    /// Tag bits OR'd into the `Ref` return tag.  `Owned` = 0 (byte-identical v1).
    fn bits(self) -> u32 {
        match self {
            Ownership::Owned    => 0,
            Ownership::Shared   => schema::TAG_SHARED_BIT,
            Ownership::Borrowed => schema::TAG_BORROW_BIT,
        }
    }
}

struct FnDef {
    jac_name:      String,
    c_sym:         String,
    kind:          u8,          // 0=ctor, 1=method
    self_idx:      Option<usize>,
    params:        Vec<Param>,
    ret:           Tag,
    ownership:     Ownership,   // Phase S: owned (default) / shared / borrowed return
    throws:        Option<usize>,
    rust_ident:    Ident,
    impl_type_i:   usize,
    ret_is_result: bool,
    // Phase 1.2.4 (self-identity): the method returns `&Self` (or `&OwnType`), so
    // the return IS the receiver's own handle box, not a fresh one.  The shim
    // writes `handle` straight back (no `Box::into_raw`), and the na loader's
    // runtime `rh == self.__handle` guard fires and RC-pins the shared box.  This
    // is the ONLY sound producer of a retain-on-adopt handle: the alias is proven
    // at runtime, never trusted from an annotation (why `#[jac(shared)]` is gone).
    ret_is_self_borrow: bool,
    self_is_mut:   bool,
    is_auto:       bool,        // auto-generated error_message shim
    is_async:      bool,        // async fn — shim blocks via module-owned Tokio runtime
}

// ─── entry point ──────────────────────────────────────────────────────────────

#[proc_macro_attribute]
pub fn bridge(attr: TokenStream, item: TokenStream) -> TokenStream {
    let module_name = match parse_module_name(attr) {
        Ok(n)  => n,
        Err(e) => return e.to_compile_error().into(),
    };
    let input = parse_macro_input!(item as ItemMod);
    match expand(module_name, input) {
        Ok(ts) => ts.into(),
        Err(e)  => e.to_compile_error().into(),
    }
}

struct BridgeAttr { name: String }
impl Parse for BridgeAttr {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        // 0.2.4: reject an unknown key with a spanned error rather than silently
        // ignoring the name and defaulting the module to "bridge".
        let key: Ident = input.parse()?;
        if key != "module" {
            return Err(Error::new(key.span(),
                format!("unknown `#[bridge(...)]` key `{key}`; expected `module`")));
        }
        let _eq: Token![=] = input.parse()?;
        let lit: LitStr = input.parse()?;
        Ok(BridgeAttr { name: lit.value() })
    }
}

fn parse_module_name(attr: TokenStream) -> Result<String, Error> {
    // A bare `#[bridge]` (no args) keeps the historical "bridge" default; a
    // non-empty attribute must be a well-formed `module = "..."`.
    if attr.is_empty() {
        return Ok("bridge".to_string());
    }
    syn::parse::<BridgeAttr>(attr).map(|a| a.name)
}

// ─── expansion ────────────────────────────────────────────────────────────────

fn expand(module_name: String, input: ItemMod) -> Result<TS2, Error> {
    let span = input.ident.span();
    let items = match &input.content {
        Some((_, it)) => it.clone(),
        None => return Err(Error::new(span,
            "#[jac_bridge::bridge] requires an inline module: mod name { ... }")),
    };

    let (types, records, fns) = analyze(&module_name, &items, span)?;
    let blob      = build_blob(&module_name, &types, &records, &fns);
    let static_ts = gen_static(&blob, &module_name);
    let shims_ts  = gen_shims(&module_name, &types, &fns, &input.ident);

    // Strip bridge-only helper attrs (#[jac_error] on structs, #[jac(...)] on
    // impl methods) before re-emitting — they are metadata for this macro, not
    // real Rust attributes the compiler understands.
    let mut cleaned: Vec<TS2> = items.iter().map(strip_bridge_attrs).collect();

    // A bridge fn that names `JacCallback` as a param needs the type in scope
    // inside the re-emitted module; it lives in the sibling rt module.  Inject
    // the `use` only when a callback is present so callback-free bridges stay
    // byte-identical (no new imports).
    let has_callback = fns.iter().any(|f| f.params.iter().any(|p| p.tag == Tag::Callback));
    if has_callback {
        let rt = format_ident!("__jac_bridge_{module_name}_rt");
        cleaned.insert(0, quote! {
            #[allow(unused_imports)]
            use super::#rt::JacCallback;
        });
    }

    // The serde wide lane: the binder writes `Wide<T>` in the re-emitted wrapper
    // signatures, so the newtype must be in scope inside the module.  It lives in
    // the sibling rt module; inject the `use` only when a wide value is present so
    // wide-free bridges stay byte-identical (mirrors the JacCallback import above).
    let has_wide = fns.iter().any(|f|
        matches!(f.ret, Tag::Wide(_)) || f.params.iter().any(|p| matches!(p.tag, Tag::Wide(_))));
    if has_wide {
        let rt = format_ident!("__jac_bridge_{module_name}_rt");
        cleaned.insert(0, quote! {
            #[allow(unused_imports)]
            use super::#rt::Wide;
        });
    }

    let vis       = &input.vis;
    let mod_attrs = &input.attrs;
    let mod_name  = &input.ident;

    Ok(quote! {
        #(#mod_attrs)*
        #vis mod #mod_name { #(#cleaned)* }
        #static_ts
        #shims_ts
    })
}

fn strip_bridge_attrs(item: &Item) -> TS2 {
    if let Item::Struct(s) = item {
        if has_attr(&s.attrs, "jac_error") {
            let mut s2 = s.clone();
            s2.attrs.retain(|a| !a.path().is_ident("jac_error"));
            // The error type is a name-only marker for D2 metadata; error handles
            // are Box<String> at runtime, so the struct is never constructed.
            return quote! { #[allow(dead_code)] #s2 };
        }
        if has_attr(&s.attrs, "jac_record") {
            let mut s2 = s.clone();
            s2.attrs.retain(|a| !a.path().is_ident("jac_record"));
            // A typed wide record (2.9) is pure metadata for the blob record table —
            // its field shape mirrors the foreign serde struct, but nothing here
            // constructs it (the wrapper marshals `Wide<foreign::T>`). Emit it inert
            // so the field types stay compile-checked without an unused warning.
            return quote! { #[allow(dead_code)] #s2 };
        }
    }
    // A `#[jac_record]` enum (2.9-followup) is likewise pure record-table metadata.
    if let Item::Enum(e) = item {
        if has_attr(&e.attrs, "jac_record") {
            let mut e2 = e.clone();
            e2.attrs.retain(|a| !a.path().is_ident("jac_record"));
            return quote! { #[allow(dead_code)] #e2 };
        }
    }
    // Strip the per-method `#[jac(...)]` ownership annotation from every method in
    // an inherent impl; it is consumed by `analyze_fn` (parse_ownership) and would
    // otherwise reach rustc as an unknown attribute.
    if let Item::Impl(imp) = item {
        if imp.trait_.is_none()
            && imp.items.iter().any(|ii| matches!(ii, ImplItem::Fn(f) if has_attr(&f.attrs, "jac")))
        {
            let mut imp2 = imp.clone();
            for ii in &mut imp2.items {
                if let ImplItem::Fn(f) = ii {
                    f.attrs.retain(|a| !a.path().is_ident("jac"));
                }
            }
            return quote! { #imp2 };
        }
    }
    quote! { #item }
}

fn has_attr(attrs: &[Attribute], name: &str) -> bool {
    attrs.iter().any(|a| a.path().is_ident(name))
}

// ─── analysis ─────────────────────────────────────────────────────────────────

fn analyze(
    module_name: &str,
    items: &[Item],
    span: Span,
) -> Result<(Vec<TypeDef>, Vec<RecordDef>, Vec<FnDef>), Error> {
    // A `#[jac_record]` struct/enum is a typed wide record (2.9), never an opaque
    // type. Record resolution is TWO passes because a record field may be ANOTHER
    // record (a nested `Region { tl: Point }`), so every record name must be known
    // before any field is resolved to a `Tag::Wide(id)`.
    //
    // Pass 1: collect opaque/error `types` and record STUBS (name + kind, no fields
    // yet). Pass 2 (below) resolves each record's fields/variants against the full
    // stub list so nested-record ids resolve.
    let mut types: Vec<TypeDef> = Vec::new();
    let mut record_stubs: Vec<RecordDef> = Vec::new();
    for item in items {
        match item {
            Item::Struct(s) => {
                if has_attr(&s.attrs, "jac_record") {
                    record_stubs.push(RecordDef {
                        name: s.ident.clone(),
                        kind: RecordKind::Struct,
                        fields: vec![],
                    });
                } else {
                    let kind = if has_attr(&s.attrs, "jac_error") { TypeKind::Error } else { TypeKind::Opaque };
                    types.push(TypeDef { name: s.ident.clone(), kind });
                }
            }
            Item::Enum(e) if has_attr(&e.attrs, "jac_record") => {
                record_stubs.push(RecordDef {
                    name: e.ident.clone(),
                    kind: RecordKind::Enum,
                    fields: vec![],
                });
            }
            _ => {}
        }
    }

    // Pass 2: resolve each record's fields (nested-record ids resolve against the
    // stub names collected in pass 1).
    let mut records: Vec<RecordDef> = Vec::new();
    for item in items {
        match item {
            Item::Struct(s) if has_attr(&s.attrs, "jac_record") => {
                records.push(analyze_record_struct(s, &types, &record_stubs)?);
            }
            Item::Enum(e) if has_attr(&e.attrs, "jac_record") => {
                records.push(analyze_record_enum(e, &types, &record_stubs)?);
            }
            _ => {}
        }
    }

    if types.iter().filter(|t| t.kind == TypeKind::Error).count() > 1 {
        return Err(Error::new(span, "bridge module must have at most one #[jac_error] type"));
    }
    let error_idx = types.iter().position(|t| t.kind == TypeKind::Error);

    let mut fns: Vec<FnDef> = Vec::new();
    for item in items {
        let Item::Impl(imp) = item else { continue };
        if imp.trait_.is_some() { continue }

        let type_name = impl_type_name(imp)?;
        let type_i = types.iter().position(|t| t.name == type_name)
            .ok_or_else(|| Error::new(imp.self_ty.span(),
                format!("`impl {type_name}` — not defined in this bridge module")))?;

        for ii in &imp.items {
            let ImplItem::Fn(f) = ii else { continue };
            if !matches!(f.vis, syn::Visibility::Public(_)) { continue }
            fns.push(analyze_fn(f, type_i, &types, &records, error_idx, module_name)?);
        }
    }

    // Auto-generate the D2 entry for error_message
    if let Some(err_i) = error_idx {
        fns.push(FnDef {
            jac_name:      "message".into(),
            c_sym:         format!("jac_{module_name}_error_message"),
            kind:          schema::FN_METHOD,
            self_idx:      Some(err_i),
            params:        vec![],
            ret:           Tag::Str,
            ownership:     Ownership::Owned,
            throws:        None,
            rust_ident:    Ident::new("__auto", Span::call_site()),
            impl_type_i:   err_i,
            ret_is_result: false,
            ret_is_self_borrow: false,
            self_is_mut:   false,
            is_auto:       true,
            is_async:      false,
        });
    }

    Ok((types, records, fns))
}

/// The tag of a `#[jac_record]` FIELD type. Unlike a method param/return (where a
/// value type is wrapped in `Wide<T>` by the binder), a record field spells its type
/// directly, so this recurses the type structure itself:
///   * `Option<T>` → `Tag::Opt(tag(T))`
///   * `Vec<T>`    → `Tag::List(tag(T))`
///   * `HashMap<String,V>` / `BTreeMap<String,V>` → `Tag::Map(tag(V))`
///   * a scalar / `String`  → the scalar tag
///   * a path naming another record → `Tag::Wide(id)` (a nested typed record)
/// Anything else (a tuple, a foreign non-record type, a non-`String`-keyed map) is
/// an error: the binder must keep such a record on the dynamic wide lane instead.
fn field_ty_to_tag(ty: &Type, types: &[TypeDef], records: &[RecordDef]) -> Result<Tag, Error> {
    if let Some(inner) = option_inner(ty) {
        return Ok(Tag::Opt(Box::new(field_ty_to_tag(inner, types, records)?)));
    }
    if let Some(elem) = extract_vec(ty) {
        return Ok(Tag::List(Box::new(field_ty_to_tag(elem, types, records)?)));
    }
    if let Some((k, v)) = extract_stringkey_map(ty) {
        // A msgpack map crosses with string keys only; a non-`String` key can't be
        // a typed record field.
        let Type::Path(kp) = k else {
            return Err(Error::new(k.span(), "#[jac_record] map field must have String keys"));
        };
        if kp.path.segments.last().map(|s| s.ident != "String").unwrap_or(true) {
            return Err(Error::new(k.span(), "#[jac_record] map field must have String keys"));
        }
        return Ok(Tag::Map(Box::new(field_ty_to_tag(v, types, records)?)));
    }
    // A scalar / String / nested-record path.
    if let Type::Path(tp) = ty {
        if let Some(seg) = tp.path.segments.last() {
            let id_str = seg.ident.to_string();
            match id_str.as_str() {
                "bool" => return Ok(Tag::Bool),
                "String" => return Ok(Tag::Str),
                _ => {
                    if let Some(t) = int_tag_for(&id_str) { return Ok(t); }
                    if let Some(t) = float_tag_for(&id_str) { return Ok(t); }
                    if let Some(i) = records.iter().position(|r| r.name == seg.ident) {
                        return Ok(Tag::Wide((i + 1) as u32));
                    }
                }
            }
        }
    }
    let _ = types;
    Err(Error::new(ty.span(), format!(
        "#[jac_record] field type `{}` is not a scalar/String, a nested #[jac_record], \
         or a container of those; keep this record on the dynamic wide lane", quote!(#ty))))
}

/// Parse a `#[jac_record]` struct into a [`RecordDef`]: each named field becomes
/// `(name, tag)` in declaration order (== msgpack map key order). Field types may be
/// scalars/`String`, nested records, or `Option`/`Vec`/`Map` of those (2.9-followup).
fn analyze_record_struct(
    s: &syn::ItemStruct, types: &[TypeDef], records: &[RecordDef],
) -> Result<RecordDef, Error> {
    let Fields::Named(named) = &s.fields else {
        return Err(Error::new(s.ident.span(),
            "#[jac_record] requires a struct with named fields"));
    };
    let mut fields = Vec::new();
    for f in &named.named {
        let fname = f.ident.as_ref()
            .ok_or_else(|| Error::new(f.span(), "#[jac_record] field must be named"))?
            .to_string();
        fields.push((fname, field_ty_to_tag(&f.ty, types, records)?));
    }
    Ok(RecordDef { name: s.ident.clone(), kind: RecordKind::Struct, fields })
}

/// Parse a `#[jac_record]` enum into a [`RecordDef`] of kind [`RecordKind::Enum`]:
/// each variant becomes `(variant_name, payload_tag)`. A unit variant carries
/// `Tag::Void`; a newtype variant `V(T)` carries `tag(T)` (scalar / nested-record /
/// container). Struct-payload (`V { .. }`) and multi-field tuple variants are
/// rejected — the binder keeps such an enum on the dynamic lane (a later slice).
fn analyze_record_enum(
    e: &syn::ItemEnum, types: &[TypeDef], records: &[RecordDef],
) -> Result<RecordDef, Error> {
    let mut variants = Vec::new();
    for v in &e.variants {
        let vname = v.ident.to_string();
        let tag = match &v.fields {
            Fields::Unit => Tag::Void,
            Fields::Unnamed(u) if u.unnamed.len() == 1 => {
                field_ty_to_tag(&u.unnamed[0].ty, types, records)?
            }
            _ => return Err(Error::new(v.span(),
                "#[jac_record] enum variant must be a unit or single-field (newtype) \
                 variant; struct/tuple-payload variants keep the enum on the dynamic lane")),
        };
        variants.push((vname, tag));
    }
    Ok(RecordDef { name: e.ident.clone(), kind: RecordKind::Enum, fields: variants })
}

fn impl_type_name(imp: &syn::ItemImpl) -> Result<Ident, Error> {
    if let Type::Path(tp) = &*imp.self_ty {
        if tp.path.segments.len() == 1 {
            return Ok(tp.path.segments[0].ident.clone());
        }
    }
    Err(Error::new(imp.self_ty.span(), "expected a simple type name in impl"))
}

fn analyze_fn(
    f: &syn::ImplItemFn,
    type_i: usize,
    types: &[TypeDef],
    records: &[RecordDef],
    error_idx: Option<usize>,
    module_name: &str,
) -> Result<FnDef, Error> {
    let name = f.sig.ident.to_string();

    let (has_self, self_is_mut) = match f.sig.inputs.first() {
        Some(FnArg::Receiver(r)) => (true, r.mutability.is_some()),
        _ => (false, false),
    };
    // `#[jac(assoc)]` marks a no-receiver fn as a STATIC (an extra factory or a
    // non-`Self` associated fn) rather than THE constructor.  A receiver + assoc
    // is a contradiction the binder never emits, but reject it defensively so a
    // hand-written bridge can't silently mislabel a method.
    let is_assoc = parse_is_assoc(&f.attrs)?;
    if is_assoc && has_self {
        return Err(Error::new(f.sig.ident.span(),
            "#[jac(assoc)] marks a no-receiver associated function; this fn has a `self` receiver"));
    }
    let kind: u8 = if has_self {
        schema::FN_METHOD
    } else if is_assoc {
        schema::FN_STATIC
    } else {
        schema::FN_CTOR
    };

    let params: Vec<Param> = f.sig.inputs.iter()
        .filter(|a| !matches!(a, FnArg::Receiver(_)))
        .map(|a| analyze_param(a, types, records))
        .collect::<Result<_, _>>()?;

    let (ret, throws, ret_is_result, ret_is_self_borrow) =
        analyze_ret(&f.sig.output, types, records, type_i, has_self, error_idx)?;

    let ownership = parse_ownership(&f.attrs)?;
    // The ownership contract only governs opaque-handle returns, and `borrowed`
    // additionally needs a receiver to retain (the owner the view pins).  Reject
    // the annotation on anything else so a misplaced `#[jac(borrowed)]` is a
    // compile error, not a silently-ignored no-op that emits an owned handle.
    if ownership != Ownership::Owned {
        if !matches!(ret, Tag::Ref(_) | Tag::Opt(_)) {
            return Err(Error::new(f.sig.output.span(),
                "#[jac(borrowed)] applies only to a method returning \
                 an opaque handle (a crate type or Option<crate type>)"));
        }
        if ret_is_self_borrow {
            return Err(Error::new(f.sig.output.span(),
                "#[jac(borrowed)] does not apply to a `&Self` return — a self-identity \
                 handle is already RC-pinned by the loader's `rh == self` guard; drop \
                 the attribute (a `&Self` return needs no ownership annotation)"));
        }
        if ownership == Ownership::Borrowed && !has_self {
            return Err(Error::new(f.sig.ident.span(),
                "#[jac(borrowed)] needs a `&self` receiver — a borrowed view retains \
                 the owner it views into; a constructor has no owner to pin"));
        }
    }

    let type_name = types[type_i].name.to_string();
    let c_sym = match types[type_i].kind {
        TypeKind::Error  => format!("jac_{module_name}_error_{name}"),
        TypeKind::Opaque => format!("jac_{module_name}_{type_name}_{name}"),
    };

    Ok(FnDef {
        jac_name: name, c_sym, kind,
        // A method's `self_idx` is its receiver type; a STATIC carries the OWNING
        // type index (so the loader can place it on that type) even though it
        // takes no handle; a ctor carries none (its type is read off the return).
        self_idx: if has_self || is_assoc { Some(type_i) } else { None },
        params, ret, ownership, throws,
        rust_ident: f.sig.ident.clone(),
        impl_type_i: type_i,
        ret_is_result, ret_is_self_borrow, self_is_mut,
        is_auto: false,
        is_async: f.sig.asyncness.is_some(),
    })
}

/// Read a method's ownership class from a `#[jac(borrowed)]` helper attribute.
/// Absent (or `#[jac(owned)]`) is the default `Owned`.  The attribute is stripped
/// from the re-emitted source by [`strip_bridge_attrs`].
///
/// `#[jac(shared)]` is REJECTED (Phase 1.2.4).  A shared handle asks the loader to
/// `retain(rh)` unconditionally on adopt, but the macro boxes every return fresh
/// (rc = 1); a fresh box that is retained but held by a single wrapper leaks (its
/// one close drops rc 2→1, never 0).  The retain was sound only if `rh` were an
/// EXISTING box some other live wrapper also holds — an aliasing fact nothing
/// checks, so the annotation was leak-by-construction.  The one alias the macro
/// can PROVE is `&self -> &Self`: return the receiver's own box, which the loader
/// RC-pins behind a runtime `rh == self.__handle` guard.  So a co-owned handle is
/// expressed by returning `&Self`, never asserted with `#[jac(shared)]`.
fn parse_ownership(attrs: &[Attribute]) -> Result<Ownership, Error> {
    Ok(parse_jac_attr(attrs)?.0)
}

/// True when the method carries `#[jac(assoc)]` — a no-receiver associated
/// function the binder emits as a STATIC (an extra `-> Self` factory or a
/// non-`Self` static like `Sha256::digest`), distinct from THE constructor.
fn parse_is_assoc(attrs: &[Attribute]) -> Result<bool, Error> {
    Ok(parse_jac_attr(attrs)?.1)
}

/// Parse the per-method `#[jac(...)]` helper attribute into `(ownership,
/// is_assoc)`.  Recognised keys: `owned`/`borrowed` (ownership class) and `assoc`
/// (mark a no-receiver fn as a static).  `assoc` alone is valid — a static is
/// always `Owned`, so it needs no ownership key.  `shared` is retired.
fn parse_jac_attr(attrs: &[Attribute]) -> Result<(Ownership, bool), Error> {
    let mut ownership = Ownership::Owned;
    let mut is_assoc = false;
    for a in attrs {
        if !a.path().is_ident("jac") { continue }
        let mut cls = None;
        let mut saw_assoc = false;
        a.parse_nested_meta(|m| {
            if m.path.is_ident("owned")    { cls = Some(Ownership::Owned);    Ok(()) }
            else if m.path.is_ident("borrowed") { cls = Some(Ownership::Borrowed); Ok(()) }
            else if m.path.is_ident("assoc") { saw_assoc = true; Ok(()) }
            else if m.path.is_ident("shared") {
                Err(m.error("#[jac(shared)] is retired: an unconditional retain-on-adopt \
                    leaks a fresh handle box.  Return `&Self` for a co-owned (self-identity) \
                    handle — the loader RC-pins it behind a runtime `rh == self` guard that \
                    proves the alias instead of trusting the annotation"))
            }
            else { Err(m.error("unknown #[jac(...)] key: expected owned, borrowed, or assoc")) }
        })?;
        if saw_assoc { is_assoc = true; }
        if let Some(c) = cls { ownership = c; }
        else if !saw_assoc {
            return Err(Error::new(a.span(),
                "#[jac(...)] requires a key: #[jac(owned)], #[jac(borrowed)], or #[jac(assoc)]"));
        }
    }
    Ok((ownership, is_assoc))
}

fn analyze_param(arg: &FnArg, types: &[TypeDef], records: &[RecordDef]) -> Result<Param, Error> {
    let FnArg::Typed(pt) = arg else {
        return Err(Error::new(arg.span(), "unexpected self"));
    };
    let name = match &*pt.pat {
        Pat::Ident(pi) => pi.ident.to_string(),
        _ => return Err(Error::new(pt.pat.span(), "expected a plain param name")),
    };
    let (tag, is_str_ref) = ty_to_tag(&pt.ty, types, records)?;
    let int_ty = match &tag {
        Tag::Int | Tag::Uint => simple_ident(&pt.ty),
        _ => None,
    };
    let float_ty = match &tag {
        Tag::F64 => simple_ident(&pt.ty),
        _ => None,
    };
    Ok(Param { name, tag, is_str_ref, int_ty, float_ty })
}

/// The trailing path identifier of a plain (possibly `&`-referenced) type, e.g.
/// `u32` from `u32` or `&i64`.  Used to recover an integer param's concrete type.
fn simple_ident(ty: &Type) -> Option<String> {
    match ty {
        Type::Reference(tr) => simple_ident(&tr.elem),
        Type::Path(tp) if tp.path.segments.len() == 1 => {
            Some(tp.path.segments[0].ident.to_string())
        }
        _ => None,
    }
}

fn ty_to_tag(ty: &Type, types: &[TypeDef], records: &[RecordDef]) -> Result<(Tag, bool), Error> {
    // The serde wide lane: `Wide<T>` crosses as a MessagePack payload on the same
    // (ptr, len) two-slot boundary as `&str`/`&[u8]`, but the second field of the
    // returned pair is `false` — the wide arm in the param codegen owns the two
    // C slots explicitly, so it is NOT flagged as a str/bytes wide-boundary param.
    if is_wide_marker(ty) {
        return Ok((Tag::Wide(wide_record_id(ty, records)), false));
    }
    match ty {
        Type::Reference(tr) => {
            if let Type::Path(tp) = &*tr.elem {
                if tp.path.is_ident("str") { return Ok((Tag::Str, true)); }
            }
            // `&[u8]` — a byte slice param crosses (ptr, len) exactly like `&str`
            // (the `true` flags the wide boundary shape), but decodes as raw bytes
            // with no UTF-8 validation. The sha2 `update(&mut self, &[u8])` carrier.
            if let Type::Slice(ts) = &*tr.elem {
                if let Type::Path(tp) = &*ts.elem {
                    if tp.path.is_ident("u8") { return Ok((Tag::Bytes, true)); }
                }
            }
            let (tag, _) = ty_to_tag(&tr.elem, types, records)?;
            Ok((tag, false))
        }
        Type::Path(tp) if tp.path.segments.len() == 1 => {
            let id = &tp.path.segments[0].ident;
            let id_str = id.to_string();
            match id_str.as_str() {
                "bool"        => Ok((Tag::Bool, false)),
                "String"      => Ok((Tag::Str,  false)),
                "str"         => Ok((Tag::Str,  true)),
                // A callback param: the Jac side supplies a C-ABI function
                // pointer (fn(*const u8, u32, *mut JacBuf, *mut u64) -> i32).
                // Crosses as a single u64; decoded into the rt `JacCallback`.
                "JacCallback" => Ok((Tag::Callback, false)),
                _ => {
                    if let Some(tag) = int_tag_for(&id_str) {
                        Ok((tag, false))
                    } else if let Some(tag) = float_tag_for(&id_str) {
                        Ok((tag, false))
                    } else if let Some(i) = types.iter().position(|t| &t.name == id) {
                        Ok((Tag::Ref(i), false))
                    } else {
                        Err(Error::new(ty.span(),
                            format!("unsupported bridge type: `{}`", quote!(#ty))))
                    }
                }
            }
        }
        Type::Tuple(tt) if tt.elems.is_empty() => Ok((Tag::Void, false)),
        _ => Err(Error::new(ty.span(), format!("unsupported bridge type: `{}`", quote!(#ty)))),
    }
}

fn analyze_ret(
    ret: &ReturnType,
    types: &[TypeDef],
    records: &[RecordDef],
    self_i: usize,
    has_self: bool,
    error_idx: Option<usize>,
) -> Result<(Tag, Option<usize>, bool, bool), Error> {
    let ReturnType::Type(_, ty) = ret else {
        return Ok((Tag::Void, None, false, false));
    };
    // A `&self` method returning `&Self` (or `&OwnType`) is a self-identity handle:
    // the return IS the receiver's box, so it lowers to the receiver's own handle
    // integer rather than a fresh `Box::into_raw`.  Checked before `extract_result`
    // — a reference return is never a `Result`, and `ret_tag` still rejects every
    // other reference (only `&str` is a value; `&T` to a foreign type would be a
    // type-confused drop).  It carries the plain `Ref(self_i)` tag (no bit): the
    // loader keys the retain on `ret_index == self_type`, guarded at runtime.
    if is_self_borrow_ret(ty, self_i, has_self, types) {
        return Ok((Tag::Ref(self_i), None, false, true));
    }
    if let Some((ok_ty, _)) = extract_result(ty) {
        let ok_tag = ret_tag(ok_ty, types, records, self_i)?;
        if error_idx.is_none() {
            return Err(Error::new(ty.span(),
                "function returns Result but the bridge module has no #[jac_error] type; \
                 add a #[jac_error] struct so callers can retrieve the error message"));
        }
        return Ok((ok_tag, error_idx, true, false));
    }
    let tag = ret_tag(ty, types, records, self_i)?;
    Ok((tag, None, false, false))
}

/// True when `ty` is `&Self` or `&OwnType` on a `&self` method — a self-identity
/// return.  The borrowed reference has the receiver's lifetime, so it IS the
/// receiver's own handle box; the shim writes the receiver handle straight back.
fn is_self_borrow_ret(ty: &Type, self_i: usize, has_self: bool, types: &[TypeDef]) -> bool {
    if !has_self { return false; }
    let Type::Reference(tr) = ty else { return false; };
    let Type::Path(tp) = &*tr.elem else { return false; };
    if tp.path.is_ident("Self") { return true; }
    tp.path.segments.len() == 1 && tp.path.segments[0].ident == types[self_i].name
}

fn extract_result(ty: &Type) -> Option<(&Type, &Type)> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "Result" { return None; }
    if let PathArguments::AngleBracketed(args) = &seg.arguments {
        let tys: Vec<_> = args.args.iter()
            .filter_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
            .collect();
        if tys.len() == 2 { return Some((tys[0], tys[1])); }
    }
    None
}

/// The `(key, value)` type arguments of a `HashMap<K, V>` path, if `ty` is one.
/// Matches both the bare `HashMap<..>` and a fully-qualified
/// `std::collections::HashMap<..>` (last segment ident is what counts).
fn extract_hashmap(ty: &Type) -> Option<(&Type, &Type)> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "HashMap" { return None; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return None };
    let tys: Vec<_> = args.args.iter()
        .filter_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
        .collect();
    if tys.len() == 2 { Some((tys[0], tys[1])) } else { None }
}

/// The `(key, value)` type arguments of a `HashMap<K, V>` OR `BTreeMap<K, V>` path,
/// if `ty` is one — the two string-keyed map shapes a typed record field admits
/// (their msgpack image is identical: a map). Last segment ident is what counts.
fn extract_stringkey_map(ty: &Type) -> Option<(&Type, &Type)> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "HashMap" && seg.ident != "BTreeMap" { return None; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return None };
    let tys: Vec<_> = args.args.iter()
        .filter_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
        .collect();
    if tys.len() == 2 { Some((tys[0], tys[1])) } else { None }
}

/// The single element type argument of a `Vec<T>` path, if `ty` is one.
/// Matches both the bare `Vec<..>` and a fully-qualified `std::vec::Vec<..>`
/// (last segment ident is what counts).
fn extract_vec(ty: &Type) -> Option<&Type> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "Vec" { return None; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return None };
    let tys: Vec<_> = args.args.iter()
        .filter_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
        .collect();
    if tys.len() == 1 { Some(tys[0]) } else { None }
}

/// True when `ty` is the serde wide-lane marker `Wide<T>` (last path segment
/// `Wide` with exactly one type argument). The binder wraps a value type in this
/// newtype in generated source to route it through the MessagePack lane; the macro
/// classifies it as [`Tag::Wide`] and marshals the inner `T` via serde. The inner
/// type is never read here — `rmp_serde` decode/encode infer `T` from the wrapper
/// fn's own signature at the call site — so this only reports presence.
fn is_wide_marker(ty: &Type) -> bool {
    let Type::Path(tp) = ty else { return false };
    let Some(seg) = tp.path.segments.last() else { return false };
    if seg.ident != "Wide" { return false; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return false };
    args.args.iter()
        .filter(|a| matches!(a, GenericArgument::Type(_)))
        .count() == 1
}

/// The single type argument `T` of a `Wide<T>` marker, if `ty` is one.
fn wide_inner(ty: &Type) -> Option<&Type> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "Wide" { return None; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return None };
    args.args.iter().find_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
}

/// The 1-based record id for a `Wide<Inner>` marker: `Inner`'s last path segment
/// (`demo::Point` → `Point`) matched by name against the collected typed records.
/// `0` when the inner is not a typed record (a bare `serde_json::Value`, a nested
/// std container, or a manual-serde type the binder left un-emitted) — that value
/// keeps the dynamic wide lane. 2.9: the binder emits a `#[jac_record]` struct
/// for exactly the derived-record shapes whose rustdoc fields ARE the wire shape.
fn wide_record_id(ty: &Type, records: &[RecordDef]) -> u32 {
    let Some(inner) = wide_inner(ty) else { return 0 };
    let Type::Path(tp) = inner else { return 0 };
    let Some(seg) = tp.path.segments.last() else { return 0 };
    records
        .iter()
        .position(|r| r.name == seg.ident)
        .map(|i| (i + 1) as u32)
        .unwrap_or(0)
}

/// The single type argument of an `Option<T>` path, if `ty` is one.
fn option_inner(ty: &Type) -> Option<&Type> {
    let Type::Path(tp) = ty else { return None };
    let seg = tp.path.segments.last()?;
    if seg.ident != "Option" { return None; }
    let PathArguments::AngleBracketed(args) = &seg.arguments else { return None };
    let tys: Vec<_> = args.args.iter()
        .filter_map(|a| if let GenericArgument::Type(t) = a { Some(t) } else { None })
        .collect();
    if tys.len() == 1 { Some(tys[0]) } else { None }
}

fn ret_tag(ty: &Type, types: &[TypeDef], records: &[RecordDef], self_i: usize) -> Result<Tag, Error> {
    // The serde wide lane: `Wide<T>` returns as an owned JacBuf holding the
    // MessagePack image of `T`. Checked first — a `Wide<..>` path must never be
    // mistaken for an opaque type reference by the generic Path arms below.
    if is_wide_marker(ty) {
        return Ok(Tag::Wide(wide_record_id(ty, records)));
    }
    // HashMap<String, V> marshals as a real Jac dict[str, V] (str keys in v1).
    // Checked before the generic Path arms so the `HashMap` ident is not mistaken
    // for an opaque type reference.
    if let Some((key_ty, val_ty)) = extract_hashmap(ty) {
        let key_ok = matches!(key_ty, Type::Path(tp)
            if tp.path.segments.last().map(|s| s.ident == "String").unwrap_or(false));
        if !key_ok {
            return Err(Error::new(key_ty.span(),
                "unsupported HashMap key type: only HashMap<String, V> is bridgeable \
                 (keys marshal as Jac str)"));
        }
        let val_tag = ret_tag(val_ty, types, records, self_i)?;
        match val_tag {
            Tag::Bool | Tag::Int | Tag::Uint | Tag::Str =>
                return Ok(Tag::Map(Box::new(val_tag))),
            _ => return Err(Error::new(val_ty.span(),
                "unsupported HashMap value type: only bool, integer, and String \
                 values are bridgeable")),
        }
    }
    // `Vec<u8>` is a byte string, NOT a list[int]: it marshals as Jac `bytes`
    // (TAG_BYTES) so a hash digest / binary blob crosses intact (explicit length,
    // embedded NULs preserved). Checked before the generic `Vec<V>` list arm below,
    // which would otherwise lower it to `List(Uint)`. This is the sha2 `finalize`
    // carrier.
    if let Some(elem_ty) = extract_vec(ty) {
        if let Type::Path(tp) = elem_ty {
            if tp.path.is_ident("u8") { return Ok(Tag::Bytes); }
        }
    }
    // Vec<V> marshals as a real Jac list[V]. Checked before the generic Path arms
    // so the `Vec` ident is not mistaken for an opaque type reference.
    if let Some(elem_ty) = extract_vec(ty) {
        let elem_tag = ret_tag(elem_ty, types, records, self_i)?;
        match elem_tag {
            Tag::Bool | Tag::Int | Tag::Uint | Tag::Str =>
                return Ok(Tag::List(Box::new(elem_tag))),
            _ => return Err(Error::new(elem_ty.span(),
                "unsupported Vec element type: only bool, integer, and String \
                 elements are bridgeable")),
        }
    }
    match ty {
        Type::Tuple(tt) if tt.elems.is_empty() => Ok(Tag::Void),
        Type::Path(tp) if tp.path.segments.last().map(|s| s.ident == "Option").unwrap_or(false) => {
            let inner_ty = option_inner(ty).ok_or_else(|| Error::new(ty.span(),
                "Option must have a single concrete type argument"))?;
            let inner = ret_tag(inner_ty, types, records, self_i)?;
            match inner {
                // Only Ref (null handle), Str, and Bytes (null JacBuf.ptr) have an
                // in-band None channel. Option<bool>/Option<int>/Option<Option<_>>
                // would need a separate presence flag — not in the v1 ABI.
                Tag::Ref(_) | Tag::Str | Tag::Bytes => Ok(Tag::Opt(Box::new(inner))),
                _ => Err(Error::new(ty.span(),
                    "unsupported Option return: only Option<&OpaqueType>, \
                     Option<String>, and Option<Vec<u8>> can signal None in-band")),
            }
        }
        Type::Path(tp) if tp.path.segments.len() == 1 => {
            let id = &tp.path.segments[0].ident;
            let id_str = id.to_string();
            match id_str.as_str() {
                "bool"   => Ok(Tag::Bool),
                "String" => Ok(Tag::Str),
                "Self"   => Ok(Tag::Ref(self_i)),
                _ => {
                    if let Some(tag) = int_tag_for(&id_str) {
                        Ok(tag)
                    } else if let Some(tag) = float_tag_for(&id_str) {
                        Ok(tag)
                    } else {
                        types.iter().position(|t| &t.name == id)
                            .map(Tag::Ref)
                            .ok_or_else(|| Error::new(ty.span(),
                                format!("unsupported return type: `{}`", quote!(#ty))))
                    }
                }
            }
        }
        Type::Reference(tr) => {
            if let Type::Path(tp) = &*tr.elem {
                if tp.path.is_ident("str") { return Ok(Tag::Str); }
            }
            Err(Error::new(ty.span(), "unsupported reference return type"))
        }
        _ => Err(Error::new(ty.span(), format!("unsupported return type: `{}`", quote!(#ty)))),
    }
}

// ─── D2 blob ──────────────────────────────────────────────────────────────────

fn put_u32(b: &mut [u8], o: usize, v: u32) { b[o..o+4].copy_from_slice(&v.to_le_bytes()); }
fn put_sr(b: &mut [u8], o: usize, (abs, len): (u32, u32)) { put_u32(b, o, abs); put_u32(b, o+4, len); }

struct Pool { bytes: Vec<u8>, map: std::collections::HashMap<String, u32> }
impl Pool {
    fn new() -> Self { Pool { bytes: Vec::new(), map: Default::default() } }
    fn intern(&mut self, s: &str) -> (u32, u32) {
        let off = match self.map.get(s) {
            Some(&o) => o,
            None => {
                let o = self.bytes.len() as u32;
                self.map.insert(s.to_string(), o);
                self.bytes.extend_from_slice(s.as_bytes());
                o
            }
        };
        (off, s.len() as u32)
    }
    fn abs(&self, base: u32, (rel, len): (u32, u32)) -> (u32, u32) { (base + rel, len) }
}

fn build_blob(module_name: &str, types: &[TypeDef], records: &[RecordDef], fns: &[FnDef]) -> Vec<u8> {
    let n_params: usize = fns.iter().map(|f| f.params.len()).sum();
    let n_fields: usize = records.iter().map(|r| r.fields.len()).sum();
    let rec_desc = schema::RECORD_DESC_SIZE as usize;
    let field_desc = schema::FIELD_DESC_SIZE as usize;
    // Layout: header | TypeDescs | FnDescs | ParamDescs | RecordDescs | FieldDescs | pool
    let records_base = 56 + types.len() * 32 + fns.len() * 44 + n_params * 12;
    let fields_base  = records_base + records.len() * rec_desc;
    let pool_base    = fields_base + n_fields * field_desc;
    let pb = pool_base as u32;

    let mut pool = Pool::new();

    let mod_sr = pool.intern(module_name);
    // Intern record + field names up front so their StrRefs land in the pool.
    let record_srs: Vec<((u32, u32), Vec<(u32, u32)>)> = records.iter().map(|r| {
        let nsr = pool.intern(&r.name.to_string());
        let fsrs = r.fields.iter().map(|(n, _)| pool.intern(n)).collect();
        (nsr, fsrs)
    }).collect();

    let type_srs: Vec<_> = types.iter().map(|t| {
        let n = t.name.to_string();
        let nsr = pool.intern(&n);
        let dsym = match t.kind {
            TypeKind::Error  => format!("jac_{module_name}_error_drop"),
            TypeKind::Opaque => format!("jac_{module_name}_{n}_drop"),
        };
        (nsr, pool.intern(&dsym))
    }).collect();

    let fn_srs: Vec<_> = fns.iter().map(|f| {
        (pool.intern(&f.jac_name), pool.intern(&f.c_sym))
    }).collect();

    let param_srs: Vec<Vec<_>> = fns.iter().map(|f| {
        f.params.iter().map(|p| pool.intern(&p.name)).collect()
    }).collect();

    let blob_len = pool_base + pool.bytes.len();
    let mut buf = vec![0u8; blob_len];

    // Header (56 bytes)
    buf[0..8].copy_from_slice(schema::MAGIC);
    put_u32(&mut buf,  8, schema::ABI_VERSION);
    put_u32(&mut buf, 12, 56);
    put_u32(&mut buf, 16, blob_len as u32);
    put_u32(&mut buf, 20, 0);
    put_sr (&mut buf, 24, pool.abs(pb, mod_sr));
    // The previously-reserved u64 at 32 now carries the record table locator (2.9).
    // Zero when there are no typed records — byte-identical to a v1 blob, so old
    // loaders (which never read offset 32) are unaffected.
    put_u32(&mut buf, 32, if records.is_empty() { 0 } else { records_base as u32 });
    put_u32(&mut buf, 36, records.len() as u32);
    put_u32(&mut buf, 40, 56);
    put_u32(&mut buf, 44, types.len() as u32);
    put_u32(&mut buf, 48, (56 + types.len() * 32) as u32);
    put_u32(&mut buf, 52, fns.len() as u32);

    // TypeDescs (32 bytes each)
    for (i, (t, (nsr, dsr))) in types.iter().zip(type_srs.iter()).enumerate() {
        let off = 56 + i * 32;
        put_u32(&mut buf, off, 32);
        buf[off + 4] = match t.kind { TypeKind::Opaque => schema::KIND_OPAQUE, TypeKind::Error => schema::KIND_ERROR };
        put_sr(&mut buf, off +  8, pool.abs(pb, *nsr));
        put_sr(&mut buf, off + 16, pool.abs(pb, *dsr));
    }

    // FnDescs (44 bytes each)
    let fns_base    = 56 + types.len() * 32;
    let params_base = fns_base + fns.len() * 44;
    let mut pcursor = params_base;

    for (i, (f, (nsr, ssr))) in fns.iter().zip(fn_srs.iter()).enumerate() {
        let off = fns_base + i * 44;
        put_u32(&mut buf, off, 44);
        put_sr(&mut buf, off +  4, pool.abs(pb, *nsr));
        put_sr(&mut buf, off + 12, pool.abs(pb, *ssr));
        put_u32(&mut buf, off + 20, f.self_idx.map(|i| i as u32).unwrap_or(schema::TAG_VOID));
        buf[off + 24] = f.kind;
        put_u32(&mut buf, off + 28, f.throws.map(|i| i as u32).unwrap_or(schema::TAG_VOID));
        // Phase S: the ownership class rides the Ref return tag as append-only
        // high bits (owned = 0, byte-identical to frozen v1).
        put_u32(&mut buf, off + 32, f.ret.as_u32() | f.ownership.bits());
        // Canonicalize an empty param slice to offset 0 (never dereferenced when
        // count==0). Matches the hand-written M0 reference vector byte-for-byte;
        // a stray cursor offset into the pool for a zero-length slice is misleading.
        let params_off = if f.params.is_empty() { 0 } else { pcursor as u32 };
        put_u32(&mut buf, off + 36, params_off);
        put_u32(&mut buf, off + 40, f.params.len() as u32);
        pcursor += f.params.len() * 12;
    }

    // ParamDescs (12 bytes each)
    let mut poff = params_base;
    for (f, pss) in fns.iter().zip(param_srs.iter()) {
        for (p, &psr) in f.params.iter().zip(pss.iter()) {
            put_sr(&mut buf, poff, pool.abs(pb, psr));
            put_u32(&mut buf, poff + 8, p.tag.as_u32());
            poff += 12;
        }
    }

    // RecordDescs (24 bytes each) + FieldDescs (12 bytes each), 2.9 typed-obj table.
    // For an enum record each FieldDesc is a variant (name + payload tag); the +20
    // kind word distinguishes struct from enum.
    let mut fcursor = fields_base;
    for (i, (r, (nsr, fsrs))) in records.iter().zip(record_srs.iter()).enumerate() {
        let off = records_base + i * rec_desc;
        put_u32(&mut buf, off, schema::RECORD_DESC_SIZE);
        put_sr(&mut buf, off + 4, pool.abs(pb, *nsr));
        let field_off = if r.fields.is_empty() { 0 } else { fcursor as u32 };
        put_u32(&mut buf, off + 12, field_off);
        put_u32(&mut buf, off + 16, r.fields.len() as u32);
        put_u32(&mut buf, off + 20, r.kind.as_u32());
        for ((_, tag), &fsr) in r.fields.iter().zip(fsrs.iter()) {
            put_sr(&mut buf, fcursor, pool.abs(pb, fsr));
            put_u32(&mut buf, fcursor + 8, tag.as_u32());
            fcursor += field_desc;
        }
    }

    buf[pool_base..].copy_from_slice(&pool.bytes);
    buf
}

// ─── codegen ──────────────────────────────────────────────────────────────────

fn gen_static(blob: &[u8], module_name: &str) -> TS2 {
    let len: usize = blob.len();
    let bytes: Vec<Literal> = blob.iter().map(|&b| Literal::u8_unsuffixed(b)).collect();
    let init_fn = format_ident!("jac_bridge_init_{module_name}");
    quote! {
        #[used]
        #[cfg_attr(target_os = "linux",  link_section = ".jac_bridge")]
        #[cfg_attr(target_os = "macos",  link_section = "__DATA,__jac_bridge")]
        #[cfg_attr(windows,              link_section = ".jacbrdg")]
        static __JAC_BRIDGE_META: [u8; #len] = [ #(#bytes),* ];

        #[no_mangle]
        pub extern "C" fn #init_fn() -> *const u8 { __JAC_BRIDGE_META.as_ptr() }
    }
}

fn gen_shims(module_name: &str, types: &[TypeDef], fns: &[FnDef], mod_ident: &Ident) -> TS2 {
    let rt = format_ident!("__jac_bridge_{module_name}_rt");

    // Computed before building the rt module so the async helper can live inside it,
    // making it referenceable as `#rt::block_on(...)` from the shim functions.
    let has_async = fns.iter().any(|f| f.is_async);
    let async_rt_helper: TS2 = if has_async {
        quote! {
            // One Tokio runtime per bridge module, lazily initialised on first use.
            // `new_multi_thread().enable_all()` supports async crates that need timers,
            // IO reactor context, etc. The runtime is reused across all async calls.
            static __JAC_ASYNC_RT: ::std::sync::OnceLock<::tokio::runtime::Runtime> =
                ::std::sync::OnceLock::new();

            pub fn block_on<F: ::std::future::Future>(fut: F) -> F::Output {
                __JAC_ASYNC_RT
                    .get_or_init(|| {
                        ::tokio::runtime::Builder::new_multi_thread()
                            .enable_all()
                            .build()
                            .expect("jac bridge async runtime")
                    })
                    .block_on(fut)
            }
        }
    } else {
        quote! {}
    };

    // The serde wide lane's runtime, emitted into `#rt` only when a `Wide<T>`
    // value is present so wide-free bridges stay byte-identical and pull in no
    // `serde`/`rmp_serde` dependency. `Wide<T>` is the newtype the binder writes in
    // generated source; `#[serde(transparent)]` makes it (de)serialize exactly as
    // its inner `T`, so the payload is `T`'s own MessagePack image (no wrapper
    // envelope). The codec helpers are generic over the whole target so `T` is
    // inferred from the wrapper fn's signature at each call site.
    let has_wide = fns.iter().any(|f|
        matches!(f.ret, Tag::Wide(_)) || f.params.iter().any(|p| matches!(p.tag, Tag::Wide(_))));
    let wide_helpers: TS2 = if has_wide {
        quote! {
            #[derive(::serde::Serialize, ::serde::Deserialize)]
            #[serde(transparent)]
            pub struct Wide<T>(pub T);

            // Decode a MessagePack payload into the target `Wide<T>`. A malformed
            // payload becomes a `String` error the shim surfaces as status 1 — the
            // wide param decode uses `?` on the closure's `Result<_, String>`.
            pub fn wide_decode<'a, W: ::serde::Deserialize<'a>>(bytes: &'a [u8])
                -> ::std::result::Result<W, String>
            {
                ::rmp_serde::from_slice(bytes)
                    .map_err(|e| format!("jac bridge: msgpack decode: {e}"))
            }

            // Encode a `Wide<T>` return to an owned JacBuf (structs as name→value
            // maps via `to_vec_named`). Runs on the shim's OK path after the call
            // succeeded; an encode failure is pathological for a cleanly-derived
            // `Serialize` type, so it panics into the status-2 path — the same
            // discipline as `string_to_jacbuf`/`vec_to_jacbuf`'s u32 boundary asserts.
            pub fn wide_encode<W: ::serde::Serialize>(v: &W) -> JacBuf {
                let bytes = ::rmp_serde::to_vec_named(v)
                    .expect("jac bridge: msgpack encode");
                vec_to_jacbuf(bytes)
            }
        }
    } else {
        quote! {}
    };

    let mut items: Vec<TS2> = vec![quote! {
        #[allow(non_snake_case, dead_code, clippy::all)]
        mod #rt {
            #async_rt_helper
            #wide_helpers
            #[repr(C)]
            pub struct JacBuf { pub ptr: *mut u8, pub len: u32, pub cap: u32 }

            // Every opaque handle points at one of these, not a bare `T`.  The
            // `busy` flag is a reentrancy latch: a `&mut self` shim try-locks it
            // before forming the exclusive borrow, so a callback that re-enters
            // its own receiver hits a clean Jac-layer error (status 1) instead of
            // aliasing the live `&mut` (UB).  `&self`-only shims never touch it.
            //
            // `rc` (Phase S, Track A) is the handle box's reference count. It
            // starts at 1 (one owner: the wrapper the return minted). A second
            // wrapper over the SAME box — an identity/`Self` return, a copied
            // handle integer, or an honestly-`shared` alias — `retain`s it
            // (rc+1); the drop shim `release`s it (rc-1) and frees the box only
            // at rc==0, so double-close is idempotent and the inner `T` drops
            // exactly once.  `busy` stays first to preserve the `&(*p).busy`
            // offset math the `&mut self` shims rely on; `rc` is appended last.
            #[repr(C)]
            pub struct JacHandle<T> {
                pub busy: ::std::sync::atomic::AtomicBool,
                pub value: T,
                pub rc: ::std::sync::atomic::AtomicUsize,
            }

            impl<T> JacHandle<T> {
                pub fn new(value: T) -> Self {
                    JacHandle {
                        busy: ::std::sync::atomic::AtomicBool::new(false),
                        value,
                        rc: ::std::sync::atomic::AtomicUsize::new(1),
                    }
                }
            }

            // RAII latch: `try_acquire` fails (None) when the handle is already in
            // use; on success the guard releases the flag on drop, so the latch is
            // cleared even if the wrapped call panics and unwinds.
            pub struct BusyGuard<'a>(&'a ::std::sync::atomic::AtomicBool);

            impl<'a> BusyGuard<'a> {
                pub fn try_acquire(flag: &'a ::std::sync::atomic::AtomicBool)
                    -> ::std::option::Option<BusyGuard<'a>>
                {
                    match flag.compare_exchange(
                        false, true,
                        ::std::sync::atomic::Ordering::Acquire,
                        ::std::sync::atomic::Ordering::Relaxed,
                    ) {
                        ::std::result::Result::Ok(_) => ::std::option::Option::Some(BusyGuard(flag)),
                        ::std::result::Result::Err(_) => ::std::option::Option::None,
                    }
                }
            }

            impl ::std::ops::Drop for BusyGuard<'_> {
                fn drop(&mut self) {
                    self.0.store(false, ::std::sync::atomic::Ordering::Release);
                }
            }

            pub fn string_to_jacbuf(s: String) -> JacBuf {
                let mut v = s.into_bytes();
                // 0.2.3: the boundary carries len/cap as u32; a >4 GiB buffer would
                // silently truncate and later free the wrong extent. Panic (→ the
                // shim's status-2 path) rather than corrupt the free.
                assert!(
                    v.len() <= u32::MAX as usize && v.capacity() <= u32::MAX as usize,
                    "jac bridge: string buffer exceeds u32 boundary limit"
                );
                let ptr = v.as_mut_ptr();
                let len = v.len() as u32;
                let cap = v.capacity() as u32;
                ::std::mem::forget(v);
                JacBuf { ptr, len, cap }
            }

            // Hand an owned byte buffer to the loader as a JacBuf (same ownership
            // discipline as string_to_jacbuf: forget the Vec, the loader frees it
            // via the module's free-buf shim).  Used for the serialized wire image
            // of a HashMap return (a dict[str, V] marshaled as one owned blob).
            pub fn vec_to_jacbuf(mut v: Vec<u8>) -> JacBuf {
                // 0.2.3: same u32 boundary guard as string_to_jacbuf.
                assert!(
                    v.len() <= u32::MAX as usize && v.capacity() <= u32::MAX as usize,
                    "jac bridge: vec buffer exceeds u32 boundary limit"
                );
                let ptr = v.as_mut_ptr();
                let len = v.len() as u32;
                let cap = v.capacity() as u32;
                ::std::mem::forget(v);
                JacBuf { ptr, len, cap }
            }

            pub fn panic_err_handle(msg: &str) -> u64 {
                ::std::boxed::Box::into_raw(::std::boxed::Box::new(msg.to_string())) as u64
            }

            // 0.2.5: recover the panic message from the caught payload. `panic!`
            // payloads are almost always `&str` or `String`; downcast both so the
            // Jac-side exception carries the real message (`ctx: detail`) instead
            // of a bare "panic in <symbol>".
            pub fn panic_err_handle_from(
                payload: ::std::boxed::Box<dyn ::std::any::Any + ::std::marker::Send>,
                ctx: &str,
            ) -> u64 {
                let detail = if let ::std::option::Option::Some(s) =
                    payload.downcast_ref::<&str>()
                {
                    (*s).to_string()
                } else if let ::std::option::Option::Some(s) =
                    payload.downcast_ref::<String>()
                {
                    s.clone()
                } else {
                    "unknown panic payload".to_string()
                };
                ::std::boxed::Box::into_raw(
                    ::std::boxed::Box::new(format!("{ctx}: {detail}"))
                ) as u64
            }

            // A callback the Jac side hands us.  It crosses as a single u64 that
            // is a *pointer* to a two-word `{call, ctx}` record (`JacCallbackRaw`):
            // `call` is the C-ABI thunk, `ctx` an opaque context threaded back into
            // every invocation.  A plain module-level Jac function has `ctx == null`;
            // a closure points `ctx` at an environment holding its captured values,
            // which the na trampoline reads back — this is what lets closures, not
            // just top-level functions, cross the boundary.  CPython closures capture
            // natively, so their `ctx` is null too.  We invoke `call` with the match
            // text and read back an owned replacement JacBuf (allocated Jac-side via
            // `..._make_buf`, freed here after copying — same allocator both ways).
            pub type JacCbFn = unsafe extern "C" fn(
                *mut ::std::ffi::c_void, *const u8, u32, *mut JacBuf, *mut u64,
            ) -> i32;

            #[repr(C)]
            struct JacCallbackRaw { call: usize, ctx: usize }

            #[derive(Clone, Copy)]
            pub struct JacCallback { func: JacCbFn, ctx: *mut ::std::ffi::c_void }

            impl JacCallback {
                /// # Safety
                /// `raw` must point to a valid `{call, ctx}` record whose `call`
                /// is a valid `JacCbFn` for the call's duration.
                pub unsafe fn from_raw(raw: u64) -> JacCallback {
                    let rec = unsafe { &*(raw as *const JacCallbackRaw) };
                    JacCallback {
                        func: unsafe { ::std::mem::transmute::<usize, JacCbFn>(rec.call) },
                        ctx: rec.ctx as *mut ::std::ffi::c_void,
                    }
                }

                /// Invoke the callback with `arg`; copy the returned buffer into an
                /// owned `String` and free it.  A null out buffer decodes to "".
                pub fn call(&self, arg: &str) -> ::std::result::Result<String, String> {
                    let mut buf = JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 };
                    let mut err = 0u64;
                    let st = unsafe {
                        (self.func)(self.ctx, arg.as_ptr(), arg.len() as u32, &mut buf, &mut err)
                    };
                    if st != 0 {
                        // The callback signalled failure.  We do NOT dereference
                        // `err` (its ownership convention is runtime-specific and
                        // v1 callbacks are infallible); surface a status message.
                        return ::std::result::Result::Err(
                            format!("callback returned error status {st}")
                        );
                    }
                    // 0.2.6: validate the callback's bytes strictly (matching the
                    // param-side `str::from_utf8` discipline) rather than lossily
                    // replacing invalid sequences.  Invalid UTF-8 becomes a callback
                    // error the bridge fn propagates as status 1.
                    let decoded: ::std::result::Result<String, String> = if buf.ptr.is_null() {
                        ::std::result::Result::Ok(String::new())
                    } else {
                        let bytes = unsafe {
                            ::std::slice::from_raw_parts(buf.ptr, buf.len as usize)
                        };
                        match ::std::str::from_utf8(bytes) {
                            ::std::result::Result::Ok(s) =>
                                ::std::result::Result::Ok(s.to_string()),
                            ::std::result::Result::Err(e) =>
                                ::std::result::Result::Err(
                                    format!("callback returned non-UTF-8 bytes: {e}")
                                ),
                        }
                    };
                    // Reclaim the owned replacement buffer (cap!=0 == Jac-allocated
                    // via `..._make_buf`).  cap==0 would be a borrowed buffer we
                    // must not free; null ptr is a no-op.  Freed regardless of
                    // whether decoding succeeded.
                    if !buf.ptr.is_null() && buf.cap != 0 {
                        unsafe {
                            ::std::mem::drop(::std::vec::Vec::from_raw_parts(
                                buf.ptr, buf.len as usize, buf.cap as usize,
                            ));
                        }
                    }
                    decoded
                }
            }
        }
    }];

    // D3: compile-time Send assertion for every opaque type (ABI requirement)
    // The handle that crosses the boundary is `JacHandle<T>`, not a bare `T`, so
    // the ABI Send requirement is asserted on the wrapper (`JacHandle<T>: Send`
    // iff `T: Send`, since both `AtomicBool` and the Phase-S `AtomicUsize` rc
    // field are Send+Sync).
    let opaque_paths: Vec<TS2> = types.iter()
        .filter(|t| t.kind == TypeKind::Opaque)
        .map(|t| { let n = &t.name; quote! { #rt :: JacHandle< #mod_ident :: #n > } })
        .collect();
    if !opaque_paths.is_empty() {
        items.push(quote! {
            const _: () = {
                fn _assert_send<T: ::core::marker::Send>() {}
                fn _check() { #( _assert_send::<#opaque_paths>(); )* }
            };
        });
    }

    // Drop shims for each type
    for t in types {
        let tname = &t.name;
        let tpath = quote! { #mod_ident :: #tname };
        match t.kind {
            TypeKind::Opaque => {
                let sym = format_ident!("jac_{module_name}_{tname}_drop");
                let retain_sym = format_ident!("jac_{module_name}_{tname}_retain");
                items.push(quote! {
                    // Phase S, Track A: bump the handle box's refcount. Called by
                    // the loader when a SECOND wrapper adopts an existing handle
                    // (identity/`Self` return, copied handle, honest `shared`
                    // alias), so the box outlives every owner.  Null is a no-op.
                    #[no_mangle]
                    pub unsafe extern "C" fn #retain_sym(handle: u64) {
                        if handle != 0 {
                            let h = unsafe { &*(handle as *const #rt::JacHandle<#tpath>) };
                            h.rc.fetch_add(1, ::std::sync::atomic::Ordering::Relaxed);
                        }
                    }
                    // Phase S, Track A: `close()`/`__del__` is now a DECREF, not an
                    // unconditional free.  The box (and its inner `T`) is dropped
                    // only when the last reference releases (rc 1 -> 0), so a
                    // double-close is idempotent and two wrappers over one box are
                    // sound.  Release/Acquire fence around the free mirrors the
                    // standard `Arc` drop discipline.
                    #[no_mangle]
                    pub unsafe extern "C" fn #sym(handle: u64) {
                        if handle != 0 {
                            let h = unsafe { &*(handle as *const #rt::JacHandle<#tpath>) };
                            if h.rc.fetch_sub(1, ::std::sync::atomic::Ordering::Release) == 1 {
                                ::std::sync::atomic::fence(::std::sync::atomic::Ordering::Acquire);
                                unsafe { ::std::mem::drop(
                                    ::std::boxed::Box::from_raw(handle as *mut #rt::JacHandle<#tpath>)
                                ); }
                            }
                        }
                    }
                });
            }
            TypeKind::Error => {
                let sym = format_ident!("jac_{module_name}_error_drop");
                items.push(quote! {
                    #[no_mangle]
                    pub unsafe extern "C" fn #sym(err_handle: u64) {
                        if err_handle != 0 {
                            unsafe { ::std::mem::drop(
                                ::std::boxed::Box::from_raw(err_handle as *mut String)
                            ); }
                        }
                    }
                });
            }
        }
    }

    // Universal panic plumbing.  A panic handle is a Box<String> just like an
    // error handle (both `Err` and panic write `Box::into_raw(Box::new(msg))`);
    // the #[jac_error] type only picks the caller-side exception class and gates
    // the error_* symbols.  Emitting these two unconditionally means a bridge with
    // NO #[jac_error] type still surfaces the panic message and frees the handle
    // on a panic (status 2) instead of leaking it behind a generic message.
    let panic_drop = format_ident!("jac_{module_name}_panic_drop");
    let panic_message = format_ident!("jac_{module_name}_panic_message");
    items.push(quote! {
        #[no_mangle]
        pub unsafe extern "C" fn #panic_drop(err_handle: u64) {
            if err_handle != 0 {
                unsafe { ::std::mem::drop(
                    ::std::boxed::Box::from_raw(err_handle as *mut String)
                ); }
            }
        }
        #[no_mangle]
        pub unsafe extern "C" fn #panic_message(
            err_handle: u64,
            out_buf: *mut #rt::JacBuf,
            out_err: *mut u64,
        ) -> i32 {
            // 0.2.1: never dereference a null panic handle.
            if err_handle == 0 {
                unsafe {
                    *out_buf = #rt::JacBuf {
                        ptr: ::std::ptr::null_mut(), len: 0, cap: 0
                    };
                    *out_err = ::std::boxed::Box::into_raw(::std::boxed::Box::new(
                        "null handle (use after close?)".to_string()
                    )) as u64;
                }
                return 1;
            }
            let r = ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(|| {
                let s = unsafe { &*(err_handle as *const String) };
                #rt::string_to_jacbuf(s.clone())
            }));
            match r {
                ::std::result::Result::Ok(buf) => {
                    unsafe { *out_buf = buf; *out_err = 0; }
                    0
                }
                ::std::result::Result::Err(_) => {
                    unsafe {
                        *out_buf = #rt::JacBuf {
                            ptr: ::std::ptr::null_mut(), len: 0, cap: 0
                        };
                        *out_err = 0;
                    }
                    2
                }
            }
        }
    });

    // free_buf
    let free_buf = format_ident!("jac_{module_name}_free_buf");
    items.push(quote! {
        #[no_mangle]
        pub unsafe extern "C" fn #free_buf(buf: #rt::JacBuf) {
            if !buf.ptr.is_null() {
                unsafe { ::std::mem::drop(::std::vec::Vec::from_raw_parts(
                    buf.ptr, buf.len as usize, buf.cap as usize,
                )); }
            }
        }
    });

    // make_buf — copy `s_len` bytes at `s_ptr` into a freshly-allocated JacBuf
    // written to `*out_buf`.  Emitted only for bridges with a callback: it lets a
    // Jac callback thunk hand back an owned replacement buffer (allocated on the
    // Rust heap, so the reader frees it via free_buf — one allocator both ways),
    // sidestepping the lack of a str->raw-pointer intrinsic on the na runtime.
    let has_callback = fns.iter().any(|f| f.params.iter().any(|p| p.tag == Tag::Callback));
    if has_callback {
        let make_buf = format_ident!("jac_{module_name}_make_buf");
        items.push(quote! {
            #[no_mangle]
            pub unsafe extern "C" fn #make_buf(
                s_ptr: *const u8, s_len: u32, out_buf: *mut #rt::JacBuf,
            ) {
                let src = unsafe { ::std::slice::from_raw_parts(s_ptr, s_len as usize) };
                let mut v = src.to_vec();
                let ptr = v.as_mut_ptr();
                let len = v.len() as u32;
                let cap = v.capacity() as u32;
                ::std::mem::forget(v);
                unsafe { *out_buf = #rt::JacBuf { ptr, len, cap }; }
            }
        });
    }

    // Function shims
    for f in fns {
        items.push(gen_fn_shim(f, types, mod_ident, &rt, has_async));
    }

    quote! { #(#items)* }
}

fn gen_fn_shim(f: &FnDef, types: &[TypeDef], mod_ident: &Ident, rt: &Ident, _has_async: bool) -> TS2 {
    let sym_id  = format_ident!("{}", f.c_sym);
    let sym_str = &f.c_sym;

    // ── auto-generated error_message reads Box<String> ───────────────────────
    if f.is_auto {
        return quote! {
            #[no_mangle]
            pub unsafe extern "C" fn #sym_id(
                err_handle: u64,
                out_buf: *mut #rt::JacBuf,
                out_err: *mut u64,
            ) -> i32 {
                // 0.2.1: never dereference a null error handle.
                if err_handle == 0 {
                    unsafe {
                        *out_buf = #rt::JacBuf {
                            ptr: ::std::ptr::null_mut(), len: 0, cap: 0
                        };
                        *out_err = ::std::boxed::Box::into_raw(::std::boxed::Box::new(
                            "null handle (use after close?)".to_string()
                        )) as u64;
                    }
                    return 1;
                }
                let r = ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(|| {
                    let s = unsafe { &*(err_handle as *const String) };
                    #rt::string_to_jacbuf(s.clone())
                }));
                match r {
                    ::std::result::Result::Ok(buf) => {
                        unsafe { *out_buf = buf; *out_err = 0; }
                        0
                    }
                    ::std::result::Result::Err(_) => {
                        unsafe {
                            *out_buf = #rt::JacBuf {
                                ptr: ::std::ptr::null_mut(), len: 0, cap: 0
                            };
                            *out_err = #rt::panic_err_handle(concat!("panic in ", #sym_str));
                        }
                        2
                    }
                }
            }
        };
    }

    // ── user function shim ────────────────────────────────────────────────────
    let tname = &types[f.impl_type_i].name;
    let tpath = quote! { #mod_ident :: #tname };
    let fn_id = &f.rust_ident;

    // C-level params
    let mut c_params: Vec<TS2> = Vec::new();
    if f.kind == schema::FN_METHOD { c_params.push(quote! { handle: u64 }); }

    let mut decode: Vec<TS2> = Vec::new();
    let mut call_args: Vec<TS2> = Vec::new();

    for p in &f.params {
        let pn = format_ident!("{}", p.name);
        if p.is_str_ref {
            // A wide (ptr, len) boundary param: `&str` OR `&[u8]`. Both cross the
            // same two C slots; only the decode differs — a byte slice is handed
            // through raw (NO UTF-8 validation, NO strlen — the explicit `len`
            // carries embedded NULs), a `&str` is UTF-8 checked.
            let ptr_n = format_ident!("{}_ptr", p.name);
            let len_n = format_ident!("{}_len", p.name);
            c_params.push(quote! { #ptr_n: *const u8 });
            c_params.push(quote! { #len_n: u32 });
            if p.tag == Tag::Bytes {
                decode.push(quote! {
                    let #pn = unsafe {
                        ::std::slice::from_raw_parts(#ptr_n, #len_n as usize)
                    };
                });
            } else {
                decode.push(quote! {
                    let #pn = ::std::str::from_utf8(
                        unsafe { ::std::slice::from_raw_parts(#ptr_n, #len_n as usize) }
                    ).map_err(|e| format!("UTF-8: {e}"))?;
                });
            }
        } else {
            match &p.tag {
                Tag::Bool => {
                    c_params.push(quote! { #pn: u8 });
                    decode.push(quote! { let #pn = #pn != 0; });
                }
                Tag::Int | Tag::Uint => {
                    // Crosses as a u64 slot; cast back to the concrete Rust
                    // integer type the call expects (truncating widths <64,
                    // reinterpreting the sign for the signed case).
                    let ity = format_ident!(
                        "{}", p.int_ty.as_deref().unwrap_or("u64")
                    );
                    c_params.push(quote! { #pn: u64 });
                    decode.push(quote! { let #pn = #pn as #ity; });
                }
                Tag::F64 => {
                    // Crosses as a u64 slot carrying the f64 bit pattern (never a
                    // numeric cast — that would truncate). Reconstruct the double
                    // with from_bits, then narrow to the concrete float type the
                    // call expects (`as f32` is a value-preserving narrowing; for
                    // f64 it is the identity).
                    let fty = format_ident!(
                        "{}", p.float_ty.as_deref().unwrap_or("f64")
                    );
                    c_params.push(quote! { #pn: u64 });
                    decode.push(quote! { let #pn = f64::from_bits(#pn) as #fty; });
                }
                Tag::Wide(_) => {
                    // The serde wide lane: a `Wide<T>` param crosses as a
                    // (payload_ptr, payload_len) pair — the same two-slot boundary
                    // as `&str`/`&[u8]` — carrying a MessagePack document. Decode it
                    // back into the wrapper fn's `Wide<T>` inside the `catch_unwind`
                    // closure; `T` is inferred from the call site. A malformed
                    // payload maps to a `String` error → status 1 (the `?` on the
                    // Result<_, String> closure), never a panic.
                    let ptr_n = format_ident!("{}_ptr", p.name);
                    let len_n = format_ident!("{}_len", p.name);
                    c_params.push(quote! { #ptr_n: *const u8 });
                    c_params.push(quote! { #len_n: u32 });
                    decode.push(quote! {
                        let #pn = #rt::wide_decode(
                            unsafe { ::std::slice::from_raw_parts(#ptr_n, #len_n as usize) }
                        )?;
                    });
                }
                Tag::Callback => {
                    // A C function pointer crosses as a u64; wrap it so the
                    // bridge fn calls it with a `&str` and gets a `String` back.
                    c_params.push(quote! { #pn: u64 });
                    decode.push(quote! {
                        let #pn = unsafe { #rt::JacCallback::from_raw(#pn) };
                    });
                }
                _ => { c_params.push(quote! { #pn: u64 }); }
            }
        }
        call_args.push(quote! { #pn });
    }

    // Self deref (inside closure below).  Two defensive guards precede every
    // method deref:
    //   0.2.1 null-handle guard — a raw handle of 0 (use-after-close on the
    //         aliasing path the Jac wrapper cannot catch) returns status 1
    //         instead of dereferencing null.
    //   0.2.2 reentrancy guard — a `&mut self` method try-locks the handle's
    //         `busy` latch before forming the exclusive borrow, so a callback
    //         re-entering its own receiver gets status 1, never an aliased &mut.
    // `&self`-only methods skip the busy latch (shared access is reentrancy-safe)
    // but still null-check.  Field access goes through raw-pointer projections
    // (`&(*p).busy` / `&mut (*p).value`) so the shared `busy` borrow and the
    // exclusive `value` borrow stay on disjoint fields.
    let self_stmt: TS2 = if f.kind == schema::FN_METHOD {
        let null_guard = quote! {
            if handle == 0 {
                return ::std::result::Result::<_, String>::Err(
                    "null handle (use after close?)".to_string()
                );
            }
        };
        if f.self_is_mut {
            quote! {
                #null_guard
                let __busy = unsafe { &(*(handle as *const #rt::JacHandle<#tpath>)).busy };
                let _guard = match #rt::BusyGuard::try_acquire(__busy) {
                    ::std::option::Option::Some(g) => g,
                    ::std::option::Option::None => {
                        return ::std::result::Result::<_, String>::Err(
                            "object already in use (reentrant call)".to_string()
                        );
                    }
                };
                let self_ = unsafe { &mut (*(handle as *mut #rt::JacHandle<#tpath>)).value };
            }
        } else {
            quote! {
                #null_guard
                let self_ = unsafe { &(*(handle as *const #rt::JacHandle<#tpath>)).value };
            }
        }
    } else {
        quote! {}
    };

    // Call expression.  A ctor and a STATIC both call through the associated-fn
    // form `Type::fn(args)` (no receiver); only a method delegates to `self_`.
    let raw_call: TS2 = if f.kind == schema::FN_METHOD {
        quote! { self_ . #fn_id ( #(#call_args),* ) }
    } else {
        quote! { #tpath :: #fn_id ( #(#call_args),* ) }
    };

    // For async fns, block on the future using the module-owned Tokio runtime.
    // The call target is `pub async fn`, so the expression is a Future; wrapping it
    // in `#rt::block_on` drives it to completion before the shim returns.
    let call_expr: TS2 = if f.is_async {
        quote! { #rt::block_on(#raw_call) }
    } else {
        raw_call
    };

    // Closure body — always yields Result<X, String>.  A self-identity return is
    // special: the method hands back a `&Self` borrow of the receiver, which is
    // NOT a value we box — it IS the receiver's existing handle.  So we call the
    // method (honouring any side effects), discard the borrow, and yield the
    // receiver's own `handle` integer.  The na loader adopts it and its runtime
    // `rh == self.__handle` guard fires, retaining the shared box (rc+1) so the
    // two wrappers over one box each close exactly once.
    let closure_body: TS2 = if f.ret_is_self_borrow {
        quote! {
            #self_stmt
            #(#decode)*
            let _ = #call_expr;
            ::std::result::Result::<u64, String>::Ok(handle)
        }
    } else if f.ret_is_result {
        quote! {
            #self_stmt
            #(#decode)*
            #call_expr.map_err(|e| e.to_string())
        }
    } else {
        quote! {
            #self_stmt
            #(#decode)*
            ::std::result::Result::<_, String>::Ok(#call_expr)
        }
    };

    // Out-param tokens.  A self-identity return crosses as the receiver's own
    // handle integer (`val` is already that `u64`) — written straight through, no
    // fresh `Box::into_raw`, so both wrappers share one box.
    let (extra_out, ok_write, zero_out) = if f.ret_is_self_borrow {
        (
            quote! { out_handle: *mut u64, },
            quote! { *out_handle = val; },
            quote! { *out_handle = 0; },
        )
    } else {
        out_param_tokens(&f.ret, rt)
    };
    let panic_msg = format!("panic in {sym_str}");

    quote! {
        #[no_mangle]
        pub unsafe extern "C" fn #sym_id(
            #(#c_params,)*
            #extra_out
            out_err: *mut u64,
        ) -> i32 {
            let r = ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(|| {
                #closure_body
            }));
            match r {
                ::std::result::Result::Ok(::std::result::Result::Ok(val)) => {
                    unsafe { #ok_write *out_err = 0; }
                    0
                }
                ::std::result::Result::Ok(::std::result::Result::Err(msg)) => {
                    unsafe {
                        #zero_out
                        *out_err = ::std::boxed::Box::into_raw(
                            ::std::boxed::Box::new(msg)
                        ) as u64;
                    }
                    1
                }
                ::std::result::Result::Err(__payload) => {
                    unsafe {
                        #zero_out
                        *out_err = #rt::panic_err_handle_from(__payload, #panic_msg);
                    }
                    2
                }
            }
        }
    }
}

fn out_param_tokens(ret: &Tag, rt: &Ident) -> (TS2, TS2, TS2) {
    match ret {
        Tag::Void => (
            quote! {},
            quote! {},
            quote! {},
        ),
        Tag::Bool => (
            quote! { out_result: *mut u8, },
            quote! { *out_result = val as u8; },
            quote! { *out_result = 0; },
        ),
        // Integers cross through a single u64 out-slot. `val as u64` sign-extends
        // a signed value and zero-extends an unsigned one; the loader reads the
        // slot back per the tag (TAG_INT signed, TAG_UINT unsigned). Both signs
        // share the Rust-side write — the distinction lives only in the tag.
        Tag::Int | Tag::Uint => (
            quote! { out_int: *mut u64, },
            quote! { *out_int = val as u64; },
            quote! { *out_int = 0; },
        ),
        // A float crosses through a single u64 out-slot as its IEEE-754 bit
        // pattern. `val as f64` value-preservingly widens an f32 (and is the
        // identity for f64); `.to_bits()` reinterprets — NEVER `val as u64`,
        // which would truncate the double to an integer. The loader reads the
        // slot back with `from_bits`.
        Tag::F64 => (
            quote! { out_f64: *mut u64, },
            quote! { *out_f64 = (val as f64).to_bits(); },
            quote! { *out_f64 = 0; },
        ),
        Tag::Str => (
            quote! { out_buf: *mut #rt::JacBuf, },
            quote! { *out_buf = #rt::string_to_jacbuf(val); },
            quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
        ),
        // A `Vec<u8>` return crosses as an owned JacBuf — the SAME wire shape as a
        // String return — carrying the explicit length so the loader reads exactly
        // `len` bytes (never strlen; embedded NULs survive). `val` is the owned
        // `Vec<u8>`; `vec_to_jacbuf` hands its buffer to the loader to free.
        Tag::Bytes => (
            quote! { out_buf: *mut #rt::JacBuf, },
            quote! { *out_buf = #rt::vec_to_jacbuf(val); },
            quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
        ),
        Tag::Ref(_) => (
            quote! { out_handle: *mut u64, },
            quote! { *out_handle = ::std::boxed::Box::into_raw(
                ::std::boxed::Box::new(#rt::JacHandle::new(val))
            ) as u64; },
            quote! { *out_handle = 0; },
        ),
        // Nullable returns: `None` is signalled in-band on an OK status —
        // a null handle for Option<Ref>, a null JacBuf for Option<Str>.
        Tag::Opt(inner) => match inner.as_ref() {
            Tag::Ref(_) => (
                quote! { out_handle: *mut u64, },
                quote! {
                    *out_handle = match val {
                        ::std::option::Option::Some(x) =>
                            ::std::boxed::Box::into_raw(
                                ::std::boxed::Box::new(#rt::JacHandle::new(x))
                            ) as u64,
                        ::std::option::Option::None => 0,
                    };
                },
                quote! { *out_handle = 0; },
            ),
            Tag::Str => (
                quote! { out_buf: *mut #rt::JacBuf, },
                quote! {
                    *out_buf = match val {
                        ::std::option::Option::Some(s) => #rt::string_to_jacbuf(s),
                        ::std::option::Option::None =>
                            #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 },
                    };
                },
                quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
            ),
            // Option<Vec<u8>>: a null JacBuf.ptr signals None in-band, same channel
            // as Option<String>; Some crosses as the owned byte buffer.
            Tag::Bytes => (
                quote! { out_buf: *mut #rt::JacBuf, },
                quote! {
                    *out_buf = match val {
                        ::std::option::Option::Some(v) => #rt::vec_to_jacbuf(v),
                        ::std::option::Option::None =>
                            #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 },
                    };
                },
                quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
            ),
            // ret_tag guarantees Opt only wraps Ref, Str, or Bytes.
            _ => unreachable!("Tag::Opt wraps only Ref, Str, or Bytes"),
        },
        // HashMap<String, V> → one owned JacBuf holding the whole map serialized
        // little-endian: [u32 count] then per entry [u32 key_len][key bytes][value].
        // The value encoding depends on V's tag (see push_value below). The loader
        // deep-copies the blob into a fresh Jac dict[str, V], then frees the buf.
        Tag::Map(inner) => {
            // Per-entry value serialization, specialized on the value tag. `__v` is
            // bound to `&V` (HashMap iteration yields references).
            let push_value = match inner.as_ref() {
                // int/uint: a single u64 slot. `*__v as u64` sign-extends a signed
                // value and zero-extends an unsigned one — the loader reads the slot
                // back per the value tag, mirroring the scalar out_int discipline.
                Tag::Int | Tag::Uint => quote! {
                    __out.extend_from_slice(&(*__v as u64).to_le_bytes());
                },
                // str: [u32 len][utf-8 bytes].
                Tag::Str => quote! {
                    __out.extend_from_slice(&(__v.len() as u32).to_le_bytes());
                    __out.extend_from_slice(__v.as_bytes());
                },
                // bool: a single byte.
                Tag::Bool => quote! {
                    __out.push(*__v as u8);
                },
                // ret_tag restricts map values to bool/int/uint/str.
                _ => unreachable!("Tag::Map wraps only bool, int, uint, or str"),
            };
            (
                quote! { out_buf: *mut #rt::JacBuf, },
                quote! {
                    let mut __out: ::std::vec::Vec<u8> = ::std::vec::Vec::new();
                    __out.extend_from_slice(&(val.len() as u32).to_le_bytes());
                    for (__k, __v) in val.iter() {
                        __out.extend_from_slice(&(__k.len() as u32).to_le_bytes());
                        __out.extend_from_slice(__k.as_bytes());
                        #push_value
                    }
                    *out_buf = #rt::vec_to_jacbuf(__out);
                },
                quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
            )
        }
        // Vec<V> → one owned JacBuf holding the whole vector serialized
        // little-endian: [u32 count] then per element [value]. Same value encoding
        // as a map value (see above), just without the per-entry key. The loader
        // deep-copies the blob into a fresh Jac list[V], then frees the buf.
        Tag::List(elem) => {
            // Per-element value serialization, specialized on the element tag. `__v`
            // is bound to `&V` (Vec iteration yields references).
            let push_value = match elem.as_ref() {
                // int/uint: a single u64 slot. `*__v as u64` sign-extends a signed
                // value and zero-extends an unsigned one — the loader reads the slot
                // back per the element tag, mirroring the scalar out_int discipline.
                Tag::Int | Tag::Uint => quote! {
                    __out.extend_from_slice(&(*__v as u64).to_le_bytes());
                },
                // str: [u32 len][utf-8 bytes].
                Tag::Str => quote! {
                    __out.extend_from_slice(&(__v.len() as u32).to_le_bytes());
                    __out.extend_from_slice(__v.as_bytes());
                },
                // bool: a single byte.
                Tag::Bool => quote! {
                    __out.push(*__v as u8);
                },
                // ret_tag restricts list elements to bool/int/uint/str.
                _ => unreachable!("Tag::List wraps only bool, int, uint, or str"),
            };
            (
                quote! { out_buf: *mut #rt::JacBuf, },
                quote! {
                    let mut __out: ::std::vec::Vec<u8> = ::std::vec::Vec::new();
                    __out.extend_from_slice(&(val.len() as u32).to_le_bytes());
                    for __v in val.iter() {
                        #push_value
                    }
                    *out_buf = #rt::vec_to_jacbuf(__out);
                },
                quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
            )
        }
        // The serde wide lane: a `Wide<T>` return crosses as one owned JacBuf
        // holding the MessagePack image of `T` — the SAME wire shape and allocator
        // discipline as a `Vec<u8>`/String return. `wide_encode` serializes `val`
        // (a `Wide<T>`, serde-transparent over `T`) and hands the buffer to the
        // loader to free via the module's free-buf shim.
        Tag::Wide(_) => (
            quote! { out_buf: *mut #rt::JacBuf, },
            quote! { *out_buf = #rt::wide_encode(&val); },
            quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
        ),
        // Callback is a param-only tag; `ret_tag` never produces it as a return.
        Tag::Callback => unreachable!("Tag::Callback is param-only, never a return"),
    }
}
