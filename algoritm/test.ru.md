# Алгоритм написания BDD-тестов на RSpec

## Введение: Философия подхода

Этот алгоритм построен на принципах **Behaviour-Driven Development (BDD)** и направлен на создание тестов, которые:
- Служат исполняемой документацией бизнес-правил
- Минимизируют когнитивную нагрузку при чтении и поддержке
- Выявляют проблемы дизайна кода через сложность тестов
- Фокусируются на поведении, а не на реализации

**Философия подробно:** [Про RSpec](../../guide.ru.md#про-rspec) | [Когнитивная нагрузка](../../guide.ru.md#почему-мы-пишем-тесты-именно-так-когнитивная-нагрузка) | [Тесты как индикатор качества кода](../../guide.ru.md#тесты-как-индикатор-качества-кода)

## Этап 1: Определение уровня тестирования

### Цель
Определить на каком уровне пирамиды тестирования находится ваш тест, чтобы понять объём проверок и степень детализации.

### Почему это важно
Разные уровни тестов имеют разную ответственность. Юнит-тесты проверяют **все комбинации**, интеграционные — **happy path + критичные corner cases**.

**Подробнее:** [Пирамида тестирования и выбор уровня](../guide.ru.md#пирамида-тестирования-и-выбор-уровня)

### Как определить уровень

| Уровень | Что тестируем | Степень детализации | Пример |
|---------|---------------|-------------------|---------|
| **Юнит** | Независимый класс/модель | Все комбинации характеристик | `PriceCalculator`, `User` model |
| **Интеграционный** | Взаимодействие компонентов | Happy path + критичные cases | Service calling repository |
| **Request/API** | HTTP-контракт | Основные сценарии + ошибки | `POST /api/orders` |

### Пример решения
```ruby
# Тестируем PriceCalculator#calculate
# Это независимый класс → ЮНИТ-ТЕСТ
# Будем проверять все комбинации скидок, налогов, промокодов

# Тестируем POST /api/payments
# Это HTTP endpoint → REQUEST SPEC
# Объединим payment prerequisites в одну характеристику
```

### ⚠️ Важно
Системные (E2E) тесты на RSpec в современных Rails-проектах практически не пишутся из-за разделения на API + React frontend.

---

## Этап 2: Сбор характеристик

### Цель
Выделить все доменные аспекты, влияющие на поведение тестируемого кода.

### Почему это важно
Характеристики — это бизнес-факты, а не технические детали. Они формируют язык общения с бизнесом и структуру тестов.

**Подробнее:** [Правило 4: Выделяйте характеристики поведения и их состояния](../guide.ru.md#4-выделяйте-характеристики-поведения-и-их-состояния)

### Как собирать характеристики

#### Для юнит-тестов: все характеристики детально
```ruby
# Класс: OrderDiscountCalculator
# Характеристики:
# 1. Тип клиента (b2c/b2b)
# 2. Сумма заказа (< 100 / >= 100)
# 3. Наличие промокода (есть/нет)
# 4. Сезонная скидка (активна/неактивна)
```

#### Для интеграционных тестов: объединение по доменам
```ruby
# Эндпоинт: POST /api/payments
# Характеристики верхнего уровня:
# 1. Аутентификация (authenticated/not authenticated)
# 2. Payment prerequisites (объединяет: card verified + sufficient balance)
#    ↳ Детали скрыты в юнит-тесте PaymentService
# 3. Идемпотентность (новый запрос/повторный)
```

### Техника объединения характеристик

**До объединения (избыточная детализация в интеграционном тесте):**
```ruby
# ❌ Плохо для request spec
- Пользователь аутентифицирован
- Карта привязана
- Карта верифицирована
- Баланс достаточен
- Лимиты не превышены
```

**После объединения по домену:**
```ruby
# ✅ Хорошо для request spec
- Пользователь аутентифицирован
- Payment prerequisites met (включает всё выше)
```

### ✅ Чек-лист
- [ ] Характеристика описывает бизнес-факт, а не техническую деталь?
- [ ] Можно сформулировать характеристику понятным языком для бизнеса?
- [ ] Для интеграционных тестов: объединили детали одного домена?

**См. также:** [Глоссарий: Характеристики и состояния](../guide.ru.md#характеристики-и-состояния)

---

## Этап 3: Определение зависимостей характеристик

### Цель
Построить иерархию характеристик, выявив какие из них зависимы, а какие независимы.

### Почему это важно
Зависимости определяют структуру контекстов. Правильная иерархия снижает когнитивную нагрузку — читатель сразу видит логические связи.

**Подробнее:** [Правило 5: Стройте иерархию context по зависимостям характеристик](../guide.ru.md#5-стройте-иерархию-context-по-зависимостям-характеристик-happy-path--corner-cases)

### Типы зависимостей

| Тип | Описание | Пример |
|-----|----------|---------|
| **Базовая** | Без неё другие не имеют смысла | Наличие карты |
| **Зависимая** | Имеет смысл только при определённом состоянии базовой | Баланс карты (только если карта есть) |
| **Независимая** | Не зависит от других характеристик | Роль пользователя и beta-доступ |

### Построение иерархии

```ruby
# Пример зависимых характеристик
Оплата картой
├── Наличие карты (базовая)
│   └── Баланс карты (зависимая от наличия карты)
│       └── Лимит транзакции (зависимая от баланса)
└── [Нет карты → остальные характеристики не рассматриваются]

# Пример независимых характеристик (можно менять порядок)
Доступ к функции
├── Роль пользователя
│   └── Beta-доступ
или
├── Beta-доступ
│   └── Роль пользователя
```

### Важное уточнение
Этап 3 — это поиск зависимостей для **всех уровней** иерархии, а не только для верхнего. Каждая характеристика может иметь свои зависимые подхарактеристики.

### ⚠️ Сигнал проблемы
Если иерархия уходит глубже 4-5 уровней — код нарушает принцип "Do One Thing". Это проблема кода, не тестов.

**См. также:** [Глоссарий: Принципы проектирования — Do One Thing](../guide.ru.md#принципы-проектирования)

---

## Этап 4: Определение типов характеристик

### Цель
Классифицировать каждую характеристику для правильного определения количества состояний.

### Почему это важно
Тип характеристики определяет количество контекстов и помогает не пропустить edge cases.

### Классификация типов

| Тип | Состояния | Пример | Количество контекстов |
|-----|-----------|---------|---------------------|
| **Бинарная** | 2 варианта | Карта есть/нет | 2 |
| **Множественная enum** | N вариантов | Роль: admin/manager/user | 3+ |
| **Диапазон** | Группы значений | Баланс: хватает/не хватает | 2+ |
| **Последовательная** | Упорядоченные состояния | Статус: draft→pending→paid | 3+ |

### Особый случай: диапазоны

Диапазоны нужно разбивать на бизнес-значимые группы:

```ruby
# ❌ Плохо: технические границы
balance == 0
balance == 99
balance == 100
balance == 101

# ✅ Хорошо: бизнес-состояния
balance < price    # Не хватает для оплаты
balance >= price   # Хватает для оплаты
```

### Пример анализа
```ruby
# Характеристика: Подписка пользователя
# Тип: Множественная enum
# Состояния: trial / basic / premium / expired
# Контекстов будет: 4
```

---

## Этап 5: Определение состояний и дефолтов

### Цель
Перечислить все возможные состояния каждой характеристики и выявить дефолтные.

### Почему это важно
Дефолтное состояние не требует отдельного контекста, что упрощает структуру тестов. Явное перечисление состояний гарантирует полноту покрытия.

### Правила определения дефолта

| Ситуация | Дефолт | Пример |
|----------|--------|---------|
| Новый объект | Начальное состояние | User: `blocked: false` |
| Типичный сценарий | Наиболее частое | Order: `status: 'pending'` |
| Happy path | Успешное состояние | Payment: `successful: true` |

### Пример таблицы состояний

```ruby
# Сервис: PaymentProcessor
# Характеристики и состояния:

| Характеристика     | Тип      | Состояния           | Дефолт    |
|-------------------|----------|---------------------|-----------|
| User authentication | Бинарная | authenticated/guest | guest     |
| Payment method    | Enum     | card/paypal/crypto | card      |
| Amount            | Диапазон | valid/exceeded      | valid     |
| Fraud check       | Бинарная | passed/failed       | passed    |
```

### Влияние на структуру контекстов

```ruby
# Характеристика с дефолтом (card — дефолт)
describe '#process_payment' do
  # Дефолт не требует контекста
  it 'processes card payment'

  context 'when payment method is paypal' do
    it 'processes paypal payment'
  end
end

# Характеристика без дефолта
describe '#apply_discount' do
  context 'when customer is b2c' do
    it 'applies consumer discount'
  end

  context 'when customer is b2b' do
    it 'applies business discount'
  end
end
```

---

## Этап 6: Построение дерева контекстов

### Цель
Трансформировать иерархию характеристик в структуру RSpec-контекстов.

### Почему это важно
Правильная структура контекстов делает тесты самодокументируемыми и отражает бизнес-логику.

**Подробнее:** [Правило 20: Язык контекстов when/with/and/without/but/NOT](../guide.ru.md#20-язык-контекстов-when--with--and--without--but--not)

### Правила построения

1. **Один уровень характеристики = один уровень `context`**
2. **Дефолтное состояние = без контекста**
3. **Недефолтные состояния = отдельные контексты**
4. **Соблюдать язык when/with/and/without/but**

### Язык контекстов (по приоритету)

| Связка | Использование | Пример |
|--------|--------------|---------|
| `when` | Открывает ветку, базовая характеристика | `when user has a card` |
| `with` | Положительное уточнение (happy path) | `with sufficient balance` |
| `and` | Дополнительное положительное состояние | `and card is verified` |
| `without` | Отсутствие (для бинарных) | `without email verification` |
| `but` | Противопоставление happy path | `but balance is insufficient` |

### Пример построения

```ruby
# Характеристики:
# 1. Наличие карты (бинарная, нет дефолта)
#    └── 2. Баланс (диапазон: sufficient/insufficient)

describe PaymentService do
  context 'when user has a payment card' do           # Уровень 1
    context 'with sufficient balance' do               # Уровень 2, happy path
      # здесь будет it на этапе 7
    end

    context 'but balance is insufficient' do           # Уровень 2, corner case
      # здесь будет it на этапе 7
    end
  end

  context 'when user does NOT have a payment card' do  # Уровень 1, альтернатива
    # здесь будет it на этапе 7
  end
end
```

### Примечание
На этом этапе мы строим только структуру контекстов. Конкретные `it` с описаниями поведений добавим на Этапе 7.

---

## Этап 7: Определение ожидаемых поведений

### Цель
Для каждого листового контекста определить наблюдаемое поведение и классифицировать как happy path или corner case.

### Почему это важно
1. **Проверка согласованности:** Убеждаемся, что в одном контексте не смешались happy path и corner cases
2. **Подготовка к сортировке:** Определив тип каждого `it`, мы понимаем тип контекста для правильной сортировки на Этапе 8
3. **Читаемость:** Чёткое разделение помогает читателю быстро понять основной сценарий и возможные отклонения

**Подробнее:** 
- [Правило 1: Тестируйте поведение, а не реализацию](../guide.ru.md#1-тестируйте-поведение-а-не-реализацию)
- [Правило 3: Каждый it описывает одно наблюдаемое поведение](../guide.ru.md#3-каждый-example-it-описывает-одно-наблюдаемое-поведение)

### Как это работает
- Если листовой `it` описывает успешное/ожидаемое поведение → это happy path
- Контекст, содержащий happy path `it` → happy path контекст
- Контекст с corner case `it` → corner case контекст
- Дефолтное состояние без контекста с happy path `it` → будет поднято вверх на этапе 8

### Классификация поведений

| Тип | Описание | Маркеры в описании |
|-----|----------|-------------------|
| **Happy path** | Основной успешный сценарий | "successfully", "creates", "returns" |
| **Corner case** | Отклонение, ошибка, защита | "rejects", "fails", "raises", "denies" |

### Техника формулировки `it`

```ruby
# Формула: [глагол в 3-м лице] + [объект] + [уточнение]

# Happy path
it 'creates user account'
it 'sends confirmation email'
it 'returns success status'

# Corner cases
it 'rejects invalid data'
it 'raises AuthenticationError'
it 'does NOT create duplicate'  # NOT капсом для отрицания
```

### Пример определения поведений

```ruby
describe OrderService do
  # Happy path контексты
  context 'when all prerequisites met' do
    it 'creates order'                    # ✅ happy path
    it 'charges payment method'           # ✅ happy path
    it 'sends confirmation'               # ✅ happy path
  end

  # Corner case контексты
  context 'when payment fails' do
    it 'does NOT create order'            # ⚠️ corner case
    it 'returns error message'            # ⚠️ corner case
  end
end
```

---

## Этап 8: Сортировка по принципу Happy Path First

### Цель
Упорядочить контексты и примеры так, чтобы успешные сценарии шли первыми.

### Почему это важно
Читатель сначала понимает "как должно работать", а затем "что может пойти не так".

**Подробнее:** [Правило 7: Располагайте happy path перед corner cases](../guide.ru.md#7-располагайте-happy-path-перед-corner-cases)

### Правила сортировки

1. **На каждом уровне: happy path контексты первыми**
2. **Внутри контекста: положительные тесты первыми**
3. **Corner cases: от менее критичных к более критичным**

### Пример до и после

```ruby
# ❌ До сортировки (хаотично)
describe '#process_order' do
  context 'when payment fails' do
    it 'cancels order'
  end

  context 'when inventory insufficient' do
    it 'puts on backorder'
  end

  context 'when everything valid' do
    it 'completes order'
  end
end

# ✅ После сортировки
describe '#process_order' do
  context 'when everything valid' do          # 1. Happy path
    it 'completes order'
  end

  context 'when inventory insufficient' do    # 2. Soft failure
    it 'puts on backorder'
  end

  context 'when payment fails' do            # 3. Hard failure
    it 'cancels order'
  end
end
```

---

## Этап 9: Полировка языка описаний

### Цель
Убедиться, что все описания следуют BDD-принципам и описывают поведение, а не реализацию.

### Почему это важно
1. **Тесты — это исполняемая документация:** Они должны читаться как спецификация бизнес-правил
2. **Читаемый вывод при падении:** Правильные описания помогают быстро понять, какое правило нарушено
3. **Единый язык с бизнесом:** Описания должны быть понятны не только разработчикам

**Подробнее:** 
- [Правило 17: Описание должно составлять валидное предложение](../guide.ru.md#17-описание-контекстов-context-и-тестовых-кейсов-it-вместе-включая-it-должны-составлять-валидное-предложение-на-английском-языке)
- [Правило 18: Описание должно быть понятно любому человеку](../guide.ru.md#18-описание-контекстов-context-и-тестовых-кейсов-it-вместе-включая-it-должны-быть-написаны-так-чтобы-их-понимал-любой-человек)
- [Правило 19: Грамматика формулировок в describe/context/it](../guide.ru.md#19-грамматика-формулировок-в-describecontextit)

### Чек-лист языка

#### 9.1 Проверка на поведение vs реализация

```ruby
# ❌ Реализация
it 'sets status attribute to paid'
it 'calls EmailService.send'
it 'returns true'

# ✅ Поведение
it 'marks order as paid'
it 'notifies customer about payment'
it 'allows order processing'
```

#### 9.2 Грамматическая проверка

| Элемент | Правило | Пример |
|---------|---------|---------|
| `describe` | Существительное или #метод | `describe User`, `describe '#calculate'` |
| `context` | when/with/and/without/but + состояние | `when user is admin` |
| `it` | Глагол 3-го лица + результат | `returns calculated price` |

#### 9.3 Проверка читаемости цепочки

```ruby
# Собираем описания в предложение:
# PaymentService
#   when customer has premium account
#     and payment amount exceeds limit
#       but manager approved override
#         it processes payment with override flag

# ✅ Читается как история? Да!
```

### Антипаттерны в описаниях

| Антипаттерн | Пример | Исправление |
|-------------|---------|-------------|
| Технический жаргон | `when flag is true` | `when feature is enabled` |
| Неясные описания | `when condition met` | `when user has sufficient balance` |
| Избыточные should | `it should create user` | `it creates user` |

---

## Этап 10: Реализация контекстов (Given)

### Цель
Внести изменения данных, которые делают описание каждого контекста истинным.

### Почему это важно
Контекст должен явно готовить только то, что описано. Это принцип явности и соответствия описания реальности.

**Подробнее:** 
- [Правило 11: Каждый тест должен быть разделен на 3 этапа](../guide.ru.md#11-каждый-тест-должен-быть-разделен-на-3-этапа-в-строгой-последовательности)
- [Правило 12: Используйте возможности FactoryBot](../guide.ru.md#12-используйте-возможности-factorybot-для-скрытия-деталей-исходных-данных)

### Правила размещения

```ruby
context 'when user is blocked' do
  let(:blocked) { true }          # ← Сразу под context
  let(:blocked_at) { 2.days.ago } # ← Все let вместе

  # Не здесь! Не прячьте внизу
end
```

### Три фазы теста

```ruby
describe Calculator do
  # 1️⃣ GIVEN (Этап 10): Подготовка данных
  let(:tax_rate) { 0.1 }
  let(:discount) { 0.2 }

  # 2️⃣ WHAT (Этап 11): Что тестируем
  subject(:result) { described_class.calculate(100, tax: tax_rate, discount: discount) }

  # 3️⃣ THEN (Этап 12): Проверка
  it 'applies tax and discount' do
    expect(result).to eq(88) # (100 - 20%) + 10% = 88
  end
end
```

### Использование фабрик

**Подробнее:** 
- [Правило 12: Используйте возможности FactoryBot](../guide.ru.md#12-используйте-возможности-factorybot-для-скрытия-деталей-исходных-данных)
- [Правило 14: В юнит-тестах используйте build_stubbed](../guide.ru.md#14-в-юнит-тестах-кроме-моделей-используйте-build_stubbed)
- [Выбор метода FactoryBot: Decision Tree](../guide.ru.md#выбор-метода-factorybot-decision-tree)

```ruby
# ❌ Плохо: технические детали
let(:user) do
  create(:user,
    email: 'test@example.com',
    password: 'password123',
    confirmed_at: Time.current,
    role: 'admin',
    blocked: false)
end

# ✅ Хорошо: бизнес-характеристики через трейты
let(:user) { create(:user, :admin, :confirmed) }
```

---

## Этап 11: Определение предмета тестирования (subject)

### Цель
Явно указать что тестируем через именованный `subject(:name)`.

### Почему это важно
- Читатель сразу видит предмет тестирования
- Избегаем повторений вызова метода в каждом `it`
- Завершает трёхфазную структуру: Given (let) → What (subject) → Then (expect)

**Подробнее:** [Правило 10: Указывайте subject](../guide.ru.md#10-указывайте-subject-чтобы-явно-обозначить-предмет-тестирования)

### Правила

1. **Subject всегда именован:** `subject(:name)`, не безымянный
2. **Определяется один раз:** на уровне `describe`
3. **Изменения через let:** переопределяйте `let`, а не `subject`

### Пример

```ruby
describe PriceCalculator do
  subject(:total) { calculator.calculate(order, tax_rate) }
  
  let(:calculator) { described_class.new }
  let(:order) { build(:order, subtotal: 100) }
  
  context 'with standard tax' do
    let(:tax_rate) { 0.2 }
    it { expect(total).to eq(120) }
  end
  
  context 'with reduced tax' do
    let(:tax_rate) { 0.1 }
    it { expect(total).to eq(110) }
  end
end
```

### ✅ Чек-лист
- [ ] Subject всегда именован: `subject(:name)`?
- [ ] Определён один раз на уровне `describe`?
- [ ] Изменения через переопределение `let`?

---

## Этап 12: Написание ожиданий (Then)

### Цель
Зафиксировать наблюдаемый результат в виде RSpec-ожиданий.

### Почему это важно
1. **Читаемый вывод при падении:** Правильные матчеры дают понятные сообщения об ошибках
2. **Предотвращение flaky specs:** Неправильный матчер привязывает к деталям реализации, создавая нестабильные тесты
3. **Точность проверки:** Матчер должен проверять именно то поведение, которое описано в `it`

**Подробнее:** [Правило 28: Делайте вывод падения теста читаемым](../guide.ru.md#28-делайте-вывод-падения-теста-читаемым)

### Последствия неправильного выбора матчера

| Проблема | Пример | Последствие |
|----------|---------|-------------|
| Привязка к порядку | `eq([1, 2, 3])` для массива | Flaky test при изменении порядка выборки из БД |
| Проверка лишнего | `eq(full_hash)` для API | Тест падает при добавлении нового поля |
| Нечитаемый вывод | Сравнение JSON строкой | При падении — стена текста без указания отличий |

### Выбор правильного матчера

| Что проверяем | Плохой матчер | Хороший матчер | Почему |
|--------------|---------------|----------------|---------|
| Состав массива | `eq([1, 2, 3])` | `match_array([1, 2, 3])` | Не зависит от порядка |
| Наличие ключей | `eq(hash)` | `include(key: value)` | Проверяет только важное |
| Атрибуты объекта | Много `expect` | `have_attributes(...)` | Компактно + aggregate_failures |
| Изменение состояния | Проверка до/после | `change { }.from().to()` | Явно показывает изменение |

### Примеры ожиданий

```ruby
# Изменение состояния
it 'creates order' do
  expect { process_order }
    .to change(Order, :count).by(1)
    .and change { user.orders.count }.by(1)
end

# Интерфейс объекта
it 'builds complete profile' do
  expect(profile).to have_attributes(
    name: 'John Doe',
    email: 'john@example.com',
    premium: true
  )
end

# HTTP-ответ
it 'returns success response' do
  expect(response).to have_http_status(:created)
  expect(response.parsed_body).to include(
    'status' => 'success',
    'order_id' => kind_of(Integer)
  )
end
```

---

## Этап 13: Запуск и отладка

### Цель
Убедиться, что тесты работают и действительно проверяют поведение.

### Почему это важно
Тест, который никогда не падал, не доказывает ничего. Нужно убедиться, что он ловит баги.

**Подробнее:** [Правило 2: Проверяйте, что тест тестирует](../guide.ru.md#2-проверяйте-что-тест-тестирует)

### Процесс проверки

#### 13.1 Первый запуск
```bash
rspec spec/services/payment_service_spec.rb
```

#### 13.2 Если тесты падают

| Проверка | Действие |
|----------|----------|
| Правильность контекстов? | Проверить let/before в контекстах |
| Правильность ожиданий? | Проверить expect и матчеры |
| Код работает правильно? | Возможно, нашли баг в коде |
| Пропущен edge case? | Тесты часто находят неучтённые случаи |

#### 13.3 Проверка "ручной Red"

```ruby
# Временно сломайте код
def calculate_discount
  return 0  # ← Временно возвращаем неправильное значение
  # ... остальной код
end

# Запустите тест - он ДОЛЖЕН упасть
# Если не упал - тест не работает!
```

---

## Этап 14: Проверка на дублирование

### Цель
Выявить скрытые характеристики и инвариантные контракты через анализ дублирования.

### Почему это важно
Дублирование в тестах — это сигнал о пропущенных абстракциях или неправильной структуре.

**Подробнее:** 
- [Правило 6: Финальный аудит контекстов](../guide.ru.md#6-финальный-аудит-контекстов-два-типа-дубликатов)
- [Правило 25: Используйте shared examples для декларации контрактов](../guide.ru.md#25-используйте-shared-examples-для-декларации-контрактов)

### 14.1 Дубликаты подготовки (let/before)

```ruby
# ❌ Сигнал: одинаковые let на одном уровне
context 'when order is small' do
  let(:shipping_cost) { 10 }  # ← дублируется
  it 'charges standard shipping'
end

context 'when order is large' do
  let(:shipping_cost) { 10 }  # ← дублируется
  it 'charges for heavy items'
end

# ✅ Решение: вынести уровень выше или выделить характеристику
let(:shipping_cost) { 10 }  # По умолчанию

context 'when order is small' do
  it 'charges standard shipping'
end

context 'when order is large' do
  context 'with free shipping promo' do
    let(:shipping_cost) { 0 }  # Переопределяем
    it 'waives shipping charges'
  end
end
```

### 14.2 Дубликаты ожиданий

```ruby
# Если одни и те же проверки во всех листовых контекстах
# ❌ До
context 'when payment by card' do
  it 'returns transaction object' do
    expect(result).to respond_to(:id)
    expect(result).to respond_to(:status)
    expect(result).to respond_to(:amount)
  end
end

context 'when payment by paypal' do
  it 'returns transaction object' do
    expect(result).to respond_to(:id)      # ← те же проверки
    expect(result).to respond_to(:status)
    expect(result).to respond_to(:amount)
  end
end

# ✅ После: shared_examples
shared_examples 'a transaction result' do
  it { is_expected.to respond_to(:id, :status, :amount) }
end

context 'when payment by card' do
  it_behaves_like 'a transaction result'
  it 'includes card details' do
    expect(result.card_last_four).to eq('1234')
  end
end
```

---

## Этап 15: Финальная проверка качества

### Цель
Убедиться, что тесты следуют всем best practices и дают читаемый вывод при падении.

**Подробнее:** 
- [Правило 3: Каждый it описывает одно наблюдаемое поведение](../guide.ru.md#3-каждый-example-it-описывает-одно-наблюдаемое-поведение)
- [Правило 23: Используйте aggregate_failures только для интерфейсов](../guide.ru.md#23-используйте-aggregate_failures-только-когда-описываете-одно-правило)

### 15.1 Одно поведение на один it

```ruby
# ❌ Несколько поведений
it 'processes order' do
  expect { process }.to change(Order, :count).by(1)
  expect(mailer).to receive(:send_confirmation)
  expect(inventory).to receive(:decrease)
end

# ✅ Разделено
it 'creates order' do
  expect { process }.to change(Order, :count).by(1)
end

it 'sends confirmation' do
  expect { process }.to have_enqueued_job(ConfirmationJob)
end

it 'updates inventory' do
  expect { process }.to change { product.reload.stock }.by(-1)
end
```

### 15.2 Правильное использование aggregate_failures

```ruby
# ✅ Когда использовать: интерфейс объекта
it 'provides complete user data', :aggregate_failures do
  expect(user.name).to eq('John')
  expect(user.email).to eq('john@example.com')
  expect(user.age).to eq(30)
end

# ❌ Когда НЕ использовать: независимые поведения
it 'creates and notifies', :aggregate_failures do  # ← НЕТ!
  expect { service.call }.to change(User, :count)
  expect { service.call }.to have_enqueued_job
end
```

### 15.3 Читаемость вывода при падении

```ruby
# ❌ Плохой вывод
expect(response.body).to eq("{\"status\":\"ok\"}")
# Failure: expected: "{\"status\":\"ok\"}"
#              got: "{\"status\":\"error\"}"

# ✅ Хороший вывод
expect(response.parsed_body).to include('status' => 'ok')
# Failure: expected hash to include {"status" => "ok"}
#          got: {"status" => "error", "message" => "Invalid"}
```

---

## Этап 16: Финальная полировка

### Цель
Привести тесты к production-ready состоянию.

### Контрольный список

- [ ] **Тесты проходят:** `rspec --format documentation`
- [ ] **Линтер доволен:** `rubocop spec/`
- [ ] **Нет flaky-тестов:** запустите несколько раз
- [ ] **Время стабильно:** использован `freeze_time` где нужно
- [ ] **Фабрики оптимальны:** `build_stubbed` > `build` > `create`
- [ ] **Читается как документация:** покажите коллеге
- [ ] **Соответствует гайдлайну:** проверьте по чек-листу из основного руководства
- [ ] **Subject определён:** явно указан предмет тестирования (Этап 11)
- [ ] **Три этапа чёткие:** Given (Этап 10) → Subject (Этап 11) → Then (Этап 12)

### Команды для проверки

```bash
# Полный прогон с документацией
bundle exec rspec --format documentation

# Проверка стиля
bundle exec rubocop spec/

# Поиск медленных тестов
bundle exec rspec --profile 10

# Случайный порядок (проверка независимости)
bundle exec rspec --order random
```

---

## Примеры: От алгоритма к коду

### Пример 1: Юнит-тест калькулятора скидок

```ruby
# Шаг 1: Уровень = Юнит (независимый класс)
# Шаг 2: Характеристики = тип клиента, сумма заказа, наличие купона
# Шаг 3-5: Иерархия и состояния

describe DiscountCalculator do
  subject(:discount) { described_class.new(order).calculate }

  let(:order) { build(:order, customer_type: customer_type, total: total, coupon: coupon) }
  let(:coupon) { nil } # Дефолт: нет купона

  # Уровень 1: Тип клиента (нет дефолта)
  context 'when customer is regular' do
    let(:customer_type) { :regular }

    # Уровень 2: Сумма заказа
    context 'with order under $100' do
      let(:total) { 50 }
      it('returns no discount') { expect(discount).to eq(0) }
    end

    context 'with order over $100' do
      let(:total) { 150 }
      it('returns 5% discount') { expect(discount).to eq(7.50) }

      # Уровень 3: Купон (отклонение от дефолта)
      context 'and has coupon' do
        let(:coupon) { build(:coupon, value: 10) }
        it('adds coupon to percentage discount') { expect(discount).to eq(17.50) }
      end
    end
  end

  context 'when customer is premium' do
    let(:customer_type) { :premium }

    context 'with any order amount' do
      let(:total) { 50 }
      it('returns 10% discount') { expect(discount).to eq(5.00) }

      context 'and has coupon' do
        let(:coupon) { build(:coupon, value: 10) }
        it('adds coupon to percentage discount') { expect(discount).to eq(15.00) }
      end
    end
  end
end
```

### Пример 2: Request spec с объединением по домену

```ruby
# Шаг 1: Уровень = Request/Integration
# Шаг 2: Объединяем характеристики payment домена

describe 'POST /api/payments' do
  subject(:request) { post '/api/payments', params: params, headers: headers }

  let(:params) { { amount: 100, currency: 'USD' } }
  let(:headers) { {} }

  # Уровень 1: Аутентификация
  context 'when user is authenticated' do
    let(:user) { create(:user) }
    let(:headers) { { 'Authorization' => "Bearer #{user.token}" } }

    # Уровень 2: Payment prerequisites (объединение!)
    context 'with valid payment setup' do
      # Объединяем: verified card + sufficient balance + passed fraud check
      let(:user) { create(:user, :authenticated, :payment_ready) }

      it 'processes payment successfully' do
        request
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include(
          'status' => 'success',
          'transaction_id' => kind_of(String)
        )
      end
    end

    context 'when payment is blocked' do
      let(:user) { create(:user, :authenticated, :payment_blocked) }

      it 'returns payment error' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to include('payment blocked')
      end
    end
  end

  context 'when user is NOT authenticated' do
    it 'returns unauthorized' do
      request
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

---

## Частые ошибки и как их избежать

| Ошибка | Симптом | Решение |
|--------|---------|---------|
| Тестирование реализации | Много `receive`, `allow` | Тестируйте публичное API ([Правило 1](../guide.ru.md#1-тестируйте-поведение-а-не-реализацию)) |
| Глубокая вложенность | 5+ уровней context | Рефакторинг кода ([Do One Thing](../guide.ru.md#принципы-проектирования)) |
| Неявные зависимости | Тесты падают при изменении порядка | Изолируйте контексты ([Правило 5](../guide.ru.md#5-стройте-иерархию-context-по-зависимостям-характеристик-happy-path--corner-cases)) |
| Дублирование | Копипаста в setup/expects | Shared examples ([Правило 25](../guide.ru.md#25-используйте-shared-examples-для-декларации-контрактов)), фабрики ([Правило 12](../guide.ru.md#12-используйте-возможности-factorybot-для-скрытия-деталей-исходных-данных)) |
| Нечитаемый вывод | Стена текста при падении | Правильные матчеры ([Правило 28](../guide.ru.md#28-делайте-вывод-падения-теста-читаемым)) |

**См. также:** [Быстрая диагностика: "Почему мой тест плохо пахнет?"](../guide.ru.md#быстрая-диагностика-почему-мой-тест-плохо-пахнет)

---

## Заключение

Этот алгоритм — не догма, а руководство к размышлению. По мере накопления опыта некоторые шаги станут автоматическими, но базовые принципы останутся:

1. **Тестируйте поведение, а не реализацию**
2. **Стройте тесты по характеристикам домена**
3. **Happy path first, corner cases after**
4. **Тесты — это документация бизнес-правил**
5. **Сложность тестов = сигнал о проблемах кода**

Помните: хорошие тесты делают код лучше, выявляя проблемы дизайна и документируя намерения.

---

**Полное руководство:** [RSpec Style Guide (../guide.ru.md)](../guide.ru.md)  
**Чек-лист для ревью:** [checklist.ru.md](../checklist.ru.md)  
**Паттерны тестирования:** [patterns.ru.md](../patterns.ru.md)
