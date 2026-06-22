// Returns the Set of CI suites requested for a PR's CURRENT head commit via
// `/test <suites>` comments from repo collaborators (read access or above).
//
// Used by the `plan` job of each test workflow so that, on a pull_request run,
// a suite executes only when explicitly requested - keeping unrequested PRs at
// ~$0 while the requested suites run as native PR checks. Requests are read
// straight from the PR's comments, so no commit statuses or marker check-runs
// are created (the PR's check list stays clean - only real test jobs show).
//
// Stale requests are not a concern: this runs in a `plan` job that only ever
// executes for the PR's CURRENT head SHA, so any `/test` comment it reads is
// scoped to the code under test by construction. (A new push starts a fresh
// run whose plan re-reads comments against the new SHA.)
//
// `aliases` maps extra command keywords to a canonical suite (e.g. a single-job
// workflow passes { check: 'check' } and asks for its own suite). `all`
// expands to every suite in `suites`.

module.exports = async ({ github, context, suites, aliases = {} }) => {
  const { owner, repo } = context.repo;
  const pr = context.payload.pull_request;
  const requested = new Set();
  if (!pr) return requested;

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

  for (const c of comments) {
    const body = (c.body || '').trim();
    if (!body.startsWith('/test')) continue;
    if (!(await isCollaborator(c.user.login))) continue;

    const toks = body.split(/\s+/).slice(1).map((t) => t.toLowerCase());
    if (toks.includes('all')) {
      for (const s of suites) requested.add(s);
      continue;
    }
    for (const t of toks) {
      const s = canon(t);
      if (s) requested.add(s);
    }
  }

  return requested;
};
