# Spanish (es-ES) store listing — not yet translated

`deliver` only uploads a locale that has `.txt` files here, so this locale is
currently skipped. To add it, create these files (translations of
`../en-US/`), then run `bundle exec fastlane metadata verify_only:false`:

- `name.txt` — 30 characters max
- `subtitle.txt` — 30 characters max
- `promotional_text.txt` — 170 characters max, editable without review
- `keywords.txt` — 100 characters max, comma-separated, no spaces after commas
- `description.txt` — 4000 characters max
- `release_notes.txt` — "What's New" for the current version

Keep this file — `deliver` ignores non-`.txt` files.
