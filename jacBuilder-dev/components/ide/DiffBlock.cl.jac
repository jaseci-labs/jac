"""Inline code diff viewer — renders OLD vs NEW as a unified diff
with red/green line highlights. Uses the `diff` npm library for
line-level diffing."""

import from react { useMemo }
import from "...lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon }
import from diff { diffLines as computeDiff }

"""Render a unified diff block from old and new code strings."""
def:pub DiffBlock(props: Any) -> Any {
    oldStr = props.oldStr or "";
    newStr = props.newStr or "";
    fileName = props.fileName or "";
    isWrite = props.isWrite or False;

    has expanded: bool = True;

    diffLines = useMemo(lambda -> Any {
        if isWrite {
            writeLines: list = [];
            if newStr {
                for line in newStr.split("\n") {
                    writeLines.push({"type": "added", "text": line});
                }
            }
            return writeLines;
        }
        changes = computeDiff(oldStr, newStr);
        result: list = [];
        for change in changes {
            lines = change.value.split("\n");
            if lines.length > 0 and lines[lines.length - 1] == "" {
                lines = lines.slice(0, -1);
            }
            for line in lines {
                if change.added {
                    result.push({"type": "added", "text": line});
                } elif change.removed {
                    result.push({"type": "removed", "text": line});
                } else {
                    result.push({"type": "unchanged", "text": line});
                }
            }
        }
        return result;
    }, [oldStr, newStr, isWrite]);

    addCount = 0;
    removeCount = 0;

    return <div className="mt-0.5 mb-1 rounded-md border border-border/50 overflow-hidden bg-muted/30">
        <div className="flex items-center gap-1.5 px-2.5 py-1.5 bg-muted/50 border-b border-border/40 cursor-pointer select-none"
            onClick={lambda -> None { expanded = not expanded; }}>
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className={cn("size-3 text-muted-foreground transition-transform", ("rotate-90" if expanded else ""))} />
            <span className="text-[11px] font-mono font-semibold text-foreground/80">{fileName}</span>
        </div>
        {expanded and <div className="overflow-x-auto max-h-[300px] overflow-y-auto">
            <table className="min-w-max text-[11px] font-mono leading-[18px] border-collapse">
                <tbody>
                    {diffLines.map(lambda (dl: Any, i: int) -> Any {
                        lineType = dl.type;
                        lineText = dl.text;
                        if lineType == "removed" {
                            return <tr key={String(i)} className="bg-red-500/10">
                                <td className="w-[20px] text-right pr-1.5 pl-1 select-none text-red-400/60 border-r border-red-500/20">-</td>
                                <td className="pl-2 pr-2 whitespace-pre text-red-300/90">{lineText or " "}</td>
                            </tr>;
                        }
                        if lineType == "added" {
                            return <tr key={String(i)} className="bg-green-500/10">
                                <td className="w-[20px] text-right pr-1.5 pl-1 select-none text-green-400/60 border-r border-green-500/20">+</td>
                                <td className="pl-2 pr-2 whitespace-pre text-green-300/90">{lineText or " "}</td>
                            </tr>;
                        }
                        return <tr key={String(i)} className="bg-transparent">
                            <td className="w-[20px] text-right pr-1.5 pl-1 select-none text-muted-foreground/30 border-r border-border/30"> </td>
                            <td className="pl-2 pr-2 whitespace-pre text-foreground/60">{lineText or " "}</td>
                        </tr>;
                    })}
                </tbody>
            </table>
        </div> or None}
    </div>;
}
