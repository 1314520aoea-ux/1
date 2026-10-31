(function() {
  var url = $request.url;
  var status = $response.status;
  var body = $response.body || "";

  // 第三方广告 SDK 域名
  var adDomains = [
    'ibroadlink.com',
    'adwangmai.com',
    'gdt.qq.com',
    'csjplatform.com',
    'pangle.cn',
    'admob.com',
    'baidumobad.com',
    'inmobi.com',
    'unityads.unity3d.com'
  ];

  // 检查是否为广告请求
  var isAd = false;
  for (var i = 0; i < adDomains.length; i++) {
    if (url.indexOf(adDomains[i]) !== -1) {
      isAd = true;
      break;
    }
  }

  if (!isAd) {
    $done({});
    return;
  }

  // 拦截广告响应
  console.log('[AdBlock] Blocked ad request: ' + url);
  $done({ status: 204 });
})();
