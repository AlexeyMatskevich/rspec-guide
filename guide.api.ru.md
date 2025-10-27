# Тестирование API-контрактов: границы применимости RSpec


RSpec создан для описания и проверки **поведения** — бизнес-правил, которые выражаются через действия и их наблюдаемые последствия. Когда речь идёт о фиксации **контракта API** (структура ответа, типы полей, обязательные атрибуты), RSpec становится неподходящим инструментом: попытка описать контракт через множество `expect` превращает спецификацию в хрупкий набор проверок реализации.

### Философия: используйте подходящий инструмент для подходящей цели

- **RSpec для поведения:** Проверяйте бизнес-логику (создание заказа, авторизация), HTTP-статусы, ключевые поля ответа.
- **Специализированные инструменты для контрактов:** Фиксируйте полную структуру API, типы полей, вложенность, обязательность.

Такое разделение даёт:

- Читаемые RSpec-тесты, сосредоточенные на бизнес-правилах
- Автоматическую актуальную документацию API
- Защиту от breaking changes в контракте
- Независимую эволюцию поведения и контракта

### Антипаттерны тестирования JSON API в RSpec

#### Антипаттерн 1: Over-splitting (излишнее разделение)

Проверка каждого поля отдельным тестом создаёт избыточность и скрывает, что все поля — части единого контракта.

```ruby
# плохо: каждое поле — отдельный тест
describe 'GET /api/orders/:id' do
  let(:order) { create(:order, total: 150.0, status: 'pending') }

  it 'returns order ID' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['id']).to eq(order.id)
  end

  it 'returns order total' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['total']).to eq(150.0)
  end

  it 'returns order status' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['status']).to eq('pending')
  end

  it 'returns customer email' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['customer_email']).to be_present
  end
  # ... ещё 10 тестов для остальных полей
end
```

**Проблемы:**

- 10+ тестов описывают одну вещь: "API возвращает заказ"
- При каждом изменении контракта ломается множество тестов
- Непонятно, какие поля критичны для бизнеса, а какие — технические детали
- Повторные HTTP-запросы замедляют тесты

#### Антипаттерн 2: Излишняя детализация (проверка всего хэша целиком)

Сравнение полного ответа через `eq` фиксирует реализацию и делает тесты хрупкими.

```ruby
# плохо: проверка всей структуры побайтово
describe 'GET /api/orders/:id' do
  it 'returns order details' do
    get "/api/orders/#{order.id}"
    
    expect(response.parsed_body).to eq({
      'id' => order.id,
      'total' => 150.0,
      'status' => 'pending',
      'customer_email' => 'user@example.com',
      'items_count' => 3,
      'shipping_address' => {
        'street' => '123 Main St',
        'city' => 'Springfield',
        'postal_code' => '12345'
      },
      'created_at' => order.created_at.iso8601(3),
      'updated_at' => order.updated_at.iso8601(3),
      'discount_amount' => nil,
      'tax_amount' => 12.0,
      'notes' => nil
    })
  end
end
```

**Проблемы:**

- Тест падает при добавлении любого нового поля в сериализатор
- Проверяются технические timestamp-поля, не важные для бизнес-логики
- Не ясно, что именно критично: `total`, `status` или все поля равнозначны
- Порядок ключей в хэше может вызывать ложные падения

### Когда RSpec подходит для API-тестов

✅ **Используйте RSpec request specs когда:**

1. **Проверяете бизнес-поведение через API:**

   ```ruby
   it 'creates order with valid payment' do
     post '/orders', params: { product_id: 1, quantity: 2 }
     expect(response).to have_http_status(:created)
     expect(Order.last).to have_attributes(status: 'pending', total: 200.0)
   end
   ```

2. **Тестируете HTTP-статусы и базовую структуру:**

   ```ruby
   it 'returns successful response with order data', :aggregate_failures do
     get "/orders/#{order.id}"
     expect(response).to have_http_status(:ok)
     expect(response.content_type).to match(/json/)
     expect(response.parsed_body).to include('id', 'status', 'total')
   end
   ```

3. **Проверяете ключевые поля, важные для бизнес-логики:**

   ```ruby
   it 'includes essential order fields', :aggregate_failures do
     get "/orders/#{order.id}"
     expect(response.parsed_body).to include(
       'id' => order.id,
       'status' => 'pending',
       'total' => a_kind_of(Numeric)
     )
   end
   ```

❌ **Избегайте RSpec для:**

- Полной фиксации структуры ответа (схемы полей, типы, вложенность)
- Сравнения огромных JSON через `eq` или string comparison
- Документирования API-контракта для внешних потребителей
- Проверки всех возможных полей ответа "на всякий случай"

### Инструменты для тестирования API-контрактов

#### 1. JSON Schema validation (thoughtbot/json_matchers)

**Что это:** Gem для валидации JSON-ответов против JSON Schema прямо в RSpec-тестах.

**Когда использовать:** Промежуточное решение между ручными проверками и полноценными контрактными тестами. Подходит для проектов, где нужна валидация структуры без генерации документации.

**Установка:**

```ruby
# Gemfile
group :test do
  gem 'json_matchers'
end
```

**Использование:**

```ruby
# spec/support/api/schemas/order.json
{
  "type": "object",
  "required": ["id", "status", "total"],
  "properties": {
    "id": { "type": "integer" },
    "status": { "type": "string", "enum": ["pending", "paid", "shipped"] },
    "total": { "type": "number", "minimum": 0 },
    "customer_email": { "type": "string", "format": "email" }
  },
  "additionalProperties": false
}
```

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  it 'matches order schema' do
    get "/api/orders/#{order.id}"
    expect(response).to match_response_schema('order')
  end
end
```

**Преимущества:**

- Работает с существующими request specs
- Схема в отдельном файле — её можно переиспользовать
- `additionalProperties: false` ловит добавление полей без обновления схемы

**Недостатки:**

- Не генерирует документацию автоматически
- Схемы нужно поддерживать вручную

#### 2. rspec-openapi — автоматическая генерация OpenAPI спецификаций

**Что это:** Gem, который генерирует OpenAPI 3.0 спецификацию из обычных RSpec request specs во время выполнения тестов.

**Когда использовать:** Вы хотите использовать RSpec по прямому назначению (тестирование поведения) и при этом автоматически получать актуальную OpenAPI-документацию.

**Установка:**

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-openapi'
end
```

**Конфигурация:**

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.openapi_root = Rails.root.join('doc', 'openapi.yaml')
  config.openapi_specs = {
    'api/v1/openapi.yaml' => {
      info: {
        title: 'My API',
        version: 'v1'
      },
      servers: [{ url: 'https://api.example.com' }]
    }
  }
end
```

**Использование:**

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  # Обычный RSpec-тест, сфокусированный на поведении
  it 'creates order with valid payment' do
    post '/api/orders', params: { product_id: 1, quantity: 2 }
    expect(response).to have_http_status(:created)
    expect(Order.last.status).to eq('pending')
  end
  
  # rspec-openapi автоматически зафиксирует:
  # - путь POST /api/orders
  # - структуру request body
  # - структуру response с кодом 201
end
```

Запуск с генерацией OpenAPI:

```bash
OPENAPI=1 rspec spec/requests
```

**Добавление метаданных для лучшей документации:**

```ruby
describe 'GET /api/orders/:id', openapi: {
  summary: 'Get order details',
  tags: ['Orders'],
  security: [{ bearer_auth: [] }]
} do
  it 'returns order with items' do
    get "/api/orders/#{order.id}", headers: auth_headers
    expect(response).to have_http_status(:ok)
  end
end
```

**Преимущества:**

- Минимальное вторжение в существующие тесты
- Автоматическое обновление документации при изменении API
- Сохраняет ручные правки в OpenAPI-файле при слиянии
- RSpec-тесты остаются простыми и читаемыми

**Недостатки:**

- Ограниченный контроль над генерируемой схемой
- Не валидирует ответы против схемы во время тестов (только генерирует)

#### 3. RSwag — DSL для описания и тестирования OpenAPI

**Что это:** Gem, который предоставляет DSL поверх RSpec для явного описания API и генерации Swagger/OpenAPI документации + встроенный Swagger UI.

**Когда использовать:** Вы хотите явно описать API-контракт в тестах и получить валидацию ответов против схемы + живую документацию.

**Установка:**

```ruby
# Gemfile
gem 'rswag-api'
gem 'rswag-ui'

group :development, :test do
  gem 'rswag-specs'
end
```

```bash
rails g rswag:api:install
rails g rswag:ui:install
RAILS_ENV=test rails g rswag:specs:install
```

```ruby
# spec/requests/orders_spec.rb
require 'swagger_helper'

RSpec.describe 'Orders API' do
  path '/api/orders' do
    post 'Creates an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :order, in: :body, schema: {
        type: :object,
        properties: {
          product_id: { type: :integer },
          quantity: { type: :integer, minimum: 1 }
        },
        required: ['product_id', 'quantity']
      }

      response '201', 'order created' do
        let(:order) { { product_id: 1, quantity: 2 } }
        
        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { type: :string },
            total: { type: :number }
          },
          required: ['id', 'status', 'total']
        
        run_test!
      end

      response '422', 'invalid request' do
        let(:order) { { product_id: 1 } }
        run_test!
      end
    end
  end
end
```

Генерация документации:

```bash
rails rswag:specs:swaggerize
```

Документация доступна по адресу: `http://localhost:3000/api-docs`

**Преимущества:**

- Явное описание контракта в тестах
- Валидация ответов против схемы во время выполнения тестов
- Автоматическая генерация Swagger UI
- Полный контроль над схемой

**Недостатки:**

- Более verbose синтаксис по сравнению с обычными request specs
- Требует миграции существующих тестов на DSL
- Смешивает описание контракта и тестирование поведения

#### 4. Snapshot testing — фиксация эталонных ответов

**Что это:** Подход, пришедший из фронтенд-мира (Jest), где тест фиксирует "снимок" вывода при первом запуске и сравнивает с ним при последующих запусках.

**Откуда это:** В мире фронтенда (React, Vue) snapshot testing используется для фиксации рендеринга компонентов. Разработчик запускает тесты, они создают snapshot (HTML-вывод), и при последующих запусках любое изменение в рендере вызывает падение теста. Если изменение ожидаемое — разработчик обновляет snapshot, если нет — ловит регрессию.

**Как это работает с API:** Тот же принцип применим к OpenAPI-спецификациям или JSON-ответам:

1. Первый запуск теста генерирует эталон (OpenAPI spec или JSON snapshot)
2. Последующие запуски сравнивают текущий вывод с эталоном
3. При изменении API тест падает, показывая diff
4. Разработчик либо фиксирует регрессию, либо обновляет эталон

**Преимущества в связке с rspec-openapi:**

Когда вы используете `rspec-openapi`, вы:

- Пишете обычные RSpec request specs, сфокусированные на **поведении** (правильно ли создаётся заказ, приходит ли нужный статус)
- Автоматически получаете OpenAPI-спецификацию, фиксирующую **контракт** (структура ответа, типы полей)
- Можете организовать snapshot-тестирование этой OpenAPI-спеки

**Ловим двух зайцев:**

1. RSpec используется по прямому назначению — тестирование поведения
2. OpenAPI-спека как snapshot ловит неожиданные изменения контракта

**Инструменты для snapshot testing в Ruby:**

```ruby
# Gemfile
group :test do
  gem 'rspec-snapshot'  # Общий snapshot testing
  # или
  gem 'rspec-request_snapshot'  # Специализирован для request specs
end
```

**Пример использования:**

```ruby
RSpec.describe 'Orders API', type: :request do
  it 'returns order details' do
    get "/api/orders/#{order.id}"
    expect(response.body).to match_snapshot('order_details')
  end
end
```

При первом запуске создаётся файл `spec/__snapshots__/orders_api_spec.rb/order_details.json`. При последующих запусках текущий ответ сравнивается с этим файлом.

**Snapshot testing OpenAPI с rspec-openapi:**

После генерации OpenAPI через `OPENAPI=1 rspec`, файл `doc/openapi.yaml` можно версионировать в git. При изменении API:

- CI проверяет, изменился ли файл
- Если да — требует явного коммита обновления (= acknowledge breaking change)
- Если изменение неожиданное — ловится регрессия

**Когда использовать snapshot testing:**

- Для стабильных API с редкими изменениями
- Когда важно ловить неожиданные изменения контракта
- В связке с rspec-openapi для автоматического контроля контракта

**Когда не использовать:**

- Для API, которые часто меняются (постоянное обновление snapshots)
- Вместо осмысленных проверок поведения
- Для критичных бизнес-правил (лучше явные expectations)

### Рекомендованный подход: комбинация инструментов

✅ **Лучшая практика:**

1. **RSpec request specs** — для тестирования поведения:

   ```ruby
   it 'creates order and charges customer' do
     post '/orders', params: order_params
     expect(response).to have_http_status(:created)
     expect(Order.last.status).to eq('pending')
     expect(customer.reload.balance).to eq(0)
   end
   ```

2. **rspec-openapi** — для автоматической фиксации контракта:

   ```ruby
   # Тот же тест выше, запущенный с OPENAPI=1,
   # автоматически обновляет doc/openapi.yaml
   ```

3. **JSON Schema / thoughtbot/json_matchers** — для критичных эндпоинтов:

   ```ruby
   it 'returns valid payment confirmation' do
     post '/payments', params: payment_params
     expect(response).to match_response_schema('payment_confirmation')
   end
   ```

4. **RSwag** — если нужна живая документация и явный контроль:

   ```ruby
   # Для публичных API, где документация = контракт с клиентами
   path '/api/v2/orders' do
     post 'Creates order' do
       # ... подробное описание схемы
     end
   end
   ```

5. **Snapshot testing** — для ловли регрессий в контракте:

   ```bash
   # CI проверяет, что doc/openapi.yaml не изменился без явного коммита
   git diff --exit-code doc/openapi.yaml
   ```

### Золотое правило

**Не смешивайте проверку поведения и контракта в одном тесте.**

- RSpec = поведение (что система делает)
- OpenAPI/JSON Schema/Snapshots = контракт (как выглядит интерфейс)

Если тест читается как "проверяет, что система создаёт заказ" — это RSpec.
Если тест читается как "проверяет, что ответ содержит все поля из схемы" — это контрактный тест.

**См. также в основном гайде:**
- [Правило 27: Стабилизируйте время](guide.ru.md#27-стабилизируйте-время-через-activesupporttestingtimehelpers) — управление временем в тестах
- [Правило 28: Делайте вывод падения теста читаемым](guide.ru.md#28-делайте-вывод-падения-теста-читаемым) — примеры читаемого форматирования JSON-ответов
