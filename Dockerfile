# ---------------------------------------------------------------------------
# Everything the editor needs (Emacs, compilers, language servers, CLI tools)
# comes from flake.nix, pinned by flake.lock. The base image only supplies a
# glibc userland for Nix to bootstrap on — that also lets prebuilt binaries
# that expect a normal FHS layout (manylinux wheels, uv-managed Pythons) run.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

ENV LANG=C.UTF-8
ENV TERM=xterm-256color

# The only apt packages: what the Nix installer itself needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Non-root user matching the host UID/GID so bind mounts stay writable.
# Single-user Nix: /nix belongs to `editor`, so `nix develop`, `nix build`
# and direnv's `use flake` work in projects without a daemon or root.
# ---------------------------------------------------------------------------
ARG UID=1000
ARG GID=1000
RUN set -eux; \
    if ! getent group "$GID" >/dev/null; then groupadd -g "$GID" editor; fi; \
    useradd -m -s /bin/bash -u "$UID" -g "$GID" editor; \
    install -d -m 0755 -o "$UID" -g "$GID" /nix; \
    mkdir -p /etc/nix; \
    printf '%s\n' \
      'experimental-features = nix-command flakes' \
      'sandbox = false' \
      > /etc/nix/nix.conf; \
    # Debian's /etc/profile resets PATH, so login shells need it re-added.
    printf '%s\n' \
      'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/nix/var/nix/profiles/editor-env/bin:$HOME/.nix-profile/bin:$PATH"' \
      > /etc/profile.d/editor-env.sh

ENV USER=editor
ENV HOME=/home/editor
USER editor
WORKDIR /home/editor

ARG NIX_VERSION=2.35.2
ARG NIX_INSTALL_SHA256=9adda97297d9e8ab360df95c729eabff4f4f93d6db091953c3a68f29e3fb130c
RUN set -eux; \
    curl -fsSLo /tmp/nix-install "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install"; \
    echo "${NIX_INSTALL_SHA256}  /tmp/nix-install" | sha256sum -c -; \
    sh /tmp/nix-install --no-daemon --no-channel-add --no-modify-profile; \
    rm /tmp/nix-install

# The flake's buildEnv lives in its own profile, ahead of the installer's
# ~/.nix-profile (which only holds nix itself) on PATH.
ENV EDITOR_ENV=/nix/var/nix/profiles/editor-env
ENV PATH=/home/editor/.local/bin:/home/editor/.cargo/bin:${EDITOR_ENV}/bin:/home/editor/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin
ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV RUST_SRC_PATH=${EDITOR_ENV}/share/rust-src
# Have uv use the flake's Python rather than downloading its own.
ENV UV_PYTHON_PREFERENCE=only-system
ENV MANPATH=${EDITOR_ENV}/share/man:

COPY --chown=editor:editor flake.nix flake.lock /home/editor/.config/editor-env/
RUN set -eux; \
    nix build --profile "$EDITOR_ENV" /home/editor/.config/editor-env#default; \
    nix-collect-garbage; \
    emacs --version | head -1

# nix-direnv makes `use flake` in a project's .envrc cache its devShell.
RUN set -eux; \
    mkdir -p /home/editor/.config/direnv; \
    echo "source ${EDITOR_ENV}/share/nix-direnv/direnvrc" \
      > /home/editor/.config/direnv/direnvrc; \
    echo 'eval "$(direnv hook bash)"' >> /home/editor/.bashrc

# ---------------------------------------------------------------------------
# Doom Emacs, pinned to a commit. Its packages are still managed by
# straight.el and pinned by Doom itself; moving them into Nix too (see
# README.org) is the next step towards a fully reproducible image.
# ---------------------------------------------------------------------------
ARG DOOM_REV=59cdaa32ae933469bb6a1fb3cadee8a988c15968
RUN set -eux; \
    git init -q /home/editor/.config/emacs; \
    cd /home/editor/.config/emacs; \
    git remote add origin https://github.com/doomemacs/core; \
    git fetch -q --depth 1 origin "$DOOM_REV"; \
    git checkout -q FETCH_HEAD; \
    bin/doom install --no-env --no-config

COPY --chown=editor:editor doom-config/ /home/editor/.config/doom
RUN /home/editor/.config/emacs/bin/doom sync

CMD ["emacs", "-nw"]
