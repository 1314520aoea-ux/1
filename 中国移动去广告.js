name: 中国移动去广告
description: 应用净化
dns: {}
map_locals:
- match: ^https?:\/\/h\.app\.coc\.10086\.cn\/biz-orange\/DH\/popupWindow\/getDetail
  status_code: 200
  body: ' '
scriptings:
- http_response:
    name: NoAds
    match: ^https?:\/\/client\.app\.coc\.10086\.cn\/biz-orange\/DN\/init\/startInit$
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
- http_response:
    name: NoAds
    match: ^https?:\/\/client\.app\.coc\.10086\.cn\/biz-orange\/DN\/newTopPullSecond\/getNewTopPullList
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
- http_response:
    name: NoAds
    match: ^https?:\/\/client\.app\.coc\.10086\.cn\/biz-orange\/DN\/emotionMarket\/getEmotionMarketNew
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
- http_response:
    name: NoAds
    match: ^https?:\/\/h\.app\.coc\.10086\.cn\/biz-orange\/DH\/homeArea\/getTopAreaList
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
- http_response:
    name: NoAds
    match: ^https?:\/\/h\.app\.coc\.10086\.cn\/biz-orange\/DH\/navigation\/getNavigationNewInfo
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
- http_response:
    name: NoAds
    match: ^https?:\/\/client\.app\.coc\.10086\.cn\/biz-orange\/DN\/friendShake\/getShakeList
    script_url: https://raw.githubusercontent.com/Yuheng0101/X/main/Scripts/ChinaMobile/NoAds.js
    max_size: -1
    timeout: 60
    body_required: true
mitm:
  hostnames:
    includes:
    - client.app.coc.10086.cn
    - h.app.coc.10086.cn
