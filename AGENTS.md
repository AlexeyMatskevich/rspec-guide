# Repository Guidelines

## Project Structure & Module Organization
- `guide.ru.md` is the canonical source; expand the navigation list when adding new top-level sections.
- Additional languages follow `guide.<lang>.md`; diagrams or screenshots live in `docs/assets/` and use relative links.
- Keep Markdown self-contained: no generated artifacts or local build steps are required to read the guide.

## Build & Edit Workflow
- `npx markdownlint-cli guide.ru.md AGENTS.md` — run before every PR to keep heading order, spacing, and code fences consistent.
- Skip commands that require extra runtimes (Python, etc.) unless a portable alternative exists.
- Python 3.14 is available via devbox; use it for quick scripts when Node solutions would be unwieldy.

## Collaboration Workflow
- Treat every checklist item as its own stage: finish it, describe the changes, and pause for review before touching the next one.
- A stage counts as complete only after the user reviews and approves it; their reply is the per-stage gate.
- Once a stage is approved, immediately commit the related changes with an English message (unless the user explicitly says not to), then move to the next stage.

## Authoring Guideline Rules
- Rule headings use `### <number>. <action>` (e.g., `### 5. Describe behavior in plain language`) followed immediately by 1–2 sentences explaining the motivation.
- Secondary structure relies on `####` subheadings for scenarios and short lists for facts or symptoms; avoid long narrative blocks.
- Stick to the built-in evaluation labels inside code blocks (`# плохо`, `# хорошо`, optionally `# отвратительно`, `# очень плохо`, `# нормально` when explicitly requested). Do not introduce phrases like “contrived example”.
- Legacy exceptions stay in place: Rule 2 keeps the “Надуманный пример” wording and `double` demo unless the user explicitly asks to change it.

## Example Composition
- Present pairs: bad snippet first, good second, then the explanation that dissects the differences.
- Keep violations scoped: the bad example should only break rules tied to the current guideline, while the good example must respect the rest of the style guide.
- Elide out-of-scope setup with `...` or terse comments; otherwise, show concrete `let`/`subject`. Use two-space Ruby indentation and pick matchers that mirror the surrounding text.

## Glossary Entries
- Organize the glossary with `###` group headers and bullet entries of the form `- **Term** — definition`. Follow with optional paragraphs or nested lists for examples.
- Always spell out boundaries (e.g., “**НЕ является…**”) so readers understand what falls outside the term.

## Commit & Pull Request Guidelines
- Commit messages stay short, imperative, and reference the touched rule or concept (`Add Rule 12: …`, `Improve aggregate_failures examples`).
- PR descriptions list the sections affected and only include screenshots when Markdown rendering changes. Link any related issues or discussions for traceability.
