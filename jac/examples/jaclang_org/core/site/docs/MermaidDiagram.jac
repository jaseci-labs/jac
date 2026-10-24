import from mermaid { default as mermaid }
import type from mermaid { Mermaid }

glob _mm: Mermaid = mermaid as Mermaid,
     _mm_ready: bool = False,
     _mm_seq: int = 0;

def:pub MermaidDiagram(code: str) -> JsxElement;
