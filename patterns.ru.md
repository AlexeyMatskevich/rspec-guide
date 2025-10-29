# Полезные паттерны

Практические приемы для написания читаемых и поддерживаемых RSpec тестов.

## Содержание

1. [Named subject для тестирования методов](#1-named-subject-для-тестирования-методов)
2. [merge для уточнения контекстов](#2-merge-для-уточнения-контекстов)
3. [subject с lambda для побочных эффектов](#3-subject-с-lambda-для-побочных-эффектов)
4. [Traits в characteristic-based contexts](#4-traits-в-characteristic-based-contexts)
5. [Shared context: когда использовать и когда это запах](#5-shared-context-когда-использовать-и-когда-это-запах)
6. [Nil object для пустого контекста](#6-nil-object-для-пустого-контекста)
7. [Когда использовать каждый паттерн](#когда-использовать-каждый-паттерн)

---

## 1. Named subject для тестирования методов

### Проблема

Повторение вызова метода в каждом тесте делает код многословным и менее читаемым:

```ruby
# плохо
describe '#premium?' do
  context 'when user has premium subscription' do
    let(:user) { create(:user, subscription: 'premium') }

    it 'returns true' do
      expect(user.premium?).to be true
    end
  end

  context 'when user has free subscription' do
    let(:user) { create(:user, subscription: 'free') }

    it 'returns false' do
      expect(user.premium?).to be false
    end
  end
end
```

### Решение

Используйте named subject чтобы вызвать метод один раз и сделать код DRY:

```ruby
# хорошо
describe '#premium?' do
  subject(:premium_status) { user.premium? }

  context 'when user has premium subscription' do
    let(:user) { create(:user, subscription: 'premium') }

    it { is_expected.to be true }
  end

  context 'when user has free subscription' do
    let(:user) { create(:user, subscription: 'free') }

    it { is_expected.to be false }
  end
end
```

### Преимущества

- **DRY**: метод вызывается в одном месте
- **Ясность**: имя `premium_status` показывает что тестируется
- **Переиспользование**: легко использовать в разных контекстах
- **Читаемость**: однострочные тесты с `is_expected`

### Когда использовать

- Метод вызывается в нескольких `it` блоках
- Метод НЕ имеет побочных эффектов (чистая функция)
- Нужно протестировать возвращаемое значение в разных условиях

---

## 2. merge для уточнения контекстов

### Проблема

При изменении одного-двух параметров приходится дублировать весь хеш:

```ruby
# плохо
describe ReportGenerator do
  let(:params) do
    {
      from: '2024-01-01',
      to: '2024-01-31',
      format: 'json',
      user_id: 123,
      include_details: true
    }
  end

  context 'when format is json' do
    let(:params) do
      {
        from: '2024-01-01',
        to: '2024-01-31',
        format: 'json',  # только это важно
        user_id: 123,
        include_details: true
      }
    end

    it 'returns json data' do
      expect(generator.call(params)).to be_a(Hash)
    end
  end

  context 'when format is csv' do
    let(:params) do
      {
        from: '2024-01-01',
        to: '2024-01-31',
        format: 'csv',  # только это меняется
        user_id: 123,
        include_details: true
      }
    end

    it 'returns csv data' do
      expect(generator.call(params)).to be_a(String)
    end
  end
end
```

### Решение

Используйте `super().merge(...)` чтобы показать только то что меняется:

```ruby
# хорошо
describe ReportGenerator do
  let(:params) do
    {
      from: '2024-01-01',
      to: '2024-01-31',
      format: 'json',
      user_id: 123,
      include_details: true
    }
  end

  context 'when format is json' do
    # используются базовые params

    it 'returns json data' do
      expect(generator.call(params)).to be_a(Hash)
    end
  end

  context 'when format is csv' do
    let(:params) { super().merge(format: 'csv') }  # ясно что меняется

    it 'returns csv data' do
      expect(generator.call(params)).to be_a(String)
    end
  end

  context 'when period is invalid' do
    let(:params) { super().merge(from: '2024-02-01', to: '2024-01-01') }

    it 'returns error' do
      result = generator.call(params)
      expect(result.error).to be_truthy
    end
  end
end
```

### Преимущества

- **Фокус на изменениях**: сразу видно какой параметр отличается
- **Нет дублирования**: базовые параметры определены один раз
- **Легко поддерживать**: изменения в базовых params распространяются автоматически
- **Снижает когнитивную нагрузку**: не нужно сравнивать большие хеши

### Когда использовать

- Много параметров в базовом `let`
- Контексты меняют 1-3 параметра
- Базовые параметры стабильны

---

## 3. subject с lambda для побочных эффектов

### Проблема

RSpec мемоизирует `subject`, поэтому метод с побочными эффектами выполняется только один раз:

```ruby
# плохо - тест упадет
describe '#increment_counter' do
  subject(:increment) { counter.increment }

  let(:counter) { create(:counter, value: 0) }

  it 'increases counter on each call' do
    increment  # value становится 1
    increment  # ничего не происходит (мемоизация!)
    expect(counter.reload.value).to eq(2)  # ПАДАЕТ: ожидается 2, получено 1
  end
end
```

### Решение

Оберните вызов в lambda `-> { ... }` чтобы получать свежий вызов каждый раз:

```ruby
# хорошо
describe '#increment_counter' do
  subject(:increment) { -> { counter.increment } }

  let(:counter) { create(:counter, value: 0) }

  it 'increases counter on each call' do
    increment.call  # value становится 1
    increment.call  # value становится 2
    expect(counter.reload.value).to eq(2)  # ПРОХОДИТ
  end

  context 'when counter reaches limit' do
    before { 98.times { increment.call } }

    it 'stops at 100' do
      increment.call  # 99
      increment.call  # 100
      increment.call  # все еще 100 (лимит)
      expect(counter.reload.value).to eq(100)
    end
  end
end
```

### Альтернатива: просто не используйте subject

Если lambda кажется неудобной, просто определите обычный метод:

```ruby
# хорошо (альтернатива)
describe '#increment_counter' do
  let(:counter) { create(:counter, value: 0) }

  def increment
    counter.increment
  end

  it 'increases counter on each call' do
    increment  # value становится 1
    increment  # value становится 2
    expect(counter.reload.value).to eq(2)
  end
end
```

### Когда использовать

- **subject с lambda**: когда нужен named subject для методов с побочными эффектами
- **Обычный метод**: когда lambda кажется избыточной
- **Не используйте обычный subject**: для методов меняющих состояние

---

## 4. Traits в characteristic-based contexts

### Идея

Используйте factory traits чтобы явно показать состояние характеристики в контексте.

### Пример

```ruby
# хорошо
describe OrderProcessor do
  describe '#process' do
    subject(:process_order) { processor.process(order) }

    let(:processor) { described_class.new }

    context 'when order is pending' do
      let(:order) { create(:order, :pending) }  # trait соответствует контексту!

      context 'and user is premium' do
        let(:user) { create(:user, :premium) }  # trait соответствует контексту!
        let(:order) { create(:order, :pending, user: user) }

        it 'processes immediately' do
          expect(process_order.priority).to eq('high')
        end
      end

      context 'and user is regular' do
        let(:user) { create(:user, :regular) }  # trait соответствует контексту!
        let(:order) { create(:order, :pending, user: user) }

        it 'adds to queue' do
          expect(process_order.priority).to eq('normal')
        end
      end
    end

    context 'when order is completed' do
      let(:order) { create(:order, :completed) }  # trait соответствует контексту!

      it 'skips processing' do
        expect(process_order).to be_nil
      end
    end
  end
end
```

### Определение traits в фабрике

```ruby
# spec/factories/orders.rb
FactoryBot.define do
  factory :order do
    user
    product
    quantity { 1 }
    status { 'draft' }

    trait :pending do
      status { 'pending' }
      submitted_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end
  end
end

# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    subscription { 'free' }

    trait :premium do
      subscription { 'premium' }
      premium_since { 6.months.ago }
    end

    trait :regular do
      subscription { 'free' }
    end
  end
end
```

### Преимущества

- **Читаемость**: `create(:order, :pending)` читается как спецификация
- **Документация**: trait name документирует состояние характеристики
- **Легко расширять**: новое состояние = новый trait
- **Соответствие Rule 4**: traits естественно мапятся на characteristics

### Когда использовать

- Characteristic states четко определены (pending/completed, premium/regular)
- Состояние требует нескольких атрибутов (не просто `status: 'pending'`)
- Нужно переиспользовать состояния в разных тестах

---

## 5. Shared context: когда использовать и когда это запах

### ✅ GOOD: Sharing между несколькими файлами

Shared context уместен когда setup используется в **нескольких test files**:

```ruby
# spec/support/shared_contexts/with_authenticated_user.rb
RSpec.shared_context 'with authenticated user' do
  let(:user) { create(:user, :verified) }

  before { sign_in(user) }
end

# spec/controllers/orders_controller_spec.rb
RSpec.describe OrdersController do
  include_context 'with authenticated user'

  describe 'GET #index' do
    it 'shows user orders' do
      get :index
      expect(assigns(:orders)).to eq(user.orders)
    end
  end
end

# spec/controllers/invoices_controller_spec.rb
RSpec.describe InvoicesController do
  include_context 'with authenticated user'

  describe 'GET #index' do
    it 'shows user invoices' do
      get :index
      expect(assigns(:invoices)).to eq(user.invoices)
    end
  end
end

# spec/requests/api/v1/profile_spec.rb
RSpec.describe 'API V1 Profile' do
  include_context 'with authenticated user'

  describe 'GET /api/v1/profile' do
    it 'returns user profile' do
      get '/api/v1/profile'
      expect(json_response['email']).to eq(user.email)
    end
  end
end
```

**Когда использовать shared context:**
- Setup используется в **3+ файлах**
- Типичные сценарии: authenticated user, api client setup, test database state
- Setup стабилен и редко меняется

---

### ❌ BAD: Shared context для одного describe (запах)

Shared context используемый только в одном файле — это **запах плохого дизайна**:

```ruby
# плохо
RSpec.describe OrderProcessor do
  shared_context 'with order setup' do  # используется только здесь!
    let(:user) { create(:user) }
    let(:product) { create(:product, price: 100) }
    let(:order) { create(:order, user: user, product: product, quantity: 2) }
  end

  describe '#process' do
    include_context 'with order setup'

    it 'charges user' do
      expect { processor.process(order) }.to change { user.reload.balance }.by(-200)
    end
  end

  describe '#cancel' do
    include_context 'with order setup'

    it 'refunds user' do
      order.update(status: 'paid')
      expect { processor.cancel(order) }.to change { user.reload.balance }.by(200)
    end
  end
end
```

**Почему это плохо:**
- **Скрывает setup**: нужно искать что такое `user`, `product`, `order`
- **Когнитивная нагрузка**: непонятно какие переменные доступны
- **Усложнение без пользы**: обычный `let` был бы проще

**Правильное решение** — обычные `let` на уровне `describe`:

```ruby
# хорошо
RSpec.describe OrderProcessor do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 100) }
  let(:order) { create(:order, user: user, product: product, quantity: 2) }

  describe '#process' do
    it 'charges user' do
      expect { processor.process(order) }.to change { user.reload.balance }.by(-200)
    end
  end

  describe '#cancel' do
    before { order.update(status: 'paid') }

    it 'refunds user' do
      expect { processor.cancel(order) }.to change { user.reload.balance }.by(200)
    end
  end
end
```

Setup виден **сразу над тестами**, не нужно искать определение shared context.

---

## 6. Nil object для пустого контекста

### Проблема

Контекст описывает "отсутствие чего-то", но остается пустым, нарушая Rule 9 (каждый контекст должен иметь свой setup):

```ruby
# плохо - пустой контекст нарушает Rule 9
describe '#leaf?' do
  subject(:is_leaf) { setting.leaf? }

  let(:setting) { described_class.new(:parent, {}) }

  context 'when setting has no children' do
    # ❌ Пустой контекст - нет let, нет before, нет subject
    it { is_expected.to be true }
  end

  context 'when setting has children' do
    let(:child) { described_class.new(:child, {}, parent: setting) }
    before { setting.add_child(child) }

    it { is_expected.to be false }
  end
end
```

### Решение

Используйте явное "пустое" значение (`nil`, `[]`, `{}`) как `let` в контексте:

```ruby
# хорошо - оба контекста имеют явный setup
describe '#leaf?' do
  subject(:is_leaf) { setting.leaf? }

  let(:setting) { described_class.new(:parent, {}) }

  before { setting.add_child(child) if child }  # Побочный эффект: можно поднять action

  context 'when setting has children' do  # Happy path первым
    let(:child) { described_class.new(:child, {}, parent: setting) }

    it { is_expected.to be false }
  end

  context 'when setting has no children' do
    let(:child) { nil }  # ✅ Явное "отсутствие" через nil

    it { is_expected.to be true }
  end
end
```

### Преимущества

- **Следует Rule 9**: Каждый контекст имеет явный setup
- **Симметрия**: Оба контекста явно показывают различия в данных
- **Побочный эффект**: Общее действие можно поднять в родитель (но это следствие, а не цель)
- **Явность**: Читатель видит что различает контексты

### Когда использовать

- Контекст описывает "отсутствие" (no X, empty X, without X)
- Можно выразить отсутствие через очевидное пустое значение: `nil`, `[]`, `{}`, explicit null object
- Код корректно обрабатывает пустое значение (нет side effects, нет исключений)
- Предпочитайте `nil` над `{}` или `[]` когда оба работают (более явно)

### Когда НЕ использовать

- Пустое значение неочевидно (например, `{}` означающий "no child" требует знания кода)
- Код не ожидает пустое значение (выбрасывает исключения, имеет side effects)
- Лучше использовать отдельную ветку без действия
- Нарушит Happy Path First без возможности переупорядочить

---

## Когда использовать каждый паттерн

| Паттерн | Используй когда | НЕ используй когда |
|---------|-----------------|-------------------|
| **Named subject** | Метод вызывается в нескольких contexts, нет побочных эффектов | Метод с побочными эффектами нужно вызвать несколько раз |
| **merge для params** | Много параметров, меняется 1-3 | Все параметры уникальны для контекста |
| **subject с lambda** | Метод с побочными эффектами, нужно несколько вызовов | Простое чтение значения без изменения состояния |
| **Traits в contexts** | Characteristic states четко мапятся на factory traits | Уникальная разовая комбинация атрибутов |
| **Shared context** | Setup используется в 3+ test files | Используется только в одном describe |
| **Nil object для пустого контекста** | Контекст описывает отсутствие, можно использовать очевидное пустое значение (nil/[]/null object) | Пустое значение неочевидно, код не обрабатывает его, или нарушает happy path |

---

## Заключение

Эти паттерны помогают писать тесты которые:
- **Читаются как спецификация** (named subject, traits)
- **Фокусируются на изменениях** (merge для params)
- **Правильно обрабатывают побочные эффекты** (lambda subject)
- **Переиспользуют код разумно** (shared context для реального sharing, а не скрытия)

Используйте их когда они улучшают читаемость и поддерживаемость. Не используйте их механически — каждый паттерн решает конкретную проблему.
