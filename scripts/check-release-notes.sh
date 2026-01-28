#!/usr/bin/env bash
# Pre-commit hook to check that release notes are updated when code changes.
# Mirrors the logic in .github/workflows/check-release-notes.yml but runs
# against the files staged for the current commit.

set -euo pipefail

declare -A FOLDER_TO_NOTES=(
    ["jac/"]="docs/docs/community/release_notes/jaclang.md"
    ["jac-scale/"]="docs/docs/community/release_notes/jac-scale.md"
    ["jac-client/"]="docs/docs/community/release_notes/jac-client.md"
    ["jac-byllm/"]="docs/docs/community/release_notes/byllm.md"
    ["jac-super/"]="docs/docs/community/release_notes/jac-super.md"
)

# Staged files are passed as arguments by pre-commit
STAGED_FILES=("$@")

MISSING_NOTES=()

for folder in "${!FOLDER_TO_NOTES[@]}"; do
    notes_file="${FOLDER_TO_NOTES[$folder]}"
    folder_changed=false
    notes_changed=false

    for file in "${STAGED_FILES[@]}"; do
        # Check if file is in the monitored folder (but not the release notes itself)
        if [[ "$file" == "${folder}"* ]]; then
            folder_changed=true
        fi
        if [[ "$file" == "$notes_file" ]]; then
            notes_changed=true
        fi
    done

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
