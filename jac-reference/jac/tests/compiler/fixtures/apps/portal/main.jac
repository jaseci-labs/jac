"""Dir-rooted `portal` web app whose page is shared UI from outside every app root."""

import from ..shared_ui { Panel }

def:pub app -> JsxElement {
    return <Panel/>;
}
