cl import from "recharts" {
    Tooltip as RechartsTooltip,
    Legend as RechartsLegend,
    ResponsiveContainer
}
cl import from react { createContext, useContext }
cl import from ...lib.utils { cn }

glob ChartContext: Any = createContext(null);

cl {
    def getPayloadConfig(config: Any, payload: Any, key: Any) -> Any {
        if not config { return None; }
        configLabelKey = key;
        if payload and payload[key] and (payload[key] + "") == payload[key] {
            configLabelKey = payload[key];
        }
        if configLabelKey in config { return config[configLabelKey]; }
        return config[key] if key in config else None;
    }

    def buildChartStyle(config: Any) -> Any {
        styleObj = {};
        entries = Object.entries(config).filter(lambda(e: Any) -> Any { return e[1].theme or e[1].color; });
        for entry in entries {
            k = entry[0];
            ic = entry[1];
            color = ic.color if ic.color else None;
            if color {
                styleObj["--color-" + k] = color;
            }
        }
        return styleObj;
    }

    def:pub ChartContainer(props: Any) -> JsxElement {
        config = props.config or {};
        colorStyle = buildChartStyle(config);
        ctxValue = {config: config};
        return <ChartContext.Provider value={ctxValue}>
            <div
                {...props}
                data-slot="chart"
                style={Object.assign({}, props.style or {}, colorStyle)}
                className={cn(
                    "cn-chart flex aspect-video justify-center text-xs",
                    props.className
                )}
            >
                <ResponsiveContainer>
                    {props.children}
                </ResponsiveContainer>
            </div>
        </ChartContext.Provider>;
    }

    def:pub ChartTooltipContent(props: Any) -> JsxElement {
        active = props.active;
        payload = props.payload;
        hideIndicator = props.hideIndicator or false;
        indicator = props.indicator or "dot";
        ctx = useContext(ChartContext);
        config = ctx.config if ctx else {};
        hasItems = active and payload and payload.length;
        filteredPayload = hasItems and payload.filter(lambda(item: Any) -> Any { return item.type != "none"; }) or [];
        return <div className={cn("border-border/50 bg-background gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs shadow-xl grid min-w-32 items-start gap-1.5 px-2.5 py-1.5 text-xs shadow-xl", props.className)}>
            {hasItems and filteredPayload.map(lambda(item: Any) -> Any {
                itemKey = props.nameKey or item.name or item.dataKey or "value";
                itemConfig = getPayloadConfig(config, item, itemKey);
                indicatorColor = props.color or (item.payload.fill if item.payload else None) or item.color;
                return <div key={item.dataKey} className="flex w-full flex-wrap items-center gap-2">
                    {not hideIndicator and (
                        <div
                            className={cn("shrink-0 rounded-[2px]", "size-2.5" if indicator == "dot" else "w-1")}
                            style={{backgroundColor: indicatorColor}}
                        />
                    )}
                    <div className="flex flex-1 justify-between leading-none">
                        <span className="text-muted-foreground">
                            {itemConfig and itemConfig.label or itemKey}
                        </span>
                        {item.value != None and (
                            <span className="font-mono font-medium tabular-nums text-foreground">
                                {item.value.toLocaleString()}
                            </span>
                        )}
                    </div>
                </div>;
            })}
        </div>;
    }

    def:pub ChartLegendContent(props: Any) -> JsxElement {
        payload = props.payload;
        hideIcon = props.hideIcon or false;
        verticalAlign = props.verticalAlign or "bottom";
        ctx = useContext(ChartContext);
        config = ctx.config if ctx else {};
        items = payload and payload.length and payload or [];
        topClass = "pb-3" if verticalAlign == "top" else "";
        return <div className={cn("flex items-center justify-center gap-4", topClass, props.className)}>
            {items and items.map(lambda(item: Any) -> Any {
                k = props.nameKey or item.dataKey or "value";
                itemConfig = getPayloadConfig(config, item, k);
                return <div key={item.value} className="flex items-center gap-1.5">
                    {not hideIcon and (
                        <div className="size-2 shrink-0 rounded-[2px]" style={{backgroundColor: item.color}} />
                    )}
                    <span className="text-muted-foreground text-xs">
                        {itemConfig and itemConfig.label or item.value}
                    </span>
                </div>;
            })}
        </div>;
    }

    def:pub ChartTooltip(props: Any) -> JsxElement {
        return <RechartsTooltip {...props} />;
    }

    def:pub ChartLegend(props: Any) -> JsxElement {
        return <RechartsLegend {...props} />;
    }
}
