import from .motion { view_once }
import from "motion/react" { motion }

glob MLine: any = motion.line,
     MCircle: any = motion.circle,
     _GNODES: list[dict] = [
         {"x": 150, "y": 92},
         {"x": 150, "y": 228},
         {"x": 252, "y": 62},
         {"x": 252, "y": 160},
         {"x": 252, "y": 258},
         {"x": 352, "y": 112},
         {"x": 352, "y": 208},

     ],
     _GEDGES: list[dict] = [
         {"x1": 70, "y1": 160, "x2": 150, "y2": 92},
         {"x1": 70, "y1": 160, "x2": 150, "y2": 228},
         {"x1": 150, "y1": 92, "x2": 252, "y2": 62},
         {"x1": 150, "y1": 92, "x2": 252, "y2": 160},
         {"x1": 150, "y1": 228, "x2": 252, "y2": 160},
         {"x1": 150, "y1": 228, "x2": 252, "y2": 258},
         {"x1": 252, "y1": 62, "x2": 352, "y2": 112},
         {"x1": 252, "y1": 160, "x2": 352, "y2": 112},
         {"x1": 252, "y1": 160, "x2": 352, "y2": 208},
         {"x1": 252, "y1": 258, "x2": 352, "y2": 208},

     ];

def:pub TopokineticDiagram -> JsxElement {
    return
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div
                className="rounded-2xl border border-border/70 bg-card/30 pt-5 pb-5 pl-5 pr-5"
            >
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                >
                    Today — data commutes to the program
                </p>
                <svg
                    viewBox="0 0 440 320"
                    className="w-full"
                    aria-label="Conventional model: the program is stationary and data round-trips to a database"
                >
                    <rect
                        x="140"
                        y="22"
                        width="160"
                        height="50"
                        rx="10"
                        fill="var(--card)"
                        stroke="var(--border)"
                    />
                    <text
                        x="220"
                        y="44"
                        textAnchor="middle"
                        fontSize="13"
                        fontWeight="600"
                        fill="var(--foreground)"
                    >
                        program
                    </text>
                    <text
                        x="220"
                        y="61"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        stationary
                    </text>
                    {#* database cylinder *#}
                    <path
                        d="M150,232 A70,14 0 0,0 290,232 L290,282 A70,14 0 0,1 150,282 Z"
                        fill="var(--card)"
                        stroke="var(--border)"
                    />
                    <ellipse
                        cx="220"
                        cy="232"
                        rx="70"
                        ry="14"
                        fill="var(--card)"
                        stroke="var(--border)"
                    />
                    <text
                        x="220"
                        y="268"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        database
                    </text>
                    {#* the round trips *#}
                    <path
                        d="M168,76 C110,120 110,180 158,226"
                        fill="none"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.6"
                        strokeWidth="1.2"
                        strokeDasharray="4 6"
                        className="dash-drift"
                    />
                    <path
                        d="M282,226 C330,180 330,120 272,76"
                        fill="none"
                        stroke="var(--muted-foreground)"
                        strokeOpacity="0.6"
                        strokeWidth="1.2"
                        strokeDasharray="4 6"
                        className="dash-drift"
                    />
                    <polygon
                        points="152,218 162,230 148,229"
                        fill="var(--muted-foreground)"
                        fillOpacity="0.6"
                    />
                    <polygon
                        points="276,84 266,72 280,73"
                        fill="var(--muted-foreground)"
                        fillOpacity="0.6"
                    />
                    <text
                        x="96"
                        y="155"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        query ↓
                    </text>
                    <text
                        x="348"
                        y="155"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        rows ↑
                    </text>
                    <GhostNote x={330} y={240} label="commit()"/>
                    <GhostNote x={40} y={240} label="ORM"/>
                </svg>
                <p className="mt-3 text-sm text-muted-foreground">
                    Every read is a round trip. Persistence is an event you must remember to fire.
                </p>
            </div>
            <div
                className="rounded-2xl border border-primary/30 bg-primary/5 pt-5 pb-5 pl-5 pr-5"
            >
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-primary"
                >
                    Jac — computation commutes to the data
                </p>
                <svg
                    viewBox="0 0 440 320"
                    className="w-full"
                    aria-label="Jac: a walker carries computation through a persistent graph anchored at root"
                >
                    {#* reachability boundary = persistence *#}
                    <rect
                        x="30"
                        y="26"
                        width="380"
                        height="268"
                        rx="20"
                        fill="none"
                        stroke="#56d364"
                        strokeOpacity="0.35"
                        strokeDasharray="4 7"
                    />
                    <text
                        x="396"
                        y="46"
                        textAnchor="end"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="#56d364"
                        fillOpacity="0.9"
                    >
                        reachable from root ⇒ persists
                    </text>
                    {#* edges draw in *#}
                    {for (ei, e) in enumerate(_GEDGES) {
                        <MLine
                            key={str(ei)}
                            x1={e["x1"]}
                            y1={e["y1"]}
                            x2={e["x2"]}
                            y2={e["y2"]}
                            stroke="var(--muted-foreground)"
                            strokeOpacity="0.45"
                            strokeWidth="1.1"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.5, "delay": 0.15 + ei * 0.07}}
                        />
                    }}
                    {#* root node *#}
                    <circle
                        cx="70"
                        cy="160"
                        r="13"
                        fill="#ff6b35"
                        fillOpacity="0.18"
                        stroke="#ff6b35"
                        strokeOpacity="0.7"
                        className="g-node"
                    />
                    <circle cx="70" cy="160" r="6" fill="#ff6b35"/>
                    <text
                        x="70"
                        y="190"
                        textAnchor="middle"
                        fontSize="10"
                        fontFamily="monospace"
                        fill="#ff6b35"
                    >
                        root
                    </text>
                    {#* graph nodes pop in *#}
                    {for (ni, nd) in enumerate(_GNODES) {
                        <MCircle
                            key={str(ni)}
                            cx={nd["x"]}
                            cy={nd["y"]}
                            r="7"
                            fill="var(--card)"
                            stroke="var(--foreground)"
                            strokeOpacity="0.55"
                            strokeWidth="1.2"
                            initial={{"opacity": 0}}
                            whileInView={{"opacity": 1}}
                            viewport={view_once()}
                            transition={{"duration": 0.4, "delay": 0.2 + ni * 0.08}}
                        />
                    }}
                    {#* the walker *#}
                    <circle r="5.5" fill="#ff6b35" className="g-walker">
                        <animateMotion
                            dur="9s"
                            repeatCount="indefinite"
                            path="M70,160 L150,92 L252,62 L352,112 L252,160 L352,208 L252,258 L150,228 L70,160"
                        />
                    </circle>
                    <text
                        x="220"
                        y="308"
                        textAnchor="middle"
                        fontSize="9"
                        fontFamily="monospace"
                        fill="var(--muted-foreground)"
                    >
                        walker — dispatched by arrival
                    </text>
                </svg>
                <p className="mt-3 text-sm text-muted-foreground">
                    Walkers carry computation through the graph. The database
                    <span className="font-medium text-foreground">
                        dissolves into the language
                    </span>
                    .
                </p>
            </div>
        </div>;
}

def:pub GhostNote(x: int, y: int, label: str) -> JsxElement {
    return
        <g opacity="0.6">
            <rect
                x={x}
                y={y}
                width="70"
                height="20"
                rx="10"
                fill="none"
                stroke="var(--border)"
                strokeDasharray="3 3"
            />
            <text
                x={x + 35}
                y={y + 13}
                textAnchor="middle"
                fontSize="8.5"
                fontFamily="monospace"
                fill="var(--muted-foreground)"
            >
                {label}
            </text>
        </g>;
}
