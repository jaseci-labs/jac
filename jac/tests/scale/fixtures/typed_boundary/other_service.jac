import from other_models { RepoMeta }

obj ScoredPayload {
    has meta: RepoMeta = RepoMeta();
}

def:pub fetch_score -> ScoredPayload {
    return ScoredPayload();
}
