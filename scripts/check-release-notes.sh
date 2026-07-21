#!/usr/bin/env bash
# Pre-commit hook to check that release note fragments are added when code changes.
# Works in two modes:
#   - Local commit: uses git diff --cached to get staged files
#   - CI (pre-commit.ci / GitHub Actions): uses git diff against main branch

set -euo pipefail

# Maps code folders to their corresponding unreleased fragment directories.
# byLLM and scale are folded into jac/jaclang/ (jaclang.byllm / jaclang.scale),
# so their changes are covered by the jac/jaclang/ -> jaclang mapping below.
declare -A FOLDER_TO_FRAGMENTS=(
    ["jac/jaclang/"]="docs/docs/community/release_notes/unreleased/jaclang/"
)

# Determine changed files based on context
if [ -n "${CI:-}" ] || [ -n "${PRE_COMMIT_FROM_REF:-}" ]; then
    # CI mode: compare against main branch
    if [ -n "${PRE_COMMIT_FROM_REF:-}" ] && [ -n "${PRE_COMMIT_TO_REF:-}" ]; then
        CHANGED_FILES=$(git diff --name-only "$PRE_COMMIT_FROM_REF"..."$PRE_COMMIT_TO_REF" 2>/dev/null || true)
    else
        # Fallback: compare against origin/main
        MERGE_BASE=$(git merge-base origin/main HEAD 2>/dev/null || echo "")
        if [ -z "$MERGE_BASE" ]; then
            exit 0
        fi
        CHANGED_FILES=$(git diff --name-only "$MERGE_BASE"...HEAD 2>/dev/null || true)
    fi
else
    # Local mode: check staged files
    CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
fi

if [ -z "$CHANGED_FILES" ]; then
    exit 0
fi

# Release PRs created by the release script legitimately edit protected files - skip all checks
if [[ "${PR_TITLE:-}" == release:* ]] || [[ "${PR_AUTHOR:-}" == "github-actions[bot]" ]]; then
    exit 0
fi

# Check if any release notes .md files were directly modified
PROTECTED_FILES=(
    "docs/docs/community/release_notes/jaclang.md"
)

DIRECTLY_MODIFIED=()
while IFS= read -r file; do
    [ -z "$file" ] && continue
    for protected in "${PROTECTED_FILES[@]}"; do
        if [[ "$file" == "$protected" ]]; then
            DIRECTLY_MODIFIED+=("$file")
        fi
    done
done <<< "$CHANGED_FILES"

if [ ${#DIRECTLY_MODIFIED[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Do not edit release notes files directly!"
    echo "=========================================="
    echo ""
    echo "The following files were modified directly:"
    echo ""
    for item in "${DIRECTLY_MODIFIED[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Release notes are managed via fragment files."
    echo "Add a fragment at: docs/docs/community/release_notes/unreleased/<package>/<PR#>.<category>.md"
    echo ""
    exit 1
fi

# Fragment path with the PR number captured in group 1.
FRAGMENT_REGEX='docs/docs/community/release_notes/unreleased/[^/]+/([0-9]+)\.(feature|bugfix|breaking|refactor|docs)\.md$'

CHANGED_FRAGMENTS=()
while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Deleted fragments (cleanup of stale entries) are not "this PR's fragment"
    [ -f "$file" ] || continue
    [[ "$file" =~ $FRAGMENT_REGEX ]] && CHANGED_FRAGMENTS+=("$file")
done <<< "$CHANGED_FILES"

# A PR may only add/edit a fragment named after its own number; skipped locally
# where PR_NUMBER is unknown.
PR_NUMBER="${PR_NUMBER:-}"
if [ -n "$PR_NUMBER" ]; then
    WRONG_NUMBER_FRAGMENTS=()
    for file in "${CHANGED_FRAGMENTS[@]}"; do
        [[ "$file" =~ $FRAGMENT_REGEX ]] || continue
        if [ "${BASH_REMATCH[1]}" != "$PR_NUMBER" ]; then
            WRONG_NUMBER_FRAGMENTS+=("$file")
        fi
    done

    if [ ${#WRONG_NUMBER_FRAGMENTS[@]} -gt 0 ]; then
        echo ""
        echo "=========================================="
        echo "ERROR: Release note fragment does not belong to this PR!"
        echo "=========================================="
        echo ""
        echo "This PR (#${PR_NUMBER}) changes fragment files whose number is not ${PR_NUMBER}:"
        echo ""
        for item in "${WRONG_NUMBER_FRAGMENTS[@]}"; do
            echo "  - $item"
        done
        echo ""
        echo "You may only add or edit a fragment named after your own PR number:"
        echo "  docs/docs/community/release_notes/unreleased/<package>/${PR_NUMBER}.<category>.md"
        echo ""
        echo "Do not reuse a different number and do not modify other contributors' fragments."
        echo ""
        echo "To skip this check, add the 'skip-release-notes-check' label to your PR."
        echo ""
        exit 1
    fi
fi

MISSING_NOTES=()

for folder in "${!FOLDER_TO_FRAGMENTS[@]}"; do
    fragments_dir="${FOLDER_TO_FRAGMENTS[$folder]}"
    folder_changed=false
    fragment_added=false

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [[ "$file" == "${folder}"* ]] && [[ "$file" != */tests/* ]]; then
            folder_changed=true
        fi
        if [[ "$file" == "${fragments_dir}"* ]] && [[ "$file" =~ /([0-9]+)\.(feature|bugfix|breaking|refactor|docs)\.md$ ]]; then
            if [ -z "$PR_NUMBER" ] || [ "${BASH_REMATCH[1]}" == "$PR_NUMBER" ]; then
                fragment_added=true
            fi
        fi
    done <<< "$CHANGED_FILES"

    if $folder_changed && ! $fragment_added; then
        MISSING_NOTES+=("${folder} -> ${fragments_dir}<PR#>.<feature|bugfix|breaking|refactor|docs>.md")
    fi
done

if [ ${#MISSING_NOTES[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Release note fragment not added!"
    echo "=========================================="
    echo ""
    echo "The following folders were modified but no release note fragment was added:"
    echo ""
    for item in "${MISSING_NOTES[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Please add a release note fragment file."
    echo "Example: docs/docs/community/release_notes/unreleased/<package>/1234.bugfix.md"
    echo "         docs/docs/community/release_notes/unreleased/<package>/1234.breaking.md"
    echo ""
    echo "Fragment content should be a single bullet point, e.g.:"
    echo '  - **Fix: Brief title**: Description of the change.'
    echo ""
    echo "To skip this check, add the 'skip-release-notes-check' label to your PR."
    echo ""
    exit 1
fi

# Validate content format of newly added/modified fragment files
MALFORMED_FRAGMENTS=()

for file in "${CHANGED_FRAGMENTS[@]}"; do
    [ -f "$file" ] || continue
    # Reject plain paragraphs and headings; entries must be bullet points.
    grep -qE '^[^[:space:]-]|^-[[:space:]]+#{1,6}[[:space:]]' "$file" 2>/dev/null && \
        MALFORMED_FRAGMENTS+=("$file: all entries must be bullet points starting with '- ' (no headings or plain paragraphs)")
done

if [ ${#MALFORMED_FRAGMENTS[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Malformed release note fragment(s)!"
    echo "=========================================="
    echo ""
    printf '  - %s\n' "${MALFORMED_FRAGMENTS[@]}"
    echo ""
    echo "Each fragment must be a single bullet point:"
    echo '  - **Category: Brief title**: Description of the change.'
    echo ""
    echo "To skip this check, add the 'skip-release-notes-check' label to your PR."
    echo ""
    exit 1
fi
