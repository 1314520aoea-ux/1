#!name=喜马拉雅 去广告
#!desc=拦截开屏广告、横幅广告、日志上报等
[rewrite_local]
^https?://adse\.wsa\.ximalaya\.com url reject
^https?://adse\.ximalaya\.com url reject
^https?://ad\.ximalaya\.com url reject
^https?://.+ximalaya\.com/focus-mobile/focusPic/ url reject
^https?://.+ximalaya\.com/business-sale-promotion-guide-mobile-web/popup/ url reject
^https?://.+ximalaya\.com/product/promotion/v1/album/price url reject-200
^https?://passport\.ximalaya\.com/friendship-mobile/v1/findFriendsBanner/show/ url reject
^https?://xdcs-collector\.ximalaya\.com/api/v1/realtime url reject
^https?://ulogs\.umeng\.com/unify_logs url reject
[mitm]
hostname = *.ximalaya.com, *.xmcdn.com, *.umeng.com
