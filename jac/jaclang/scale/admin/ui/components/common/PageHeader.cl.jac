"""Shared page-header bar and ops banner for admin dashboard pages.

PageHeader renders the standard `icon + title [+ namespace] [+ Live]`
row with either the stock Refresh button (pass `onRefresh`) or custom
right-side content (pass `right`). OpsUnavailableBanner is the warning
strip the ops pages show when the cluster view is degraded; only the
label/remediation wording differs per page.
"""

import from "lucide-react" { RefreshCw, AlertTriangle }

def:pub PageHeader(
    icon: any,
    title: str,
    namespace: str = "",
    live: bool = False,
    onRefresh: any = None,
    right: any = None
) -> JsxElement {
    Icon = icon;
    rightContent = right;
    if (not rightContent) and onRefresh {
        rightContent = <button
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md bg-surface-2 text-fg border border-line hover:bg-line transition-colors"
            onClick={onRefresh}
        >
            <RefreshCw className="w-3.5 h-3.5"/>
            Refresh
        </button>;
    }
    return
        <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
                <Icon className="w-5 h-5 text-accent"/>
                <h1 className="text-lg font-semibold text-fg">{title}</h1>
                {<span className="text-xs text-faint">{namespace}</span>
                    if namespace
                    else None}
                {<span
                    className="ml-1 inline-flex items-center gap-1.5 text-xs text-success"
                >
                    <span className="w-1.5 h-1.5 rounded-full bg-success"></span>
                    Live
                </span>
                    if live
                    else None}
            </div>
            {rightContent}
        </div>;
}

def:pub OpsUnavailableBanner(
    detail: str,
    remediation: str,
    show: bool = False,
    label: str = "Cluster view unavailable"
) -> JsxElement | None {
    return <div
        className="flex items-start gap-2 text-warning text-sm bg-warning-weak border border-line rounded-md p-3"
    >
        <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5"/>
        <span className="text-muted">{label + ": " + detail + ". " + remediation}</span>
    </div>
        if show
        else None;
}
