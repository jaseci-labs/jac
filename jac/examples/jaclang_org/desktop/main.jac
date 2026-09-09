import from core.jacyac.github.auth {
    github_enabled,
    begin_github,
    github_callback_mode,
    finish_github,
    complete_native_github,
    poll_github
}
import from core.jacyac.github.repos { github_repositories }
import "../core/site/styles/global.css";
import "../core/site/styles/site.css";
import "../core/site/styles/brand.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
