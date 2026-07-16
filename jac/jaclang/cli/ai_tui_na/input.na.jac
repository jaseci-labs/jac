# Input adapter — routes keys through the reducer; maps effects onto CmdQueue.

import from .keys { Key, KeyKind }
import from .runtime { TuiRuntime }
import from .input_types { UiAction, UiActionKind, Effect, EffectKind }
import from .reducer { reduce_input }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT, CMD_APPLY }

def execute_effects(rt: TuiRuntime, effects: list[Effect]) {
    state = rt.state;
    for e in effects {
        if e.kind == EffectKind.QUIT {
            rt.cmd_queue.send(state.ipc_fd, CMD_QUIT);
        } elif e.kind == EffectKind.STOP {
            rt.cmd_queue.send(state.ipc_fd, CMD_STOP);
        } elif e.kind == EffectKind.RESET {
            rt.cmd_queue.send(state.ipc_fd, CMD_RESET);
        } elif e.kind == EffectKind.SEND_PROMPT {
            rt.cmd_queue.send(state.ipc_fd, CMD_SEND + ":" + e.payload);
        } elif e.kind == EffectKind.APPLY_SETTINGS {
            rt.cmd_queue.send(state.ipc_fd, CMD_APPLY + ":" + e.payload);
        }
    }
}

def handle_key(k: Key, rt: TuiRuntime) -> bool {
    if k.kind == KeyKind.UNKNOWN {
        return False;
    }
    action = UiAction(kind=UiActionKind.KEY, key=k);
    res = reduce_input(rt.state, action);
    execute_effects(rt, res.effects);
    return res.quit;
}
