import os;
import sys;
import from scoring { fetch_score, hidden_score, ScoredPayload, RepoMeta }
import from scoring { RepoMeta as Meta, ScoredPayload as Payload }
import from scoring { Metadata, inherited_score }
import from scoring {
    score_list,
    score_lookup,
    maybe_score,
    score_or_meta,
    ScoreWalker
}

async def:pub check_score -> dict {
    payload = await fetch_score();
    assert isinstance(payload, ScoredPayload);
    assert isinstance(payload.meta, RepoMeta) , "nested RepoMeta stayed a dict";
    assert payload.meta.owner == "jaseci-labs";
    assert isinstance(payload.analysis.meta, RepoMeta);
    assert payload.analysis.meta.owner == "jaseci-labs";
    assert isinstance(payload.items[0], RepoMeta);
    assert payload.items[0].owner == "jaseci-labs";
    assert isinstance(payload.lookup["repos"][0], RepoMeta);
    assert payload.lookup["repos"][0].owner == "jaseci-labs";
    assert payload.missing is None;
    assert isinstance(payload.tree.children[0].meta, Meta);
    assert payload.tree.children[0].meta.owner == "jaseci-labs";
    return {
        "owner": payload.meta.owner,
        "provider_pid": payload.service_pid,
        "consumer_pid": os.getpid(),
        "provider_loaded": "scoring" in sys.modules
    };
}

async def:pub check_collections -> bool {
    hidden = await hidden_score();
    assert isinstance(hidden.meta, Meta);
    assert hidden.meta.owner == "jaseci-labs";
    assert Meta is RepoMeta;
    assert Payload is ScoredPayload;
    scores = await score_list();
    assert isinstance(scores[0], Payload);
    assert isinstance(scores[0].meta, Meta);
    assert scores[0].analysis.meta.owner == "jaseci-labs";
    lookup = await score_lookup();
    assert isinstance(lookup["scores"][0], Payload);
    assert lookup["scores"][0].meta.owner == "jaseci-labs";
    present = await maybe_score(True);
    assert isinstance(present, Payload);
    assert present.meta.owner == "jaseci-labs";
    assert await maybe_score(False) is None;
    assert isinstance(await score_or_meta(True), Payload);
    assert isinstance(await score_or_meta(False), Meta);
    return True;
}

async def:pub check_provider_alias -> bool {
    payload = await fetch_score();
    assert Metadata is Meta , "provider alias must retain type identity";
    assert isinstance(payload.analysis.meta, Metadata);
    return True;
}

async def:pub check_inherited -> bool {
    payload = await inherited_score();
    assert payload.inherited.owner == "inherited";
    return True;
}

async def:pub forward_score -> ScoredPayload {
    return await fetch_score();
}

async def:pub check_walker -> bool {
    walked = await ScoreWalker();
    assert isinstance(walked, ScoreWalker);
    assert isinstance(walked.payload, Payload);
    assert isinstance(walked.payload.meta, Meta);
    assert walked.payload.analysis.meta.owner == "jaseci-labs";
    assert isinstance(walked.reports[0], Meta);
    assert walked.reports[0].owner == "jaseci-labs";
    return True;
}
