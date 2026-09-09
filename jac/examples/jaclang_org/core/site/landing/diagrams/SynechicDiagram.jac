import from .motion { view_once }
import from "motion/react" { motion }

glob MPath: any = motion.path,
     MLine: any = motion.line,
     MText: any = motion.text,
     C_COMPILER: str = "#a78bfa",
     C_PROGRAM: str = "#ff6b35",
     C_ECO: str = "#56d364";

def:pub StackBox(x: int, y: int, label: str, sub: str) -> JsxElement {
    return
        <g>
            <rect
                x={x}
                y={y}
                width="220"
                height="52"
                rx="10"
                fill="var(--card)"
                stroke={C_PROGRAM}
                strokeOpacity="0.55"
                strokeWidth="1.2"
            />
            <text
                x={x + 110}
                y={y + 23}
                textAnchor="middle"
                fontSize="13"
                fontWeight="600"
                fill="var(--foreground)"
            >
                {label}
            </text>
            <text
                x={x + 110}
                y={y + 40}
                textAnchor="middle"
                fontSize="9"
                fill="var(--muted-foreground)"
                fontFamily="monospace"
            >
                {sub}
            </text>
        </g>;
}

def:pub GhostChip(x: int, y: int, w: int, label: str) -> JsxElement {
    return
        <g opacity="0.65">
            <rect
                x={x}
                y={y}
                width={w}
                height="20"
                rx="10"
                fill="none"
                stroke="var(--border)"
                strokeDasharray="3 3"
            />
            <text
                x={x + w / 2}
                y={y + 13}
                textAnchor="middle"
                fontSize="8.5"
                fill="var(--muted-foreground)"
                fontFamily="monospace"
            >
                {label}
            </text>
        </g>;
}

def:pub ToolChip(x: int, y: int, w: int, label: str, tone: str = "") -> JsxElement {
    return
        <g>
            <rect
                x={x}
                y={y}
                width={w}
                height="20"
                rx="10"
                fill="var(--card)"
                stroke={tone if tone != "" else "var(--border)"}
                strokeOpacity={0.55 if tone != "" else 1.0}
            />
            <text
                x={x + w / 2}
                y={y + 13}
                textAnchor="middle"
                fontSize="8.5"
                fill={tone if tone != "" else "var(--muted-foreground)"}
                fontFamily="monospace"
            >
                {label}
            </text>
        </g>;
}

def:pub RoleDot(color: str, label: str) -> JsxElement {
    return
        <span className="flex items-center gap-2 text-muted-foreground">
            <span className="size-2 rounded-full" style={{"background": color}}></span>
            {label}
        </span>;
}

def:pub CallPill(cx: int, label: str) -> JsxElement {
    return
        <g>
            <rect
                x={cx - 38}
                y="142"
                width="76"
                height="17"
                rx="8.5"
                fill="var(--card)"
                stroke="#ff6b35"
                strokeOpacity="0.5"
            />
            <text
                x={cx}
                y="153.5"
                textAnchor="middle"
                fontSize="8.5"
                fill="#ff6b35"
                fontFamily="monospace"
            >
                {label}
            </text>
        </g>;
}

def:pub Boundary(y: int, label: str) -> JsxElement {
    return
        <g>
            <line
                x1="118"
                y1={y}
                x2="322"
                y2={y}
                stroke="var(--destructive)"
                strokeOpacity="0.5"
                strokeWidth="1"
                strokeDasharray="5 7"
                className="dash-drift"
            />
            <text
                x="220"
                y={y + 16}
                textAnchor="middle"
                fontSize="9"
                fill="var(--destructive)"
                fillOpacity="0.9"
                fontFamily="monospace"
            >
                {label}
            </text>
            <text
                x="146"
                y={y + 4}
                textAnchor="middle"
                fontSize="11"
                fill="var(--destructive)"
                className="x-pulse"
            >
                ✕
            </text>
            <text
                x="294"
                y={y + 4}
                textAnchor="middle"
                fontSize="11"
                fill="var(--destructive)"
                className="x-pulse"
                style={{"animationDelay": "0.9s"}}
            >
                ✕
            </text>
        </g>;
}

def:pub SynechicDiagram -> JsxElement {
    return
        <div>
            <div
                className="mb-4 flex flex-wrap items-center justify-center gap-x-6 gap-y-1 font-mono text-[10px] uppercase tracking-widest"
            >
                <RoleDot color={C_COMPILER} label="compiler"/>
                <RoleDot color={C_PROGRAM} label="program"/>
                <RoleDot color={C_ECO} label="ecosystem"/>
            </div>
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
                <div
                    className="rounded-2xl border border-border/70 bg-card/30 pt-5 pb-5 pl-5 pr-5"
                >
                    <p
                        className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                    >
                        Today — three programs, hand-synced
                    </p>
                    <svg
                        viewBox="0 0 440 320"
                        className="w-full"
                        aria-label="A conventional stack: three programs, each with its own compiler and ecosystem, joined by unchecked boundaries"
                    >
                        <StackBox x={110} y={14} label="TypeScript" sub="browser"/>
                        <ToolChip
                            x={16}
                            y={30}
                            w={88}
                            label="tsc · node"
                            tone={C_COMPILER}
                        />
                        <ToolChip x={336} y={30} w={88} label="npm" tone={C_ECO}/>
                        <Boundary y={94} label="JSON over the wire — unchecked"/>
                        <GhostChip x={16} y={84} w={88} label="route table"/>
                        <GhostChip x={340} y={84} w={84} label="OpenAPI"/>
                        <StackBox x={110} y={128} label="Python" sub="server"/>
                        <ToolChip
                            x={16}
                            y={144}
                            w={88}
                            label="CPython"
                            tone={C_COMPILER}
                        />
                        <ToolChip
                            x={336}
                            y={144}
                            w={88}
                            label="pip · PyPI"
                            tone={C_ECO}
                        />
                        <Boundary y={208} label="FFI — unchecked"/>
                        <GhostChip x={16} y={198} w={88} label="ORM models"/>
                        <GhostChip x={340} y={198} w={84} label="serializers"/>
                        <StackBox x={110} y={242} label="C / Rust" sub="native"/>
                        <ToolChip
                            x={16}
                            y={258}
                            w={88}
                            label="gcc · rustc"
                            tone={C_COMPILER}
                        />
                        <ToolChip
                            x={336}
                            y={258}
                            w={88}
                            label="crates · apt"
                            tone={C_ECO}
                        />
                    </svg>
                    <p className="mt-3 text-sm text-muted-foreground">
                        Rename a field: it ships anyway, and fails in production.
                    </p>
                </div>
                <div
                    className="rounded-2xl border border-primary/30 bg-primary/5 pt-5 pb-5 pl-5 pr-5"
                >
                    <p
                        className="mb-3 font-mono text-[10px] uppercase tracking-widest text-primary"
                    >
                        Jac — a codespace boundary is just a function call
                    </p>
                    <svg
                        viewBox="0 0 440 320"
                        className="w-full"
                        aria-label="Jac: one continuous checked medium across client, server, and native"
                    >
                        <defs>
                            <linearGradient id="synGrad" x1="0" y1="0" x2="1" y2="0">
                                <stop
                                    offset="0%"
                                    stopColor="#f7931e"
                                    stopOpacity="0.14"
                                />
                                <stop
                                    offset="100%"
                                    stopColor="#e8442c"
                                    stopOpacity="0.14"
                                />
                            </linearGradient>
                        </defs>
                        {#* one compiler, seeing every zone *#}
                        <rect
                            x="164"
                            y="10"
                            width="112"
                            height="28"
                            rx="14"
                            fill="var(--card)"
                            stroke={C_COMPILER}
                            strokeOpacity="0.6"
                        />
                        <text
                            x="220"
                            y="28"
                            textAnchor="middle"
                            fontSize="10"
                            fontFamily="monospace"
                            fill={C_COMPILER}
                        >
                            one compiler
                        </text>
                        <MPath
                            d="M196,38 C160,58 120,70 108,94"
                            fill="none"
                            stroke={C_COMPILER}
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.7, "delay": 0.2}}
                        />
                        <MPath
                            d="M220,38 L220,94"
                            fill="none"
                            stroke={C_COMPILER}
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.7, "delay": 0.35}}
                        />
                        <MPath
                            d="M244,38 C280,58 320,70 332,94"
                            fill="none"
                            stroke={C_COMPILER}
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.7, "delay": 0.5}}
                        />
                        {#* the continuous medium *#}
                        <rect
                            x="40"
                            y="96"
                            width="360"
                            height="110"
                            rx="26"
                            fill="url(#synGrad)"
                            stroke="#ff6b35"
                            strokeOpacity="0.45"
                            strokeWidth="1.2"
                        />
                        <line
                            x1="160"
                            y1="106"
                            x2="160"
                            y2="196"
                            stroke="var(--border)"
                            strokeDasharray="3 5"
                        />
                        <line
                            x1="280"
                            y1="106"
                            x2="280"
                            y2="196"
                            stroke="var(--border)"
                            strokeDasharray="3 5"
                        />
                        <text
                            x="100"
                            y="132"
                            textAnchor="middle"
                            fontSize="15"
                            fontWeight="700"
                            fontFamily="monospace"
                            fill="#ff6b35"
                        >
                            cl
                        </text>
                        <text
                            x="220"
                            y="132"
                            textAnchor="middle"
                            fontSize="15"
                            fontWeight="700"
                            fontFamily="monospace"
                            fill="#ff6b35"
                        >
                            sv
                        </text>
                        <text
                            x="340"
                            y="132"
                            textAnchor="middle"
                            fontSize="15"
                            fontWeight="700"
                            fontFamily="monospace"
                            fill="#ff6b35"
                        >
                            na
                        </text>
                        <text
                            x="100"
                            y="188"
                            textAnchor="middle"
                            fontSize="9"
                            fill="var(--muted-foreground)"
                            fontFamily="monospace"
                        >
                            browser
                        </text>
                        <text
                            x="220"
                            y="188"
                            textAnchor="middle"
                            fontSize="9"
                            fill="var(--muted-foreground)"
                            fontFamily="monospace"
                        >
                            server
                        </text>
                        <text
                            x="340"
                            y="188"
                            textAnchor="middle"
                            fontSize="9"
                            fill="var(--muted-foreground)"
                            fontFamily="monospace"
                        >
                            machine code
                        </text>
                        {#* a value crossing the whole medium, checked everywhere *#}
                        <circle r="4" fill="#ff6b35" className="g-walker">
                            <animateMotion
                                dur="3.2s"
                                repeatCount="indefinite"
                                path="M62,156 L378,156"
                            />
                        </circle>
                        {#* crossing a codespace boundary is just a function call *#}
                        <CallPill cx={160} label="await f(x)"/>
                        <CallPill cx={280} label="g(y)"/>
                        {#* ecosystems plug straight in *#}
                        <MLine
                            x1="110"
                            y1="268"
                            x2="106"
                            y2="208"
                            stroke="#56d364"
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.5, "delay": 0.7}}
                        />
                        <MLine
                            x1="220"
                            y1="268"
                            x2="220"
                            y2="208"
                            stroke="#56d364"
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.5, "delay": 0.85}}
                        />
                        <MLine
                            x1="330"
                            y1="268"
                            x2="334"
                            y2="208"
                            stroke="#56d364"
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.5, "delay": 1.0}}
                        />
                        <MText
                            x="120"
                            y="242"
                            fontSize="10"
                            fill="#56d364"
                            initial={{"opacity": 0}}
                            whileInView={{"opacity": 1}}
                            viewport={view_once()}
                            transition={{"delay": 1.1}}
                        >
                            ✓
                        </MText>
                        <MText
                            x="230"
                            y="242"
                            fontSize="10"
                            fill="#56d364"
                            initial={{"opacity": 0}}
                            whileInView={{"opacity": 1}}
                            viewport={view_once()}
                            transition={{"delay": 1.25}}
                        >
                            ✓
                        </MText>
                        <MText
                            x="344"
                            y="242"
                            fontSize="10"
                            fill="#56d364"
                            initial={{"opacity": 0}}
                            whileInView={{"opacity": 1}}
                            viewport={view_once()}
                            transition={{"delay": 1.4}}
                        >
                            ✓
                        </MText>
                        <g>
                            <rect
                                x="70"
                                y="268"
                                width="80"
                                height="24"
                                rx="12"
                                fill="var(--card)"
                                stroke={C_ECO}
                                strokeOpacity="0.55"
                            />
                            <text
                                x="110"
                                y="284"
                                textAnchor="middle"
                                fontSize="10"
                                fontFamily="monospace"
                                fill={C_ECO}
                            >
                                npm
                            </text>
                            <rect
                                x="180"
                                y="268"
                                width="80"
                                height="24"
                                rx="12"
                                fill="var(--card)"
                                stroke={C_ECO}
                                strokeOpacity="0.55"
                            />
                            <text
                                x="220"
                                y="284"
                                textAnchor="middle"
                                fontSize="10"
                                fontFamily="monospace"
                                fill={C_ECO}
                            >
                                PyPI
                            </text>
                            <rect
                                x="290"
                                y="268"
                                width="80"
                                height="24"
                                rx="12"
                                fill="var(--card)"
                                stroke={C_ECO}
                                strokeOpacity="0.55"
                            />
                            <text
                                x="330"
                                y="284"
                                textAnchor="middle"
                                fontSize="10"
                                fontFamily="monospace"
                                fill={C_ECO}
                            >
                                C ABI
                            </text>
                        </g>
                    </svg>
                    <p className="mt-3 text-sm text-muted-foreground">
                        Rename a field: every stale use is a{" "}
                        <span className="font-medium text-foreground">
                            compile error
                        </span>
                        .
                    </p>
                </div>
            </div>
        </div>;
}
