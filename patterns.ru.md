# Полезные паттерны

Дополнение к [основному гайду](guide.ru.md). Три приёма, которые не входят в 17 правил, но регулярно встречаются в реальных проектах.

## Содержание

1. [super().merge() для уточнения контекстов](#supermerge-для-уточнения-контекстов)
2. [subject с lambda для побочных эффектов](#subject-с-lambda-для-побочных-эффектов)
3. [Shared context: когда использовать и когда это запах](#shared-context-когда-использовать-и-когда-это-запах)

---

## super().merge() для уточнения контекстов

[Правило 4.4](guide.ru.md#44-каждый-контекст--одно-различие) показывает переопределение скалярных `let` — `let(:blocked) { true }` — для выделения единственного различия между контекстами. Но когда тестируемый метод принимает хэш с пятью-шестью ключами, переопределять весь хэш в каждом контексте — значит дублировать четыре-пять строк ради одной.

```ruby
# плохо — весь хеш повторяется в каждом контексте
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

`super().merge()` решает задачу: контекст переопределяет только те ключи, которые ему важны, а остальные наследуются из родительского `let`.

```ruby
# хорошо — каждый контекст показывает только своё отличие
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

Приём работает когда базовый `let` стабилен, а контексты меняют один-три ключа. Если все ключи уникальны для каждого контекста — `super().merge()` не нужен, проще переопределить весь хэш.

---

## subject с lambda для побочных эффектов

RSpec мемоизирует `subject`: повторный вызов возвращает кэшированный результат, а не выполняет блок заново. Для чистых функций это поведение — плюс. Для методов с побочными эффектами — ловушка, которая приводит к зелёным тестам, не проверяющим то, что нужно. Подробнее о `subject` — [правило 7](guide.ru.md#7-не-программируйте-в-тестах).

```ruby
# плохо — тест упадёт
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

Обёртка в lambda возвращает не результат вызова, а саму процедуру — мемоизируется лямбда, а не побочный эффект:

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
      increment.call  # всё ещё 100 (лимит)
      expect(counter.reload.value).to eq(100)
    end
  end
end
```

Если lambda кажется неудобной — обычный метод работает не хуже:

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

Обычный `subject` (без lambda) безопасен для методов без побочных эффектов — там мемоизация не мешает.

---

## Shared context: когда использовать и когда это запах

`shared_context` объединяет setup (`let`, `before`), который нужен в нескольких местах. Это полезный инструмент, но часто его применяют не по назначению — о разнице между `shared_context` и `shared_examples` см. [правило 14](guide.ru.md#14-shared-examples-для-контрактов).

**Хороший случай** — setup, который используется в нескольких файлах:

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

Authenticated user, API client setup, подготовка тестовой БД — типичные кандидаты. Общий признак: setup стабилен, меняется редко и нужен в трёх и более файлах.

**Запах** — `shared_context`, который используется только внутри одного `describe`:

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

`include_context` скрывает, какие переменные доступны — читателю приходится искать определение. Обычные `let` на уровне `describe` делают то же самое без лишнего уровня косвенности:

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

Setup виден сразу над тестами — не нужно искать определение shared context.
