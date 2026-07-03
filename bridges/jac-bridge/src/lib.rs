use jac_bridge_schema as schema;
use proc_macro::TokenStream;
use proc_macro2::{Literal, Span, TokenStream as TS2};
use quote::{format_ident, quote};
use syn::{
    parse_macro_input, Attribute, Error, FnArg, GenericArgument, Ident,
    ImplItem, Item, ItemMod, LitStr, Pat, PathArguments, ReturnType, Token,
    Type, parse::Parse, parse::ParseStream, spanned::Spanned,
};

// ─── data model ───────────────────────────────────────────────────────────────

#[derive(Clone, Copy, PartialEq, Eq)]
enum TypeKind { Opaque, Error }

struct TypeDef { name: Ident, kind: TypeKind }

#[derive(Clone, PartialEq, Eq)]
enum Tag { Bool, Str, Void, Ref(usize), Opt(Box<Tag>), Callback }

impl Tag {
    fn as_u32(&self) -> u32 {
        match self {
            Tag::Bool     => schema::TAG_BOOL,
            Tag::Str      => schema::TAG_STR,
            Tag::Void     => schema::TAG_VOID,
            Tag::Ref(i)   => schema::TAG_REF_BIT | (*i as u32),
            Tag::Opt(inner) => schema::TAG_OPT_BIT | inner.as_u32(),
            Tag::Callback => schema::TAG_FN,
        }
    }
}

struct Param {
    name:       String,
    tag:        Tag,
    is_str_ref: bool, // &str (ptr+len at boundary) vs String (single ptr)
}

struct FnDef {
    jac_name:      String,
    c_sym:         String,
    kind:          u8,          // 0=ctor, 1=method
    self_idx:      Option<usize>,
    params:        Vec<Param>,
    ret:           Tag,
    throws:        Option<usize>,
    rust_ident:    Ident,
    impl_type_i:   usize,
    ret_is_result: bool,
    self_is_mut:   bool,
    is_auto:       bool,        // auto-generated error_message shim
}

// ─── entry point ──────────────────────────────────────────────────────────────

#[proc_macro_attribute]
pub fn bridge(attr: TokenStream, item: TokenStream) -> TokenStream {
    let module_name = parse_module_name(attr);
    let input = parse_macro_input!(item as ItemMod);
    match expand(module_name, input) {
        Ok(ts) => ts.into(),
        Err(e)  => e.to_compile_error().into(),
    }
}

struct BridgeAttr { name: String }
impl Parse for BridgeAttr {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let _key: Ident = input.parse()?;
        let _eq: Token![=] = input.parse()?;
        let lit: LitStr = input.parse()?;
        Ok(BridgeAttr { name: lit.value() })
    }
}

fn parse_module_name(attr: TokenStream) -> String {
    syn::parse::<BridgeAttr>(attr)
        .map(|a| a.name)
        .unwrap_or_else(|_| "bridge".to_string())
}

// ─── expansion ────────────────────────────────────────────────────────────────

fn expand(module_name: String, input: ItemMod) -> Result<TS2, Error> {
    let span = input.ident.span();
    let items = match &input.content {
        Some((_, it)) => it.clone(),
        None => return Err(Error::new(span,
            "#[jac_bridge::bridge] requires an inline module: mod name { ... }")),
    };

    let (types, fns) = analyze(&module_name, &items, span)?;
    let blob      = build_blob(&module_name, &types, &fns);
    let static_ts = gen_static(&blob, &module_name);
    let shims_ts  = gen_shims(&module_name, &types, &fns, &input.ident);

    // Strip #[jac_error] from struct attrs before re-emitting
    let mut cleaned: Vec<TS2> = items.iter().map(strip_jac_error).collect();

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

fn strip_jac_error(item: &Item) -> TS2 {
    if let Item::Struct(s) = item {
        if has_attr(&s.attrs, "jac_error") {
            let mut s2 = s.clone();
            s2.attrs.retain(|a| !a.path().is_ident("jac_error"));
            // The error type is a name-only marker for D2 metadata; error handles
            // are Box<String> at runtime, so the struct is never constructed.
            return quote! { #[allow(dead_code)] #s2 };
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
) -> Result<(Vec<TypeDef>, Vec<FnDef>), Error> {
    let mut types: Vec<TypeDef> = Vec::new();
    for item in items {
        if let Item::Struct(s) = item {
            let kind = if has_attr(&s.attrs, "jac_error") { TypeKind::Error } else { TypeKind::Opaque };
            types.push(TypeDef { name: s.ident.clone(), kind });
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
            fns.push(analyze_fn(f, type_i, &types, error_idx, module_name)?);
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
            throws:        None,
            rust_ident:    Ident::new("__auto", Span::call_site()),
            impl_type_i:   err_i,
            ret_is_result: false,
            self_is_mut:   false,
            is_auto:       true,
        });
    }

    Ok((types, fns))
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
    error_idx: Option<usize>,
    module_name: &str,
) -> Result<FnDef, Error> {
    let name = f.sig.ident.to_string();

    let (has_self, self_is_mut) = match f.sig.inputs.first() {
        Some(FnArg::Receiver(r)) => (true, r.mutability.is_some()),
        _ => (false, false),
    };
    let kind: u8 = if !has_self { schema::FN_CTOR } else { schema::FN_METHOD };

    let params: Vec<Param> = f.sig.inputs.iter()
        .filter(|a| !matches!(a, FnArg::Receiver(_)))
        .map(|a| analyze_param(a, types))
        .collect::<Result<_, _>>()?;

    let (ret, throws, ret_is_result) =
        analyze_ret(&f.sig.output, types, type_i, error_idx)?;

    let type_name = types[type_i].name.to_string();
    let c_sym = match types[type_i].kind {
        TypeKind::Error  => format!("jac_{module_name}_error_{name}"),
        TypeKind::Opaque => format!("jac_{module_name}_{type_name}_{name}"),
    };

    Ok(FnDef {
        jac_name: name, c_sym, kind,
        self_idx: if has_self { Some(type_i) } else { None },
        params, ret, throws,
        rust_ident: f.sig.ident.clone(),
        impl_type_i: type_i,
        ret_is_result, self_is_mut,
        is_auto: false,
    })
}

fn analyze_param(arg: &FnArg, types: &[TypeDef]) -> Result<Param, Error> {
    let FnArg::Typed(pt) = arg else {
        return Err(Error::new(arg.span(), "unexpected self"));
    };
    let name = match &*pt.pat {
        Pat::Ident(pi) => pi.ident.to_string(),
        _ => return Err(Error::new(pt.pat.span(), "expected a plain param name")),
    };
    let (tag, is_str_ref) = ty_to_tag(&pt.ty, types)?;
    Ok(Param { name, tag, is_str_ref })
}

fn ty_to_tag(ty: &Type, types: &[TypeDef]) -> Result<(Tag, bool), Error> {
    match ty {
        Type::Reference(tr) => {
            if let Type::Path(tp) = &*tr.elem {
                if tp.path.is_ident("str") { return Ok((Tag::Str, true)); }
            }
            let (tag, _) = ty_to_tag(&tr.elem, types)?;
            Ok((tag, false))
        }
        Type::Path(tp) if tp.path.segments.len() == 1 => {
            let id = &tp.path.segments[0].ident;
            match id.to_string().as_str() {
                "bool"        => Ok((Tag::Bool, false)),
                "String"      => Ok((Tag::Str,  false)),
                "str"         => Ok((Tag::Str,  true)),
                // A callback param: the Jac side supplies a C-ABI function
                // pointer (fn(*const u8, u32, *mut JacBuf, *mut u64) -> i32).
                // Crosses as a single u64; decoded into the rt `JacCallback`.
                "JacCallback" => Ok((Tag::Callback, false)),
                _ => {
                    if let Some(i) = types.iter().position(|t| &t.name == id) {
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
    self_i: usize,
    error_idx: Option<usize>,
) -> Result<(Tag, Option<usize>, bool), Error> {
    let ReturnType::Type(_, ty) = ret else {
        return Ok((Tag::Void, None, false));
    };
    if let Some((ok_ty, _)) = extract_result(ty) {
        let ok_tag = ret_tag(ok_ty, types, self_i)?;
        if error_idx.is_none() {
            return Err(Error::new(ty.span(),
                "function returns Result but the bridge module has no #[jac_error] type; \
                 add a #[jac_error] struct so callers can retrieve the error message"));
        }
        return Ok((ok_tag, error_idx, true));
    }
    let tag = ret_tag(ty, types, self_i)?;
    Ok((tag, None, false))
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

fn ret_tag(ty: &Type, types: &[TypeDef], self_i: usize) -> Result<Tag, Error> {
    match ty {
        Type::Tuple(tt) if tt.elems.is_empty() => Ok(Tag::Void),
        Type::Path(tp) if tp.path.segments.last().map(|s| s.ident == "Option").unwrap_or(false) => {
            let inner_ty = option_inner(ty).ok_or_else(|| Error::new(ty.span(),
                "Option must have a single concrete type argument"))?;
            let inner = ret_tag(inner_ty, types, self_i)?;
            match inner {
                // Only Ref (null handle) and Str (null JacBuf.ptr) have an in-band
                // None channel. Option<bool>/Option<int>/Option<Option<_>> would
                // need a separate presence flag — not in the v1 ABI.
                Tag::Ref(_) | Tag::Str => Ok(Tag::Opt(Box::new(inner))),
                _ => Err(Error::new(ty.span(),
                    "unsupported Option return: only Option<&OpaqueType> and \
                     Option<String> can signal None in-band")),
            }
        }
        Type::Path(tp) if tp.path.segments.len() == 1 => {
            let id = &tp.path.segments[0].ident;
            match id.to_string().as_str() {
                "bool"   => Ok(Tag::Bool),
                "String" => Ok(Tag::Str),
                "Self"   => Ok(Tag::Ref(self_i)),
                _ => {
                    types.iter().position(|t| &t.name == id)
                        .map(Tag::Ref)
                        .ok_or_else(|| Error::new(ty.span(),
                            format!("unsupported return type: `{}`", quote!(#ty))))
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
fn put_u64(b: &mut [u8], o: usize, v: u64) { b[o..o+8].copy_from_slice(&v.to_le_bytes()); }
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

fn build_blob(module_name: &str, types: &[TypeDef], fns: &[FnDef]) -> Vec<u8> {
    let n_params: usize = fns.iter().map(|f| f.params.len()).sum();
    let pool_base = 56 + types.len() * 32 + fns.len() * 44 + n_params * 12;
    let pb = pool_base as u32;

    let mut pool = Pool::new();

    let mod_sr = pool.intern(module_name);

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
    put_u64(&mut buf, 32, 0);
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
        put_u32(&mut buf, off + 32, f.ret.as_u32());
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

    let mut items: Vec<TS2> = vec![quote! {
        #[allow(non_snake_case, dead_code, clippy::all)]
        mod #rt {
            #[repr(C)]
            pub struct JacBuf { pub ptr: *mut u8, pub len: u32, pub cap: u32 }

            pub fn string_to_jacbuf(s: String) -> JacBuf {
                let mut v = s.into_bytes();
                let ptr = v.as_mut_ptr();
                let len = v.len() as u32;
                let cap = v.capacity() as u32;
                ::std::mem::forget(v);
                JacBuf { ptr, len, cap }
            }

            pub fn panic_err_handle(msg: &str) -> u64 {
                ::std::boxed::Box::into_raw(::std::boxed::Box::new(msg.to_string())) as u64
            }

            // A callback the Jac side hands us: a C-ABI function pointer with a
            // fixed signature.  The Jac runtime (na `def:pub` thunk, or a CPython
            // CFUNCTYPE) supplies the pointer; we invoke it with the match text
            // and read back an owned replacement JacBuf (allocated Jac-side via
            // `..._make_buf`, freed here after copying — same allocator both ways).
            pub type JacCbFn = unsafe extern "C" fn(
                *const u8, u32, *mut JacBuf, *mut u64,
            ) -> i32;

            #[derive(Clone, Copy)]
            pub struct JacCallback { func: JacCbFn }

            impl JacCallback {
                /// # Safety
                /// `raw` must be a valid `JacCbFn` pointer for the call's duration.
                pub unsafe fn from_raw(raw: u64) -> JacCallback {
                    JacCallback { func: unsafe { ::std::mem::transmute::<usize, JacCbFn>(raw as usize) } }
                }

                /// Invoke the callback with `arg`; copy the returned buffer into an
                /// owned `String` and free it.  A null out buffer decodes to "".
                pub fn call(&self, arg: &str) -> ::std::result::Result<String, String> {
                    let mut buf = JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 };
                    let mut err = 0u64;
                    let st = unsafe {
                        (self.func)(arg.as_ptr(), arg.len() as u32, &mut buf, &mut err)
                    };
                    if st != 0 {
                        // The callback signalled failure.  We do NOT dereference
                        // `err` (its ownership convention is runtime-specific and
                        // v1 callbacks are infallible); surface a status message.
                        return ::std::result::Result::Err(
                            format!("callback returned error status {st}")
                        );
                    }
                    let out = if buf.ptr.is_null() {
                        String::new()
                    } else {
                        let bytes = unsafe {
                            ::std::slice::from_raw_parts(buf.ptr, buf.len as usize)
                        };
                        String::from_utf8_lossy(bytes).into_owned()
                    };
                    // Reclaim the owned replacement buffer (cap!=0 == Jac-allocated
                    // via `..._make_buf`).  cap==0 would be a borrowed buffer we
                    // must not free; null ptr is a no-op.
                    if !buf.ptr.is_null() && buf.cap != 0 {
                        unsafe {
                            ::std::mem::drop(::std::vec::Vec::from_raw_parts(
                                buf.ptr, buf.len as usize, buf.cap as usize,
                            ));
                        }
                    }
                    ::std::result::Result::Ok(out)
                }
            }
        }
    }];

    // D3: compile-time Send assertion for every opaque type (ABI requirement)
    let opaque_paths: Vec<TS2> = types.iter()
        .filter(|t| t.kind == TypeKind::Opaque)
        .map(|t| { let n = &t.name; quote! { #mod_ident :: #n } })
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
                items.push(quote! {
                    #[no_mangle]
                    pub unsafe extern "C" fn #sym(handle: u64) {
                        if handle != 0 {
                            unsafe { ::std::mem::drop(
                                ::std::boxed::Box::from_raw(handle as *mut #tpath)
                            ); }
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
        items.push(gen_fn_shim(f, types, mod_ident, &rt));
    }

    quote! { #(#items)* }
}

fn gen_fn_shim(f: &FnDef, types: &[TypeDef], mod_ident: &Ident, rt: &Ident) -> TS2 {
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
            let ptr_n = format_ident!("{}_ptr", p.name);
            let len_n = format_ident!("{}_len", p.name);
            c_params.push(quote! { #ptr_n: *const u8 });
            c_params.push(quote! { #len_n: u32 });
            decode.push(quote! {
                let #pn = ::std::str::from_utf8(
                    unsafe { ::std::slice::from_raw_parts(#ptr_n, #len_n as usize) }
                ).map_err(|e| format!("UTF-8: {e}"))?;
            });
        } else {
            match &p.tag {
                Tag::Bool => {
                    c_params.push(quote! { #pn: u8 });
                    decode.push(quote! { let #pn = #pn != 0; });
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

    // Self deref (inside closure below)
    let self_stmt: TS2 = if f.kind == schema::FN_METHOD {
        if f.self_is_mut {
            quote! { let self_ = unsafe { &mut *(handle as *mut #tpath) }; }
        } else {
            quote! { let self_ = unsafe { &*(handle as *const #tpath) }; }
        }
    } else {
        quote! {}
    };

    // Call expression
    let call_expr: TS2 = if f.kind == schema::FN_CTOR {
        quote! { #tpath :: #fn_id ( #(#call_args),* ) }
    } else {
        quote! { self_ . #fn_id ( #(#call_args),* ) }
    };

    // Closure body — always yields Result<X, String>
    let closure_body: TS2 = if f.ret_is_result {
        quote! {
            #(#decode)*
            #self_stmt
            #call_expr.map_err(|e| e.to_string())
        }
    } else {
        quote! {
            #(#decode)*
            #self_stmt
            ::std::result::Result::<_, String>::Ok(#call_expr)
        }
    };

    // Out-param tokens
    let (extra_out, ok_write, zero_out) = out_param_tokens(&f.ret, rt);
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
                ::std::result::Result::Err(_) => {
                    unsafe {
                        #zero_out
                        *out_err = #rt::panic_err_handle(#panic_msg);
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
        Tag::Str => (
            quote! { out_buf: *mut #rt::JacBuf, },
            quote! { *out_buf = #rt::string_to_jacbuf(val); },
            quote! { *out_buf = #rt::JacBuf { ptr: ::std::ptr::null_mut(), len: 0, cap: 0 }; },
        ),
        Tag::Ref(_) => (
            quote! { out_handle: *mut u64, },
            quote! { *out_handle = ::std::boxed::Box::into_raw(::std::boxed::Box::new(val)) as u64; },
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
                            ::std::boxed::Box::into_raw(::std::boxed::Box::new(x)) as u64,
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
            // ret_tag guarantees Opt only wraps Ref or Str.
            _ => unreachable!("Tag::Opt wraps only Ref or Str"),
        },
        // Callback is a param-only tag; `ret_tag` never produces it as a return.
        Tag::Callback => unreachable!("Tag::Callback is param-only, never a return"),
    }
}
