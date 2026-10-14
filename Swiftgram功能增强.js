name: Swiftgram功能增强
description: TG外链接跳转Swiftgram
author: ddgksf2013
dns: {}
url_rewrites:
- match: ^https?:\/\/t.me\/(.+)
  location: sg://resolve?domain=$1
  status_code: 307
mitm:
  hostnames:
    includes:
    - t.me
