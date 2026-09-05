import from .motion { view_once }
import from "motion/react" { motion }

glob MPath: any = motion.path,
     _IN_PATHS: list[str] = [
         "M124,65 C230,65 300,118 384,140",
         "M124,150 L384,150",
         "M124,235 C230,235 300,182 384,160",

     ],
     _OUT_PATHS: list[str] = [
         "M496,140 C580,118 650,65 756,65",
         "M496,150 L756,150",
         "M496,160 C580,182 650,235 756,235",

     ],
     _INS: list[dict] = [
         {"y": 52, "label": "PyPI"},
         {"y": 137, "label": "npm"},
         {"y": 222, "label": "C ABI"},

     ],
     _OUTS: list[dict] = [
         {"y": 52, "label": "Python bytecode"},
         {"y": 137, "label": "JavaScript"},
         {"y": 222, "label": "native · wasm"},

     ];

def:pub PolypilerDiagram -> JsxElement {
    return
        <div className="overflow-x-auto">
            <svg
                viewBox="0 0 880 300"
                className="w-full min-w-[640px]"
                aria-label="The polypiler: PyPI, npm, and the C ABI flow into the jac binary, which emits Python bytecode, JavaScript, and native machine code"
            >
                <defs>
                    <linearGradient id="polyHexGrad" x1="0" y1="0" x2="1" y2="1">
                        <stop offset="0%" stopColor="#f7931e"/>
                        <stop offset="100%" stopColor="#e8442c"/>
                    </linearGradient>
                </defs>
                {#* ecosystems in *#}
                {for (i, item) in enumerate(_INS) {
                    <g key={"in" + str(i)}>
                        <rect
                            x="24"
                            y={item["y"]}
                            width="100"
                            height="26"
                            rx="13"
                            fill="var(--card)"
                            stroke="var(--border)"
                        />
                        <text
                            x="74"
                            y={(item["y"] as int) + 17}
                            textAnchor="middle"
                            fontSize="11"
                            fontFamily="monospace"
                            fill="var(--foreground)"
                        >
                            {item["label"]}
                        </text>
                    </g>
                }}
                {for (i, p) in enumerate(_IN_PATHS) {
                    <MPath
                        key={"ip" + str(i)}
                        d={p}
                        fill="none"
                        stroke="#ff6b35"
                        strokeOpacity="0.4"
                        strokeWidth="1.3"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.8, "delay": 0.2 + i * 0.15}}
                    />
                }}
                {#* moving packets *#}
                {for (i, p) in enumerate(_IN_PATHS) {
                    <circle key={"id" + str(i)} r="3" fill="#f7931e" opacity="0.9">
                        <animateMotion
                            dur={str(2.6 + i * 0.5) + "s"}
                            repeatCount="indefinite"
                            path={p}
                        />
                    </circle>
                }}
                {#* the polypiler *#}
                <circle
                    cx="440"
                    cy="150"
                    r="58"
                    fill="#ff6b35"
                    fillOpacity="0.07"
                    className="pulse-ring"
                />
                <polygon
                    points="440,102 482,126 482,174 440,198 398,174 398,126"
                    fill="url(#polyHexGrad)"
                    stroke="#ff6b35"
                    strokeOpacity="0.6"
                />
                <text
                    x="440"
                    y="148"
                    textAnchor="middle"
                    fontSize="19"
                    fontWeight="700"
                    fontFamily="monospace"
                    fill="#ffffff"
                >
                    jac
                </text>
                <text
                    x="440"
                    y="168"
                    textAnchor="middle"
                    fontSize="9"
                    fontFamily="monospace"
                    fill="#ffffff"
                    fillOpacity="0.85"
                >
                    the polypiler
                </text>
                <text
                    x="440"
                    y="234"
                    textAnchor="middle"
                    fontSize="10"
                    fontFamily="monospace"
                    fill="var(--muted-foreground)"
                >
                    one binary · compiler + runtime + linkers + package managers
                </text>
                {#* targets out — three artifacts, ONE program *#}
                <rect
                    x="740"
                    y="40"
                    width="136"
                    height="216"
                    rx="14"
                    fill="#ff6b35"
                    fillOpacity="0.05"
                    stroke="#ff6b35"
                    strokeOpacity="0.35"
                />
                <text
                    x="808"
                    y="30"
                    textAnchor="middle"
                    fontSize="10"
                    fontFamily="monospace"
                    fill="#ff6b35"
                >
                    one program
                </text>
                {for (i, p) in enumerate(_OUT_PATHS) {
                    <MPath
                        key={"op" + str(i)}
                        d={p}
                        fill="none"
                        stroke="#ff6b35"
                        strokeOpacity="0.4"
                        strokeWidth="1.3"
                        initial={{"pathLength": 0}}
                        whileInView={{"pathLength": 1}}
                        viewport={view_once()}
                        transition={{"duration": 0.8, "delay": 0.5 + i * 0.15}}
                    />
                }}
                {for (i, p) in enumerate(_OUT_PATHS) {
                    <circle key={"od" + str(i)} r="3" fill="#e8442c" opacity="0.9">
                        <animateMotion
                            dur={str(2.4 + i * 0.6) + "s"}
                            repeatCount="indefinite"
                            path={p}
                        />
                    </circle>
                }}
                {for (i, item) in enumerate(_OUTS) {
                    <g key={"out" + str(i)}>
                        <rect
                            x="756"
                            y={item["y"]}
                            width="112"
                            height="26"
                            rx="13"
                            fill="var(--card)"
                            stroke="var(--border)"
                        />
                        <text
                            x="812"
                            y={(item["y"] as int) + 17}
                            textAnchor="middle"
                            fontSize="10"
                            fontFamily="monospace"
                            fill="var(--foreground)"
                        >
                            {item["label"]}
                        </text>
                    </g>
                }}
            </svg>
        </div>;
}
