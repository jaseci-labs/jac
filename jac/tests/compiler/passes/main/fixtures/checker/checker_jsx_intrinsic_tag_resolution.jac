"""Regression: intrinsic JSX tag names must not emit W1051.

Intrinsic HTML tag names (``div``, ``button``, ``p``, ...) are resolved
against the ``_JsxIntrinsicElements`` registry by the JsxElement handler
in the type evaluator, not against the enclosing module scope.  The
type checker's ``exit_name`` hook must therefore skip Name nodes whose
parent is a ``JsxElementName``; otherwise it evaluates each tag name as
a free-standing variable reference, gets ``Unknown``, and emits
``W1051: Expression type could not be resolved``.

This fixture exercises several shapes — a root element, self-closing,
child elements, and closing tags — so every Name position under a
JsxElementName is covered."""

def App -> JsxElement {
    return
        <div>
            <input value="hi"/>
            <button>Add</button>
            <p>some text</p>
        </div>;
}
