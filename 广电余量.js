/**
 * 中国广电余量 · 抓取脚本（http_request + http_response 共用）
 *
 * 作用：在你打开「中国广电」App、查询套餐/余额时，把
 *   1) 请求（URL / 请求头 / 加密请求体 / Cookie）  → cbn:req:<接口名>
 *   2) 响应（解析后的 JSON）                      → cbn:res:<接口名>
 * 存进 Egern 本地存储，供小组件重放请求或作为缓存显示。
 *
 * 只读取，不修改任何请求和响应。数据只保存在本机，只会发往 app.10099.com.cn。
 */

const SKIP = new Set(['host', 'content-length', 'accept-encoding', 'connection', 'transfer-encoding', 'keep-alive']);
// 抓不到枚举时兜底读取的请求头（t5hhv8ah 是瑞数防护头，名字随站点变化，所以同时尝试枚举）
const WHITELIST = [
  'cookie', 'access', 'session', 't5hhv8ah', 'user-agent', 'content-type',
  'accept', 'accept-language', 'origin', 'referer',
  'sec-fetch-site', 'sec-fetch-mode', 'sec-fetch-dest',
];

function dumpHeaders(h) {
  const out = {};
  if (!h) return out;
  try {
    for (const k of Object.keys(h)) {
      const lk = String(k).toLowerCase();
      if (!lk || lk[0] === ':' || SKIP.has(lk)) continue;
      const v = h[k];
      if (typeof v === 'string') out[lk] = v;
      else if (Array.isArray(v)) out[lk] = v.join('; ');
    }
  } catch (e) {}
  for (const name of WHITELIST) {
    try {
      const v = h.get(name);
      if (v && !out[name]) out[name] = v;
    } catch (e) {}
  }
  return out;
}

function validResponse(name, j) {
  if (!j || j.status !== '000000' || !j.data) return false;
  if (name === 'qryUserInfo') return !!j.data.userData;
  if (name === 'qryUserRes') return !!(j.data.intfResultBean && j.data.intfResultBean.userResList);
  return false;
}

async function onRequest(ctx, name) {
  const req = ctx.request;
  let body = '';
  try {
    body = await req.text();
  } catch (e) {}
  const headers = dumpHeaders(req.headers);
  if (!body || !Object.keys(headers).length) return;
  ctx.storage.setJSON('cbn:req:' + name, {
    url: req.url,
    method: req.method || 'POST',
    headers,
    body,
    ts: Date.now(),
  });
}

async function onResponse(ctx, name) {
  let j = null;
  try {
    j = JSON.parse(await ctx.response.text());
  } catch (e) {
    return;
  }
  if (!validResponse(name, j)) return;
  ctx.storage.setJSON('cbn:res:' + name, { data: j, ts: Date.now() });

  // 通知最多每 10 分钟一次，避免打开 App 时刷屏
  const key = 'cbn:notified';
  const last = Number(ctx.storage.get(key) || 0);
  if (Date.now() - last > 10 * 60 * 1000) {
    ctx.storage.set(key, String(Date.now()));
    const hasReq = !!ctx.storage.getJSON('cbn:req:' + name);
    ctx.notify({
      title: '中国广电',
      body: hasReq ? '登录信息已就绪，可以添加小组件了' : '已获取数据，但没拦到请求头，请再打开一次套餐查询',
      sound: false,
    });
  }
}

export default async function (ctx) {
  try {
    const m = String(ctx.request.url).match(/\/busi\/(qryUserInfo|qryUserRes)(?:\?|$)/);
    if (!m) return;
    if (ctx.response) await onResponse(ctx, m[1]);
    else await onRequest(ctx, m[1]);
  } catch (e) {
    // 抓取失败不能影响 App 正常使用
  }
}
