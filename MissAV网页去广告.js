
description: 净化网页
dns: {}
scriptings:
- http_response:
    name: missav.ads
    match: ^https?:\/\/missav\.(ws|live|com|ai)\/(?!(.*(api|login|cdn-cgi|verify|auth|captch|(\.(js|css|jpg|jpeg|png|webp|gif|zip|woff|woff2|m3u8|mp4|mov|m4v|avi|mkv|flv|rmvb|wmv|rm|asf|asx|mp3|json|ico|otf|ttf)))))
    script_url: https://ddgksf2013.top/scripts/missav.ads.js
    max_size: -1
    timeout: 60
    body_required: true
mitm:
  hostnames:
    includes:
    - missav.live
    - missav.ws
    - missav.ai
    - missav.com
