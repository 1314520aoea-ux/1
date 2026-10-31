(function() {
  var url = $request.url;
  var status = $response.status;
  var body = $response.body || "";

  // 广告域名列表
  var adDomains = [
    'adwangmai.com',
    'ibroadlink.com',
    'gdt.qq.com',
    'csjplatform.com',
    'pangle.cn',
    'admob.com',
    'googleadservices.com',
    'googlesyndication.com',
    'inmobi.com',
    'unityads.unity3d.com',
    'baidumobad.com',
    'mobads.baidu.com',
    'juhuiad.com',
    'jutuiad.com',
    'madx.com',
    'madx.cn',
    'menta.com',
    'menta.cn'
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

  // 返回空响应
  if (url.indexOf('.json') !== -1 || url.indexOf('config') !== -1) {
    // JSON 配置请求返回空对象
    $done({ status: 200, body: '{}' });
  } else if (url.indexOf('.xml') !== -1) {
    // XML 请求返回空
