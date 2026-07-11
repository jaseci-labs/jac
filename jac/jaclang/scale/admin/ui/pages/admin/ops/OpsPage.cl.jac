"""Operations self-check page for the admin dashboard.

Renders GET /admin/ops/health as one card per signal (traces, logs,
metrics, mongo, redis, admin API). Each card shows the causal chain as a
vertical stepper: a green check / red x / grey dash per step, with the
FIRST RED step highlighted - that step IS the diagnosis (e.g. "tracing
extra NOT installed" closes the count:0 incident in a glance, and
"Mongo ping reachable: failed" closes the admin-login-HTML incident).

Kubeconfig-free: every check is an in-process read or a short backend
probe done server-side, so operators never need kubectl to know why
observability/health is broken.
"""

import from "lucide-react" { Stethoscope, RefreshCw, Check, X, Minus, AlertTriangle }

import from react { useEffect }
import from ....components.common.PageHeader { PageHeader }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getOpsHealth }
import from ....utils.api { getErrorMessage }

# Per-signal display labels. Keys match the backend `signals` dict.
glob SIGNAL_ORDER = ["traces", "logs", "metrics", "mongo", "redis", "admin_api"],
     SIGNAL_LABELS = {
         "traces": "Traces",
         "logs": "Logs",
         "metrics": "Metrics",
         "mongo": "Mongo",
         "redis": "Redis",
         "admin_api": "Admin API"
     };

def:pub OpsPage -> JsxElement {
    has isLoading: bool = False,
        signals: dict = {},
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def loadHealth {
        isLoading = True;
        try {
            result = await getOpsHealth(auth["authToken"]);
            if result["ok"] and result["data"] {
                signals = result["data"]["signals"] or {};
                errorMsg = "";
            } elif result["error"] {
                errorMsg = getErrorMessage(result, "Failed to load self-check");
            }
        } except Exception as e {
            console.error("loadHealth error:", e);
            errorMsg = "Error loading self-check: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { loadHealth(); }, []);

    # ---- helpers -----------------------------------------------------
    # Per-step status icon as a DICT of pre-built elements (NOT a
    # def -> JsxElement helper, which would compile to a React
    # component and drop the argument). Keyed "ok"/"fail"/"skip".
    stepIcons = {
        "ok": <Check className="w-3.5 h-3.5 text-success shrink-0"/>,
        "fail": <X className="w-3.5 h-3.5 text-danger shrink-0"/>,
        "skip": <Minus className="w-3.5 h-3.5 text-faint shrink-0"/>
    };

    def stepKey(ok: any) -> str {
        if ok == True {
            return "ok";
        }
        if ok == False {
            return "fail";
        }
        return "skip";
    }

    # Card header accent by signal status.
    def statusBadgeCls(status: str) -> str {
        base = "text-[11px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded ";
        if status == "ok" {
            return base + "bg-success-weak text-success";
        }
        if status == "off" {
            return base + "bg-warning-weak text-warning";
        }
        return base + "bg-danger-weak text-danger";
    }

    def statusLabel(status: str) -> str {
        if status == "ok" {
            return "Healthy";
        }
        if status == "off" {
            return "Off";
        }
        return "Problem";
    }

    # Annotate each step with `_firstFail` (only the first ok==False
    # rung is true) so the render comprehension needs no index/enumerate
    # (avoided: enumerate has no cl.jac/JS equivalent). Names are unique
    # within a chain, so `name` doubles as the React key.
    def annotate(chain: list) -> list {
        seenFail = False;
        out: list = [];
        for step in chain {
            first = (not seenFail) and (step["ok"] == False);
            if first {
                seenFail = True;
            }
            out.push(
                {
                    "name": step["name"],
                    "ok": step["ok"],
                    "detail": step["detail"],
                    "_firstFail": first
                }
            );
        }
        return out;
    }

    # Precompute plain-dict card data (NOT JSX). A def returning JSX
    # would compile to a React component and drop its positional arg
    # (the navIcon trap), so the card markup is inlined in the render
    # comprehension below and this only assembles data.
    def cardData -> list {
        out: list = [];
        for name in SIGNAL_ORDER {
            sig = signals[name];
            if not sig {
                continue;
            }
            status = String(sig["status"] or "fail");
            out.push(
                {
                    "name": name,
                    "label": SIGNAL_LABELS[name] or name,
                    "badgeCls": statusBadgeCls(status),
                    "statusLabel": statusLabel(status),
                    "steps": annotate(sig["chain"] or [])
                }
            );
        }
        return out;
    }

    # ---- render ------------------------------------------------------
    # Deviates from the stock PageHeader refresh: disabled while
    # loading, spinning icon - so it rides in the `right` slot.
    refreshBtn = <button
        className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md bg-surface-2 text-fg border border-line hover:bg-line transition-colors disabled:opacity-60"
        onClick={lambda { loadHealth(); }}
        disabled={isLoading}
    >
        <RefreshCw className={"w-3.5 h-3.5 " + (isLoading and "animate-spin" or "")}/>
        Refresh
    </button>;

    return
        <div className="space-y-4">
            <PageHeader
                icon={Stethoscope}
                title="Signal Self-Check"
                right={refreshBtn}
            />
            <p className="text-sm text-muted">
                Each signal's causal chain, evaluated top-down. The first red step is the diagnosis - no kubectl needed.
            </p>
            {<div
                className="flex items-start gap-2 text-danger text-sm bg-danger-weak border border-line rounded-md p-3"
            >
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5"/>
                <span>{errorMsg}</span>
            </div>
                if errorMsg
                else None}
            {<div className="text-faint text-sm">Running self-check...</div>
                if (isLoading and not loadedOnce)
                else None}
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                {[
                    <div
                        key={card["name"]}
                        className="rounded-lg border border-line bg-surface p-4 space-y-3"
                    >
                        <div className="flex items-center justify-between">
                            <h2 className="text-sm font-semibold text-fg">
                                {card["label"]}
                            </h2>
                            <span className={card["badgeCls"]}>
                                {card["statusLabel"]}
                            </span>
                        </div>
                        <div className="space-y-0.5">
                            {[
                                <div
                                    key={step["name"]}
                                    className={"flex items-start gap-2 px-2 py-1.5 rounded " + (
                                        "bg-danger-weak ring-1 ring-danger/40"
                                            if step["_firstFail"]
                                            else ""
                                    )}
                                >
                                    {stepIcons[stepKey(step["ok"])]
                                    or <Minus
                                        className="w-3.5 h-3.5 text-faint shrink-0"
                                    />}
                                    <div className="min-w-0">
                                        <div
                                            className={"text-xs " + (
                                                "font-medium text-fg"
                                                    if step["_firstFail"]
                                                    else "text-muted"
                                            )}
                                        >
                                            {step["name"]}
                                        </div>
                                        <div
                                            className="text-[11px] text-faint break-words"
                                        >
                                            {step["detail"]}
                                        </div>
                                    </div>
                                </div> for step in card["steps"]
                            ]}
                        </div>
                    </div> for card in cardData()
                ]}
            </div>
            {<div className="text-faint text-sm">No signals reported.</div>
                if (loadedOnce and len(cardData()) == 0)
                else None}
        </div>;
}
