ДЛЯ АГЕНТОВ - ИГНОРИРУЙТЕ ЭТОТ ФАЙЛ.

Ниже — полный список **актуальных задач** (после появления `isolation-decider`) с постановкой “что/зачем/почему”, с учётом последних решений из переписки (включая: request-only для Rails controllers, невалидный Ruby на этапе architect допустим, shared_examples — отдельным постпроцессором/скриптом, валидаторы YAML/metadata отдельными скриптами + self-check loop, progressive disclosure).

---

## Контекст: почему вообще нужны изменения

1. В репо сейчас есть **конфликт контрактов “architect → implementer”**:

- `agent-communication.md` прямо говорит: **test-architect генерирует spec-файл с плейсхолдерами `{SETUP_CODE}`, `{EXPECTATION}`, а test-implementer заполняет плейсхолдеры** .
- При этом `test-implementer.md` описан как агент, который **генерирует spec файл целиком из YAML `structure`**, который передаёт architect .
- И команда `/rspec-cover` сейчас оркестрирует `test-implementer` именно так: передаёт `structure: [architect output]` .

Одновременно `spec_structure_generator.rb` уже генерирует skeleton с `{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}` — то есть “линия плейсхолдеров” уже фактически реализована.

2. `check-spec-exists.sh` декларирует, что controller может маппиться в `spec/controllers/*` **или** `spec/requests/*`, но реально всегда маппит в `spec/controllers/*` . Это против твоего правила “новые controller tests — всегда request”.

3. В `agent-communication.md` есть внутренние несостыковки:

- В одном месте говорится “test_level removed” ,
- но ниже же указано, что `isolation-decider` пишет `methods[].test_config (test_level + isolation…)` .
  Это надо выровнять, иначе агенты/команды будут дрейфовать.

4. По best-practice плагинов: детерминированные операции надо уносить в скрипты (валидаторы, патчинг файлов, трансформации) и держать main agent файл под ~500 строк, используя progressive disclosure с чёткими триггерами .

---

# Список задач

## Задача 1 — Выровнять контракт “test-architect → test-implementer” вокруг skeleton/spec-файла (убрать `structure` как обязательный вход implementer)

### Зачем

Сейчас документация и оркестрация противоречат друг другу: один источник говорит “implementer заполняет плейсхолдеры” , второй/команда — что implementer строит файл из YAML `structure` . Это создаёт нестабильность пайплайна и лишнюю передачу больших YAML через контекст.

### Что изменить

1. `plugins/rspec-testing/commands/rspec-cover.md`
   - Переписать вызов implementer: **передавать только `slug`** (и при необходимости `spec_file`/`spec_path` как подсказку), а не `structure/output_path`.
     Сейчас это выглядит как `Task(test-implementer, { structure: …, output_path: … })` — это должно исчезнуть.

2. `plugins/rspec-testing/agents/test-implementer.md`
   - Переписать “Responsibility Boundary” и фазы: implementer **не генерирует describe/context дерево**, а:
     - читает metadata по `slug`,
     - читает/находит spec-файл, созданный/обновлённый architect,
     - заполняет плейсхолдеры `{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}` (и будущие маркеры v2),
     - (опционально) создаёт фабрики/трейты (если это его зона ответственности; если позже будет `factory-agent`, то implementer только использует).

3. `plugins/rspec-testing/docs/agent-communication.md`
   - В таблице “Progressive Enrichment” сейчас test-implementer “writes warnings only” — это нужно обновить: implementer должен писать `test_implementer_completed`, и иметь право модифицировать spec-файлы (артефакты).

### Критерии готовности

- Команда `/rspec-cover` больше **не** передаёт `structure` в implementer.
- `test-implementer` документирован и работает как “placeholder filler”.
- `agent-communication.md` не противоречит `/rspec-cover` и агентам.

---

## Задача 2 — Placeholder Contract v2: машинные маркеры в skeleton (generator) + документ контракта architect↔implementer

### Зачем

Чтобы implementer мог **детерминированно** маппить:

- `it` ↔ `behavior_id`,
- набор контекстов ↔ путь состояний характеристик (branch path),
- side effects ↔ соответствующие `behavior_id`,
  без повторного чтения исходников и без хрупкого парсинга Ruby.

Сейчас generator выводит только текстовые описания, а внутренние структуры не сохраняют `behavior_id` для it-блоков (например leaf/terminal кладутся как `{ description: behavior }`) и side effects как `{ description: …, side_effect: true }` — этого недостаточно для “строгого” связывания.

### Что изменить

1. Добавить документ:

- `plugins/rspec-testing/docs/placeholder-contract.md` (или аналогичное имя)

В нём зафиксировать **строгий синтаксис маркеров**, которые generator будет печатать в skeleton. Минимально нужно:

- **Границы метода** (для replace/regenerate и поиска блока):

  ```
  # rspec-testing:method_begin method="#process" method_id="PaymentProcessor#process"
  ...
  # rspec-testing:method_end method="#process" method_id="PaymentProcessor#process"
  ```

- **Маркер примера перед it** (для implementer):

  ```
  # rspec-testing:example behavior_id="returns_completed" kind="terminal" path="payment_status=completed"
  it "returns completed status" do
    {EXPECTATION}
  end
  ```

- **Маркер side-effect примера**:

  ```
  # rspec-testing:example behavior_id="sends_confirmation_email" kind="side_effect" path="payment_status=pending,gateway_result=true"
  it "sends confirmation email" do
    {EXPECTATION}
  end
  ```

- Опционально: маркеры контекстов (если нужно implementer’у), но на практике достаточно `path=...`, если он стабильный.

2. Обновить `plugins/rspec-testing/scripts/spec_structure_generator.rb`:

- В `resolve_side_effects` добавить возврат `behavior_id` вместе с `type/description` .
- В `context[:it_blocks]` хранить не только `description`, но и `behavior_id`, `kind`, `path`. Сейчас там только `description` .
- Добавить печать маркеров `method_begin/method_end` вокруг каждого describe метода.
- Добавить печать маркеров `example` перед каждым `it`.

3. (Важно) Стабилизировать `path`:

- `path` должен быть **детерминированным и каноническим**: порядок характеристик = порядок уровней (level), значения = raw `value`.
- Если `level` не уникален/есть параллельные ветки, path всё равно должен однозначно отражать контекст (возможен формат `level:char=value`).

### Критерии готовности

- generator в режиме `--structure-mode=blocks` печатает method-блоки с `method_begin/end` + `example` маркерами.
- В каждом `it` можно однозначно восстановить `behavior_id` и `path` без эвристик.
- Контракт описан в отдельном doc.

---

## Задача 3 — Детерминированный патчинг spec-файла: вставка/замена describe-блоков по `method_mode` (скриптом, не через “умные” эвристики в агенте)

### Зачем

`test-architect` должен:

- для `method_mode=new` — **вставлять новый describe блока**,
- для `modified/unchanged (selected)` — **перегенерировать/заменять существующий блок**.

Сейчас это описано на уровне “намерения” в `agent-communication` (method_mode обязателен, architect решает insert vs regenerate) , но надёжного механизма патчинга текста spec-файла по маркерам нет.
А по best practice детерминированные операции должны уходить в скрипт .

### Что изменить

1. Создать новый скрипт:

- `plugins/rspec-testing/scripts/apply_method_blocks.rb` (или `.sh + ruby внутри`)

Скрипт должен:

- вход: `spec_file_path`, `blocks_text` (или путь к файлу blocks), опции режима,
- парсить blocks по маркерам `# rspec-testing:method_begin …` / `method_end …`,
- парсить целевой spec-файл и находить существующие блоки по тем же маркерам,
- выполнять операции:
  - insert (если блока нет),
  - replace (если блок есть),
  - (опционально) skip (если так решил orchestrator/agent).

2. Обновить `plugins/rspec-testing/agents/test-architect.md`:

- Перестроить “Phase 4: Generate Spec Structure” так, чтобы architect:
  - получал blocks от generator,
  - (опционально) прогонял постпроцессоры (см. shared examples ниже),
  - вызывал `apply_method_blocks.rb` для вставки/замены,
  - обновлял metadata markers `test_architect_completed`.

3. Встроить `AskUserQuestion` там, где **детерминированности недостаточно**:

- если метод помечен `new`, но в spec уже найден block с тем же `method_id` → спросить “overwrite/skip”.

### Критерии готовности

- Повторный запуск architect на том же методе делает **идемпотентный replace**, не плодит дубликаты.
- Замена производится строго в пределах `method_begin/end`.

---

## Задача 4 — Controllers: всегда request specs для новых тестов + обработка legacy `spec/controllers/*`

### Зачем

Ты фиксируешь правило: “новые controller tests в Rails — всегда request/integration”, а legacy controller specs нужно либо мигрировать, либо спросить пользователя.

Но текущий `check-spec-exists.sh` всегда строит `spec/controllers/*` путём замены `app/...` → `spec/...` , несмотря на комментарий про `spec/requests` .

### Что изменить

1. Обновить `plugins/rspec-testing/scripts/check-spec-exists.sh`:

- Для `app/controllers/...`:
  - вычислять **предпочтительный** путь `spec/requests/..._spec.rb` (или `spec/requests/<namespace>/..._spec.rb`),
  - параллельно вычислять legacy путь `spec/controllers/..._spec.rb`,
  - в NDJSON отдавать оба + флаги существования.

Пример выхода (NDJSON):

```json
{
  "file": "app/controllers/api/v1/users_controller.rb",
  "preferred_spec_path": "spec/requests/api/v1/users_spec.rb",
  "preferred_exists": false,
  "legacy_spec_path": "spec/controllers/api/v1/users_controller_spec.rb",
  "legacy_exists": true
}
```

2. Обновить `test-architect` поведение для controllers:

- Если `preferred_exists=false` и `legacy_exists=true`:
  `AskUserQuestion`:
  - “Создать request spec и (рекомендовано) удалить/игнорировать controller spec”
  - “Переписать существующий controller spec (не рекомендовано)”

- Если файла теста нет — создавать request spec.

### Критерии готовности

- Discovery/Architect получают корректный `spec_path` для controllers.
- При наличии legacy controller spec пайплайн не “молча” продолжает, а спрашивает пользователя.

---

## Задача 5 — Shared Examples: детект повтора behavior ≥ 3 и рефакторинг в shared_examples отдельным постпроцессором (не внутри generator)

### Зачем

Ты не хочешь раздувать `spec_structure_generator.rb` обязанностями “валидация+структура+оптимизация”. Shared examples — это отдельная трансформация структуры (и потенциально зависит от контекста проекта/существующих shared_examples), значит логичнее как отдельный этап.

Также у тебя есть идея: “domain-specific shared_example если поведение повторяется 3+ раз”.

### Что изменить

1. Создать отдельный скрипт:

- `plugins/rspec-testing/scripts/refactor_shared_examples.rb`

Он должен:

- принимать blocks (после generator, уже с `behavior_id` маркерами),
- для каждого method блока:
  - считать повторы `behavior_id` среди `# rspec-testing:example …`,
  - если `count >= threshold`:
    - создать `shared_examples "<stable name>" do … end` внутри method describe,
    - заменить повторяющиеся `it ...` на `include_examples ...` (или `it_behaves_like ...`),
    - сохранить `example` маркеры так, чтобы implementer всё ещё мог найти `behavior_id`/path (если include_examples остаётся без it — тогда маркер должен жить рядом с include).

2. В `test-architect` добавить **условный запуск** скрипта:

- IF: “обнаружены повторы behavior_id >= 3 в одном методе” → прогнать `refactor_shared_examples.rb`,
- ELSE: пропустить.

3. Документировать ограничения:

- На этапе `test-architect` shared_examples **только внутри одного spec файла** (intra-file), без попытки шарить между файлами.
- Cross-file shared_examples — зарезервировать для будущего implementer/factory-agent этапа (вариант C).

### Критерии готовности

- При 3+ повторах в одном методе skeleton преобразуется в shared_examples, не ломая маркерный контракт.
- Implementer может заполнить placeholders внутри shared_examples так же, как внутри it.

---

## Задача 6 — Валидаторы YAML/metadata/spec + self-check loop в агентах (единая задача)

### Зачем

Ты хочешь:

- не “смешивать” валидацию с генерацией,
- иметь детерминированную проверку YAML/контрактов после каждого агента, чтобы агент мог сам себя исправлять,
- при этом пайплайн остаётся fail-fast без retry на уровне оркестратора и “no automatic retry” .

### Что изменить

1. Добавить набор валидаторов в `plugins/rspec-testing/scripts/`:

- `validate_yaml.rb`
  Проверяет, что YAML парсится (metadata-файлы + при желании YAML финального ответа агента).

- `validate_metadata_stage.rb --stage=code-analyzer|isolation-decider|test-architect|test-implementer`
  Проверяет:
  - наличие required полей,
  - наличие нужных completion markers предыдущего шага (по `agent-communication` prerequisite check ),
  - stage-specific invariants (например: после isolation-decider у каждого selected метода есть `test_config`, после architect есть `test_architect_completed`, etc).

- `validate_spec_skeleton.rb`
  Проверяет:
  - что в spec файле есть `method_begin/end` для каждого selected метода,
  - что каждый `it`/example имеет `behavior_id`,
  - после implementer — что плейсхолдеров `{EXPECTATION}/{SETUP_CODE}/{COMMON_SETUP}` больше не осталось (или остались только разрешённые).

2. Встроить self-check loop в агентов:

- `isolation-decider`, `test-architect`, `test-implementer` (и по желанию `code-analyzer`):
  - агент делает работу,
  - запускает валидатор,
  - если ошибки: агент должен попытаться исправить и повторить (ограниченный цикл N попыток),
  - если не получается — `status: error` с конкретным списком нарушений.

3. В этот же этап добавить “сигнал комбинаторного взрыва”:

- Валидатор (или code-analyzer) считает количество характеристик/ветвей.
- Если > 4–5 характеристик или оценка листьев > порога — `AskUserQuestion` (рефакторить/продолжить/ограничить покрытие).
  Это соответствует твоей идее “сигнализировать о проблеме дизайна до генерации огромного дерева”.

### Критерии готовности

- Каждый агент после записи артефактов сам проверяет корректность и либо чинит, либо падает с детальным error.
- Валидация вынесена в scripts, а не в generator.
- Пайплайн всё ещё fail-fast на уровне command/orchestrator.

---

## Задача 7 — Progressive Disclosure: разрезать `test-architect.md` (и обновлённый `test-implementer.md`) на main+supporting files с чёткими триггерами

### Зачем

У тебя упирается в “агенты по 1k строк”. По гайду:

- main agent файл должен быть под ~500 строк ,
- большие куски надо выносить в supporting files, но только с ясным IF/WHEN триггером ,
- иначе агент либо всегда читает всё и нет выигрыша, либо пропускает важное.

### Что изменить

1. `plugins/rspec-testing/agents/test-architect.md`:

- Оставить в main:
  - контракт, вход/выход,
  - короткий алгоритм,
  - обязательные проверки,
  - вызовы scripts (generator → postprocess → apply blocks → validators).

- Вынести в `plugins/rspec-testing/agents/test-architect/…`:
  - `controllers-migration.md`
    **IF обнаружен legacy controller spec** → load.
  - `shared-examples-refactor.md`
    **IF behavior повторяется >= threshold** → load.
  - `apply-blocks-algo.md`
    **IF spec file exists** → load (сложный алгоритм патчинга).
  - `examples/` как reference (не грузить).

2. `plugins/rspec-testing/agents/test-implementer.md`:

- Аналогично: parser placeholders, отдельные conditional файлы:
  - **IF test_level=unit AND external deps present** → load “unit isolation tactics”
  - **IF request spec** → load “request helpers / rack-test tactics”
  - **IF shared_examples present** → load “fill placeholders in shared_examples”.

3. Синхронизировать docs:

- `agent-communication.md` (исправить противоречия по test_level/test_config, роли implementer)
- при необходимости `plugins/rspec-testing/docs/decision-trees.md` — чтобы он не конфликтовал с новой реальностью.

### Критерии готовности

- `test-architect.md` и `test-implementer.md` в целевом размере, а сложные ветки вынесены с явными IF/WHEN.
- Supporting файлы не “always needed” (иначе они должны быть inline).

---

# Рекомендуемый порядок выполнения

1. **Задача 1** (контракт architect↔implementer + команда `/rspec-cover`) — иначе все остальные изменения будут “в воздухе”.
2. **Задача 2** (placeholder contract v2 + маркеры в generator) — база для детерминированного implementer и patcher.
3. **Задача 3** (apply_method_blocks скрипт + method_mode) — чтобы architecture реально применялась к существующим файлам.
4. **Задача 4** (controllers→request + legacy ask) — чтобы rails web-entrypoints были корректны.
5. **Задача 5** (shared_examples постпроцессор) — отдельная оптимизация, когда база стабилизирована.
6. **Задача 6** (валидаторы + self-check loop) — лучше внедрять как только контракт стабилен, чтобы фиксировать регрессии.
7. **Задача 7** (progressive disclosure + doc sync) — в конце, когда структура задач ясна, и можно “упаковать”.

Если нужно, могу дополнительно составить “Definition of Done” в формате чек-листа для каждого PR (по файлам/командам/ожидаемым диффам), но список задач выше уже сформулирован как постановка для Claude Code/Codex.
