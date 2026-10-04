# comai 2.10.0

- Add `doctor --json` with safe, differentiated provider and model health diagnostics.
- Bound aggregate file, directory, stdin and request context; disclose omitted excerpts and add `--tail-context` for logs.
- Run shared privacy, provider and input contracts against both editions, plus real local Git update/rollback fixtures.
- Resolve updates to immutable commits, preview targets, require archive checksums and retain rollback snapshots.

# ComAI 2.9.0


- Add `context` to preview local file/directory input without calling a model.
- Apply cloud-context consent to directory listings as well as files.
- Preserve update failure exit codes and stop false success messages.
- Validate local HTTP URL authorities, including IPv6 loopback.
- Add regression coverage and make local tests independent of the running AI server.
- Include core, context/update regression and chat tests in the repository.
