{
  description = "Toolchain for the dockerised Doom Emacs editor";

  # Bump with `nix flake update`; flake.lock pins the exact nixpkgs commit,
  # so every image build gets the same Emacs, compilers and language servers.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          # vterm's native module comes prebuilt from nixpkgs; packages.el
          # tells straight to prefer this copy instead of compiling its own.
          emacs = (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages (epkgs: [ epkgs.vterm ]);

          # Interpreter that :lang python, :tools ein and uv default to.
          # Project dependencies belong in each project's own uv venv or flake.
          python = pkgs.python3.withPackages (ps: [
            ps.pytest
            ps.jupyterlab
          ]);
        in
        {
          default = pkgs.buildEnv {
            name = "editor-env";
            paths = with pkgs; [
              emacs

              # Core CLI: Doom (vertico, projectile, lookup), magit/forge, vterm.
              git
              openssh
              ripgrep
              fd
              fzf
              jq
              sqlite
              coreutils
              findutils
              diffutils
              gnugrep
              gnused
              gawk
              gnutar
              gzip
              xz
              unzip
              zip
              less
              file
              tree
              procps
              htop
              which
              man

              # Per-project flakes: `use flake` in an .envrc, picked up by
              # :tools direnv.
              direnv
              nix-direnv
              nil
              nixfmt

              # C/C++ (:lang cc +lsp, :tools debugger). gcc provides cc/c++;
              # clang-tools provides clangd and clang-format.
              gcc
              clang-tools
              cmake
              ninja
              gnumake
              pkg-config
              gdb
              lldb
              valgrind

              # Rust (:lang rust +lsp). RUST_SRC_PATH points at share/rust-src
              # below so rust-analyzer can index std.
              rustc
              cargo
              rust-analyzer
              clippy
              rustfmt

              # Python (:lang python, :tools ein).
              python
              uv
              ruff
              pyright

              # :lang sh, :lang yaml, :editor format.
              shellcheck
              shfmt
              bash-language-server
              yaml-language-server
              prettier

              # :tools llm (acp / agent-shell) needs a current Node.
              nodejs_22
            ];
            postBuild = ''
              ln -s ${pkgs.rustPlatform.rustLibSrc} $out/share/rust-src
            '';
          };
        }
      );
    };
}
