#!/usr/bin/env bash
# Pre-commit hook to check that release notes are updated when code changes.
# Works in two modes:
#   - Local commit: uses git diff --cached to get staged files
#   - CI (pre-commit.ci / GitHub Actions): uses git diff against main branch

set -euo pipefail

declare -A FOLDER_TO_NOTES=(
    ["jac/jaclang/"]="docs/docs/community/release_notes/jaclang.md"
    ["jac-scale/jac_scale/"]="docs/docs/community/release_notes/jac-scale.md"
    ["jac-client/jac_client/"]="docs/docs/community/release_notes/jac-client.md"
    ["jac-byllm/byllm/"]="docs/docs/community/release_notes/byllm.md"
    ["jac-super/jac_super/"]="docs/docs/community/release_notes/jac-super.md"
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

for folder in "${!FOLDER_TO_NOTES[@]}"; do
    notes_file="${FOLDER_TO_NOTES[$folder]}"
    folder_changed=false
    notes_changed=false

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [[ "$file" == "${folder}"* ]] && [[ "$file" != */tests/* ]]; then
            folder_changed=true
        fi
        if [[ "$file" == "$notes_file" ]]; then
            notes_changed=true
        fi
    done <<< "$CHANGED_FILES"

    if $folder_changed && ! $notes_changed; then
        MISSING_NOTES+=("${folder} -> ${notes_file}")
    fi
done

if [ ${#MISSING_NOTES[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Release notes not updated!"
    echo "=========================================="
    echo ""
    echo "The following folders were modified but their release notes were not updated:"
    echo ""
    for item in "${MISSING_NOTES[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Please update the corresponding release notes file(s)."
    echo "To skip this check, use: SKIP=check-release-notes git commit ..."
    exit 1
fi
