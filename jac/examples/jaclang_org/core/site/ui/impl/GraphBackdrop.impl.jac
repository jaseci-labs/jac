impl GraphBackdrop(className: str = "") -> JsxElement {
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
