#!/usr/bin/env bash

comai_parse_args() {
  local arg next_is_file=0 next_is_model=0 next_is_api_base=0 next_is_max_tokens=0 next_is_command=0

  REQUEST_ARGS=()
  FILES=()

  while [[ "$#" -gt 0 ]]; do
    arg="$1"

    if [[ "$next_is_file" -eq 1 ]]; then
      FILES+=("$arg")
      next_is_file=0
      shift
      continue
    fi

    if [[ "$next_is_model" -eq 1 ]]; then
      COMAI_MODEL="$arg"
      next_is_model=0
      shift
      continue
    fi

    if [[ "$next_is_api_base" -eq 1 ]]; then
      COMAI_API_BASE="$arg"
      next_is_api_base=0
      shift
      continue
    fi

    if [[ "$next_is_max_tokens" -eq 1 ]]; then
      COMAI_MAX_TOKENS="$arg"
      next_is_max_tokens=0
      shift
      continue
    fi

    if [[ "$next_is_command" -eq 1 ]]; then
      REQUEST_ARGS+=("$arg")
      next_is_command=0
      shift
      continue
    fi

    case "$arg" in
      --model=*)
        COMAI_MODEL="${arg#--model=}"
        ;;
      --model|-m)
        next_is_model=1
        ;;
      --api-base=*)
        COMAI_API_BASE="${arg#--api-base=}"
        ;;
      --api-base)
        next_is_api_base=1
        ;;
      --max-tokens=*)
        COMAI_MAX_TOKENS="${arg#--max-tokens=}"
        ;;
      --max-tokens)
        next_is_max_tokens=1
        ;;
      --file=*|--files=*|-f=*)
        FILES+=("${arg#*=}")
        ;;
      --file|--files|-f)
        next_is_file=1
        ;;
      --command=*)
        REQUEST_ARGS+=("${arg#--command=}")
        ;;
      --command|-command|-c)
        next_is_command=1
        ;;
      --local)
        ;;
      --local=*)
        REQUEST_ARGS+=("${arg#--local=}")
        ;;
      *)
        REQUEST_ARGS+=("$arg")
        ;;
    esac
    shift
  done

  if [[ "$next_is_file" -eq 1 ]]; then
    comai_error "missing path after --file/-f"
    return 1
  fi
  if [[ "$next_is_model" -eq 1 ]]; then
    comai_error "missing model after --model"
    return 1
  fi
  if [[ "$next_is_api_base" -eq 1 ]]; then
    comai_error "missing URL after --api-base"
    return 1
  fi
  if [[ "$next_is_max_tokens" -eq 1 ]]; then
    comai_error "missing number after --max-tokens"
    return 1
  fi
  if [[ "$next_is_command" -eq 1 ]]; then
    comai_error "missing command text after --command"
    return 1
  fi
}
