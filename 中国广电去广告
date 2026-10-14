name: 中国广电去广告@ddgksf2013
description: 全面净化
dns: {}
body_rewrites:
- response_jq:
    match: ^https?:\/\/app\.10099\.com\.cn\/contact-web\/api\/content\/qryPosterStand
    filter: .data |= map(select(.posterStandName | test("中部业务菜单|导航栏|我的-特色|个人中心|客服")))
- response_jq:
    match: ^https?:\/\/app\.10099\.com\.cn\/contact-web\/api/content\/qryNavigationMenuList
    filter: .data[]?.children |= map(select(.catalogName!="视听"))
map_locals:
- match: ^https?:\/\/app\.10099\.com\.cn\/contact-web\/api\/version\/getFlashScreenPage
  status_code: 200
  body: ' '
mitm:
  hostnames:
    includes:
    - app.10099.com.cn
