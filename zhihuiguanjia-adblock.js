(function() {
  var url = $request.url;
  var status = $response.status;
  var body = $response.body || "";

  // 广告域名列表
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

  // 广告 API 路径
  var adPaths = [
    '/ads/',
    '/ad/',
    '/banner',
    '/splash',
    '/promotion',
    '/marketing',
    '/campaign',
    '/recommend'
  ];

  // 检查是否为广告请求
  var isAd = false;
  
  // 检查域名
  for (var i = 0; i < adDomains.length; i++) {
    if (url.indexOf(adDomains[i]) !== -1) {
      isAd = true;
      break;
    }
  }
  
  // 检查 komect.com 的广告 API
  if (!isAd && url.indexOf('komect.com') !== -1) {
    for (var i = 0; i < adPaths.length; i++) {
      if (url.indexOf(adPaths[i]) !== -1) {
        isAd = true;
        break;
      }
    }
  }

  if (!isAd) {
    $done({});
    return;
  }

  // 拦截广告响应
  console.log('[AdBlock] Blocked ad request: ' + url);

  // 返回空响应
  if (url.indexOf('.json') !== -1 || url.indexOf('config') !== -1 || url.indexOf('/ads/') !== -1) {
    // JSON 配置/广告请求返回空数组
    $done({ status: 200, body: '[]' });
  } else if (url.indexOf('.xml') !== -1) {
    // XML 请求返回空
    $done({ status: 200, body: '<?xml version="1.0"?><root></root>' });
  } else {
    // 其他请求返回 204 No Content
    $done({ status: 204 });
  }
})();
