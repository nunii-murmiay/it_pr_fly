# Зоомагазин «Лапки и Хвостики» — GitHub Pages + Supabase

Клиент на Flutter Web. База и вход — **Supabase** (облако).  
Ноутбук для работы сайта **не нужен**.

---

## Часть 1. Репозиторий на GitHub

1. На GitHub создай **новый пустой** репозиторий (например `zoomag-shop`).
2. Локально в этой папке:

```powershell
cd "C:\Users\sirot\OneDrive\Desktop\учёба\itogovaia_pr-main_set"
git add .
git commit -m "Зоомагазин на Supabase + GitHub Pages"
git remote add origin https://github.com/ТВОЙ_ЛОГИН/ИМЯ_РЕПО.git
git push -u origin main
```

3. Settings → Pages → Build and deployment → Source: **GitHub Actions**.

Сайт после зелёного Actions:  
`https://ТВОЙ_ЛОГИН.github.io/ИМЯ_РЕПО/`

---

## Часть 2. Проект Supabase

1. https://supabase.com → Sign in (через GitHub).
2. **New project** → имя, пароль БД (сохрани), регион → Create.
3. Дождись статуса **Ready**.

---

## Часть 3. SQL-схема

1. Supabase → **SQL Editor** → New query.
2. Открой файл [`supabase/reset_and_schema.sql`](supabase/reset_and_schema.sql).
3. Скопируй **весь** текст → вставь → **Run**.

Появятся таблицы: `profiles`, `suppliers`, `categories`, `brands`, `products`,  
`customers`, `loyalty_cards`, `sales`, `sale_items`, связи M2M,  
функция `create_sale`, представление `inventory_valuation`, демо-данные.

---

## Часть 4. Авторизация

### 4.1. Email
Authentication → Providers → **Email** — включи.  
Для учёбы отключи **Confirm email**.

### 4.2. Site URL
Authentication → URL Configuration:

- Site URL: `https://ТВОЙ_ЛОГИН.github.io/ИМЯ_РЕПО/`
- Redirect URLs: та же ссылка и `http://localhost:5555/**`

### 4.3. Пользователи
Authentication → Users → Add user (**Auto confirm**):

| Email | Password |
|---|---|
| reader@zoomag.local | reader123 |
| librarian@zoomag.local | librarian123 |
| admin@zoomag.local | admin123 |

### 4.4. Роли
SQL Editor → выполни файл [`supabase/assign_roles.sql`](supabase/assign_roles.sql).

На сайте вход коротким логином: `librarian` / `librarian123`  
(к логину добавится `@zoomag.local`).

---

## Часть 5. Ключи API

Project Settings → **API**:

| Что | Куда |
|---|---|
| Project URL | `SUPABASE_URL` |
| anon / publishable key | `SUPABASE_ANON_KEY` |

**Не** клади `service_role` / secret в Flutter.

---

## Часть 6. Подключить ключи и опубликовать

### Вариант A — вписать в код (быстрее)
Открой [`lib/core/config.dart`](lib/core/config.dart) и замени дефолты:

```dart
defaultValue: 'https://xxxxx.supabase.co',
defaultValue: 'eyJhbGciOi...',
```

Затем:

```powershell
git add .
git commit -m "Ключи Supabase"
git push origin main
```

### Вариант B — GitHub Secrets (аккуратнее)
Settings → Secrets and variables → Actions:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Workflow уже передаёт их в `--dart-define`.

Дождись зелёного **Сборка и публикация зоомагазина**.

---

## Часть 7. Проверка

1. Открой сайт → Ctrl+F5.
2. Войди `admin` / `admin123` — статистика, пользователи, «Остатки ₽».
3. Войди `librarian` / `librarian123` — раздел **Касса** (у админа его нет).
4. Войди `reader` / `reader123` — **Мои покупки** и чек.
5. Ноутбук можно выключить — сайт и БД в облаке.

---

## Локальный запуск

```powershell
cd "C:\Users\sirot\OneDrive\Desktop\учёба\itogovaia_pr-main_set"
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run -d edge --web-hostname=127.0.0.1 --web-port=5555 ^
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=ваш_anon_key
```

---

## Роли (п.10)

| Роль | Уникальный раздел |
|---|---|
| Покупатель (`reader`) | Мои покупки / чек |
| Менеджер (`librarian`) | Касса |
| Админ (`admin`) | Пользователи, Статистика |
