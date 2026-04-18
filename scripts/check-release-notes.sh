#!/usr/bin/env bash
# Pre-commit hook to check that release note fragments are added when code changes.
# Works in two modes:
#   - Local commit: uses git diff --cached to get staged files
#   - CI (pre-commit.ci / GitHub Actions): uses git diff against main branch

set -euo pipefail

# Maps code folders to their corresponding unreleased fragment directories
declare -A FOLDER_TO_FRAGMENTS=(
    ["jac/jaclang/"]="docs/docs/community/release_notes/unreleased/jaclang/"
    ["jac-scale/jac_scale/"]="docs/docs/community/release_notes/unreleased/jac-scale/"
    ["jac-client/jac_client/"]="docs/docs/community/release_notes/unreleased/jac-client/"
    ["jac-byllm/byllm/"]="docs/docs/community/release_notes/unreleased/byllm/"
    ["jac-super/jac_super/"]="docs/docs/community/release_notes/unreleased/jac-super/"
    ["jac-mcp/jac_mcp/"]="docs/docs/community/release_notes/unreleased/jac-mcp/"
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
        if [[ "$file" == "${fragments_dir}"* ]] && [[ "$file" =~ /[0-9]+\.(feature|bugfix|breaking|refactor|docs)\.md$ ]]; then
            fragment_added=true
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
