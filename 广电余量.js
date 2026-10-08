/*
 * 中国广电小组件（Egern 版，单文件三模式）· Hark 改版
 * 逆向自中国广电 App（app.10099.com.cn），RSA 加密请求 + MD5 签名
 *
 * 三种用法（脚本 URL 填同一个文件）：
 *   1. generic 类型 → iOS 小组件：显示剩余话费 / 剩余流量 / 剩余语音
 *   2. http_request 类型 → 登录捕获：在「中国广电」App 里用短信验证码登录一次，
 *      自动存下 Cookie
 *   3. http_response 类型 → Cookie 刷新：自动从响应里抓 Set-Cookie
 *
 * 环境变量：
 *   CBN_PHONENUMBER         广电手机号（必填，11 位）
 *   CBN_SHOW_USED_FLOW      'true' 显示已用流量，否则显示剩余流量（默认剩余）
 *   CBN_TITLE               小组件标题，默认 "中国广电"
 *   CBN_DEBUG               'true' 在小组件上显示调试信息
 *
 * 数据来源：
 *   https://app.10099.com.cn/contact-web/api/busi/qryUserInfo
 */

'use strict';

/* ==================== UTF-8 / hex / base64 工具 ==================== */

function utf8Bytes(str) {
  const out = [];
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
      const lo = str.charCodeAt(i + 1);
      if (lo >= 0xdc00 && lo <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (lo - 0xdc00);
        i++;
      }
    }
    if (c < 0x80) out.push(c);
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
  }
  return out;
}

function utf8String(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length;) {
    const b = bytes[i];
    if (b < 0x80) { s += String.fromCharCode(b); i++; }
    else if ((b & 0xe0) === 0xc0) { s += String.fromCharCode(((b & 0x1f) << 6) | (bytes[i + 1] & 0x3f)); i += 2; }
    else if ((b & 0xf0) === 0xe0) { s += String.fromCharCode(((b & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f)); i += 3; }
    else {
      const c = ((b & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f);
      const v = c - 0x10000;
      s += String.fromCharCode(0xd800 + (v >> 10), 0xdc00 + (v & 0x3ff));
      i += 4;
    }
  }
  return s;
}

function bytesToHex(bytes) {
  return bytes.map((b) => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');
}

const B64MAP = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const B64INV = {};
for (let i = 0; i < 64; i++) B64INV[B64MAP[i]] = i;

function base64Decode(s) {
  s = s.replace(/[^A-Za-z0-9+/=]/g, '');
  const bytes = [];
  for (let i = 0; i < s.length; i += 4) {
    const a = B64INV[s[i]] || 0, b = B64INV[s[i + 1]] || 0, c = B64INV[s[i + 2]] || 0, d = B64INV[s[i + 3]] || 0;
    const n = (a << 18) | (b << 12) | (c << 6) | d;
    bytes.push((n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff);
  }
  const pad = (s.match(/=+$/) || [''])[0].length;
  return bytes.slice(0, bytes.length - pad);
}

function base64Encode(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i], b1 = i + 1 < bytes.length ? bytes[i + 1] : 0, b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    const n = (b0 << 16) | (b1 << 8) | b2;
    s += B64MAP[(n >> 18) & 63] + B64MAP[(n >> 12) & 63] + (i + 1 < bytes.length ? B64MAP[(n >> 6) & 63] : '=') + (i + 2 < bytes.length ? B64MAP[n & 63] : '=');
  }
  return s;
}

/* ==================== MD5 ==================== */

function md5Hex(str) {
  const msg = utf8Bytes(str);
  const bitLen = msg.length * 8;
  msg.push(0x80);
  while (msg.length % 64 !== 56) msg.push(0);
  for (let i = 0; i < 8; i++) msg.push((bitLen / Math.pow(2, i * 8)) & 0xff);

  let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
  const S = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
             5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
             4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
             6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];
  const K = [];
  for (let i = 0; i < 64; i++) K.push(Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296) >>> 0);

  const add = (x, y) => (x + y) >>> 0;
  const rol = (x, n) => ((x << n) | (x >>> (32 - n))) >>> 0;

  for (let off = 0; off < msg.length; off += 64) {
    const M = [];
    for (let i = 0; i < 16; i++) {
      M.push((msg[off + i * 4] | (msg[off + i * 4 + 1] << 8) | (msg[off + i * 4 + 2] << 16) | (msg[off + i * 4 + 3] << 24)) >>> 0);
    }
    let A = a0, B = b0, C = c0, D = d0;
    for (let i = 0; i < 64; i++) {
      let F, g;
      if (i < 16) { F = (B & C) | (~B & D); g = i; }
      else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }
      else if (i < 48) { F = B ^ C ^ D; g = (3 * i + 5) % 16; }
      else { F = C ^ (B | ~D); g = (7 * i) % 16; }
      F = add(add(add(F, A), K[i]), M[g]);
      A = D; D = C; C = B;
      B = add(B, rol(F, S[i]));
    }
    a0 = add(a0, A); b0 = add(b0, B); c0 = add(c0, C); d0 = add(d0, D);
  }
  const le = (x) => [x & 0xff, (x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff];
  return bytesToHex([].concat(le(a0), le(b0), le(c0), le(d0)));
}

/* ==================== BigInt（RSA 运算支持） ==================== */
// 用 base-10^9 数组表示大整数，d[0] 为最高位
// 例：1234567890123 → [1, 234567890, 123]

const BI_BASE = 1000000000;

function biNorm(a) {
  while (a.length > 1 && a[0] === 0) a.shift();
  if (a.length === 0) a.push(0);
  return a;
}

function biFromBytes(bytes) {
  if (bytes.length === 0) return [0];
  let r = [0];
  for (let i = 0; i < bytes.length; i++) {
    r = biMulSmall(r, 256);
    r = biAddSmall(r, bytes[i]);
  }
  return biNorm(r);
}

function biToBytes(a, fixedLen) {
  let v = a.slice();
  biNorm(v);
  if (v.length === 1 && v[0] === 0) {
    return fixedLen ? new Array(fixedLen).fill(0) : [0];
  }
  const hex = [];
  while (v.length > 0) {
    const q = [], r = [];
    let rem = 0;
    for (let i = 0; i < v.length; i++) {
      const cur = rem * BI_BASE + v[i];
      q.push(Math.floor(cur / 256));
      rem = cur % 256;
    }
    hex.push(rem);
    biNorm(q);
    v = q;
  }
  hex.reverse();
  if (fixedLen) {
    while (hex.length < fixedLen) hex.unshift(0);
    if (hex.length > fixedLen) hex = hex.slice(hex.length - fixedLen);
  }
  return hex;
}

function biAddSmall(a, b) {
  const r = a.slice();
  let carry = b;
  for (let i = r.length - 1; i >= 0 && carry > 0; i--) {
    const s = r[i] + carry;
    r[i] = s % BI_BASE;
    carry = Math.floor(s / BI_BASE);
  }
  while (carry > 0) { r.unshift(carry % BI_BASE); carry = Math.floor(carry / BI_BASE); }
  return r;
}

function biMulSmall(a, b) {
  const r = new Array(a.length);
  let carry = 0;
  for (let i = a.length - 1; i >= 0; i--) {
    const p = a[i] * b + carry;
    r[i] = p % BI_BASE;
    carry = Math.floor(p / BI_BASE);
  }
  while (carry > 0) { r.unshift(carry % BI_BASE); carry = Math.floor(carry / BI_BASE); }
  return r;
}

function biAdd(a, b) {
  const r = [], la = a.length, lb = b.length;
  let carry = 0, i = 0;
  while (i < la || i < lb || carry > 0) {
    const s = (la - 1 - i >= 0 ? a[la - 1 - i] : 0) + (lb - 1 - i >= 0 ? b[lb - 1 - i] : 0) + carry;
    r.push(s % BI_BASE);
    carry = Math.floor(s / BI_BASE);
    i++;
  }
  r.reverse();
  return biNorm(r);
}

function biCmp(a, b) {
  if (a.length !== b.length) return a.length > b.length ? 1 : -1;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return a[i] > b[i] ? 1 : -1;
  }
  return 0;
}

function biSub(a, b) {
  const r = new Array(a.length);
  let borrow = 0;
  for (let i = a.length - 1; i >= 0; i--) {
    const bi = i - (a.length - b.length);
    const d = a[i] - (bi >= 0 ? b[bi] : 0) - borrow;
    if (d < 0) { r[i] = d + BI_BASE; borrow = 1; }
    else { r[i] = d; borrow = 0; }
  }
  return biNorm(r);
}

function biMul(a, b) {
  const r = new Array(a.length + b.length).fill(0);
  for (let i = a.length - 1; i >= 0; i--) {
    let carry = 0;
    for (let j = b.length - 1; j >= 0; j--) {
      const p = a[i] * b[j] + r[i + j + 1] + carry;
      r[i + j + 1] = p % BI_BASE;
      carry = Math.floor(p / BI_BASE);
    }
    r[i] += carry;
  }
  return biNorm(r);
}

// 二进制长除法求 a mod b
function biMod(a, b) {
  if (biCmp(a, b) < 0) return a.slice();
  const bits = biToBinary(a);
  let rem = [0];
  for (let i = 0; i < bits.length; i++) {
    rem = biMulSmall(rem, 2);
    if (bits[i]) rem = biAddSmall(rem, 1);
    if (biCmp(rem, b) >= 0) rem = biSub(rem, b);
  }
  return biNorm(rem);
}

function biToBinary(a) {
  const hex = [];
  let v = a.slice();
  while (v.length > 0 && !(v.length === 1 && v[0] === 0)) {
    const q = [], r = [];
    let rem = 0;
    for (let i = 0; i < v.length; i++) {
      const cur = rem * BI_BASE + v[i];
      q.push(Math.floor(cur / 16));
      rem = cur % 16;
    }
    hex.push(rem);
    biNorm(q);
    v = q;
  }
  hex.reverse();
  const bits = [];
  for (const h of hex) {
    bits.push((h >> 3) & 1, (h >> 2) & 1, (h >> 1) & 1, h & 1);
  }
  while (bits.length > 1 && bits[0] === 0) bits.shift();
  return bits;
}

// RSA modpow：m^e mod n，e=65537 优化（16 次平方 + 1 次乘法）
function rsaModPow(m, n) {
  let r = m.slice();
  for (let i = 0; i < 16; i++) {
    r = biMod(biMul(r, r), n);
  }
  return biMod(biMul(r, m), n);
}

/* ==================== RSA 加密 ==================== */

function parseDerPublicKey(derBytes) {
  let pos = 0;
  function readTag() { return derBytes[pos++]; }
  function readLen() {
    const b = derBytes[pos++];
    if (b < 0x80) return b;
    const nb = b & 0x7f;
    let len = 0;
    for (let i = 0; i < nb; i++) len = len * 256 + derBytes[pos++];
    return len;
  }
  function skipTLV() { readTag(); const l = readLen(); pos += l; }

  readTag(); readLen(); // SEQUENCE (outer)
  readTag(); readLen(); // SEQUENCE (AlgorithmIdentifier)
  skipTLV(); // OID rsaEncryption
  skipTLV(); // NULL
  readTag(); // BIT STRING tag
  readLen(); // length (includes unused-bits byte + inner SEQUENCE)
  pos++; // skip unused bits byte (should be 0)

  readTag(); readLen(); // inner SEQUENCE

  // modulus (INTEGER, may have leading 0x00 for sign)
  readTag(); // 0x02
  const mLen = readLen();
  let mStart = pos;
  if (derBytes[mStart] === 0) mStart++;
  const modBytes = derBytes.slice(mStart, pos + mLen);
  pos += mLen;

  // exponent (INTEGER)
  readTag(); // 0x02
  const eLen = readLen();
  let eStart = pos;
  if (derBytes[eStart] === 0) eStart++;
  const expBytes = derBytes.slice(eStart, pos + eLen);
  pos += eLen;

  return { modulus: modBytes, exponent: expBytes };
}

function rsaEncrypt(plainBytes, pubKeyB64) {
  const der = base64Decode(pubKeyB64);
  const { modulus: nBytes, exponent: eBytes } = parseDerPublicKey(der);

  const n = biFromBytes(nBytes);
  const keyLen = nBytes.length;

  // PKCS#1 v1.5 padding: 0x00 0x02 [PS: random non-zero bytes, >= 8] 0x00 [message]
  const padLen = keyLen - plainBytes.length - 3;
  if (padLen < 8) throw new Error('message too long for RSA key');
  const padded = [0, 2];
  for (let j = 0; j < padLen; j++) {
    let b;
    do { b = Math.floor(Math.random() * 255) + 1; } while (b === 0);
    padded.push(b);
  }
  padded.push(0);
  for (const b of plainBytes) padded.push(b);

  const m = biFromBytes(padded);
  const c = rsaModPow(m, n);
  return biToBytes(c, keyLen);
}

/* ==================== 广电加密请求构建 ==================== */

const CBN_PUB_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4QJmWsYFtBbd/yoySbBAy7pBbfrgHr2SGSOGoBukd65IUqQ9uWhvzCN9r0nWESIXWW6FR2A5adHUFFeETucXGjU61BZxbLLf0ARL4F1NkkFMUF/D3GMY401+6TK8jVMxy4vLb6EKzlyZaI8jKBJ9jh0HMli6U7JHydsXstGRUnyx8Mu11bJ3+ZMUcKe51Zi+85Ez756EdZhGTXSY7pUAvh8/0Fea6mtsOs9OLMHbGMKAOE0alN1QdfqE3QMKgB58MVwlPY7uljelSocjNxCIS58CLvu1iWFrLvsCp8t3DavyA1OD/PPcXRrNLYZgzG5304/LAqfurOpU35AaB5tOnwIDAQAB';

function buildEncryptedRequest(dataObj) {
  // 1. 加 timestamp 和 v
  const data = Object.assign({}, dataObj, { timestamp: Date.now(), v: 'a0049' });

  // 2. 按 key 排序，拼成 key1=val1&key2=val2
  const sortedKeys = Object.keys(data).sort();
  const signStr = sortedKeys.map(k => `${k}=${data[k]}`).join('&');

  // 3. MD5 签名 → Access header
  const access = md5Hex(signStr);

  // 4. JSON → UTF-8 bytes → RSA 加密 → Base64
  const jsonStr = JSON.stringify(data);
  const plainBytes = utf8Bytes(jsonStr);
  const encrypted = rsaEncrypt(plainBytes, CBN_PUB_KEY);
  const encB64 = base64Encode(encrypted);

  return {
    body: JSON.stringify({ data: encB64 }),
    access: access,
  };
}

/* ==================== 常量 ==================== */

const API_BASE = 'https://app.10099.com.cn/contact-web/api';
const API_USERINFO = API_BASE + '/busi/qryUserInfo';
const UA_CBN = 'ChinaRadio/2.2.1 (iPhone; iOS 18.7; Scale/3.00)';

const STORE = {
  cookie: 'cbn_cookie',
  loginTs: 'cbn_login_ts',
  phone: 'cbn_phone',
  datasource: 'cbn_datasource',
  rawDebug: 'cbn_raw_debug',
};

/* ==================== 工具 ==================== */

function pad2(n) { return n < 10 ? `0${n}` : `${n}`; }

function fmtTime(ts) {
  const d = new Date(ts);
  return `${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function getHeader(headers, name) {
  if (!headers) return '';
  if (typeof headers.get === 'function') {
    try {
      const v = headers.get(name);
      if (v) return v;
    } catch (e) {}
  }
  if (typeof headers.getSetCookie === 'function' && /set-cookie/i.test(name)) {
    try { return headers.getSetCookie().join('; '); } catch (e) {}
  }
  const want = String(name).toLowerCase();
  for (const k of Object.keys(headers)) {
    if (String(k).toLowerCase() === want) {
      const v = headers[k];
      return Array.isArray(v) ? v.join('; ') : (v || '');
    }
  }
  return '';
}

function dlog(ctx, msg) {
  if (typeof console !== 'undefined' && console.log) {
    try { console.log(`[CBN] ${msg}`); } catch (e) {}
  }
}

/* ==================== 捕获 ==================== */

function isCbnUrl(url) {
  return /app\.10099\.com\.cn/.test(url);
}

// http_request：捕获登录请求，保存 Cookie 和手机号
async function handleCapture(ctx) {
  const req = ctx.request || {};
  const url = req.url || '';
  const headers = req.headers || {};
  if (!isCbnUrl(url)) return;

  const qmark = url.indexOf('?');
  dlog(ctx, `REQ ${req.method || ''} ${(qmark > 0 ? url.slice(0, qmark) : url).slice(0, 200)}`);

  // 保存 Cookie
  const cookie = String(getHeader(headers, 'cookie') || '').trim();
  if (cookie) ctx.storage.set(STORE.cookie, cookie);

  // 从 cbn_info Cookie 提取手机号（格式：hash,true,手机号,省份代码,...）
  let phone = '';
  const cbnInfoMatch = cookie.match(/cbn_info=([^;]+)/);
  if (cbnInfoMatch) {
    const parts = cbnInfoMatch[1].split(',');
    if (parts.length >= 3 && /^\d{11}$/.test(parts[2])) {
      phone = parts[2];
    }
  }

  // 备用：尝试从请求体提取手机号（虽然实际请求体是加密的）
  if (!phone) {
    let rawBody = '';
    try {
      if (typeof $request !== 'undefined' && $request && typeof $request.body === 'string' && $request.body.length > 0) {
        rawBody = $request.body;
      }
    } catch (e) {}
    if (!rawBody) {
      const cb = req.body;
      rawBody = typeof cb === 'string' ? cb : JSON.stringify(cb || '');
    }
    try {
      const bodyObj = JSON.parse(rawBody);
      if (bodyObj.phone) phone = String(bodyObj.phone);
      else if (bodyObj.mobile) phone = String(bodyObj.mobile);
    } catch (e) {
      const m = rawBody.match(/(?:phone|mobile)["\s:]+(\d{11})/);
      if (m) phone = m[1];
    }
    if (!phone) {
      const um = url.match(/(?:phone|mobile)=(\d{11})/);
      if (um) phone = um[1];
    }
  }

  if (/^\d{11}$/.test(phone)) {
    ctx.storage.set(STORE.phone, phone);
    dlog(ctx, `捕获手机号: ${phone.slice(0, 3)}****${phone.slice(7)}`);
  }

  if (cookie) {
    ctx.storage.set(STORE.loginTs, String(Date.now()));
    ctx.notify({ title: '中国广电', body: '登录 Cookie 已捕获，小组件将自动更新' });
  }
}

// http_response：从响应里抓 Set-Cookie
async function handleRespCapture(ctx) {
  const req = ctx.request || {};
  const resp = ctx.response || {};
  const url = req.url || resp.url || '';
  if (!isCbnUrl(url)) return;

  let respHeaders = resp.headers || {};
  try {
    if (typeof $response !== 'undefined' && $response && $response.headers) {
      const gh = $response.headers;
      if (!respHeaders['set-cookie'] && !respHeaders['Set-Cookie'] && (gh['set-cookie'] || gh['Set-Cookie'])) {
        respHeaders = gh;
      }
    }
  } catch (e) {}

  const setCookie = String(getHeader(respHeaders, 'set-cookie') || '').trim();
  if (setCookie) {
    const old = ctx.storage.get(STORE.cookie) || '';
    // 合并新旧 cookie
    const merged = old ? mergeCookies(old, setCookie) : setCookie;
    if (merged !== old) {
      ctx.storage.set(STORE.cookie, merged);
      dlog(ctx, `Cookie 已更新`);
    }
  }
}

function mergeCookies(old, newSC) {
  const map = {};
  for (const part of old.split(/;\s*/)) {
    const eq = part.indexOf('=');
    if (eq > 0) map[part.slice(0, eq).trim()] = part;
  }
  for (const part of newSC.split(/;\s*/)) {
    const eq = part.indexOf('=');
    if (eq > 0) {
      const name = part.slice(0, eq).trim();
      // Set-Cookie 可能带 path/domain 等属性，只取 name=value
      const val = part.split(';')[0].trim();
      map[name] = val;
    }
  }
  return Object.values(map).join('; ');
}

/* ==================== 数据层 ==================== */

function getPhone(ctx) {
  const env = ctx.env || {};
  const fromEnv = (env.CBN_PHONENUMBER || '').trim();
  if (/^\d{11}$/.test(fromEnv)) {
    try { ctx.storage.set('cbn_phone_backup', fromEnv); } catch (e) {}
    return fromEnv;
  }
  try {
    const stored = (ctx.storage.get(STORE.phone) || '').trim();
    if (/^\d{11}$/.test(stored)) return stored;
  } catch (e) {}
  try {
    const bak = (ctx.storage.get('cbn_phone_backup') || '').trim();
    if (/^\d{11}$/.test(bak)) return bak;
  } catch (e) {}
  return '';
}

async function queryUserInfo(ctx) {
  const env = ctx.env || {};
  const phone = getPhone(ctx);
  if (!/^\d{11}$/.test(phone)) {
    const e = new Error('no-phone');
    e.stage = 'phone';
    throw e;
  }
  // 优先使用环境变量 CBN_COOKIE，其次使用存储的 Cookie
  let cookie = (env.CBN_COOKIE || '').trim();
  if (!cookie) {
    cookie = ctx.storage.get(STORE.cookie) || '';
  }
  if (!cookie) {
    const e = new Error('no-cookie');
    e.stage = 'capture';
    throw e;
  }

  const { body, access } = buildEncryptedRequest({ phoneNumber: phone });

  const headers = {
    'Host': 'app.10099.com.cn',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Access': access,
    'Cookie': cookie,
    'User-Agent': UA_CBN,
    'Origin': 'https://app.10099.com.cn',
    'Referer': 'https://app.10099.com.cn/',
  };

  const resp = await ctx.http.post(API_USERINFO, { headers, body, timeout: 15000 });
  if (!resp || resp.status !== 200) {
    const e = new Error(`HTTP ${resp ? resp.status : 'no-response'}`);
    e.stage = 'network';
    throw e;
  }

  // 更新 Cookie
  absorbSetCookie(ctx, resp.headers);

  const text = typeof resp.text === 'function' ? await resp.text() : String(resp.body || '');
  const env = ctx.env || {};
  if (env.CBN_DEBUG === 'true') ctx.storage.set(STORE.rawDebug, text.slice(0, 500));

  let data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    const err = new Error('json-parse-failed');
    err.stage = 'parse';
    throw err;
  }

  if (data.status !== '000000') {
    const e = new Error(`api-error: ${data.status} ${data.message || ''}`);
    e.stage = 'session';
    throw e;
  }

  return data;
}

function absorbSetCookie(ctx, headers) {
  const sc = String(getHeader(headers, 'set-cookie') || '').trim();
  if (sc) {
    const old = ctx.storage.get(STORE.cookie) || '';
    const merged = old ? mergeCookies(old, sc) : sc;
    if (merged !== old) {
      ctx.storage.set(STORE.cookie, merged);
      return true;
    }
  }
  return false;
}

async function loadData(ctx) {
  const env = ctx.env || {};
  const debug = env.CBN_DEBUG === 'true';
  const phone = getPhone(ctx);
  
  const envCookie = (env.CBN_COOKIE || '').trim();
  const storedCookie = ctx.storage.get(STORE.cookie) || '';
  const hasCookie = !!(envCookie || storedCookie);

  if (!hasCookie) return { configured: false, reason: 'capture', debug };
  if (!/^\d{11}$/.test(phone)) return { configured: false, reason: 'phone', debug };

  try {
    const resp = await queryUserInfo(ctx);
    const ds = parseCbnData(resp, ctx);
    ds.updatedAt = Date.now();
    ds.valid = true;
    if (debug) ds.debug = ctx.storage.get(STORE.rawDebug) || '';
    ctx.storage.setJSON(STORE.datasource, ds);
    return { configured: true, ds, fromCache: false, debug };
  } catch (e) {
    let cached = null;
    try { cached = ctx.storage.getJSON(STORE.datasource); } catch (ex) {}
    if (cached && cached.flow && cached.flow.number === '--' && cached.voice && cached.voice.number === '--') cached = null;
    if (cached) cached.stale = (e && e.stage) === 'session' ? '登录过期' : '缓存';
    return {
      configured: true, ds: cached || null, fromCache: !!cached, debug,
      error: String((e && e.message) || e), stage: (e && e.stage) || '',
    };
  }
}

function parseCbnData(resp, ctx) {
  const ud = (resp && resp.data && resp.data.userData) || {};
  const env = ctx.env || {};

  if (env.CBN_DEBUG === 'true') {
    const keys = Object.keys(ud).join(', ');
    try { ctx.storage.set(STORE.rawDebug, `API字段: ${keys}\nflow=${ud.flow}\nflowAll=${ud.flowAll}\nflowUserd=${ud.flowUserd}\nflowUsed=${ud.flowUsed}\nvoice=${ud.voice}\nvoiceAll=${ud.voiceAll}\nfinBalance=${ud.finBalance}\nfee=${ud.fee}`); } catch (e) {}
  }

  // 话费
  const feeNum = ud.finBalance != null
    ? parseFloat(ud.finBalance)
    : (ud.fee != null ? ud.fee / 100 : 0);
  const fee = {
    title: '剩余话费',
    number: Number.isFinite(feeNum) ? feeNum.toFixed(2) : '0.00',
    unit: '元',
  };

  // 流量（字节 → MB/GB）— 兼容多种字段名
  const flowRemain = parseFloat(ud.flow || ud.flowRemain || ud.remainFlow || '0');
  const flowTotal = parseFloat(ud.flowAll || ud.totalFlow || ud.allFlow || '0');
  const flowUsed = parseFloat(ud.flowUserd || ud.flowUsed || ud.usedFlow || '0');
  const showUsed = env.CBN_SHOW_USED_FLOW === 'true';

  const flowMB = flowRemain / (1024 * 1024);
  const flowTotalMB = flowTotal / (1024 * 1024);
  const flowUsedMB = flowUsed / (1024 * 1024);

  let flow;
  if (flowTotal > 0) {
    const u = flowMB >= 1024
      ? { number: (flowMB / 1024).toFixed(2), unit: 'GB' }
      : { number: flowMB.toFixed(2), unit: 'MB' };
    flow = {
      title: showUsed ? '已用流量' : '剩余流量',
      number: showUsed ? (flowUsedMB >= 1024 ? (flowUsedMB / 1024).toFixed(2) : flowUsedMB.toFixed(2)) : u.number,
      unit: showUsed ? (flowUsedMB >= 1024 ? 'GB' : 'MB') : u.unit,
      percent: Math.max(0, Math.min(1, flowRemain / flowTotal)),
      color: '#0A84FF',
    };
    const totalU = flowTotalMB >= 1024
      ? { number: (flowTotalMB / 1024).toFixed(2), unit: 'GB' }
      : { number: flowTotalMB.toFixed(2), unit: 'MB' };
    flow.total = totalU;
  } else {
    flow = { title: '剩余流量', number: '--', unit: '', percent: 0, color: '#0A84FF' };
  }

  // 其他流量（广电暂不区分，留空）
  const otherFlow = { title: '其他流量', number: '--', unit: '', percent: 0, color: '#5AC8FA' };

  // 语音
  const voiceRemain = parseInt(ud.voice || '0', 10);
  const voiceTotal = parseInt(ud.voiceAll || '0', 10);
  let voice;
  if (voiceTotal > 0) {
    voice = {
      title: '剩余语音',
      number: String(Number.isFinite(voiceRemain) ? voiceRemain : 0),
      unit: '分钟',
      percent: Math.max(0, Math.min(1, voiceRemain / voiceTotal)),
      color: '#30D158',
    };
  } else {
    voice = { title: '剩余语音', number: voiceRemain > 0 ? String(voiceRemain) : '--', unit: '分钟', percent: 0, color: '#30D158' };
  }

  return { fee, flow, otherFlow, voice, updatedAt: Date.now(), valid: true, packName: ud.packName || '' };
}

/* ==================== 渲染层（Widget DSL）· iOS 液态玻璃风格 ==================== */

const C_FEE = '#FF9F0A';
const C_FLOW = '#0A84FF';
const C_OTHER = '#64D2FF';
const C_VOICE = '#30D158';
const WARN = '#FF453A';
const TXT = { light: '#000000', dark: '#FFFFFF' };
const SUB = { light: '#3C3C4399', dark: '#EBEBF599' };
const GLASS = { light: '#FFFFFFA6', dark: '#FFFFFF1A' };

function bg() {
  return {
    type: 'linear',
    colors: [{ light: '#EAF3FF', dark: '#0B1A33' }, { light: '#F4F0FF', dark: '#120B24' }, { light: '#E9FBF3', dark: '#03140F' }],
    stops: [0, 0.55, 1],
    startPoint: { x: 0, y: 0 },
    endPoint: { x: 1, y: 1 },
  };
}

/* ---------- 用量洞察 ---------- */

function toMB(d) {
  const n = parseFloat(d && d.number);
  if (!Number.isFinite(n)) return null;
  return d.unit === 'GB' ? n * 1024 : n;
}

function fmtMB(mb) {
  if (mb == null || !Number.isFinite(mb)) return '--';
  return mb >= 1024 ? `${(mb / 1024).toFixed(2)} GB` : `${mb.toFixed(0)} MB`;
}

function insights(ctx, ds) {
  const now = new Date();
  const dayKey = `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`;
  const dim = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const daysLeft = dim - now.getDate() + 1;
  const _g = toMB(ds.flow), _o = toMB(ds.otherFlow);
  const env = ctx.env || {};
  const flowMB = env.CBN_SHOW_USED_FLOW === 'true' ? null
    : (_g == null && _o == null ? null : (_g || 0) + (_o || 0));
  let todayMB = null;
  if (flowMB != null) {
    let snap = null;
    try { snap = ctx.storage.getJSON('cbn_day_snap'); } catch (e) {}
    if (!snap || snap.date !== dayKey || flowMB > snap.start + 1) {
      snap = { date: dayKey, start: flowMB };
      try { ctx.storage.setJSON('cbn_day_snap', snap); } catch (e) {}
    }
    todayMB = Math.max(0, snap.start - flowMB);
  }
  const hist = [];
  if (todayMB != null) {
    let h = {};
    try { h = ctx.storage.getJSON('cbn_hist') || {}; } catch (e) {}
    h[dayKey] = todayMB;
    const keep = {};
    for (let i = 7; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 86400000);
      const k = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
      if (h[k] != null) keep[k] = h[k];
      if (i <= 6) hist.push(h[k] == null ? null : h[k]);
    }
    try { ctx.storage.setJSON('cbn_hist', keep); } catch (e) {}
  }
  let forecast = { text: '用量统计中…', color: SUB };
  if (flowMB != null) {
    const past = hist.slice(0, 6).filter(v => v != null && v > 0);
    const vals = past.length ? past : (todayMB > 0 ? [todayMB] : []);
    if (vals.length) {
      const avg = vals.reduce((a, b) => a + b, 0) / vals.length;
      const days = Math.floor(flowMB / avg);
      forecast = days >= daysLeft
        ? { text: days > 999 ? '按近期速度 充足' : `预计够用 ${days} 天 ✓`, color: C_VOICE }
        : { text: `约 ${days} 天用完 · 早于月底`, color: C_FEE };
    }
  }
  return {
    hist, forecast, daysLeft,
    monthPct: (now.getDate() - 1 + now.getHours() / 24) / dim,
    todayMB,
    dailyMB: flowMB != null ? flowMB / daysLeft : null,
    lowFee: (() => { const n = parseFloat(ds.fee.number); return Number.isFinite(n) && n < 10; })(),
  };
}

/* ---------- 图形 ---------- */

function ringSvg(pct, size, stroke) {
  const h = size / 2;
  const r = h - stroke / 2;
  const c = 2 * Math.PI * r;
  const p = Math.max(0, Math.min(1, Number(pct) || 0));
  let body = `<circle cx='${h}' cy='${h}' r='${r.toFixed(2)}' fill='none' stroke='white' stroke-opacity='0.22' stroke-width='${stroke}'/>`;
  if (p > 0) {
    if (p >= 0.999) {
      body += `<circle cx='${h}' cy='${h}' r='${r.toFixed(2)}' fill='none' stroke='white' stroke-width='${stroke}'/>`;
    } else {
      const a = p * 2 * Math.PI;
      const x = (h + r * Math.sin(a)).toFixed(2), y = (h - r * Math.cos(a)).toFixed(2);
      body += `<path d='M ${h} ${(h - r).toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(2)} 0 ${p > 0.5 ? 1 : 0} 1 ${x} ${y}' fill='none' stroke='white' stroke-width='${stroke}' stroke-linecap='round'/>`;
    }
  }
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 ${size} ${size}'>${body}</svg>`;
  return 'data:image/svg+xml,' + encodeURIComponent(svg);
}

function gaugeSvg(pct, color, w) {
  const stroke = 12, r = (w - stroke) / 2, cx = w / 2, cy = w / 2, h = w / 2 + stroke / 2;
  const p = Math.max(0, Math.min(1, Number(pct) || 0));
  const pt = a => [(cx - r * Math.cos(a)).toFixed(2), (cy - r * Math.sin(a)).toFixed(2)];
  const [x0, y0] = pt(0), [x1, y1] = pt(Math.PI), [xp, yp] = pt(Math.PI * p);
  let body = `<path d='M ${x0} ${y0} A ${r} ${r} 0 0 1 ${x1} ${y1}' fill='none' stroke='${color}' stroke-opacity='0.22' stroke-width='${stroke}' stroke-linecap='round'/>`;
  if (p > 0.005) body += `<path d='M ${x0} ${y0} A ${r} ${r} 0 0 1 ${xp} ${yp}' fill='none' stroke='${color}' stroke-width='${stroke}' stroke-linecap='round'/>`;
  return 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 ${w} ${h}'>${body}</svg>`);
}

function sparkSvg(values, color, w, h) {
  const vals = values && values.length ? values : [null, null, null, null, null, null, null];
  const n = vals.length, gap = 3, bw = (w - gap * (n - 1)) / n;
  const max = Math.max(1, ...vals.map(v => v || 0));
  let body = '';
  vals.forEach((v, i) => {
    const bh = v ? Math.max(2, (v / max) * h) : 2;
    const op = v == null ? 0.15 : (i === n - 1 ? 1 : 0.55);
    body += `<rect x='${(i * (bw + gap)).toFixed(1)}' y='${(h - bh).toFixed(1)}' width='${bw.toFixed(1)}' height='${bh.toFixed(1)}' rx='${Math.min(2, bw / 2).toFixed(1)}' fill='${color}' fill-opacity='${op}'/>`;
  });
  return 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 ${w} ${h}'>${body}</svg>`);
}

/* ---------- 组件 ---------- */

function t(text, size, weight, color, extra) {
  return Object.assign({ type: 'text', text: String(text), font: { size, weight: weight || 'regular' }, textColor: color || TXT, maxLines: 1, minScale: 0.6 }, extra || {});
}

function glass(children, extra) {
  return Object.assign({ type: 'stack', direction: 'column', alignItems: 'start', gap: 6, padding: 12, borderRadius: 22, backgroundColor: GLASS, children }, extra || {});
}

function header(title, ds, fromCache) {
  return {
    type: 'stack', direction: 'row', alignItems: 'center', gap: 4,
    children: [
      { type: 'image', src: 'sf-symbol:antenna.radiowaves.left.and.right', width: 12, height: 12, color: C_FLOW },
      t(title, 'footnote', 'semibold'),
      { type: 'spacer' },
      t(`${fromCache ? ((ds && ds.stale) || '缓存') + ' · ' : ''}更新 ${ds && ds.updatedAt ? fmtTime(ds.updatedAt) : '--'}`, 10, 'regular', SUB, { minScale: 1 }),
    ],
  };
}

function gaugeCard(icon, color, d, fallbackTitle, opt) {
  const o = opt || {};
  const data = d || { title: fallbackTitle, number: '--', unit: '', percent: 0 };
  const pct = data.percent > 0 ? Math.round(data.percent * 100) : 0;
  const gw = o.gw || 46;
  return glass([
    {
      type: 'stack', direction: 'row', alignItems: 'center', gap: 3,
      children: [
        { type: 'image', src: `sf-symbol:${icon}`, width: 10, height: 10, color },
        t(o.title || data.title || fallbackTitle, 9, 'medium', SUB, { minScale: 1 }),
      ],
    },
    {
      type: 'stack', direction: 'column', alignItems: 'center', gap: -3,
      children: [
        { type: 'image', src: gaugeSvg(data.percent, color, 64), width: gw, height: Math.round(gw * 38 / 64) },
        t(`${pct}%`, 9, 'bold', color, { minScale: 1 }),
      ],
    },
    {
      type: 'stack', direction: 'row', alignItems: 'end', gap: 2,
      children: [
        t(data.number, o.numSize || 15, 'bold', TXT, { minScale: 0.7 }),
        t(data.unit || '', 9, 'semibold', SUB, { minScale: 1 }),
      ],
    },
  ], { flex: 1, alignItems: 'center', gap: 2, padding: [7, 4], borderRadius: 16, ...(o.height ? { height: o.height } : {}) });
}

function feeCard(ds, ins, size, extra) {
  const low = ins.lowFee;
  return glass([
    {
      type: 'stack', direction: 'row', alignItems: 'center', gap: 3,
      children: [
        { type: 'image', src: 'sf-symbol:yensign.circle.fill', width: 10, height: 10, color: low ? WARN : C_FEE },
        t(low ? '话费不足' : '剩余话费', 9, 'medium', low ? WARN : SUB, { minScale: 1 }),
      ],
    },
    { type: 'spacer' },
    {
      type: 'stack', direction: 'row', alignItems: 'end', gap: 1,
      children: [t('¥', 11, 'semibold', low ? WARN : SUB, { minScale: 1 }), t(ds.fee.number, size || 22, 'bold', low ? WARN : TXT, { minScale: 0.6 })],
    },
    t(`本月剩 ${ins.daysLeft} 天`, 9, 'medium', SUB, { minScale: 1 }),
    ...(extra && extra.alignItems === 'center' ? [{ type: 'spacer' }] : []),
  ], Object.assign({ gap: 2, padding: [7, 9], borderRadius: 16 }, extra || {}));
}

function statsStrip(ins, sparkW) {
  return glass([
    {
      type: 'stack', direction: 'row', alignItems: 'center', gap: 6,
      children: [
        { type: 'image', src: sparkSvg(ins.hist, C_FLOW, 70, 14), width: sparkW || 46, height: 11 },
        t(`今日 ${fmtMB(ins.todayMB)}`, 9, 'semibold', TXT, { minScale: 1 }),
        t(`日均可用 ${fmtMB(ins.dailyMB)}`, 9, 'medium', SUB, { minScale: 1 }),
        { type: 'spacer' },
        t(ins.forecast.text, 9, 'semibold', ins.forecast.color, { minScale: 0.8 }),
      ],
    },
  ], { padding: [6, 9], borderRadius: 12, gap: 0 });
}

function pctText(d) { return d && d.percent > 0 ? `${Math.round(d.percent * 100)}%` : ''; }

function refresh30() { return new Date(Date.now() + 30 * 60 * 1000).toISOString(); }

/* ---------- 尺寸 ---------- */

function buildSmall(title, ds, fromCache, ctx) {
  const ins = insights(ctx, ds);
  return {
    type: 'widget', padding: 12, gap: 5, backgroundGradient: bg(), refreshAfter: refresh30(),
    children: [
      {
        type: 'stack', direction: 'row', alignItems: 'center', gap: 4,
        children: [
          { type: 'image', src: 'sf-symbol:antenna.radiowaves.left.and.right', width: 11, height: 11, color: C_FLOW },
          t(title, 'caption1', 'semibold'),
          { type: 'spacer' },
          t(`¥${ds.fee.number}`, 11, 'bold', ins.lowFee ? WARN : C_FEE, { minScale: 1 }),
        ],
      },
      {
        type: 'stack', direction: 'row', alignItems: 'center', gap: 4, flex: 1,
        children: [
          {
            type: 'stack', direction: 'column', alignItems: 'start', gap: 0,
            children: [
              t('剩余流量', 9, 'medium', SUB, { minScale: 1 }),
              { type: 'stack', direction: 'row', alignItems: 'end', gap: 2, children: [t(ds.flow.number, 22, 'bold', TXT), t(ds.flow.unit || '', 9, 'semibold', SUB, { minScale: 1 })] },
            ],
          },
          { type: 'spacer' },
          {
            type: 'stack', direction: 'column', alignItems: 'center', gap: -3,
            children: [
              { type: 'image', src: gaugeSvg(ds.flow.percent, C_FLOW, 64), width: 42, height: 25 },
              t(pctText(ds.flow) || '0%', 9, 'bold', C_FLOW, { minScale: 1 }),
            ],
          },
        ],
      },
      {
        type: 'stack', direction: 'row', alignItems: 'end', gap: 5,
        children: [
          { type: 'image', src: sparkSvg(ins.hist, C_FLOW, 70, 14), width: 44, height: 11 },
          t(`今日 ${fmtMB(ins.todayMB)}`, 9, 'semibold', TXT, { minScale: 1 }),
        ],
      },
      t(`其他 ${ds.otherFlow ? ds.otherFlow.number + (ds.otherFlow.unit || '') : '--'} · 语音 ${ds.voice.number}${ds.voice.unit || ''}`, 9, 'medium', SUB, { minScale: 0.75 }),
      t(`日均可用 ${fmtMB(ins.dailyMB)} · ${ins.forecast.text}`, 9, 'semibold', ins.forecast.color, { minScale: 0.7 }),
    ],
  };
}

function buildMedium(title, ds, fromCache, ctx) {
  const ins = insights(ctx, ds);
  return {
    type: 'widget', padding: [10, 11], gap: 6, backgroundGradient: bg(), refreshAfter: refresh30(),
    children: [
      header(title, ds, fromCache),
      {
        type: 'stack', direction: 'row', alignItems: 'center', gap: 6, flex: 1,
        children: [
          feeCard(ds, ins, 21, { width: 84, height: 82, alignItems: 'center' }),
          gaugeCard('wifi', C_FLOW, ds.flow, '剩余流量', { height: 82 }),
          gaugeCard('globe.asia.australia.fill', C_OTHER, ds.otherFlow, '其他流量', { height: 82 }),
          gaugeCard('phone.fill', C_VOICE, ds.voice, '剩余语音', { height: 82 }),
        ],
      },
      statsStrip(ins, 40),
      ...(ds.debug ? [t(ds.debug, 'caption2', 'regular', SUB, { maxLines: 3 })] : []),
    ],
  };
}

function buildLarge(title, ds, fromCache, ctx) {
  const ins = insights(ctx, ds);
  const phone = getPhone(ctx);
  const masked = /^\d{11}$/.test(phone) ? `${phone.slice(0, 3)} **** ${phone.slice(7)}` : '';
  const labels = [];
  for (let i = 6; i >= 0; i--) { const d = new Date(Date.now() - i * 86400000); labels.push(i === 0 ? '今' : `${d.getDate()}`); }
  return {
    type: 'widget', padding: 14, gap: 9, backgroundGradient: bg(), refreshAfter: refresh30(),
    children: [
      header(title, ds, fromCache),
      {
        type: 'stack', direction: 'row', alignItems: 'center', gap: 8,
        children: [
          feeCard(ds, ins, 30, { flex: 1, height: 74, padding: [9, 12] }),
          glass([
            t('当前号码', 9, 'medium', SUB, { minScale: 1 }),
            t(masked || '--', 13, 'semibold', TXT, { family: 'Menlo', minScale: 0.7 }),
            { type: 'spacer' },
            t(ins.forecast.text, 10, 'semibold', ins.forecast.color, { minScale: 0.7 }),
          ], { flex: 1, height: 74, gap: 2, padding: [9, 12], borderRadius: 16 }),
        ],
      },
      {
        type: 'stack', direction: 'row', alignItems: 'center', gap: 8,
        children: [
          gaugeCard('wifi', C_FLOW, ds.flow, '剩余流量', { gw: 62, numSize: 18 }),
          gaugeCard('globe.asia.australia.fill', C_OTHER, ds.otherFlow, '其他流量', { gw: 62, numSize: 18 }),
          gaugeCard('phone.fill', C_VOICE, ds.voice, '剩余语音', { gw: 62, numSize: 18 }),
        ],
      },
      glass([
        {
          type: 'stack', direction: 'row', alignItems: 'center', gap: 4,
          children: [
            { type: 'image', src: 'sf-symbol:chart.bar.fill', width: 10, height: 10, color: C_FLOW },
            t('近 7 天流量', 10, 'semibold', TXT, { minScale: 1 }),
            { type: 'spacer' },
            t(`今日 ${fmtMB(ins.todayMB)} · 日均可用 ${fmtMB(ins.dailyMB)}`, 9, 'medium', SUB, { minScale: 0.8 }),
          ],
        },
        { type: 'image', src: sparkSvg(ins.hist, C_FLOW, 290, 40), width: 290, height: 40 },
        {
          type: 'stack', direction: 'row', alignItems: 'center', gap: 0,
          children: labels.map(l => ({ type: 'stack', direction: 'row', flex: 1, children: [{ type: 'spacer' }, t(l, 8, 'medium', SUB, { minScale: 1 }), { type: 'spacer' }] })),
        },
      ], { gap: 5, padding: [9, 12], borderRadius: 16 }),
      { type: 'spacer' },
      ...(ds.debug ? [t(ds.debug, 'caption2', 'regular', SUB, { maxLines: 3 })] : []),
    ],
  };
}

function buildLockScreen(title, ds, family, ctx) {
  const ins = insights(ctx, ds);
  if (family === 'accessoryInline') {
    return { type: 'widget', children: [{ type: 'text', text: `¥${ds.fee.number} · ${ds.flow.number}${ds.flow.unit} · ${ds.voice.number}分`, maxLines: 1, minScale: 0.6 }] };
  }
  if (family === 'accessoryCircular') {
    const hasPct = ds.flow && ds.flow.percent > 0;
    return {
      type: 'widget', padding: 8, backgroundImage: ringSvg(hasPct ? ds.flow.percent : 0, 60, 6),
      children: [
        { type: 'spacer' },
        {
          type: 'stack', direction: 'column', alignItems: 'center', gap: 0,
          children: hasPct
            ? [
              { type: 'image', src: 'sf-symbol:wifi', width: 10, height: 10 },
              { type: 'text', text: String(ds.flow.number), font: { size: 14, weight: 'bold' }, textAlign: 'center', maxLines: 1, minScale: 0.5 },
              { type: 'text', text: ds.flow.unit, font: { size: 9 }, textAlign: 'center', opacity: 0.7 },
            ]
            : [
              { type: 'text', text: '¥', font: { size: 9 }, textAlign: 'center', opacity: 0.7 },
              { type: 'text', text: ds.fee.number, font: { size: 14, weight: 'bold' }, textAlign: 'center', maxLines: 1, minScale: 0.5 },
            ],
        },
        { type: 'spacer' },
      ],
    };
  }
  return {
    type: 'widget', padding: [2, 4], gap: 2,
    children: [
      { type: 'text', text: `¥${ds.fee.number}${ins.lowFee ? ' · 话费不足' : ''}`, font: { size: 'footnote', weight: 'bold' }, maxLines: 1, minScale: 0.6 },
      { type: 'text', text: `流量 ${ds.flow.number} ${ds.flow.unit} · 语音 ${ds.voice.number}分`, font: { size: 'caption2', weight: 'semibold' }, maxLines: 1, minScale: 0.6 },
      { type: 'text', text: ins.todayMB != null ? `今日 ${fmtMB(ins.todayMB)} · 日均 ${fmtMB(ins.dailyMB)}` : `还剩 ${ins.daysLeft} 天`, font: { size: 'caption2' }, opacity: 0.7, maxLines: 1, minScale: 0.6 },
    ],
  };
}

function buildError(title, message, extra) {
  const children = [
    t(title, 'footnote', 'semibold'),
    { type: 'spacer' },
    { type: 'image', src: 'sf-symbol:exclamationmark.triangle.fill', width: 22, height: 22, color: C_FEE },
    t(message, 'caption1', 'medium', TXT, { maxLines: 4, minScale: 0.7 }),
  ];
  if (extra) children.push(t(extra, 'caption2', 'regular', SUB, { maxLines: 3 }));
  children.push({ type: 'spacer' });
  return { type: 'widget', padding: 14, gap: 6, backgroundGradient: bg(), children };
}

/* ==================== 小组件（generic） ==================== */

async function handleWidget(ctx) {
  const env = ctx.env || {};
  const title = (env.CBN_TITLE || '中国广电').trim() || '中国广电';
  
  // 调试：在小组件上显示环境变量信息
  const debug = env.CBN_DEBUG === 'true';
  if (debug) {
    const envKeys = Object.keys(env).join(', ') || '无';
    const envInfo = `环境变量: ${envKeys}\nCBN_COOKIE长度: ${(env.CBN_COOKIE || '').length}\nCBN_PHONENUMBER: ${env.CBN_PHONENUMBER || '未设置'}`;
    try { ctx.storage.set(STORE.rawDebug, envInfo); } catch (e) {}
  }
  
  const r = await loadData(ctx);

  if (!r.configured) {
    if (r.reason === 'phone') {
      return buildError(title, '请在模块 Env 里填写 CBN_PHONENUMBER（11 位广电手机号）');
    }
    // 显示调试信息
    if (debug) {
      const envInfo = ctx.storage.get(STORE.rawDebug) || '无法读取调试信息';
      return buildError(title, `还没抓到登录 Cookie\n\n调试信息:\n${envInfo}`, '检查环境变量是否正确配置');
    }
    return buildError(title, '还没抓到登录 Cookie：打开「中国广电」App，用短信验证码登录一次，或在模块 Env 里填写 CBN_COOKIE');
  }
  if (!r.ds) {
    const hint = r.stage === 'network'
      ? `网络请求失败: ${r.error || ''}`
      : r.stage === 'session'
        ? `登录过期: ${r.error || ''}`
        : r.stage === 'parse'
          ? `解析失败: ${r.error || ''}`
          : `查询失败: ${r.error || ''}`;
    return buildError(title, hint, '');
  }

  const family = ctx.widgetFamily || 'systemSmall';
  if (family === 'systemLarge' || family === 'systemExtraLarge') return buildLarge(title, r.ds, r.fromCache, ctx);
  if (family === 'systemMedium') return buildMedium(title, r.ds, r.fromCache, ctx);
  if (family.startsWith('accessory')) return buildLockScreen(title, r.ds, family, ctx);
  return buildSmall(title, r.ds, r.fromCache, ctx);
}

/* ==================== 入口：单文件三模式 ==================== */

export default async function(ctx) {
  try {
    if (ctx.request && ctx.request.url) {
      if (ctx.response && (ctx.response.status || ctx.response.headers)) {
        return await handleRespCapture(ctx);
      }
      return await handleCapture(ctx);
    }
    return await handleWidget(ctx);
  } catch (e) {
    // 全局错误处理：如果脚本执行失败，显示错误信息
    const title = (ctx.env && ctx.env.CBN_TITLE) || '中国广电';
    return {
      type: 'widget',
      padding: 14,
      gap: 6,
      backgroundGradient: bg(),
      children: [
        t(title, 'footnote', 'semibold'),
        { type: 'spacer' },
        { type: 'image', src: 'sf-symbol:exclamationmark.triangle.fill', width: 22, height: 22, color: C_FEE },
        t(`脚本执行错误: ${String(e.message || e)}`, 'caption1', 'medium', TXT, { maxLines: 4, minScale: 0.7 }),
        t(`堆栈: ${String(e.stack || '').slice(0, 100)}`, 'caption2', 'regular', SUB, { maxLines: 3 }),
        { type: 'spacer' },
      ],
    };
  }
}
