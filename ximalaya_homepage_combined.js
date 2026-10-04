/*
#!name=喜马拉雅 homePage 诊断
#!desc=记录 homePage 响应结构，帮助分析 VIP 字段
[rewrite_local]
^https?:\/\/.+((ximalaya)|(xmcdn)).+mobile-user\/v2\/homePage url script-response-body https://raw.githubusercontent.com/1314520aoea-ux/1/refs/heads/main/ximalaya_homepage.js
[mitm]
hostname = *.ximalaya.com, *.xmcdn.com
*/

(function() {
    const url = $request.url;
    const isHomePage = /mobile-user\/v2\/homePage/.test(url);
    
    if (!$response || !$response.body) {
        $done({});
        return;
    }
    
    let body;
    try {
        body = JSON.parse($response.body);
    } catch (e) {
        $done({});
        return;
    }
    
    if (isHomePage) {
        const topLevelKeys = Object.keys(body);
        $notification.post('喜马拉雅 homePage 结构', '顶层字段', topLevelKeys.join(', '));
        
        function findUserFields(obj, path, results) {
            if (!obj || typeof obj !== 'object') return;
            if (results.length > 30) return;
            
            for (const key of Object.keys(obj)) {
                const lower = key.toLowerCase();
                const currentPath = path ? path + '.' + key : key;
                
                if (lower.includes('avatar') || lower.includes('nickname') || 
                    lower.includes('username') || lower.includes('uid') ||
                    lower.includes('vip') || lower.includes('member') ||
                    lower.includes('isvip') || lower.includes('is_vip')) {
                    results.push({
                        path: currentPath,
                        value: typeof obj[key] === 'object' ? JSON.stringify(obj[key]).substring(0, 80) : String(obj[key]).substring(0, 80)
                    });
                }
                
                if (typeof obj[key] === 'object' && obj[key] !== null) {
                    findUserFields(obj[key], currentPath, results);
                }
            }
        }
        
        const userFields = [];
        findUserFields(body, '', userFields);
        
        if (userFields.length > 0) {
            const summary = userFields.slice(0, 15).map(f => f.path + '=' + f.value).join('\n');
            $notification.post('喜马拉雅 用户字段', '找到 ' + userFields.length + ' 个', summary);
        }
        
        const vipFields = [
            'isVip', 'isVIP', 'is_vip', 'vipStatus', 'vip_status',
            'memberStatus', 'member_status', 'hasVip', 'has_vip'
        ];
        vipFields.forEach(f => {
            if (body[f] !== undefined) body[f] = true;
        });
        
        function setVipInObject(obj) {
            if (!obj || typeof obj !== 'object') return;
            vipFields.forEach(f => {
                if (obj[f] !== undefined) obj[f] = true;
            });
            Object.values(obj).forEach(v => {
                if (typeof v === 'object' && v !== null) setVipInObject(v);
            });
        }
        setVipInObject(body);
        
        $done({ body: JSON.stringify(body) });
    } else {
        $done({});
    }
})();
