import os;
import sys;

obj TargetSpec {
    has triple: str,
        osarch: str,
        os_family: str,
        arch: str,
        cpython_platform: str,
        object_format: str,
        shared_prefix: str,
        shared_suffix: str;

    def kernel_file_name -> str;
}

class UnknownTarget(ValueError) {}

glob RELEASE_TARGETS: list[TargetSpec] = [
         TargetSpec(
             triple="x86_64-unknown-linux-gnu",
             osarch="linux-x86_64",
             os_family="linux",
             arch="x86_64",
             cpython_platform="linux",
             object_format="elf",
             shared_prefix="lib",
             shared_suffix=".so"
         ),
         TargetSpec(
             triple="aarch64-unknown-linux-gnu",
             osarch="linux-aarch64",
             os_family="linux",
             arch="aarch64",
             cpython_platform="linux",
             object_format="elf",
             shared_prefix="lib",
             shared_suffix=".so"
         ),
         TargetSpec(
             triple="arm64-apple-macosx11.0.0",
             osarch="macos-aarch64",
             os_family="darwin",
             arch="aarch64",
             cpython_platform="darwin",
             object_format="macho",
             shared_prefix="lib",
             shared_suffix=".dylib"
         ),
         TargetSpec(
             triple="x86_64-apple-macosx10.15.0",
             osarch="macos-x86_64",
             os_family="darwin",
             arch="x86_64",
             cpython_platform="darwin",
             object_format="macho",
             shared_prefix="lib",
             shared_suffix=".dylib"
         ),
         TargetSpec(
             triple="x86_64-pc-windows-msvc",
             osarch="windows-x86_64",
             os_family="windows",
             arch="x86_64",
             cpython_platform="win32",
             object_format="pe",
             shared_prefix="",
             shared_suffix=".dll"
         )
     ];

def triple_osarch(triple: str) -> str;

def target_spec(name: str) -> TargetSpec;

def host_target_spec -> TargetSpec;
