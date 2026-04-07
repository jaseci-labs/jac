"""Toast notification utility — replaces @mantine/notifications."""
cl import from "sonner" { toast as sonnerToast }

cl {
    def:pub notify(title: str, message: str, color: str) -> None {
        desc = message or title;
        ttl = title;
        if color == "red" or color == "error" {
            sonnerToast.error(ttl, {"description": desc});
        } elif color == "green" or color == "success" {
            sonnerToast.success(ttl, {"description": desc});
        } elif color == "yellow" or color == "warning" {
            sonnerToast.warning(ttl, {"description": desc});
        } else {
            sonnerToast(ttl, {"description": desc});
        }
    }
}
