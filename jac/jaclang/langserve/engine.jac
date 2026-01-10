"""Living Workspace of Jac project."""

import asyncio;
import logging;
import os;
import sys;
import time;
import threading;
import from concurrent.futures { ThreadPoolExecutor }
import from queue { Queue, Empty }
import from typing { Callable, Optional }

import jaclang.pycore.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.pycore.constant { SymbolType }
import from jaclang.pycore.program { JacProgram }
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.compiler.type_system.types {
    ClassType,
    FunctionType,
    OverloadedType,
    ModuleType,
    TypeBase
}
import from jaclang.pycore.unitree { UniScopeNode }
import from .sem_manager { SemTokManager }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import from . { utils }
import from .module_manager { ModuleManager }

obj Task {
    has file_uri: str,
        task_id: int = 0,
        cancel_token: threading.Event | None = None;

    static has _task_id: int = 0;

    def postinit -> None;
}

"""Jac Language Server, manages JacProgram and LSP."""
class JacLangServer(JacProgram, LanguageServer) {
    has module_manager: ModuleManager,
        sem_managers: dict,
        queue: Queue,
        worker_thread: threading.Thread,
        last_task: Task | None = None,
        _shutdown_called: bool = False;

    def init(self: JacLangServer) -> None;
    def dispatcher(self: JacLangServer) -> None;
    @property
    def diagnostics(self: JacLangServer,) -> dict[str, list];

    def _clear_alerts_for_file(self: JacLangServer, file_path: str) -> None;
    def get_ir(self: JacLangServer, file_path: str) -> Optional[uni.Module];
    def update_modules(
        self: JacLangServer, file_path: str, build: uni.Module, need: bool = True
    ) -> None;

    def type_check_file(
        self: JacLangServer,
        file_uri: str,
        cancel_token: Event | None = None,
        annex_view: Optional[str] = None,
        # This parameter will be passed recursively
        # and dont need to pass when the function itself is called
        # outside.
    ) -> bool;

    def type_check(self: JacLangServer, file_uri: str) -> None;
    def get_token_at_position(
        self: JacLangServer, file_path: str, position: lspt.Position
    ) -> Optional[uni.AstNode];

    def debug(self: JacLangServer, msg: str) -> None;
    async def wait_till_idle(self: JacLangServer) -> None {
        self.debug("Waiting for queue to empty...");
        await asyncio.to_thread(self.queue.join);
        self.debug("Queue is now empty");
    }

    def wait_till_idle_sync(self: JacLangServer) -> None;
    """Return completion for a file."""
    async def get_completion(
        self: JacLangServer,
        file_uri: str,
        position: lspt.Position,
        completion_trigger: Optional[str]
    ) -> lspt.CompletionList {
        # NOTE: We may only need to wait for the current file's type check.
        await self.wait_till_idle();

        self.debug("Getting completion for " + file_uri + " at " + str(position));
        try {
            file_path = uris.to_fs_path(file_uri);
            if (
                node_at_pos := self.get_node_at_position(
                    file_path, position.line, position.character - 1
                )
            ) {
                self.debug(
                    "found the node at pos " + str(position) + " " + str(node_at_pos)
                );
                # For each trigger character we need to handle the completion differently
                if isinstance(node_at_pos, uni.Token) {
                    if node_at_pos.name == "DOT" {
                        member_access = node_at_pos.parent;
                        self.debug("found dot " + str(member_access));
                        if isinstance(member_access, uni.AtomTrailer) {
                            self.debug("before returning the list");
                            return self.get_completion_of_node(member_access.target);
                        }
                        # FIXME: This is wrong but imma do it anyways like this for now.
                    } elif node_at_pos.name == "NAME" {
                        # Name of atom trailer.
                        if (
                            node_at_pos.parent
                            and isinstance(node_at_pos.parent, uni.AtomTrailer)
                        ) {
                            self.debug(
                                "found name in atom trailer " + str(node_at_pos.parent)
                            );
                            return self.get_completion_of_node(
                                node_at_pos.parent.target
                            );
                        }
                        # Just a name field.
                        if scope_node := node_at_pos.find_parent_of_type(
                            uni.UniScopeNode
                        ) {
                            self.debug("found name in scope node " + str(scope_node));
                            return self.get_completion_of_node(scope_node);
                        }
                    }
                }
            }
            return lspt.CompletionList(is_incomplete=False, items=[]);
        } except Exception as e {
            self.log_py(f"'Error during completion: '{e}");
            return lspt.CompletionList(is_incomplete=False, items=[]);
        }

        self.debug("returning empty list");
    }

    def get_ast_of_file(self: JacLangServer, file_path: str) -> Optional[uni.AstNode];
    def get_node_at_position(
        self: JacLangServer, file_path: str, line: int, col: int
    ) -> Optional[uni.AstNode];

    def get_completion_of_node(
        self: JacLangServer, node: uni.AstNode
    ) -> lspt.CompletionList;

    def get_node_type(self: JacLangServer, n: uni.AstNode) -> Optional[TypeBase];
    def get_completion_items_of(
        self: JacLangServer, ty: TypeBase | uni.UniScopeNode
    ) -> lspt.CompletionList;

    def rename_module(self: JacLangServer, old_path: str, new_path: str) -> None;
    def delete_module(self: JacLangServer, uri: str) -> None;
    def formatted_jac(self: JacLangServer, file_path: str) -> list[lspt.TextEdit];
    def get_hover_info(
        self: JacLangServer, file_path: str, position: lspt.Position
    ) -> Optional[lspt.Hover];

    def get_node_info(
        self: JacLangServer, sym_node: uni.AstSymbolNode
    ) -> Optional[str];

    def get_outline(self: JacLangServer, file_path: str) -> list[lspt.DocumentSymbol];
    def get_definition(
        self: JacLangServer, file_path: str, position: lspt.Position
    ) -> Optional[lspt.Location];

    def get_references(
        self: JacLangServer, file_path: str, position: lspt.Position
    ) -> list[lspt.Location];

    def rename_symbol(
        self: JacLangServer, file_path: str, position: lspt.Position, new_name: str
    ) -> Optional[lspt.WorkspaceEdit];

    def get_semantic_tokens(self: JacLangServer, file_path: str) -> lspt.SemanticTokens;
    def log_error(self: JacLangServer, message: str) -> None;
    def log_warning(self: JacLangServer, message: str) -> None;
    def log_info(self: JacLangServer, message: str) -> None;
    def log_py(self: JacLangServer, message: str) -> None;
    def shutdown(self: JacLangServer) -> None;
}
