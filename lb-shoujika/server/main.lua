-- ============================================
-- LB手机运营商系统 - 服务器端
-- ============================================

ESX = exports['es_extended']:getSharedObject()

-- ============================================
-- 日志系统
-- ============================================
local LogLevels = {
    debug = 1,
    info = 2,
    warning = 3,
    error = 4
}

local function GetLogLevel()
    if not Config or not Config.Logging then return LogLevels.info end
    return LogLevels[Config.Logging.Level] or LogLevels.info
end

local function ShouldLog(level)
    if not Config or not Config.Logging then return true end -- 如果配置未加载，默认启用日志
    if not Config.Logging.Enabled then return false end
    return LogLevels[level] >= GetLogLevel()
end

local function FormatTimestamp()
    if not Config or not Config.Logging or not Config.Logging.ShowTimestamp then return "" end
    local time = os.date("%Y-%m-%d %H:%M:%S")
    return string.format("[%s] ", time)
end

local function GetColorCode(level)
    if not Config or not Config.Logging or not Config.Logging.Console or not Config.Logging.Console.Colors then return "" end
    local colors = {
        debug = "^7",    -- 白色
        info = "^2",     -- 绿色
        warning = "^3",  -- 黄色
        error = "^1"     -- 红色
    }
    return colors[level] or ""
end

function Log(level, message, ...)
    if not ShouldLog(level) then return end
    
    local formattedMessage = string.format(message, ...)
    local prefix = FormatTimestamp()
    local sourceTag = (Config and Config.Logging and Config.Logging.ShowSource) and "[服务器] " or ""
    local colorCode = GetColorCode(level)
    local resetCode = (Config and Config.Logging and Config.Logging.Console and Config.Logging.Console.Colors) and "^7" or ""
    local fullMessage = string.format("%s%s%s[LB-SHOUJIKA] %s: %s%s", 
        colorCode, prefix, sourceTag, level:upper(), formattedMessage, resetCode)
    
    local consoleEnabled = true
    if Config and Config.Logging and Config.Logging.Console then
        consoleEnabled = Config.Logging.Console.Enabled ~= false
    end
    
    if consoleEnabled then
        print(fullMessage)
    end
end

-- 便捷函数
function LogDebug(message, ...)
    Log("debug", message, ...)
end

function LogInfo(message, ...)
    Log("info", message, ...)
end

function LogWarning(message, ...)
    Log("warning", message, ...)
end

function LogError(message, ...)
    Log("error", message, ...)
end

-- 接收客户端日志
RegisterNetEvent('lb-shoujika:log')
AddEventHandler('lb-shoujika:log', function(level, message)
    local sourceTag = string.format("[客户端-%d] ", source)
    local prefix = FormatTimestamp()
    local colorCode = GetColorCode(level)
    local resetCode = (Config and Config.Logging and Config.Logging.Console and Config.Logging.Console.Colors) and "^7" or ""
    local fullMessage = string.format("%s%s%s[LB-SHOUJIKA] %s: %s%s", 
        colorCode, prefix, sourceTag, level:upper(), message, resetCode)
    
    local consoleEnabled = true
    if Config and Config.Logging and Config.Logging.Console then
        consoleEnabled = Config.Logging.Console.Enabled ~= false
    end
    
    if consoleEnabled then
        print(fullMessage)
    end
end)

-- 接收客户端加载通知
RegisterNetEvent('lb-shoujika:clientLoaded')
AddEventHandler('lb-shoujika:clientLoaded', function()
    print("^2[LB-SHOUJIKA] 客户端脚本已加载 (玩家ID: " .. source .. ")^7")
end)

-- ============================================
-- 资源启动日志
-- ============================================
CreateThread(function()
    -- 立即输出启动信息（不依赖配置）
    print("^2============================================^7")
    print("^2[LB-SHOUJIKA] 服务器端脚本正在启动...^7")
    
    -- 检查ESX是否加载
    if not ESX then
        print("^1[LB-SHOUJIKA] 错误: ESX未加载！请确保es_extended资源已启动^7")
        return
    end
    
    Wait(3000) -- 等待资源完全加载，确保Config已加载
    
    -- 检查配置是否加载
    if not Config then
        print("^1[LB-SHOUJIKA] 错误: Config未加载！^7")
        print("^1[LB-SHOUJIKA] 请检查fxmanifest.lua中的shared_scripts配置^7")
        return
    end
    
    if not Config.Logging then
        print("^3[LB-SHOUJIKA] 警告: Config.Logging未找到，使用默认日志设置^7")
        -- 使用默认设置
        Config.Logging = {
            Enabled = true,
            Level = "info",
            ShowTimestamp = true,
            ShowSource = true,
            Console = { Enabled = true, Colors = true },
            F8 = { Enabled = true }
        }
    end
    
    -- 输出详细启动信息
    if Config.Logging.Enabled then
        LogInfo("============================================")
        LogInfo("LB手机运营商系统服务器端已启动")
        LogInfo("ESX框架: 已加载")
        LogInfo("日志系统: 已启用")
        LogInfo("日志级别: %s", Config.Logging.Level or "info")
        LogInfo("调试模式: %s", (Config.Debug and "开启" or "关闭"))
        LogInfo("时间戳: %s", (Config.Logging.ShowTimestamp and "开启" or "关闭"))
        LogInfo("颜色输出: %s", ((Config.Logging.Console and Config.Logging.Console.Colors) and "开启" or "关闭"))
        LogInfo("============================================")
        
        -- 测试日志输出
        LogInfo("测试日志: 这是一条测试信息")
        LogWarning("测试日志: 这是一条测试警告")
        LogError("测试日志: 这是一条测试错误")
    else
        print("^3[LB-SHOUJIKA] 警告: 日志系统未启用，请在config.lua中设置Config.Logging.Enabled = true^7")
    end
end)

-- ============================================
-- 语言函数
-- ============================================
function _U(key, ...)
    local locale = Config.Locale or 'zh-cn'
    if Locales[locale] and Locales[locale][key] then
        return string.format(Locales[locale][key], ...)
    elseif Locales['zh-cn'] and Locales['zh-cn'][key] then
        return string.format(Locales['zh-cn'][key], ...)
    else
        return key
    end
end

-- ============================================
-- 工具函数
-- ============================================

local function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        return xPlayer.identifier
    end
    return nil
end

-- 检查是否为管理员
local function IsAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    -- 检查管理员组
    for _, group in ipairs(Config.AdminGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end
    
    -- 检查管理员许可证
    if Config.AdminLicenses and #Config.AdminLicenses > 0 then
        local playerLicense = nil
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.find(identifier, "license:") then
                playerLicense = identifier
                break
            end
        end
        
        if playerLicense then
            for _, adminLicense in ipairs(Config.AdminLicenses) do
                if playerLicense == adminLicense then
                    return true
                end
            end
        end
    end
    
    return false
end

-- 检查是否为老板（可使用靓号管理功能）
local function IsBoss(source)
    if not Config.Boss or not Config.Boss.Enabled then
        return false
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    -- 检查老板组
    if Config.Boss.Groups then
        for _, group in ipairs(Config.Boss.Groups) do
            if xPlayer.getGroup() == group then
                return true
            end
        end
    end
    
    -- 检查老板许可证
    if Config.Boss.Licenses and #Config.Boss.Licenses > 0 then
        local playerLicense = nil
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.find(identifier, "license:") then
                playerLicense = identifier
                break
            end
        end
        
        if playerLicense then
            for _, bossLicense in ipairs(Config.Boss.Licenses) do
                if playerLicense == bossLicense then
                    return true
                end
            end
        end
    end
    
    return false
end

-- 更新信用评分
local function UpdateCreditScore(phoneNumber, change, reason)
    if not phoneNumber or not change then return end
    
    local numberData = MySQL.single.await(
        "SELECT credit_score, credit_limit FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    
    if not numberData then return end
    
    local currentScore = numberData.credit_score or Config.Credit.CreditScore.InitialScore
    local newScore = math.max(
        Config.Credit.CreditScore.MinScore,
        math.min(Config.Credit.CreditScore.MaxScore, currentScore + change)
    )
    
    local newCreditLimit = Config.Credit.CreditFormula(newScore)
    
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET credit_score = ?, credit_limit = ? WHERE phone_number = ?",
        { newScore, newCreditLimit, phoneNumber }
    )
    
    if Config.Debug then
        print(string.format("[LB-SHOUJIKA] 信用评分更新: %s, 变化: %d, 新评分: %d, 新额度: %d, 原因: %s",
            phoneNumber, change, newScore, newCreditLimit, reason or "未知"))
    end
    
    return newScore, newCreditLimit
end

-- 发送通知
local function Notify(source, title, message, type, duration)
    if not source or source == 0 then return end
    
    type = type or "info"
    duration = duration or Config.Notification.Duration
    
    -- 验证通知类型
    local validTypes = {
        ["info"] = true,
        ["success"] = true,
        ["error"] = true,
        ["warning"] = true
    }
    
    if not validTypes[type] then
        type = "info"
    end
    
    -- 根据配置的通知系统发送通知
    if Config.Notification.System == "okokNotify" then
        TriggerClientEvent('okokNotify:Alert', source, title, message, duration, type)
    elseif Config.Notification.System == "esx" then
        TriggerClientEvent('esx:showNotification', source, message)
    else
        -- 默认使用ESX通知
        TriggerClientEvent('esx:showNotification', source, message)
    end
end

-- 检测靓号并计算价格倍数
local function CheckPremiumNumber(phoneNumber)
    if not Config.PhoneNumber.PremiumNumbers.Enabled then
        return nil, 1.0
    end
    
    -- 提取号码主体（去除前缀）
    local body = phoneNumber
    
    -- 先检查配置的前缀列表
    if Config.PhoneNumber.Prefixes and #Config.PhoneNumber.Prefixes > 0 then
        for _, prefix in ipairs(Config.PhoneNumber.Prefixes) do
            if string.find(phoneNumber, "^" .. prefix, 1, true) then
                body = string.sub(phoneNumber, #prefix + 1)
                break
            end
        end
    end
    
    -- 如果前缀长度是3位，也尝试直接提取（如205, 907等）
    if #body == #phoneNumber and #phoneNumber > Config.PhoneNumber.Length then
        local possiblePrefix = string.sub(phoneNumber, 1, 3)
        if string.match(possiblePrefix, "^%d%d%d$") then
            body = string.sub(phoneNumber, 4)
        end
    end
    
    -- 检查所有靓号模式
    local bestMatch = nil
    local bestMultiplier = Config.PhoneNumber.PremiumNumbers.MinPriceMultiplier
    
    for _, pattern in ipairs(Config.PhoneNumber.PremiumNumbers.Patterns) do
        if string.match(body, pattern.pattern) then
            local multiplier = pattern.price_multiplier
            if multiplier > bestMultiplier then
                bestMultiplier = multiplier
                bestMatch = pattern
            end
        end
    end
    
    -- 如果没有匹配到任何模式，返回nil
    if not bestMatch then
        return nil, 1.0
    end
    
    -- 限制倍数范围
    bestMultiplier = math.max(Config.PhoneNumber.PremiumNumbers.MinPriceMultiplier, 
                             math.min(Config.PhoneNumber.PremiumNumbers.MaxPriceMultiplier, bestMultiplier))
    
    return bestMatch, bestMultiplier
end

local function GeneratePhoneNumber(prefix)
    local prefixes = Config.PhoneNumber.Prefixes
    local ok, number
    
    while not ok do
        local body = ""
        for _ = 1, Config.PhoneNumber.Length do
            body = body .. tostring(math.random(0, 9))
        end
        
        if prefix then
            number = prefix .. body
        elseif #prefixes > 0 then
            number = prefixes[math.random(1, #prefixes)] .. body
        else
            number = body
        end
        
        local exists = MySQL.scalar.await(
            "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
            { number }
        )
        ok = (exists == nil)
        if not ok then Wait(0) end
    end
    
    return number
end

-- ============================================
-- 生成特定模式的靓号
-- ============================================
local function GeneratePatternNumber(pattern, prefix)
    local body = ""
    local bodyLength = Config.PhoneNumber.Length or 7
    
    -- 根据模式生成号码
    if pattern.pattern == "^(%d)%1%1%1%1%1%1$" then
        -- 六连号：1111111（需要7位）
        if bodyLength >= 6 then
            local digit = math.random(0, 9)
            body = string.rep(tostring(digit), bodyLength)
        else
            -- 长度不足，随机生成
            for i = 1, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        end
    elseif pattern.pattern == "^(%d)%1%1%1%1%1" then
        -- 五连号：111112
        if bodyLength >= 5 then
            local digit = math.random(0, 9)
            local other = math.random(0, 9)
            while other == digit do other = math.random(0, 9) end
            body = string.rep(tostring(digit), bodyLength - 1) .. tostring(other)
        else
            for i = 1, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        end
    elseif pattern.pattern == "^(%d)%1%1%1%1" then
        -- 四连号：1111234
        if bodyLength >= 4 then
            local digit = math.random(0, 9)
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = string.rep(tostring(digit), 4) .. rest
        else
            for i = 1, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        end
    elseif pattern.pattern == "^(%d)%1%1%1" then
        -- 三连号：1112345
        if bodyLength >= 3 then
            local digit = math.random(0, 9)
            local rest = ""
            for i = 1, bodyLength - 3 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = string.rep(tostring(digit), 3) .. rest
        else
            for i = 1, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        end
    elseif pattern.pattern == "^1234567$" then
        -- 顺子号（固定7位）
        if bodyLength == 7 then
            body = "1234567"
        else
            -- 长度不是7位，生成对应长度的顺子
            body = ""
            for i = 1, bodyLength do
                body = body .. tostring((i - 1) % 10)
            end
        end
    elseif pattern.pattern == "^7654321$" then
        -- 倒顺号（固定7位）
        if bodyLength == 7 then
            body = "7654321"
        else
            body = ""
            for i = bodyLength, 1, -1 do
                body = body .. tostring((i - 1) % 10)
            end
        end
    elseif pattern.pattern == "^8888888$" then
        body = string.rep("8", bodyLength)
    elseif pattern.pattern == "^6666666$" then
        body = string.rep("6", bodyLength)
    elseif pattern.pattern == "^9999999$" then
        body = string.rep("9", bodyLength)
    elseif pattern.pattern == "^8888" then
        -- 四八号开头
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = "8888" .. rest
        else
            body = string.rep("8", bodyLength)
        end
    elseif pattern.pattern == "^6666" then
        -- 四六号开头
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = "6666" .. rest
        else
            body = string.rep("6", bodyLength)
        end
    elseif pattern.pattern == "^9999" then
        -- 四九号开头
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = "9999" .. rest
        else
            body = string.rep("9", bodyLength)
        end
    elseif pattern.pattern == "8888$" then
        -- 尾四八
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = rest .. "8888"
        else
            body = string.rep("8", bodyLength)
        end
    elseif pattern.pattern == "6666$" then
        -- 尾四六
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = rest .. "6666"
        else
            body = string.rep("6", bodyLength)
        end
    elseif pattern.pattern == "9999$" then
        -- 尾四九
        if bodyLength >= 4 then
            local rest = ""
            for i = 1, bodyLength - 4 do
                rest = rest .. tostring(math.random(0, 9))
            end
            body = rest .. "9999"
        else
            body = string.rep("9", bodyLength)
        end
    elseif pattern.pattern == "^(%d)%1(%d)%2(%d)%3" then
        -- 对子号：1122334（需要至少6位）
        if bodyLength >= 6 then
            local d1 = math.random(0, 9)
            local d2 = math.random(0, 9)
            local d3 = math.random(0, 9)
            while d2 == d1 do d2 = math.random(0, 9) end
            while d3 == d1 or d3 == d2 do d3 = math.random(0, 9) end
            body = tostring(d1) .. tostring(d1) .. tostring(d2) .. tostring(d2) .. tostring(d3) .. tostring(d3)
            for i = 7, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        else
            -- 长度不够，随机生成
            for i = 1, bodyLength do
                body = body .. tostring(math.random(0, 9))
            end
        end
    else
        -- 其他模式，随机生成
        for i = 1, bodyLength do
            body = body .. tostring(math.random(0, 9))
        end
    end
    
    -- 组合前缀
    local phoneNumber
    if prefix then
        phoneNumber = prefix .. body
    elseif Config.PhoneNumber.Prefixes and #Config.PhoneNumber.Prefixes > 0 then
        phoneNumber = Config.PhoneNumber.Prefixes[math.random(1, #Config.PhoneNumber.Prefixes)] .. body
    else
        phoneNumber = body
    end
    
    return phoneNumber
end

-- ============================================
-- 生成靓号列表
-- ============================================
local function GeneratePremiumNumbers(packageId, count)
    count = count or 10 -- 默认生成10个靓号
    
    if not Config.PhoneNumber.PremiumNumbers.Enabled then
        LogWarning("靓号系统未启用")
        return {}
    end
    
    local package = MySQL.single.await(
        "SELECT * FROM phone_operator_packages WHERE id = ? AND active = 1",
        { packageId }
    )
    
    if not package then
        LogWarning("套餐不存在或未激活: %d", packageId)
        return {}
    end
    
    local premiumNumbers = {}
    local seenNumbers = {} -- 用于去重
    local maxAttempts = count * 100 -- 增加尝试次数
    local attempts = 0
    
    -- 获取前缀
    local prefix = package.phone_number_prefix
    if not prefix and #Config.PhoneNumber.Prefixes > 0 then
        prefix = Config.PhoneNumber.Prefixes[1] -- 使用第一个前缀
    end
    
    -- 优先使用智能生成（针对特定模式）
    -- 按价格倍数从高到低排序，优先生成倍数高的靓号
    local sortedPatterns = {}
    for _, pattern in ipairs(Config.PhoneNumber.PremiumNumbers.Patterns) do
        table.insert(sortedPatterns, pattern)
    end
    table.sort(sortedPatterns, function(a, b)
        return (a.price_multiplier or 1) > (b.price_multiplier or 1)
    end)
    
    for _, pattern in ipairs(sortedPatterns) do
        if #premiumNumbers >= count then break end
        
        -- 为每个模式尝试生成1个号码
        local patternAttempts = 0
        local maxPatternAttempts = 5 -- 每个模式最多尝试5次
        
        while patternAttempts < maxPatternAttempts do
            patternAttempts = patternAttempts + 1
            attempts = attempts + 1
            
            local phoneNumber = GeneratePatternNumber(pattern, prefix)
            
            -- 检查是否已生成过
            if not seenNumbers[phoneNumber] then
                seenNumbers[phoneNumber] = true
                
                -- 检查号码是否已存在于数据库
                local exists = MySQL.scalar.await(
                    "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
                    { phoneNumber }
                )
                
                if not exists then
                    -- 验证是否为靓号
                    local premiumMatch, priceMultiplier = CheckPremiumNumber(phoneNumber)
                    if premiumMatch then
                        table.insert(premiumNumbers, {
                            phone_number = phoneNumber,
                            premium_type = premiumMatch.name,
                            price_multiplier = priceMultiplier,
                            base_price = package.price,
                            final_price = math.floor(package.price * priceMultiplier)
                        })
                        LogDebug("智能生成靓号: %s, 类型: %s, 倍数: %.2f", phoneNumber, premiumMatch.name, priceMultiplier)
                        break -- 成功生成一个，继续下一个模式
                    end
                end
            end
            
            Wait(0) -- 避免阻塞
        end
    end
    
    -- 如果还不够，继续随机生成
    while #premiumNumbers < count and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- 随机生成号码
        local body = ""
        for _ = 1, Config.PhoneNumber.Length do
            body = body .. tostring(math.random(0, 9))
        end
        
        local phoneNumber
        if prefix then
            phoneNumber = prefix .. body
        elseif Config.PhoneNumber.Prefixes and #Config.PhoneNumber.Prefixes > 0 then
            phoneNumber = Config.PhoneNumber.Prefixes[math.random(1, #Config.PhoneNumber.Prefixes)] .. body
        else
            phoneNumber = body
        end
        
        -- 检查是否已生成过
        if not seenNumbers[phoneNumber] then
            seenNumbers[phoneNumber] = true
            
            -- 检查号码是否已存在于数据库
            local exists = MySQL.scalar.await(
                "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
                { phoneNumber }
            )
            
            if not exists then
                -- 检测是否为靓号
                local premiumMatch, priceMultiplier = CheckPremiumNumber(phoneNumber)
                if premiumMatch then
                    table.insert(premiumNumbers, {
                        phone_number = phoneNumber,
                        premium_type = premiumMatch.name,
                        price_multiplier = priceMultiplier,
                        base_price = package.price,
                        final_price = math.floor(package.price * priceMultiplier)
                    })
                end
            end
        end
        
        Wait(0) -- 避免阻塞
    end
    
    -- 按价格倍数排序（从高到低）
    table.sort(premiumNumbers, function(a, b)
        return a.price_multiplier > b.price_multiplier
    end)
    
    LogInfo("生成靓号完成: 请求 %d 个，实际生成 %d 个，尝试次数: %d", count, #premiumNumbers, attempts)
    
    -- 即使没有找到足够的靓号，也返回已找到的
    return premiumNumbers
end

-- ============================================
-- 批量生成靓号并保存到数据库（老板功能）
-- ============================================
local function BatchGenerateAndSavePremiumNumbers(packageId, count, creatorIdentifier)
    if not Config.PhoneNumber.PremiumNumbers.Enabled then
        return 0, "靓号系统未启用"
    end
    
    local package = MySQL.single.await(
        "SELECT * FROM phone_operator_packages WHERE id = ? AND active = 1",
        { packageId }
    )
    
    if not package then
        return 0, "套餐不存在或未激活"
    end
    
    -- 生成靓号
    local generatedNumbers = GeneratePremiumNumbers(packageId, count)
    local savedCount = 0
    
    -- 保存到数据库
    for _, premiumNumber in ipairs(generatedNumbers) do
        -- 检查是否已存在于已上架表中
        local exists = MySQL.scalar.await(
            "SELECT id FROM phone_operator_premium_numbers WHERE phone_number = ?",
            { premiumNumber.phone_number }
        )
        
        if not exists then
            -- 检查是否已被购买
            local sold = MySQL.scalar.await(
                "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
                { premiumNumber.phone_number }
            )
            
            if not sold then
                -- 保存到已上架表
                MySQL.insert.await(
                    [[INSERT INTO phone_operator_premium_numbers 
                        (phone_number, package_id, premium_type, price_multiplier, base_price, final_price, status, created_by)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
                    {
                        premiumNumber.phone_number,
                        packageId,
                        premiumNumber.premium_type,
                        premiumNumber.price_multiplier,
                        premiumNumber.base_price,
                        premiumNumber.final_price,
                        Config.Boss.PremiumNumbers.AutoStatus or 'available',
                        creatorIdentifier
                    }
                )
                savedCount = savedCount + 1
            end
        end
    end
    
    return savedCount, string.format("成功生成并上架 %d 个靓号", savedCount)
end

-- ============================================
-- 获取套餐列表
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getPackages', function(source, cb)
    LogDebug("玩家 %d 请求获取套餐列表", source)
    local packages = MySQL.query.await(
        "SELECT * FROM phone_operator_packages WHERE active = 1 ORDER BY price ASC"
    )
    LogDebug("返回 %d 个套餐", #(packages or {}))
    cb(packages or {})
end)

-- ============================================
-- 获取靓号列表
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getPremiumNumbers', function(source, cb, packageId, count)
    count = count or 10
    LogDebug("玩家 %d 请求获取靓号列表，套餐ID: %d, 数量: %d", source, packageId, count)
    
    local premiumNumbers = GeneratePremiumNumbers(packageId, count)
    LogDebug("生成 %d 个靓号", #premiumNumbers)
    
    cb(premiumNumbers)
end)

-- ============================================
-- 获取玩家的手机号列表
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getMyNumbers', function(source, cb)
    local identifier = GetIdentifier(source)
    if not identifier then
        LogWarning("玩家 %d 标识符获取失败", source)
        return cb({})
    end
    
    LogDebug("玩家 %d (%s) 请求获取手机号列表", source, identifier)
    local numbers = MySQL.query.await(
        [[SELECT 
            n.*, 
            p.name as package_name, 
            p.description as package_description,
            p.weekly_fee,
            p.call_rate,
            p.sms_rate,
            p.data_rate
        FROM phone_operator_numbers n
        LEFT JOIN phone_operator_packages p ON n.package_id = p.id
        WHERE n.identifier = ? ORDER BY n.created_at DESC]],
        { identifier }
    )
    
    LogDebug("玩家 %d 有 %d 个手机号", source, #(numbers or {}))
    cb(numbers or {})
end)

-- ============================================
-- 购买手机号
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:purchaseNumber', function(source, cb, packageId, selectedPhoneNumber)
    LogInfo("玩家 %d 请求购买手机号，套餐ID: %d, 选择的号码: %s", source, packageId, selectedPhoneNumber or "随机")
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        LogError("玩家 %d 不存在", source)
        return cb(false, "玩家不存在")
    end
    
    local identifier = xPlayer.identifier
    
    -- 检查是否已有手机号
    if not Config.Purchase.AllowMultiple then
        local existing = MySQL.scalar.await(
            "SELECT phone_number FROM phone_operator_numbers WHERE identifier = ? AND status != 'expired'",
            { identifier }
        )
        if existing then
            LogWarning("玩家 %d 已拥有手机号: %s，不允许重复购买", source, existing)
            return cb(false, _U('purchase_already_owned'))
        end
    end
    
    -- 验证生成的手机号长度（普通玩家必须是7-15位）
    -- 注意：管理员可以通过命令设置1-7位号码，但普通玩家购买时生成的号码必须符合配置
    
    -- 获取套餐信息
    local package = MySQL.single.await(
        "SELECT * FROM phone_operator_packages WHERE id = ? AND active = 1",
        { packageId }
    )
    
    if not package then
        LogWarning("玩家 %d 请求的套餐不存在: ID=%d", source, packageId)
        return cb(false, _U('purchase_package_not_found'))
    end
    
    LogDebug("套餐信息: %s, 价格: $%d", package.name, package.price)
    
    -- 生成或使用选择的手机号
    local phoneNumber
    local premiumMatch, priceMultiplier
    local premiumNumberData = nil
    
    if selectedPhoneNumber and selectedPhoneNumber ~= "" then
        -- 使用用户选择的号码（可能是已上架的靓号）
        phoneNumber = selectedPhoneNumber
        
        -- 首先检查是否是从已上架靓号列表中购买的
        premiumNumberData = MySQL.single.await(
            "SELECT * FROM phone_operator_premium_numbers WHERE phone_number = ? AND status = 'available'",
            { phoneNumber }
        )
        
        if premiumNumberData then
            -- 是从已上架列表购买的靓号
            premiumMatch = { name = premiumNumberData.premium_type }
            priceMultiplier = premiumNumberData.price_multiplier
            
            -- 标记为已售出
            MySQL.update.await(
                "UPDATE phone_operator_premium_numbers SET status = 'sold', sold_to = ?, sold_at = NOW() WHERE phone_number = ?",
                { identifier, phoneNumber }
            )
            
            LogInfo("玩家 %d 购买已上架靓号: %s, 类型: %s, 价格: $%d", source, phoneNumber, premiumNumberData.premium_type, premiumNumberData.final_price)
        else
            -- 验证号码是否已存在或被使用
            local exists = MySQL.scalar.await(
                "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
                { phoneNumber }
            )
            if exists then
                LogWarning("玩家 %d 选择的号码已被使用: %s", source, phoneNumber)
                return cb(false, _U('purchase_phone_number_used') or "该号码已被使用")
            end
            
            -- 检查是否在已上架列表中但已售出
            local soldNumber = MySQL.scalar.await(
                "SELECT phone_number FROM phone_operator_premium_numbers WHERE phone_number = ? AND status != 'available'",
                { phoneNumber }
            )
            if soldNumber then
                LogWarning("玩家 %d 选择的号码已售出: %s", source, phoneNumber)
                return cb(false, "该号码已售出")
            end
            
                -- 检测靓号并计算价格
            premiumMatch, priceMultiplier = CheckPremiumNumber(phoneNumber)
            LogInfo("玩家 %d 选择号码: %s", source, phoneNumber)
        end
    else
        -- 随机生成号码
        phoneNumber = GeneratePhoneNumber(package.phone_number_prefix)
        LogInfo("为玩家 %d 生成手机号: %s", source, phoneNumber)
        
        -- 检测靓号并计算价格
        premiumMatch, priceMultiplier = CheckPremiumNumber(phoneNumber)
    end
    
    -- 计算最终价格
    local finalPrice
    if premiumNumberData and premiumNumberData.final_price then
        finalPrice = premiumNumberData.final_price
    else
        finalPrice = math.floor(package.price * (priceMultiplier or 1.0))
    end
    
    if premiumMatch then
        LogInfo("检测到靓号: %s, 类型: %s, 价格倍数: %.2f, 最终价格: $%d", 
            phoneNumber, premiumMatch.name, priceMultiplier, finalPrice)
    end
    
    -- 如果是靓号，记录信息
    local premiumInfo = nil
    if premiumMatch then
        premiumInfo = {
            name = premiumMatch.name,
            multiplier = priceMultiplier,
            original_price = package.price,
            final_price = finalPrice
        }
        
        if Config.Debug then
            print(string.format("[LB-SHOUJIKA] 检测到靓号: %s, 类型: %s, 价格倍数: %.2f, 最终价格: $%d", 
                phoneNumber, premiumMatch.name, priceMultiplier, finalPrice))
        end
    end
    
    -- 检查余额
    local playerMoney = xPlayer.getMoney()
    if playerMoney < finalPrice then
        LogWarning("玩家 %d 余额不足: 需要 $%d, 当前 $%d", source, finalPrice, playerMoney)
        local premiumInfo = ""
        if premiumMatch and premiumMatch.name and priceMultiplier then
            premiumInfo = " (" .. _U('purchase_premium_number', premiumMatch.name, priceMultiplier) .. ")"
        end
        return cb(false, _U('purchase_insufficient_funds', finalPrice) .. premiumInfo)
    end
    
    -- 扣除费用
    xPlayer.removeMoney(finalPrice)
    LogInfo("从玩家 %d 扣除费用: $%d, 剩余: $%d", source, finalPrice, xPlayer.getMoney())
    
    -- 创建手机号记录（包含初始信用评分和信用额度）
    local status = Config.Purchase.AutoActivate and 'active' or 'inactive'
    local activatedAtValue = nil
    if Config.Purchase.AutoActivate then
        -- 将时间戳转换为MySQL日期时间格式 'YYYY-MM-DD HH:MM:SS'
        activatedAtValue = os.date('%Y-%m-%d %H:%M:%S', os.time())
    end
    local initialCreditScore = Config.Credit.CreditScore.InitialScore
    local initialCreditLimit = Config.Credit.CreditFormula(initialCreditScore)
    
    MySQL.insert.await(
        [[INSERT INTO phone_operator_numbers 
            (identifier, phone_number, package_id, balance, status, activated_at, credit_score, credit_limit) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        { identifier, phoneNumber, packageId, package.initial_balance, status, activatedAtValue, initialCreditScore, initialCreditLimit }
    )
    
    LogInfo("创建手机号记录: %s, 状态: %s, 余额: $%d, 信用评分: %d, 信用额度: $%d", 
        phoneNumber, status, package.initial_balance, initialCreditScore, initialCreditLimit)
    
    -- 发送购买成功通知
    if Config.Notifications.PurchaseSuccess then
        local message = _U('purchase_phone_number', phoneNumber) .. ", " .. _U('purchase_initial_balance', package.initial_balance)
        if premiumMatch and premiumMatch.name and priceMultiplier then
            message = message .. "\n" .. _U('purchase_premium_number', premiumMatch.name, priceMultiplier)
        end
        Notify(source, _U('notify_purchase_success'), message, "success")
    end
    
    -- 无论是否自动激活，都要确保手机号在lb-phone系统中可被拨打
    -- 这是为了让其他玩家可以拨打这个号码
    LogInfo("开始更新lb-phone系统的手机号: %s", phoneNumber)
    
    -- 获取所有可能的标识符格式（ESX可能使用不同的标识符格式）
    local identifiers = {}
    table.insert(identifiers, identifier) -- 主标识符
    
    -- 获取玩家的所有标识符
    local playerIdentifiers = GetPlayerIdentifiers(source)
    for _, ident in ipairs(playerIdentifiers) do
        -- 添加所有标识符（包括license、char1等格式）
        local found = false
        for _, existing in ipairs(identifiers) do
            if existing == ident then
                found = true
                break
            end
        end
        if not found then
            table.insert(identifiers, ident)
        end
    end
    
    LogInfo("找到 %d 个标识符需要更新", #identifiers)
    for _, ident in ipairs(identifiers) do
        LogInfo("  - 标识符: %s", ident)
    end
    
    -- 更新所有可能的标识符格式
    for _, ident in ipairs(identifiers) do
        -- 确保phone_phones表中存在该手机号，使其可被拨打
        -- 首先尝试更新phone_phones表中id匹配的记录
        local updateResult1 = MySQL.update.await(
            "UPDATE phone_phones SET phone_number = ?, is_setup = 1 WHERE id = ?",
            { phoneNumber, ident }
        )
        LogInfo("更新phone_phones表（id=%s），影响行数: %s", ident, tostring(updateResult1 or 0))
        
        -- 如果id没有匹配的记录，使用INSERT ... ON DUPLICATE KEY UPDATE创建新记录
        if (updateResult1 or 0) == 0 then
            local insertResult = MySQL.insert.await(
                "INSERT INTO phone_phones (id, owner_id, phone_number, is_setup) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE phone_number = ?, is_setup = 1",
                { ident, ident, phoneNumber, 1, phoneNumber }
            )
            LogInfo("插入phone_phones表（id=%s），结果: %s", ident, tostring(insertResult))
        end
        
        -- 同时更新所有匹配owner_id的记录（确保所有相关记录都被更新）
        local updateResult2 = MySQL.update.await(
            "UPDATE phone_phones SET phone_number = ? WHERE owner_id = ?",
            { phoneNumber, ident }
        )
        LogInfo("更新phone_phones表（owner_id=%s），影响行数: %s", ident, tostring(updateResult2 or 0))
        
        -- 更新phone_last_phone（lb-phone使用此表获取当前号码）
        local updateResult3 = MySQL.insert.await(
            "INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?",
            { ident, phoneNumber, phoneNumber }
        )
        LogInfo("更新phone_last_phone表（id=%s），结果: %s", ident, tostring(updateResult3))
    end
    
    -- 如果自动激活且需要替换默认号码，则设置为当前使用的号码
    if Config.Purchase.AutoActivate and Config.Purchase.ReplaceDefault then
        -- 验证更新结果
        for _, ident in ipairs(identifiers) do
            local verifyPhone = MySQL.single.await(
                "SELECT phone_number FROM phone_phones WHERE id = ? OR owner_id = ? LIMIT 1",
                { ident, ident }
            )
            if verifyPhone then
                LogInfo("验证phone_phones表（标识符: %s）: 当前手机号 = %s", ident, tostring(verifyPhone.phone_number))
            else
                LogWarning("验证phone_phones表（标识符: %s）: 未找到记录", ident)
            end
            
            local verifyLastPhone = MySQL.single.await(
                "SELECT phone_number FROM phone_last_phone WHERE id = ?",
                { ident }
            )
            if verifyLastPhone then
                LogInfo("验证phone_last_phone表（标识符: %s）: 当前手机号 = %s", ident, tostring(verifyLastPhone.phone_number))
            else
                LogWarning("验证phone_last_phone表（标识符: %s）: 未找到记录", ident)
            end
        end
        
        -- 通知客户端刷新手机号
        if Config.Purchase.NotifyClient then
            -- 延迟通知，确保数据库更新完成
            CreateThread(function()
                Wait(500) -- 等待数据库操作完成
                TriggerClientEvent('lb-shoujika:phoneNumberUpdated', source, phoneNumber)
                -- 同时触发lb-phone的刷新事件（如果lb-phone支持）
                TriggerClientEvent('lb-phone:refreshPhoneNumber', source)
                TriggerClientEvent('lb-phone:updatePhoneNumber', source)
                TriggerClientEvent('phone:updatePhoneNumber', source)
            end)
        end
    end
    
    LogInfo("手机号更新完成: %s, 标识符数量: %d", phoneNumber, #identifiers)
    
    -- 记录充值（初始余额）
    if package.initial_balance > 0 then
        MySQL.insert.await(
            [[INSERT INTO phone_operator_recharges 
                (phone_number, amount, balance_before, balance_after, method) 
                VALUES (?, ?, ?, ?, ?)]],
            { phoneNumber, package.initial_balance, 0, package.initial_balance, 'purchase' }
        )
        LogDebug("记录初始余额充值: $%d", package.initial_balance)
    end
    
    LogInfo("玩家 %d 购买手机号成功: %s", source, phoneNumber)
    cb(true, phoneNumber)
end)

-- ============================================
-- 激活手机号
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:activateNumber', function(source, cb, phoneNumber)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(false, "玩家不存在")
    end
    
    local identifier = xPlayer.identifier
    
    -- 检查手机号是否属于该玩家
    local numberData = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE phone_number = ? AND identifier = ?",
        { phoneNumber, identifier }
    )
    
    if not numberData then
        return cb(false, _U('activate_not_owned'))
    end
    
    if numberData.status == 'active' then
        return cb(false, _U('activate_already_active'))
    end
    
    -- 检查激活费用
    if Config.Activation.RequirePayment and Config.Activation.ActivationFee > 0 then
        if xPlayer.getMoney() < Config.Activation.ActivationFee then
            return cb(false, _U('activate_insufficient_funds'))
        end
        xPlayer.removeMoney(Config.Activation.ActivationFee)
    end
    
    -- 激活手机号
    local activatedAt = os.date('%Y-%m-%d %H:%M:%S', os.time())
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET status = 'active', activated_at = ? WHERE phone_number = ?",
        { activatedAt, phoneNumber }
    )
    
    -- 替换默认手机号
    if Config.Purchase.ReplaceDefault then
        -- 获取所有可能的标识符格式
        local identifiers = {}
        table.insert(identifiers, identifier)
        
        local playerIdentifiers = GetPlayerIdentifiers(source)
        for _, ident in ipairs(playerIdentifiers) do
            local found = false
            for _, existing in ipairs(identifiers) do
                if existing == ident then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(identifiers, ident)
            end
        end
        
        -- 更新所有可能的标识符格式
        for _, ident in ipairs(identifiers) do
            -- 首先尝试更新phone_phones表中id匹配的记录
            local updateResult1 = MySQL.update.await(
                "UPDATE phone_phones SET phone_number = ?, is_setup = 1 WHERE id = ?",
                { phoneNumber, ident }
            )
            
            -- 如果id没有匹配的记录，使用INSERT ... ON DUPLICATE KEY UPDATE创建新记录
            if (updateResult1 or 0) == 0 then
                MySQL.insert.await(
                    "INSERT INTO phone_phones (id, owner_id, phone_number, is_setup) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE phone_number = ?, is_setup = 1",
                    { ident, ident, phoneNumber, 1, phoneNumber }
                )
            end
            
            -- 同时更新所有匹配owner_id的记录（确保所有相关记录都被更新）
            MySQL.update.await(
                "UPDATE phone_phones SET phone_number = ? WHERE owner_id = ?",
                { phoneNumber, ident }
            )
            
            -- 更新phone_last_phone
            MySQL.insert.await(
                "INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?",
                { ident, phoneNumber, phoneNumber }
            )
        end
        
        -- 通知客户端刷新手机号
        if Config.Purchase.NotifyClient then
            CreateThread(function()
                Wait(500)
                TriggerClientEvent('lb-shoujika:phoneNumberUpdated', source, phoneNumber)
                TriggerClientEvent('lb-phone:refreshPhoneNumber', source)
                TriggerClientEvent('lb-phone:updatePhoneNumber', source)
                TriggerClientEvent('phone:updatePhoneNumber', source)
            end)
        end
    end
    
    Notify(source, _U('notify_activate_success'), _U('activate_success'), "success")
    cb(true)
end)

-- ============================================
-- 删除手机号
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:deleteNumber', function(source, cb, phoneNumber)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(false, "玩家不存在")
    end
    
    local identifier = xPlayer.identifier
    
    -- 检查手机号是否属于该玩家
    local numberData = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE phone_number = ? AND identifier = ?",
        { phoneNumber, identifier }
    )
    
    if not numberData then
        LogWarning("玩家 %d 尝试删除不属于自己的手机号: %s", source, phoneNumber)
        return cb(false, "该手机号不属于您")
    end
    
    -- 获取所有可能的标识符格式
    local identifiers = {}
    table.insert(identifiers, identifier)
    
    local playerIdentifiers = GetPlayerIdentifiers(source)
    for _, ident in ipairs(playerIdentifiers) do
        local found = false
        for _, existing in ipairs(identifiers) do
            if existing == ident then
                found = true
                break
            end
        end
        if not found then
            table.insert(identifiers, ident)
        end
    end
    
    -- 检查该手机号是否是当前激活使用的手机号
    local isActiveNumber = false
    for _, ident in ipairs(identifiers) do
        local currentPhone = MySQL.scalar.await(
            "SELECT phone_number FROM phone_last_phone WHERE id = ?",
            { ident }
        )
        if currentPhone == phoneNumber then
            isActiveNumber = true
            break
        end
    end
    
    -- 如果这是当前使用的手机号，需要从phone_phones和phone_last_phone中移除
    if isActiveNumber then
        for _, ident in ipairs(identifiers) do
            -- 检查是否有其他手机号可以切换（如果有多个手机号）
            local otherNumbers = MySQL.query.await(
                "SELECT phone_number FROM phone_operator_numbers WHERE identifier = ? AND phone_number != ? AND status = 'active' LIMIT 1",
                { identifier, phoneNumber }
            )
            
            if otherNumbers and #otherNumbers > 0 then
                -- 如果有其他激活的手机号，切换到第一个
                local newPhoneNumber = otherNumbers[1].phone_number
                MySQL.update.await(
                    "UPDATE phone_phones SET phone_number = ? WHERE owner_id = ?",
                    { newPhoneNumber, ident }
                )
                MySQL.insert.await(
                    "INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?",
                    { ident, newPhoneNumber, newPhoneNumber }
                )
                LogInfo("删除手机号 %s 后，自动切换到 %s", phoneNumber, newPhoneNumber)
            else
                -- 如果没有其他手机号，删除phone_phones和phone_last_phone中的记录
                -- 注意：phone_phones表的phone_number列不允许NULL，所以直接删除匹配的记录
                MySQL.update.await(
                    "DELETE FROM phone_phones WHERE owner_id = ? AND phone_number = ?",
                    { ident, phoneNumber }
                )
                MySQL.update.await(
                    "DELETE FROM phone_last_phone WHERE id = ? AND phone_number = ?",
                    { ident, phoneNumber }
                )
                LogInfo("删除手机号 %s，这是玩家的唯一手机号", phoneNumber)
            end
        end
    end
    
    -- 删除手机号记录（使用CASCADE会自动删除相关的充值记录和消费记录）
    local deleteResult = MySQL.query.await(
        "DELETE FROM phone_operator_numbers WHERE phone_number = ? AND identifier = ?",
        { phoneNumber, identifier }
    )
    
    if deleteResult then
        LogInfo("玩家 %d 成功删除手机号: %s", source, phoneNumber)
        
        -- 通知客户端刷新
        if Config.Purchase.NotifyClient then
            TriggerClientEvent('lb-shoujika:phoneNumberDeleted', source, phoneNumber)
        end
        
        cb(true, "手机号已成功删除")
    else
        LogError("玩家 %d 删除手机号失败: %s", source, phoneNumber)
        cb(false, "删除失败，请稍后重试")
    end
end)

-- ============================================
-- 充值话费
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:rechargeBalance', function(source, cb, phoneNumber, amount, method)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(false, "玩家不存在")
    end
    
    -- 验证金额
    if amount < Config.Recharge.MinAmount or amount > Config.Recharge.MaxAmount then
        return cb(false, _U('recharge_amount_invalid', Config.Recharge.MinAmount, Config.Recharge.MaxAmount))
    end
    
    -- 检查手机号
    local numberData = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    
    if not numberData then
        return cb(false, _U('recharge_phone_not_found'))
    end
    
    -- 验证充值方式
    if not Config.Recharge.Methods[method] then
        return cb(false, _U('recharge_method_not_supported', method))
    end
    
    -- 计算手续费和总费用
    local commission = 0
    if Config.Recharge.Commission > 0 then
        commission = math.floor(amount * Config.Recharge.Commission)
    end
    local totalCost = amount + commission
    
    -- 检查余额并扣除费用
    if method == 'cash' then
        if xPlayer.getMoney() < totalCost then
            return cb(false, _U('recharge_insufficient_cash'))
        end
        xPlayer.removeMoney(totalCost)
    elseif method == 'bank' then
        if xPlayer.getAccount('bank').money < totalCost then
            return cb(false, _U('recharge_insufficient_bank'))
        end
        xPlayer.removeAccountMoney('bank', totalCost)
    elseif method == 'card' then
        -- 银行卡充值（如果有实现）
        if xPlayer.getAccount('bank').money < totalCost then
            return cb(false, _U('recharge_insufficient_bank'))
        end
        xPlayer.removeAccountMoney('bank', totalCost)
    else
        return cb(false, _U('recharge_method_not_supported'))
    end
    
    -- 更新余额
    local newBalance = numberData.balance + amount
    local wasSuspended = (numberData.status == 'suspended')
    
    -- 检查是否需要恢复服务
    local newStatus = numberData.status
    if wasSuspended and Config.Balance.AutoResume and newBalance >= Config.Balance.ResumeThreshold then
        newStatus = 'active'
    end
    
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET balance = ?, status = ?, last_recharge = NOW(), total_recharged = total_recharged + ? WHERE phone_number = ?",
        { newBalance, newStatus, amount, phoneNumber }
    )
    
    -- 如果服务已恢复，通知玩家
    if wasSuspended and newStatus == 'active' and Config.Notifications.ActivationSuccess then
        Notify(source, _U('notify_service_resumed'), 
            _U('recharge_current_balance', newBalance), 
            "success")
    end
    
    -- 记录充值
    MySQL.insert.await(
        [[INSERT INTO phone_operator_recharges 
            (phone_number, amount, balance_before, balance_after, method) 
            VALUES (?, ?, ?, ?, ?)]],
        { phoneNumber, amount, numberData.balance, newBalance, method }
    )
    
    -- 更新信用评分（充值增加信用）
    if Config.Credit.CreditScore.RechargeAmount > 0 then
        local scoreIncrease = math.floor(amount * Config.Credit.CreditScore.RechargeAmount)
        if scoreIncrease > 0 then
            local newScore = math.min(
                Config.Credit.CreditScore.MaxScore,
                (numberData.credit_score or Config.Credit.CreditScore.InitialScore) + scoreIncrease
            )
            local newCreditLimit = Config.Credit.CreditFormula(newScore)
            
            MySQL.update.await(
                "UPDATE phone_operator_numbers SET credit_score = ?, credit_limit = ? WHERE phone_number = ?",
                { newScore, newCreditLimit, phoneNumber }
            )
            
            if Config.Notifications.CreditUpdate then
                Notify(source, _U('notify_credit_increased'), 
                    _U('credit_score_increased', amount, scoreIncrease, newCreditLimit), 
                    "info")
            end
        end
    end
    
    -- 发送充值成功通知
    if Config.Notifications.RechargeSuccess then
        local message = _U('recharge_current_balance', newBalance)
        if commission > 0 then
            message = message .. "\n" .. _U('recharge_commission', amount, commission)
        end
        Notify(source, _U('notify_recharge_success'), message, "success")
    end
    
    cb(true, newBalance)
end)

-- ============================================
-- 获取话费余额
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getBalance', function(source, cb, phoneNumber)
    local balance = MySQL.scalar.await(
        "SELECT balance FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    cb(balance or 0)
end)

-- 计算通话费用
local function CalculateCallCost(phoneNumber, duration, package)
    if not package then return 0 end
    
    -- 获取手机号信息
    local numberData = MySQL.single.await(
        "SELECT used_free_minutes, weekly_free_minutes_reset FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    
    if not numberData then return 0 end
    
    -- 检查免费分钟数重置
    local now = os.time()
    local resetTime = numberData.weekly_free_minutes_reset
    local usedFreeMinutes = numberData.used_free_minutes or 0
    local freeMinutes = package.free_minutes or 0
    
    -- 如果重置时间已过或不存在，重置免费分钟数
    if not resetTime or (now - resetTime) >= (7 * 24 * 60 * 60) then
        usedFreeMinutes = 0
        resetTime = os.date('%Y-%m-%d %H:%M:%S', now)
        MySQL.update.await(
            "UPDATE phone_operator_numbers SET used_free_minutes = 0, weekly_free_minutes_reset = ? WHERE phone_number = ?",
            { resetTime, phoneNumber }
        )
    end
    
    -- 计算通话分钟数
    local callMinutes = duration / 60
    if Config.CallBilling.RoundUp then
        callMinutes = math.ceil(callMinutes)
    else
        callMinutes = math.floor(callMinutes)
    end
    
    -- 计算费用
    local cost = 0
    local remainingFreeMinutes = math.max(0, freeMinutes - usedFreeMinutes)
    local chargeableMinutes = math.max(0, callMinutes - remainingFreeMinutes)
    
    if chargeableMinutes > 0 then
        cost = math.floor(chargeableMinutes * (package.call_rate or 0) * 100) -- 转换为分
    end
    
    -- 更新已使用的免费分钟数
    local newUsedFreeMinutes = math.min(freeMinutes, usedFreeMinutes + callMinutes)
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET used_free_minutes = ? WHERE phone_number = ?",
        { newUsedFreeMinutes, phoneNumber }
    )
    
    return cost, chargeableMinutes, (callMinutes - chargeableMinutes)
end

-- 检查是否可以拨打电话
local function CanMakeCall(phoneNumber)
    if not Config.CallBilling.CheckBeforeCall then
        return true
    end
    
    local numberData = MySQL.single.await(
        "SELECT balance, credit_limit, status FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    
    if not numberData or numberData.status ~= 'active' then
        return false, "手机号未激活或已暂停"
    end
    
    -- 检查是否有余额或信用额度
    local availableBalance = numberData.balance + (numberData.credit_limit or 0)
    if availableBalance <= 0 then
        if Config.CallBilling.BlockOnOverdue then
            return false, "余额不足，无法拨打电话"
        end
    end
    
    return true
end

-- ============================================
-- 扣除话费（供lb-phone调用）
-- ============================================
-- 通话计费导出函数（供lb-phone调用）
exports('chargeCall', function(phoneNumber, duration, calleeNumber)
    if not phoneNumber or not duration or duration <= 0 then
        return false, "参数错误"
    end
    
    -- 检查是否可以拨打电话
    local canCall, errorMsg = CanMakeCall(phoneNumber)
    if not canCall then
        return false, errorMsg
    end
    
    -- 获取套餐信息
    local numberData = MySQL.single.await(
        [[SELECT n.*, p.call_rate, p.free_minutes 
          FROM phone_operator_numbers n
          LEFT JOIN phone_operator_packages p ON n.package_id = p.id
          WHERE n.phone_number = ? AND n.status = 'active']],
        { phoneNumber }
    )
    
    if not numberData then
        return false, "手机号不存在或未激活"
    end
    
    -- 计算通话费用
    local cost, chargeableMinutes, freeMinutes = CalculateCallCost(phoneNumber, duration, numberData)
    
    if cost > 0 then
        -- 扣除费用
        local success, newBalance = exports['lb-shoujika']:chargeBalance(
            phoneNumber,
            cost,
            'call',
            string.format('通话费用 (%d分钟)', chargeableMinutes),
            {
                duration = duration,
                callee = calleeNumber,
                chargeable_minutes = chargeableMinutes,
                free_minutes = freeMinutes
            }
        )
        
        if not success then
            return false, "扣费失败"
        end
        
        -- 记录通话日志
        MySQL.insert.await(
            [[INSERT INTO phone_operator_call_logs 
                (phone_number, callee_number, duration, charge_amount, used_free_minutes) 
                VALUES (?, ?, ?, ?, ?)]],
            { phoneNumber, calleeNumber or '', duration, cost, freeMinutes > 0 }
        )
        
        return true, newBalance
    else
        -- 免费通话，只记录日志
        MySQL.insert.await(
            [[INSERT INTO phone_operator_call_logs 
                (phone_number, callee_number, duration, charge_amount, used_free_minutes) 
                VALUES (?, ?, ?, ?, ?)]],
            { phoneNumber, calleeNumber or '', duration, 0, true }
        )
        
        return true, numberData.balance
    end
end)

exports('chargeBalance', function(phoneNumber, amount, chargeType, description, metadata)
    if not phoneNumber or not amount or amount <= 0 then
        return false
    end
    
    local numberData = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE phone_number = ? AND status = 'active'",
        { phoneNumber }
    )
    
    if not numberData then
        return false
    end
    
    -- 检查余额和信用额度
    local availableBalance = numberData.balance + (numberData.credit_limit or 0)
    
    if availableBalance < amount then
        -- 余额和信用额度都不足
        if Config.Balance.AutoSuspend and numberData.balance <= Config.Balance.AutoSuspendThreshold then
            MySQL.update.await(
                "UPDATE phone_operator_numbers SET status = 'suspended' WHERE phone_number = ?",
                { phoneNumber }
            )
            
            -- 欠费扣信用评分
            if Config.Credit.CreditScore.OverduePenalty < 0 then
                UpdateCreditScore(phoneNumber, Config.Credit.CreditScore.OverduePenalty, "欠费暂停服务")
            end
        end
        return false
    end
    
    -- 如果余额不足但信用额度足够，使用信用额度
    local balanceUsed = math.min(numberData.balance, amount)
    local creditUsed = amount - balanceUsed
    
    if creditUsed > 0 then
        -- 使用信用额度，扣信用评分
        if Config.Credit.CreditScore.LatePayment < 0 then
            UpdateCreditScore(phoneNumber, Config.Credit.CreditScore.LatePayment, "使用信用额度")
        end
    end
    
    local newBalance = numberData.balance - balanceUsed
    -- 如果使用了信用额度，需要更新信用额度使用情况
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET balance = ?, total_spent = total_spent + ? WHERE phone_number = ?",
        { newBalance, amount, phoneNumber }
    )
    
    -- 记录消费
    MySQL.insert.await(
        [[INSERT INTO phone_operator_charges 
            (phone_number, type, amount, balance_before, balance_after, description, metadata) 
            VALUES (?, ?, ?, ?, ?, ?, ?)]],
        { phoneNumber, chargeType or 'other', amount, numberData.balance, newBalance, description, json.encode(metadata or {}) }
    )
    
    -- 低余额警告和自动暂停
    if newBalance <= Config.Balance.LowBalanceWarning then
        local ownerSrc = nil
        -- 查找在线玩家
        for _, playerId in ipairs(GetPlayers()) do
            local playerIdentifier = GetIdentifier(tonumber(playerId))
            if playerIdentifier == numberData.identifier then
                ownerSrc = tonumber(playerId)
                break
            end
        end
        
        -- 低余额警告
        if Config.Notifications.LowBalance and ownerSrc then
            Notify(ownerSrc, _U('notify_low_balance'), 
                _U('balance_low_warning', newBalance), 
                "warning")
        end
        
        -- 自动暂停服务
        if Config.Balance.AutoSuspend and newBalance <= Config.Balance.AutoSuspendThreshold then
            if numberData.status ~= 'suspended' then
                MySQL.update.await(
                    "UPDATE phone_operator_numbers SET status = 'suspended' WHERE phone_number = ?",
                    { phoneNumber }
                )
                
                if ownerSrc then
                    Notify(ownerSrc, _U('notify_service_suspended'), 
                        _U('balance_auto_suspend', newBalance), 
                        "error")
                end
                
                if Config.Debug then
                    print(string.format("[LB-SHOUJIKA] 自动暂停服务: %s, 余额: $%d", phoneNumber, newBalance))
                end
            end
        end
    end
    
    return true, newBalance
end)

-- ============================================
-- 验证手机号是否存在且可拨打（供lb-phone调用）
-- ============================================
exports('validatePhoneNumber', function(phoneNumber)
    if not phoneNumber then
        return false
    end
    
    -- 检查phone_phones表中是否存在该号码
    local exists = MySQL.scalar.await(
        "SELECT phone_number FROM phone_phones WHERE phone_number = ? LIMIT 1",
        { phoneNumber }
    )
    
    if exists then
        -- 进一步检查号码状态
        local numberData = MySQL.single.await(
            "SELECT status FROM phone_operator_numbers WHERE phone_number = ? LIMIT 1",
            { phoneNumber }
        )
        if numberData and numberData.status == 'active' then
            return true
        end
    end
    
    return false
end)

-- ============================================
-- SMS计费导出函数（供lb-phone调用）
-- ============================================
exports('chargeSMS', function(phoneNumber, recipientNumber)
    if not phoneNumber then
        return false, "参数错误"
    end
    
    -- 获取套餐信息
    local numberData = MySQL.single.await(
        [[SELECT n.*, p.sms_rate 
          FROM phone_operator_numbers n
          LEFT JOIN phone_operator_packages p ON n.package_id = p.id
          WHERE n.phone_number = ? AND n.status = 'active']],
        { phoneNumber }
    )
    
    if not numberData then
        return false, "手机号不存在或未激活"
    end
    
    -- 计算短信费用（每条短信的费用，转换为分）
    local smsCost = math.floor((numberData.sms_rate or 0) * 100)
    
    if smsCost > 0 then
        -- 扣除费用
        local success, newBalance = exports['lb-shoujika']:chargeBalance(
            phoneNumber,
            smsCost,
            'sms',
            string.format('短信费用 (发送至: %s)', recipientNumber or '未知'),
            {
                recipient = recipientNumber,
                type = 'sms'
            }
        )
        
        if not success then
            return false, "扣费失败"
        end
        
        return true, newBalance
    else
        -- 免费短信
        return true, numberData.balance
    end
end)

-- ============================================
-- 获取充值记录
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getRechargeHistory', function(source, cb, phoneNumber, limit)
    limit = limit or 20
    local history = MySQL.query.await(
        "SELECT * FROM phone_operator_recharges WHERE phone_number = ? ORDER BY created_at DESC LIMIT ?",
        { phoneNumber, limit }
    )
    cb(history or {})
end)

-- ============================================
-- 获取消费记录
-- ============================================
ESX.RegisterServerCallback('lb-shoujika:getChargeHistory', function(source, cb, phoneNumber, limit)
    limit = limit or 20
    local history = MySQL.query.await(
        "SELECT * FROM phone_operator_charges WHERE phone_number = ? ORDER BY created_at DESC LIMIT ?",
        { phoneNumber, limit }
    )
    cb(history or {})
end)

-- ============================================
-- 管理员命令：修改玩家手机号（支持1-7位，可指定套餐）
-- ============================================
RegisterCommand(Config.AdminCommands.Command, function(source, args)
    if not Config.AdminCommands.Enabled then
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return
    end
    
    -- 检查权限
    if not IsAdmin(source) then
        Notify(source, _U('error'), _U('admin_no_permission'), "error")
        return
    end
    
    -- 检查参数
    if #args < 2 then
        Notify(source, _U('admin_command_format_error'), 
            string.format("用法: /%s [玩家ID] [新手机号] [套餐ID(可选)]\n示例: /%s 1 1234567 2", 
                Config.AdminCommands.Command, Config.AdminCommands.Command), 
            "error")
        return
    end
    
    local targetId = tonumber(args[1])
    local newPhoneNumber = args[2]
    local packageId = tonumber(args[3]) or 1 -- 默认套餐ID为1
    
    if not targetId or not newPhoneNumber then
        Notify(source, _U('error'), _U('admin_command_format_error'), "error")
        return
    end
    
    -- 验证手机号格式（管理员可设置1-7位）
    local phoneLength = #newPhoneNumber
    if phoneLength < Config.AdminCommands.MinPhoneLength or phoneLength > Config.AdminCommands.MaxPhoneLength then
        Notify(source, _U('admin_phone_number_format_error'), 
            _U('admin_phone_number_length_error', Config.AdminCommands.MinPhoneLength, Config.AdminCommands.MaxPhoneLength), 
            "error")
        return
    end
    
    -- 验证手机号只包含数字
    if not string.match(newPhoneNumber, "^%d+$") then
        Notify(source, _U('admin_phone_number_format_error'), _U('admin_phone_number_digits_only'), "error")
        return
    end
    
    -- 验证套餐是否存在
    local package = MySQL.single.await(
        "SELECT * FROM phone_operator_packages WHERE id = ?",
        { packageId }
    )
    
    if not package then
        Notify(source, _U('admin_package_not_found'), string.format("套餐ID %d 不存在", packageId), "error")
        return
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        Notify(source, _U('admin_player_not_found'), string.format("ID %d 的玩家不在线", targetId), "error")
        return
    end
    
    local targetIdentifier = targetPlayer.identifier
    
    -- 检查新手机号是否已被使用
    local existing = MySQL.scalar.await(
        "SELECT phone_number FROM phone_operator_numbers WHERE phone_number = ?",
        { newPhoneNumber }
    )
    
    if existing then
        Notify(source, _U('admin_phone_number_used'), string.format("手机号 %s 已被其他玩家使用", newPhoneNumber), "error")
        return
    end
    
    -- 检查phone_phones表中是否已存在
    local existingPhone = MySQL.scalar.await(
        "SELECT phone_number FROM phone_phones WHERE phone_number = ?",
        { newPhoneNumber }
    )
    
    if existingPhone then
        Notify(source, _U('admin_phone_number_used'), string.format("手机号 %s 在系统中已被使用", newPhoneNumber), "error")
        return
    end
    
    -- 获取玩家当前的手机号记录
    local currentNumber = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE identifier = ? AND status = 'active' LIMIT 1",
        { targetIdentifier }
    )
    
    if currentNumber then
        -- 更新现有记录（包括套餐）
        MySQL.update.await(
            "UPDATE phone_operator_numbers SET phone_number = ?, package_id = ? WHERE id = ?",
            { newPhoneNumber, packageId, currentNumber.id }
        )
    else
        -- 创建新记录（使用指定套餐）
        local initialCreditScore = Config.Credit.CreditScore.InitialScore
        local initialCreditLimit = Config.Credit.CreditFormula(initialCreditScore)
        
        local activatedAt = os.date('%Y-%m-%d %H:%M:%S', os.time())
        MySQL.insert.await(
            [[INSERT INTO phone_operator_numbers 
                (identifier, phone_number, package_id, balance, status, activated_at, credit_score, credit_limit) 
                VALUES (?, ?, ?, ?, 'active', ?, ?, ?)]],
            { targetIdentifier, newPhoneNumber, packageId, package.initial_balance or 0, activatedAt, initialCreditScore, initialCreditLimit }
        )
    end
    
    -- 获取目标玩家的所有标识符格式
    local identifiers = {}
    table.insert(identifiers, targetIdentifier)
    
    local playerIdentifiers = GetPlayerIdentifiers(targetId)
    for _, ident in ipairs(playerIdentifiers) do
        local found = false
        for _, existing in ipairs(identifiers) do
            if existing == ident then
                found = true
                break
            end
        end
        if not found then
            table.insert(identifiers, ident)
        end
    end
    
    -- 更新所有可能的标识符格式
    for _, ident in ipairs(identifiers) do
        -- 首先尝试更新phone_phones表中id匹配的记录
        local updateResult1 = MySQL.update.await(
            "UPDATE phone_phones SET phone_number = ?, is_setup = 1 WHERE id = ?",
            { newPhoneNumber, ident }
        )
        
        -- 如果id没有匹配的记录，使用INSERT ... ON DUPLICATE KEY UPDATE创建新记录
        if (updateResult1 or 0) == 0 then
            MySQL.insert.await(
                "INSERT INTO phone_phones (id, owner_id, phone_number, is_setup) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE phone_number = ?, is_setup = 1",
                { ident, ident, newPhoneNumber, 1, newPhoneNumber }
            )
        end
        
        -- 同时更新所有匹配owner_id的记录（确保所有相关记录都被更新）
        MySQL.update.await(
            "UPDATE phone_phones SET phone_number = ? WHERE owner_id = ?",
            { newPhoneNumber, ident }
        )
        
        -- 更新phone_last_phone
        MySQL.insert.await(
            "INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?",
            { ident, newPhoneNumber, newPhoneNumber }
        )
    end
    
    -- 通知目标玩家客户端刷新手机号
    if Config.Purchase.NotifyClient then
        CreateThread(function()
            Wait(500)
            TriggerClientEvent('lb-shoujika:phoneNumberUpdated', targetId, newPhoneNumber)
            TriggerClientEvent('lb-phone:refreshPhoneNumber', targetId)
            TriggerClientEvent('lb-phone:updatePhoneNumber', targetId)
            TriggerClientEvent('phone:updatePhoneNumber', targetId)
        end)
    end
    
    -- 通知管理员
    Notify(source, _U('admin_operation_success'), 
        string.format("已将玩家 %s (ID: %d) 的手机号修改为: %s\n套餐: %s (ID: %d)", 
            targetPlayer.getName(), targetId, newPhoneNumber, package.name, packageId), 
        "success")
    
    -- 通知目标玩家
    if targetId ~= source then
        Notify(targetId, _U('admin_phone_updated'), 
            string.format("管理员已将您的手机号修改为: %s\n套餐: %s", newPhoneNumber, package.name), 
            "info")
    end
    
    -- 记录日志
    print(string.format("[LB-SHOUJIKA] 管理员 %s (ID: %d) 将玩家 %s (ID: %d) 的手机号修改为: %s，套餐: %s (ID: %d)",
        xPlayer.getName(), source, targetPlayer.getName(), targetId, newPhoneNumber, package.name, packageId))
end, false)

-- ============================================
-- 管理员命令：设置玩家信用额度
-- ============================================
RegisterCommand(Config.AdminCreditCommand.Command, function(source, args)
    if not Config.AdminCreditCommand.Enabled then
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return
    end
    
    -- 检查权限
    if not IsAdmin(source) then
        Notify(source, "权限不足", "您没有权限使用此命令", "error")
        return
    end
    
    -- 检查参数
    if #args < 2 then
        Notify(source, "命令格式错误", 
            string.format("用法: /%s [玩家ID] [信用额度(分)]\n示例: /%s 1 10000 (设置100元信用额度)", 
                Config.AdminCreditCommand.Command, Config.AdminCreditCommand.Command), 
            "error")
        return
    end
    
    local targetId = tonumber(args[1])
    local creditLimit = tonumber(args[2])
    
    if not targetId or not creditLimit then
        Notify(source, "参数错误", "玩家ID和信用额度必须是有效数字", "error")
        return
    end
    
    -- 验证信用额度范围
    if creditLimit < Config.Credit.MinCredit or creditLimit > Config.Credit.MaxCredit then
        Notify(source, "信用额度错误", 
            string.format("信用额度必须在 %d - %d 之间", 
                Config.Credit.MinCredit, Config.Credit.MaxCredit), 
            "error")
        return
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        Notify(source, "玩家不存在", string.format("ID %d 的玩家不在线", targetId), "error")
        return
    end
    
    local targetIdentifier = targetPlayer.identifier
    
    -- 获取玩家当前的手机号记录
    local currentNumber = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE identifier = ? AND status = 'active' LIMIT 1",
        { targetIdentifier }
    )
    
    if not currentNumber then
        Notify(source, "玩家没有手机号", "该玩家还没有激活的手机号", "error")
        return
    end
    
    -- 计算对应的信用评分（反向计算）
    local creditScore = math.floor(creditLimit / 10) -- 根据公式 credit_limit = credit_score * 10
    
    -- 更新信用额度和信用评分
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET credit_limit = ?, credit_score = ? WHERE phone_number = ?",
        { creditLimit, creditScore, currentNumber.phone_number }
    )
    
    -- 通知管理员
    Notify(source, "操作成功", 
        string.format("已将玩家 %s (ID: %d) 的信用额度设置为: $%d (信用评分: %d)", 
            targetPlayer.getName(), targetId, creditLimit, creditScore), 
        "success")
    
    -- 通知目标玩家
    if targetId ~= source then
        Notify(targetId, "信用额度已更新", 
            string.format("管理员已将您的信用额度设置为: $%d", creditLimit), 
            "info")
    end
    
    -- 记录日志
    print(string.format("[LB-SHOUJIKA] 管理员 %s (ID: %d) 将玩家 %s (ID: %d) 的信用额度设置为: $%d (信用评分: %d)",
        xPlayer.getName(), source, targetPlayer.getName(), targetId, creditLimit, creditScore))
end, false)

-- ============================================
-- 管理员命令：对指定号码充值话费
-- ============================================
RegisterCommand(Config.AdminRechargeCommand.Command, function(source, args)
    if not Config.AdminRechargeCommand.Enabled then
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return
    end
    
    -- 检查权限
    if not IsAdmin(source) then
        Notify(source, "权限不足", "您没有权限使用此命令", "error")
        return
    end
    
    -- 检查参数
    if #args < 2 then
        Notify(source, "命令格式错误", 
            string.format("用法: /%s [手机号] [充值金额(分)]\n示例: /%s 1234567 10000 (充值100元)", 
                Config.AdminRechargeCommand.Command, Config.AdminRechargeCommand.Command), 
            "error")
        return
    end
    
    local phoneNumber = args[1]
    local amount = tonumber(args[2])
    
    if not phoneNumber or not amount or amount <= 0 then
        Notify(source, "参数错误", "手机号和充值金额必须是有效值", "error")
        return
    end
    
    -- 验证充值金额范围
    if amount < Config.Recharge.MinAmount or amount > Config.Recharge.MaxAmount then
        Notify(source, "充值金额错误", 
            string.format("充值金额必须在 %d - %d 之间", 
                Config.Recharge.MinAmount, Config.Recharge.MaxAmount), 
            "error")
        return
    end
    
    -- 检查手机号是否存在
    local numberData = MySQL.single.await(
        "SELECT * FROM phone_operator_numbers WHERE phone_number = ?",
        { phoneNumber }
    )
    
    if not numberData then
        Notify(source, "手机号不存在", string.format("手机号 %s 不存在", phoneNumber), "error")
        return
    end
    
    -- 更新余额
    local newBalance = numberData.balance + amount
    local wasSuspended = (numberData.status == 'suspended')
    
    -- 检查是否需要恢复服务
    local newStatus = numberData.status
    if wasSuspended and Config.Balance.AutoResume and newBalance >= Config.Balance.ResumeThreshold then
        newStatus = 'active'
    end
    
    MySQL.update.await(
        "UPDATE phone_operator_numbers SET balance = ?, status = ?, last_recharge = NOW(), total_recharged = total_recharged + ? WHERE phone_number = ?",
        { newBalance, newStatus, amount, phoneNumber }
    )
    
    -- 记录充值
    MySQL.insert.await(
        [[INSERT INTO phone_operator_recharges 
            (phone_number, amount, balance_before, balance_after, method) 
            VALUES (?, ?, ?, ?, ?)]],
        { phoneNumber, amount, numberData.balance, newBalance, 'admin' }
    )
    
    -- 更新信用评分（充值增加信用）
    if Config.Credit.CreditScore.RechargeAmount > 0 then
        local scoreIncrease = math.floor(amount * Config.Credit.CreditScore.RechargeAmount)
        if scoreIncrease > 0 then
            local newScore = math.min(
                Config.Credit.CreditScore.MaxScore,
                (numberData.credit_score or Config.Credit.CreditScore.InitialScore) + scoreIncrease
            )
            local newCreditLimit = Config.Credit.CreditFormula(newScore)
            
            MySQL.update.await(
                "UPDATE phone_operator_numbers SET credit_score = ?, credit_limit = ? WHERE phone_number = ?",
                { newScore, newCreditLimit, phoneNumber }
            )
        end
    end
    
    -- 通知管理员
    local message = string.format("已为手机号 %s 充值 $%d\n当前余额：$%d", phoneNumber, amount, newBalance)
    if wasSuspended and newStatus == 'active' then
        message = message .. "\n服务已自动恢复"
    end
    Notify(source, "充值成功", message, "success")
    
    -- 查找并通知号码所有者（如果在线）
    for _, playerId in ipairs(GetPlayers()) do
        local playerIdentifier = GetIdentifier(tonumber(playerId))
        if playerIdentifier == numberData.identifier then
            local ownerSrc = tonumber(playerId)
            if ownerSrc then
                local ownerMessage = string.format("管理员已为您的手机号充值 $%d\n当前余额：$%d", amount, newBalance)
                if wasSuspended and newStatus == 'active' then
                    ownerMessage = ownerMessage .. "\n服务已自动恢复"
                end
                Notify(ownerSrc, "话费已充值", ownerMessage, "success")
            end
            break
        end
    end
    
    -- 记录日志
    print(string.format("[LB-SHOUJIKA] 管理员 %s (ID: %d) 为手机号 %s 充值 $%d，余额：$%d -> $%d",
        xPlayer.getName(), source, phoneNumber, amount, numberData.balance, newBalance))
end, false)

-- ============================================
-- 周租费自动扣除（定时任务）
-- ============================================
CreateThread(function()
    if not Config.WeeklyFee.Enabled then
        return
    end
    
    while true do
        Wait(3600000) -- 每小时检查一次
        
        if not Config.WeeklyFee.AutoDeduct then
            goto continue
        end
        
        local numbers = MySQL.query.await(
            "SELECT * FROM phone_operator_numbers WHERE status = 'active'"
        )
        
        if numbers then
            local currentTime = os.time()
            local currentDate = os.date("*t", currentTime)
            
            -- 检查是否到了扣费时间（根据配置的星期和小时）
            local isDeductDay = false
            if Config.WeeklyFee.DeductDay then
                -- 0=周日, 1=周一, ..., 6=周六
                local currentDayOfWeek = currentDate.wday == 1 and 7 or (currentDate.wday - 1) -- 转换为1=周一, 7=周日
                isDeductDay = (currentDayOfWeek == Config.WeeklyFee.DeductDay) and 
                              (currentDate.hour == (Config.WeeklyFee.DeductHour or 0)) and
                              (currentDate.min == (Config.WeeklyFee.DeductMinute or 0))
            end
            
            for _, numberData in ipairs(numbers) do
                local package = MySQL.single.await(
                    "SELECT weekly_fee FROM phone_operator_packages WHERE id = ?",
                    { numberData.package_id }
                )
                
                if package and package.weekly_fee > 0 then
                    -- 检查是否到了扣费时间
                    local lastCharge = numberData.last_weekly_fee
                    local shouldDeduct = false
                    
                    if isDeductDay then
                        -- 如果到了扣费时间，检查上次扣费是否在今天或更早
                        if not lastCharge then
                            shouldDeduct = true
                        else
                            -- 如果lastCharge是字符串，需要转换为时间戳
                            local lastChargeTime
                            if type(lastCharge) == "string" then
                                local year, month, day, hour, min, sec = lastCharge:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                                if year and month and day and hour and min and sec then
                                    lastChargeTime = os.time({year=tonumber(year) or 2024, month=tonumber(month) or 1, day=tonumber(day) or 1, hour=tonumber(hour) or 0, min=tonumber(min) or 0, sec=tonumber(sec) or 0})
                                else
                                    shouldDeduct = true
                                    goto skip_deduct_check
                                end
                            else
                                lastChargeTime = lastCharge
                            end
                            local daysSince = math.floor((currentTime - lastChargeTime) / 86400)
                            -- 确保至少7天
                            if daysSince >= 7 then
                                shouldDeduct = true
                            end
                        end
                        ::skip_deduct_check::
                    else
                        -- 兼容旧逻辑：检查是否超过7天
                        if lastCharge then
                            local lastChargeTime
                            if type(lastCharge) == "string" then
                                local year, month, day, hour, min, sec = lastCharge:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                                if year and month and day and hour and min and sec then
                                    lastChargeTime = os.time({year=tonumber(year) or 2024, month=tonumber(month) or 1, day=tonumber(day) or 1, hour=tonumber(hour) or 0, min=tonumber(min) or 0, sec=tonumber(sec) or 0})
                                else
                                    shouldDeduct = true
                                    goto skip_old_deduct_check
                                end
                            else
                                lastChargeTime = lastCharge
                            end
                            local daysSince = math.floor((currentTime - lastChargeTime) / 86400)
                            if daysSince >= 7 then
                                shouldDeduct = true
                            end
                        end
                    end
                    ::skip_old_deduct_check::
                    
                    if shouldDeduct then
                        -- 通知玩家（如果启用）
                        if Config.WeeklyFee.NotifyBeforeDeduct then
                            for _, playerId in ipairs(GetPlayers()) do
                                local player = ESX.GetPlayerFromId(tonumber(playerId))
                                if player and player.identifier == numberData.identifier then
                                    Notify(tonumber(playerId), "周租费提醒", 
                                        string.format("您的手机号 %s 将扣除周租费 $%d", 
                                            numberData.phone_number, package.weekly_fee), 
                                        "info")
                                    break
                                end
                            end
                        end
                        
                        -- 扣除周租费
                        exports['lb-shoujika']:chargeBalance(
                            numberData.phone_number,
                            package.weekly_fee,
                            'weekly_fee',
                            '周租费',
                            {}
                        )
                        
                        MySQL.update.await(
                            "UPDATE phone_operator_numbers SET last_weekly_fee = NOW() WHERE phone_number = ?",
                            { numberData.phone_number }
                        )
                    end
                end
            end
        end
        
        ::continue::
    end
end)

-- ============================================
-- 免费分钟数重置（定时任务）
-- ============================================
CreateThread(function()
    while true do
        Wait(3600000) -- 每小时检查一次
        
        local numbers = MySQL.query.await(
            "SELECT phone_number, weekly_free_minutes_reset FROM phone_operator_numbers WHERE status = 'active'"
        )
        
        if numbers then
            local currentTime = os.time()
            local currentDate = os.date("*t", currentTime)
            
            -- 检查是否到了重置时间（根据配置的星期和小时）
            local isResetDay = false
            if Config.FreeMinutes.ResetDay then
                local currentDayOfWeek = currentDate.wday == 1 and 7 or (currentDate.wday - 1)
                isResetDay = (currentDayOfWeek == Config.FreeMinutes.ResetDay) and 
                             (currentDate.hour == (Config.FreeMinutes.ResetHour or 0)) and
                             (currentDate.min == (Config.FreeMinutes.ResetMinute or 0))
            end
            
            if isResetDay then
                for _, numberData in ipairs(numbers) do
                    local resetTime = numberData.weekly_free_minutes_reset
                    local shouldReset = false
                    
                    if not resetTime then
                        shouldReset = true
                    else
                        -- 如果resetTime是字符串，需要转换为时间戳
                        local resetTimeStamp
                        if type(resetTime) == "string" then
                            -- MySQL返回的datetime字符串，转换为时间戳
                            local year, month, day, hour, min, sec = resetTime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                            if year and month and day and hour and min and sec then
                                resetTimeStamp = os.time({year=tonumber(year) or 2024, month=tonumber(month) or 1, day=tonumber(day) or 1, hour=tonumber(hour) or 0, min=tonumber(min) or 0, sec=tonumber(sec) or 0})
                            else
                                shouldReset = true
                                goto skip_reset_check
                            end
                        else
                            resetTimeStamp = resetTime
                        end
                        local daysSince = math.floor((currentTime - resetTimeStamp) / 86400)
                        -- 确保至少7天
                        if daysSince >= 7 then
                            shouldReset = true
                        end
                    end
                    ::skip_reset_check::
                    
                    if shouldReset then
                        MySQL.update.await(
                            "UPDATE phone_operator_numbers SET used_free_minutes = 0, weekly_free_minutes_reset = NOW() WHERE phone_number = ?",
                            { numberData.phone_number }
                        )
                        LogDebug("重置手机号 %s 的免费分钟数", numberData.phone_number)
                    end
                end
            end
        end
    end
end)

-- ============================================
-- 余额检查（定时任务）
-- ============================================
CreateThread(function()
    while true do
        Wait(Config.Balance.CheckInterval or 300000) -- 默认5分钟检查一次
        
        local numbers = MySQL.query.await(
            "SELECT * FROM phone_operator_numbers WHERE status = 'active'"
        )
        
        if numbers then
            for _, numberData in ipairs(numbers) do
                -- 检查低余额警告
                if numberData.balance <= Config.Balance.LowBalanceWarning then
                    for _, playerId in ipairs(GetPlayers()) do
                        local player = ESX.GetPlayerFromId(tonumber(playerId))
                        if player and player.identifier == numberData.identifier then
                            if Config.Notifications.LowBalance then
                                Notify(tonumber(playerId), _U('notify_low_balance'), 
                                    _U('balance_low_warning', numberData.balance), 
                                    "warning")
                            end
                            break
                        end
                    end
                end
                
                -- 检查自动暂停
                if Config.Balance.AutoSuspend and numberData.balance <= Config.Balance.AutoSuspendThreshold then
                    if numberData.status ~= 'suspended' then
                        MySQL.update.await(
                            "UPDATE phone_operator_numbers SET status = 'suspended' WHERE phone_number = ?",
                            { numberData.phone_number }
                        )
                        
                        for _, playerId in ipairs(GetPlayers()) do
                            local player = ESX.GetPlayerFromId(tonumber(playerId))
                            if player and player.identifier == numberData.identifier then
                                Notify(tonumber(playerId), _U('notify_service_suspended'), 
                                    _U('balance_auto_suspend', numberData.balance), 
                                    "error")
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================
-- 自动收回欠费号码（定时任务）
-- ============================================
CreateThread(function()
    while true do
        Wait(Config.AutoReclaim.CheckInterval or 3600000) -- 默认每小时检查一次
        
        if not Config.AutoReclaim.Enabled then
            Wait(Config.AutoReclaim.CheckInterval or 3600000)
            goto continue
        end
        
        -- 查找所有欠费且状态为suspended或overdue的号码
        -- 使用UNIX_TIMESTAMP获取时间戳，方便计算天数
        local overdueNumbers = MySQL.query.await(
            [[SELECT n.*, p.name as package_name,
              UNIX_TIMESTAMP(n.last_recharge) as last_recharge_timestamp
              FROM phone_operator_numbers n
              LEFT JOIN phone_operator_packages p ON n.package_id = p.id
              WHERE n.status IN ('suspended', 'overdue') 
              AND n.balance < 0
              AND n.last_recharge IS NOT NULL]]
        )
        
        if overdueNumbers then
            local currentTime = os.time()
            
            for _, numberData in ipairs(overdueNumbers) do
                -- 计算欠费天数
                local rechargeTimestamp = numberData.last_recharge_timestamp
                if not rechargeTimestamp or rechargeTimestamp == 0 then
                    -- 如果没有时间戳，跳过此号码
                    goto continue_number
                end
                
                local daysOverdue = math.floor((currentTime - rechargeTimestamp) / 86400)
                
                -- 检查是否达到收回天数
                if daysOverdue >= Config.AutoReclaim.OverdueDays then
                    -- 收回前通知（如果启用）
                    if Config.AutoReclaim.NotifyBeforeReclaim and 
                       daysOverdue == Config.AutoReclaim.OverdueDays then
                        -- 查找在线玩家并通知
                        for _, playerId in ipairs(GetPlayers()) do
                            local playerIdentifier = GetIdentifier(tonumber(playerId))
                            if playerIdentifier == numberData.identifier then
                                local ownerSrc = tonumber(playerId)
                                if ownerSrc then
                                    Notify(ownerSrc, "号码即将被收回", 
                                        string.format("您的手机号 %s 已欠费 %d 天，即将被收回。请及时充值！", 
                                            numberData.phone_number, daysOverdue), 
                                        "warning")
                                end
                                break
                            end
                        end
                    end
                    
                    -- 执行收回
                    if daysOverdue >= Config.AutoReclaim.OverdueDays then
                        -- 更新状态为已过期
                        MySQL.update.await(
                            "UPDATE phone_operator_numbers SET status = ? WHERE phone_number = ?",
                            { Config.AutoReclaim.ReclaimStatus, numberData.phone_number }
                        )
                        
                        -- 从phone_phones表中移除（释放号码）
                        -- 注意：phone_phones表的phone_number列不允许NULL，所以直接删除匹配的记录
                        MySQL.update.await(
                            "DELETE FROM phone_phones WHERE phone_number = ?",
                            { numberData.phone_number }
                        )
                        
                        -- 从phone_last_phone表中移除
                        MySQL.update.await(
                            "DELETE FROM phone_last_phone WHERE phone_number = ?",
                            { numberData.phone_number }
                        )
                        
                        -- 查找并通知号码所有者（如果在线）
                        for _, playerId in ipairs(GetPlayers()) do
                            local playerIdentifier = GetIdentifier(tonumber(playerId))
                            if playerIdentifier == numberData.identifier then
                                local ownerSrc = tonumber(playerId)
                                if ownerSrc then
                                    Notify(ownerSrc, "号码已被收回", 
                                        string.format("您的手机号 %s 因欠费 %d 天未充值已被收回", 
                                            numberData.phone_number, daysOverdue), 
                                        "error")
                                end
                                break
                            end
                        end
                        
                        -- 记录日志
                        print(string.format("[LB-SHOUJIKA] 自动收回号码: %s, 所有者: %s, 欠费天数: %d, 余额: $%d",
                            numberData.phone_number, numberData.identifier, daysOverdue, numberData.balance))
                    end
                end
                ::continue_number::
            end
        end
        
        ::continue::
    end
end)

-- ============================================
-- 调试命令：检查手机号状态
-- ============================================
RegisterCommand('checkphone', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- 检查权限（可选：只有管理员可以使用）
    -- if xPlayer.getGroup() ~= 'admin' then
    --     TriggerClientEvent('esx:showNotification', source, '~r~你没有权限使用此命令')
    --     return
    -- end
    
    local identifier = GetIdentifier(source)
    if not identifier then
        LogWarning("玩家 %d 标识符获取失败", source)
        TriggerClientEvent('esx:showNotification', source, '~r~无法获取玩家标识符')
        return
    end
    
    -- 获取所有标识符
    local identifiers = {}
    table.insert(identifiers, identifier)
    local playerIdentifiers = GetPlayerIdentifiers(source)
    for _, ident in ipairs(playerIdentifiers) do
        local found = false
        for _, existing in ipairs(identifiers) do
            if existing == ident then
                found = true
                break
            end
        end
        if not found then
            table.insert(identifiers, ident)
        end
    end
    
    LogInfo("玩家 %d 调试检查手机号状态", source)
    LogInfo("主标识符: %s", identifier)
    LogInfo("所有标识符数量: %d", #identifiers)
    
    -- 检查phone_phones表
    for _, ident in ipairs(identifiers) do
        local phoneData = MySQL.query.await(
            "SELECT id, owner_id, phone_number, is_setup FROM phone_phones WHERE id = ? OR owner_id = ?",
            { ident, ident }
        )
        if phoneData and #phoneData > 0 then
            LogInfo("phone_phones表（标识符: %s）:", ident)
            for _, row in ipairs(phoneData) do
                LogInfo("  - id: %s, owner_id: %s, phone_number: %s, is_setup: %s", 
                    tostring(row.id), tostring(row.owner_id), tostring(row.phone_number), tostring(row.is_setup))
            end
        else
            LogInfo("phone_phones表（标识符: %s）: 无记录", ident)
        end
    end
    
    -- 检查phone_last_phone表
    for _, ident in ipairs(identifiers) do
        local lastPhone = MySQL.single.await(
            "SELECT id, phone_number FROM phone_last_phone WHERE id = ?",
            { ident }
        )
        if lastPhone then
            LogInfo("phone_last_phone表（标识符: %s）: phone_number = %s", ident, tostring(lastPhone.phone_number))
        else
            LogInfo("phone_last_phone表（标识符: %s）: 无记录", ident)
        end
    end
    
    -- 检查phone_operator_numbers表
    local operatorNumbers = MySQL.query.await(
        "SELECT phone_number, status, balance FROM phone_operator_numbers WHERE identifier = ?",
        { identifier }
    )
    if operatorNumbers and #operatorNumbers > 0 then
        LogInfo("phone_operator_numbers表（主标识符: %s）:", identifier)
        for _, row in ipairs(operatorNumbers) do
            LogInfo("  - phone_number: %s, status: %s, balance: %s", 
                tostring(row.phone_number), tostring(row.status), tostring(row.balance))
        end
    else
        LogInfo("phone_operator_numbers表（主标识符: %s）: 无记录", identifier)
    end
    
    -- 发送通知给玩家
    TriggerClientEvent('esx:showNotification', source, '~g~手机号状态已检查，请查看服务器控制台日志')
end, false)

-- ============================================
-- 老板管理功能
-- ============================================

-- 批量生成靓号并保存（老板回调）
ESX.RegisterServerCallback('lb-shoujika:boss:batchGeneratePremiumNumbers', function(source, cb, packageId, count)
    if not IsBoss(source) then
        return cb(false, "权限不足")
    end
    
    local identifier = GetIdentifier(source)
    if not identifier then
        return cb(false, "无法获取标识符")
    end
    
    count = count or Config.Boss.BatchGenerate.DefaultCount
    count = math.max(Config.Boss.BatchGenerate.MinCount, math.min(Config.Boss.BatchGenerate.MaxCount, count))
    
    LogInfo("老板 %s (ID: %d) 请求批量生成靓号，套餐ID: %d, 数量: %d", identifier, source, packageId, count)
    
    local savedCount, message = BatchGenerateAndSavePremiumNumbers(packageId, count, identifier)
    
    if savedCount > 0 then
        cb(true, message)
    else
        cb(false, message or "生成失败")
    end
end)

-- 获取已上架靓号列表（老板回调）
ESX.RegisterServerCallback('lb-shoujika:boss:getPremiumNumbersList', function(source, cb, packageId, status)
    if not IsBoss(source) then
        return cb({})
    end
    
    status = status or 'available'
    
    local whereClause = "WHERE package_id = ?"
    local params = { packageId }
    
    if status ~= 'all' then
        whereClause = whereClause .. " AND status = ?"
        table.insert(params, status)
    end
    
    local premiumNumbers = MySQL.query.await(
        string.format([[
            SELECT 
                id, phone_number, premium_type, price_multiplier, 
                base_price, final_price, status, sold_to, 
                sold_at, created_at
            FROM phone_operator_premium_numbers
            %s
            ORDER BY status, price_multiplier DESC, final_price DESC
            LIMIT 500
        ]], whereClause),
        params
    )
    
    cb(premiumNumbers or {})
end)

-- 下架靓号（老板回调）
ESX.RegisterServerCallback('lb-shoujika:boss:removePremiumNumber', function(source, cb, premiumNumberId)
    if not IsBoss(source) then
        return cb(false, "权限不足")
    end
    
    -- 检查是否为可购买状态
    local premiumNumber = MySQL.single.await(
        "SELECT * FROM phone_operator_premium_numbers WHERE id = ?",
        { premiumNumberId }
    )
    
    if not premiumNumber then
        return cb(false, "靓号不存在")
    end
    
    if premiumNumber.status == 'sold' then
        return cb(false, "已售出的靓号无法下架")
    end
    
    -- 删除记录
    MySQL.query.await(
        "DELETE FROM phone_operator_premium_numbers WHERE id = ?",
        { premiumNumberId }
    )
    
    LogInfo("老板 %s (ID: %d) 下架靓号: %s", GetIdentifier(source), source, premiumNumber.phone_number)
    
    cb(true, "下架成功")
end)

-- 获取套餐列表（老板回调，包含所有套餐）
ESX.RegisterServerCallback('lb-shoujika:boss:getPackages', function(source, cb)
    if not IsBoss(source) then
        return cb({})
    end
    
    local packages = MySQL.query.await(
        "SELECT * FROM phone_operator_packages ORDER BY price ASC"
    )
    
    cb(packages or {})
end)

-- 检查老板权限（客户端回调）
ESX.RegisterServerCallback('lb-shoujika:checkBossPermission', function(source, cb)
    cb(IsBoss(source))
end)

