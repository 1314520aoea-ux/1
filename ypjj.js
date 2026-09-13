/**
 * Audio Editor & Music Mixer 解锁脚本
 * 适用平台: Surge / Loon / Quantumult X / Shadowrocket
 */

const resp = {};
const obj = JSON.parse(typeof $response != "undefined" && $response.body || "{}");

// 修改本地鉴权/订阅状态标记
if (obj) {
  obj.is_vip = true;
  obj.vip_type = 1;
  obj.expire_time = 4070880000; // 2099年过期时间戳
  obj.status = 1;
}

$done({ body: JSON.stringify(obj) });

