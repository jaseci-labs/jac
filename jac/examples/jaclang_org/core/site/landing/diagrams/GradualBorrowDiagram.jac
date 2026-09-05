import from .motion { view_once }
import from "motion/react" { motion }

glob MPath: any = motion.path,
     MLine: any = motion.line,
     MText: any = motion.text,
     MCircle: any = motion.circle;

def:pub TaxChip(x: int, y: int, w: int, label: str) -> JsxElement {
    return
        <g opacity="0.75">
            <rect
                x={x}
                y={y}
                width={w}
                height="18"
                rx="9"
                fill="none"
                stroke="var(--border)"
                strokeDasharray="3 3"
            />
            <text
                x={x + w / 2}
                y={y + 12}
                textAnchor="middle"
                fontSize="8"
                fill="var(--muted-foreground)"
                fontFamily="monospace"
            >
                {label}
            </text>
        </g>;
}

def:pub GradualBorrowDiagram -> JsxElement {
    return
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div
                className="rounded-2xl border border-border/70 bg-card/30 pt-5 pb-5 pl-5 pr-5"
            >
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                >
                    Today — pick a memory religion for the whole program
                </p>
                <svg
                    viewBox="0 0 440 320"
                    className="w-full"
                    aria-label="Conventional choice: fully managed languages tax every object at runtime, ownership languages annotate everything up front — with no middle ground between them"
                >
                    {#* managed world: everything aliased, GC taxes every object *#}
                    <rect
                        x="52"
                        y="16"
                        width="336"
                        height="112"
                        rx="12"
                        fill="var(--card)"
                        stroke="var(--border)"
                    />
                    <text
                        x="220"
                        y="36"
                        textAnchor="middle"
                        fontSize="11"
                        fontWeight="600"
                        fill="var(--foreground)"
                    >
                        managed — everything shared
                    </text>
                    <line
                        x1="118"
                        y1="84"
                        x2="212"
                        y2="62"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="118"
                        y1="84"
                        x2="212"
                        y2="104"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="212"
                        y1="62"
                        x2="318"
                        y2="92"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="212"
                        y1="104"
                        x2="318"
                        y2="92"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="118"
                        y1="84"
                        x2="318"
                        y2="92"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.35"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="212"
                        y1="62"
                        x2="212"
                        y2="104"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.35"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <circle
                        cx="118"
                        cy="84"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <circle
                        cx="212"
                        cy="62"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <circle
                        cx="212"
                        cy="104"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <circle
                        cx="318"
                        cy="92"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <text
                        x="220"
                        y="122"
                        textAnchor="middle"
                        fontSize="8.5"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        GC / RC taxes every object, forever
                    </text>
                    {#* the missing middle *#}
                    <line
                        x1="94"
                        y1="160"
                        x2="346"
                        y2="160"
                        stroke="var(--destructive)"
                        strokeOpacity="0.5"
                        strokeWidth="1"
                        strokeDasharray="5 7"
                        className="dash-drift"
                    />
                    <text
                        x="220"
                        y="152"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--destructive)"
                        fillOpacity="0.9"
                    >
                        no middle ground
                    </text>
                    <text
                        x="76"
                        y="164"
                        textAnchor="middle"
                        fontSize="11"
                        fill="var(--destructive)"
                        className="x-pulse"
                    >
                        ✕
                    </text>
                    <text
                        x="364"
                        y="164"
                        textAnchor="middle"
                        fontSize="11"
                        fill="var(--destructive)"
                        className="x-pulse"
                        style={{"animationDelay": "0.9s"}}
                    >
                        ✕
                    </text>
                    {#* ownership world: annotations on everything, day one *#}
                    <rect
                        x="52"
                        y="182"
                        width="336"
                        height="112"
                        rx="12"
                        fill="var(--card)"
                        stroke="var(--border)"
                    />
                    <text
                        x="220"
                        y="202"
                        textAnchor="middle"
                        fontSize="11"
                        fontWeight="600"
                        fill="var(--foreground)"
                    >
                        owned — everything annotated
                    </text>
                    <rect
                        x="86"
                        y="222"
                        width="76"
                        height="30"
                        rx="8"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.5"
                    />
                    <text
                        x="124"
                        y="241"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--foreground)"
                    >
                        &amp;'a T
                    </text>
                    <rect
                        x="182"
                        y="222"
                        width="76"
                        height="30"
                        rx="8"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.5"
                    />
                    <text
                        x="220"
                        y="241"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--foreground)"
                    >
                        &amp;mut u
                    </text>
                    <rect
                        x="278"
                        y="222"
                        width="76"
                        height="30"
                        rx="8"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.5"
                    />
                    <text
                        x="316"
                        y="241"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--foreground)"
                    >
                        Box&lt;T&gt;
                    </text>
                    <line
                        x1="162"
                        y1="237"
                        x2="182"
                        y2="237"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.6"
                    />
                    <line
                        x1="258"
                        y1="237"
                        x2="278"
                        y2="237"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.6"
                    />
                    <TaxChip x={96} y={262} w={110} label="lifetimes on day one"/>
                    <TaxChip x={236} y={262} w={110} label="fights every borrow"/>
                </svg>
                <p className="mt-3 text-sm text-muted-foreground">
                    One tax or the other — and you owe it on the entire codebase.
                </p>
            </div>
            <div
                className="rounded-2xl border border-primary/30 bg-primary/5 pt-5 pb-5 pl-5 pr-5"
            >
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-primary"
                >
                    Jac — ownership is a dial, turned per declaration
                </p>
                <svg
                    viewBox="0 0 440 320"
                    className="w-full"
                    aria-label="Jac: values start fully managed; declaring own moves one into a checked region where reference counting disappears and escapes are compile errors"
                >
                    <defs>
                        <linearGradient id="gradBorrow" x1="0" y1="0" x2="1" y2="0">
                            <stop offset="0%" stopColor="#f7931e" stopOpacity="0.03"/>
                            <stop offset="55%" stopColor="#f7931e" stopOpacity="0.08"/>
                            <stop offset="100%" stopColor="#e8442c" stopOpacity="0.2"/>
                        </linearGradient>
                    </defs>
                    {#* the dial, one notch per declaration *#}
                    <text
                        x="104"
                        y="34"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        x = obj()
                    </text>
                    <MPath
                        d="M150,30 L262,30"
                        fill="none"
                        stroke="#ff6b35"
                        strokeOpacity="0.6"
                        strokeWidth="1.2"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.6, "delay": 0.3}}
                    />
                    <polygon
                        points="262,30 254,26 254,34"
                        fill="#ff6b35"
                        fillOpacity="0.75"
                    />
                    <MText
                        x="322"
                        y="34"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fontWeight="700"
                        fill="#ff6b35"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 0.7}}
                    >
                        own y = obj()
                    </MText>
                    {#* one heap, two disciplines *#}
                    <rect
                        x="30"
                        y="56"
                        width="380"
                        height="170"
                        rx="22"
                        fill="url(#gradBorrow)"
                        stroke="#ff6b35"
                        strokeOpacity="0.45"
                        strokeWidth="1.2"
                    />
                    <line
                        x1="236"
                        y1="66"
                        x2="236"
                        y2="216"
                        stroke="var(--border)"
                        strokeDasharray="3 5"
                    />
                    <text
                        x="133"
                        y="82"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        managed — GC&apos;d
                    </text>
                    <text
                        x="323"
                        y="82"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fontWeight="700"
                        fill="#ff6b35"
                    >
                        own region — zero RC
                    </text>
                    {#* managed side: loose aliases, business as usual *#}
                    <line
                        x1="90"
                        y1="140"
                        x2="160"
                        y2="118"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="90"
                        y1="140"
                        x2="160"
                        y2="170"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.45"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <line
                        x1="160"
                        y1="118"
                        x2="160"
                        y2="170"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.35"
                        strokeDasharray="4 5"
                        className="dash-drift"
                    />
                    <circle
                        cx="90"
                        cy="140"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <circle
                        cx="160"
                        cy="118"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    <circle
                        cx="160"
                        cy="170"
                        r="7"
                        fill="var(--card)"
                        stroke="var(--foreground)"
                        strokeOpacity="0.55"
                    />
                    {#* the gate: one keyword moves a value across *#}
                    <rect
                        x="204"
                        y="136"
                        width="64"
                        height="18"
                        rx="9"
                        fill="var(--card)"
                        stroke="#ff6b35"
                        strokeOpacity="0.6"
                    />
                    <text
                        x="236"
                        y="148.5"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="#ff6b35"
                    >
                        own
                    </text>
                    <circle r="5" fill="#ff6b35" className="g-walker">
                        <animateMotion
                            dur="3.6s"
                            repeatCount="indefinite"
                            path="M118,145 L236,145 L336,145"
                        />
                    </circle>
                    {#* owned side: single owner, checked borrows *#}
                    <MCircle
                        cx="336"
                        cy="145"
                        r="8"
                        fill="#ff6b35"
                        fillOpacity="0.2"
                        stroke="#ff6b35"
                        strokeOpacity="0.8"
                        strokeWidth="1.4"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 0.5}}
                    />
                    <MPath
                        d="M336,153 C318,182 302,190 282,192"
                        fill="none"
                        stroke="#56d364"
                        strokeOpacity="0.6"
                        strokeWidth="1.2"
                        strokeDasharray="3 4"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.6, "delay": 0.8}}
                    />
                    <MText
                        x="266"
                        y="204"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="#56d364"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 1.2}}
                    >
                        borrow ✓ checked
                    </MText>
                    <MPath
                        d="M366,150 C388,166 396,186 398,214"
                        fill="none"
                        stroke="var(--destructive)"
                        strokeOpacity="0.6"
                        strokeWidth="1.2"
                        strokeDasharray="3 4"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.6, "delay": 1.0}}
                    />
                    <text
                        x="398"
                        y="228"
                        textAnchor="middle"
                        fontSize="11"
                        fill="var(--destructive)"
                        className="x-pulse"
                    >
                        ✕
                    </text>
                    <MText
                        x="352"
                        y="244"
                        textAnchor="middle"
                        fontSize="8.5"
                        fontFamily="monospace"
                        fill="var(--destructive)"
                        fillOpacity="0.9"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 1.4}}
                    >
                        escape = compile error
                    </MText>
                    {#* payoff *#}
                    <MLine
                        x1="133"
                        y1="258"
                        x2="133"
                        y2="282"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.5"
                        strokeWidth="1.1"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.4, "delay": 1.5}}
                    />
                    <MLine
                        x1="323"
                        y1="258"
                        x2="323"
                        y2="282"
                        stroke="#ff6b35"
                        strokeOpacity="0.6"
                        strokeWidth="1.1"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.4, "delay": 1.6}}
                    />
                    <MText
                        x="133"
                        y="298"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 1.7}}
                    >
                        ships as today&apos;s code
                    </MText>
                    <MText
                        x="323"
                        y="298"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="#ff6b35"
                        initial={{"opacity": 0}}
                        whileInView={{"opacity": 1}}
                        viewport={view_once()}
                        transition={{"delay": 1.8}}
                    >
                        ships Rust-grade native
                    </MText>
                </svg>
                <p className="mt-3 text-sm text-muted-foreground">
                    The checker only bills the code that{" "}
                    <span className="font-medium text-foreground">opts in</span>{" "}
                    — start managed, tighten one declaration at a time.
                </p>
            </div>
        </div>;
}
