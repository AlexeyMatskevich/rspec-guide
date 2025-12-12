# Repository Guidelines

This repository is a documentation‑first RSpec style guide and automation toolkit. It contains bilingual guides (RU/EN), RuboCop configs, and a Claude Code plugin under `plugins/` and `rspec-testing/`.

## Project Structure & Module Organization

- Root Markdown guides: `guide.*.md`, `checklist.*.md`, `patterns.*.md`, `guide.api.*.md`.
- Automation docs and skills:
  - `rspec-testing/` – Claude skill for RSpec tests.
  - `plugins/rspec-testing/` – Claude Code plugin (commands, agents, docs).
  - `docs/` – plugin architecture (`PLUGINS-GUIDE.md`, metadata schemas, flows).
- RuboCop configs: `rubocop-configs/`.

When editing docs, keep Russian/English pairs structurally synchronized.

## Build, Test, and Development Commands

This repo has no build or test pipeline. Useful commands:

- `ls`, `rg`, `sed` – inspect docs and plugin files.
- `devbox shell` – optional dev environment for tools (Markdown linters, etc.).

Do not add build steps or test runners without consensus.

## Coding Style & Naming Conventions

- Markdown:
  - Use ATX headings (`#`, `##`, …); keep sections shallow and scannable.
  - Prefer short paragraphs and bullet lists; avoid long prose blocks.
- Examples:
  - Ruby code and RSpec examples in English.
  - Quality annotations: RU – `# плохо / # нормально / # хорошо`; EN – `# bad / # okay / # good`.
- Plugin docs (`plugins/rspec-testing/agents/*.md`):
  - Follow `docs/PLUGINS-GUIDE.md` (responsibility boundary, input/output contracts).
  - Describe inputs as requirements, not by naming other agents.
  - Use progressive disclosure: top-level agent file + optional detailed subfiles.

## MCP Tools Usage (Serena, Context7, NixOS)

- **Serena MCP**  
  - Use for semantic navigation and edits in plugin/agent files (symbol search, references, structured inserts/replacements) instead of raw grep/line edits.  
  - Prefer `find_symbol`, `get_symbols_overview`, and symbol-level edit tools; only read full files when absolutely necessary.

- **Context7 MCP**  
  - Use whenever you need external library/API documentation, setup/configuration patterns, or non-trivial code generation for examples.  
  - Always resolve a library via Context7 first and read docs, rather than guessing RSpec/Rails/third‑party APIs from memory.

- **mcp-nixos**  
  - Use only for questions about NixOS / Home Manager / Nix packages (e.g., configuring devbox, finding package versions, inspecting Nix options).  
  - Do not use it for repository‑local logic or general Ruby/RSpec questions.

## Testing Guidelines

There is no automated test suite here. When changing behavior in plugin specs:

- Validate examples conceptually against the main guides.
- Keep metadata schemas consistent between `docs/metadata-schema.md` and `plugins/rspec-testing/agents/*`.

## Commit & Pull Request Guidelines

- Commit messages: English, imperative mood (e.g., `Update metadata schema`, `Add isolation-decider agent`).
- Group related changes (docs + corresponding plugin files) in a single commit.
- In PRs:
  - Clearly state what part you touched (guides, rspec-testing plugin, rubocop-configs).
  - Mention if bilingual files are fully synchronized or still pending translation.
