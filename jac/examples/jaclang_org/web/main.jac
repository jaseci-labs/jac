import from core.jacyac.github.auth {
    github_enabled,
    begin_github,
    github_callback_mode,
    finish_github,
    complete_native_github,
    poll_github
}
import from core.jacyac.github.repos { github_repositories }
import from core.source.files {
    source_tree,
    source_file,
    source_span,
    example_sources,
    SourceFile,
    SourceView,
    SourceSpan
}
import from core.docs.graph { docs_status, doc_tree, doc_page, llms_txt }
import from core.docs.sync { docs_sync_tick }
import from core.install { ensure_install, install_sh }

import "../core/site/styles/global.css";
import "../core/site/styles/site.css";
import "../core/site/styles/brand.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
