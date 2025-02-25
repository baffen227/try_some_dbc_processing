# Cf: https://nixos.wiki/wiki/Rust

# Variable and Imports definition
let
  # Import overlay to install specific Rust versions
  rust_overlay = import (fetchTarball
    "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");

  # Import the 24.05 stable Nixpkgs library
  # `import` and `fetchTarball` are both attributes of the `builtins` set that are also available in the global scope.
  # Hence instead of writing `builtins.fetchTarball` we can write `fetchTarball`
  # However `fetchurl` isn't in the global scope.
  pkgs = import
    (fetchTarball "https://github.com/nixos/nixpkgs/tarball/nixos-24.11")
    {
      overlays = [ rust_overlay ];
    };
  # # We could specify the Rust version manually like this, however we use a nice helper to import from our `rust-toolchain.toml` file
  #   rustChannel = "nightly";
  #   rustVersion = "latest";
  #   #rustVersion = "1.62.0";
  #   rust = pkgs.rust-bin.${rustChannel}.${rustVersion}.default.override {
  #     extensions = [
  #       "rust-src" # for rust-analyzer
  #       "rust-analyzer"
  # 	  "cargo"
  # 	  "rustc"
  # 	  "rustfmt"
  # 	  "clippy"
  # 	  "rust-docs"
  # 	  "miri"
  #     ];
  # 	targets = [
  # 		"x86_64-unknown-linux-gnu"
  # 		"wasm32-unknown-unknown"
  # 		"aarch64-unknown-linux-gnu"
  # 	];
  #   };

  # After importing the nixpkgs and applying the rust overlay we can customize our rust installation
  rust = (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml);

  # Put pkgs into scope
in
with pkgs;

# If an issue occur with the cross-compiler, we might have to search and try this again
# https://github.com/oxalica/rust-overlay/issues/87
# pkgs.callPackage (
# 	{ mkShell, stdenv }:

# Shell session Creation (with the build tooling necessary for our project)
# We could use `mkShell rec {` if needed to reference attributes created in the same set
mkShell {
  nativeBuildInputs = [
    pkg-config
    diesel-cli
    rust
    # Install this on your OS if you need VsCode Rust Analyzer to use clippy instead of cargo check
    #  Use the following setting in your VsCode if you want clippy to check your code on save:
    # "rust-analyzer.check.overrideCommand": [
    #    "cargo-clippy",
    #    "--workspace",
    #    "--message-format=json",
    #    "--all-targets"
    #],
    clippy
    cargo-make
    trunk
    # (trunk.overrideAttrs (oldAttrs: rec {
    #   version = "0.21.3";
    #   src = fetchFromGitHub {
    #     owner = "trunk-rs";
    #     repo = "trunk";
    #     rev = "v${version}";
    #     hash = "sha256-IRLXn6Z1HYHJiJs6qIa+A2Dwm8rx/7DuJnCoZYInWf0=";
    #   };
    #   cargoDeps = oldAttrs.cargoDeps.overrideAttrs (lib.const {
    #     name = "trunk-vendor.tar.gz";
    #     inherit src;
    #     outputHash = "sha256-yZ/7LShTcTW6VeP/hRubPIq7B86sEBIywwjuIvWgDgM=";
    #   });
    # }))
    dart-sass
    # # If the need comes, we can specify a specific version of the `dart-sass`. It has to be the same as in the `Trunk.toml`
    # (unstable_pkgs.dart-sass.overrideAttrs rec {
    #   version = "1.50.0";
    #   pname = "dart-sass";
    #   src = fetchFromGitHub {
    #     owner = "sass";
    #     repo = pname;
    #     rev = version;
    #     hash = "sha256-giiSj5tjr3F4Uu9GsJQIDE9hBXi4HBVJmdEBuhIjZi4=";
    #   };
    # })
    wasm-bindgen-cli
    # (wasm-bindgen-cli.override {
    #   version = "0.2.92";
    #   hash = "sha256-1VwY8vQy7soKEgbki4LD+v259751kKxSxmo/gqE6yV0=";
    #   cargoHash = "sha256-aACJ+lYNEU8FFBs158G1/JG8sc6Rq080PeKCMnwdpH0=";
    # })
    cargo-zigbuild
    cargo-cache
    cargo-tarpaulin
    cargo-nextest
    cargo-flamegraph
    typos
    cargo-udeps
    cargo-audit
    cargo-edit
    # Embedded
    flip-link
    # Embedded Debugging
    # On NixOs, also set:
    # services.udev.packages = [ pkgs.openocd ];
    # and
    #
    #{
    #    #probe-rs.probe-rs-debugger
    #    name = "probe-rs-debugger";
    #    publisher = "probe-rs";
    #    version = "0.24.1";
    #    sha256 = "sha256-Fb5a+sU+TahjhMTSCTg3eqKfjYMlrmbKyyD47Sr8qJY=";
    #}
    # in vscode-utils.extensionsFromVscodeMarketplace
    probe-rs
    # To use lld
    llvmPackages.bintools
  ];
  # Rust Cross-compilation issue https://github.com/oxalica/rust-overlay/issues/59
  depsHostHostPropagated = [
    # Only if you need to build the database/webserver for the PI
    #pkgs.pkgsCross.aarch64-multiplatform.postgresql
    # https://github.com/oxalica/rust-overlay/blob/master/docs/cross_compilation.md
    # https://github.com/oxalica/rust-overlay/blob/master/docs/cross_compilation.md
    # TODO: use binutils instead?
    pkgsCross.aarch64-multiplatform.stdenv.cc
    pkgsCross.armv7l-hf-multiplatform.stdenv.cc
    # Here order does matter, as the latest linker will be the one overriding the env vars like CC etc..
    stdenv.cc

  ];
  buildInputs = [
    patchelf
    fontconfig
    postgresql
    # Need to wait before getting libpq static build support
    # https://github.com/NixOS/nixpkgs/issues/61580
    # https://github.com/NixOS/nixpkgs/issues/191920
    # pkgsStatic.postgresql.libpq
  ];

  LIBCLANG_PATH = "${libclang.lib}/lib";
  RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";

  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER =
    let inherit (pkgsCross.aarch64-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER =
    let inherit (pkgsCross.aarch64-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CC_armv7_unknown_linux_gnueabihf =
    let inherit (pkgsCross.armv7l-hf-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CC_armv7_unknown_linux_musleabihf =
    let inherit (pkgsCross.armv7l-hf-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CC_aarch64_unknown_linux_musl =
    let inherit (pkgsCross.aarch64-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER =
    let inherit (pkgsCross.armv7l-hf-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABIHF_LINKER =
    let inherit (pkgsCross.armv7l-hf-multiplatform.stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER =
    let inherit (stdenv) cc;
    in "${cc}/bin/${cc.targetPrefix}cc";

  # Setting env var here can be tricky as sometimes Nix will override those in the previous package imports.
  # For common var like CC etc, please set them in the shellHook.

}
