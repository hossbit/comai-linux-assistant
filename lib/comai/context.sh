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
    *here* | *current\ director* | *this\ director* | *this\ folder* | *this\ repo* | *this\ project* | *project\ files* | *repo\ files* | *list\ files* | *show\ files* | *newest\ file* | *largest\ file* | *biggest\ file*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

comai_directory_context_raw() {
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
  [[ "${#FILES[@]}" -gt 0 ]] || return 0
  local file size shown mime header excerpt remaining="${COMAI_CONTEXT_REMAINING:-${COMAI_INPUT_MAX_BYTES:-96000}}" bytes
  for file in "${FILES[@]}"; do
    [[ -f "$file" && -r "$file" ]] || { comai_error "context omitted: unreadable file $file"; continue; }
    size="$(stat -c '%s' -- "$file")" || continue
    mime='unknown'
    comai_have file && mime="$(file --mime-type -b -- "$file")"
    case "$mime" in text/*|application/json|application/xml|application/x-sh|unknown) ;;
      *) comai_error "context omitted: binary file $file"; continue ;; esac
    header="$(printf '\nFile: %s (%s bytes, %s)\n' "$file" "$size" "$mime")"$'\n'
    bytes="$(LC_ALL=C printf '%s' "$header" | wc -c)"
    shown=$((remaining - bytes - 1))
    (( shown > 0 )) || { comai_error "context omitted: $file (aggregate input budget)"; continue; }
    (( shown <= COMAI_FILE_MAX_BYTES )) || shown="$COMAI_FILE_MAX_BYTES"
    (( shown <= size )) || shown="$size"
    if [[ "${COMAI_CONTEXT_TAIL:-0}" == 1 ]]; then excerpt="$(tail -c "$shown" -- "$file")"
    else excerpt="$(head -c "$shown" -- "$file")"; fi
    printf '%s%s\n' "$header" "$excerpt"
    bytes="$(LC_ALL=C printf '%s%s\n' "$header" "$excerpt" | wc -c)"
    remaining=$((remaining - bytes))
    (( shown >= size )) || comai_error "context truncated: $file ($shown of $size bytes; tail=${COMAI_CONTEXT_TAIL:-0})"
  done
}

comai_directory_context() {
  local limit=$(( ${COMAI_INPUT_MAX_BYTES:-96000} / 4 )) excerpt bytes
  excerpt="$(comai_directory_context_raw | head -c "$((limit + 1))" || true; printf '.')"
  excerpt="${excerpt%.}"
  bytes="$(LC_ALL=C printf '%s' "$excerpt" | wc -c)"
  if (( bytes > limit )); then
    comai_error "directory context: omitted listing bytes after $limit (aggregate budget)"
    printf '%s' "$excerpt" | head -c "$limit"
  else printf '%s' "$excerpt"; fi
}
