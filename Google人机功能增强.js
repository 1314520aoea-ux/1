name: Google人机功能增强
description: 解决Google搜索人机验证
dns: {}
scriptings:
- http_response:
    name: Google_CAPTCHA
    match: ^https:\/\/www\.google\.com(?:\.[a-z]+|)\/(?:search\?(?:|.+?&)q=|$)
    script_url: https://raw.githubusercontent.com/NobyDa/Script/master/Surge/JS/Google_CAPTCHA.js
    max_size: -1
    timeout: 60
    body_required: true
mitm:
  hostnames:
    includes:
    - www.google.com*
