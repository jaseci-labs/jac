"""Shared web component: raw HTML is legal here because only the web app
(kind "web-app", a DOM ui) imports it. Under a mobile app the <div> would be E1105."""

import from core.helper { label }

def:pub Card(count: int) -> JsxElement {
    return <div>{label(count)}</div>;
}
