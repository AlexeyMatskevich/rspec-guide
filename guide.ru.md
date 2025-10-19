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

# RSpec style guide
### 1. Тестируйте поведение, а ни реализацию.

Если в вашем тесте нет описания поведения, то это не тест. Почему? При отсутствии описания поведения возникает привязка
к реализации, когда после вас кто-то будет смотреть тесты - он ничего не поймет и тесты окажутся бесполезными.
###### далее `some_action` в примерах - это псевдокод, который мы тестируем и поведение которого мы описываем
```ruby
# очень плохой пример кода
describe "#some_action" do
  # ... build test data
  it "true" do          # из этого описания не понятно, что означает факт того, что мы ожидаем `true`
    expect { some_action }.to eq true
  end
end

# хороший пример кода
describe "#some_action" do
  # ... build test data
  it "allow to unlock a user" do         # это описание рассказывает нам о том, что означает наше ожидание от кода
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

### 2. Каждое свойство вашего поведения должно отражаться отдельным контекстом `context` и эти контексты должны быть на разных уровнях вложенности

Под `свойство` имется ввиду что-либо, что влияет на поведение тестирумого кода. Например, если у нас есть пользователи и у них есть карточка с деньгами, то в контексте способности купить товар у нас может быть 2 свойства:
1. Наличие привязанной карточки
2. Наличие на привязанной карточке денег

Вполне очевидно, какое свойство является главным, а какое зависимым, соответственно понятно, что будет в верхнеуровневом контесте при описании поведения в тестах, а что во вложенном.
`context "when user have card"; context "and card has enough money"`

```ruby
# Есть пользователи и метод some_action, позволяющий определить можно ли пользователя разблокировать. 
# У пользователя есть свойства `blocked`, `blocked_at`.
# плохо
describe "#some_action" do
  let(:user) { build :user, blocked: true, blocked_at: Time... }
  # здесь мы видим 2 свойства, как они влияют на наш метод нам не понятно
  
  it "true" do
    expect { some_action(user) }.to eq true
  end
end
# из этого теста ничего не понятно

# хорошо
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }
  # здесь мы видим 2 свойства, как они влияют на наш метод нам не понятно, но мы уже видим что здесь предполагается наличие 2-х переменных
  
  # Контекст 1-го уровня для свойства `blocked`
  context "when admin blocked user" do # здесь мы вводим свойство `blocked` в описание поведения метода `some_action`
    let(:blocked) { true }
    # сразу под определением контекста мы видим определение свойства, именование которого соответствует упомянутому свойству в контексте

    # Контекст 2-го уровня для свойства `blocked_at`, который вложен в контекст 1 уровня
    context "but it's been over a month" do # здесь мы вводим свойство `blocked_at` в описание поведения метода `some_action`
      let(:blocked_at) { 2.month.ago }
      # сразу под определением контекста мы видим определение свойства, именование которого соответствует упомянутому свойству в контексте
       
      it "allow to unlock a user" do
        expect { some_action }.to eq true
      end
    end
  end
end
```
### 3. Пишите положительный и отрицательный тест
```ruby
# Плохо
describe "#some_action" do
  # ... build test data as general context for tests
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when admin blocked user" do # положительный контекст для свойства `blocked`
    # ... build test data reflecting the difference in the behavior described in the context from the higher context
    let(:blocked) { true }

    context "but it's been over a month" do # положительный контекст для свойства `blocked_at`
      # ... build test data reflecting the difference in the behavior described in the context from the higher context
      let(:blocked_at) { 2.month.ago }

      it "allow to unlock a user" do
        expect { some_action }.to eq true # положительный тест для свойств `blocked`, `blocked_at`
      end
    end
  end
end

# хорошо
describe "#some_action" do
  # ... build test data as general context for tests
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }
  
  context "when admin blocked user" do # положительный контекст для свойства `blocked`
    # ... build test data reflecting the difference in the behavior described in the context from the higher context
    let(:blocked) { true }

    # Контекст 2 уровня для свойства `blocked_at`
    context "but it's been over a month ago" do # положительный контекст для свойства `blocked_at`
      # ... build test data reflecting the difference in the behavior described in the context from the higher context
      let(:blocked_at) { 2.month.ago }

      it "allow to unlock a user" do
        expect { some_action }.to eq true # положительный тест для свойств `blocked`, `blocked_at`
      end
    end

    context "but it's been less than a month yet" do # отрицательный контекст для свойства `blocked_at`
      let(:blocked_at) { 1.month.ago }

      it "allow to unlock a user" do
        expect { some_action }.to eq true # отрицательный тест для свойства `blocked_at`
      end
    end
  end

  context "when admin NOT blocked user" do # отрицательный контекст для свойства `blocked`
    let(:blocked) { true }

    it "NOT allow to unlock a user" do
      expect { some_action }.to eq false # отрицательный тест для свойства `blocked_at`
    end
  end
end
```
Если присутствуют только плоложительные тесты, то в дальнейшем на такие тесты нельзя полагаться,
ввиду того, что они не отразят факта регрессии поведения при дальнейших изменениях в коде,
так как они не будут проверять обратный случай.

### 4. Каждый тестовый кейс должен быть в своем `it`

```ruby
# плохо
it "create user" do
  expect { some_action }.to change(User, :count)
  expect { some_action }.to have_attributes(name: "Jim", age: 32)
  # два ожидания в одном тесте, если первое ожидание в списке не пройдет,
  # то в описании ошибки мы увидим только первую ошибку
  # и не будем знать, работает ли следующее ожидание
end

# хорошо
it "change user count" do
  expect { some_action }.to change(User, :count)
end

it "create user with attributes" do
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


### 5. Описание контестов `context` и тестовых кейсов `it` вместе и включая `it` должны составлять валидное предложение на английском языке.

Для примера оставим только описание тестов, без примера создания тестовых данных и измнений в контекстах:
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
  context "when admin blocked user" do # здесь понятно, кто, что и с кем сделал
    context "but it's been over a month ago" do # а здесь уже понятно что это продолжение предложения, начатого в прошлом контексте
      it("allow to unlock a user") { test } # ага, теперь вообще понятно, зачем этот метод нужен, в чем его ценность
      # он определяет "можно ли разблокировать пользователя?"
    end
  end
end
# #some_action when admin blocked user but it's been over a month ago /it/ allow to unlock a user 
```

### 6. Описание конкестов `context` и тестовых кейсов `it` вместе и включая `it` должны написаны быть так, что бы их понимал любой человек

Здесь имеется ввиду, что описание поведения должно быть абсолютно однозначно понятным и не требующим познания чего-то специфичного из программирования.
Вы должны быть в состоянии просто дать все описания тестов любому человеку, для того чтобы он в свою очередь прочитав их мог понять бизнес.

```
when admin blocked user but it's been over a month ago /it/ allow to unlock a user
when admin blocked user but it's been less than a month yet /it/ NOT allow to unlock a user
```
вполне понятное описание, по которому однозначно понятно, что разблокировать пользователя заблокированного менее месяца назад нельзя.

### 7. Каждый тест должен быть разделен на 3 этапа в строгой последовательности
1. Предварительное создание тестовых данных
2. Действие или предватилеьные вычисления над предварительными тестовыми данными (необязательный этап)
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
  it "blocked user" do
    expect(user.blocked).to eq true # ожидание
  end
end
# или
describe "#block" do
   # 1 этап
   let(:user) { create :user } # создание тестовых данных
   let(:admin) { create :admin }
   
   it "blocked user" do
      # 2 этап
      admin.block(user) # действие/операция

      # 3 этап
      expect(user.blocked).to eq true # ожиданиe
   end
end
# но лучше по возможности переносить действие и любые runtime вычисления в before.
```

### 8. Каждый контекст должен отражать различие вложенной части от внешней

Можно ещё сказать так, если у вас есть контекст внутри которого между `context "..." do` и `it` пусто - то это чисто
синтаксический контекст и он либо не нужен вовсе, либо не отражает изменения, соотвествующие описанию контекста.

Ещё можно назвать это правило так - изменения, соответствующие описанию контекста, должны быть в четко определенном
месте - сразу после `context "..." do`. Не надо писать тесты так, чтобы потом приходилось искать в каком месте происходят
изменения соответствующие описанию контекста.

```ruby
# Есть пользователи и метод some_action, позволяющий определить, можно ли пользователя разблокировать.
# У пользователей есть свойства `blocked`, `blocked_at`.

# плохо
describe "#some_action" do
  let(:user) { build :user }
  let(:blocked_user) { build :user, blocked: true }
  let(:old_blocked_user) { build :user, blocked: true, blocked_at: 2.month.ago }

  it "NOT allow to unlock a user" do
    expect { user.some_action }.to eq false
  end
  
  context "when admin blocked user" do # есть контекст
    # нет никаких изменений, где они?
    it "allow to unlock a user" do
      expect { blocked_user.some_action }.to eq false
    end
    
    context "but it's been over a month" do 
      # Что же этот контекст отличает от внешнего? помножьте это на 300 строчный тест и вы поймете проблему поиска изменений
      # экономьте свой и чужой труд, пишите изменения сразу под контекстом, там его ожидают все увидеть.
      it "allow to unlock a user" do
        expect { old_blocked_user.some_action }.to eq true
      end
    end
  end
end

# хорошо
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  it "NOT allow to unlock a user" do
    expect { user.some_action }.to eq false
  end
  
  context "when admin blocked user" do
    let(:blocked) { true } # измения этого контекста - вот они, сразу брасаются в глаза, на своем месте

    it "allow to unlock a user" do
      expect { blocked_user.some_action }.to eq false
    end
    
    context "but it's been over a month" do
      let(:blocked_at) { 2.month.ago } # измения этого контекста - вот они, сразу брасаются в глаза, на своем месте
      
      it "allow to unlock a user" do
        expect { some_action }.to eq true
      end
    end
  end
end
```

Кроме того, изменения в контексте могут быть вычислимыми, являться какой-то операцией/действием т.е. внутри `before`

### 9. Грамматика формулировок в describe/context/it

Мы описываем устойчивое поведение системы, поэтому формулировки должны звучать как правила предметной области, а не как инструкции тестировщику.

1. **Present Simple.** Поведение считается верным всегда, поэтому говорим о нем в настоящем времени: `it 'returns the summary'`. Настоящее простое время делает фразу универсальной и убирает ощущение временности.
2. **Активный залог в `it`, третье лицо.** Субъектом предложения выступает объект системы: `order generates invoice`, `service authenticates user`. Так читающий понимает, кто выполняет действие, и предложение остается коротким.
3. **Пассивный залог и глаголы-состояния для контекстов.** Контекст задает состояние, поэтому используем форму `is/are + V3` или короткие конструкции со статичным глаголом: `when user is blocked`, `when account has balance`. Так мы фиксируем факт состояния, а не действие, которое к нему привело.
4. **Zero conditional для связки условия и результата.** В паре `context/it` обе части остаются в Present Simple: `when payment is confirmed, it issues receipt`. Такая структура читается как бизнес-правило «если … то …» без временных сдвигов.
5. **Без модальных глаголов и лишних слов.** Избегаем `should`, `can`, `must` и вводных конструкций (`it should`, `it is expected that`). Остается декларация поведения — она короче и лучше ложится в отчеты.
6. **Явное отрицание `NOT`.** Негативные сценарии выделяем капсом (`when user NOT verified`), чтобы в выводе тестов сразу увидеть, что сломался отрицательный кейс.

Минимальный шаблон: объект/состояние описываем в `describe`, условия — через `context` в пассивном залоге, ожидаемую реакцию — через `it` в активном Present Simple.

```ruby
describe OrderMailer do
  context 'when invoice is generated' do
    it 'sends the invoice email'
  end
end
```

### 10. Связки when/with/without/and/but в названиях контекстов

Используем короткие глагольные связки, чтобы контексты читались как gherkin-подобные условия.

- `when` — первое условие, открывающее ветку: `context 'when user is blocked'`.
- `with` / `and` — добавляют положительные свойства: `context 'and user has a premium account'`.
- `without` / `but` / `NOT` — фиксируют альтернативное или отрицательное свойство: `context 'but token NOT valid'`.
- Для зависимых свойств (логическое «и») используем `and/with` и проверяем обе полярности во вложенных контекстах.

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


### 11. Не используйте [any_instance](https://relishapp.com/rspec/rspec-mocks/v/3-10/docs/old-syntax/any-instance), allow_any_instance_of, expect_any_instance_of

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

   it "some behavior" do
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

   it "some behavior" do
      expect(instanse.some_method).to eq(:some_expected_value)
   end
end
```
### 12. Используйте :aggregate_failures флаг, если складываете несколько ожиданий в один контекст для оптимизации производительности.

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
### 13. Изучите подробно правила из rubocop по части наименования https://rspec.rubystyle.guide/#naming
