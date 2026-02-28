# Тестирование API-контрактов: границы применимости RSpec

## Оглавление

- [Философия](#философия)
- [Антипаттерны тестирования JSON API](#антипаттерны-тестирования-json-api-в-rspec)
  - [Over-splitting](#антипаттерн-1-over-splitting-излишнее-разделение)
  - [Излишняя детализация](#антипаттерн-2-излишняя-детализация-проверка-всего-хэша-целиком)
- [Когда RSpec подходит для API-тестов](#когда-rspec-подходит-для-api-тестов)
- [Инструменты для тестирования API-контрактов](#инструменты-для-тестирования-api-контрактов)
  - [JSON Schema validation](#json-schema-validation-thoughtbotjson_matchers)
  - [rspec-openapi](#rspec-openapi)
  - [RSwag](#rswag)
  - [Snapshot testing](#snapshot-testing)
- [Быстрый выбор инструмента](#быстрый-выбор-инструмента)
- [Золотое правило](#золотое-правило)
- [Глоссарий терминов](#глоссарий-терминов)

RSpec создан для описания и проверки **поведения** — бизнес-правил, которые выражаются через действия и их наблюдаемые последствия. Когда речь идёт о фиксации **[контракта API](#api-контракт)** (структура ответа, типы полей, обязательные атрибуты), RSpec становится неподходящим инструментом: попытка описать контракт через множество `expect` превращает спецификацию в хрупкий набор проверок реализации.

## Философия

RSpec проверяет поведение: бизнес-логику (создание заказа, авторизация), HTTP-статусы, ключевые поля ответа. Специализированные инструменты фиксируют контракт: полную структуру API, типы полей, вложенность, обязательность.

Когда поведение и контракт разделены, RSpec-тесты читаются как спецификация бизнес-правил, документация API обновляется автоматически, а breaking changes в контракте ловятся до деплоя. Поведение и контракт развиваются независимо.

## Антипаттерны тестирования JSON API в RSpec

### Антипаттерн 1: Over-splitting (излишнее разделение)

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

**Решение:** См. [JSON Schema validation](#json-schema-validation-thoughtbotjson_matchers) или [Snapshot testing](#snapshot-testing).

### Антипаттерн 2: Излишняя детализация (проверка всего хэша целиком)

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

**Решение:** См. [aggregate_failures в guide.ru.md](guide.ru.md#11-aggregate_failures-для-интерфейсных-тестов) для бизнес-проверок, [JSON Schema](#json-schema-validation-thoughtbotjson_matchers) для контракта.

## Когда RSpec подходит для API-тестов

RSpec request specs уместны, когда проверяется поведение, а не структура.

Проверка бизнес-поведения через API:

```ruby
it 'creates order with valid payment' do
  post '/orders', params: { product_id: 1, quantity: 2 }
  expect(response).to have_http_status(:created)
  expect(Order.last).to have_attributes(status: 'pending', total: 200.0)
end
```

Тестирование HTTP-статусов и базовой структуры:

```ruby
it 'returns successful response with order data', :aggregate_failures do
  get "/orders/#{order.id}"
  expect(response).to have_http_status(:ok)
  expect(response.content_type).to match(/json/)
  expect(response.parsed_body).to include('id', 'status', 'total')
end
```

Проверка ключевых полей, важных для бизнес-логики:

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

**См. также:** [Правило 11 "aggregate_failures для интерфейсных тестов"](guide.ru.md#11-aggregate_failures-для-интерфейсных-тестов) — использование `have_attributes` и структурных матчеров.

RSpec не подходит для полной фиксации структуры ответа (схемы полей, типы, вложенность), сравнения объёмных JSON через `eq` или string comparison, документирования API-контракта для внешних потребителей и проверки всех возможных полей ответа «на всякий случай». Для этого — инструменты ниже.

## Инструменты для тестирования API-контрактов

Выбор инструмента определяется тем, что именно нужно: валидация структуры без документации, документация из кода, разработка под контракт или защита от регрессий.

### JSON Schema validation (thoughtbot/json_matchers)

Если нужна валидация структуры ответа без генерации документации — подойдёт `json_matchers`. Gem добавляет в RSpec матчер для проверки JSON-ответов против [JSON Schema](#json-schema), которую вы описываете в отдельном файле.

```ruby
# Gemfile
group :test do
  gem 'json_matchers'
end
```

Схема описывает контракт — типы полей, обязательность, допустимые значения:

```json
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

В тесте одна строка проверяет весь контракт:

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  it 'matches order schema' do
    get "/api/orders/#{order.id}"
    expect(response).to match_response_schema('order')
  end
end
```

Работает с существующими request specs, схема в отдельном файле переиспользуется, а `additionalProperties: false` ловит добавление полей без обновления схемы. Обратная сторона — схемы не генерируют документацию и требуют ручной поддержки.

### rspec-openapi

Если вы хотите писать обычные RSpec-тесты и автоматически получать актуальную документацию — это [code-first](#code-first) подход. Gem `rspec-openapi` генерирует [OpenAPI](#openapi-swagger) 3.0 спецификацию из фактических запросов и ответов во время прогона тестов. Код является источником истины, документация следует за ним.

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-openapi'
end
```

Конфигурация:

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

Тесты остаются сфокусированными на поведении — gem извлекает контракт из фактических запросов:

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

Для лучшей документации можно добавить метаданные:

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

Главное преимущество — минимальное вторжение в существующие тесты: документация обновляется автоматически, ручные правки в OpenAPI-файле сохраняются при слиянии. Ограничение — gem не валидирует ответы против схемы (только генерирует), и контроль над результатом ограничен.

### RSwag

Если контракт первичен и API разрабатывается под спецификацию — это [spec-first](#spec-first) подход. RSwag предоставляет DSL поверх RSpec для явного описания [OpenAPI](#openapi-swagger)-контракта в тестах. По сути вы пишете OpenAPI-документацию на Ruby-синтаксисе, а RSwag конвертирует её в JSON/YAML и поднимает Swagger UI.

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

RSwag даёт полный контроль: явное описание контракта, валидация ответов против схемы при прогоне тестов, автоматическая генерация Swagger UI. Цена — более verbose синтаксис, необходимость миграции существующих тестов на DSL и смешивание описания контракта с тестированием поведения в одном файле.

### Snapshot testing

Snapshot testing — подход из фронтенд-мира. В React и Vue он используется для фиксации рендеринга компонентов: при первом запуске Jest создаёт снимок HTML-вывода, при последующих — сравнивает текущий вывод с эталоном. Если изменение ожидаемое — разработчик обновляет [snapshot](#глоссарий-терминов), если нет — ловит регрессию.

Тот же принцип применим к API-ответам и OpenAPI-спецификациям:

1. Первый запуск теста генерирует эталон (OpenAPI spec или JSON snapshot)
2. Последующие запуски сравнивают текущий вывод с эталоном
3. При изменении API тест падает, показывая diff
4. Разработчик либо фиксирует регрессию, либо обновляет эталон

В связке с `rspec-openapi` это работает так: вы пишете обычные RSpec-тесты, сфокусированные на поведении, автоматически получаете OpenAPI-спецификацию, фиксирующую контракт, и организуете snapshot-тестирование этой спеки. RSpec используется по прямому назначению — тестирование поведения, а OpenAPI-спека как snapshot ловит неожиданные изменения контракта.

Инструменты для snapshot testing в Ruby:

```ruby
# Gemfile
group :test do
  gem 'rspec-snapshot'  # Общий snapshot testing
  # или
  gem 'rspec-request_snapshot'  # Специализирован для request specs
end
```

Пример использования:

```ruby
RSpec.describe 'Orders API', type: :request do
  it 'returns order details' do
    get "/api/orders/#{order.id}"
    expect(response.body).to match_snapshot('order_details')
  end
end
```

При первом запуске создаётся файл `spec/__snapshots__/orders_api_spec.rb/order_details.json`. При последующих запусках текущий ответ сравнивается с этим файлом.

Snapshot testing OpenAPI через `rspec-openapi` работает ещё проще: после генерации через `OPENAPI=1 rspec` файл `doc/openapi.yaml` версионируется в git. CI проверяет, изменился ли файл, и требует явного коммита обновления — это acknowledge breaking change. Неожиданное изменение ловится как регрессия.

Snapshot testing подходит для стабильных API с редкими изменениями и для автоматического контроля контракта в связке с `rspec-openapi`. Не подходит для API, которые часто меняются (постоянное обновление snapshots замедляет работу), и не заменяет осмысленные проверки поведения и явные expectations для критичных бизнес-правил.

## Быстрый выбор инструмента

| Ситуация | Рекомендуемый инструмент | Почему |
|----------|-------------------------|--------|
| Тестирую бизнес-логику через API | **RSpec request specs** | Проверка поведения — прямое назначение RSpec |
| Code-first: хочу документацию из кода | **rspec-openapi** | Код — источник истины, OpenAPI генерируется автоматически |
| Spec-first: разрабатываю API под контракт | **RSwag** | Спека — источник истины, тесты валидируют соответствие |
| Нужна валидация структуры ответа | **json_matchers** | Легковесное решение для проверки JSON Schema |
| Нужно ловить неожиданные изменения | **Snapshot testing** | Автофиксация эталона, git diff показывает изменения |
| Проверяю HTTP-статусы и ключевые поля | **RSpec + структурные матчеры** | `include`, `match_array` вместо `eq` |

## Золотое правило

Не смешивайте проверку поведения и контракта в одном тесте.

- RSpec = поведение (что система делает)
- OpenAPI/JSON Schema/Snapshots = контракт (как выглядит интерфейс)

Если тест читается как «проверяет, что система создаёт заказ» — это RSpec.
Если тест читается как «проверяет, что ответ содержит все поля из схемы» — это контрактный тест.

## Глоссарий терминов

### API-контракт

Формальное описание структуры запросов и ответов API: какие поля обязательны, их типы, формат, вложенность. Контракт не описывает бизнес-логику, только структуру данных.

### Code-first

Подход, при котором сначала пишется код API, а документация (OpenAPI) генерируется из него автоматически. Код является источником истины.

### Spec-first

Подход, при котором сначала создается спецификация API (OpenAPI), а код пишется в соответствии с ней. Спецификация является источником истины.

### OpenAPI (Swagger)

Стандарт описания REST API в формате JSON/YAML. Включает endpoints, параметры, схемы данных, примеры ответов.

### JSON Schema

Стандарт описания структуры JSON-документов: типы полей, обязательность, форматы, валидация.

### Snapshot testing

Техника тестирования, при которой результат первого выполнения сохраняется как эталон, а последующие запуски сравниваются с ним.

**См. также в основном гайде:**
- [Правило 16: Стабилизируйте время](guide.ru.md#16-стабилизируйте-время) — управление временем в тестах
- [Правило 17: Делайте вывод падения читаемым](guide.ru.md#17-делайте-вывод-падения-читаемым) — примеры читаемого форматирования JSON-ответов
