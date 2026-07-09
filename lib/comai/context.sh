#!/usr/bin/env bash

declare -g -A COMAI_FILES_SEEN 2> /dev/null || declare -A COMAI_FILES_SEEN 2> /dev/null || true

comai_clean_path_token() {
  local token="$1"
  token="${token#\`}"
  token="${token%\`}"
  token="${token#\"}"
  token="${token%\"}"
  token="${token#\'}"
  token="${token%\'}"
  token="${token%,}"
  token="${token%.}"
  token="${token%\?}"
  token="${token%:}"
  token="${token%;}"
  printf '%s' "$token"
}

comai_add_file_once() {
  local file="$1"

  [[ -z "${COMAI_FILES_SEEN[$file]+set}" ]] || return 0

  FILES+=("$file")
  COMAI_FILES_SEEN["$file"]=1
}

comai_detect_mentioned_files() {
  local arg text word candidate entry name i j phrase
  local tokens=()

  [[ "${COMAI_PROVIDER:-local}" == "local" ]] || return 0
  text="$(comai_join_args "${REQUEST_ARGS[@]}")"

  for arg in "${REQUEST_ARGS[@]}"; do
    read -r -a PARTS <<< "$arg"
    for word in "${PARTS[@]}"; do
      candidate="$(comai_clean_path_token "$word")"
      [[ -n "$candidate" ]] || continue
      tokens+=("$candidate")
      [[ "$candidate" == -* ]] && continue
      if [[ -f "$candidate" ]]; then
        comai_add_file_once "$candidate"
      fi
    done
  done

  for ((i = 0; i < ${#tokens[@]}; i++)); do
    phrase=""
    for ((j = i; j < ${#tokens[@]} && j < i + 8; j++)); do
      if [[ -z "$phrase" ]]; then
        phrase="${tokens[$j]}"
      else
        phrase="${phrase} ${tokens[$j]}"
      fi
      [[ "$phrase" == -* ]] && continue
      if [[ -f "$phrase" ]]; then
        comai_add_file_once "$phrase"
      elif [[ -f "./$phrase" ]]; then
        comai_add_file_once "./$phrase"
      fi
    done
  done

  while IFS= read -r entry; do
    name="${entry#./}"
    [[ "$name" == "$entry" ]] && name="${entry##*/}"
    [[ "$name" == *" "* ]] || continue
    case "$text" in
      *"$name"* | *"$entry"*)
        comai_add_file_once "$entry"
        ;;
    esac
  done < <(find . -maxdepth 1 -type f -print 2> /dev/null)
}

comai_wants_directory_context() {
  local text="${1,,}"

  case "$text" in
    *here* | *current\ director* | *this\ director* | *this\ folder* | *this\ repo* | *this\ project* | *in\ this\ project* | *in\ this\ repo* | *project\ files* | *repo\ files* | *list\ files* | *show\ files* | *newest\ file* | *largest\ file* | *biggest\ file* | *files\ here* | *scripts\ here* | *logs\ here*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

comai_directory_context() {
  local limit="$COMAI_DIR_CONTEXT_MAX"

  printf 'Current directory context:\n'
  printf 'PWD: %s\n' "$PWD"
  printf 'Entries, newest first. Columns: modified_time bytes kind path\n'

  if find . -maxdepth 1 -mindepth 1 -printf '%T@ %TY-%Tm-%Td %TH:%TM %.0s%s %y %p\n' 2> /dev/null |
    sort -nr |
    head -n "$limit" |
    sed -E 's/^[0-9.]+ //'; then
    :
  else
    printf '[Directory listing unavailable]\n'
  fi
}

comai_file_context() {
  local file size shown mime

  [[ "${#FILES[@]}" -gt 0 ]] || return 0

  printf 'File context:\n'
  for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      printf '\n--- %s ---\n[File not found]\n' "$file"
      continue
    fi

    if [[ ! -r "$file" ]]; then
      printf '\n--- %s ---\n[File is not readable]\n' "$file"
      continue
    fi

    size="$(wc -c < "$file" | tr -d '[:space:]')"
    shown="$size"
    if [[ "$size" -gt "$COMAI_FILE_MAX_BYTES" ]]; then
      shown="$COMAI_FILE_MAX_BYTES"
    fi

    mime=""
    if comai_have file; then
      mime="$(file -b --mime-type "$file" 2> /dev/null || true)"
    fi

    printf '\n--- %s (%s bytes' "$file" "$size"
    [[ -n "$mime" ]] && printf ', %s' "$mime"
    printf ') ---\n'

    if [[ -n "$mime" && "$mime" != text/* && "$mime" != application/json && "$mime" != application/xml && "$mime" != application/x-sh ]]; then
      printf '[Binary or non-text file; content not included]\n'
      continue
    fi

    head -c "$shown" "$file" 2> /dev/null || true
    if [[ "$size" -gt "$COMAI_FILE_MAX_BYTES" ]]; then
      printf '\n[Truncated after %s bytes]\n' "$COMAI_FILE_MAX_BYTES"
    fi
    printf '\n'
  done
}
