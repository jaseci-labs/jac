"""Client module plain-importing an obj whose closure is unpullable."""
import from infer_xmod_poison_service { Ticket }

def:pub board(t: Ticket | None) -> JsxElement {
    return <div>{t.label if t is not None else ""}</div>;
}
