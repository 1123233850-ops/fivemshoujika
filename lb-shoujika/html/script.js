// ============================================
// 全局变量
// ============================================
let currentMenu = null;
let myNumbers = [];
let packages = [];
let currentPackage = null;
let currentNumber = null;
let rechargePhoneNumber = null;
let rechargeMethod = null;
let rechargeConfig = null;

// ============================================
// 工具函数
// ============================================
function $(selector) {
    return document.querySelector(selector);
}

function $$(selector) {
    return document.querySelectorAll(selector);
}

function setHTML(element, html) {
    if (typeof element === 'string') {
        element = $(element);
    }
    if (element) {
        element.innerHTML = html;
    }
}

function getHTML(element) {
    if (typeof element === 'string') {
        element = $(element);
    }
    return element ? element.innerHTML : '';
}

// ============================================
// NUI 回调通用函数
// ============================================
function nuiCallback(name, data, callback) {
    fetch(`https://lb-shoujika/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data || {})
    })
    .then(resp => resp.json())
    .then(data => {
        if (callback) callback(data);
    })
    .catch(err => {
        console.error(`Error in NUI callback ${name}:`, err);
        if (callback) callback({ success: false, error: err.message });
    });
}

// ============================================
// 初始化
// ============================================
document.addEventListener('DOMContentLoaded', function() {
    // 监听来自 Lua 的消息
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'openMenu') {
            openMenu();
        } else if (data.action === 'closeMenu') {
            closeMenu();
        } else if (data.action === 'updateMyNumbers') {
            myNumbers = data.numbers || [];
            updateNumbersCount();
        } else if (data.action === 'updatePackages') {
            packages = data.packages || [];
        } else if (data.action === 'updateRechargeConfig') {
            rechargeConfig = data.config || null;
        }
    });
    
    // ESC 键关闭菜单
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape' || event.keyCode === 27) {
            event.preventDefault();
            closeMenu();
        }
    });
    
    // 确保菜单默认隐藏
    $$('.menu-panel').forEach(panel => {
        panel.classList.remove('active');
    });
});

// ============================================
// 菜单导航
// ============================================
function showMenu(menuId) {
    $$('.menu-panel').forEach(panel => {
        panel.classList.remove('active');
    });
    const panel = $('#' + menuId);
    if (panel) {
        panel.classList.add('active');
    }
    currentMenu = menuId;
}

function showMainMenu() {
    showMenu('mainMenu');
    loadMainMenu();
}

function closeMenu() {
    // 隐藏 body
    document.body.classList.remove('show-menu');
    $$('.menu-panel').forEach(panel => {
        panel.classList.remove('active');
    });
    currentMenu = null;
    nuiCallback('closeMenu', {}, function() {});
}

function openMenu() {
    // 显示 body
    document.body.classList.add('show-menu');
    showMenu('mainMenu');
    loadMainMenu();
}

// ============================================
// 主菜单
// ============================================
function loadMainMenu() {
    nuiCallback('getMyNumbers', {}, function(data) {
        if (data.success) {
            myNumbers = data.numbers || [];
            updateNumbersCount();
            
            const rechargeCard = $('#rechargeCard');
            if (rechargeCard) {
                rechargeCard.style.display = myNumbers.length > 0 ? 'block' : 'none';
            }
        }
    });
}

function updateNumbersCount() {
    const count = myNumbers.length;
    const numbersCountEl = $('#numbersCount');
    if (numbersCountEl) {
        numbersCountEl.textContent = count === 0 ? '暂无手机号' : `拥有 ${count} 个手机号`;
    }
}

function showMyNumbers() {
    showMenu('myNumbersMenu');
    loadMyNumbers();
}

function showPurchaseMenu() {
    showMenu('purchaseMenu');
    loadPackages();
}

function showRechargeMenu() {
    showMenu('rechargeMenu');
    loadRechargeNumbers();
}

// ============================================
// 我的手机号列表
// ============================================
function loadMyNumbers() {
    setHTML('#numbersList', '<div class="loading">加载中...</div>');
    
    nuiCallback('getMyNumbers', {}, function(data) {
        if (data.success) {
            myNumbers = data.numbers || [];
            renderNumbersList();
        } else {
            setHTML('#numbersList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function renderNumbersList() {
    if (myNumbers.length === 0) {
        setHTML('#numbersList', '<div class="empty-state"><i class="fas fa-mobile-screen-button"></i><div class="empty-state-text">您还没有手机号</div></div>');
        return;
    }
    
    let html = '';
    myNumbers.forEach(function(number) {
        const statusClass = getStatusClass(number.status);
        const statusText = getStatusText(number.status);
        
        html += `
            <div class="list-item" onclick="showNumberDetail('${number.phone_number}')">
                <div class="list-item-header">
                    <div class="list-item-title">${number.phone_number}</div>
                    <div class="list-item-badge ${statusClass}">${statusText}</div>
                </div>
                <div class="list-item-info">
                    <span><i class="fas fa-wallet"></i> 余额: $${number.balance}</span>
                    <span><i class="fas fa-box"></i> ${number.package_name || '未知套餐'}</span>
                </div>
            </div>
        `;
    });
    
    setHTML('#numbersList', html);
}

function getStatusClass(status) {
    const statusMap = {
        'active': 'badge-active',
        'inactive': 'badge-inactive',
        'suspended': 'badge-suspended',
        'expired': 'badge-expired'
    };
    return statusMap[status] || 'badge-inactive';
}

function getStatusText(status) {
    const statusMap = {
        'active': '已激活',
        'inactive': '未激活',
        'suspended': '已暂停',
        'expired': '已过期'
    };
    return statusMap[status] || '未知';
}

// ============================================
// 手机号详情
// ============================================
function showNumberDetail(phoneNumber) {
    currentNumber = phoneNumber;
    showMenu('numberDetailMenu');
    loadNumberDetail(phoneNumber);
}

function loadNumberDetail(phoneNumber) {
    setHTML('#numberDetail', '<div class="loading">加载中...</div>');
    
    nuiCallback('getNumberDetail', { phoneNumber: phoneNumber }, function(data) {
        if (data.success) {
            renderNumberDetail(data.number);
        } else {
            setHTML('#numberDetail', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function renderNumberDetail(number) {
    const statusClass = getStatusClass(number.status);
    const statusText = getStatusText(number.status);
    
    let html = `
        <div class="detail-card">
            <div class="detail-card-title"><i class="fas fa-info-circle"></i> 基本信息</div>
            <div class="detail-info">
                <div class="detail-info-item">
                    <div class="detail-info-label">手机号</div>
                    <div class="detail-info-value">${number.phone_number}</div>
                </div>
                <div class="detail-info-item">
                    <div class="detail-info-label">状态</div>
                    <div class="detail-info-value"><span class="list-item-badge ${statusClass}">${statusText}</span></div>
                </div>
                <div class="detail-info-item">
                    <div class="detail-info-label">余额</div>
                    <div class="detail-info-value">$${number.balance}</div>
                </div>
                <div class="detail-info-item">
                    <div class="detail-info-label">套餐</div>
                    <div class="detail-info-value">${number.package_name || '未知'}</div>
                </div>
                <div class="detail-info-item">
                    <div class="detail-info-label">周租</div>
                    <div class="detail-info-value">$${number.weekly_fee || 0}</div>
                </div>
                <div class="detail-info-item">
                    <div class="detail-info-label">信用评分</div>
                    <div class="detail-info-value">${number.credit_score || 100}</div>
                </div>
            </div>
        </div>
        
        <div class="detail-card">
            <div class="detail-card-title"><i class="fas fa-cog"></i> 操作</div>
            <div class="detail-actions">
    `;
    
    if (number.status === 'inactive') {
        html += `<button class="btn-primary" onclick="activateNumber('${number.phone_number}')"><i class="fas fa-power-off"></i> 激活手机号</button>`;
    }
    
    html += `
                <button class="btn-secondary" onclick="showRechargeHistory('${number.phone_number}')"><i class="fas fa-history"></i> 充值记录</button>
                <button class="btn-secondary" onclick="showChargeHistory('${number.phone_number}')"><i class="fas fa-receipt"></i> 消费记录</button>
                <button class="btn-danger" onclick="deleteNumber('${number.phone_number}')"><i class="fas fa-trash"></i> 删除手机号</button>
            </div>
        </div>
    `;
    
    setHTML('#numberDetail', html);
}

function activateNumber(phoneNumber) {
    if (!confirm('确认激活此手机号？')) return;
    
    nuiCallback('activateNumber', { phoneNumber: phoneNumber }, function(data) {
        if (data.success) {
            alert('激活成功！');
            loadNumberDetail(phoneNumber);
        } else {
            alert('激活失败: ' + (data.message || '未知错误'));
        }
    });
}

function deleteNumber(phoneNumber) {
    const confirmPhone = prompt('请输入手机号以确认删除: ' + phoneNumber);
    if (confirmPhone !== phoneNumber) {
        alert('手机号不匹配，删除已取消');
        return;
    }
    
    if (!confirm('确认删除此手机号？此操作不可恢复！')) return;
    
    nuiCallback('deleteNumber', { phoneNumber: phoneNumber }, function(data) {
        if (data.success) {
            alert('删除成功！');
            showMyNumbers();
        } else {
            alert('删除失败: ' + (data.message || '未知错误'));
        }
    });
}

function showRechargeHistory(phoneNumber) {
    currentNumber = phoneNumber;
    const historyTitle = $('#historyTitle');
    if (historyTitle) historyTitle.textContent = '充值记录';
    showMenu('historyMenu');
    loadRechargeHistory(phoneNumber);
}

function showChargeHistory(phoneNumber) {
    currentNumber = phoneNumber;
    const historyTitle = $('#historyTitle');
    if (historyTitle) historyTitle.textContent = '消费记录';
    showMenu('historyMenu');
    loadChargeHistory(phoneNumber);
}

function loadRechargeHistory(phoneNumber) {
    setHTML('#historyList', '<div class="loading">加载中...</div>');
    
    nuiCallback('getRechargeHistory', { phoneNumber: phoneNumber }, function(data) {
        if (data.success) {
            renderHistory(data.history, 'recharge');
        } else {
            setHTML('#historyList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function loadChargeHistory(phoneNumber) {
    setHTML('#historyList', '<div class="loading">加载中...</div>');
    
    nuiCallback('getChargeHistory', { phoneNumber: phoneNumber }, function(data) {
        if (data.success) {
            renderHistory(data.history, 'charge');
        } else {
            setHTML('#historyList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function renderHistory(history, type) {
    if (!history || history.length === 0) {
        setHTML('#historyList', '<div class="empty-state"><i class="fas fa-history"></i><div class="empty-state-text">暂无记录</div></div>');
        return;
    }
    
    let html = '';
    history.forEach(function(item) {
        const amount = type === 'recharge' ? item.amount : -item.amount;
        const amountClass = amount > 0 ? 'amount-positive' : 'amount-negative';
        const typeIcon = type === 'recharge' ? 'fa-arrow-down' : 'fa-arrow-up';
        const typeText = type === 'recharge' ? '充值' : getChargeTypeText(item.type);
        
        html += `
            <div class="history-item">
                <div class="history-item-header">
                    <div class="history-item-type">
                        <i class="fas ${typeIcon}"></i> ${typeText}
                    </div>
                    <div class="history-item-amount ${amountClass}">${amount > 0 ? '+' : ''}$${Math.abs(amount)}</div>
                </div>
                <div class="history-item-info">
                    <span>${item.method || item.type || '未知'}</span>
                    <span>${formatDate(item.created_at)}</span>
                </div>
            </div>
        `;
    });
    
    setHTML('#historyList', html);
}

function getChargeTypeText(type) {
    const typeMap = {
        'call': '通话',
        'sms': '短信',
        'data': '流量',
        'weekly_fee': '周租',
        'monthly_fee': '月租'
    };
    return typeMap[type] || type || '其他';
}

function formatDate(dateString) {
    if (!dateString) return '未知时间';
    const date = new Date(dateString);
    return date.toLocaleString('zh-CN');
}

// ============================================
// 购买菜单
// ============================================
function loadPackages() {
    setHTML('#packagesList', '<div class="loading">加载中...</div>');
    
    nuiCallback('getPackages', {}, function(data) {
        if (data.success) {
            packages = data.packages || [];
            renderPackages();
        } else {
            setHTML('#packagesList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function renderPackages() {
    if (packages.length === 0) {
        setHTML('#packagesList', '<div class="empty-state"><i class="fas fa-box"></i><div class="empty-state-text">暂无可用套餐</div></div>');
        return;
    }
    
    let html = '';
    packages.forEach(function(pkg) {
        html += `
            <div class="list-item" onclick="showPackageOptions(${pkg.id})">
                <div class="list-item-header">
                    <div class="list-item-title">${pkg.name}</div>
                    <div class="list-item-badge badge-active">$${pkg.price}</div>
                </div>
                <div class="list-item-info">
                    <span><i class="fas fa-wallet"></i> 初始余额: $${pkg.initial_balance}</span>
                    <span><i class="fas fa-calendar-week"></i> 周租: $${pkg.weekly_fee || 0}</span>
                </div>
                ${pkg.description ? `<div style="margin-top: 10px; color: rgba(255,255,255,0.7); font-size: 14px;">${pkg.description}</div>` : ''}
            </div>
        `;
    });
    
    setHTML('#packagesList', html);
}

function showPackageOptions(packageId) {
    currentPackage = packages.find(p => p.id === packageId);
    if (!currentPackage) return;
    
    showMenu('packageOptionsMenu');
    renderPackageOptions();
}

function renderPackageOptions() {
    let html = `
        <div class="option-card" onclick="purchaseRandomNumber()">
            <div class="option-header">
                <div class="option-icon"><i class="fas fa-shuffle"></i></div>
                <div class="option-title">随机号码</div>
            </div>
            <div class="option-description">
                系统将随机生成一个手机号码，价格为基础套餐价格。
            </div>
            <div class="option-price">
                <span class="price-label">价格</span>
                <span class="price-value">$${currentPackage.price}</span>
            </div>
        </div>
    `;
    
    html += `
        <div class="option-card premium" onclick="showPremiumNumbers()">
            <div class="option-header">
                <div class="option-icon premium"><i class="fas fa-star"></i></div>
                <div class="option-title">选择靓号</div>
                <div class="option-badge">✨ 靓号</div>
            </div>
            <div class="option-description">
                从系统生成的靓号列表中选择您喜欢的号码。靓号价格会根据号码类型自动调整。
            </div>
            <div class="option-price">
                <span class="price-label">起价</span>
                <span class="price-value">$${currentPackage.price}</span>
                <span class="price-multiplier">× 倍数</span>
            </div>
        </div>
    `;
    
    setHTML('#packageOptions', html);
}

function purchaseRandomNumber() {
    if (!confirm(`确认购买套餐 "${currentPackage.name}" 的随机号码？\n价格: $${currentPackage.price}`)) return;
    
    nuiCallback('purchaseNumber', {
        packageId: currentPackage.id,
        phoneNumber: null
    }, function(data) {
        if (data.success) {
            alert('购买成功！\n您的手机号: ' + data.phoneNumber);
            closeMenu();
        } else {
            alert('购买失败: ' + (data.message || '未知错误'));
        }
    });
}

function showPremiumNumbers() {
    showMenu('premiumNumbersMenu');
    loadPremiumNumbers();
}

let premiumNumbersList = [];

function loadPremiumNumbers() {
    setHTML('#premiumNumbersList', '<div class="loading">正在生成靓号列表...</div>');
    
    nuiCallback('getPremiumNumbers', {
        packageId: currentPackage.id,
        count: 10
    }, function(data) {
        if (data.success) {
            renderPremiumNumbers(data.numbers);
        } else {
            setHTML('#premiumNumbersList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">生成失败: ' + (data.message || '未知错误') + '</div></div>');
        }
    });
}

function renderPremiumNumbers(numbers) {
    premiumNumbersList = numbers || [];
    
    if (premiumNumbersList.length === 0) {
        setHTML('#premiumNumbersList', '<div class="empty-state"><i class="fas fa-star"></i><div class="empty-state-text">暂无可用的靓号，请稍后再试或选择随机号码</div></div>');
        return;
    }
    
    let html = `
        <div class="list-item" onclick="purchaseRandomNumber()" style="margin-bottom: 20px;">
            <div class="list-item-header">
                <div class="list-item-title"><i class="fas fa-shuffle"></i> 随机号码</div>
                <div class="list-item-badge badge-active">$${currentPackage.price}</div>
            </div>
            <div class="list-item-info">
                <span>让系统随机生成号码</span>
            </div>
        </div>
    `;
    
    premiumNumbersList.forEach(function(number) {
        html += `
            <div class="list-item premium" onclick="purchasePremiumNumber('${number.phone_number}')">
                <div class="list-item-header">
                    <div class="list-item-title"><i class="fas fa-star"></i> ${number.phone_number}</div>
                    <div class="list-item-badge" style="background: rgba(255, 193, 7, 0.3); color: #FFC107; border-color: rgba(255, 193, 7, 0.5);">${number.premium_type}</div>
                </div>
                <div class="list-item-info">
                    <span><i class="fas fa-tag"></i> ${number.premium_type}</span>
                    <span><i class="fas fa-times"></i> ${number.price_multiplier}x</span>
                    <span><i class="fas fa-dollar-sign"></i> $${number.final_price}</span>
                </div>
            </div>
        `;
    });
    
    setHTML('#premiumNumbersList', html);
}

function purchasePremiumNumber(phoneNumber) {
    const premiumNumber = premiumNumbersList.find(n => n.phone_number === phoneNumber);
    if (!premiumNumber) return;
    
    if (!confirm(`确认购买靓号 "${phoneNumber}"？\n类型: ${premiumNumber.premium_type}\n价格倍数: ${premiumNumber.price_multiplier}x\n最终价格: $${premiumNumber.final_price}`)) return;
    
    nuiCallback('purchaseNumber', {
        packageId: currentPackage.id,
        phoneNumber: phoneNumber
    }, function(data) {
        if (data.success) {
            alert('购买成功！\n您的手机号: ' + data.phoneNumber);
            closeMenu();
        } else {
            alert('购买失败: ' + (data.message || '未知错误'));
        }
    });
}

// ============================================
// 充值菜单
// ============================================
function loadRechargeNumbers() {
    setHTML('#rechargeNumbersList', '<div class="loading">加载中...</div>');
    
    nuiCallback('getMyNumbers', {}, function(data) {
        if (data.success) {
            myNumbers = data.numbers || [];
            renderRechargeNumbers();
        } else {
            setHTML('#rechargeNumbersList', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">加载失败</div></div>');
        }
    });
}

function renderRechargeNumbers() {
    if (myNumbers.length === 0) {
        setHTML('#rechargeNumbersList', '<div class="empty-state"><i class="fas fa-mobile-screen-button"></i><div class="empty-state-text">您还没有手机号</div></div>');
        return;
    }
    
    let html = '';
    myNumbers.forEach(function(number) {
        html += `
            <div class="list-item" onclick="showRechargeMethodMenu('${number.phone_number}')">
                <div class="list-item-header">
                    <div class="list-item-title">${number.phone_number}</div>
                    <div class="list-item-badge badge-active">余额: $${number.balance}</div>
                </div>
                <div class="list-item-info">
                    <span><i class="fas fa-box"></i> ${number.package_name || '未知套餐'}</span>
                </div>
            </div>
        `;
    });
    
    setHTML('#rechargeNumbersList', html);
}

function showRechargeMethodMenu(phoneNumber) {
    rechargePhoneNumber = phoneNumber;
    showMenu('rechargeMethodMenu');
    loadRechargeMethods();
}

function loadRechargeMethods() {
    nuiCallback('getRechargeConfig', {}, function(data) {
        if (data.success) {
            rechargeConfig = data.config;
            renderRechargeMethods();
        }
    });
}

function renderRechargeMethods() {
    if (!rechargeConfig) {
        setHTML('#rechargeMethods', '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">无法加载充值配置</div></div>');
        return;
    }
    
    let html = '';
    const methods = rechargeConfig.methods || {};
    
    if (methods.cash) {
        html += `
            <div class="option-card" onclick="showRechargeAmount('cash')">
                <div class="option-header">
                    <div class="option-icon"><i class="fas fa-money-bill"></i></div>
                    <div class="option-title">现金</div>
                </div>
                <div class="option-description">使用现金充值</div>
            </div>
        `;
    }
    
    if (methods.bank) {
        html += `
            <div class="option-card" onclick="showRechargeAmount('bank')">
                <div class="option-header">
                    <div class="option-icon"><i class="fas fa-university"></i></div>
                    <div class="option-title">银行</div>
                </div>
                <div class="option-description">使用银行账户充值</div>
            </div>
        `;
    }
    
    if (methods.card) {
        html += `
            <div class="option-card" onclick="showRechargeAmount('card')">
                <div class="option-header">
                    <div class="option-icon"><i class="fas fa-credit-card"></i></div>
                    <div class="option-title">银行卡</div>
                </div>
                <div class="option-description">使用银行卡充值</div>
            </div>
        `;
    }
    
    if (html === '') {
        html = '<div class="empty-state"><i class="fas fa-exclamation-circle"></i><div class="empty-state-text">暂无可用的充值方式</div></div>';
    }
    
    setHTML('#rechargeMethods', html);
}

function showRechargeAmount(method) {
    rechargeMethod = method;
    showMenu('rechargeAmountMenu');
    
    if (rechargeConfig) {
        const minAmountEl = $('#minAmount');
        const maxAmountEl = $('#maxAmount');
        const rechargeAmountEl = $('#rechargeAmount');
        if (minAmountEl) minAmountEl.textContent = rechargeConfig.minAmount || 1;
        if (maxAmountEl) maxAmountEl.textContent = rechargeConfig.maxAmount || 10000;
        if (rechargeAmountEl) {
            rechargeAmountEl.setAttribute('min', rechargeConfig.minAmount || 1);
            rechargeAmountEl.setAttribute('max', rechargeConfig.maxAmount || 10000);
            rechargeAmountEl.value = '';
        }
    }
}

function confirmRecharge() {
    const rechargeAmountEl = $('#rechargeAmount');
    if (!rechargeAmountEl) return;
    
    const amount = parseInt(rechargeAmountEl.value);
    
    if (!amount || amount < 1) {
        alert('请输入有效的充值金额');
        return;
    }
    
    if (rechargeConfig) {
        if (amount < (rechargeConfig.minAmount || 1)) {
            alert('充值金额不能小于 $' + rechargeConfig.minAmount);
            return;
        }
        if (amount > (rechargeConfig.maxAmount || 10000)) {
            alert('充值金额不能大于 $' + rechargeConfig.maxAmount);
            return;
        }
    }
    
    if (!confirm(`确认使用 ${getRechargeMethodText(rechargeMethod)} 为 ${rechargePhoneNumber} 充值 $${amount}？`)) return;
    
    nuiCallback('recharge', {
        phoneNumber: rechargePhoneNumber,
        method: rechargeMethod,
        amount: amount
    }, function(data) {
        if (data.success) {
            alert('充值成功！\n当前余额: $' + data.balance);
            closeMenu();
        } else {
            alert('充值失败: ' + (data.message || '未知错误'));
        }
    });
}

function getRechargeMethodText(method) {
    const methodMap = {
        'cash': '现金',
        'bank': '银行',
        'card': '银行卡'
    };
    return methodMap[method] || method;
}

function showPackageOptions() {
    if (currentPackage) {
        showMenu('packageOptionsMenu');
        renderPackageOptions();
    } else {
        showPurchaseMenu();
    }
}

function showNumberDetail() {
    if (currentNumber) {
        showNumberDetail(currentNumber);
    } else {
        showMyNumbers();
    }
}

function showRechargeMethodMenu() {
    showRechargeMenu();
}
