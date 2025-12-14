ДЛЯ АГЕНТОВ - ИГНОРИРУЙТЕ ЭТОТ ФАЙЛ. НЕ ЧИТАЙТЕ И НЕ МЕНЯЙТЕ ЕГО.

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

  ```tasks
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

2. Обновить rspec-init команду, чтобы она спрашивала, предпочитает ли пользователь создавать request spec всегда или обновлять controller speс если они уже есть, иначе говоря предпочитает ли пользователь осуществлять переход с legacy тестов на новые для controller или оставить как есть, опции да, нет, спрашивать по факту.

3. Обновить `test-architect` поведение для controllers:

- Если пользователь выбрал всегда создавать request spec, то создать request spec и удалить controller spec.
- Если пользователь выбрал обновлять controller spec, то обновить controller spec.
- Если пользователь выбрал вспрашивать и мы получили `preferred_exists=false` и `legacy_exists=true`:
  `AskUserQuestion`:
  - “Создать request spec и (рекомендовано) удалить/игнорировать controller spec”
  - “Переписать существующий controller spec (не рекомендовано)”

- Если файла теста нет — создавать request spec.

### Критерии готовности

- Discovery/Architect получают корректный `spec_path` для controllers.
- При наличии legacy controller spec пайплайн не “молча” продолжает, а спрашивает пользователя.

Дополнительное задание, описать в docs контракт по полям и что они означают, которые предоставляет rspec-init.

---

## Задача 5 — Shared Examples: детект повтора behavior ≥ 3 и рефакторинг в shared_examples отдельным постпроцессором (не внутри generator)

Ключевое наблюдение: сейчас контракт “implementer ↔ skeleton” завязан на то, что `# rspec-testing:example …` лежит **внутри** каждого `it` (после `{EXPECTATION}`) — так делает генератор , так это зафиксировано в `placeholder-contract.md` , и так прямо описан алгоритм implementer’а .
При переходе на `shared_examples` невозможно сохранить “реальный” `path` внутри шаблонного `it` shared_examples (он разный для каждого include), значит маркер для `path` неизбежно должен жить **рядом с include/it_behaves_like** (как ты и писал в исходной идее).

Дальше выбор “отдельный скрипт vs внутри generator”:

- **Внутри `spec_structure_generator.rb`** это проще и надёжнее: ты уже имеешь дерево контекстов + `(behavior_id, kind, path)` в структурированном виде и просто по-другому печатаешь код. Не нужно писать отдельный рефакторер, который будет “разбирать” Ruby-текст blocks и перестраивать его (это сильно более хрупко).
- Чтобы не раздувать генератор логикой, можно сделать внутри него отдельный класс/модуль (например `SharedExamplesOptimizer`) — но всё равно запускать это как часть генерации (детерминированно).

Ниже — переписанная задача под твой новый выбор (встроить в generator), с обязательным обновлением контракта/implementer под маркеры рядом с `it_behaves_like`.

---

## Задача 5 — Shared Examples: дедупликация повторяющегося behavior ≥ 3 прямо в `spec_structure_generator.rb`

### Зачем

Автоматически сокращать дублирующиеся `it`-блоки внутри **одного method describe**, когда один и тот же `(behavior_id, kind)` встречается ≥ `threshold` раз, но при этом:

- не терять связь с `behavior_id` и **конкретным `path` каждого появления** (для implementer’а),
- оставить возможность implementer’у заполнять `{EXPECTATION}` в shared_examples так же, как он заполнял в обычных `it`.

### Решение (архитектура)

- Не делать отдельный `refactor_shared_examples.rb`.
- Делать трансформацию детерминированно **в момент генерации текста** в `plugins/rspec-testing/scripts/spec_structure_generator.rb`.

### Что изменить

#### 1) `plugins/rspec-testing/scripts/spec_structure_generator.rb`

Добавить “оптимизатор shared examples” на уровне **каждого метода** (внутри `generate_method_block`):

1. **Сбор статистики повторов**
   - Обойти все leaf-контексты метода, собрать список `it_blocks`.
   - Считать повторы по ключу: `(behavior_id, kind)` (минимум) или `(behavior_id, kind, description)` (если хочешь защиту от странных кейсов).
   - `threshold` по умолчанию: `3`.
   - (Опционально) CLI-опция: `--shared-examples-threshold=N` (default 3).

2. **Генерация shared_examples для повторяющихся behavior**
   - Для каждого ключа с `count >= threshold` сгенерировать **шаблон** внутри method describe **до контекстов**, чтобы `it_behaves_like` ниже мог его использовать.
   - Имя shared_examples должно быть стабильным и уникальным _в рамках метода_, например:
     - `"__rspec_testing__#{method_id}__#{behavior_id}__#{kind}"`

   - Шаблон содержит **один `it`** с `{EXPECTATION}`:

     ```ruby
     shared_examples '__rspec_testing__PaymentProcessor#process__returns_completed__success' do
       it 'returns completed status' do
         {EXPECTATION}
         # rspec-testing:example behavior_id="returns_completed" kind="success" path="" template="true"
       end
     end
     ```

     Примечания:
     - Маркер остаётся `rspec-testing:example`, но:
       - `template="true"` (новый атрибут),
       - `path=""` допустим **только** для template-маркера (см. обновление контракта ниже).

     - Описание `it` берём из behavior bank (оно у тебя уже резолвится).

3. **Замена повторяющихся `it` на `it_behaves_like`**
   - В leaf-контекстах, для it_blocks попавших под дедупликацию:
     - **не печатать `it`**
     - печатать:

       ```ruby
       # rspec-testing:example behavior_id="returns_completed" kind="success" path="1:payment_status=:completed"
       it_behaves_like '__rspec_testing__PaymentProcessor#process__returns_completed__success'
       ```

     - Важно: маркер находится **рядом с include**, чтобы сохранить `path` конкретного появления.

4. **Сохранить порядок**
   - Внутри leaf-контекста порядок должен остаться прежним:
     - side_effect сначала,
     - success/terminal потом.

   - Если часть из них превращается в `it_behaves_like`, порядок строк должен соответствовать исходному порядку it_blocks.

#### 2) `plugins/rspec-testing/docs/placeholder-contract.md`

Расширить контракт маркеров:

- Разрешить два “носителя” маркера `example`:
  1. классический (как сейчас) — **внутри `it`** после `{EXPECTATION}`
  2. новый — **на строке-комментарии прямо перед `it_behaves_like`** (или `include_examples`), где `path` обязателен

- Добавить правило для template-маркеров:
  - `template="true"` означает “шаблон ожидания” внутри shared_examples
  - для template допустим `path=""` (потому что реальный path находится у include-site маркера)

- Добавить короткий пример блока метода с shared_examples + it_behaves_like.

#### 3) `plugins/rspec-testing/agents/test-implementer.md`

Обновить алгоритм чтения skeleton:

- Помимо “маркер внутри `it`”, implementer должен уметь:
  - находить `# rspec-testing:example …` **перед `it_behaves_like`**,
  - использовать `behavior_id/kind/path` из этого маркера для заполнения `{SETUP_CODE}` в соответствующем контексте,
  - находить shared_examples templates по маркеру `template="true"` и заполнять `{EXPECTATION}` **один раз** в шаблоне.

Минимально: добавить отдельный раздел “IF shared_examples present → load/handle”.

#### 4) (Опционально, но желательно) `plugins/rspec-testing/scripts/README.md`

В секции про `spec_structure_generator.rb` дописать, что генератор может выдавать shared_examples при повторах ≥ threshold и как при этом выглядят маркеры.

### Ограничения (зафиксировать в задаче)

- Дедупликация только **внутри одного method describe** (intra-method).
- Не шарим shared_examples между методами и тем более между файлами на этапе architect/generator.
- Cross-file/cross-method shared_examples — отложить на будущий этап (вариант C) в implementer/factory-agent.

### Критерии готовности (DoD)

- При `count >= threshold` для `(behavior_id, kind)` внутри одного метода:
  - generator печатает shared_examples-шаблон + заменяет повторы на `it_behaves_like`,
  - include-site маркеры сохраняют `behavior_id/kind/path` (не ломаем связку),
  - implementer может:
    - заполнить `{EXPECTATION}` в shared_examples,
    - заполнить `{SETUP_CODE}` в контекстах, ориентируясь на include-site `path`,
    - и не требует хрупкого парсинга Ruby.

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
