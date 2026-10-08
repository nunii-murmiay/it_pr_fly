#!/usr/bin/env node
/**
 * Мок-сервер учебного API «Зоомагазин».
 *
 * Зависимостей нет — нужен только Node.js 18 или новее.
 *
 *   node mock-server.js
 *   node mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Данные хранятся в памяти и сбрасываются при перезапуске
 * либо запросом POST /api/__reset
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах (проверка индикатора загрузки)
 *   ?__fail=500     принудительный код ошибки (проверка обработки ошибок)
 */

'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', 'http://localhost:5555');
const SECRET = 'учебный-ключ-не-для-продакшена';
const ACCESS_TTL = Number(arg('ttl', 900));      // секунд
const REFRESH_TTL = 60 * 60 * 24 * 7;

// ─────────────────────────────── токены ───────────────────────────────

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payload) {
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac !== expected) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

// ─────────────────────────────── данные ───────────────────────────────

let db;

function seed() {
  db = {
    seq: {},
    suppliers: [],
    brands: [],
    categories: [],
    products: [],
    customers: [],
    cards: [],
    sales: [],
    users: [],
    refreshTokens: new Set(),
  };

  const S = (name, country, contactPerson, phone, email, rating) =>
    push('suppliers', { name, country, contactPerson, phone, email, rating });

  const B = (name, country, description, supplierIds) =>
    push('brands', { name, country, description, supplierIds });

  const C = (name, description, iconName) =>
    push('categories', { name, description, iconName });

  const zooOpt = S('ООО «ЗооОпт»', 'Россия', 'Иванова М. С.', '+7 495 100-20-01', 'sales@zooopt.ru', 4.6);
  const mars = S('Mars Petcare Russia', 'Россия', 'Петров К. А.', '+7 495 200-30-02', 'info@mars-pet.ru', 4.8);
  const purina = S('Nestlé Purina', 'Швейцария', 'Schmidt H.', '+41 21 924-11-11', 'contact@purina.com', 4.7);
  const royal = S('Royal Canin', 'Франция', 'Dupont L.', '+33 1 44-08-50-00', 'info@royalcanin.com', 4.9);

  const brandRoyal = B(
    'Royal Canin',
    'Франция',
    'Специализированные рационы для собак и кошек',
    [royal, zooOpt]
  );
  const brandProPlan = B('Purina Pro Plan', 'США', 'Профессиональные корма премиум-класса', [purina, zooOpt]);
  const brandWhiskas = B('Whiskas', 'Великобритания', 'Корма и лакомства для кошек', [mars, zooOpt]);
  const brandFelix = B('Felix', 'Германия', 'Влажные корма для кошек', [purina, zooOpt]);
  const brandPedigree = B('Pedigree', 'США', 'Корма для собак', [mars, zooOpt]);
  const brandSheba = B('Sheba', 'США', 'Премиальные влажные корма для кошек', [mars, zooOpt]);
  const brandHills = B("Hill's", 'США', 'Диетические и лечебные корма', [zooOpt]);
  const brandAcana = B('Acana', 'Канада', 'Беззерновые корма с высоким содержанием мяса', [zooOpt]);

  const catDogFood = C('Корма для собак', 'Сухие и влажные рационы для собак', 'pets');
  const catCatFood = C('Корма для кошек', 'Сухие и влажные рационы для кошек', 'cat');
  const catTreats = C('Лакомства', 'Угощения для дрессировки и поощрения', 'cookie');
  const catLitter = C('Наполнители', 'Наполнители для туалетов кошек', 'grain');
  const catToys = C('Игрушки', 'Игрушки для собак и кошек', 'toys');
  const catAccessories = C('Аксессуары', 'Миски, поводки, переноски', 'shopping_bag');
  const catVitamins = C('Витамины и добавки', 'Витаминные комплексы и БАДы', 'medication');

  const P = (name, sku, supplierId, brandIds, categoryIds, price, stock, rating) =>
    push('products', {
      name,
      sku,
      supplierId,
      brandIds,
      categoryIds,
      price,
      stock,
      rating,
    });

  P('Royal Canin Medium Adult', 'RC-MED-15KG', royal, [brandRoyal], [catDogFood], 5490, 12, 4.9);
  P('Royal Canin Kitten', 'RC-KIT-2KG', royal, [brandRoyal], [catCatFood], 1890, 18, 4.8);
  P('Royal Canin Sterilised 37', 'RC-STR-4KG', royal, [brandRoyal], [catCatFood], 3290, 8, 4.7);
  P('Purina Pro Plan Adult Large', 'PP-LRG-14KG', purina, [brandProPlan], [catDogFood], 4890, 6, 4.6);
  P('Purina Pro Plan Kitten', 'PP-KIT-3KG', purina, [brandProPlan], [catCatFood], 2490, 10, 4.7);
  P('Whiskas с курицей 1,9 кг', 'WH-CH-1900', mars, [brandWhiskas], [catCatFood], 890, 25, 4.4);
  P('Whiskas лакомства Dentabites', 'WH-DEN-40', mars, [brandWhiskas], [catTreats], 320, 30, 4.5);
  P('Felix Аппетитные кусочки 24×85 г', 'FX-MIX-24', purina, [brandFelix], [catCatFood], 1290, 14, 4.3);
  P('Pedigree с говядиной 13 кг', 'PD-BEF-13KG', mars, [brandPedigree], [catDogFood], 3590, 9, 4.2);
  P('Pedigree DentaStix', 'PD-DEN-7', mars, [brandPedigree], [catTreats], 450, 22, 4.4);
  P('Sheba Fine Flakes лосось', 'SH-SAL-4', mars, [brandSheba], [catCatFood], 180, 40, 4.6);
  P("Hill's Science Plan Adult 7+ кошка", 'HL-SP-7-2KG', zooOpt, [brandHills], [catCatFood], 4190, 5, 4.8);
  P('Acana Grass-Fed Lamb 6 кг', 'AC-LAM-6KG', zooOpt, [brandAcana], [catDogFood], 6790, 4, 4.9);
  P('Наполнитель Cats Best Universal 10 л', 'CB-UNI-10L', zooOpt, [], [catLitter], 990, 16, 4.5);
  P('Игрушка Kong Classic M', 'KONG-CL-M', zooOpt, [], [catToys], 1290, 11, 4.7);
  P('Поводок Flexi New Classic M', 'FLX-NC-M', zooOpt, [], [catAccessories], 2190, 7, 4.6);
  P('8in1 Excel Multi-Vitamin', '81-MV-100', zooOpt, [], [catVitamins], 690, 13, 4.3);
  P('Royal Canin Giant Junior (демо: нет на складе)', 'RC-GJ-15KG-DEMO', royal, [brandRoyal], [catDogFood], 5990, 0, 4.8);

  const customerNames = [
    ['Смирнов П. А.', 'smirnov@example.com', '+7 900 100-10-01'],
    ['Кузнецова М. И.', 'kuznetsova@example.com', '+7 900 100-10-02'],
    ['Попов Д. С.', 'popov@example.com', '+7 900 100-10-03'],
    ['Васильева Е. О.', 'vasileva@example.com', '+7 900 100-10-04'],
    ['Новиков А. В.', 'novikov@example.com', '+7 900 100-10-05'],
    ['Морозова Т. Н.', 'morozova@example.com', '+7 900 100-10-06'],
  ];

  const levels = ['Стандарт', 'Серебро', 'Золото', 'Серебро', 'Стандарт', 'Платина'];
  const pointsList = [1200, 3400, 890, 2100, 450, 5600];

  customerNames.forEach(([fullName, email, phone], i) => {
    const customerId = push('customers', { fullName, email, phone });
    push('cards', {
      customerId,
      number: 'ZC-' + String(customerId).padStart(6, '0'),
      issuedAt: iso(2025, 6, 1 + i),
      points: pointsList[i],
      level: levels[i],
    });
    push('users', {
      username: i === 0 ? 'reader' : email.split('@')[0],
      passwordHash: hash('reader123'),
      fullName,
      email,
      role: 'reader',
      customerId,
    });
  });

  const adminId = push('customers', {
    fullName: 'Администратор',
    email: 'admin@petshop.local',
    phone: '+7 900 100-10-07',
  });
  push('cards', {
    customerId: adminId,
    number: 'ZC-' + String(adminId).padStart(6, '0'),
    issuedAt: iso(2025, 6, 7),
    points: 0,
    level: 'Стандарт',
  });
  push('users', {
    username: 'admin',
    passwordHash: hash('admin123'),
    fullName: 'Администратор',
    email: 'admin@petshop.local',
    role: 'admin',
    customerId: adminId,
  });

  const managerId = push('customers', {
    fullName: 'Петрова А. С.',
    email: 'petrova@petshop.local',
    phone: '+7 900 100-10-08',
  });
  push('cards', {
    customerId: managerId,
    number: 'ZC-' + String(managerId).padStart(6, '0'),
    issuedAt: iso(2025, 6, 8),
    points: 0,
    level: 'Стандарт',
  });
  push('users', {
    username: 'librarian',
    passwordHash: hash('librarian123'),
    fullName: 'Петрова А. С.',
    email: 'petrova@petshop.local',
    role: 'librarian',
    customerId: managerId,
  });

  makeSale(1, 6, 2, -10);
  makeSale(2, 11, 1, -3);
  makeSale(3, 3, 1, -20);
}

function push(collection, obj) {
  db.seq[collection] = (db.seq[collection] || 0) + 1;
  const id = db.seq[collection];
  db[collection].push({ id, ...obj, createdAt: new Date().toISOString(), deletedAt: null });
  return id;
}

function iso(y, m, d) {
  return new Date(Date.UTC(y, m - 1, d)).toISOString();
}

function hash(password) {
  return crypto.createHash('sha256').update(password + SECRET).digest('hex');
}

function makeSale(customerId, productId, quantity, soldDaysAgo) {
  const product = db.products.find((p) => p.id === productId);
  if (!product) return null;
  const soldAt = new Date(Date.now() + soldDaysAgo * 86400000);
  const unitPrice = product.price;
  const id = push('sales', {
    customerId,
    productId,
    quantity,
    unitPrice,
    totalPrice: unitPrice * quantity,
    soldAt: soldAt.toISOString(),
  });
  product.stock = Math.max(0, product.stock - quantity);
  return id;
}

// ──────────────────────── развёртывание объектов ────────────────────────

function slimSupplier(id) {
  const s = db.suppliers.find((x) => x.id === id);
  return s ? { id: s.id, name: s.name } : null;
}

function expandProduct(p) {
  return {
    id: p.id,
    name: p.name,
    sku: p.sku,
    supplier: slimSupplier(p.supplierId),
    brands: p.brandIds
      .map((id) => db.brands.find((b) => b.id === id))
      .filter(Boolean)
      .map((b) => ({ id: b.id, name: b.name })),
    categories: p.categoryIds
      .map((id) => db.categories.find((c) => c.id === id))
      .filter(Boolean)
      .map((c) => ({ id: c.id, name: c.name })),
    price: p.price,
    stock: p.stock,
    rating: p.rating,
    createdAt: p.createdAt,
    deletedAt: p.deletedAt,
  };
}

function expandCustomer(c) {
  const card = db.cards.find((x) => x.customerId === c.id && !x.deletedAt);
  return {
    id: c.id,
    fullName: c.fullName,
    email: c.email,
    phone: c.phone,
    card: card
      ? { id: card.id, number: card.number, issuedAt: card.issuedAt, points: card.points, level: card.level }
      : null,
    createdAt: c.createdAt,
    deletedAt: c.deletedAt,
  };
}

function expandSale(s) {
  const customer = db.customers.find((c) => c.id === s.customerId);
  const product = db.products.find((p) => p.id === s.productId);
  return {
    id: s.id,
    customerId: s.customerId,
    customer: customer ? { id: customer.id, fullName: customer.fullName } : null,
    product: product ? { id: product.id, name: product.name } : null,
    quantity: s.quantity,
    unitPrice: s.unitPrice,
    totalPrice: s.totalPrice,
    soldAt: s.soldAt,
    deletedAt: s.deletedAt,
  };
}

function expandUser(u) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.fullName,
    email: u.email,
    role: u.role,
    customerId: u.customerId,
  };
}

const EXPANDERS = {
  products: expandProduct,
  customers: expandCustomer,
  sales: expandSale,
  brands: (b) => b,
  categories: (c) => c,
  suppliers: (s) => s,
};

// ─────────────────────────── общие операции ───────────────────────────

function searchableText(collection, item) {
  switch (collection) {
    case 'products':
      return [item.name, item.sku].join(' ');
    case 'brands':
      return [item.name, item.country, item.description].join(' ');
    case 'categories':
      return [item.name, item.description, item.iconName].join(' ');
    case 'suppliers':
      return [item.name, item.country, item.contactPerson, item.email, item.phone].join(' ');
    case 'customers':
      return [item.fullName, item.email, item.phone].join(' ');
    default:
      return '';
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;

  if (q.search) {
    const needle = String(q.search).toLowerCase();
    result = result.filter((x) => searchableText(collection, x).toLowerCase().includes(needle));
  }

  if (collection === 'products') {
    if (q.categoryId) result = result.filter((p) => p.categoryIds.includes(Number(q.categoryId)));
    if (q.brandId) result = result.filter((p) => p.brandIds.includes(Number(q.brandId)));
    if (q.supplierId) result = result.filter((p) => p.supplierId === Number(q.supplierId));
    if (q.priceFrom) result = result.filter((p) => p.price >= Number(q.priceFrom));
    if (q.priceTo) result = result.filter((p) => p.price <= Number(q.priceTo));
  }

  if (collection === 'sales') {
    if (q.customerId) result = result.filter((s) => s.customerId === Number(q.customerId));
    if (q.productId) result = result.filter((s) => s.productId === Number(q.productId));
  }

  return result;
}

function applySort(rows, sort) {
  if (!sort) return rows;
  const [field, dirRaw] = String(sort).split(',');
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const av = a[field];
    const bv = b[field];
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir;
    return String(av).localeCompare(String(bv), 'ru') * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages,
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

function validate(collection, body, id = null) {
  const e = {};
  const str = (v) => (typeof v === 'string' ? v.trim() : '');

  if (collection === 'products') {
    if (!str(body.name)) e.name = 'Укажите название товара';
    else if (str(body.name).length > 200) e.name = 'Не длиннее 200 символов';

    if (!str(body.sku)) e.sku = 'Укажите артикул (SKU)';
    else {
      const dup = db.products.find((p) => p.sku === str(body.sku) && p.id !== id && !p.deletedAt);
      if (dup) e.sku = 'Товар с таким артикулом уже существует';
    }

    const price = Number(body.price);
    if (!Number.isFinite(price) || price < 0) e.price = 'Цена — неотрицательное число';

    const stock = Number(body.stock);
    if (!Number.isInteger(stock) || stock < 0) e.stock = 'Остаток — целое число, не меньше нуля';

    if (body.rating != null) {
      const rating = Number(body.rating);
      if (!Number.isFinite(rating) || rating < 0 || rating > 5) e.rating = 'Рейтинг от 0 до 5';
    }

    if (body.supplierId != null && !db.suppliers.find((s) => s.id === Number(body.supplierId) && !s.deletedAt)) {
      e.supplierId = 'Поставщик не найден';
    }
  }

  if (collection === 'brands') {
    if (!str(body.name)) e.name = 'Укажите название бренда';
    if (body.supplierIds != null && !Array.isArray(body.supplierIds)) {
      e.supplierIds = 'Список поставщиков должен быть массивом';
    }
  }

  if (collection === 'categories') {
    if (!str(body.name)) e.name = 'Укажите название категории';
    else {
      const dup = db.categories.find(
        (c) => c.name.toLowerCase() === str(body.name).toLowerCase() && c.id !== id && !c.deletedAt
      );
      if (dup) e.name = 'Такая категория уже существует';
    }
  }

  if (collection === 'suppliers') {
    if (!str(body.name)) e.name = 'Укажите название поставщика';
    if (body.email && !/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(str(body.email))) {
      e.email = 'Некорректный адрес почты';
    }
    if (body.rating != null) {
      const rating = Number(body.rating);
      if (!Number.isFinite(rating) || rating < 0 || rating > 5) e.rating = 'Рейтинг от 0 до 5';
    }
  }

  if (collection === 'customers') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО покупателя';
    if (!str(body.email)) e.email = 'Укажите адрес почты';
    else if (!/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(str(body.email))) e.email = 'Некорректный адрес почты';
    else {
      const dup = db.customers.find((c) => c.email === str(body.email) && c.id !== id && !c.deletedAt);
      if (dup) e.email = 'Покупатель с такой почтой уже зарегистрирован';
    }
  }

  return e;
}

// ──────────────────────────── HTTP-обвязка ────────────────────────────

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null;
  }
}

function currentUser(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.type !== 'access') return null;
  return db.users.find((u) => u.id === payload.sub && !u.deletedAt) || null;
}

const ROLE_LEVEL = { reader: 1, librarian: 2, admin: 3 };

function requireRole(res, user, minRole) {
  if (!user) {
    fail(res, 401, 'Требуется аутентификация');
    return false;
  }
  if (ROLE_LEVEL[user.role] < ROLE_LEVEL[minRole]) {
    fail(res, 403, `Операция доступна начиная с роли «${minRole}»`);
    return false;
  }
  return true;
}

const COLLECTIONS = ['products', 'brands', 'categories', 'suppliers', 'customers', 'sales'];

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();
  const user = currentUser(req);

  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }

  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  }

  if (path === '/api/auth/register' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    if (username.length < 3) errors.username = 'Логин не короче трёх символов';
    else if (db.users.find((u) => u.username === username)) errors.username = 'Такой логин уже занят';
    if (password.length < 8) errors.password = 'Пароль не короче восьми символов';
    else if (!/\d/.test(password)) errors.password = 'Пароль должен содержать цифру';
    if (body.email && !/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(String(body.email))) {
      errors.email = 'Некорректный адрес почты';
    }

    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }

    const fullName = String(body.fullName || username);
    const email = String(body.email || '');
    const customerId = push('customers', { fullName, email, phone: '' });
    ensureLoyaltyCard(customerId, null);
    const id = push('users', {
      username,
      passwordHash: hash(password),
      fullName,
      email,
      role: 'reader',
      customerId,
    });
    return send(res, 201, expandUser(db.users.find((u) => u.id === id)));
  }

  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const found = db.users.find(
      (u) => u.username === String(body.username || '').trim() && !u.deletedAt
    );
    if (!found || found.passwordHash !== hash(String(body.password || ''))) {
      return fail(res, 401, 'Неверный логин или пароль');
    }

    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, {
      accessToken,
      refreshToken,
      expiresIn: ACCESS_TTL,
      user: expandUser(found),
    });
  }

  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const token = body && body.refreshToken;
    const payload = verify(token);
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(token)) {
      return fail(res, 401, 'Токен обновления недействителен');
    }
    const found = db.users.find((u) => u.id === payload.sub);
    if (!found) return fail(res, 401, 'Пользователь не найден');

    db.refreshTokens.delete(token);
    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, { accessToken, refreshToken, expiresIn: ACCESS_TTL, user: expandUser(found) });
  }

  if (path === '/api/auth/me' && method === 'GET') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    return send(res, 200, expandUser(user));
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    const body = await readBody(req);
    if (body && body.refreshToken) db.refreshTokens.delete(body.refreshToken);
    return send(res, 204);
  }

  if (path === '/api/users' && method === 'GET') {
    if (!requireRole(res, user, 'admin')) return;
    const rows = applySort(db.users.filter((u) => !u.deletedAt), q.sort);
    const page = paginate(rows, q);
    return send(res, 200, { ...page, items: page.items.map(expandUser) });
  }

  if (path === '/api/sales' && method === 'POST') {
    if (!requireRole(res, user, 'librarian')) return;
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const customer = db.customers.find((c) => c.id === Number(body.customerId) && !c.deletedAt);
    const product = db.products.find((p) => p.id === Number(body.productId) && !p.deletedAt);
    if (!customer) errors.customerId = 'Покупатель не найден';
    if (!product) errors.productId = 'Товар не найден';
    const quantity = Number(body.quantity);
    if (!Number.isInteger(quantity) || quantity < 1) errors.quantity = 'Количество — целое число не меньше 1';
    if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

    if (product.stock < quantity) {
      return send(res, 409, {
        message: `Недостаточно «${product.name}»: на складе ${product.stock}`,
        productId: product.id,
        stock: product.stock,
      });
    }

    const soldAt = new Date();
    const unitPrice = product.price;
    const id = push('sales', {
      customerId: customer.id,
      productId: product.id,
      quantity,
      unitPrice,
      totalPrice: unitPrice * quantity,
      soldAt: soldAt.toISOString(),
    });
    product.stock -= quantity;
    return send(res, 201, expandSale(db.sales.find((s) => s.id === id)));
  }

  let m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);

  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!requireRole(res, user, 'librarian')) return;

    const body = await readBody(req);
    const ids = Array.isArray(body && body.ids) ? body.ids.map(Number) : [];
    if (!ids.length) {
      return send(res, 422, {
        message: 'Ошибка валидации',
        errors: { ids: 'Передайте непустой список идентификаторов' },
      });
    }

    let deleted = 0;
    for (const row of db[collection]) {
      if (ids.includes(row.id) && !row.deletedAt) {
        row.deletedAt = new Date().toISOString();
        if (collection === 'customers') setCustomerUsersDeleted(row.id, row.deletedAt);
        deleted += 1;
      }
    }
    return send(res, 200, { deleted });
  }

  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    const expand = EXPANDERS[collection];

    if (action === 'restore' && method === 'POST') {
      if (!requireRole(res, user, 'admin')) return;
      const row = db[collection].find((x) => x.id === id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      if (collection === 'customers') setCustomerUsersDeleted(id, null);
      return send(res, 200, expand(row));
    }

    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);

      if (collection === 'sales' && user && user.role === 'reader') {
        rows = rows.filter((s) => Number(s.customerId) === Number(user.customerId));
      }

      rows = applyFilters(collection, rows, q);
      rows = applySort(rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    if (id !== null && method === 'GET') {
      const row = db[collection].find((x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt));
      if (!row) return fail(res, 404, 'Объект не найден');
      if (collection === 'sales' && user && user.role === 'reader' && row.customerId !== user.customerId) {
        return fail(res, 403, 'Нет доступа к этой продаже');
      }
      return send(res, 200, expand(row));
    }

    if (id === null && method === 'POST') {
      if (!requireRole(res, user, 'librarian')) return;
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const errors = validate(collection, body);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      const data = normalize(collection, body);
      const newId = push(collection, data);
      const row = db[collection].find((x) => x.id === newId);
      if (collection === 'customers') {
        ensureLoyaltyCard(row.id, body.card);
        ensureCustomerAccount(row);
      }
      return send(res, 201, expand(row));
    }

    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      if (!requireRole(res, user, 'librarian')) return;
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');

      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      Object.assign(row, normalize(collection, merged));
      if (collection === 'customers') {
        ensureLoyaltyCard(row.id, body.card);
        const linked = db.users.find((u) => u.customerId === row.id);
        if (linked) {
          linked.fullName = row.fullName;
          linked.email = row.email;
          if (!row.deletedAt) linked.deletedAt = null;
        } else {
          ensureCustomerAccount(row);
        }
      }
      return send(res, 200, expand(row));
    }

    if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      if (!requireRole(res, user, hard ? 'admin' : 'librarian')) return;

      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');

      if (hard) {
        if (collection === 'suppliers') {
          const linked = db.products.some((p) => p.supplierId === id && !p.deletedAt);
          if (linked) return fail(res, 409, 'На поставщика ссылаются товары, удаление невозможно');
        }
        if (collection === 'customers') removeCustomerUsers(id);
        db[collection].splice(index, 1);
      } else {
        db[collection][index].deletedAt = new Date().toISOString();
        if (collection === 'customers') {
          setCustomerUsersDeleted(id, db[collection][index].deletedAt);
        }
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  const str = (v) => (v == null ? '' : String(v).trim());
  const ids = (v) => (Array.isArray(v) ? v.map(Number).filter((n) => Number.isInteger(n)) : []);

  switch (collection) {
    case 'products':
      return {
        name: str(body.name),
        sku: str(body.sku),
        supplierId: num(body.supplierId),
        brandIds: ids(body.brandIds),
        categoryIds: ids(body.categoryIds),
        price: num(body.price) ?? 0,
        stock: num(body.stock) ?? 0,
        rating: num(body.rating) ?? 0,
      };
    case 'brands':
      return {
        name: str(body.name),
        country: str(body.country),
        description: str(body.description),
        supplierIds: ids(body.supplierIds),
      };
    case 'categories':
      return {
        name: str(body.name),
        description: str(body.description),
        iconName: str(body.iconName),
      };
    case 'suppliers':
      return {
        name: str(body.name),
        country: str(body.country),
        contactPerson: str(body.contactPerson),
        phone: str(body.phone),
        email: str(body.email),
        rating: num(body.rating) ?? 0,
      };
    case 'customers':
      return { fullName: str(body.fullName), email: str(body.email), phone: str(body.phone) };
    default:
      return { ...body };
  }
}

function ensureLoyaltyCard(customerId, card) {
  const existing = db.cards.find((c) => c.customerId === customerId && !c.deletedAt);
  const next = {
    number: (card && card.number) || ('ZC-' + String(customerId).padStart(6, '0')),
    issuedAt: (card && card.issuedAt) || new Date().toISOString(),
    points: card && card.points != null ? Number(card.points) : 0,
    level: (card && card.level) || 'Стандарт',
  };
  if (existing) {
    Object.assign(existing, next);
    return;
  }
  push('cards', { customerId, ...next });
}

function ensureCustomerAccount(customer) {
  if (db.users.some((u) => u.customerId === customer.id && !u.deletedAt)) return;
  let login = String(customer.email || '').split('@')[0] || `client${customer.id}`;
  login = login.replace(/[^a-zA-Z0-9._-]/g, '') || `client${customer.id}`;
  if (db.users.some((u) => u.username === login && !u.deletedAt)) {
    login = `${login}${customer.id}`;
  }
  push('users', {
    username: login,
    passwordHash: hash('reader123'),
    fullName: customer.fullName,
    email: customer.email,
    role: 'reader',
    customerId: customer.id,
  });
}

function setCustomerUsersDeleted(customerId, deletedAt) {
  for (const user of db.users) {
    if (user.customerId === customerId) user.deletedAt = deletedAt;
  }
}

function removeCustomerUsers(customerId) {
  db.users = db.users.filter((user) => user.customerId !== customerId);
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(
    `${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`
  );
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «Зоомагазин»');
  console.log(`  Адрес:              http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  console.log(`  Срок жизни токена:  ${ACCESS_TTL} с`);
  console.log('');
  console.log('  Учётные записи:  admin/admin123   librarian/librarian123   reader/reader123');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});
