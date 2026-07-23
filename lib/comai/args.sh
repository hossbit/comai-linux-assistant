#!/usr/bin/env bash

comai_validate_max_tokens() {
  local value="$1"

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    comai_error "--max-tokens must be a positive integer."
    return 1
  fi
}

comai_parse_args() {
  local arg provider_flag next_is_file=0 next_is_model=0 next_is_api_base=0 next_is_provider=0 next_is_max_tokens=0 next_is_command=0 literal_args=0

  REQUEST_ARGS=()
  FILES=()

  while [[ "$#" -gt 0 ]]; do
    arg="$1"

    if [[ "$literal_args" -eq 1 ]]; then
      REQUEST_ARGS+=("$arg")
      shift
      continue
    fi

    if [[ "$next_is_file" -eq 1 ]]; then
      FILES+=("$arg")
      next_is_file=0
      shift
      continue
    fi

    if [[ "$next_is_model" -eq 1 ]]; then
      COMAI_MODEL="$arg"
      COMAI_MODEL_EXPLICIT=1
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

    if [[ "$next_is_provider" -eq 1 ]]; then
      if ! comai_provider_select "$arg"; then
        comai_error "unknown provider: $arg"
        return 1
      fi
      next_is_provider=0
      shift
      continue
    fi

    if [[ "$next_is_max_tokens" -eq 1 ]]; then
      comai_validate_max_tokens "$arg" || return 1
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
      gpt | chatgpt)
        if [[ "${#REQUEST_ARGS[@]}" -eq 0 ]]; then
          comai_provider_select openai
        else
          REQUEST_ARGS+=("$arg")
        fi
        ;;
      --gpt | --chatgpt)
        comai_provider_select openai
        ;;
      opr)
        if [[ "${#REQUEST_ARGS[@]}" -eq 0 ]]; then
          comai_provider_select openrouter
        else
          REQUEST_ARGS+=("$arg")
        fi
        ;;
      --opr | --openrouter)
        comai_provider_select openrouter
        ;;
      --provider=*)
        provider_flag="${arg#--provider=}"
        if ! comai_provider_select "$provider_flag"; then
          comai_error "unknown provider: $provider_flag"
          return 1
        fi
        ;;
      --provider)
        next_is_provider=1
        ;;
      --model=*)
        COMAI_MODEL="${arg#--model=}"
        COMAI_MODEL_EXPLICIT=1
        ;;
      --model | -m)
        next_is_model=1
        ;;
      --api-base=*)
        COMAI_API_BASE="${arg#--api-base=}"
        ;;
      --api-base)
        next_is_api_base=1
        ;;
      --max-tokens=*)
        comai_validate_max_tokens "${arg#--max-tokens=}" || return 1
        COMAI_MAX_TOKENS="${arg#--max-tokens=}"
        ;;
      --max-tokens)
        next_is_max_tokens=1
        ;;
      --)
        literal_args=1
        ;;
      --file=* | --files=* | -f=*)
        FILES+=("${arg#*=}")
        ;;
      --file | --files | -f)
        next_is_file=1
        ;;
      --command=*)
        REQUEST_ARGS+=("${arg#--command=}")
        ;;
      --command | -command | -c)
        next_is_command=1
        ;;
      --local=*)
        REQUEST_ARGS+=("${arg#--local=}")
        ;;
      --*)
        provider_flag="${arg#--}"
        provider_flag="${provider_flag//-/_}"
        if [[ "$provider_flag" == "lm_studio" ]]; then
          provider_flag="lmstudio"
        fi
        if comai_provider_exists "$provider_flag"; then
          comai_provider_select "$provider_flag"
        else
          REQUEST_ARGS+=("$arg")
        fi
        ;;
      *)
        if [[ "${#REQUEST_ARGS[@]}" -eq 0 ]] && comai_provider_exists "$arg"; then
          comai_provider_select "$arg"
        elif [[ "${#REQUEST_ARGS[@]}" -eq 0 && "$arg" == "lm-studio" ]]; then
          comai_provider_select lmstudio
        else
          REQUEST_ARGS+=("$arg")
        fi
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
  if [[ "$next_is_provider" -eq 1 ]]; then
    comai_error "missing provider after --provider"
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
