use std::path::PathBuf;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let (doc_path, out_dir, jac_bridge_path) = parse_args(&args);

    let data = std::fs::read_to_string(&doc_path).expect("cannot read rustdoc JSON");
    let doc: rustdoc_types::Crate = serde_json::from_str(&data).expect("invalid rustdoc JSON");

    // Determine the module name to locate its overlay before classifying — a
    // `treat_as` directive must steer classification while the rustdoc is in hand.
    let module_name = doc
        .index
        .get(&doc.root)
        .and_then(|i| i.name.clone())
        .unwrap_or_default();
    let overlay_path = doc_path
        .parent()
        .unwrap_or(std::path::Path::new("."))
        .join(format!("{module_name}.overlay.toml"));
    let overlay = overlay_path.exists().then(|| {
        let overlay_src = std::fs::read_to_string(&overlay_path).expect("read overlay");
        jac_bridge_binder::parse_overlay(&overlay_src).expect("parse overlay")
    });

    let mut spec = jac_bridge_binder::classify_with_overlay(&doc, overlay.as_ref());

    eprintln!(
        "// module: {}  version: {}",
        spec.module_name, spec.crate_version
    );
    eprintln!(
        "// types: {}  skips: {}",
        spec.types.len(),
        spec.skips.len()
    );

    if let Some(overlay) = &overlay {
        if let Err(e) = jac_bridge_binder::apply_overlay(&mut spec, overlay) {
            eprintln!("error: {e}");
            std::process::exit(1);
        }
        eprintln!("// applied overlay: {}", overlay_path.display());
    }

    // North-star metric: print coverage after any overlay has been applied.
    eprintln!("{}", jac_bridge_binder::report(&spec));

    let lib_src = jac_bridge_binder::emit(&spec);
    let cargo_src = jac_bridge_binder::emit_cargo_toml(&spec, &jac_bridge_path);

    match out_dir {
        Some(dir) => {
            let src_dir = dir.join("src");
            std::fs::create_dir_all(&src_dir).expect("create src dir");
            std::fs::write(src_dir.join("lib.rs"), &lib_src).expect("write lib.rs");
            std::fs::write(dir.join("Cargo.toml"), &cargo_src).expect("write Cargo.toml");
            eprintln!("// wrote {}/src/lib.rs + Cargo.toml", dir.display());
        }
        None => {
            print!("{}", lib_src);
        }
    }
}

fn parse_args(args: &[String]) -> (PathBuf, Option<PathBuf>, String) {
    let mut doc_path: Option<PathBuf> = None;
    let mut out_dir: Option<PathBuf> = None;
    let mut jac_bridge_path = String::from("../jac-bridge");

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--out" => {
                i += 1;
                out_dir = Some(PathBuf::from(args.get(i).expect("--out requires a path")));
            }
            "--jac-bridge" => {
                i += 1;
                jac_bridge_path = args
                    .get(i)
                    .expect("--jac-bridge requires a path")
                    .to_string();
            }
            arg if !arg.starts_with('-') => {
                doc_path = Some(PathBuf::from(arg));
            }
            other => {
                eprintln!("unknown flag: {other}");
                std::process::exit(1);
            }
        }
        i += 1;
    }

    let doc_path = doc_path
        .expect("usage: jac-bridge-binder <rustdoc.json> [--out <dir>] [--jac-bridge <path>]");
    (doc_path, out_dir, jac_bridge_path)
}
