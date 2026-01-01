# Zinit Annex for Sourcing the Latest GitHub Release

**Zinit annex that automatically selects the latest GitHub release tag when installing or updating plugins built from source.**

This annex introduces a new ICE modifier, **`latest-release`**, which resolves the most recent GitHub release tag and assigns it to `ice[ver]`.  It is especially useful when **no prebuilt binaries are available** and compiling from source is required, while still ensuring that the checked-out code corresponds to a **stable, released version**.

---

## Motivation

Many GitHub projects:

- provide precompiled binaries only for selected platforms, or
- require compilation from source on some systems (e.g. macOS), and
- keep `HEAD` moving in ways that may temporarily break builds.

Zinit already supports version pinning via `ice[ver]`, but determining the *latest* release tag dynamically is non-trivial. This annex fills that gap by automatically resolving the latest GitHub release and enforcing it during both **clone** and **pull** phases.

---

## Features

- 🔖 Resolves the **latest GitHub release tag**
- 🔁 Works on both **install (`clone`)** and **update (`pull`)**
- 🧠 Automatically sets `ice[ver]` for the current Zinit run
- 🔒 Ensures reproducible builds from **stable release tags**
- 🌐 Uses GitHub API with HTML fallback
- 📦 Designed for **source-based installs** (e.g. `make && make install`)

---

## Installation

Install the annex like any other Zinit annex:

```zsh
zinit light @alberti42/zinit-annex-latest-release
```

---

## Usage

Enable the annex by adding the `latest-release` ICE modifier to a plugin.

### Example: `btop` on macOS (build from source)

```zsh
() {
  local -a _ices
  _ices+=(
    nocompile        # No zsh scripts to compile
    lucid            # Show hook output
    null             # Don't source files automatically
    wait'0'          # Background install
  )

  if [[ $OSTYPE == darwin* ]]; then
    _ices+=(
      atclone'
        command env QUIET=true \
          CXXFLAGS="-Wno-deprecated-declarations -Wno-unused-command-line-argument -Wno-unused-private-field" \
          command make -j${(n)NPROCS:-8} &&
        command make install PREFIX="$ZPFX"
      ' # Compilation instructions
      atpull'%atclone'  
      latest-release   # <= The new ICE, which sources the latest release
    )
  fi

  zinit ice "${_ices[@]}"
  zinit light aristocratos/btop
}
```

On macOS, this ensures:

- the **latest release tag** is checked out
- the code is built from a known-good release
- updates only occur when a *new release* is published

On Linux, you might still prefer `from"gh-r"` with prebuilt binaries.

---

## How It Works

When `latest-release` is present:

### Resolution order

1. **GitHub API**  
   ```
   https://api.github.com/repos/<user>/<repo>/releases/latest
   ```
   Reads the `tag_name` field.

2. **GitHub HTML fallback**  
   ```
   https://github.com/<user>/<repo>/releases/latest
   ```
   Parses `/releases/tag/<tag>` from the page.

If both methods fail, a warning is logged and `ice[ver]` is left unchanged.

---

### Clone phase (`atclone`)

- Resolves the latest release tag
- Overrides any existing `ice[ver]`
- Fetches tags and checks out the resolved tag in detached HEAD state
- Persists ICEs so later hooks see the same version

---

### Pull phase (`atpull`)

- Compares the currently checked-out tag (or commit) with the latest release
- If already up-to-date, the update is skipped
- Otherwise, forces the pull stage and updates `ice[ver]`
- Ensures rebuild hooks (e.g. `atpull`) run only when a new release exists

---

## When Should You Use This?

✅ Recommended when:

- You must **compile from source**
- The project uses **GitHub releases**
- You want **stable, release-based updates**
- You do *not* want to track `HEAD`

❌ Probably unnecessary when:

- You use `from"gh-r"` with prebuilt binaries
- The project has no releases
- You explicitly want to track a branch

---

## Limitations & Notes

- Only supports **GitHub-hosted repositories**
- Requires `git` and network access during install/update
- Does not currently support prereleases (by design)

---

## License

MIT License  
© 2025 Andrea Alberti

---

## Acknowledgements

Built for and inspired by the internals of **[Zinit](https://github.com/zdharma-continuum/zinit)** and its annex system.
