import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Alert01Icon,
    ArrowLeft01Icon,
    ArrowRight01Icon
}

def:pub DocsArticleSkeleton -> JsxElement;

def:pub DocsArticle(page: DocPageView, version: str, loading: bool) -> JsxElement;
