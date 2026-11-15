"""SVG children and the less common HTML elements are intrinsic JSX elements."""

def Diagram(label: str) -> JsxElement {
    return
        <svg viewBox="0 0 100 100">
            <defs>
                <marker id="arrow" markerWidth="6" markerHeight="6"/>
                <linearGradient id="fade">
                    <stop offset="0"/>
                </linearGradient>
                <clipPath id="clip">
                    <rect width="10" height="10"/>
                </clipPath>
            </defs>
            <g transform="translate(1 1)">
                <circle cx="5" cy="5" r="2"/>
                <ellipse cx="5" cy="5" rx="2" ry="1"/>
                <rect x="1" y="1" width="3" height="3"/>
                <line x1="0" y1="0" x2="1" y2="1"/>
                <polyline points="0,0 1,1"/>
                <polygon points="0,0 1,1 1,0"/>
                <path d="M0 0 L1 1"/>
                <text x="1" y="1">
                    <tspan>{label}</tspan>
                </text>
                <use href="#arrow"/>
            </g>
        </svg>;
}

def Shortcut(keys: str) -> JsxElement {
    return
        <p>
            Press{" "}
            <kbd>{keys}</kbd>{" "}
            to{" "}
            <b>save</b>
            ,{" "}
            <i>or</i>{" "}
            <u>not</u>
            ;
            <samp>ok</samp>{" "}
            <var>x</var>{" "}
            <abbr>e.g.</abbr>{" "}
            <wbr/>
        </p>;
}
