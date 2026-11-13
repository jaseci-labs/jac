obj ShellScreen {
    has screen: MainScreen,
        header: Header,
        transcript: TranscriptView,
        status: Status,
        prompt: Prompt,
        approval: ApprovalOverlay | None = None;
}


obj ShellIdSnapshot {
    has screen_id: str,
        header_id: str,
        transcript_id: str,
        status_id: str,
        prompt_id: str;
}


glob _SHELL_BY_SESSION: dict[str, ShellScreen] = {};


def build_main_shell(session: UiSession) -> ShellScreen;


def install_shell_contracts(session: UiSession, shell: ShellScreen, binding_name: str);


def shell_ids(shell: ShellScreen) -> ShellIdSnapshot;


def shell_insert_text(session: UiSession, shell: ShellScreen, text: str);


def shell_submit(session: UiSession, shell: ShellScreen) -> list[any];


def shell_cancel(session: UiSession, shell: ShellScreen);


def shell_open_approval(session: UiSession, shell: ShellScreen,) -> OverlayOpenResult;


def shell_close_approval(
    session: UiSession, shell: ShellScreen,
) -> OverlayCloseResult;


def shell_resize(session: UiSession, shell: ShellScreen, columns: int, rows: int,);


def _fill -> AxisSize;


def _fixed(n: float) -> AxisSize;


def _grow(weight: float) -> AxisSize;


def _spec(width: AxisSize, height: AxisSize) -> LayoutSpec;


def configure_main_shell_layout(
    state: LayoutState, shell: ShellScreen,
) -> list[LayoutDiagnostic];
