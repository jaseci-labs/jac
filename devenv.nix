{ pkgs, ... }:

{
  # Toolchain for `bash scripts/fresh_env.sh` (the -Ddev jac build).
  #
  # - zig 0.16.0 drives the whole build; version pinned in build.zig.
  # - glibc.dev is needed because -Ddev links a pinned neovim fork as a
  #   static library (see jac/build.zig), which pulls in the nlua0 host
  #   tool that compiles C. Zig's bundled clang doesn't see libc headers
  #   on NixOS, so we expose glibc via CPATH below.
  packages = [
    pkgs.zig
    pkgs.glibc.dev
  ];

  env.CPATH = "${pkgs.glibc.dev}/include";

  enterShell = ''
    zig version >/dev/null 2>&1 && echo "zig $(zig version) ready — run: bash scripts/fresh_env.sh"
  '';
}
