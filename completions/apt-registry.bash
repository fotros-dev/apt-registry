_apt_registry_completion() {
  local current_word=${COMP_WORDS[COMP_CWORD]}
  local subcommand=${COMP_WORDS[1]:-}
  local candidates=""
  if ((COMP_CWORD == 1)); then
    candidates="set get unset status upstreams version help"
  else
    case $subcommand in
      set) candidates="--dry-run --no-update --force" ;;
      unset) candidates="--dry-run --no-update" ;;
    esac
  fi
  mapfile -t COMPREPLY < <(compgen -W "$candidates" -- "$current_word")
}

complete -F _apt_registry_completion apt-registry
