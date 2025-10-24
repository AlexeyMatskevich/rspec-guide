# Repository Guidelines

## Project Structure & Module Organization
- `guide.ru.md` is the canonical source; expand the existing navigation list when adding new top-level sections and keep the document linear.
- Additional languages follow the `guide.<lang>.md` convention, while shared diagrams or screenshots live in `docs/assets/` and are referenced with relative paths.
- Keep Markdown files self-contained: no generated artifacts or local build steps are required to consume the guide.

## Build & Edit Workflow
- `npx markdownlint-cli guide.ru.md AGENTS.md` — run before every PR to keep heading order, spacing, and code fences consistent.
- Prefer portable tooling; if a command requires extra runtimes (Python, etc.), provide an alternative or skip mentioning it here.

## Authoring Guideline Rules
- Rule headings use `### <number>. <action>` (e.g., `### 5. Describe behavior in plain language`) followed immediately by 1–2 sentences explaining the motivation.
- Secondary structure relies on `####` subheadings for scenarios and short lists for facts or symptoms; avoid long narrative blocks.
- Stick to the built-in evaluation labels inside code blocks (`# плохо`, `# хорошо`, optionally `# отвратительно`, `# очень плохо`, `# нормально` when explicitly requested). Do not introduce phrases like “contrived example”.

## Example Composition
- Present pairs: the “bad” snippet (labeled `# плохо`) comes first, the improved snippet (`# хорошо`) immediately follows, and only after both blocks do we provide the explanation that dissects the differences.
- Keep violations scoped: the bad example should only break rules that are directly related to the current guideline, while the good example must respect the rest of the style guide.
- Use comments to connect setup with the behavior under test, keep Ruby indentation at two spaces, and align matcher choice with the surrounding prose.

## Glossary Entries
- Organize the glossary with `###` group headers and bullet entries of the form `- **Term** — definition`. Follow with optional paragraphs or nested lists for examples.
- Always spell out boundaries (e.g., “**НЕ является…**”) so readers understand what falls outside the term.

## Commit & Pull Request Guidelines
- Commit messages stay short, imperative, and reference the touched rule or concept (`Add Rule 12: …`, `Improve aggregate_failures examples`).
- PR descriptions list the sections affected and only include screenshots when Markdown rendering changes. Link any related issues or discussions for traceability.
