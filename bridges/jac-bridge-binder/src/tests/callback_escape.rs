//! SOUNDNESS (HOLE 1): the v1 callback ABI crosses a Jac closure whose captured
//! env lives on the CALLER's stack — valid only for the synchronous call. A
//! callee that STORES the callback (a `'static`-bounded closure generic, an
//! `impl Fn + 'static`, or an owned `Box`/`Arc`/`Rc<dyn Fn>` trait object) would
//! read that env after the frame is gone. The binder must REJECT the escaping
//! shape as a machine-readable `callback-may-escape` skip, while still bridging a
//! non-`'static` same-thread closure (regex's `replace_all<R: Replacer>`).

use rustdoc_types::{
    Abi, Function, FunctionHeader, FunctionSignature, GenericArg, GenericArgs, GenericBound,
    GenericParamDef, GenericParamDefKind, Generics, Id, Path, TraitBoundModifier, Type,
    WherePredicate,
};

use crate::classify::callback_escape_reason;

// ---- synthetic-rustdoc builders (only the fields the escape check reads) ----

fn path(name: &str, args: Option<GenericArgs>) -> Path {
    Path {
        path: name.to_string(),
        id: Id(0),
        args: args.map(Box::new),
    }
}

fn trait_bound(name: &str) -> GenericBound {
    GenericBound::TraitBound {
        trait_: path(name, None),
        generic_params: vec![],
        modifier: TraitBoundModifier::None,
    }
}

fn static_bound() -> GenericBound {
    GenericBound::Outlives("'static".to_string())
}

fn type_param(name: &str, bounds: Vec<GenericBound>) -> GenericParamDef {
    GenericParamDef {
        name: name.to_string(),
        kind: GenericParamDefKind::Type {
            bounds,
            default: None,
            is_synthetic: false,
        },
    }
}

/// A `Box`/`Arc`/`Rc<dyn Trait>` param type.
fn owned_dyn(wrapper: &str, trait_name: &str, lifetime: Option<&str>) -> Type {
    let dyn_ty = Type::DynTrait(rustdoc_types::DynTrait {
        traits: vec![rustdoc_types::PolyTrait {
            trait_: path(trait_name, None),
            generic_params: vec![],
        }],
        lifetime: lifetime.map(str::to_string),
    });
    Type::ResolvedPath(path(
        wrapper,
        Some(GenericArgs::AngleBracketed {
            args: vec![GenericArg::Type(dyn_ty)],
            constraints: vec![],
        }),
    ))
}

fn func(params: Vec<GenericParamDef>, wheres: Vec<WherePredicate>, inputs: Vec<(String, Type)>) -> Function {
    Function {
        sig: FunctionSignature {
            inputs,
            output: None,
            is_c_variadic: false,
        },
        generics: Generics {
            params,
            where_predicates: wheres,
        },
        header: FunctionHeader {
            is_const: false,
            is_unsafe: false,
            is_async: false,
            abi: Abi::Rust,
        },
        has_body: false,
        default_unstable: None,
    }
}

// ------------------------------- SAFE (bridged) ------------------------------

#[test]
fn non_static_replacer_generic_is_safe() {
    // `fn replace_all<R: Replacer>(&self, &str, R)` — regex's real shape. No
    // `'static`, so the closure can't outlive the synchronous call: still bridged.
    let f = func(
        vec![type_param("R", vec![trait_bound("Replacer")])],
        vec![],
        vec![
            ("self".into(), Type::Generic("Self".into())),
            (
                "rep".into(),
                Type::Generic("R".into()),
            ),
        ],
    );
    assert_eq!(
        callback_escape_reason(&f),
        None,
        "a non-'static Replacer generic must stay bridgeable"
    );
}

#[test]
fn non_static_fnmut_generic_is_safe() {
    // `fn each<F: FnMut(&T)>(&self, f: F)` — a same-thread synchronous callback.
    let f = func(
        vec![type_param("F", vec![trait_bound("FnMut")])],
        vec![],
        vec![("f".into(), Type::Generic("F".into()))],
    );
    assert_eq!(callback_escape_reason(&f), None);
}

// ---------------------------- UNSAFE (rejected) ------------------------------

#[test]
fn static_bounded_closure_generic_escapes() {
    // `fn on_event<F: Fn() + 'static>(&self, f: F)` — the `'static` is exactly the
    // permission for the callee to stash the closure past the call.
    let f = func(
        vec![type_param("F", vec![trait_bound("Fn"), static_bound()])],
        vec![],
        vec![("f".into(), Type::Generic("F".into()))],
    );
    let why = callback_escape_reason(&f).expect("must be flagged as escaping");
    assert!(why.contains("'static"), "reason should cite 'static: {why}");
    assert!(why.contains('F'), "reason should name the generic: {why}");
}

#[test]
fn static_bound_via_where_clause_escapes() {
    // Same, but the `'static` lives in a `where F: Fn() + 'static` predicate rather
    // than inline on the param — the escape check must gather both.
    let f = func(
        vec![type_param("F", vec![])],
        vec![WherePredicate::BoundPredicate {
            type_: Type::Generic("F".into()),
            bounds: vec![trait_bound("Fn"), static_bound()],
            generic_params: vec![],
        }],
        vec![("f".into(), Type::Generic("F".into()))],
    );
    assert!(callback_escape_reason(&f).is_some());
}

#[test]
fn boxed_dyn_fn_param_escapes() {
    // `fn set_handler(&self, cb: Box<dyn Fn()>)` — ownership of the trait object
    // crosses in, so the callee may retain it beyond the call.
    let f = func(
        vec![],
        vec![],
        vec![("cb".into(), owned_dyn("Box", "Fn", None))],
    );
    let why = callback_escape_reason(&f).expect("Box<dyn Fn> must escape");
    assert!(why.contains("Box<dyn Fn>"), "reason: {why}");
}

#[test]
fn arc_dyn_fnmut_param_escapes() {
    // `fn subscribe(&self, cb: Arc<dyn FnMut(&Event) + 'static>)`.
    let f = func(
        vec![],
        vec![],
        vec![("cb".into(), owned_dyn("Arc", "FnMut", Some("'static")))],
    );
    assert!(callback_escape_reason(&f).is_some());
}

#[test]
fn non_callback_static_generic_is_ignored() {
    // `fn insert<T: Clone + 'static>(&self, v: T)` — a `'static` VALUE param, not a
    // callback. The escape guard must NOT fire (it would over-reject handles).
    let f = func(
        vec![type_param("T", vec![trait_bound("Clone"), static_bound()])],
        vec![],
        vec![("v".into(), Type::Generic("T".into()))],
    );
    assert_eq!(callback_escape_reason(&f), None);
}
