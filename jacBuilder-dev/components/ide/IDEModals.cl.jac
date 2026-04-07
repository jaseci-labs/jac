import from "..ui.alert-dialog" {
    AlertDialog, AlertDialogContent, AlertDialogHeader,
    AlertDialogTitle, AlertDialogDescription,
    AlertDialogFooter, AlertDialogCancel, AlertDialogAction
}
import from .KeyboardShortcuts { KeyboardShortcuts }

def:pub IDEModals(props: Any) -> Any {
    m = props.modals;

    return <>
        <AlertDialog open={m.deleteModalOpen} onOpenChange={lambda(open: bool) { if not open { closeFn = m.closeDeleteModal; closeFn.call(None); } }}>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>Delete File</AlertDialogTitle>
                    <AlertDialogDescription>
                        Are you sure you want to delete{" "}
                        <span className="font-semibold text-foreground">{m.deleteTargetPath}</span>
                        {"? This action cannot be undone."}
                    </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel onClick={m.closeDeleteModal}>
                        Cancel
                    </AlertDialogCancel>
                    <AlertDialogAction variant="destructive" onClick={m.handleDeleteConfirm}>
                        Delete
                    </AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>

        <KeyboardShortcuts
            opened={m.shortcutsModalOpen}
            onClose={m.closeShortcuts}
        />
    </>;
}
