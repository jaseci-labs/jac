impl CopyCommandBlock.handle_copy(_e: MouseEvent) {
    navigator.clipboard.writeText("\n".join(lines));
    copied = True;
    _ = setTimeout(lambda { copied = False; }, 1800);
}

impl CopyCommand.handle_copy(_e: MouseEvent) {
    navigator.clipboard.writeText(command);
    copied = True;
    _ = setTimeout(lambda { copied = False; }, 1800);
}
