# Что можно изучить по тестам

Better Specs — краткий свод лучших (и худших) практик для RSpec: как формулировать примеры, работать с матчерами и контекстами. https://www.betterspecs.org

Testing for Beginners — вводная книга по тестированию на Ruby: что тестировать, как думать о сценариях и как читать фейлы. http://testing-for-beginners.rubymonstas.org/index.html

Pluralsight: RSpec Ruby Application Testing — наглядный курс: BDD на примере игры в карты, структура describe/context/it, три фазы теста (подготовка -> действие -> ожидание). Есть 10-дневный триал; https://www.pluralsight.com/courses/rspec-ruby-application-testing

Everyday Rails Testing with RSpec — практичная "библиотека приемов": factory_bot, VCR, WebMock и другие инструменты. Около 230 страниц; можно прочитать за пару дней. https://leanpub.com/everydayrailsrspec

Эти материалы дадут базу. Ниже — философия RSpec/BDD, на которой держатся правила из следующего раздела.

# Про RSpec

RSpec — тестовая библиотека для Ruby с DSL, заточенным под описание поведения, а не внутренней реализации.

```ruby
describe "my app" do
  it "works" do
    expect(MyApp.working).to eq(true)
  end
end
```

Официальный слоган на https://rspec.info/:

```
Behaviour Driven Development for Ruby.
Making TDD Productive and Fun.
```

Ключевая мысль: RSpec — инструмент BDD для Ruby. Он делает практику TDD продуктивной и более "человечной" за счет языка, близкого к бизнес-формулировкам.

## Как связаны RSpec, BDD и TDD

TDD (test-driven development) — короткий цикл Red -> Green -> Refactor:
- пишем тест, фиксирующий желаемое поведение;
- пишем минимальный код, чтобы тест прошел;
- рефакторим, сохраняя зеленое состояние.

BDD (behaviour-driven development) вырос из TDD и смещает фокус на поведение домена и язык разговора с бизнесом. Тесты становятся читаемой спецификацией, а не просто проверкой кода.

RSpec воплощает BDD в экосистеме Ruby: `describe/context/it` помогают формулировать поведение единообразно и понятно.

## Зачем нам BDD на практике

- Единый язык с бизнесом: формулируем правила домена "человеческими" фразами, не зная реализации.
- Исполняемая документация: тесты — проверяемая спецификация поведения.
- Быстрая локализация проблем: упавший тест явно показывает, какое правило нарушено.
- Свободный рефакторинг: фокус на том, что делает система, а не как она устроена.

**Предметная область** — набор правил и понятий, которые бизнес хочет видеть в системе (например, биллинг). В коде мы реализуем именно эти правила поведения.

## От естественного языка к формальному синтаксису Gherkin

BDD часто опирается на Gherkin — формальный, но читаемый синтаксис для описания историй и сценариев. Он фиксирует три ключевые фазы: Given (условия), When (действие), Then (результат).

Пример истории и сценариев:

```
As a store owner
In order to keep track of stock
I want to add items back to stock when they're returned.

Scenario 1: Refunded items should be returned to stock
  Given that a customer previously bought a black sweater from me
  And I have three black sweaters in stock
  When they return the black sweater for a refund
  Then I should have four black sweaters in stock

Scenario 2: Replaced items should be returned to stock
  Given that a customer previously bought a blue garment from me
  And I have two blue garments in stock
  And three black garments in stock
  When they return the blue garment for a replacement in black
  Then I should have three blue garments in stock
  And two black garments in stock
```

И адаптация на русском:

```
Как владелец магазина
Чтобы следить за запасами на складе
Я хочу возвращать товары на склад, когда их возвращают покупатели.

Сценарий 1: Возвращенные товары должны вернуться на склад
  Дано, что клиент ранее купил у меня черный свитер
  И на складе есть три таких свитера
  Когда клиент возвращает свитер
  Тогда на складе должно быть четыре черных свитера

Сценарий 2: Обмененные товары должны вернуться на склад
  Дано, что клиент покупал у меня одежду синего цвета
  И на складе есть два таких наименования синего цвета
  И три наименования черного цвета
  Когда клиент возвращает синюю вещь, чтобы обменять на черную
  Тогда на складе должно быть три синих наименования
  И два черных наименования
```

### Язык Gherkin — памятка

| Ключевое слово (EN) | Русский | Короткое описание |
| --- | --- | --- |
| Story / Feature | История | Заголовок спецификации, формулирует ценность. |
| As a | Как (в роли) | Роль заинтересованного лица. |
| In order to | Чтобы достичь | Цель роли. |
| I want to | Я хочу | Краткий желаемый результат. |
| Scenario | Сценарий | Конкретный сценарий истории. |
| Given | Дано | Начальные условия (повторяются через And). |
| When | Когда | Действие, запускающее сценарий. |
| Then | Тогда | Наблюдаемый результат (можно добавлять And/But). |
| And / But | И / Но | Дополнительные условия или исключения. |

### Как это соотносится с RSpec

RSpec не требует Gherkin и не исполняет `.feature`-файлы, но следует тем же смысловым фазам:

- **Given** -> подготовка данных и окружения (`let`, `before`, вспомогательные методы).
- **When** -> действие, которое проверяем (вызов метода, HTTP-запрос, команда).
- **Then** -> ожидаемый результат (`expect`-утверждения).
- **Feature / Story** -> верхний уровень `describe`, задающий область поведения.
- **Scenario** -> `it`, конкретный пример поведения.
- **And / But** -> уточнения условий через вложенные `context`.

Это не механическое соответствие один-к-одному, но такая оптика помогает писать тесты как читабельные спецификации домена. На этой базе построены правила из следующего раздела.

## Глоссарий

- **Поведение** — наблюдаемый результат системы, сформулированный как правило предметной области ("если … то …").

- **Характеристика** — доменный аспект, влияющий на исход поведения (роль пользователя, способ оплаты, статус заказа).
  - *Как найти:* спросите «если изменить этот аспект, изменится ли ожидаемый результат?», и убедитесь, что речь идёт о бизнес-факте, а не о технической детали.

- **Состояние характеристики** — конкретный вариант значения характеристики, важный для правила (подписка активна, баланс ниже лимита).
  - *Как выделить:* сгруппируйте возможные значения в доменные диапазоны и сформулируйте их короткими утверждениями.
  - *Типы состояний:*
    - бинарные (да/нет: карта привязана ↔ не привязана);
    - множественные (enum: роль = admin / manager / guest);
    - диапазоны (число/дата: баланс ≥ стоимость / баланс < стоимость).

- **Контекст (`context`)** — блок, фиксирующий одно или несколько состояний характеристик. Контекст отвечает за «Given»-часть спецификации.
  - **Положительный контекст** — состояние выполняется (обычно часть happy path).
  - **Отрицательный контекст** — состояние нарушено или отрицается (часто часть corner case).
  - **Вложенный контекст** — уточняет внешний, добавляя состояние новой характеристики или уточняя текущую.

- **Кейс / пример (`it`)** — минимальный сценарий, проверяющий конкретное поведение на выбранном наборе состояний.
  - **Happy path case** — основной поток: ожидаемый успех без исключений.
  - **Corner case** — отклонение от основного потока: крайние значения, ошибки, исключительные ситуации.
  - **Положительный тест** — пример подтверждает поведение (чаще совпадает с happy path).
  - **Отрицательный тест** — пример показывает отказ или защиту от некорректного поведения (часто совпадает с corner case).
  - *Важно:* happy/corner описывают тип кейса, а положительный/отрицательный — результат проверки. При множественных состояниях возможно несколько happy path кейсов без отрицательных тестов на этой характеристике.

- **Настройка контекста** — подготовка данных или окружения (через `let`, `before`, вспомогательные методы), делающая состояние характеристики истинным. Должна находиться сразу под соответствующим `context`.

```
| Тип кейса        | Тип контекстов внутри            | Результат теста       |
| ---------------- | -------------------------------- | --------------------- |
| Happy path case  | Положительные контексты          | Положительный тест    |
| Corner case      | Отрицательные / уточняющие контексты | Отрицательный тест / защита |
```

Таблица отражает типичную связь, но возможны исключения — например, enum-характеристика может включать несколько happy path кейсов без отрицательных тестов, или corner case может завершаться положительным результатом (например, graceful degradation).

# RSpec style guide
### 1. Тестируйте поведение, а ни реализацию.

Если в вашем тесте нет описания поведения, то это не тест. Почему? При отсутствии описания поведения возникает привязка
к реализации, когда после вас кто-то будет смотреть тесты - он ничего не поймет и тесты окажутся бесполезными.
###### далее `some_action` в примерах - это псевдокод, который мы тестируем и поведение которого мы описываем
```ruby
# очень плохой пример кода
describe "#some_action" do
  # ... создаем пользователя, но не связываем подготовку с описанием контекста
  it "true" do          # из этого описания не понятно, что означает факт того, что мы ожидаем `true`
    expect { some_action }.to eq true
  end
end

# хороший пример кода
describe "#some_action" do
  # ... создаем пользователя и явно подготавливаем характеристику, о которой говорим в `it`
  it "allows unlocking the user" do         # это описание рассказывает нам о том, что означает наше ожидание от кода
    expect { some_action }.to eq true
  end
end
```

Или, например, используйте `match_array`, когда пишите ожидание для массива, порядок значений в котором вам не важен.
```ruby
# плохо
expect(some_action).to eq [1, 2, 3] # pass
# хорошо
expect(some_action).to match_array [2, 3, 1] # pass
```
Представим что `some_action` возвращал всегда `[1, 2, 3]` и ваши тесты проходили,
потом вы внесли какие-то изменения в код, обновили базу данных и т.д. То есть по какой-то причине порядок в массиве изменился,
например, он стал `[2, 1, 3]`,
и у вас начала падать дюжина тестов. И все это произошло из-за вашей привязки к реализации!
Не делайте так, тестируйте конкретное поведение.
Если это выборка данных, то проверяйте факт правильной выборки данных.

В целом, каждый раз как вы работаете с любой коллекцией (массивы, хеши, ActiveRecord::Relation ...)
и используете `eq`, то это звоночек, что вы делаете что-то не так. Возможно существует хелпер из библиотеки `RSpec Expectations`, подходящий
для определения вашего ожидания, а возможно вы в принципе не то тестируете (не поведение вашего кода) или даже не то реализуете.

### 2. Выделяйте характеристики поведения и их состояния

**Характеристика** — доменный аспект, который влияет на исход проверяемого поведения (роль пользователя, способ оплаты, статус заказа).

**Состояние характеристики** — конкретный вариант этой характеристики, который важен для правила (подписка активна, баланс меньше лимита, статус = shipped).

Как понять, что вы нашли характеристику:

- задайте вопрос: «если изменить этот аспект, ожидание примера изменится?»;
- характеристика описывает бизнес-факт, а не реализацию (`user has subscription`, а не `premium_flag`);
- характеристика формулируется как сущность с уточнением (`user role`, `card balance`).

Как подобрать состояния:

- перечислите все варианты, которые различает бизнес (роль = admin / customer; статус = draft / paid / cancelled);
- числовые величины группируйте в диапазоны, которые влияют на решение (баланс ≥ стоимость, баланс < стоимость);
- каждое состояние выражайте отдельным `context` с ясной формулировкой.

### 3. Стройте иерархию `context` по зависимостям характеристик (happy path → corner cases)

Характеристики могут быть:

- **базовыми** — без них остальные не имеют смысла (нет карты → нет баланса);
- **уточняющими** — уточняют базовую характеристику (баланс карты при наличии карты);
- **независимыми** — не влияют друг на друга (роль пользователя и флаг beta-теста).

Алгоритм:

1. Выпишите характеристики и состояния.
2. Отметьте зависимости: характеристика B зависит от A, если её состояние осмысленно только при конкретном состоянии A.
3. Постройте таблицу иерархии.
4. Для каждой ветки создайте вложенные `context` от базовой к уточняющей, упорядочив состояния: сначала happy path (нормальный сценарий), затем corner cases (отклонения).

#### Зависимые характеристики (бинарная характеристика)

| Характеристика | Состояния, которые тестируем | Зависит от |
| --- | --- | --- |
| Привязка карты | has card / has NO card | — |
| Баланс карты | balance ≥ price / balance < price | Привязка карты (has card) |

```ruby
describe '#purchase' do
  context 'when user has a payment card' do               # happy path: карта привязана
    context 'and card balance covers the price' do        # happy path: баланс достаточен
      it 'charges the card'
    end

    context 'but card balance does NOT cover the price' do # corner case: денег не хватило
      it 'rejects the purchase'
    end
  end

  context 'when user has NO payment card' do              # corner case: карты нет
    it 'rejects the purchase'
  end
end
```

> Антипример: если вынести уточняющую характеристику на верхний уровень, контекст перестанет быть самодостаточным и потеряет связь с базовым условием.
>
> ```ruby
> # плохо
> describe '#purchase' do
>   context 'but card balance does NOT cover the price' do
>     it 'rejects the purchase'
>   end
>
>   context 'when user has a payment card' do
>     context 'and card balance covers the price' do
>       it 'charges the card'
>     end
>   end
> end
> ```

#### Независимые характеристики (enum + бинарная характеристика)

| Характеристика | Состояния, которые тестируем | Зависит от |
| --- | --- | --- |
| Роль пользователя | admin / customer | — |
| Флаг beta-доступа | enabled / disabled | — |

```ruby
describe '#feature_access' do
  context 'when user role is admin' do        # happy path: полный доступ
    it 'grants access to admin tools'

    context 'and beta feature is enabled' do  # happy path: бонусный доступ
      it 'grants access to beta tools'
    end

    context 'but beta feature is disabled' do # corner case для admin
      it 'falls back to standard tools'
    end
  end

  context 'when user role is customer' do     # corner case: ограниченные права
    it 'denies access to admin tools'

    context 'and beta feature is enabled' do  # corner case: частичное смягчение
      it 'grants access to beta tools'
    end

    context 'but beta feature is disabled' do # самый строгий corner case
      it 'denies access to beta tools'
    end
  end
end
```

Порядок независимых характеристик можно менять (сначала флаг, потом роль), но happy path должен оставаться выше, а отклонения — группироваться ниже на соответствующем уровне вложенности.

### 4. Располагайте happy path перед corner cases

Внутри каждого `describe` читающий ожидает увидеть нормальное поведение первым, а уже затем — исключения. Такой порядок снижает когнитивную нагрузку: мы быстро убеждаемся, что система делает «как надо», и только потом разбираем, что происходит, когда что-то идет не так.

Антипример (нарушен порядок, хотя сами формулировки корректны):

```ruby
# плохо: corner cases выше happy path
describe '#enroll' do
  context 'when enrollment is rejected because email is invalid' do
    it 'shows a validation error'
  end

  context 'when enrollment is rejected because plan is sold out' do
    it 'puts the user on the waitlist'
  end

  context 'when enrollment is accepted' do # happy path затерян внизу
    it 'activates the membership'
  end
end
```

Правильный порядок:

```ruby
# хорошо: happy path сверху, затем corner cases
describe '#enroll' do
  context 'when enrollment is accepted' do
    it 'activates the membership'
  end

  context 'when enrollment is rejected because email is invalid' do
    it 'shows a validation error'
  end

  context 'when enrollment is rejected because plan is sold out' do
    it 'puts the user on the waitlist'
  end
end
```

Инструкция: добавляя новые примеры, проверьте, что блоки happy path остаются первыми на своем уровне вложенности. Corner cases должны находиться ниже и либо начинаться с `but`/`without`, либо явно описывать отклонение.

### 5. Пишите положительный и отрицательный тест

Каждая ветка контекстов описывает конкретное сочетание состояний характеристик. Для этих сочетаний нужен минимум один пример, подтверждающий поведение, и один пример, показывающий отказ — так мы защищаемся от регрессий в обе стороны.

```ruby
# Плохо
describe "#some_action" do
  # ... базовая настройка характеристик: пользователь, роль, дата блокировки
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when user is blocked by admin" do # положительный контекст для состояния характеристики `blocked`
    # ... настройка состояния `blocked = true`
    let(:blocked) { true }

    context "and blocking duration is over a month" do # положительный контекст для состояния характеристики `blocked_at`
      # ... настройка уточняющей характеристики `blocked_at`
      let(:blocked_at) { 2.month.ago }

      it "allows unlocking the user" do
        expect { some_action }.to eq true # положительный тест для сочетания состояний характеристик `blocked`, `blocked_at`
      end
    end
  end
end

# хорошо
describe "#some_action" do
  # ... базовая настройка характеристик: пользователь, роль, дата блокировки
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }
  
  context "when user is blocked by admin" do # положительный контекст для состояния характеристики `blocked`
    # ... настройка состояния характеристики `blocked`
    let(:blocked) { true }

    # Контекст 2 уровня для состояния характеристики `blocked_at`
    context "and blocking duration is over a month" do # положительный контекст для состояния характеристики `blocked_at`
      # ... состояние уточняющей характеристики `blocked_at`
      let(:blocked_at) { 2.month.ago }

      it "allows unlocking the user" do
        expect { some_action }.to eq true # положительный тест для сочетания состояний характеристик `blocked`, `blocked_at`
      end
    end

    context "but blocking duration is under a month" do # отрицательный контекст для состояния характеристики `blocked_at`
      # ... состояние уточняющей характеристики `blocked_at`
      let(:blocked_at) { 1.month.ago }

      it "does NOT allow unlocking the user" do
        expect { some_action }.to eq false # отрицательный тест для состояния характеристики `blocked_at`
      end
    end
  end

  context "when user is NOT blocked by admin" do # отрицательный контекст для состояния характеристики `blocked`
    # ... настройка состояния характеристики `blocked`
    let(:blocked) { false }

    it "does NOT allow unlocking the user" do
      expect { some_action }.to eq false # отрицательный тест для состояния характеристики `blocked_at`
    end
  end
end
```
Если присутствуют только положительные тесты, то в дальнейшем на такие тесты нельзя полагаться,
ввиду того, что они не отразят факта регрессии поведения при дальнейших изменениях в коде,
так как они не будут проверять обратный случай.

### 6. Каждый тестовый кейс должен быть в своем `it`

```ruby
# плохо
it "creates a user" do
  expect { some_action }.to change(User, :count)
  expect { some_action }.to have_attributes(name: "Jim", age: 32)
  # два ожидания в одном тесте, если первое ожидание в списке не пройдет,
  # то в описании ошибки мы увидим только первую ошибку
  # и не будем знать, работает ли следующее ожидание
end

# хорошо
it "changes the user count" do
  expect { some_action }.to change(User, :count)
end

it "creates a user with attributes" do
  expect { some_action }.to have_attributes(name: "Jim", age: 32)
end

# ещё лучше для данного примера
describe some_action do
  it { is_expected.to change(User, :count)}
  it { is_expected.to have_attributes(name: "Jim", age: 32)}
  # здесь описание ожидания генерируется автоматически из помощников change и have_attributes, но такой подход не всегда
  # хорош, иногда помощники не могут сгенерировать правильный текст вашего ожидания,
  # иначе говоря, это не подходит для случаев с описанием сложного поведения
end
```
Кто-то может сказать, что это накладно по ресурсам и лучше совмещать многие тесты в один `it`.

Да, действительно, это ускорит тесты по нескольким причинам:

1. Ожидания в одном `it` не изолированы друг от друга, из-за чего тестовые данные создаются для них один раз, что быстрее,
   чем создавать их много раз для каждого ожидания;
2. При падении первого ожидания, следующие не проверяются, что тоже экономит время.

Но смотрите к каким недостаткам это приводит:
1. Это делает менее читаемыми результаты тестов (вывод в консоли);
2. Это делает менее читаемым сам тест, его ожидания;
3. Будет не вполне понятно, какое именно ожидание соответствует описанию поведения в `it`;
4. Отсутствие изоляции делает менее надежными ожидания, они могут начать друг на друга влиять (но такое очень редко бывает);
5. Самое важное, что это может быть запахом плохого дизайна кода, который покрывается данными тестами.

   Если вы делаете ожидания на несколько разных вещей, то получается что ваш код делает тоже несколько разных вещей,
   а это нарушает данное правило:
    ```markdown
    Do One Thing
    
    FUNCTIONS SHOULD DO ONE THING. THEY SHOULD DO IT WELL.
    THEY SHOULD DO IT ONLY.
    
    * Clean Code Robert Martin
    ```
   Как видите, тестирование поведения отражает поведение самого кода и его изъяны. Если ваши тесты стали "слишком умными",
   то наверняка из-за того, что таковым является тестируемый код. Попробуйте разделить код на более простые части и
   тестировать их поведение отдельно, напишите сначала модульные тесты на каждую маленькую часть, покрывая их отдельное поведение.
   Потом напишите код, который будет использовать эти маленькие части, и уже для него напишие один простой интеграционный тест,
   а в нем проверяйте ожидаемое поведение, не привязываясь к деталям и поведению маленьких частей кода, которыми он пользуется.


### 7. Описание контекстов `context` и тестовых кейсов `it` вместе (включая `it`) должны составлять валидное предложение на английском языке.

Для примера оставим только описание тестов, без примера создания тестовых данных и изменений в контекстах:
```ruby
# отвратительно
describe "#some_action" do
  context "blocked" do # что заблокировано, когда, кем? что это вообще значит?
    context "month ago" do # месяц назад что? заблокирован? точно?
      it("true") { test } # что значит true? как оно оценивается?
    end
  end
end
# когда вы запустите тест он вернет вот такое непонятное описание
# #some_action user blocked month ago /it/ true

# идеально
describe "#some_action" do
  context "when user is blocked by admin" do # здесь понятно, кто, что и с кем сделал
    context "and blocking duration is over a month" do # а здесь уже понятно что это продолжение предложения, начатого в прошлом контексте
      it("allows unlocking the user") { test } # ага, теперь вообще понятно, зачем этот метод нужен, в чем его ценность
      # он определяет "можно ли разблокировать пользователя?"
    end
  end
end
# #some_action when user is blocked by admin and blocking duration is over a month /it/ allows unlocking the user 
```

### 8. Описание контекстов `context` и тестовых кейсов `it` вместе (включая `it`) должны быть написаны так, чтобы их понимал любой человек

Здесь имеется ввиду, что описание поведения должно быть абсолютно однозначно понятным и не требующим познания чего-то специфичного из программирования.
Вы должны быть в состоянии просто дать все описания тестов любому человеку, для того чтобы он в свою очередь прочитав их мог понять бизнес.

```
when user is blocked by admin and blocking duration is over a month /it/ allows unlocking the user
when user is blocked by admin but blocking duration is under a month /it/ does NOT allow unlocking the user
```
вполне понятное описание, по которому однозначно понятно, что разблокировать пользователя заблокированного менее месяца назад нельзя.

### 9. Каждый тест должен быть разделен на 3 этапа в строгой последовательности
1. Предварительное создание тестовых данных
2. Действие или предварительные вычисления над подготовленными тестовыми данными (необязательный этап)
3. Ожидание
```ruby
# отвратительно
describe "#block" do
  before do
    user = create :user # тестовые данные
    admin = create :admin # тестовые данные
    admin.block(user) # действие
  end
  
  it "true" do
    expect(User.find(1).bloсked).to eq true # ожидание
  end
end

# хорошо
describe "#block" do
  # 1 этап
  let(:user) { create :user } # создание тестовых данных 
  let(:admin) { create :admin }
  
  # 2 этап
  before { admin.block(user) } # действие/операция

  # 3 этап
  it "marks the user as blocked" do
    expect(user.blocked).to eq true # ожидание
  end
end
# или
describe "#block" do
   # 1 этап
   let(:user) { create :user } # создание тестовых данных
   let(:admin) { create :admin }
   
   it "marks the user as blocked" do
      # 2 этап
      admin.block(user) # действие/операция

      # 3 этап
      expect(user.blocked).to eq true # ожидание
   end
end
# но лучше по возможности переносить действие и любые runtime вычисления в before.
```

### 10. Каждый контекст должен отражать различие вложенной части от внешней

Можно ещё сказать так: если у вас есть контекст, внутри которого между `context "..." do` и `it` пусто, это чисто
синтаксический контекст. Он либо не нужен вовсе, либо не содержит настройки, соответствующей описанию контекста.

Правило можно сформулировать иначе: настройка, которая делает контекст истинным, должна находиться сразу после строки `context "..." do`.
Не заставляйте читателя искать по всему тесту, где именно выполняется подготовка под указанное состояние.

```ruby
# Есть пользователи и метод some_action, позволяющий определить, можно ли пользователя разблокировать.
# У пользователей есть состояния `blocked`, `blocked_at`.

# плохо
describe "#some_action" do
  let(:user) { build :user }
  let(:blocked_user) { build :user, blocked: true }
  let(:old_blocked_user) { build :user, blocked: true, blocked_at: 2.month.ago }

  it "does NOT allow unlocking the user" do
    expect { user.some_action }.to eq false
  end
  
  context "when user is blocked by admin" do # есть контекст
    # нет никакой настройки, которая делает его отличным от внешнего блока
    it "allows unlocking the user" do
      expect { blocked_user.some_action }.to eq false
    end
    
    context "and blocking duration is over a month" do 
      # Что отличает этот контекст от внешнего? В большом тесте искать настройку будет невозможно.
      # Экономьте свой и чужой труд — размещайте подготовку сразу под контекстом, там её все и ожидают увидеть.
      it "allows unlocking the user" do
        expect { old_blocked_user.some_action }.to eq true
      end
    end
  end
end

# хорошо
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  it "does NOT allow unlocking the user" do
    expect { user.some_action }.to eq false
  end
  
  context "when user is blocked by admin" do
    let(:blocked) { true } # настройка этого контекста — на своём месте, сразу заметна

    it "allows unlocking the user" do
      expect { blocked_user.some_action }.to eq false
    end
    
    context "and blocking duration is over a month" do
      let(:blocked_at) { 2.month.ago } # настройка вложенного контекста — здесь же, под объявлением
      
      it "allows unlocking the user" do
        expect { some_action }.to eq true
      end
    end
  end
end
```

Кроме того, настройка контекста может быть вычислимой операцией — например, располагаться внутри `before`.

### 11. Грамматика формулировок в describe/context/it

Мы описываем устойчивое поведение системы, поэтому формулировки должны звучать как правила предметной области, а не как инструкции тестировщику.

1. **Present Simple.** Поведение считается верным всегда, поэтому говорим о нем в настоящем времени: `it 'returns the summary'`. Настоящее простое время делает фразу универсальной и убирает ощущение временности.
2. **Активный залог в `it`, третье лицо.** Субъектом предложения выступает объект системы: `order generates invoice`, `service authenticates user`. Так читающий понимает, кто выполняет действие, и предложение остается коротким.
3. **Пассивный залог и глаголы-состояния для контекстов.** Контекст задает состояние характеристики, поэтому используем форму `is/are + V3` или короткие конструкции со статичным глаголом: `when user is blocked`, `when account has balance`. Так мы фиксируем факт состояния, а не действие, которое к нему привело.
4. **Zero conditional для связки условия и результата.** В паре `context/it` обе части остаются в Present Simple: `when payment is confirmed, it issues receipt`. Такая структура читается как бизнес-правило «если … то …» без временных сдвигов.
5. **Без модальных глаголов и лишних слов.** Избегаем `should`, `can`, `must` и вводных конструкций (`it should`, `it is expected that`). Остается декларация поведения — она короче и лучше ложится в отчеты.
6. **Явное отрицание `NOT`.** Негативные сценарии выделяем капсом: в контекстах — `when user NOT verified`, в примерах — `it 'does NOT unlock user'`. Так в отчете сразу видно, что падает отрицательный кейс.

Минимальный шаблон: объект и характеристику описываем в `describe`, условия — через `context` в пассивном залоге, ожидаемую реакцию — через `it` в активном Present Simple.

```ruby
describe OrderMailer do
  context 'when invoice is generated' do
    it 'sends the invoice email'
  end
end
```

### 12. Связки when/with/without/and/but в названиях контекстов

Используем короткие глагольные связки, чтобы контексты читались как gherkin-подобные условия.

- `when` — первое условие, открывающее ветку: `context 'when user is blocked'`.
- `with` / `and` — добавляют положительные состояния: `context 'and user has a premium account'`.
- `without` / `but` / `NOT` — фиксируют альтернативное или отрицательное состояние: `context 'but token is NOT valid'`.
- Для зависимых состояний характеристик (логическое «и») используем `and/with` и проверяем обе полярности во вложенных контекстах.

```ruby
describe '#some_action' do
  context 'when user is created more than a month ago' do
    context 'and account is premium' do
      it 'allows some_action'
    end

    context 'and account is NOT premium' do
      it 'denies some_action'
    end
  end
end
```


### 13. Не используйте [any_instance](https://relishapp.com/rspec/rspec-mocks/v/3-10/docs/old-syntax/any-instance), allow_any_instance_of, expect_any_instance_of

В большинстве случаев это "запах" к тому, что вы не следуете `dependency inversion principle`,
или, что ваш класс не следует `single responsibility` и объединяет в себе код для двух акторов,
которые в свою очередь зависят друг от друга в одностороннем порядке.
Таким образом, ваш класс можно разбить на два класса поменьше, для которых в свою очередь можно покрыть тестами их поведение в отдельных тестах.
Справедливости ради, следовать этому правилу не очень просто тогда, когда у вас накопился гигантский технический долг, поэтому это правило может иметь исключения.

Подробнее о том, почему его не стоит использовать читайте здесь https://relishapp.com/rspec/rspec-mocks/docs/working-with-legacy-code/any-instance.
```ruby
# плохо
class HighLevelClass
   def some_method
      data = LowLevelClass.foo

      data.uniq.select { some code }.map { some code }
   end
end

describe HighLevelClass do
   let(:some_data) { build :some_data }

   before do
      allow_any_instance_of(LowLevelClass).to receive(:foo).and_return({some_key: :some_value}) # замокали все обьекты этого класса глобально
   end

   it "returns the processed value" do
      expect(HighLevelClass.new.some_method).to eq(:some_expected_value)
   end
end

# хорошо
class HighLevelClass
   def initialize(low_level_dependency = LowLevelClass)
      @low_level_dependency = low_level_dependency # Произвели инверсию зависимости
   end

   def some_method
      data = low_level_dependency.foo

      data.uniq.select { some code }.map { some code }
   end
end

describe HighLevelClass do
   let(:some_data) { build :some_data }
   let(:low_level_dependency) { instance_double(LowLevelClass) }
   let(:instanse) { HighLevelClass.new(low_level_dependency) } # теперь зависимость можно просто подставить через new

   before do
      allow(low_level_dependency).to receive(:foo).and_return({some_key: :some_value})
      # теперь мы просто разрешаем вернуть нужное нам значение одному instance double,
      # причем будет проверка что такой метод действительно есть у данного класса.
      # таким образом при рефакторинге интерфейса класса, данный тест может предупредить сломанную зависимость других классов
   end

   it "returns the processed value" do
      expect(instanse.some_method).to eq(:some_expected_value)
   end
end
```
### 14. Используйте :aggregate_failures флаг, если складываете несколько ожиданий в один контекст для оптимизации производительности.

```ruby
# Хорошо - одно ожидание за example(it)
describe ArticlesController do
  #...

  describe 'GET new' do
    it 'assigns a new article' do
      get :new
      expect(assigns[:article]).to be_a(Article)
    end

    it 'renders the new article template' do
      get :new
      expect(response).to render_template :new
    end
  end
end

# Плохо, если упадет одно ожидание - остальные не проверятся, traceback будет не подробным
describe ArticlesController do
  #...

  describe 'GET new' do
    it 'assigns new article and renders the new article template' do
      get :new
      expect(assigns[:article]).to be_a(Article)
      expect(response).to render_template :new
    end
  end

  # ...
end

# Хорошо - несколько ожиданий в одном example
describe ArticlesController do
  #...

  describe 'GET new', :aggregate_failures do
    it 'assigns new article and renders the new article template' do
      get :new
      expect(assigns[:article]).to be_a(Article)
      expect(response).to render_template :new
    end
  end

  # ...
end
```
### 15. Изучите подробно правила из rubocop по части наименования https://rspec.rubystyle.guide/#naming
