#!/usr/bin/env bash

comai_human_bytes() {
  local bytes="$1"
  if comai_have numfmt; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    printf '%s bytes' "$bytes"
  fi
}

comai_first_matching_entry() {
  local kind="$1"
  local order="$2"
  local type_args=()

  case "$kind" in
    file)
      type_args=(-type f)
      ;;
    directory)
      type_args=(-type d)
      ;;
  esac

  case "$order" in
    newest)
      find . -maxdepth 1 -mindepth 1 "${type_args[@]}" -printf '%T@\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null \
        | sort -k1,1nr \
        | head -n 1
      ;;
    oldest)
      find . -maxdepth 1 -mindepth 1 "${type_args[@]}" -printf '%T@\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null \
        | sort -k1,1n \
        | head -n 1
      ;;
    largest)
      find . -maxdepth 1 -mindepth 1 "${type_args[@]}" -printf '%T@\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null \
        | sort -k2,2nr \
        | head -n 1
      ;;
    smallest)
      find . -maxdepth 1 -mindepth 1 "${type_args[@]}" -printf '%T@\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null \
        | sort -k2,2n \
        | head -n 1
      ;;
  esac
}

comai_answer_local_file_fact() {
  local request="$1"
  local text kind="file" order="" label line _mtime size modified path

  text="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]')"

  if [[ "$text" == *directory* || "$text" == *directories* || "$text" == *folder* || "$text" == *folders* ]]; then
    kind="directory"
  fi

  case "$text" in
    *newest*|*latest*|*recent*)
      order="newest"
      label="newest"
      ;;
    *oldest*)
      order="oldest"
      label="oldest"
      ;;
    *biggest*|*largest*|*large*|*big-files*|*big\ files*)
      order="largest"
      label="largest"
      ;;
    *smallest*)
      order="smallest"
      label="smallest"
      ;;
    *)
      return 1
      ;;
  esac

  [[ "$text" == *file* || "$text" == *files* || "$kind" == "directory" ]] || return 1

  line="$(comai_first_matching_entry "$kind" "$order")"
  if [[ -z "$line" ]]; then
    printf 'No %s found in %s.\n' "$kind" "$PWD"
    return 0
  fi

  IFS=$'\t' read -r _mtime size modified path <<< "$line"
  printf 'The %s %s in %s is %s (%s, modified %s).\n' "$label" "$kind" "$PWD" "$path" "$(comai_human_bytes "$size")" "$modified"
}

comai_answer_file_contains() {
  local request="$1"
  local text needle file count

  [[ "${#FILES[@]}" -gt 0 ]] || return 1

  text="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]')"
  case "$text" in
    *see\ number\ *|*find\ number\ *|*has\ number\ *|*have\ number\ *|*contains\ number\ *)
      needle="$(printf '%s' "$text" | sed -nE 's/.*(see|find|has|have|contains)[[:space:]]+number[[:space:]]+([0-9]+).*/\2/p' | head -n 1)"
      ;;
    *see\ *|*find\ *|*contains\ *)
      needle=""
      ;;
    *)
      return 1
      ;;
  esac

  [[ -n "$needle" ]] || return 1

  for file in "${FILES[@]}"; do
    [[ -f "$file" && -r "$file" ]] || continue
    count="$(grep -F -- "$needle" "$file" 2>/dev/null | wc -l | tr -d '[:space:]')"
    if [[ "$count" -gt 0 ]]; then
      printf 'Yes. `%s` appears in %s on %s line(s).\n' "$needle" "$file" "$count"
      grep -nF -- "$needle" "$file" 2>/dev/null | head -5
    else
      printf 'No. `%s` was not found in %s.\n' "$needle" "$file"
    fi
    return 0
  done

  return 1
}

comai_answer_file_errors() {
  local request="$1"
  local text file count

  [[ "${#FILES[@]}" -gt 0 ]] || return 1

  text="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]')"
  if ! printf '%s\n' "$text" | grep -Eq 'error|errors|failed|failure|warning|warnings|problem|problems|issue|issues|wrong|bad|broken|fail|crash|crashed|panic|timeout|traceback|healthy|health|(^|[[:space:]])ok([[:space:]]|$)|okay|check (this )?log|scan (this )?log'; then
    return 1
  fi

  for file in "${FILES[@]}"; do
    [[ -f "$file" && -r "$file" ]] || continue

    count="$(grep -Ein "$COMAI_ERROR_RE" "$file" 2>/dev/null | wc -l | tr -d '[:space:]')"
    if [[ "$count" -eq 0 ]]; then
      printf 'No error, warning, failure, panic, timeout, or traceback lines were found in %s.\n' "$file"
    else
      printf 'Found %s possible issue line(s) in %s:\n' "$count" "$file"
      grep -Ein "$COMAI_ERROR_RE" "$file" 2>/dev/null | head -20
    fi
    return 0
  done

  return 1
}
