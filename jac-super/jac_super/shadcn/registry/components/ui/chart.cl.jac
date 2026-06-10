import from "recharts" {
    Tooltip as RechartsTooltip,
    Legend as RechartsLegend,
    ResponsiveContainer
}
import from react { createContext, useContext }
import from ...lib.utils { cn }

glob ChartContext: any = createContext(None);

def getPayloadConfig(config: any, payload: any, key: any) -> any {
    if not config {
        return None;
    }
    configLabelKey = key;
    if payload and payload[key] and isinstance(payload[key], str) {
        configLabelKey = payload[key];
    }
    cfg: dict[str, any] = {** config};
    if configLabelKey in cfg {
        return cfg[configLabelKey];
    }
    return cfg[key] if key in cfg else None;
}

def buildChartStyle(config: any) -> any {
    styleObj = {};
    for k in Object.keys(config) {  # jac:ignore[W6001]
        ic: any = config[k];
        color = ic.color if ic else None;
        if color {
            styleObj["--color-" + str(k)] = color;
        }
    }
    return styleObj;
}

def:pub ChartContainer(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    config = props["config"] or {};
    colorStyle = buildChartStyle(config);
    ctxValue = {"config": config};
    return
        <ChartContext.Provider value={ctxValue}>
            <div
                {**attrs}
                data-slot="chart"
                style={{** (props["style"] or {}), ** colorStyle}}
                className={cn(
                    "cn-chart flex aspect-video justify-center text-xs",
                    props["className"]
                )}
            >
                <ResponsiveContainer>{props["children"]}</ResponsiveContainer>
            </div>
        </ChartContext.Provider>;
}

def:pub ChartTooltipContent(props: any) -> JsxElement {
    active = props["active"];
    payload = props["payload"];
    hideIndicator = props["hideIndicator"] or False;
    indicator = props["indicator"] or "dot";
    ctx: any = useContext(ChartContext);
    config = ctx.config if ctx else {};
    filteredPayload: list[any] = [
        item
        for item in (payload or [])
        if item.type != "none"
    ];
    hasItems = active and len(filteredPayload);
    return
        <div
            className={cn(
                "cn-chart-tooltip grid min-w-32 items-start gap-1.5 px-2.5 py-1.5 text-xs shadow-xl",
                props["className"]
            )}
        >
            {if hasItems {
                for item in filteredPayload {
                    itemKey = props["nameKey"] or item.name or item.dataKey or "value";
                    itemConfig = getPayloadConfig(config, item, itemKey);
                    indicatorColor = props["color"]
                    or (item.payload.fill if item.payload else None)
                    or item.color;
                    <div
                        key={item.dataKey}
                        className="flex w-full flex-wrap items-center gap-2"
                    >
                        {not hideIndicator
                        and (
                            <div
                                className={cn(
                                    "shrink-0 rounded-[2px]",
                                    "size-2.5" if indicator == "dot" else "w-1"
                                )}
                                style={{"backgroundColor": indicatorColor}}
                            />
                        )}
                        <div className="flex flex-1 justify-between leading-none">
                            <span className="text-muted-foreground">
                                {itemConfig and itemConfig.label or itemKey}
                            </span>
                            {item.value is not None
                            and (
                                <span
                                    className="font-mono font-medium tabular-nums text-foreground"
                                >
                                    {item.value.toLocaleString()}
                                </span>
                            )}
                        </div>
                    </div>
                }
            }}
        </div>;
}

def:pub ChartLegendContent(props: any) -> JsxElement {
    payload = props["payload"];
    hideIcon = props["hideIcon"] or False;
    verticalAlign = props["verticalAlign"] or "bottom";
    ctx: any = useContext(ChartContext);
    config = ctx.config if ctx else {};
    items: any = payload or [];
    topClass = "pb-3" if verticalAlign == "top" else "";
    return
        <div
            className={cn(
                "flex items-center justify-center gap-4", topClass, props["className"]
            )}
        >
            {for item in items {
                k = props["nameKey"] or item.dataKey or "value";
                itemConfig = getPayloadConfig(config, item, k);
                <div key={item.value} className="flex items-center gap-1.5">
                    {not hideIcon
                    and (
                        <div
                            className="size-2 shrink-0 rounded-[2px]"
                            style={{"backgroundColor": item.color}}
                        />
                    )}
                    <span className="text-muted-foreground text-xs">
                        {itemConfig and itemConfig.label or item.value}
                    </span>
                </div>
            }}
        </div>;
}

def:pub ChartTooltip(props: any) -> JsxElement {
    return <RechartsTooltip {**props}/>;
}

def:pub ChartLegend(props: any) -> JsxElement {
    return <RechartsLegend {**props}/>;
}
