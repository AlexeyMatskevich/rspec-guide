# Алгоритм оптимизации подготовки данных с FactoryBot

## Предусловия

Этот алгоритм применяется **после** основного алгоритма написания BDD-тестов, когда:
- ✅ Структура контекстов уже построена ([Правило 4.2](../guide.ru.md#42-постройте-иерархию-зависимые--независимые))
- ✅ Характеристики и состояния определены ([Правило 4.1](../guide.ru.md#41-выделите-характеристики-и-состояния))
- ✅ Описания поведений написаны ([Правило 10.1](../guide.ru.md#101-context--it--валидное-предложение))
- ✅ Нужно оптимизировать подготовку тестовых данных

**Важно:** FactoryBot используется не во всех тестах. Этот алгоритм применим для большинства случаев в ruby on rails, как правило всегда, когда в логике есть модели.

---

## Этап 1: Аудит текущей подготовки данных

### Цель
Выявить все места подготовки данных в тестах и определить, где можно применить FactoryBot.

### Почему это важно
Явная инициализация объектов с десятками атрибутов создаёт техническую сложность и скрывает бизнес-характеристики.

### Что искать

```ruby
# ❌ Сигналы для оптимизации:

# 1. Создание моделей с множеством атрибутов
let(:user) do
  User.create(
    email: 'test@example.com',
    password: 'password123',
    first_name: 'John',
    last_name: 'Doe',
    phone: '+1234567890',
    confirmed_at: Time.current,
    role: 'customer',
    newsletter: true,
    timezone: 'UTC'
  )
end

# 2. Повторяющиеся наборы атрибутов
context 'when user is premium' do
  let(:user) { User.create(email: '...', role: 'premium', subscription_ends_at: 1.year.from_now) }
end

context 'when user is trial' do
  let(:user) { User.create(email: '...', role: 'trial', trial_ends_at: 14.days.from_now) }
end

# 3. Создание связанных объектов вручную
let(:order) { Order.create(user: user, status: 'pending') }
let(:item1) { OrderItem.create(order: order, product: product1, quantity: 2) }
let(:item2) { OrderItem.create(order: order, product: product2, quantity: 1) }
```

### Чек-лист аудита
- [ ] Выписать все `let` блоки с созданием объектов
- [ ] Найти повторяющиеся паттерны инициализации
- [ ] Идентифицировать технические vs бизнес-атрибуты
- [ ] Отметить места с созданием связанных объектов

---

## Этап 2: Маппинг характеристик на трейты

### Связь с основным алгоритмом

На [Этапе 4](test.ru.md#этап-4-определение-типов-характеристик) и [Этапе 5](test.ru.md#этап-5-определение-состояний-и-дефолтов) основного алгоритма вы определили типы характеристик и их состояния.

Теперь каждое **недефолтное состояние** характеристики становится трейтом в фабрике:
- Если характеристика имеет дефолтное состояние → трейт только для недефолтных состояний
- Если характеристика без дефолта → трейты для всех состояний

**Пример:** Характеристика "Статус блокировки" имеет состояния `blocked`/`active` (дефолт: `active`) → создаём только трейт `:blocked`.

### Цель
Преобразовать выявленные состояния характеристик из основного алгоритма в трейты FactoryBot.

### Почему это важно
Трейты документируют состояния характеристик и делают тесты читаемыми на уровне бизнес-языка ([Правило 10.1](../guide.ru.md#101-context--it--валидное-предложение)).

**См. также:** [Правило 9.1: Traits для характеристик](../guide.ru.md#91-traits-для-характеристик)

### Правила создания трейтов

| Тип характеристики | Трейт в фабрике | Пример |
|------------------------|-----------------|---------|
| Бинарная (2 состояния) | Трейт для недефолтного состояния | `:blocked`, `:unverified` |
| Enum (N состояний) | Трейт для каждого состояния | `:admin`, `:manager`, `:customer` |
| Диапазон (группы значений) | Трейт для каждого бизнес-состояния | `:with_sufficient_balance`, `:overdue` |
| Комбинация состояний | Составной трейт | `:payment_ready` (= verified + with_balance) |

### Именование трейтов

Название трейта должно быть самодокументирующим и однозначно отражать состояние характеристики:

- ✅ `:verified`, `:blocked`, `:premium` — понятно без комментариев
- ❌ `:special`, `:ready`, `:custom` — неясно, что это означает

**Комментарии** добавляйте только для сложных составных трейтов или неочевидной бизнес-логики:

```ruby
# Composite trait: user ready for payment processing
# Includes: email verified + payment card attached + sufficient balance + passed KYC
trait :payment_ready do
  verified
  with_payment_card
  with_sufficient_balance
  kyc_passed
end
```

### Пример маппинга

```ruby
# Из анализа тестов выявили характеристики:
# - Статус подписки: trial/basic/premium
# - Верификация email: verified/unverified (дефолт: unverified)
# - Блокировка: blocked/active (дефолт: active)

# Создаём фабрику с трейтами:
FactoryBot.define do
  factory :user do
    # Дефолтные значения - "средний" пользователь
    email { Faker::Internet.email }
    password { 'SecurePass123!' }
    subscription_type { 'basic' }
    email_verified { false }
    blocked { false }

    # Трейты для состояний характеристик
    trait :trial do
      subscription_type { 'trial' }
      trial_ends_at { 14.days.from_now }
    end

    trait :premium do
      subscription_type { 'premium' }
      subscription_ends_at { 1.year.from_now }
    end

    trait :verified do
      email_verified { true }
      email_verified_at { 1.day.ago }
    end

    trait :blocked do
      blocked { true }
      blocked_at { 2.days.ago }
      blocked_reason { 'Terms violation' }
    end

    # Составной трейт для интеграционных тестов
    trait :ready_for_purchase do
      verified
      premium
      after(:create) do |user|
        create(:payment_method, user: user, verified: true)
      end
    end
  end
end
```

---

## Этап 3: Выбор метода FactoryBot (Decision Tree)

### Цель
Для каждого места создания объекта выбрать оптимальный метод FactoryBot.

### Почему это важно
Правильный выбор метода влияет на скорость тестов и их изолированность.

**Подробнее:** [Правило 9.2: attributes_for для параметров](../guide.ru.md#92-attributes_for-для-параметров), [Правило 9.3: build_stubbed для юнит-тестов](../guide.ru.md#93-build_stubbed-для-юнит-тестов)

### Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│ Нужен ли вам объект для проверки поведения?                 │
└─────────────┬───────────────────────────────────────────────┘
              │
              ├─── НЕТ (только параметры для API/контроллера)
              │    └─→ attributes_for(:user)
              │       # Возвращает { name: "...", email: "..." }
              │
              └─── ДА (нужен объект)
                   │
                   ├─── Объект должен быть сохранён в БД?
                   │    │
                   │    ├─── ДА (нужна персистентность, ассоциации, колбэки)
                   │    │    │
                   │    │    ├─── Нужны связанные объекты?
                   │    │    │    ├─── ДА → create(:order, :with_items)
                   │    │    │    │         # Используйте traits
                   │    │    │    │
                   │    │    │    └─── НЕТ → create(:user)
                   │    │    │              # Простое создание
                   │    │    │
                   │    │    └─→ Всегда create() когда нужна БД
                   │    │
                   │    └─── НЕТ (только в памяти, БД не нужна)
                   │         │
                   │         ├─── Тестируете ПОВЕДЕНИЕ этого объекта?
                   │         │    (валидации, методы модели, бизнес-логика)
                   │         │    │
                   │         │    └─→ build(:user)
                   │         │        # new_record? = true
                   │         │        # Валидации работают корректно
                   │         │
                   │         └─── Объект нужен только как ДАННЫЕ?
                   │              (передаёте в другой сервис/метод)
                   │              │
                   │              └─→ build_stubbed(:user)
                   │                  # Быстрее, id stubbed
                   │                  # persisted? = true
```

### Примеры применения

```ruby
# attributes_for - параметры для Request spec
describe 'POST /api/users' do
  let(:user_params) { attributes_for(:user, :verified) }

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end
end

# build_stubbed - юнит-тест сервиса
describe PriceCalculator do
  let(:order) { build_stubbed(:order, total: 100) }
  let(:coupon) { build_stubbed(:coupon, discount: 10) }

  it 'applies discount' do
    result = described_class.new(order, coupon).calculate
    expect(result).to eq(90)
  end
end

# build - тестирование валидаций
describe User do
  let(:user) { build(:user, email: nil) }

  it 'requires email' do
    expect(user).not_to be_valid
    expect(user.errors[:email]).to include("can't be blank")
  end
end

# create - интеграционный тест
describe OrderService do
  let(:user) { create(:user, :with_payment_method) }

  it 'processes order' do
    service = described_class.new(user)
    expect { service.process }.to change(Order, :count).by(1)
  end
end
```

---

## Этап 4: Оптимизация дефолтных значений

### Цель
Настроить фабрики так, чтобы дефолтные значения соответствовали "среднему" happy path объекту.

### Почему это важно
Правильные дефолты уменьшают необходимость в явных параметрах и делают тесты чище.

### Правила дефолтных значений

| Тип атрибута | Стратегия | Пример |
|--------------|-----------|---------|
| Обязательные технические | Минимально валидные | `email { Faker::Internet.email }` |
| Бизнес-характеристики | Happy path значение | `status { 'active' }` |
| Опциональные | nil или минимум | `middle_name { nil }` |
| Timestamps | Автоматически Rails | Не указывать явно |

### Анализ для оптимизации

```ruby
# 1. Собрать статистику использования
# Если в 80% тестов пишем create(:user, verified: true)
# → Сделать verified дефолтным

# 2. Проверить Happy Path
# Если большинство happy path тестов требуют определённое состояние
# → Это кандидат на дефолт

# ❌ До оптимизации
let(:user) { create(:user, verified: true, active: true, newsletter: false) }
# Повторяется в 15 из 20 тестов

# ✅ После оптимизации в фабрике
factory :user do
  verified { true }      # Новый дефолт
  active { true }        # Новый дефолт
  newsletter { false }   # Новый дефолт

  trait :unverified do
    verified { false }
  end
end

# Теперь в тестах
let(:user) { create(:user) }  # Уже имеет нужные дефолты
```

---

## Этап 5: Скрытие технических деталей

### Цель
Вынести все технические атрибуты, не относящиеся к проверяемому поведению, внутрь фабрики.

### Почему это важно
Тесты должны показывать только бизнес-важные характеристики, а не технические требования валидации.

**Подробнее:** [Правило 9.1: Traits для характеристик](../guide.ru.md#91-traits-для-характеристик)

### Что скрывать в фабрике

| Скрывать | Оставлять явным | Обоснование |
|----------|-----------------|-------------|
| Обязательные поля для валидности | Характеристики из контекста | Контекст определяет что важно |
| Форматы (phone, email) | Состояния для проверки | Состояния - часть спецификации |
| Служебные поля (tokens, uuids) | Граничные значения | Граничные значения - суть теста |

### Техники скрытия

```ruby
# 1. Sequences для уникальности
factory :user do
  sequence(:email) { |n| "user#{n}@example.com" }
  sequence(:username) { |n| "user_#{n}" }
end

# 2. Faker для реалистичности
factory :address do
  street { Faker::Address.street_address }
  city { Faker::Address.city }
  postal_code { Faker::Address.postcode }
end

# 3. Callbacks для сложной логики
factory :order do
  after(:create) do |order|
    create_list(:order_item, 3, order: order) unless order.items.any?
  end
end

# 4. Transient attributes для управления
factory :user do
  transient do
    posts_count { 5 }
  end

  after(:create) do |user, evaluator|
    create_list(:post, evaluator.posts_count, user: user)
  end
end
```

---

## Этап 6: Создание составных трейтов для интеграции

### Цель
Создать трейты, объединяющие несколько характеристик для интеграционных тестов.

### Почему это важно
В интеграционных тестах мы объединяем детали одного домена. Составные трейты документируют эти объединения.

**Подробнее:** [Правило 4.2: Постройте иерархию: зависимые / независимые](../guide.ru.md#42-постройте-иерархию-зависимые--независимые), [Правило 9.1: Traits для характеристик](../guide.ru.md#91-traits-для-характеристик)

### Паттерны составных трейтов

```ruby
factory :user do
  # Базовые трейты
  trait :verified do
    email_verified { true }
  end

  trait :with_payment_card do
    after(:create) do |user|
      create(:payment_card, user: user)
    end
  end

  trait :with_sufficient_balance do
    after(:create) do |user|
      user.payment_card.update(balance: 1000)
    end
  end

  # Составной трейт для Request specs
  trait :payment_ready do
    verified
    with_payment_card
    with_sufficient_balance

    after(:create) do |user|
      user.payment_card.update(verified: true)
    end
  end
end

# Использование в интеграционном тесте
describe 'POST /api/payments' do
  # Вместо создания всех предусловий вручную
  let(:user) { create(:user, :payment_ready) }

  it 'processes payment' do
    post '/api/payments', headers: auth_headers(user)
    expect(response).to have_http_status(:created)
  end
end
```

### Naming Convention для составных трейтов

| Паттерн | Использование | Пример |
|---------|---------------|---------|
| `:ready_for_X` | Все предусловия для действия X | `:ready_for_checkout` |
| `:with_complete_X` | Полный набор X | `:with_complete_profile` |
| `:X_eligible` | Подходит для X | `:discount_eligible` |

### Антипаттерн: избыточные составные трейты

Не создавайте составной трейт, если комбинация используется редко (1-2 раза в тестах). Композиция напрямую читаемее и не создаёт лишней абстракции.

#### Когда составной трейт НЕ нужен

```ruby
# ❌ Плохо: over-engineering для редкой комбинации
trait :admin_with_posts do
  admin
  with_posts
end

# Используется только в одном тесте
let(:user) { create(:user, :admin_with_posts) }
```

```ruby
# ✅ Хорошо: явная композиция для редких случаев
let(:user) { create(:user, :admin, :with_posts) }
```

#### Когда составной трейт НУЖЕН

```ruby
# ✅ Хорошо: частая комбинация в интеграционных тестах
trait :payment_ready do
  verified
  with_payment_card
  with_sufficient_balance
end

# Используется в 10+ request specs
let(:user) { create(:user, :payment_ready) }
```

**Эмпирическое правило:** Если комбинация трейтов повторяется 3+ раза в разных тестах → создавайте составной трейт. Если 1-2 раза → используйте композицию напрямую.

---

## Этап 7: Рефакторинг тестов с новыми фабриками

### Цель
Заменить явную инициализацию объектов на использование фабрик с трейтами.

### Почему это важно
После создания фабрик нужно обновить тесты, чтобы получить выгоду от проделанной работы.

### Процесс рефакторинга

```ruby
# ❌ До: явная инициализация
describe OrderService do
  let(:user) do
    User.create(
      email: 'test@example.com',
      verified: true,
      subscription: 'premium'
    )
  end

  let(:payment_card) do
    PaymentCard.create(
      user: user,
      verified: true,
      balance: 500
    )
  end

  context 'when user has sufficient balance' do
    it 'processes order' do
      # ...
    end
  end
end

# ✅ После: фабрики с трейтами
describe OrderService do
  let(:user) { create(:user, :premium, :payment_ready) }

  context 'when user has sufficient balance' do
    it 'processes order' do
      # ...
    end
  end
end
```

### Чек-лист рефакторинга
- [ ] Заменить `Model.create(...)` на `create(:model, traits)`
- [ ] Заменить хэши параметров на `attributes_for`
- [ ] Заменить `create` на `build_stubbed` где возможно
- [ ] Убрать дублирующиеся `let` блоки
- [ ] Проверить, что тесты всё ещё проходят

---

## Этап 8: Оптимизация производительности

### Цель
Ускорить тесты через правильное использование методов FactoryBot.

### Почему это важно
Медленные тесты снижают продуктивность и мотивацию запускать их часто.

### Техники оптимизации

#### 8.1 Замена create на build_stubbed

```ruby
# Анализ: где объект используется только для чтения?
describe DiscountCalculator do
  # ❌ До: лишнее обращение к БД
  let(:order) { create(:order, total: 100) }

  # ✅ После: объект в памяти
  let(:order) { build_stubbed(:order, total: 100) }
end
```

#### 8.2 Ленивая загрузка через let

```ruby
# ❌ let! создаёт объект сразу
let!(:admin) { create(:user, :admin) }
let!(:moderator) { create(:user, :moderator) }

# ✅ let создаёт только при использовании
let(:admin) { create(:user, :admin) }
let(:moderator) { create(:user, :moderator) }
```

#### 8.3 Переиспользование объектов

```ruby
# ⚠️ Для read-only объектов можно использовать let_it_be (test-prof gem)
# ВНИМАНИЕ: Используйте только для справочных данных, которые ГАРАНТИРОВАННО
# не изменяются в тестах. Может нарушить изоляцию и усложнить отладку.
let_it_be(:category) { create(:category) }

# Безопаснее: обычный let (создаётся для каждого теста)
let(:category) { create(:category) }

# Или before(:all) для группы тестов (также с рисками изоляции)
before(:all) do
  @shared_config = create(:app_config)
end
```

### Метрики для отслеживания

```bash
# Профилирование медленных примеров
rspec --profile 10

# Подсчёт SQL-запросов (с test-prof)
TPROF=sql rspec spec/models/user_spec.rb

# Анализ создания фабрик
FPROF=1 rspec spec/
```

---

## Этап 9: Финальная проверка

### Цель
Убедиться, что оптимизация с FactoryBot достигла целей.

### Чек-лист проверки

#### Читаемость
- [ ] В тестах видны только бизнес-характеристики
- [ ] Трейты называются по состояниям характеристик
- [ ] Нет дублирования атрибутов в тестах

#### Производительность
- [ ] Использован `build_stubbed` где возможно
- [ ] `attributes_for` для параметров запросов
- [ ] Нет лишних `create` для read-only данных

#### Поддерживаемость
- [ ] Трейты имеют самодокументирующие названия
- [ ] Составные трейты для интеграционных тестов
- [ ] Дефолты соответствуют happy path

#### Соответствие правилам
- [ ] Правило 9.1: Технические детали скрыты
- [ ] Правило 9.2: `attributes_for` для параметров
- [ ] Правило 9.3: `build_stubbed` в юнит-тестах
- [ ] Правило 8: Явность характеристик сохранена

### Команды для проверки

```bash
# Убедиться, что тесты проходят
bundle exec rspec

# Проверить скорость
bundle exec rspec --profile 10

# Найти неиспользуемые фабрики (с factory_bot_rails)
bundle exec rake factory_bot:lint
```

---

## Антипаттерны FactoryBot

| Антипаттерн | Проблема | Решение |
|-------------|----------|---------|
| Фабрика-монстр | Одна фабрика с 50+ трейтами | Разделить на несколько фабрик |
| Трейты-implementation | `:with_5_posts` вместо состояния | Использовать transient attributes (см. [правило 9.1](../guide.ru.md#91-traits-для-характеристик)) |
| Божественные дефолты | Дефолт создаёт полный граф объектов | Минимальные дефолты + трейты |
| Mystery guest | Фабрика создаёт скрытые связи | Явные associations в трейтах |
| Хрупкие фабрики | Падают при изменении модели | Минимум обязательных атрибутов ([Правило 9.1](../guide.ru.md#91-traits-для-характеристик)) |

---

## Примеры миграции: До и После

### Пример 1: Простая модель

```ruby
# ❌ До оптимизации
describe User do
  let(:user) do
    User.create!(
      email: 'john@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      confirmed: true,
      role: 'customer',
      created_at: 2.days.ago
    )
  end

  context 'when user is admin' do
    let(:admin) do
      User.create!(
        email: 'admin@example.com',
        password: 'password123',
        first_name: 'Admin',
        last_name: 'User',
        confirmed: true,
        role: 'admin',
        created_at: 1.year.ago
      )
    end
    # ...
  end
end

# ✅ После оптимизации
describe User do
  let(:user) { create(:user) }

  context 'when user is admin' do
    let(:admin) { create(:user, :admin) }
    # ...
  end
end
```

### Пример 2: Request spec с параметрами

```ruby
# ❌ До оптимизации
describe 'POST /api/users' do
  let(:user_params) do
    {
      email: 'test@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      phone: '+1234567890',
      role: 'customer',
      newsletter: true,
      timezone: 'UTC'
    }
  end

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end
end

# ✅ После оптимизации
describe 'POST /api/users' do
  let(:user_params) { attributes_for(:user, :customer) }

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end

  context 'when creating premium user' do
    let(:user_params) { attributes_for(:user, :premium) }
    
    it 'creates user with premium subscription' do
      post '/api/users', params: user_params
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['subscription_type']).to eq('premium')
    end
  end
end
```

---

## Заключение

Оптимизация с FactoryBot — это не просто DRY, а создание языка описания тестовых данных, который:

1. **Соответствует характеристикам из тестов** — трейты = состояния ([Правило 4.1](../guide.ru.md#41-выделите-характеристики-и-состояния))
2. **Скрывает техническую сложность** — фокус на бизнес-логике ([Правило 9.1](../guide.ru.md#91-traits-для-характеристик))
3. **Ускоряет выполнение** — правильные методы для правильных задач ([Правила 9.2-9.3](../guide.ru.md#92-attributes_for-для-параметров))
4. **Упрощает поддержку** — изменения в одном месте

Помните: фабрики — это часть документации вашего домена. Они должны быть понятны новым членам команды и отражать бизнес-правила, а не технические детали реализации.

**Дополнительные материалы:**
- [Все правила FactoryBot в основном гайде](../guide.ru.md#9-factorybot-фабрики-traits-методы)
- [Правило 9.1: Traits для характеристик](../guide.ru.md#91-traits-для-характеристик)
