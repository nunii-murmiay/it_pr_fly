-- Выполнить ПОСЛЕ создания пользователей в Authentication → Users.

update public.profiles
set
  role = 'reader',
  username = 'reader',
  full_name = 'Анна Читатель',
  customer_id = '55555555-5555-5555-5555-555555555501'
where id = (select id from auth.users where email = 'reader@zoomag.local');

update public.profiles
set
  role = 'librarian',
  username = 'librarian',
  full_name = 'Мария Менеджер',
  customer_id = null
where id = (select id from auth.users where email = 'librarian@zoomag.local');

update public.profiles
set
  role = 'admin',
  username = 'admin',
  full_name = 'Админ ЗооМаг',
  customer_id = null
where id = (select id from auth.users where email = 'admin@zoomag.local');
