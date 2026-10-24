// Cloudflare Worker - PinToIsland IAP Mock Server
// 部署到 https://workers.cloudflare.com

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // 会员状态查询
    if (path === '/get_membership' || path.includes('get_membership.php')) {
      return new JSONResponse({
        code: 0,
        data: {
          is_member: true,
          is_lifetime: true,
          tier: "lifetime",
          expiration_date: null,
          source: "storekit",
          display_name: "永久会员"
        }
      });
    }

    // 购买同步
    if (path === '/sync_purchase' || path.includes('sync_purchase.php')) {
      return new JSONResponse({
        code: 0,
        success: true,
        data: {
          is_member: true,
          is_lifetime: true,
          tier: "lifetime",
          expiration_date: null,
          source: "storekit",
          display_name: "永久会员"
        }
      });
    }

    // 订单恢复
    if (path === '/order_recovery' || path.includes('storekit_order_recovery.php')) {
      return new JSONResponse({
        code: 0,
        success: true,
        data: {
          is_member: true,
          is_lifetime: true,
          tier: "lifetime",
          expiration_date: null,
          source: "storekit",
          display_name: "永久会员"
        }
      });
    }

    // StoreKit 迁移
    if (path === '/migration' || path.includes('storekit_migration_request.php')) {
      return new JSONResponse({
        code: 0,
        success: true,
        data: {
          is_member: true,
          is_lifetime: true,
          tier: "lifetime",
          expiration_date: null,
          source: "storekit",
          display_name: "永久会员"
        }
      });
    }

    // 定价配置
    if (path === '/pricing' || path.includes('pricing.php')) {
      return new JSONResponse({
        lifetimePricing: {
          isActive: true,
          showsCountdown: false,
          badge: "已解锁"
        },
        earlyBird: {
          disabledForever: true
        }
      });
    }

    // 默认响应
    return new JSONResponse({ error: "Not found" }, { status: 404 });
  }
};

class JSONResponse extends Response {
  constructor(data, init = {}) {
    super(JSON.stringify(data), {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...init.headers
      }
    });
  }
