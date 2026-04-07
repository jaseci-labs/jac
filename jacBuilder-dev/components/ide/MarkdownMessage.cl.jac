"""Markdown renderer for AI chat messages with syntax-highlighted code blocks and copy buttons."""

import from react { useState }
import from "react-markdown" { default as ReactMarkdown }
import from "remark-gfm" { default as remarkGfm }
import from "rehype-highlight" { default as rehypeHighlight }
import from ...lib.utils { cn }
import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Copy01Icon, Tick02Icon }

glob _NL: str = String.fromCharCode(10);

def:pub CodeBlock(props: Any) -> Any {
    children = props.children or "";
    className = props.className or "";
    has copied: bool = False;

    isBlock = Boolean(className);
    if not isBlock {
        return <code className="bg-primary/15 text-primary px-1.5 py-0.5 rounded text-[13px] font-mono">{children}</code>;
    }

    langMatch = className.replace("hljs ", "").replace("language-", "");
    lang = langMatch or "";
    rawStr = String(children);
    codeStr = rawStr;
    if rawStr.endsWith(_NL) {
        codeStr = rawStr.slice(0, rawStr.length - 1);
    }

    def handleCopy() -> None {
        navigator.clipboard.writeText(codeStr);
        copied = True;
        setTimeout(lambda { copied = False; }, 2000);
    }

    return <div className="rounded-lg overflow-hidden border border-border bg-background my-2">
        <div className="flex items-center justify-between px-3 py-1.5 bg-muted/50 border-b border-border">
            <span className="text-[11px] font-mono text-muted-foreground uppercase">{lang}</span>
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost" className="text-muted-foreground hover:text-foreground"
                        onClick={lambda -> None { handleCopy(); }}>
                        {copied and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3 text-success" /> or <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-3" />}
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{copied and "Copied!" or "Copy code"}</TooltipContent>
            </Tooltip>
        </div>
        <pre className="p-3 overflow-x-auto text-sm font-mono">
            <code className={className}>{children}</code>
        </pre>
    </div>;
}

def:pub MarkdownMessage(props: Any) -> Any {
    content = props.content or "";
    extraClass = props.className or "";

    return <div className={cn("markdown-message text-sm leading-relaxed text-foreground prose-sm max-w-none", extraClass)}>
        <ReactMarkdown
            remarkPlugins={[remarkGfm]}
            rehypePlugins={[rehypeHighlight]}
            components={{
                "code": lambda(codeProps: Any) -> Any {
                    codeChildren = codeProps.children;
                    codeClassName = codeProps.className or "";
                    return <CodeBlock className={codeClassName}>{codeChildren}</CodeBlock>;
                },
                "p": lambda(pProps: Any) -> Any {
                    return <p className="mb-2 last:mb-0">{pProps.children}</p>;
                },
                "ul": lambda(ulProps: Any) -> Any {
                    return <ul className="mb-2 pl-4 list-disc space-y-1">{ulProps.children}</ul>;
                },
                "ol": lambda(olProps: Any) -> Any {
                    return <ol className="mb-2 pl-4 list-decimal space-y-1">{olProps.children}</ol>;
                },
                "li": lambda(liProps: Any) -> Any {
                    return <li className="text-sm">{liProps.children}</li>;
                },
                "h1": lambda(h1Props: Any) -> Any {
                    return <h1 className="text-base font-bold mb-2 mt-3">{h1Props.children}</h1>;
                },
                "h2": lambda(h2Props: Any) -> Any {
                    return <h2 className="text-sm font-bold mb-2 mt-3">{h2Props.children}</h2>;
                },
                "h3": lambda(h3Props: Any) -> Any {
                    return <h3 className="text-sm font-semibold mb-1.5 mt-2">{h3Props.children}</h3>;
                },
                "blockquote": lambda(bqProps: Any) -> Any {
                    return <blockquote className="border-l-2 border-primary/40 pl-3 text-muted-foreground italic mb-2">{bqProps.children}</blockquote>;
                },
                "a": lambda(aProps: Any) -> Any {
                    return <a href={aProps.href} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2 hover:text-primary/80">{aProps.children}</a>;
                },
                "strong": lambda(sProps: Any) -> Any {
                    return <strong className="font-semibold text-foreground">{sProps.children}</strong>;
                },
                "hr": lambda(_hrProps: Any) -> Any {
                    return <hr className="my-3 border-border" />;
                },
                "table": lambda(tProps: Any) -> Any {
                    return <div className="overflow-x-auto mb-2"><table className="min-w-full text-sm border border-border">{tProps.children}</table></div>;
                },
                "th": lambda(thProps: Any) -> Any {
                    return <th className="px-2 py-1 border border-border bg-muted/50 text-left text-xs font-semibold">{thProps.children}</th>;
                },
                "td": lambda(tdProps: Any) -> Any {
                    return <td className="px-2 py-1 border border-border text-sm">{tdProps.children}</td>;
                }
            }}
        >
            {content}
        </ReactMarkdown>
    </div>;
}
