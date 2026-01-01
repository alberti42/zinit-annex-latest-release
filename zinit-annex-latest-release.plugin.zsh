# zinit-annex-latest-release.zsh
#
# Andrea Alberti (2025)
# License: MIT

@zinit-register-annex "zinit-annex-latest-release" \
  hook:\!atclone-10 \
  ".za_force_latest_release_atclone_hook" \
  ".za_force_latest_release_help" \
  "latest-release"

@zinit-register-hook "zinit-annex-latest-release-atpull" \
  hook:e-\!atpull-pre \
  ".za_force_latest_release_atpull_hook" \
  "latest-release"

# -------- hooks --------

.za_force_latest_release_atpull_hook() {
  builtin emulate -LR zsh
  builtin setopt nobanghist typesetsilent

  # args: plugin user plugin id_as local_path hook subtype
  local kind="$1" user="$2" plugin="$3" id_as="$4" local_path="${5#%}" hook="$6" subtype="$7"

  (( ${+ICE[latest-release]} )) || return 0
  
  .za_force_latest_release__resolve_and_store "$@" pull
}

.za_force_latest_release_atclone_hook() {
  builtin emulate -LR zsh
  builtin setopt nobanghist typesetsilent

  (( ${+ICE[latest-release]} )) || return 0

  .za_force_latest_release__resolve_and_store "$@" clone
}

.za_force_latest_release__resolve_and_store() {
  builtin emulate -LR zsh
  builtin setopt nobanghist typesetsilent

  local kind="$1" user="$2" plugin="$3" id_as="$4" local_path="${5#%}" hook="$6" subtype="$7" action="$8"

  local tag_version="" payload="" api_msg=""

  # --- Try GitHub API first ---
  local api_url="https://api.github.com/repos/${user}/${plugin}/releases/latest"
  payload="$({ .zinit-download-file-stdout "$api_url" || .zinit-download-file-stdout "$api_url" 1; } 2>/dev/null)"

  tag_version="$(
    builtin print -r -- "$payload" |
      command grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]\+"' |
      command grep -o '"[^"]*"$' |
      command tr -d '"'
  )"

  api_msg="$(
    builtin print -r -- "$payload" |
      command grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]\+"' |
      command grep -o '"[^"]*"$' |
      command tr -d '"'
  )"

  # --- Fallback: GitHub HTML ---
  if [[ -z $tag_version ]]; then
    local releases_url="https://github.com/${user}/${plugin}/releases/latest"
    payload="$({ .zinit-download-file-stdout "$releases_url" || .zinit-download-file-stdout "$releases_url" 1; } 2>/dev/null)"

    tag_version="$(
      builtin print -r -- "$payload" |
        command grep -m1 -Eo '/releases/tag/[^"'"'"' <>\t]+' |
        command sed 's|^/releases/tag/||'
    )"
  fi

  if [[ -z $tag_version ]]; then
    if [[ -n $api_msg ]]; then
      +zi-log -- "{u-warn}Warning{b-warn}:{rst} {obj}latest-release{rst}: cannot determine latest tag for {obj}${user}/${plugin}{rst} (API: {obj}${api_msg}{rst})."
    else
      +zi-log -- "{u-warn}Warning{b-warn}:{rst} {obj}latest-release{rst}: cannot determine latest tag for {obj}${user}/${plugin}{rst} (API/HTML parse failed or rate-limited)."
    fi
    return 0
  fi

  case "$action" in
  clone)
    # Only ICE is guaranteed here
    if [[ -n ${ICE[ver]-} && ${ICE[ver]} != "$tag_version" ]]; then
      +zi-log -- "{u-warn}Warning{b-warn}:{rst} {obj}latest-release{rst}: overriding {obj}ver=${ICE[ver]}{rst} with {obj}${tag_version}{rst} for {obj}${user}/${plugin}{rst}."
    fi
    
    # tag_version="v1.4.5" # <- for debug purpose, overwrite
    ICE[ver]="$tag_version"

    command git -C "$local_path" fetch --tags --force --quiet 2>/dev/null
    command git -C "$local_path" -c advice.detachedHead=false switch --detach --quiet "$tag_version" 2>/dev/null \
      || command git -C "$local_path" -c advice.detachedHead=false checkout --detach --quiet "$tag_version"
    ;;
  pull)
    # What is currently checked out?
    local current_tag=""
    current_tag="$(command git -C "$local_path" describe --tags --exact-match 2>/dev/null)"

    # If not exactly at a tag, use HEAD sha (still useful for "changed?" decisions)
    local current_sha=""
    (( $? )) && current_sha="$(command git -C "$local_path" rev-parse --short HEAD 2>/dev/null)"

    # Set the desired version for this update run
    ICE[ver]="$tag_version"
    ice[ver]="$tag_version"

    if [[ -n $current_tag && $current_tag == "$tag_version" ]]; then
      # Already at the desired tag      
      ZINIT[annex-multi-flag:pull-active]=0
      return 0
    fi

    # Not at the desired tag → force the pull stage (and later you still need a post-step to checkout tag)
    ZINIT[annex-multi-flag:pull-active]=2
    +zi-log -- "{info}latest-release{rst}: current={obj}${current_tag:-$current_sha}{rst} → target={obj}${tag_version}{rst} for {obj}${user}/${plugin}{rst}; forcing update."
    ;;
  esac

  # Persist for subsequent steps (Zinit stores before hooks)
  .zinit-store-ices "$local_path/._zinit" ICE "" "" "" ""

  return 0
}

.za_force_latest_release_help() {
  builtin print -r -- \
"latest-release
  Select the latest GitHub release tag and assign it to ice[ver].

  Behaviour:
  - On install (clone): runs when ICE[latest-release] is present and drops a marker:
      <plugin-dir>/._zinit/latest-release
  - On update (pull): ICEs are reloaded from disk and the marker decides whether
    latest-release should run for that plugin.

  Resolution order:
    1) GitHub API:  /repos/<user>/<repo>/releases/latest  (reads tag_name)
    2) HTML page:   https://github.com/<user>/<repo>/releases/latest (parses /releases/tag/<tag>)

  If the tag can't be determined, it logs a warning and leaves ice[ver] unchanged."
}
