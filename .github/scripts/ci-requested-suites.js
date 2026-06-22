// Returns the Set of CI suites requested for a PR via `/test <suites>` comments
// from repo collaborators (read access or above).
//
// Used by the `plan` job of each test workflow so that a suite executes only
// when explicitly requested - keeping unrequested PRs at ~$0 while the
// requested suites run as native PR checks. Requests are read straight from the
// PR's comments, so no commit statuses or marker check-runs are created (the
// PR's check list stays clean - only real test jobs show).
//
// Freshness: a `/test` request only takes effect when ci-command RE-RUNS this
// workflow (run attempt > 1). The automatic run that fires on PR open/push is
// always attempt 1, so it requests nothing - every suite skips until a
// collaborator explicitly comments `/test`, which makes ci-command re-run.
// This means a new push starts clean (its auto run is attempt 1 again),
// without relying on fragile commit-timestamp comparisons.
//
// Only the MOST RECENT collaborator `/test` comment is honored - a request
// runs exactly what that one comment names, with nothing inherited from earlier
// `/test` comments. Want several suites? List them in one comment
// (`/test core mcp`). `all` expands to every suite in `suites`.
//
// `aliases` maps extra command keywords to a canonical suite (e.g. a single-job
// workflow passes { check: 'check' } and asks for its own suite).

module.exports = async ({ github, context, suites, aliases = {} }) => {
  const { owner, repo } = context.repo;
  const pr = context.payload.pull_request;
  const requested = new Set();
  if (!pr) return requested;

  // Attempt 1 = the automatic open/push run: request nothing. Only a /test
  // re-run (attempt > 1) reads the request comments. Fail closed: if the
  // attempt can't be determined, treat it as the automatic run (request
  // nothing) rather than honoring stale comments.
  const attempt = Number(process.env.GITHUB_RUN_ATTEMPT || context.runAttempt);
  if (!Number.isFinite(attempt) || attempt <= 1) return requested;

  const known = new Set(suites);
  const canon = (tok) => (known.has(tok) ? tok : aliases[tok]);

  const perm = {};
  const isCollaborator = async (login) => {
    if (login in perm) return perm[login];
    try {
      const r = await github.rest.repos.getCollaboratorPermissionLevel({ owner, repo, username: login });
      perm[login] = ['admin', 'maintain', 'write', 'triage', 'read'].includes(r.data.permission);
    } catch (e) {
      perm[login] = false;
    }
    return perm[login];
  };

  const comments = await github.paginate(
    github.rest.issues.listComments.endpoint.merge({
      owner, repo, issue_number: pr.number, per_page: 100,
    })
  );

  // Walk newest-first and use the FIRST collaborator `/test` comment found -
  // i.e. the most recent valid request. Nothing accumulates across comments.
  for (let i = comments.length - 1; i >= 0; i--) {
    const c = comments[i];
    const body = (c.body || '').trim();
    if (!body.startsWith('/test')) continue;
    if (!(await isCollaborator(c.user.login))) continue;

    const toks = body.split(/\s+/).slice(1).map((t) => t.toLowerCase());
    if (toks.includes('all')) {
      for (const s of suites) requested.add(s);
      return requested;
    }
    for (const t of toks) {
      const s = canon(t);
      if (s) requested.add(s);
    }
    return requested; // honor only this latest /test comment
  }

  return requested;
};
