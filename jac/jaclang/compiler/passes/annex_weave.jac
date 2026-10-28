obj WovenAnnex {
    has source: str,
        path: str,
        consumer: str = "";
}

def merge_annex_into(nd: Module, annex_mod: Module) -> None;

def import_form(
    is_absorb: bool, is_typed: bool, is_comptime: bool, from_form: bool
) -> str;
