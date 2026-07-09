#!/usr/bin/env bash

comai_have() {
  command -v "$1" > /dev/null 2>&1
}

comai_yaml_value() {
  local key="$1"
  local file="$2"

  [[ -f "$file" ]] || return 1
  LC_ALL=C awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
    }
    line ~ "^" key "[[:space:]]*:" {
      value = substr(line, index(line, ":") + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      found = 1
      exit 0
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$file"
}

comai_yaml_provider_value() {
  local provider="$1"
  local key="$2"
  local file="$3"

  [[ -f "$file" ]] || return 1
  LC_ALL=C awk -v provider="$provider" -v key="$key" '
    /^[^[:space:]#][^:]*:/ {
      in_providers = ($0 ~ /^providers[[:space:]]*:/)
      in_provider = 0
    }
    in_providers && $0 ~ "^[[:space:]][[:space:]]" provider "[[:space:]]*:" {
      in_provider = 1
      next
    }
    in_provider && $0 ~ "^[[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:" {
      in_provider = 0
    }
    in_provider {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ "^" key "[[:space:]]*:") {
        value = substr(line, index(line, ":") + 1)
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        print value
        found = 1
        exit 0
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$file"
}

comai_yaml_config_values() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  LC_ALL=C awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function emit(key, value) {
      print key "\t" trim(value)
    }
    /^[[:space:]]*($|#)/ {
      next
    }
    /^[^[:space:]#][^:]*:/ {
      line = $0
      key = trim(substr(line, 1, index(line, ":") - 1))
      value = substr(line, index(line, ":") + 1)
      in_providers = (key == "providers")
      provider = ""
      if (key != "providers") {
        emit(key, value)
      }
      next
    }
    in_providers && $0 ~ "^[[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:" {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      provider = trim(substr(line, 1, index(line, ":") - 1))
      next
    }
    in_providers && provider != "" && $0 ~ "^[[:space:]][[:space:]][[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:" {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      key = trim(substr(line, 1, index(line, ":") - 1))
      value = substr(line, index(line, ":") + 1)
      emit("provider_" provider "_" key, value)
    }
  ' "$file"
}
