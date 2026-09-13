/*
 * Audio Editor (音频剪辑) & RevenueCat 通用解锁脚本
 */

const obj = JSON.parse(typeof $response != "undefined" && $response.body || "{}");

if (typeof obj.subscriber !== "undefined") {
  obj.subscriber.subscriptions = obj.subscriber.subscriptions || {};
  obj.subscriber.entitlements = obj.subscriber.entitlements || {};

  const proData = {
    "expires_date": "2099-12-31T23:59:59Z",
    "product_identifier": "com.audioeditor.pro_yearly",
    "purchase_date": "2023-01-01T00:00:00Z"
  };

  // 注入通用及常见 VIP 权限标识
  obj.subscriber.entitlements["pro"] = proData;
  obj.subscriber.entitlements["VIP"] = proData;
  obj.subscriber.entitlements["Premium"] = proData;
  obj.subscriber.entitlements["premium"] = proData;

  obj.subscriber.subscriptions["com.audioeditor.pro_yearly"] = {
    "expires_date": "2099-12-31T23:59:59Z",
    "original_purchase_date": "2023-01-01T00:00:00Z",
    "purchase_date": "2023-01-01T00:00:00Z",
    "store": "app_store"
  };
} else {
  obj.is_vip = true;
  obj.vip_type = 1;
  obj.expire_time = 4070880000;
  obj.status = 1;
}

$done({ body: JSON.stringify(obj) });

