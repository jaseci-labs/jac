import dis;
import marshal;
import pdb;

class Jdb(pdb.Pdb) {
    def init(self: Jdb, *args: any, **kwargs: any) -> None;
    def has_breakpoint(self: Jdb, bytecode: bytes) -> bool;
}

glob debugger = Jdb();
