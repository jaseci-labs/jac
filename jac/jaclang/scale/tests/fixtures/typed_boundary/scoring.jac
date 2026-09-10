import os;
import from models { RepoMeta, RepoMeta as Metadata }
import from other_models { RepoMeta as OtherMeta }

obj OtherPayload {
    has meta: OtherMeta = OtherMeta();
}

def:pub other_score -> OtherPayload {
    return OtherPayload();
}

def:pub forward_inherited(payload: DerivedPayload) -> str {
    return payload.inherited.owner;
}

obj HiddenPayload {
    has meta: RepoMeta = RepoMeta();
}

obj Analysis {
    has meta: Metadata = Metadata();
}

obj InheritedMeta {
    has owner: str = "inherited";
}

obj BasePayload {
    has inherited: InheritedMeta = InheritedMeta();
}

obj DerivedPayload(BasePayload) {}

obj RepoTree {
    has meta: RepoMeta = RepoMeta(),
        children: list[RepoTree] = [];
}

obj ScoredPayload {
    has meta: RepoMeta = RepoMeta(),
        analysis: Analysis = Analysis(),
        items: list[RepoMeta] = [RepoMeta()],
        lookup: dict[str, list[RepoMeta]] = {"repos": [RepoMeta()]},
        missing: RepoMeta | None = None,
        tree: RepoTree = RepoTree(children=[RepoTree()]),
        service_pid: int = 0;
}

def:pub score_list -> list[ScoredPayload] {
    return [fetch_score()];
}

def:pub score_lookup -> dict[str, list[ScoredPayload]] {
    return {"scores": score_list()};
}

def:pub maybe_score(present: bool) -> ScoredPayload | None {
    return fetch_score() if present else None;
}

def:pub score_or_meta(scored: bool) -> ScoredPayload | RepoMeta {
    return fetch_score() if scored else RepoMeta();
}

walker:pub ScoreWalker {
    has payload: ScoredPayload = ScoredPayload();

    can run with Root entry {
        self.payload = fetch_score();
        report self.payload.meta;
    }
}

def:pub fetch_score -> ScoredPayload {
    return ScoredPayload(service_pid=os.getpid());
}

def:pub hidden_score -> HiddenPayload {
    return HiddenPayload();
}

def:pub inherited_score -> DerivedPayload {
    return DerivedPayload();
}

def:pub walker_value -> ScoreWalker {
    return ScoreWalker(payload=fetch_score());
}
