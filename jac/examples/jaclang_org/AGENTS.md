# Working on jaclang.org

Read `README.md` for the workspace layout, the apps, and how to run them.
Before writing or editing `.jac`, load the guides bundled with the compiler:
`jac guide jac-essentials`, then the guide for the task (`jac guide --search
<topic>`).

## Validate your work

- `jac check <file>` for every file you touch, then the matching `jac test`.
- `jac run --dev web` serves the site on `localhost:8000` with hot reload for
  client modules; server-side changes need a restart.
- QA every UI change in the rendered page with `jac browse`, not just by
  reading code: `jac browse open localhost:8000/<route>`, `snapshot`, act on
  the `@e` refs (`click`, `fill`), check `console` for errors, `screenshot`.
  Cover the signed-out and signed-in paths of anything that touches auth.
- Do not `jac run` a probe script from inside this directory while the dev
  server is up; run probes from a scratch project instead.

## Don't work around jac bugs -- fix them in the compiler

A core goal of this site is to exercise and improve Jac itself. The compiler
lives in this same repo (`jac/jaclang/`), and the dev `jac` binary already
runs that source, so a fix there takes effect here immediately.

Working around a jac bug hides the defect and defeats that goal. When a
reasonable Jac idiom, CLI command or documented workflow fails, errors, or
behaves unexpectedly:

1. First verify it is a jac defect and not a misuse (check the guides, docs,
   examples and tests under `jac/`).
2. If it is jac, **pause the affected work and make a proper fix**: isolate a
   minimal repro, fix the root cause on its own branch off `main`, add
   regression coverage, and run the relevant targeted checks. CI gates on
   formatting first: from the repo root, run `jac fmt --lintfix` on every
   `.jac` file the fix touches, then `jac check <files> --nowarn`. The lint
   config strips comments and docstrings, so put the rationale in the commit
   message and release note.
3. Push the fix and open a PR against `main` with the `realdeal` label
   (`gh pr create --label realdeal ...`). This workflow is authorized without
   asking for separate permission for each defect. The PR body must say
   plainly whether the change is a **proper root-cause fix** or a
   **workaround** (a guard, special case or symptom patch that leaves the
   underlying defect in place). Proper fixes are strongly preferred; ship a
   workaround only when the root cause cannot be fixed now, and then explain
   in the PR body why, and what a proper fix would take. Report the issue,
   validation results, and PR link.
4. **Resume the original work on top of the fix** (stack the site branch on
   the fix branch) while the PR awaits review. Do not wait for the merge
   unless it is technically necessary.
5. Do **not** rewrite site code to avoid the construct, and do not hand out a
   manual workaround in place of a fix. If a fix or PR cannot be completed,
   explain the concrete blocker and continue any independent work that
   remains possible.

### Guides and docs are in scope

Outdated, wrong or missing information in a `jac guide` skill or in the jac
docs is a defect too, whenever it cost time or led to a wrong attempt: an
example that no longer compiles, a flag or config key that was renamed, a
required step nobody mentions, an error message whose advice is wrong. Do not
just note the correct usage and move on. Fix the text at its source
(`jac/jaclang/cli/skills/*.md` for the guides, `jac/jaclang/cli/docs/` for the
docs) and take it through the same steps: a branch off `main`, a PR labeled
`realdeal`, and the site work resumed on top. In place of a regression test, run every example
the corrected text shows.
