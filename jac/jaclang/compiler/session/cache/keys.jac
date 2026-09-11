import hashlib;
import from pathlib { Path }

def content_stamp(path: str) -> tuple[int, str] {
    digest = hashlib.sha256();
    size = 0;
    with Path(path).open('rb') as stream {
        while chunk := stream.read(1024 * 1024) {
            digest.update(chunk);
            size += len(chunk);
        }
    }
    return (size, digest.hexdigest());
}

def module_revision(path: str) -> str {
    import from jaclang.compiler.session.cache.annexes {
        discover_annex_files,
        discover_style_annex
    }
    related = discover_annex_files(path, '.impl.jac')
        + discover_annex_files(path, '.test.jac');
    style = discover_style_annex(path);
    if style is not None {
        related.append(style);
    }
    digest = hashlib.sha256();
    for source in [path] + sorted(related) {
        digest.update(repr((source, content_stamp(source))).encode());
    }
    return digest.hexdigest();
}
