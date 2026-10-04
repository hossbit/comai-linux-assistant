# ComAI 2.9.0

Released 2026-10-04.

- Add `context` to preview local file/directory input without calling a model.
- Apply cloud-context consent to directory listings as well as files.
- Preserve update failure exit codes and stop false success messages.
- Validate local HTTP URL authorities, including IPv6 loopback.
- Add regression coverage and make local tests independent of the running AI server.
- Include core, context/update regression and chat tests in the repository.
