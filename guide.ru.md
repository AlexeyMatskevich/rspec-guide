# Что можно изучить по тестам

[Better Specs](https://www.betterspecs.org) - набор best practice как надо (и как не надо) писать тесты.

[Testing For Beginners](http://testing-for-beginners.rubymonstas.org/index.html) – хорошая книга про тестерование в ruby

[Очень хорошее видео](https://www.pluralsight.com/courses/rspec-ruby-application-testing), где предельно понятно на примере небольшой игры в карты объясняется как правильно пользоваться rspec, что такое BDD, как правильно писать describe, как организовывать ожидания по контекстам, как должен быть организован тест по своим этапах (конфигурация, действие, ожидание). Показывается в том числе собственная миниатюрная реализация rspec для объяснения на пальцах как это все работает. Доступ платный, но есть 10-дневный триал, за который более чем можно успеть изучить курс.

[Everyday Rails Testing with RSpec](https://leanpub.com/everydayrailsrspec) – В качестве библиотеки куда стоит ходить для того чтобы понимать как писать те или иные виды тестов на rspec. Книга относительно свежая, последние правки от 2019 года, там есть объяснения по factory-bot, раскрываются более продвинутые темы по VCR и Webmock. Размер книги 230 страниц, можно её всю изучить за пару дней или за неделю.

# Про RSpec

RSpec - это тестовая библиотека с DSL для описания поведения вашего приложения.

```ruby
describe "my app" do
   it "works" do
      expect(MyApp.working).to eq(true)
   end
end
```

Если вы перейдете на официальный сайт https://rspec.info/ , то вы сами убедитесь в том, как позиционирует себя эта
библиотека:

```text
Behaviour Driven
Development for Ruby
Making TDD Productive and Fun
```

Что такое BDD?

Behavior-driven development, дословно «разработка через поведение» — это методология разработки программного
обеспечения, являющаяся ответвлением от методологии разработки через тестирование (TDD).

А что такое TDD?

Test-driven development — техника разработки программного обеспечения, которая основывается на повторении очень коротких
циклов разработки: сначала пишется тест, покрывающий желаемое поведение, затем пишется код, который позволит пройти
тест, и под конец проводится рефакторинг нового кода к соответствующим стандартам.

Оказывается, использование RSpec предполагает следование BDD, а он, в свою очередь, TDD, и уже это ведет к тому, что RSpec
предполагает сначала написание тестов, а уже потом реализацию.

![bdd_development_flow.png](bdd_development_flow.png)

### Про BDD

BDD - это концепция, подразумевающая разработку через описывание поведения предметной области.

Этот подход хорош тем, что позволяет добиться разделения разработки от бизнеса в результате чего вам, как специалисту
в области разработки, становится проще взаимодействовать с бизнесом или, иначе говоря, с предметной областью.
```
Предметная область - объект вашей программисткой деятельности, некая область знаний и правил логику которых требуется определить в коде.
Так как ваш проект это бизнес, то предметная область для вас, чаще всего, бизнес вашего проекта,
но иногда просто конкретная предметная область, например биллинг или база данных. 
```

Так происходит за счет того, что вы используете человеческий язык для описания поведения.
```
Когда пользователя заблокировал администратор, он не может купить товары
```

При этом не нужно быть специалистом в программировании, чтобы описать поведение или его понять. Таким образом
описание можно составлять вместе с менеджерами, более того, менеджеры вполне способны написать ожидаемое поведение самостоятельно.
При описании наших ожиданий от предметной области, в тесте мы документируем поведение системы, реализующей предметную область.
Одним из преимуществ использования DSL в тестах является тот факт, что при описании поведения происходит структурирование и по итогу
упорядочивание предметной области (далее бизнес).

Использование BDD предполагает использование специального синтаксиса для описания поведения, ниже один из примеров того как это может быть

<tr style="vertical-align:top; text-align:left">
<td>
<div><pre><span></span><span>Story: Returns go to stock</span>

<span>As a store owner</span>
<span>In order to keep track of stock</span>
<span style="color:green">I </span><span>want to add items back to stock when they're
returned.</span>

<span>Scenario </span><span>1</span><span>: Refunded items should be returned to
stock</span>
<span style="color:green">Given </span><span>that a customer previously bought a black sweater from
me</span>
<span style="color:green">And </span><span>I have three black sweaters in stock.</span>
<span style="color:green">When </span><span>they return the black sweater for a refund</span>
<span style="color:green">Then </span><span>I should have four black sweaters in stock.</span>

<span>Scenario </span><span>2</span><span>: Replaced items should be returned to
stock</span>
<span style="color:green">Given </span><span>that a customer previously bought a blue garment from
me</span>
<span style="color:green">And </span><span>I have two blue garments in stock</span>
<span style="color:green">And </span><span>three black garments in stock.</span>
<span style="color:green">When </span><span>they return the blue garment for a replacement in
black</span>
<span style="color:green">Then </span><span>I should have three blue garments in stock</span>
<span style="color:green">And </span><span>two black garments in stock.</span>
</pre></div>
</td>
<td>
<div dir="ltr"><pre><span></span><span>История: Возвращённый товар должен быть учтён на складе</span>

<span>Как владелец магазина</span>
<span>Чтобы следить за запасами на складе</span>
<span>Я хочу восстанавливать записи о товарах, которые возвращаются на склад.</span>

<span>Сценарий </span><span>1</span><span>: Возвращенные товары должны размещаться на
складе</span>
<span>Дано то, что ранее покупатель приобрёл у меня чёрный свитер</span>
<span>И </span><span>на моём складе уже есть три точно таких же.</span>
<span>Когда покупатель возвращает приобретенный свитер</span>
<span>Тогда я должен видеть, что сейчас на складе </span><span>4</span><span> чёрных
свитера.</span>

<span>Сценарий </span><span>2</span><span>: Замененные предметы должны быть возвращены
на склад</span>
<span>Дано то, что клиент приобрёл у меня одежду синего цвета</span>
<span>И </span><span>на моём складе есть два этих наименования синего цвета</span>
<span>И </span><span>три наименования чёрного цвета.</span>
<span>Когда клиент возвращает одежду синего цвета, чтобы заменить на такую же, но чёрную</span>
<span>Тогда я должен видеть, что сейчас на складе три наименования для одежды синего цвета</span>
<span>И </span><span>два наименования для одежды чёрного цвета.</span>
</pre></div>
</td></tr>

Есть пример специального языка для описания поведения в BDD - Cherkin, это все тот же человеческий язык,
хотя предполагается именно английский, в котором предполагается использование определенного синтаксиса

<table>
<caption>Язык Gherkin
</caption>
<tbody><tr>
<th>Ключевое слово на английском языке</th>
<th>Русскоязычная адаптация</th>
<th>Описание
</th></tr>
<tr>
<td><b>Story</b><br>(<b>Feature</b>)</td>
<td>История</td>
<td>Каждая новая спецификация начинается с этого ключевого слова, после которого через двоеточие в сослагательной форме пишется имя истории.
</td></tr>
<tr>
<td><b>As a</b></td>
<td>Как (в роли)</td>
<td>Роль того лица в бизнес-модели, которому данная функциональность интересна.
</td></tr>
<tr>
<td><b>In order to</b></td>
<td>Чтобы достичь</td>
<td>В краткой форме какие цели преследует лицо.
</td></tr>
<tr>
<td><b>I want to</b></td>
<td>Я хочу, чтобы</td>
<td>В краткой форме описывается конечный результат.
</td></tr>
<tr>
<td><b>Scenario</b></td>
<td>Сценарий</td>
<td>Каждый сценарий одной истории начинается с этого слова, после которого через двоеточие в сослагательной форме пишется цель сценария. Если сценариев в одной истории несколько, то после ключевого слова должен писаться его порядковый номер.
</td></tr>
<tr>
<td><b>Given</b></td>
<td>Дано</td>
<td>Начальное условие. Если начальных условий несколько, то каждое новое условие добавляется с новой строки с помощью ключевого слова And.
</td></tr>
<tr>
<td><b>When</b></td>
<td>Когда (<i>прим.</i>: что-то происходит)</td>
<td>Событие, которое инициирует данный сценарий. Если событие нельзя раскрыть одним предложением, то все последующие детали раскрываются через ключевые слова And и But.
</td></tr>
<tr>
<td><b>Then</b></td>
<td>Тогда</td>
<td>Результат, который пользователь должен наблюдать в конечном итоге. Если результат нельзя раскрыть одним предложением, то все последующие детали раскрываются через ключевые слова And и But.
</td></tr>
<tr>
<td><b>And</b></td>
<td>И</td>
<td>Вспомогательное ключевое слово, аналог конъюнкции.
</td></tr>
<tr>
<td><b>But</b></td>
<td>Но</td>
<td>Вспомогательное ключевое слово, аналог отрицания.
</td></tr>
</tbody></table>
Все это является полуформальным, и RSpec не следует какому-то определенному языку, тем не менее требуется использовать ограниченный набор предложений, о котором стоит заранее договорится.  

#### В чем преимущества BDD?

1. Тесты, понятные не только для программистов, но и для людей, у которых нет квалификации в информатике.
2. Они легко поддаются изменению. Они часто пишутся практически на чистом английском языке.
3. Результаты выполнения тестов более "человечные", например, при поломке теста вы сразу видите какое поведение в вашей системе не выполняется,
   например, "когда пользователь вводит правильные данные для авторизации (логин и пароль), то система авторизует" и если
   такой тест падает, то вполне понятно, что пользователи не могут авторизоваться.
4. Тесты не зависят от целевого языка программирования. Описание поведения остается неизменным при миграции.

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

### 9. Описание поведения в контекстах и в it должны следовать определенному правилу.
1. Используйте `Present Simple` в третьем лице -
```ruby
# плохо
it 'should return the summary' do
  # ...
end

# хорошо
it 'returns the summary' do
  # ...
end
```
2. а так же в `Passive` `voice`, например вы описываете контекст - `Когда пользователь заблокирован`, получается `when user is blocked`, где `blocked` это глагол block в третьей форме т.е. добавляем `ed` на конце или смотрим третью колонку неправильных глаголов.
3. Если вы нашли первое общее свойство, описывайте его через `when`, например `when user blocked` - "when #{объект} #{его свойство}"
4. Если у вас есть второе свойство, описывайте его используя `but`, `and`, `without`, `with` например - `but it's been over a month`
5. Когда лучше использовать отрицание `but`, `without`, а когда `and`, `with` в целом правило такое - используйте отрицание в вложенных контекстах, чтобы обозначить что ожидание вложенного контекста, отличается от внешнего. Этот принцип больше про структуру тестов, вот смотрите у вас есть тест:
```ruby
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  it "NOT allow to unlock a user" do
    expect { user.some_action }.to eq false
  end
  
  context "when user is blocked" do # внешний контекст
    let(:blocked) { true }

    it "allow to unlock a user" do
      expect { blocked_user.some_action }.to eq false
    end
    
    context "but it's been over a month" do # вложенный контекст, используем but и обозначаем тот факт что ожидание отличается.
      let(:blocked_at) { 2.month.ago }
      
      it "allow to unlock a user" do
        expect { some_action }.to eq true
      end
    end
  end
end
```
Рассмотрим пример где свойство из внешнего контекста само по себе не было бы самостоятельным. Представим что мы позволяем пользователю совершать действие только когда он зарегистрирован больше месяца (первое свойство) и купил премиум аккаунт (второе свойство). В этом случае у нас был бы первый контекст 'when user is created more than month ago', и вложенный контекст 'and user has a premium account'
```ruby
describe "#some_action" do
  let(:user) { build :user, premium: premium, created_at: created_at }
  
  context "when user is created more than month ago" do # внешний контекст
    let(:created_at) { 2.month.ago }
    
    context "and user has a premium account" do # вложенный контекст
      let(:premium) { true }
      
      it "allow to some_action" do
        expect { some_action }.to eq true
      end
    end

    context "and user has NOT a premium account" do # вложенный контекст
      let(:premium) { false }
      
      it "allow to some_action" do
        expect { some_action }.to eq false
      end
    end
  end
end
```
В этом примере как видите мы используем `and` вместо `but`, поскольку первое свойство несамостоятельное, чтобы поменялся результат нужно чтобы и свойства из внешнего и вложенного контекста были положительными, это своего рода `логическое И`.
Стоит заметить что в первом примере при использовании `but` нам не нужно было писать отрицательный тест свойства из вложенного контекста, потому что мы уже протестировали отрицальный случай относительно этого свойства на внешнем контексте. В свою очередь при `and` т.е. `логическом и` нам нужно писать отрицательный тест.
5. Когда у вас есть `положительный тест` и вы пишите к нему `отрицательный` пишите `NOT` большими буквами, например `when admin blocked a user` и `when admin NOT blocked a user`. Это полезно для того чтобы при просмотре списка тестов, вам бросалось сразу в глаза то, что упал именно отрицательный тест.

### 10. Не используйте [any_instance](https://relishapp.com/rspec/rspec-mocks/v/3-10/docs/old-syntax/any-instance), allow_any_instance_of, expect_any_instance_of

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
### 11. Используйте :aggregate_failures флаг, если складываете несколько ожиданий в один контекст для оптимизации производительности.

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
### 12. Изучите подробно правила из rubocop по части наименования https://rspec.rubystyle.guide/#naming
