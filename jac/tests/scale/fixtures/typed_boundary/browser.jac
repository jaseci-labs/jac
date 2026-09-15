import from scoring { fetch_score }
import from scoring { ScoredPayload, RepoMeta as Meta }
import from other_service { fetch_score as other_score }
import from other_service { ScoredPayload as OtherPayload, RepoMeta as OtherMeta }

def:pub BoundaryPanel -> JsxElement {
    has value: str = "";
    async can with entry {
        first = await fetch_score();
        second = await other_score();
        value = first.meta.owner + second.meta.owner;
    }
    return <div>{value}</div>;
}
