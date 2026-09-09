import from mermaid { default as mermaid }
import type from mermaid { Mermaid }
import from core.site.ui.CodeBlock { CodeLines }

glob _mm: Mermaid = mermaid as Mermaid,
     _mm_ready: bool = False,
     _mm_seq: int = 0;

def:pub MermaidDiagram(code: str) -> JsxElement {
    has svg_html: str = "",
        failed: bool = False;

    async can with [code] entry {
        if not _mm_ready {
            _mm.initialize(
                {
                    "startOnLoad": False,
                    "theme": "base",
                    "themeVariables": {
                        "darkMode": True,
                        "background": "#0d0c0e",
                        "primaryColor": "#1f1712",
                        "primaryTextColor": "#e7e5e4",
                        "primaryBorderColor": "#ff6b35",
                        "secondaryColor": "#171412",
                        "secondaryTextColor": "#d6d3d1",
                        "secondaryBorderColor": "#57534e",
                        "tertiaryColor": "#121014",
                        "tertiaryTextColor": "#d6d3d1",
                        "tertiaryBorderColor": "#44403c",
                        "lineColor": "#a8a29e",
                        "textColor": "#e7e5e4",
                        "clusterBkg": "#131110",
                        "clusterBorder": "#44403c",
                        "edgeLabelBackground": "#1c1917",
                        "fontFamily": "Geist Mono Variable, ui-monospace, monospace",
                        "fontSize": "13px",

                    },

                }
            );
            _mm_ready = True;
        }
        _mm_seq = _mm_seq + 1;
        try {
            r = await _mm.render("mmdg" + str(_mm_seq), code);
            svg_html = r.svg;
        } except Exception {
            failed = True;
        }
    }

    if failed {
        return
            <div className="code-window my-5 overflow-hidden rounded-lg">
                <div
                    className="code-titlebar flex items-center pl-4 pr-4 pt-1.5 pb-1.5"
                >
                    <span
                        className="font-mono text-[10px] uppercase tracking-widest text-white/40"
                    >
                        mermaid
                    </span>
                </div>
                <div className="overflow-x-auto pt-3 pb-3">
                    <CodeLines lines={code.split("\n")} lang="text" numbers={False}/>
                </div>
            </div>;
    }
    return
        <div
            className="my-5 overflow-x-auto rounded-xl border border-border/60 bg-card/40 pt-4 pb-4 pl-4 pr-4"
        >
            {if svg_html != "" {
                <div className="flex justify-center [&_svg]:h-auto [&_svg]:max-w-full">
                    {unsafe_html(svg_html)}
                </div>
            } else {
                <p
                    className="text-center font-mono text-[11px] text-muted-foreground/60"
                >
                    rendering diagram…
                </p>
            } }
        </div>;
}
