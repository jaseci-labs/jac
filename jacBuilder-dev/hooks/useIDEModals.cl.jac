"""Modal state management hook for the IDE — only delete confirmation and shortcuts."""

import from react { useState }

"""Hook for managing IDE modal dialogs: delete confirmation and keyboard shortcuts."""
def:pub useIDEModals(ide: Any) -> Any {
    has deleteModalOpen: bool = False;
    has shortcutsModalOpen: bool = False;
    has deleteTargetPath: str = "";

    def handleDeleteFile(path: str) -> None {
        deleteTargetPath = path;
        deleteModalOpen = True;
    }

    def handleDeleteConfirm() -> None {
        if deleteTargetPath {
            ide.deleteFile(deleteTargetPath);
        }
        deleteModalOpen = False;
        deleteTargetPath = "";
    }

    def openShortcuts() -> None {
        shortcutsModalOpen = True;
    }

    def closeShortcuts() -> None {
        shortcutsModalOpen = False;
    }

    def closeDeleteModal() -> None {
        deleteModalOpen = False;
        deleteTargetPath = "";
    }

    return {
        "deleteModalOpen": deleteModalOpen,
        "shortcutsModalOpen": shortcutsModalOpen,
        "deleteTargetPath": deleteTargetPath,
        "handleDeleteFile": handleDeleteFile,
        "handleDeleteConfirm": handleDeleteConfirm,
        "openShortcuts": openShortcuts,
        "closeShortcuts": closeShortcuts,
        "closeDeleteModal": closeDeleteModal
    };
}
