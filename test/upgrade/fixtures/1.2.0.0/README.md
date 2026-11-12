These are unmodified Linux handler scripts from release `1.2.0.0`, commit
[`26ffdf6ab7123771f8a03e4f81bbb06d7f247568`](https://github.com/elastic/azure-vm-extension/tree/26ffdf6ab7123771f8a03e4f81bbb06d7f247568/src/handler/linux).
They retain the repository's license.

The regression tests check their SHA-256 hashes against `manifest.json` before
copying them to a temporary directory and replacing host/configuration
boundaries. Vendoring these historical inputs makes the tests work with
shallow, tagless, and source-archive checkouts without fetching Git history.

The scoped Git attributes preserve their original bytes and whitespace across
checkouts. Do not run these scripts directly or update them with current handler
code.
