impl FnMini -> JsxElement {
    return
        <svg viewBox="0 0 320 96" className="w-full" aria-hidden="true">
            <rect
                x="0"
                y="28"
                width="96"
                height="40"
                rx="8"
                fill="var(--card)"
                stroke="var(--border)"
            />
            <text
                x="48"
                y="45"
                textAnchor="middle"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--muted-foreground)"
            >
                ticket: str
            </text>
            <text
                x="48"
                y="59"
                textAnchor="middle"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--foreground)"
            >
                "Checkout…"
            </text>
            <path
                d="M96,48 L132,48"
                stroke="var(--muted-foreground)"
                strokeWidth="1.2"
                markerEnd="url(#agArrow)"
            />
            <circle
                cx="160"
                cy="48"
                r="26"
                fill="#ff6b35"
                fillOpacity="0.1"
                stroke="#ff6b35"
            />
            <text
                x="160"
                y="52"
                textAnchor="middle"
                fontSize="11"
                fontWeight="700"
                fontFamily="monospace"
                fill="#ff6b35"
            >
                llm
            </text>
            <path
                d="M186,48 L220,48"
                stroke="var(--muted-foreground)"
                strokeWidth="1.2"
                markerEnd="url(#agArrow)"
            />
            <rect
                x="224"
                y="28"
                width="96"
                height="40"
                rx="8"
                fill="var(--card)"
                stroke="#ff6b35"
                strokeOpacity="0.6"
            />
            <text
                x="272"
                y="45"
                textAnchor="middle"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--muted-foreground)"
            >
                -&gt; Priority
            </text>
            <text
                x="272"
                y="59"
                textAnchor="middle"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--foreground)"
            >
                URGENT
            </text>
            <text
                x="160"
                y="92"
                textAnchor="middle"
                fontSize="10"
                fill="var(--muted-foreground)"
            >
                the signature is the prompt · the return type is the schema
            </text>
        </svg>;
}

impl ObjMini -> JsxElement {
    return
        <svg viewBox="0 0 320 120" className="w-full" aria-hidden="true">
            <rect
                x="0"
                y="6"
                width="190"
                height="108"
                rx="10"
                fill="var(--card)"
                stroke="var(--border)"
            />
            <text
                x="14"
                y="28"
                fontSize="12"
                fontWeight="700"
                fontFamily="monospace"
                fill="var(--foreground)"
            >
                Concierge
            </text>
            <text
                x="14"
                y="50"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--muted-foreground)"
            >
                has guest, bookings
            </text>
            <text
                x="176"
                y="50"
                textAnchor="end"
                fontSize="9"
                fill="var(--muted-foreground)"
            >
                context
            </text>
            <text
                x="14"
                y="74"
                fontSize="10"
                fontFamily="monospace"
                fill="var(--foreground)"
            >
                def book()
            </text>
            <text
                x="176"
                y="74"
                textAnchor="end"
                fontSize="9"
                fill="var(--muted-foreground)"
            >
                tool
            </text>
            <text x="14" y="98" fontSize="10" fontFamily="monospace" fill="#ff6b35">
                def help() by llm
            </text>
            <text
                x="176"
                y="98"
                textAnchor="end"
                fontSize="9"
                fill="var(--muted-foreground)"
            >
                goal
            </text>
            <circle
                cx="270"
                cy="60"
                r="26"
                fill="#ff6b35"
                fillOpacity="0.1"
                stroke="#ff6b35"
            />
            <text
                x="270"
                y="64"
                textAnchor="middle"
                fontSize="11"
                fontWeight="700"
                fontFamily="monospace"
                fill="#ff6b35"
            >
                llm
            </text>
            <path
                d="M190,94 C220,94 230,80 248,74"
                fill="none"
                stroke="#ff6b35"
                strokeWidth="1.2"
                markerEnd="url(#agArrowHot)"
            />
            <path
                d="M248,46 C226,40 214,58 192,68"
                fill="none"
                stroke="var(--muted-foreground)"
                strokeWidth="1.2"
                strokeDasharray="3 3"
                markerEnd="url(#agArrow)"
            />
            <text
                x="226"
                y="34"
                textAnchor="middle"
                fontSize="9"
                fill="var(--muted-foreground)"
            >
                calls book()
            </text>
        </svg>;
}

impl WalkMini -> JsxElement {
    return
        <svg viewBox="0 0 320 110" className="w-full" aria-hidden="true">
            <path
                d="M30,55 L140,18"
                stroke="var(--border)"
                strokeWidth="1.2"
                strokeDasharray="4 4"
            />
            <path d="M30,55 L140,55" stroke="#ff6b35" strokeWidth="1.6"/>
            <path
                d="M30,55 L140,92"
                stroke="var(--border)"
                strokeWidth="1.2"
                strokeDasharray="4 4"
            />
            <path d="M140,55 L260,55" stroke="#ff6b35" strokeWidth="1.6"/>
            <path
                d="M140,55 L260,92"
                stroke="var(--border)"
                strokeWidth="1.2"
                strokeDasharray="4 4"
            />
            <circle
                cx="30"
                cy="55"
                r="9"
                fill="var(--card)"
                stroke="var(--foreground)"
            />
            <circle cx="140" cy="18" r="8" fill="var(--card)" stroke="var(--border)"/>
            <circle cx="140" cy="55" r="9" fill="var(--card)" stroke="#ff6b35"/>
            <circle cx="140" cy="92" r="8" fill="var(--card)" stroke="var(--border)"/>
            <circle cx="260" cy="55" r="9" fill="var(--card)" stroke="#ff6b35"/>
            <circle cx="260" cy="92" r="8" fill="var(--card)" stroke="var(--border)"/>
            <circle r="5" fill="#ff6b35" className="g-walker">
                <animateMotion
                    dur="3.2s"
                    repeatCount="indefinite"
                    path="M30,55 L140,55 L260,55"
                />
            </circle>
        </svg>;
}

impl WalkerDiagram -> JsxElement {
    return
        <div className="overflow-x-auto">
            <svg
                viewBox="0 0 1000 420"
                className="w-full min-w-[760px]"
                role="img"
                aria-label="A Researcher walker starts at root, the model chooses Billing out of three topics, then Refund policy out of three pages, and the walker reports the answer"
            >
                <rect
                    x="0"
                    y="0"
                    width="470"
                    height="44"
                    rx="10"
                    fill="var(--card)"
                    stroke="var(--border)"
                />
                <text
                    x="16"
                    y="27"
                    fontSize="12"
                    fontFamily="monospace"
                    fill="var(--muted-foreground)"
                >
                    Researcher(question=
                    <tspan fill="var(--foreground)">
                        "How long does a refund take?"
                    </tspan>
                    )
                </text>
                <circle cx="620" cy="22" r="5" fill="#ff6b35"/>
                <text x="632" y="26" fontSize="11" fill="var(--muted-foreground)">
                    walker
                </text>
                <path d="M700,22 L740,22" stroke="#ff6b35" strokeWidth="2"/>
                <text x="748" y="26" fontSize="11" fill="var(--muted-foreground)">
                    chosen by the model
                </text>
                <path
                    d="M890,22 L930,22"
                    stroke="var(--muted-foreground)"
                    strokeOpacity="0.5"
                    strokeWidth="1.2"
                    strokeDasharray="4 4"
                />
                <text x="938" y="26" fontSize="11" fill="var(--muted-foreground)">
                    not taken
                </text>
                {for (i, n) in enumerate(_L1) {
                    <path
                        key={"e1" + str(i)}
                        d={"M94,210 C170,210 160,"
                            + str(n["y"])
                            + " 225,"
                            + str(n["y"])}
                        fill="none"
                        stroke={"#ff6b35" if n["on"] else "var(--muted-foreground)"}
                        strokeOpacity={"1" if n["on"] else "0.45"}
                        strokeWidth={"2" if n["on"] else "1.2"}
                        strokeDasharray={"" if n["on"] else "4 4"}
                    />
                }}
                {for (i, n) in enumerate(_L2) {
                    <path
                        key={"e2" + str(i)}
                        d={"M375,210 C450,210 440,"
                            + str(n["y"])
                            + " 505,"
                            + str(n["y"])}
                        fill="none"
                        stroke={"#ff6b35" if n["on"] else "var(--muted-foreground)"}
                        strokeOpacity={"1" if n["on"] else "0.45"}
                        strokeWidth={"2" if n["on"] else "1.2"}
                        strokeDasharray={"" if n["on"] else "4 4"}
                    />
                }}
                <path
                    d="M655,210 L790,210"
                    stroke="#ff6b35"
                    strokeWidth="2"
                    strokeDasharray="6 4"
                    className="dash-drift"
                />
                <circle
                    cx="70"
                    cy="210"
                    r="24"
                    fill="var(--card)"
                    stroke="var(--foreground)"
                    strokeWidth="1.4"
                />
                <text
                    x="70"
                    y="214"
                    textAnchor="middle"
                    fontSize="11"
                    fontFamily="monospace"
                    fill="var(--foreground)"
                >
                    root
                </text>
                {for (i, n) in enumerate(_L1) {
                    <g key={"n1" + str(i)}>
                        <rect
                            x="225"
                            y={(n["y"] as int) - 20}
                            width="150"
                            height="40"
                            rx="20"
                            fill="var(--card)"
                            stroke={"#ff6b35" if n["on"] else "var(--border)"}
                            strokeWidth={"1.6" if n["on"] else "1"}
                        />
                        <text
                            x="300"
                            y={(n["y"] as int) + 4}
                            textAnchor="middle"
                            fontSize="12"
                            fill={"var(--foreground)"
                                if n["on"]
                                else "var(--muted-foreground)"}
                        >
                            {n["label"]}
                        </text>
                    </g>
                }}
                {for (i, n) in enumerate(_L2) {
                    <g key={"n2" + str(i)}>
                        <rect
                            x="505"
                            y={(n["y"] as int) - 20}
                            width="150"
                            height="40"
                            rx="20"
                            fill="var(--card)"
                            stroke={"#ff6b35" if n["on"] else "var(--border)"}
                            strokeWidth={"1.6" if n["on"] else "1"}
                        />
                        <text
                            x="580"
                            y={(n["y"] as int) + 4}
                            textAnchor="middle"
                            fontSize="12"
                            fill={"var(--foreground)"
                                if n["on"]
                                else "var(--muted-foreground)"}
                        >
                            {n["label"]}
                        </text>
                    </g>
                }}
                <rect
                    x="790"
                    y="178"
                    width="210"
                    height="64"
                    rx="10"
                    fill="#ff6b35"
                    fillOpacity="0.08"
                    stroke="#ff6b35"
                />
                <text
                    x="808"
                    y="203"
                    fontSize="11"
                    fontFamily="monospace"
                    fill="#ff6b35"
                >
                    report
                </text>
                <text
                    x="808"
                    y="225"
                    fontSize="12"
                    fontFamily="monospace"
                    fill="var(--foreground)"
                >
                    "5 to 7 business days"
                </text>
                <circle r="7" fill="#ff6b35" className="g-walker">
                    <animateMotion
                        dur="5s"
                        repeatCount="indefinite"
                        path="M70,210 L300,210 L580,210 L800,210"
                    />
                </circle>
                {#* step captions under each decision *#}
                <text
                    x="160"
                    y="362"
                    textAnchor="middle"
                    fontSize="12"
                    fontWeight="600"
                    fill="var(--foreground)"
                >
                    <tspan fill="#ff6b35">1 </tspan>
                    At root, pick 1 of 3
                </text>
                <text
                    x="160"
                    y="382"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    the model reads the question and
                </text>
                <text
                    x="160"
                    y="398"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    the edges, and chooses Billing
                </text>
                <text
                    x="440"
                    y="362"
                    textAnchor="middle"
                    fontSize="12"
                    fontWeight="600"
                    fill="var(--foreground)"
                >
                    <tspan fill="#ff6b35">2 </tspan>
                    At Billing, pick 1 of 3
                </text>
                <text
                    x="440"
                    y="382"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    the same visit runs again, here,
                </text>
                <text
                    x="440"
                    y="398"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    and chooses Refund policy
                </text>
                <text
                    x="760"
                    y="362"
                    textAnchor="middle"
                    fontSize="12"
                    fontWeight="600"
                    fill="var(--foreground)"
                >
                    <tspan fill="#ff6b35">3 </tspan>
                    Report from the data
                </text>
                <text
                    x="760"
                    y="382"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    the walker answers where the
                </text>
                <text
                    x="760"
                    y="398"
                    textAnchor="middle"
                    fontSize="11"
                    fill="var(--muted-foreground)"
                >
                    answer lives, then returns it
                </text>
            </svg>
        </div>;
}

impl Rung(
    num: str, title: str, body: str, lines: list[str], file: str, diagram: any = None
) -> JsxElement {
    return
        <Reveal>
            <div
                className="grid grid-cols-1 gap-8 border-t border-border pt-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)] lg:gap-12"
            >
                <div className="min-w-0">
                    <span className="font-mono text-xs text-primary">{num}</span>
                    <h3 className="mt-2 text-2xl font-semibold tracking-tight">
                        {title}
                    </h3>
                    <p className="mt-3 text-base leading-relaxed text-muted-foreground">
                        <Prose text={body}/>
                    </p>
                    <div className="mt-8 max-w-sm">{diagram}</div>
                </div>
                <CodeWindow lines={lines} title={file} className="self-start"/>
            </div>
        </Reveal>;
}

impl AgentNative -> JsxElement {
    return
        <HomeSection id="agents">
            <svg width="0" height="0" className="absolute" aria-hidden="true">
                <defs>
                    <marker
                        id="agArrow"
                        viewBox="0 0 8 8"
                        refX="7"
                        refY="4"
                        markerWidth="7"
                        markerHeight="7"
                        orient="auto"
                    >
                        <path d="M0,0 L8,4 L0,8 z" fill="var(--muted-foreground)"/>
                    </marker>
                    <marker
                        id="agArrowHot"
                        viewBox="0 0 8 8"
                        refX="7"
                        refY="4"
                        markerWidth="7"
                        markerHeight="7"
                        orient="auto"
                    >
                        <path d="M0,0 L8,4 L0,8 z" fill="#ff6b35"/>
                    </marker>
                </defs>
            </svg>
            <SectionHead
                num="03"
                kicker="Agents built in"
                title="Agents are a language abstraction."
            />
            <div className="mt-14 flex flex-col gap-14 sm:mt-16">
                <Rung
                    num="a"
                    title="A function becomes a model call"
                    body="End a signature with `by llm()` and the compiler writes the prompt, returning a checked `Priority` rather than loose text."
                    lines={_FN_LINES}
                    file="triage.jac"
                    diagram={<FnMini/>}
                />
                <Rung
                    num="b"
                    title="An object becomes an agent"
                    body="Put `by llm` on a method and its fields become the model's context and its other methods the tools it can call."
                    lines={_OBJ_LINES}
                    file="concierge.jac"
                    diagram={<ObjMini/>}
                />
                <Rung
                    num="c"
                    title="A walker becomes an agent that moves"
                    body="Add `by llm` to a `visit` and the model picks the walker's next hop, one node at a time."
                    lines={_WALK_LINES}
                    file="researcher.jac"
                    diagram={<WalkMini/>}
                />
            </div>
            <Figure
                label="fig. 6"
                caption="At each node the model picks among that node's edges, so the agent's reasoning follows the shape of the data."
            >
                <WalkerDiagram/>
            </Figure>
        </HomeSection>;
}
