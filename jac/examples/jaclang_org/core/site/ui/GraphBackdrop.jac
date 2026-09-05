glob _NODES: list[dict] = [
         {"x": 120, "y": 140, "r": 4, "d": "0s"},
         {"x": 300, "y": 80, "r": 5, "d": "0.6s"},
         {"x": 520, "y": 120, "r": 4, "d": "1.2s"},
         {"x": 740, "y": 90, "r": 3, "d": "0.3s"},
         {"x": 200, "y": 320, "r": 5, "d": "1.8s"},
         {"x": 430, "y": 260, "r": 6, "d": "0.9s"},
         {"x": 650, "y": 300, "r": 4, "d": "2.2s"},
         {"x": 820, "y": 240, "r": 5, "d": "1.5s"},
         {"x": 90, "y": 470, "r": 3, "d": "2.6s"},
         {"x": 330, "y": 480, "r": 5, "d": "0.4s"},
         {"x": 560, "y": 450, "r": 4, "d": "1.1s"},
         {"x": 780, "y": 470, "r": 3, "d": "1.9s"},

     ],
     _EDGES: list[dict] = [
         {"x1": 120, "y1": 140, "x2": 300, "y2": 80},
         {"x1": 300, "y1": 80, "x2": 520, "y2": 120},
         {"x1": 520, "y1": 120, "x2": 740, "y2": 90},
         {"x1": 120, "y1": 140, "x2": 200, "y2": 320},
         {"x1": 300, "y1": 80, "x2": 430, "y2": 260},
         {"x1": 520, "y1": 120, "x2": 430, "y2": 260},
         {"x1": 740, "y1": 90, "x2": 820, "y2": 240},
         {"x1": 430, "y1": 260, "x2": 650, "y2": 300},
         {"x1": 650, "y1": 300, "x2": 820, "y2": 240},
         {"x1": 200, "y1": 320, "x2": 330, "y2": 480},
         {"x1": 430, "y1": 260, "x2": 330, "y2": 480},
         {"x1": 650, "y1": 300, "x2": 560, "y2": 450},
         {"x1": 820, "y1": 240, "x2": 780, "y2": 470},
         {"x1": 200, "y1": 320, "x2": 90, "y2": 470},
         {"x1": 560, "y1": 450, "x2": 330, "y2": 480},

     ];

def:pub GraphBackdrop(className: str = "") -> JsxElement {
    return
        <div
            className={"pointer-events-none absolute inset-0 overflow-hidden "
                + className}
            aria-hidden="true"
        >
            <svg
                className="h-full w-full opacity-40"
                viewBox="0 0 900 560"
                preserveAspectRatio="xMidYMid slice"
            >
                {for (ei, e) in enumerate(_EDGES) {
                    <line
                        key={"e" + str(ei)}
                        className="g-edge"
                        x1={e["x1"]}
                        y1={e["y1"]}
                        x2={e["x2"]}
                        y2={e["y2"]}
                        stroke="#ff6b35"
                        strokeOpacity="0.35"
                        strokeWidth="1"
                    />
                }}
                {for (ni, nd) in enumerate(_NODES) {
                    <circle
                        key={"n" + str(ni)}
                        className="g-node"
                        cx={nd["x"]}
                        cy={nd["y"]}
                        r={nd["r"]}
                        fill="#ff6b35"
                        fillOpacity="0.55"
                        style={{"animationDelay": nd["d"]}}
                    />
                }}
                <circle className="g-walker" r="5" fill="#ff6b35">
                    <animateMotion
                        dur="12s"
                        repeatCount="indefinite"
                        path="M120,140 L300,80 L430,260 L650,300 L820,240 L740,90 L520,120 L300,80 L120,140"
                    />
                </circle>
                <circle className="g-walker" r="4" fill="#f7931e">
                    <animateMotion
                        dur="16s"
                        repeatCount="indefinite"
                        path="M90,470 L200,320 L430,260 L330,480 L560,450 L650,300 L430,260 L200,320 L90,470"
                    />
                </circle>
            </svg>
        </div>;
}
