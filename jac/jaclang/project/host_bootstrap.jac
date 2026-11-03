import sys;

obj BootstrapProjectHost(ProjectHost) {
    def module_in_flight(names: list[str]) -> str;
    def import_in_flight(path: str) -> bool;
}
