#!/usr/bin/env bash

# Keep model-specific behavior here. The main script stays generic.
comai_model_is_coder() {
  [[ "${COMAI_MODEL,,}" == *coder* ]]
}

comai_model_note() {
  if comai_model_is_coder; then
    return 0
  fi
  return 0
}
