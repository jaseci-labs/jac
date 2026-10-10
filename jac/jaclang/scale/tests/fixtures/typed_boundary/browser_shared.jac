import from scoring { fetch_score }
import from models { RepoMeta }

def:pub SharedPanel -> JsxElement {
    has value: str = "";
    async can with entry {
        mine = RepoMeta();
        first = await fetch_score();
        value = first.meta.owner + mine.owner;
    }
    return <div>{value}</div>;
}
