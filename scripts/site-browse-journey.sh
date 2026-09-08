#!/usr/bin/env bash
# Drive the served jaclang.org site (jac/examples/jaclang_org) through a full
# user journey with `jac browse`, asserting rendered content and fullstack
# behavior at every stop. Used by CI (ci.yml pack-smoke) and
# runnable locally against any server:
#
#   scripts/site-browse-journey.sh [BASE_URL]
#
# Env knobs:
#   SITE_JOURNEY_SKIP_DOCS=1   skip the docs stop (docs sync needs either
#                              network or JAC_DOCS_LOCAL on the server side)
#   SITE_JOURNEY_SKIP_WASM=1   skip the arena.wasm asset check (dev-mode wasm
#                              emission needs a jac newer than the fix; drop
#                              this knob once that release ships)
#   SITE_JOURNEY_ARTIFACTS     directory for failure screenshots (default /tmp)
set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"
ARTIFACTS="${SITE_JOURNEY_ARTIFACTS:-/tmp}"
RUN_TAG="$(date +%s)"
USER_NAME="ci_ninja_${RUN_TAG}"
USER_PASS="ci-secret-${RUN_TAG}"
TWEET_TEXT="Hello from the CI journey ${RUN_TAG}. One program, whole stack. #jacdev"
COMMENT_TEXT="CI reply ${RUN_TAG}: comments work."
CHANNEL_NAME="ci-channel-${RUN_TAG}"
CHANNEL_POST="First CI post in ${CHANNEL_NAME}."

CURRENT_STEP="(setup)"

step() {
    CURRENT_STEP="$1"
    echo ""
    echo "=== ${CURRENT_STEP}"
}

fail() {
    echo "::error::journey failed at step: ${CURRENT_STEP} :: $*"
    jac browse screenshot "${ARTIFACTS}/site-journey-failure.png" || true
    jac browse snapshot | head -n 60 || true
    echo "--- console at failure ---"
    jac browse console || true
    exit 1
}

# Evaluate JS in the page; the expression must throw on failure.
check() {
    jac browse eval "$1" || fail "eval check did not pass"
}

# Poll the rendered page text until it contains a literal string.
wait_for_text() {
    local needle="$1"
    local tries="${2:-30}"
    local i
    for i in $(seq 1 "$tries"); do
        if jac browse get text body 2>/dev/null | grep -qF "$needle"; then
            echo "found: ${needle}"
            return 0
        fi
        sleep 2
    done
    fail "page text never contained: ${needle}"
}

open_page() {
    # A slow page-load event can outlast the CDP navigation wait; one retry
    # absorbs that without masking a dead server.
    if ! jac browse open "$1"; then
        echo "open of $1 timed out; retrying once"
        sleep 3
        jac browse open "$1" || fail "could not open $1"
    fi
    sleep 2
}

# ---------------------------------------------------------------- landing ---
step "landing: open and title"
for i in 1 2 3; do
    if jac browse open "$BASE_URL"; then
        break
    fi
    echo "browser launch attempt ${i} failed; retrying"
    jac browse close || true
    sleep 5
    [ "$i" = 3 ] && fail "browser failed to launch after 3 attempts"
done
jac browse wait '#top' || fail "landing #top never appeared"
# The headless profile persists localStorage between runs; start from a clean
# slate so the JacYac journey always begins at the auth form.
jac browse eval 'localStorage.clear(); sessionStorage.clear(); "storage cleared"' \
    || fail "could not clear browser storage"
title="$(jac browse get title)"
echo "title: ${title}"
[ -n "$title" ] || fail "empty page title"

step "landing: install one-liner is rendered"
check '(() => {
  const text = document.body.innerText;
  if (!/curl\s+-fsSL\s+\S*install\.sh\s*\|\s*bash/.test(text)) {
    throw new Error("install curl one-liner not rendered on the landing page");
  }
  return "install curl one-liner rendered";
})()'

step "landing: quickstart scaffolds the site with jac create --awesome"
check '(() => {
  const text = document.body.innerText;
  if (/jac_site/.test(text)) {
    throw new Error("landing page still references the retired jac_site repo");
  }
  if (/git clone/.test(text)) {
    throw new Error("landing page still shows the clone-and-cd quickstart");
  }
  if (!/jac create \S+ --awesome/.test(text)) {
    throw new Error("landing page does not show the jac create --awesome quickstart");
  }
  return "quickstart scaffolds the site via --awesome";
})()'

step "landing: ninja book cover is visible and links to the book"
check '(async () => {
  const section = document.querySelector("#book");
  if (!section) throw new Error("no #book section on the landing page");
  section.scrollIntoView({block: "center"});
  const img = section.querySelector("a[href] img[src*=ninja-book-cover]");
  if (!img) throw new Error("no ninja book cover image inside a link");
  const href = img.closest("a").href;
  if (!/doi\.org|zenodo/.test(href)) {
    throw new Error("book cover links to " + href + ", not the book");
  }
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const rect = img.getBoundingClientRect();
    const unobscured = img.checkVisibility
      ? img.checkVisibility({checkOpacity: true, checkVisibilityCSS: true})
      : true;
    if (img.complete && img.naturalWidth > 0
        && rect.width > 0 && rect.height > 0 && unobscured) {
      return "book cover visible, links to " + href;
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error("book cover image never became visible");
})()'

if [ "${SITE_JOURNEY_SKIP_WASM:-0}" = "1" ]; then
    step "landing: wasm check skipped (SITE_JOURNEY_SKIP_WASM=1)"
else
    step "landing: native wasm module is built and served"
    wasm_bytes="$(curl -sf --max-time 30 "$BASE_URL/static/arena.wasm" | wc -c | tr -d ' ')"
    echo "arena.wasm: ${wasm_bytes} bytes"
    [ "$wasm_bytes" -gt 10000 ] || fail "arena.wasm missing or implausibly small (${wasm_bytes} bytes)"
fi

# ------------------------------------------------------------- wait-wuuut ---
step "wait-wuuut: live source windows stream real files"
open_page "$BASE_URL/wait-wuuut"
wait_for_text "What you won't see" 30
wait_for_text "LIVE SOURCE" 45
check '(() => {
  const text = document.body.innerText;
  if (!/source\/files\.jac/.test(text)) {
    throw new Error("no live source window resolved source/files.jac");
  }
  return "live source windows loaded";
})()'

# ----------------------------------------------------------- Ninja Scores ---
step "Ninja Scores: the legacy board opens the public JacYac directory"
open_page "$BASE_URL/leaderboard"
wait_for_text "Ninja Scores" 30
jac browse wait 'section[aria-label="Ninja Scores"]' || fail "public scores never appeared"
check '(() => {
  if (location.pathname !== "/jacyac/scores") {
    throw new Error("legacy leaderboard did not redirect into JacYac");
  }
  const section = document.querySelector("section[aria-label=\"Ninja Scores\"]");
  if (!section.querySelector("input[aria-label=\"Search Ninja Scores\"]")) {
    throw new Error("public scores search is missing");
  }
  if (!section.textContent.includes("Sign in to add your project")) {
    throw new Error("anonymous scores must offer sign-in before submission");
  }
  if (section.querySelector("input[aria-label=\"GitHub repository URL\"]")) {
    throw new Error("anonymous visitor was offered repository submission");
  }
  const header = document.querySelector("header");
  const join = [...header.querySelectorAll("a")]
    .find(a => a.textContent.trim() === "Join JacYac");
  if (!join || join.getAttribute("href") !== "/jacyac") {
    throw new Error("site CTA does not open JacYac");
  }
  if (header.textContent.includes("Ninja Scores")) {
    throw new Error("Ninja Scores still appears in the site-wide navigation");
  }
  return "legacy redirect, public scores, and signed-in submission boundary verified";
})()'

# -------------------------------------------------------------- socialize ---
step "JacYac: signup through the real form"
open_page "$BASE_URL/socialize"
jac browse wait '#lx-username' || fail "auth form never appeared"
check '(() => {
  const toggle = [...document.querySelectorAll("button")]
    .find((b) => b.textContent.trim() === "Sign Up");
  if (!toggle) throw new Error("no Sign Up toggle on the auth card");
  toggle.click();
  return "switched to signup";
})()'
sleep 1
jac browse fill '#lx-username' "$USER_NAME" || fail "could not fill username"
jac browse fill '#lx-password' "$USER_PASS" || fail "could not fill password"
check '(() => {
  const submit = document.querySelector("button[type=submit]");
  if (!submit) throw new Error("no submit button on the auth form");
  if (submit.disabled) throw new Error("submit button is disabled after filling");
  submit.click();
  return "signup submitted";
})()'
jac browse wait 'textarea' || fail "feed composer never appeared after signup"
wait_for_text "$USER_NAME" 15

step "JacYac: signed-in Ninja Scores validates submissions and retains the draft"
open_page "$BASE_URL/jacyac/scores"
jac browse wait 'input[aria-label="GitHub repository URL"]' || fail "signed-in repository input never appeared"
check '(() => {
  const submit = document.querySelector("section[aria-label=\"Ninja Scores\"] button[type=submit]");
  if (!submit || submit.textContent.trim() !== "Add project" || !submit.disabled) {
    throw new Error("empty repository submission must be disabled");
  }
  return "signed-in repository submission rendered";
})()'
jac browse fill 'input[aria-label="GitHub repository URL"]' 'https://example.com/owner/repo' || fail "could not fill repository URL"
jac browse click 'section[aria-label="Ninja Scores"] button[type=submit]' || fail "could not submit invalid repository"
wait_for_text "That is not a GitHub repository" 20
check '(() => {
  const input = document.querySelector("input[aria-label=\"GitHub repository URL\"]");
  if (input.value !== "https://example.com/owner/repo") {
    throw new Error("failed submission discarded the repository draft");
  }
  return "invalid repository rejected and draft retained";
})()'
open_page "$BASE_URL/jacyac"
jac browse wait 'textarea' || fail "modern JacYac route lost the session"

step "JacYac: post a tweet"
jac browse fill 'textarea' "$TWEET_TEXT" || fail "could not fill composer"
# The sidebar has a "Post" nav button too; the composer submit is the first
# enabled "Post" that follows the textarea in document order.
check '(() => {
  const ta = document.querySelector("textarea");
  const post = [...document.querySelectorAll("button")]
    .filter((b) => b.textContent.trim() === "Post" && !b.disabled)
    .find((b) => ta
      && (ta.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING));
  if (!post) throw new Error("no enabled Post button after the composer");
  post.click();
  return "tweet posted";
})()'
wait_for_text "Hello from the CI journey ${RUN_TAG}" 20

step "JacYac: hashtag shows up in trending"
wait_for_text "#jacdev" 20

step "JacYac: like the tweet"
check '(() => {
  const like = [...document.querySelectorAll("main article button")]
    .find((b) => b.querySelector("svg.lucide-heart"));
  if (!like) throw new Error("no like button on the tweet");
  like.click();
  return "like clicked";
})()'
check '(async () => {
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    const like = [...document.querySelectorAll("main article button")]
      .find((b) => b.querySelector("svg.lucide-heart"));
    if (like && /1/.test(like.textContent)) return "like count is 1";
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error("like count never reached 1");
})()'

# Posts, comments, and channel posts share the default 10-second account quota.
# Keep this happy-path journey within the same limits as real users.
sleep 10
step "JacYac: comment on the tweet"
check '(() => {
  const reply = [...document.querySelectorAll("main article button")]
    .find((b) => b.querySelector("svg.lucide-message-circle"));
  if (!reply) throw new Error("no reply toggle on the tweet");
  reply.click();
  return "reply box opened";
})()'
jac browse wait 'main article input' || fail "reply input never appeared"
jac browse fill 'main article input' "$COMMENT_TEXT" || fail "could not fill reply"
jac browse press Enter || fail "could not submit reply"
wait_for_text "CI reply ${RUN_TAG}" 20

step "JacYac: create a channel and post in it"
check '(() => {
  const nav = [...document.querySelectorAll("aside button")]
    .find((b) => /Channels/.test(b.textContent));
  if (!nav) throw new Error("no Channels nav button");
  nav.click();
  return "channels tab opened";
})()'
wait_for_text "Create Channel" 15
check '(() => {
  const create = [...document.querySelectorAll("button")]
    .find((b) => /Create Channel/.test(b.textContent));
  create.click();
  return "create dialog opened";
})()'
jac browse wait '#lx-ch-name' || fail "channel dialog never appeared"
jac browse fill '#lx-ch-name' "$CHANNEL_NAME" || fail "could not fill channel name"
check '(() => {
  const confirm = [...document.querySelectorAll("button")]
    .find((b) => b.textContent.trim() === "Create" && !b.disabled);
  if (!confirm) throw new Error("no enabled Create button in the dialog");
  confirm.click();
  return "channel created";
})()'
wait_for_text "$CHANNEL_NAME" 20
wait_for_text "1 member" 15
check "(() => {
  const card = [...document.querySelectorAll('main div')]
    .find((d) => (d.className || '').includes('cursor-pointer')
      && d.textContent.includes('${CHANNEL_NAME}'));
  if (!card) throw new Error('channel card not found');
  card.click();
  return 'channel opened';
})()"
jac browse wait 'textarea' || fail "channel composer never appeared"
sleep 10
jac browse fill 'textarea' "$CHANNEL_POST" || fail "could not fill channel post"
check '(() => {
  const ta = document.querySelector("textarea");
  const post = [...document.querySelectorAll("button")]
    .filter((b) => b.textContent.trim() === "Post" && !b.disabled)
    .find((b) => ta
      && (ta.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING));
  if (!post) throw new Error("no enabled Post button after the channel composer");
  post.click();
  return "channel post sent";
})()'
wait_for_text "First CI post in ${CHANNEL_NAME}" 20

step "JacYac: session and data survive a reload"
open_page "$BASE_URL/socialize"
jac browse wait 'textarea' || fail "reload lost the session (auth form is back)"
wait_for_text "Hello from the CI journey ${RUN_TAG}" 30

# ------------------------------------------------------------------- docs ---
if [ "${SITE_JOURNEY_SKIP_DOCS:-0}" = "1" ]; then
    step "docs: skipped (SITE_JOURNEY_SKIP_DOCS=1)"
else
    step "docs: the synced graph serves pages"
    open_page "$BASE_URL/docs/latest"
    wait_for_text "What is Jac" 120
    check '(() => {
      const links = [...document.querySelectorAll("aside a, nav a")]
        .filter((a) => /\/docs\//.test(a.getAttribute("href") || ""));
      if (links.length < 5) {
        throw new Error("docs sidebar has only " + links.length + " page links");
      }
      return "docs sidebar carries " + links.length + " links";
    })()'
fi

# --------------------------------------------------------------- not found ---
step "404: unmatched routes render the catch-all page"
open_page "$BASE_URL/definitely-not-a-page-${RUN_TAG}"
wait_for_text "No node here." 15

# ---------------------------------------------------------- console sweep ---
step "console: no uncaught client errors anywhere on the journey"
console_out="$(jac browse console || true)"
echo "--- console (informational) ---"
printf '%s\n' "$console_out" | tail -n 40
if printf '%s' "$console_out" \
    | grep -E '\[error\]' \
    | grep -qEv 'Failed to load resource|forwardRef|favicon'; then
    printf '%s\n' "$console_out" | grep -E '\[error\]'
    fail "client console captured uncaught errors"
fi

step "done"
echo "journey complete: landing, wait-wuuut, public Ninja Scores, JacYac"
echo "(signup/repository validation/post/trend/like/comment/channels/reload), legacy routes, docs, 404, console"
