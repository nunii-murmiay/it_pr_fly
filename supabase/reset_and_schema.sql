-- Зоомагазин «Лапки и Хвостики» — полный сброс и схема для Supabase.
-- SQL Editor → New query → вставить всё → Run.

create extension if not exists "pgcrypto";

-- ========== DROP ==========
drop view if exists public.inventory_valuation cascade;
drop function if exists public.create_sale(uuid, jsonb, int) cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.current_role() cascade;
drop function if exists public.is_staff() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.set_loyalty_level(int) cascade;

drop table if exists public.sale_items cascade;
drop table if exists public.sales cascade;
drop table if exists public.loyalty_cards cascade;
drop table if exists public.product_brands cascade;
drop table if exists public.product_categories cascade;
drop table if exists public.brand_suppliers cascade;
drop table if exists public.products cascade;
drop table if exists public.brands cascade;
drop table if exists public.categories cascade;
drop table if exists public.suppliers cascade;
drop table if exists public.customers cascade;
drop table if exists public.profiles cascade;

-- ========== HELPERS ==========
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()),
    'reader'
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() in ('librarian', 'admin');
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() = 'admin';
$$;

create or replace function public.set_loyalty_level(p int)
returns text
language sql
immutable
as $$
  select case
    when p >= 5000 then 'Платина'
    when p >= 2000 then 'Золото'
    when p >= 500 then 'Серебро'
    else 'Стандарт'
  end;
$$;

-- ========== PROFILES ==========
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  full_name text not null default '',
  email text not null default '',
  role text not null default 'reader'
    check (role in ('reader', 'librarian', 'admin')),
  customer_id uuid null,
  created_at timestamptz not null default now()
);

-- ========== CORE TABLES ==========
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text not null,
  contact_person text not null,
  phone text not null,
  email text not null,
  rating numeric(3,1) not null default 5 check (rating >= 1 and rating <= 5),
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  icon_name text not null default '',
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text not null,
  description text not null default '',
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create table public.brand_suppliers (
  brand_id uuid not null references public.brands (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id) on delete cascade,
  primary key (brand_id, supplier_id)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null,
  phone text not null,
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add constraint profiles_customer_id_fkey
  foreign key (customer_id) references public.customers (id) on delete set null;

create table public.loyalty_cards (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  issued_at timestamptz not null default now(),
  points int not null default 0 check (points >= 0),
  level text not null default 'Стандарт',
  customer_id uuid not null unique references public.customers (id) on delete cascade,
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sku text not null,
  supplier_id uuid not null references public.suppliers (id),
  price numeric(12,2) not null check (price >= 0),
  stock int not null default 0 check (stock >= 0),
  rating numeric(3,1) not null default 5 check (rating >= 1 and rating <= 5),
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create unique index products_sku_active_uidx
  on public.products (sku)
  where deleted = false;

create table public.product_brands (
  product_id uuid not null references public.products (id) on delete cascade,
  brand_id uuid not null references public.brands (id) on delete cascade,
  primary key (product_id, brand_id)
);

create table public.product_categories (
  product_id uuid not null references public.products (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  primary key (product_id, category_id)
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id),
  total numeric(12,2) not null default 0,
  points_earned int not null default 0,
  points_redeemed int not null default 0,
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  product_id uuid not null references public.products (id),
  quantity int not null check (quantity >= 1),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  deleted boolean not null default false,
  deleted_at timestamptz null,
  created_at timestamptz not null default now()
);

-- Отчёт для админа (остатки в ₽)
create or replace view public.inventory_valuation as
select
  p.id as product_id,
  p.name,
  p.sku,
  p.stock,
  p.price,
  (p.stock * p.price) as stock_value,
  s.name as supplier_name
from public.products p
join public.suppliers s on s.id = p.supplier_id
where p.deleted = false;

-- ========== AUTH TRIGGER ==========
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text;
begin
  uname := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1),
    'user'
  );
  insert into public.profiles (id, username, full_name, email, role)
  values (
    new.id,
    uname,
    coalesce(new.raw_user_meta_data->>'full_name', uname),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'role', 'reader')
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(nullif(excluded.full_name, ''), profiles.full_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========== CREATE SALE RPC ==========
-- p_items: [{"product_id":"...","quantity":1}, ...]
create or replace function public.create_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_points_to_redeem int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := public.current_role();
  v_customer public.customers%rowtype;
  v_card public.loyalty_cards%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_subtotal numeric(12,2) := 0;
  v_redeem int := greatest(coalesce(p_points_to_redeem, 0), 0);
  v_payable numeric(12,2);
  v_earned int;
  v_sale_id uuid;
  v_lines jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'Требуется вход.' using errcode = '42501';
  end if;
  -- Касса только у менеджера
  if v_role <> 'librarian' then
    raise exception 'Оформлять продажи может только менеджер.' using errcode = '42501';
  end if;
  if p_customer_id is null or p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Укажите клиента и хотя бы одну позицию.';
  end if;

  select * into v_customer from public.customers
  where id = p_customer_id and deleted = false;
  if not found then
    raise exception 'Клиент не найден.';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty < 1 or (v_item->>'product_id') is null then
      raise exception 'Некорректная позиция продажи.';
    end if;
    select * into v_product from public.products
    where id = (v_item->>'product_id')::uuid and deleted = false
    for update;
    if not found then
      raise exception 'Товар не найден.';
    end if;
    if v_qty > v_product.stock then
      raise exception using
        errcode = 'P0001',
        message = format('Недостаточно «%s»: на складе %s', v_product.name, v_product.stock),
        detail = v_product.id::text;
    end if;
    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_product.id,
      'quantity', v_qty,
      'unit_price', v_product.price,
      'name', v_product.name
    ));
  end loop;

  select * into v_card from public.loyalty_cards
  where customer_id = p_customer_id and deleted = false
  for update;

  if v_redeem > coalesce(v_card.points, 0) then
    raise exception 'Недостаточно баллов на карте' using errcode = '22023';
  end if;
  if v_redeem > floor(v_subtotal) then
    raise exception 'Скидка не может быть больше суммы чека' using errcode = '22023';
  end if;

  v_payable := v_subtotal - v_redeem;
  v_earned := floor(v_payable / 100);

  insert into public.sales (customer_id, total, points_earned, points_redeemed)
  values (p_customer_id, v_payable, v_earned, v_redeem)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(v_lines)
  loop
    insert into public.sale_items (sale_id, product_id, quantity, unit_price)
    values (
      v_sale_id,
      (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::int,
      (v_item->>'unit_price')::numeric
    );
    update public.products
    set stock = stock - (v_item->>'quantity')::int
    where id = (v_item->>'product_id')::uuid;
  end loop;

  if v_card.id is not null then
    update public.loyalty_cards
    set
      points = points - v_redeem + v_earned,
      level = public.set_loyalty_level(points - v_redeem + v_earned)
    where id = v_card.id;
  end if;

  return jsonb_build_object(
    'id', v_sale_id,
    'customerId', p_customer_id,
    'total', v_payable,
    'subtotal', v_subtotal,
    'pointsEarned', v_earned,
    'pointsRedeemed', v_redeem,
    'customer', jsonb_build_object(
      'id', v_customer.id,
      'fullName', v_customer.full_name
    )
  );
end;
$$;

grant execute on function public.create_sale(uuid, jsonb, int) to authenticated;

-- ========== RLS ==========
alter table public.profiles enable row level security;
alter table public.suppliers enable row level security;
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.brand_suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.loyalty_cards enable row level security;
alter table public.products enable row level security;
alter table public.product_brands enable row level security;
alter table public.product_categories enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin() or public.is_staff());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin());

-- catalog read for any authenticated; write for staff
create policy suppliers_select on public.suppliers for select to authenticated using (true);
create policy suppliers_write on public.suppliers for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy categories_select on public.categories for select to authenticated using (true);
create policy categories_write on public.categories for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy brands_select on public.brands for select to authenticated using (true);
create policy brands_write on public.brands for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy brand_suppliers_select on public.brand_suppliers for select to authenticated using (true);
create policy brand_suppliers_write on public.brand_suppliers for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy products_select on public.products for select to authenticated using (true);
create policy products_write on public.products for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy product_brands_select on public.product_brands for select to authenticated using (true);
create policy product_brands_write on public.product_brands for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy product_categories_select on public.product_categories for select to authenticated using (true);
create policy product_categories_write on public.product_categories for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy customers_select on public.customers for select to authenticated
  using (
    public.is_staff()
    or id = (select customer_id from public.profiles where id = auth.uid())
  );
create policy customers_write on public.customers for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy loyalty_select on public.loyalty_cards for select to authenticated
  using (
    public.is_staff()
    or customer_id = (select customer_id from public.profiles where id = auth.uid())
  );
create policy loyalty_write on public.loyalty_cards for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy sales_select on public.sales for select to authenticated
  using (
    public.is_staff()
    or customer_id = (select customer_id from public.profiles where id = auth.uid())
  );
create policy sales_insert on public.sales for insert to authenticated
  with check (public.current_role() = 'librarian');

create policy sale_items_select on public.sale_items for select to authenticated
  using (
    public.is_staff()
    or exists (
      select 1 from public.sales s
      where s.id = sale_id
        and s.customer_id = (select customer_id from public.profiles where id = auth.uid())
    )
  );
create policy sale_items_insert on public.sale_items for insert to authenticated
  with check (public.current_role() = 'librarian');

-- ========== SEED ==========
-- Фиксированные UUID для демо
insert into public.suppliers (id, name, country, contact_person, phone, email, rating) values
  ('11111111-1111-1111-1111-111111111101', 'Royal Canin RU', 'Россия', 'Ирина Соколова', '+7 (495) 111-11-11', 'ru@royalcanin.demo', 4.8),
  ('11111111-1111-1111-1111-111111111102', 'Ferplast IT', 'Италия', 'Marco Rossi', '+39 0422 000000', 'sales@ferplast.demo', 4.5),
  ('11111111-1111-1111-1111-111111111103', 'Triol Wholesale', 'Россия', 'Пётр Волков', '+7 (812) 222-22-22', 'opt@triol.demo', 4.2);

insert into public.categories (id, name, description, icon_name) values
  ('22222222-2222-2222-2222-222222222201', 'Корма', 'Сухие и влажные корма', 'restaurant'),
  ('22222222-2222-2222-2222-222222222202', 'Игрушки', 'Игрушки для питомцев', 'toys'),
  ('22222222-2222-2222-2222-222222222203', 'Аксессуары', 'Ошейники, миски, лежанки', 'pets');

insert into public.brands (id, name, country, description) values
  ('33333333-3333-3333-3333-333333333301', 'Royal Canin', 'Франция', 'Ветеринарные диеты'),
  ('33333333-3333-3333-3333-333333333302', 'Ferplast', 'Италия', 'Клетки и аксессуары'),
  ('33333333-3333-3333-3333-333333333303', 'Triol', 'Россия', 'Игрушки и амуниция');

insert into public.brand_suppliers (brand_id, supplier_id) values
  ('33333333-3333-3333-3333-333333333301', '11111111-1111-1111-1111-111111111101'),
  ('33333333-3333-3333-3333-333333333302', '11111111-1111-1111-1111-111111111102'),
  ('33333333-3333-3333-3333-333333333303', '11111111-1111-1111-1111-111111111103');

insert into public.products (id, name, sku, supplier_id, price, stock, rating) values
  ('44444444-4444-4444-4444-444444444401', 'RC Adult Dog 3 кг', 'RC-DOG-3', '11111111-1111-1111-1111-111111111101', 2890, 25, 4.9),
  ('44444444-4444-4444-4444-444444444402', 'Мяч пищащий', 'TR-BALL-01', '11111111-1111-1111-1111-111111111103', 350, 80, 4.3),
  ('44444444-4444-4444-4444-444444444403', 'Клетка для грызунов', 'FP-CAGE-M', '11111111-1111-1111-1111-111111111102', 4590, 8, 4.6),
  ('44444444-4444-4444-4444-444444444404', 'RC Kitten 2 кг', 'RC-CAT-2', '11111111-1111-1111-1111-111111111101', 2190, 40, 4.8),
  ('44444444-4444-4444-4444-444444444405', 'Ошейник кожаный', 'TR-COL-L', '11111111-1111-1111-1111-111111111103', 890, 30, 4.1);

insert into public.product_brands (product_id, brand_id) values
  ('44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333301'),
  ('44444444-4444-4444-4444-444444444402', '33333333-3333-3333-3333-333333333303'),
  ('44444444-4444-4444-4444-444444444403', '33333333-3333-3333-3333-333333333302'),
  ('44444444-4444-4444-4444-444444444404', '33333333-3333-3333-3333-333333333301'),
  ('44444444-4444-4444-4444-444444444405', '33333333-3333-3333-3333-333333333303');

insert into public.product_categories (product_id, category_id) values
  ('44444444-4444-4444-4444-444444444401', '22222222-2222-2222-2222-222222222201'),
  ('44444444-4444-4444-4444-444444444402', '22222222-2222-2222-2222-222222222202'),
  ('44444444-4444-4444-4444-444444444403', '22222222-2222-2222-2222-222222222203'),
  ('44444444-4444-4444-4444-444444444404', '22222222-2222-2222-2222-222222222201'),
  ('44444444-4444-4444-4444-444444444405', '22222222-2222-2222-2222-222222222203');

insert into public.customers (id, full_name, email, phone) values
  ('55555555-5555-5555-5555-555555555501', 'Анна Читатель', 'reader@zoomag.local', '+7 (900) 111-22-33'),
  ('55555555-5555-5555-5555-555555555502', 'Борис Покупатель', 'boris@zoomag.local', '+7 (900) 222-33-44'),
  ('55555555-5555-5555-5555-555555555503', 'Вера Клиент', 'vera@zoomag.local', '+7 (900) 333-44-55');

insert into public.loyalty_cards (number, issued_at, points, level, customer_id) values
  ('LC-READER', now() - interval '120 days', 1250, 'Серебро', '55555555-5555-5555-5555-555555555501'),
  ('LC-BORIS', now() - interval '60 days', 320, 'Стандарт', '55555555-5555-5555-5555-555555555502'),
  ('LC-VERA', now() - interval '30 days', 2100, 'Золото', '55555555-5555-5555-5555-555555555503');

-- После создания пользователей в Auth выполните:
-- update public.profiles set role = 'reader', username = 'reader', full_name = 'Анна Читатель',
--   customer_id = '55555555-5555-5555-5555-555555555501'
--   where id = (select id from auth.users where email = 'reader@zoomag.local');
-- update public.profiles set role = 'librarian', username = 'librarian', full_name = 'Мария Менеджер'
--   where id = (select id from auth.users where email = 'librarian@zoomag.local');
-- update public.profiles set role = 'admin', username = 'admin', full_name = 'Админ ЗооМаг'
--   where id = (select id from auth.users where email = 'admin@zoomag.local');
