-- ============================================
-- LB手机运营商系统 - 客户端
-- ============================================

-- 加载ESX
ESX = exports['es_extended']:getSharedObject()

-- 等待玩家加载完成后发送通知
CreateThread(function()
    Wait(2000) -- 等待玩家完全加载
    TriggerServerEvent('lb-shoujika:clientLoaded')
    TriggerServerEvent('lb-shoujika:log', 'info', '客户端脚本已加载并初始化')
    print("^5[LB-SHOUJIKA] 客户端脚本已初始化^7")
end)

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
    -- FiveM客户端环境不支持os.date，使用游戏时间作为替代
    local hours = GetClockHours()
    local minutes = GetClockMinutes()
    local seconds = GetClockSeconds()
    local timeStr = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    return string.format("[%s] ", timeStr)
end

function Log(level, message, ...)
    if not ShouldLog(level) then return end
    
    local formattedMessage = string.format(message, ...)
    local prefix = FormatTimestamp()
    local sourceTag = (Config and Config.Logging and Config.Logging.ShowSource) and "[客户端] " or ""
    local fullMessage = string.format("%s%s[LB-SHOUJIKA] %s: %s", prefix, sourceTag, level:upper(), formattedMessage)
    
    local f8Enabled = true
    if Config and Config.Logging and Config.Logging.F8 then
        f8Enabled = Config.Logging.F8.Enabled ~= false
    end
    
    if f8Enabled then
        print(fullMessage)
    end
    
    -- 同时输出到服务器控制台（通过服务器事件）
    TriggerServerEvent('lb-shoujika:log', level, formattedMessage)
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
-- 通知函数
-- ============================================
local function Notify(title, message, type, duration)
    type = type or "info"
    duration = duration or Config.Notification.Duration
    
    if Config.Notification.System == "okokNotify" then
        exports['okokNotify']:Alert(title, message, duration, type)
    else
        ESX.ShowNotification(message)
    end
end

-- ============================================
-- 手机号更新事件处理
-- ============================================
RegisterNetEvent('lb-shoujika:phoneNumberUpdated')
AddEventHandler('lb-shoujika:phoneNumberUpdated', function(phoneNumber)
    LogInfo("收到手机号更新通知: %s", phoneNumber)
    
    if Config.Purchase.NotifyClient then
        local message = _U('notify_phone_installed') .. ": " .. phoneNumber
        message = message .. "\n提示: 请关闭并重新打开手机以查看新号码"
        Notify(_U('notify_phone_updated'), message, "success")
    end
    
    -- 通知lb-phone系统刷新手机号
    CreateThread(function()
        -- 等待数据库更新完成
        Citizen.Wait(2000)
        
        -- 尝试多种方式刷新lb-phone系统
        if exports['lb-phone'] then
            -- 方式1: 触发刷新事件（安全，不会报错）
            TriggerEvent('lb-phone:refreshPhoneNumber')
            TriggerEvent('lb-phone:updatePhoneNumber')
            TriggerEvent('phone:updatePhoneNumber')
            TriggerEvent('lb-phone:reload')
            TriggerEvent('phone:reload')
            
            -- 方式2: 安全地尝试调用导出函数（使用pcall避免错误）
            local success, result = pcall(function()
                if exports['lb-phone'].updatePhoneNumber then
                    return exports['lb-phone']:updatePhoneNumber()
                end
            end)
            if success then
                LogDebug("成功调用lb-phone:updatePhoneNumber")
            end
            
            success, result = pcall(function()
                if exports['lb-phone'].reloadPhone then
                    return exports['lb-phone']:reloadPhone()
                end
            end)
            if success then
                LogDebug("成功调用lb-phone:reloadPhone")
            end
            
            LogInfo("已尝试刷新lb-phone系统，手机号: %s", phoneNumber)
        else
            LogWarning("lb-phone资源未找到，无法刷新手机号")
        end
        
        -- 额外等待后再次尝试（确保数据库完全同步）
        Citizen.Wait(3000)
        if exports['lb-phone'] then
            TriggerEvent('lb-phone:refreshPhoneNumber')
            TriggerEvent('lb-phone:updatePhoneNumber')
            LogDebug("二次刷新lb-phone系统")
        end
    end)
end)

-- ============================================
-- 手机号删除事件处理
-- ============================================
RegisterNetEvent('lb-shoujika:phoneNumberDeleted')
AddEventHandler('lb-shoujika:phoneNumberDeleted', function(phoneNumber)
    LogInfo("收到手机号删除通知: %s", phoneNumber)
    
    -- 通知lb-phone系统刷新手机号
    CreateThread(function()
        Citizen.Wait(2000)
        
        if exports['lb-phone'] then
            -- 触发刷新事件
            TriggerEvent('lb-phone:refreshPhoneNumber')
            TriggerEvent('lb-phone:updatePhoneNumber')
            TriggerEvent('phone:updatePhoneNumber')
            TriggerEvent('lb-phone:reload')
            TriggerEvent('phone:reload')
            
            -- 安全地尝试调用导出函数
            pcall(function()
                if exports['lb-phone'].updatePhoneNumber then
                    exports['lb-phone']:updatePhoneNumber()
                end
            end)
            
            pcall(function()
                if exports['lb-phone'].reloadPhone then
                    exports['lb-phone']:reloadPhone()
                end
            end)
            
            LogInfo("已尝试刷新lb-phone系统（删除后）")
        end
    end)
end)

local npcSpawned = false
local npcPed = nil
local npcBlip = nil
local isNearNPC = false

-- 已移动到文件开头

-- ============================================
-- NPC生成函数
-- ============================================
local function SpawnNPC()
    -- 检查是否已经生成过NPC，避免重复生成
    if npcSpawned and npcPed and DoesEntityExist(npcPed) then
        print("^3[LB-SHOUJIKA] NPC已经存在，跳过重复生成^7")
        return
    end
    
    print("^5[LB-SHOUJIKA] ===========================================^7")
    print("^5[LB-SHOUJIKA] NPC生成函数被调用^7")
    print("^5[LB-SHOUJIKA] ===========================================^7")
    TriggerServerEvent('lb-shoujika:log', 'info', 'NPC生成函数被调用')
    
    -- 检查配置
    if not Config then
        print("^1[LB-SHOUJIKA] 错误: Config未加载！^7")
        return
    end
    
    if not Config.NPC then
        print("^1[LB-SHOUJIKA] 错误: Config.NPC未找到！^7")
        return
    end
    
    print(string.format("^3[LB-SHOUJIKA] NPC配置检查: Enabled=%s^7", tostring(Config.NPC.Enabled)))
    
    if not Config.NPC.Enabled then 
        print("^3[LB-SHOUJIKA] NPC功能已禁用^7")
        LogInfo("NPC功能已禁用")
        return 
    end
    
    print("^2[LB-SHOUJIKA] 开始NPC生成流程...^7")
    LogInfo("开始NPC生成流程")
    
    -- 等待游戏完全加载
    print("^3[LB-SHOUJIKA] 等待游戏完全加载...^7")
    local waitCount = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and waitCount < 50 do
        Wait(100)
        waitCount = waitCount + 1
    end
    
    if waitCount >= 50 then
        print("^3[LB-SHOUJIKA] 警告: 碰撞加载超时，继续执行...^7")
    end
    
    Wait(2000) -- 额外等待确保地图加载完成
    print("^2[LB-SHOUJIKA] 游戏加载完成，开始生成NPC^7")
    
    LogInfo("开始生成NPC，位置: x=%.2f, y=%.2f, z=%.2f, 朝向: %.2f", 
        Config.NPC.Coords.x, Config.NPC.Coords.y, Config.NPC.Coords.z, Config.NPC.Coords.w)
    
    print(string.format("^3[LB-SHOUJIKA] NPC坐标: x=%.2f, y=%.2f, z=%.2f, 朝向=%.2f^7", 
        Config.NPC.Coords.x, Config.NPC.Coords.y, Config.NPC.Coords.z, Config.NPC.Coords.w))
    
    -- 请求NPC模型
    print(string.format("^3[LB-SHOUJIKA] 请求NPC模型: %d^7", Config.NPC.Model))
    RequestModel(Config.NPC.Model)
    local timeout = 0
    while not HasModelLoaded(Config.NPC.Model) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(Config.NPC.Model) then
        print(string.format("^1[LB-SHOUJIKA] 错误: NPC模型加载超时: %d^7", Config.NPC.Model))
        LogError("NPC模型加载超时: %d", Config.NPC.Model)
        return
    end
    
    print("^2[LB-SHOUJIKA] NPC模型加载成功^7")
    
    -- 创建NPC
    print("^3[LB-SHOUJIKA] 正在创建NPC实体...^7")
    npcPed = CreatePed(4, Config.NPC.Model, Config.NPC.Coords.x, Config.NPC.Coords.y, Config.NPC.Coords.z - 1.0, Config.NPC.Coords.w, false, true)
    
    if not npcPed then
        print("^1[LB-SHOUJIKA] 错误: CreatePed返回nil^7")
        LogError("NPC创建失败！CreatePed返回nil")
        return
    end
    
    Wait(100) -- 等待实体创建完成
    
    if not DoesEntityExist(npcPed) then
        print(string.format("^1[LB-SHOUJIKA] 错误: NPC实体不存在，ID: %d^7", npcPed))
        LogError("NPC创建失败！实体不存在")
        return
    end
    
    print(string.format("^2[LB-SHOUJIKA] NPC实体创建成功，ID: %d^7", npcPed))
    
    SetEntityHeading(npcPed, Config.NPC.Coords.w)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetEntityCanBeDamaged(npcPed, false)
    SetPedCanRagdollFromPlayerImpact(npcPed, false)
    SetPedFleeAttributes(npcPed, 0, false)
    SetPedCombatAttributes(npcPed, 46, true)
    
    -- 启动NPC动作
    TaskStartScenarioInPlace(npcPed, Config.NPC.Scenario, 0, true)
    
    npcSpawned = true
    print(string.format("^2[LB-SHOUJIKA] NPC生成成功，实体ID: %d^7", npcPed))
    LogInfo("NPC生成成功，实体ID: %d", npcPed)
    
    -- 创建Blip（地图标记）
    if Config.NPC.Blip then
        print(string.format("^3[LB-SHOUJIKA] Blip配置检查: Enabled=%s^7", tostring(Config.NPC.Blip.Enabled)))
    else
        print("^1[LB-SHOUJIKA] 错误: Config.NPC.Blip未找到！^7")
    end
    
    if Config.NPC.Blip and Config.NPC.Blip.Enabled then
        print("^3[LB-SHOUJIKA] 开始创建地图标记...^7")
        Wait(500) -- 等待一下再创建Blip
        
        npcBlip = AddBlipForCoord(Config.NPC.Coords.x, Config.NPC.Coords.y, Config.NPC.Coords.z)
        print(string.format("^3[LB-SHOUJIKA] AddBlipForCoord返回: %s^7", tostring(npcBlip)))
        
        if npcBlip then
            print(string.format("^3[LB-SHOUJIKA] 检查Blip是否存在: %s^7", tostring(DoesBlipExist(npcBlip))))
        end
        
        if npcBlip and DoesBlipExist(npcBlip) then
            print("^2[LB-SHOUJIKA] Blip创建成功，开始设置属性...^7")
            SetBlipSprite(npcBlip, Config.NPC.Blip.Sprite)
            SetBlipColour(npcBlip, Config.NPC.Blip.Color)
            SetBlipScale(npcBlip, Config.NPC.Blip.Scale)
            SetBlipAsShortRange(npcBlip, false) -- 改为全局显示，不需要靠近就能看到
            SetBlipDisplay(npcBlip, 4) -- 始终显示
            
            -- 设置标记名称
            local blipName = _U('npc_blip_name') or Config.NPC.Blip.Name or "手机运营商"
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blipName)
            EndTextCommandSetBlipName(npcBlip)
            
            print(string.format("^2[LB-SHOUJIKA] 地图标记创建成功: %s (Blip ID: %d)^7", blipName, npcBlip))
            LogInfo("地图标记已创建: %s (Blip ID: %d, 图标ID: %d, 颜色: %d, 坐标: %.2f, %.2f, %.2f)", 
                blipName, npcBlip, Config.NPC.Blip.Sprite, Config.NPC.Blip.Color, 
                Config.NPC.Coords.x, Config.NPC.Coords.y, Config.NPC.Coords.z)
        else
            print(string.format("^1[LB-SHOUJIKA] 错误: 创建地图标记失败！Blip ID: %s, 存在: %s^7", 
                tostring(npcBlip), tostring(npcBlip and DoesBlipExist(npcBlip))))
            LogError("创建地图标记失败！Blip ID: %s", tostring(npcBlip))
        end
    else
        print("^3[LB-SHOUJIKA] 地图标记功能已禁用^7")
        LogInfo("地图标记功能已禁用")
    end
    
    -- 添加ox_target交互（等待NPC完全创建）
    CreateThread(function()
        Wait(1000) -- 等待NPC完全创建
        
        local oxTarget = exports.ox_target or exports['ox_target']
        if oxTarget and npcPed and DoesEntityExist(npcPed) then
            local success, err = pcall(function()
                oxTarget:addLocalEntity(npcPed, {
                    {
                        name = 'lb-shoujika-operator',
                        icon = 'fa-solid fa-mobile-screen',
                        label = _U('npc_interact') or '打开手机运营商',
                        onSelect = function()
                            LogInfo("玩家通过ox_target打开运营商菜单")
                            -- 检查是否为老板
                            ESX.TriggerServerCallback('lb-shoujika:checkBossPermission', function(isBoss)
                                if isBoss then
                                    -- 老板可以选择打开管理面板或普通菜单
                                    local options = {}
                                    
                                    -- 普通玩家菜单选项
                                    table.insert(options, {
                                        title = _U('menu_operator'),
                                        description = _U('boss_normal_menu_desc') or "购买手机号、充值等普通功能",
                                        icon = 'fa-solid fa-mobile-screen-button',
                                        onSelect = function()
                                            OpenOperatorMenu()
                                        end
                                    })
                                    
                                    -- 老板管理面板选项
                                    table.insert(options, {
                                        title = _U('boss_menu_title'),
                                        description = _U('boss_management_menu_desc') or "靓号管理、批量生成等功能",
                                        icon = 'fa-solid fa-crown',
                                        onSelect = function()
                                            TriggerEvent('lb-shoujika:openBossMenu')
                                        end
                                    })
                                    
                                    exports.ox_lib:registerContext({
                                        id = 'lb-shoujika-boss-select',
                                        title = _U('boss_select_menu') or '选择菜单',
                                        options = options
                                    })
                                    
                                    exports.ox_lib:showContext('lb-shoujika-boss-select')
                                else
                                    -- 普通玩家直接打开普通菜单
                                    OpenOperatorMenu()
                                end
                            end)
                        end
                    }
                })
            end)
            
            if success then
                LogInfo("已为NPC添加ox_target交互")
                print("^2[LB-SHOUJIKA] ox_target交互已添加^7")
            else
                LogError("添加ox_target交互失败: %s", tostring(err))
                print("^1[LB-SHOUJIKA] ox_target交互添加失败: " .. tostring(err) .. "^7")
            end
        else
            if not oxTarget then
                LogWarning("ox_target未找到，无法添加交互点")
                print("^3[LB-SHOUJIKA] 警告: ox_target未找到，请确保ox_target资源已启动^7")
            end
        end
    end)
    
    print("^2[LB-SHOUJIKA] NPC生成流程完成^7")
end

-- ============================================
-- 资源启动日志
-- ============================================
CreateThread(function()
    -- 立即输出启动信息（不依赖配置）
    print("============================================")
    print("[LB-SHOUJIKA] 客户端脚本正在启动...")
    
    Wait(3000) -- 等待资源完全加载，确保Config已加载
    
    -- 检查配置是否加载
    if not Config then
        print("[LB-SHOUJIKA] 警告: Config未加载，使用默认日志设置")
        -- 使用默认设置
        Config = {}
        Config.Logging = {
            Enabled = true,
            Level = "info",
            ShowTimestamp = true,
            ShowSource = true,
            Console = { Enabled = true, Colors = true },
            F8 = { Enabled = true }
        }
    end
    
    if not Config.Logging then
        print("[LB-SHOUJIKA] 警告: Config.Logging未找到，使用默认日志设置")
        Config.Logging = {
            Enabled = true,
            Level = "info",
            ShowTimestamp = true,
            ShowSource = true,
            Console = { Enabled = true, Colors = true },
            F8 = { Enabled = true }
        }
    end
    
    -- 检查ESX是否加载
    if not ESX then
        print("[LB-SHOUJIKA] 警告: ESX未加载！请确保es_extended资源已启动")
    end
    
    -- 输出详细启动信息
    if Config.Logging.Enabled then
        LogInfo("============================================")
        LogInfo("LB手机运营商系统客户端已启动")
        LogInfo("ESX框架: %s", ESX and "已加载" or "未加载")
        LogInfo("日志系统: 已启用")
        LogInfo("日志级别: %s", Config.Logging.Level or "info")
        LogInfo("调试模式: %s", (Config.Debug and "开启" or "关闭"))
        LogInfo("F8控制台: %s", ((Config.Logging.F8 and Config.Logging.F8.Enabled) and "开启" or "关闭"))
        LogInfo("============================================")
        
        -- 测试日志输出
        LogInfo("测试日志: 这是一条测试信息")
        LogWarning("测试日志: 这是一条测试警告")
        
        -- 资源启动完成后，调用NPC生成
        Wait(2000) -- 再等待2秒确保一切就绪
        print("^5[LB-SHOUJIKA] 准备在资源启动后生成NPC^7")
        TriggerServerEvent('lb-shoujika:log', 'info', '准备在资源启动后生成NPC')
        if Config and Config.NPC then
            TriggerServerEvent('lb-shoujika:log', 'info', 'Config和Config.NPC已找到，开始生成NPC')
            SpawnNPC()
        else
            print("^1[LB-SHOUJIKA] 错误: Config或Config.NPC未找到，无法生成NPC^7")
            TriggerServerEvent('lb-shoujika:log', 'error', 'Config或Config.NPC未找到，无法生成NPC')
        end
    else
        print("[LB-SHOUJIKA] 警告: 日志系统未启用，请在config.lua中设置Config.Logging.Enabled = true")
        -- 即使日志未启用，也尝试生成NPC
        Wait(5000)
        if Config and Config.NPC then
            SpawnNPC()
        end
    end
end)

-- ============================================
-- 资源停止时清理
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- 清理ox_target
        local oxTarget = exports.ox_target or exports['ox_target']
        if npcPed and DoesEntityExist(npcPed) and oxTarget then
            pcall(function()
                oxTarget:removeLocalEntity(npcPed, 'lb-shoujika-operator')
            end)
        end
        
        -- 清理NPC
        if npcPed and DoesEntityExist(npcPed) then
            DeleteEntity(npcPed)
            LogInfo("NPC已清理")
        end
        
        -- 清理地图标记
        if npcBlip and DoesBlipExist(npcBlip) then
            RemoveBlip(npcBlip)
            LogInfo("地图标记已清理")
        end
    end
end)

-- ============================================
-- 打开运营商菜单
-- ============================================
function OpenOperatorMenu()
    LogInfo("打开运营商菜单")
    
    -- 确保ESX已加载
    if not ESX then
        LogError("ESX未加载，无法打开菜单")
        if exports.ox_lib then
            exports.ox_lib:notify({
                title = "错误",
                description = "ESX框架未加载",
                type = "error"
            })
        end
        return
    end
    
    -- 检查ox_lib是否可用
    if not exports.ox_lib then
        LogError("ox_lib未找到，无法打开菜单")
        ESX.ShowNotification("菜单系统未加载，请确保ox_lib资源已启动", "error")
        return
    end
    
    ESX.TriggerServerCallback('lb-shoujika:getMyNumbers', function(myNumbers)
        if not myNumbers then
            LogError("获取手机号列表失败")
            myNumbers = {}
        end
        
        LogDebug("获取到 %d 个手机号", #myNumbers)
        
        local options = {}
        
        -- 我的手机号
        table.insert(options, {
            title = _U('menu_my_numbers'),
            description = string.format("查看您拥有的 %d 个手机号", #myNumbers),
            icon = 'fa-solid fa-mobile-screen-button',
            onSelect = function()
                OpenMyNumbersMenu(myNumbers)
            end
        })
        
        -- 购买新号码
        table.insert(options, {
            title = _U('menu_purchase'),
            description = "购买新的手机号码和套餐",
            icon = 'fa-solid fa-cart-shopping',
            onSelect = function()
                OpenPurchaseMenu()
            end
        })
        
        -- 充值话费
        if #myNumbers > 0 then
            table.insert(options, {
                title = _U('menu_recharge'),
                description = "为您的手机号充值话费",
                icon = 'fa-solid fa-money-bill-wave',
                onSelect = function()
                    OpenRechargeMenu(myNumbers)
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-operator-main',
            title = _U('menu_operator'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-operator-main')
    end, function()
        LogError("获取手机号列表的服务器回调失败")
        if exports.ox_lib then
            exports.ox_lib:notify({
                title = "错误",
                description = "无法连接到服务器",
                type = "error"
            })
        end
    end)
end

-- ============================================
-- 我的手机号菜单
-- ============================================
function OpenMyNumbersMenu(numbers)
    if #numbers == 0 then
        if exports.ox_lib then
            exports.ox_lib:notify({
                title = _U('info'),
                description = _U('notify_no_numbers'),
                type = "info"
            })
        else
            Notify(_U('info'), _U('notify_no_numbers'), "info")
        end
        return
    end
    
    local options = {}
    for _, number in ipairs(numbers) do
        local statusText = ""
        local statusColor = "gray"
        if number.status == 'active' then
            statusText = _U('status_active')
            statusColor = "green"
        elseif number.status == 'inactive' then
            statusText = _U('status_inactive')
            statusColor = "yellow"
        elseif number.status == 'suspended' then
            statusText = _U('status_suspended')
            statusColor = "red"
        elseif number.status == 'expired' then
            statusText = _U('status_expired')
            statusColor = "gray"
        end
        
        table.insert(options, {
            title = number.phone_number,
            description = string.format("状态: %s | 余额: $%d", statusText, number.balance),
            icon = 'fa-solid fa-phone',
            metadata = {
                {label = '状态', value = statusText},
                {label = '余额', value = '$' .. number.balance}
            },
            onSelect = function()
                OpenNumberDetailMenu(number)
            end
        })
    end
    
    exports.ox_lib:registerContext({
        id = 'lb-shoujika-my-numbers',
        title = _U('menu_my_numbers_title'),
        options = options
    })
    
    exports.ox_lib:showContext('lb-shoujika-my-numbers')
end

-- ============================================
-- 手机号详情菜单
-- ============================================
function OpenNumberDetailMenu(numberData)
    local options = {}
    
    -- 激活/停用
    if numberData.status == 'inactive' then
        table.insert(options, {
            title = _U('action_activate'),
            description = "激活此手机号",
            icon = 'fa-solid fa-power-off',
            onSelect = function()
                ESX.TriggerServerCallback('lb-shoujika:activateNumber', function(success, message)
                    if success then
                        LogInfo("激活手机号成功: %s", numberData.phone_number)
                        if exports.ox_lib then
                            exports.ox_lib:notify({
                                title = _U('notify_activate_success'),
                                description = _U('activate_success'),
                                type = "success"
                            })
                        else
                            Notify(_U('notify_activate_success'), _U('activate_success'), "success")
                        end
                    else
                        LogWarning("激活手机号失败: %s, 原因=%s", numberData.phone_number, message or _U('activate_failed'))
                        if exports.ox_lib then
                            exports.ox_lib:notify({
                                title = _U('notify_activate_failed'),
                                description = message or _U('activate_failed'),
                                type = "error"
                            })
                        else
                            Notify(_U('notify_activate_failed'), message or _U('activate_failed'), "error")
                        end
                    end
                end, numberData.phone_number)
            end
        })
    end
    
    -- 查看余额
    table.insert(options, {
        title = _U('action_view_balance'),
        description = string.format("当前余额: $%d", numberData.balance),
        icon = 'fa-solid fa-wallet',
        metadata = {
            {label = '余额', value = '$' .. numberData.balance}
        }
    })
    
    -- 充值记录
    table.insert(options, {
        title = _U('action_view_recharge_history'),
        description = "查看此手机号的充值历史记录",
        icon = 'fa-solid fa-history',
        onSelect = function()
            ShowRechargeHistory(numberData.phone_number)
        end
    })
    
    -- 消费记录
    table.insert(options, {
        title = _U('action_view_charge_history'),
        description = "查看此手机号的消费历史记录",
        icon = 'fa-solid fa-receipt',
        onSelect = function()
            ShowChargeHistory(numberData.phone_number)
        end
    })
    
    -- 删除手机号
    table.insert(options, {
        title = _U('action_delete_number') or '删除手机号',
        description = "永久删除此手机号（此操作不可恢复）",
        icon = 'fa-solid fa-trash',
        metadata = {
            {label = '警告', value = '此操作不可恢复'}
        },
        onSelect = function()
            -- 确认删除对话框
            local confirm = exports.ox_lib:inputDialog('确认删除手机号', {
                {
                    type = 'input',
                    label = '请输入手机号以确认删除',
                    description = string.format("手机号: %s\n\n警告: 删除后无法恢复！", numberData.phone_number),
                    required = true,
                    placeholder = numberData.phone_number
                }
            })
            
            if confirm and confirm[1] == numberData.phone_number then
                ESX.TriggerServerCallback('lb-shoujika:deleteNumber', function(success, message)
                    if success then
                        LogInfo("删除手机号成功: %s", numberData.phone_number)
                        if exports.ox_lib then
                            exports.ox_lib:notify({
                                title = "删除成功",
                                description = message or "手机号已成功删除",
                                type = "success"
                            })
                        else
                            Notify("删除成功", message or "手机号已成功删除", "success")
                        end
                        -- 重新打开菜单以刷新列表
                        OpenOperatorMenu()
                    else
                        LogWarning("删除手机号失败: %s, 原因=%s", numberData.phone_number, message or "未知错误")
                        if exports.ox_lib then
                            exports.ox_lib:notify({
                                title = "删除失败",
                                description = message or "删除失败，请稍后重试",
                                type = "error"
                            })
                        else
                            Notify("删除失败", message or "删除失败，请稍后重试", "error")
                        end
                    end
                end, numberData.phone_number)
            elseif confirm then
                if exports.ox_lib then
                    exports.ox_lib:notify({
                        title = "取消删除",
                        description = "手机号不匹配，删除已取消",
                        type = "error"
                    })
                end
            end
        end
    })
    
    local statusText = ""
    if numberData.status == 'active' then
        statusText = _U('status_active')
    elseif numberData.status == 'inactive' then
        statusText = _U('status_inactive')
    elseif numberData.status == 'suspended' then
        statusText = _U('status_suspended')
    elseif numberData.status == 'expired' then
        statusText = _U('status_expired')
    end
    
    exports.ox_lib:registerContext({
        id = 'lb-shoujika-number-detail',
        title = string.format("%s: %s", _U('menu_number_detail'), numberData.phone_number),
        options = options,
        metadata = {
            {label = '手机号', value = numberData.phone_number},
            {label = '状态', value = statusText},
            {label = '余额', value = '$' .. numberData.balance}
        }
    })
    
    exports.ox_lib:showContext('lb-shoujika-number-detail')
end

-- ============================================
-- 购买菜单
-- ============================================
function OpenPurchaseMenu()
    ESX.TriggerServerCallback('lb-shoujika:getPackages', function(packages)
        if #packages == 0 then
            if exports.ox_lib then
                exports.ox_lib:notify({
                    title = _U('info'),
                    description = _U('notify_no_packages'),
                    type = "info"
                })
            else
                Notify(_U('info'), _U('notify_no_packages'), "info")
            end
            return
        end
        
        local options = {}
        for _, package in ipairs(packages) do
            -- 普通购买选项
            table.insert(options, {
                title = package.name .. " (随机号码)",
                description = string.format("价格: $%d | 初始余额: $%d | 周租: $%d", 
                    package.price, package.initial_balance, package.weekly_fee or 0),
                icon = 'fa-solid fa-box',
                metadata = {
                    {label = '价格', value = '$' .. package.price},
                    {label = '初始余额', value = '$' .. package.initial_balance},
                    {label = '周租', value = '$' .. (package.weekly_fee or 0)},
                    {label = '号码类型', value = '随机生成'}
                },
                onSelect = function()
                    PurchasePackage(package, nil)
                end
            })
            
            -- 选择靓号选项
            if Config.PhoneNumber.PremiumNumbers.Enabled then
                table.insert(options, {
                    title = package.name .. " (选择靓号)",
                    description = string.format("价格: $%d起 | 初始余额: $%d | 周租: $%d\n✨ 可选择特殊靓号", 
                        package.price, package.initial_balance, package.weekly_fee or 0),
                    icon = 'fa-solid fa-star',
                    metadata = {
                        {label = '基础价格', value = '$' .. package.price},
                        {label = '初始余额', value = '$' .. package.initial_balance},
                        {label = '周租', value = '$' .. (package.weekly_fee or 0)},
                        {label = '号码类型', value = '✨ 靓号选择'}
                    },
                    onSelect = function()
                        OpenPremiumNumberMenu(package)
                    end
                })
            end
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-purchase',
            title = _U('menu_purchase_title'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-purchase')
    end)
end

-- ============================================
-- 购买套餐（通用函数）
-- ============================================
function PurchasePackage(package, selectedPhoneNumber)
    -- 确认购买对话框
    local confirmText = "确认购买"
    local description = string.format("套餐: %s\n价格: $%d\n初始余额: $%d\n周租: $%d", 
        package.name, package.price, package.initial_balance, package.weekly_fee or 0)
    
    if selectedPhoneNumber then
        description = description .. string.format("\n选择的号码: %s", selectedPhoneNumber.phone_number)
        if selectedPhoneNumber.premium_type then
            description = description .. string.format("\n✨ 靓号类型: %s (价格倍数: %.1fx)", 
                selectedPhoneNumber.premium_type, selectedPhoneNumber.price_multiplier)
            description = description .. string.format("\n最终价格: $%d", selectedPhoneNumber.final_price)
        end
    end
    
    description = description .. "\n\n输入 '确认' 以继续"
    
    local confirm = exports.ox_lib:inputDialog(_U('purchase_confirm', package.name), {
        {
            type = 'input',
            label = confirmText,
            description = description,
            required = true
        }
    })
    
    if confirm and confirm[1] == '确认' then
        ESX.TriggerServerCallback('lb-shoujika:purchaseNumber', function(success, message)
            if success then
                LogInfo("购买手机号成功: %s", message)
                if exports.ox_lib then
                    exports.ox_lib:notify({
                        title = _U('notify_purchase_success'),
                        description = _U('purchase_phone_number', message),
                        type = "success"
                    })
                else
                    Notify(_U('notify_purchase_success'), _U('purchase_phone_number', message), "success")
                end
            else
                LogWarning("购买手机号失败: %s", message or _U('purchase_failed'))
                if exports.ox_lib then
                    exports.ox_lib:notify({
                        title = _U('notify_purchase_failed'),
                        description = message or _U('purchase_failed'),
                        type = "error"
                    })
                else
                    Notify(_U('notify_purchase_failed'), message or _U('purchase_failed'), "error")
                end
            end
        end, package.id, selectedPhoneNumber and selectedPhoneNumber.phone_number or nil)
    end
end

-- ============================================
-- 靓号选择菜单
-- ============================================
function OpenPremiumNumberMenu(package)
    -- 显示加载提示
    if exports.ox_lib then
        exports.ox_lib:notify({
            title = _U('loading') or '加载中...',
            description = _U('please_wait') or '正在生成靓号列表，请稍候...',
            type = "info"
        })
    end
    
    ESX.TriggerServerCallback('lb-shoujika:getPremiumNumbers', function(premiumNumbers)
        if #premiumNumbers == 0 then
            if exports.ox_lib then
                exports.ox_lib:notify({
                    title = _U('info'),
                    description = _U('notify_no_premium_numbers') or "暂无可用的靓号，请稍后再试或选择随机号码",
                    type = "info"
                })
            else
                Notify(_U('info'), _U('notify_no_premium_numbers') or "暂无可用的靓号，请稍后再试或选择随机号码", "info")
            end
            return
        end
        
        local options = {}
        
        -- 添加随机号码选项
        table.insert(options, {
            title = "🎲 随机号码",
            description = string.format("基础价格: $%d\n让系统随机生成一个号码", package.price),
            icon = 'fa-solid fa-shuffle',
            metadata = {
                {label = '价格', value = '$' .. package.price},
                {label = '类型', value = '随机生成'}
            },
            onSelect = function()
                PurchasePackage(package, nil)
            end
        })
        
        -- 添加靓号选项
        for _, premiumNumber in ipairs(premiumNumbers) do
            table.insert(options, {
                title = premiumNumber.phone_number,
                description = string.format("✨ %s\n基础价格: $%d × %.1f = $%d", 
                    premiumNumber.premium_type, 
                    premiumNumber.base_price, 
                    premiumNumber.price_multiplier,
                    premiumNumber.final_price),
                icon = 'fa-solid fa-star',
                metadata = {
                    {label = '靓号类型', value = premiumNumber.premium_type},
                    {label = '价格倍数', value = string.format('%.1fx', premiumNumber.price_multiplier)},
                    {label = '最终价格', value = '$' .. premiumNumber.final_price}
                },
                onSelect = function()
                    PurchasePackage(package, premiumNumber)
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-premium-numbers',
            title = string.format("%s - 选择靓号", package.name),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-premium-numbers')
    end, package.id, 10) -- 生成10个靓号
end

-- ============================================
-- 充值菜单
-- ============================================
function OpenRechargeMenu(numbers)
    if #numbers == 0 then
        if exports.ox_lib then
            exports.ox_lib:notify({
                title = _U('info'),
                description = _U('notify_no_numbers'),
                type = "info"
            })
        else
            Notify(_U('info'), _U('notify_no_numbers'), "info")
        end
        return
    end
    
    local options = {}
    for _, number in ipairs(numbers) do
        table.insert(options, {
            title = number.phone_number,
            description = string.format("当前余额: $%d", number.balance),
            icon = 'fa-solid fa-phone',
            metadata = {
                {label = '余额', value = '$' .. number.balance}
            },
            onSelect = function()
                local phoneNumber = number.phone_number
                
                -- 选择充值方式
                local methodOptions = {}
                if Config.Recharge.Methods.cash then
                    table.insert(methodOptions, {
                        title = _U('recharge_method_cash'),
                        description = "使用现金充值",
                        icon = 'fa-solid fa-money-bill',
                        onSelect = function()
                            RechargeWithMethod(phoneNumber, "cash")
                        end
                    })
                end
                if Config.Recharge.Methods.bank then
                    table.insert(methodOptions, {
                        title = _U('recharge_method_bank'),
                        description = "使用银行账户充值",
                        icon = 'fa-solid fa-credit-card',
                        onSelect = function()
                            RechargeWithMethod(phoneNumber, "bank")
                        end
                    })
                end
                
                if #methodOptions == 0 then
                    if exports.ox_lib then
                        exports.ox_lib:notify({
                            title = "错误",
                            description = "没有可用的充值方式",
                            type = "error"
                        })
                    end
                    return
                end
                
                exports.ox_lib:registerContext({
                    id = 'lb-shoujika-recharge-method',
                    title = _U('menu_recharge_method'),
                    options = methodOptions
                })
                
                exports.ox_lib:showContext('lb-shoujika-recharge-method')
            end
        })
    end
    
    exports.ox_lib:registerContext({
        id = 'lb-shoujika-recharge-select',
        title = "选择要充值的手机号",
        options = options
    })
    
    exports.ox_lib:showContext('lb-shoujika-recharge-select')
end

-- ============================================
-- 使用指定方式充值
-- ============================================
function RechargeWithMethod(phoneNumber, method)
    local input = exports.ox_lib:inputDialog(string.format("为 %s 充值", phoneNumber), {
        {
            type = 'number',
            label = '充值金额',
            description = string.format("范围: $%d - $%d", Config.Recharge.MinAmount, Config.Recharge.MaxAmount),
            required = true,
            min = Config.Recharge.MinAmount,
            max = Config.Recharge.MaxAmount
        }
    })
    
    if input and input[1] then
        local amount = tonumber(input[1])
        
        if amount and amount >= Config.Recharge.MinAmount and amount <= Config.Recharge.MaxAmount then
            ESX.TriggerServerCallback('lb-shoujika:rechargeBalance', function(success, message)
                if success then
                    LogInfo("充值成功: 手机号=%s, 金额=$%d, 余额=$%d", phoneNumber, amount, message)
                    if exports.ox_lib then
                        exports.ox_lib:notify({
                            title = _U('notify_recharge_success'),
                            description = _U('recharge_current_balance', message),
                            type = "success"
                        })
                    else
                        Notify(_U('notify_recharge_success'), _U('recharge_current_balance', message), "success")
                    end
                else
                    LogWarning("充值失败: 手机号=%s, 金额=$%d, 原因=%s", phoneNumber, amount, message or _U('recharge_failed'))
                    if exports.ox_lib then
                        exports.ox_lib:notify({
                            title = _U('notify_recharge_failed'),
                            description = message or _U('recharge_failed'),
                            type = "error"
                        })
                    else
                        Notify(_U('notify_recharge_failed'), message or _U('recharge_failed'), "error")
                    end
                end
            end, phoneNumber, amount, method)
        else
            if exports.ox_lib then
                exports.ox_lib:notify({
                    title = _U('error'),
                    description = _U('recharge_amount_invalid', Config.Recharge.MinAmount, Config.Recharge.MaxAmount),
                    type = "error"
                })
            else
                Notify(_U('error'), _U('recharge_amount_invalid', Config.Recharge.MinAmount, Config.Recharge.MaxAmount), "error")
            end
        end
    end
end

-- ============================================
-- 显示充值记录
-- ============================================
function ShowRechargeHistory(phoneNumber)
    ESX.TriggerServerCallback('lb-shoujika:getRechargeHistory', function(history)
        if #history == 0 then
            if exports.ox_lib then
                exports.ox_lib:notify({
                    title = _U('info'),
                    description = _U('notify_no_recharge_history'),
                    type = "info"
                })
            else
                Notify(_U('info'), _U('notify_no_recharge_history'), "info")
            end
            return
        end
        
        local options = {}
        for _, record in ipairs(history) do
            local date = record.created_at or "未知时间"
            if type(date) == "number" then
                date = "时间戳:" .. date
            end
            table.insert(options, {
                title = string.format("+$%d", record.amount),
                description = string.format("时间: %s | 方式: %s", date, record.method or "未知"),
                icon = 'fa-solid fa-arrow-up',
                metadata = {
                    {label = '金额', value = '+$' .. record.amount},
                    {label = '时间', value = date},
                    {label = '方式', value = record.method or "未知"}
                }
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-recharge-history',
            title = _U('menu_recharge_history'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-recharge-history')
    end, phoneNumber)
end

-- ============================================
-- 显示消费记录
-- ============================================
function ShowChargeHistory(phoneNumber)
    ESX.TriggerServerCallback('lb-shoujika:getChargeHistory', function(history)
        if #history == 0 then
            if exports.ox_lib then
                exports.ox_lib:notify({
                    title = _U('info'),
                    description = _U('notify_no_charge_history'),
                    type = "info"
                })
            else
                Notify(_U('info'), _U('notify_no_charge_history'), "info")
            end
            return
        end
        
        local options = {}
        for _, record in ipairs(history) do
            local date = record.created_at or "未知时间"
            if type(date) == "number" then
                date = "时间戳:" .. date
            end
            local typeText = ""
            local typeIcon = 'fa-solid fa-receipt'
            if record.type == 'call' then
                typeText = _U('charge_type_call')
                typeIcon = 'fa-solid fa-phone'
            elseif record.type == 'sms' then
                typeText = _U('charge_type_sms')
                typeIcon = 'fa-solid fa-message'
            elseif record.type == 'data' then
                typeText = _U('charge_type_data')
                typeIcon = 'fa-solid fa-wifi'
            elseif record.type == 'weekly_fee' then
                typeText = _U('charge_type_weekly_fee')
                typeIcon = 'fa-solid fa-calendar-week'
            else
                typeText = _U('charge_type_other')
            end
            
            table.insert(options, {
                title = string.format("-$%d", record.amount),
                description = string.format("时间: %s | 类型: %s", date, typeText),
                icon = typeIcon,
                metadata = {
                    {label = '金额', value = '-$' .. record.amount},
                    {label = '时间', value = date},
                    {label = '类型', value = typeText}
                }
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-charge-history',
            title = _U('menu_charge_history'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-charge-history')
    end, phoneNumber)
end

-- ============================================
-- 老板管理菜单
-- ============================================
RegisterNetEvent('lb-shoujika:openBossMenu')
AddEventHandler('lb-shoujika:openBossMenu', function()
    if not exports.ox_lib then
        ESX.ShowNotification("菜单系统未加载", "error")
        return
    end
    
    local options = {}
    
    -- 批量生成靓号
    table.insert(options, {
        title = _U('boss_generate_premium'),
        description = "批量生成并上架靓号",
        icon = 'fa-solid fa-wand-magic-sparkles',
        onSelect = function()
            OpenBossGenerateMenu()
        end
    })
    
    -- 查看已上架靓号
    table.insert(options, {
        title = _U('boss_view_list'),
        description = "查看和管理已上架的靓号",
        icon = 'fa-solid fa-list',
        onSelect = function()
            OpenBossPremiumListMenu()
        end
    })
    
    exports.ox_lib:registerContext({
        id = 'lb-shoujika-boss-main',
        title = _U('boss_menu_title'),
        options = options
    })
    
    exports.ox_lib:showContext('lb-shoujika-boss-main')
end)

-- 批量生成靓号菜单
function OpenBossGenerateMenu()
    ESX.TriggerServerCallback('lb-shoujika:boss:getPackages', function(packages)
        if not packages or #packages == 0 then
            exports.ox_lib:notify({
                title = "错误",
                description = "暂无可用套餐",
                type = "error"
            })
            return
        end
        
        local options = {}
        
        for _, package in ipairs(packages) do
            table.insert(options, {
                title = package.name,
                description = string.format("价格: $%d | 初始余额: $%d", package.price, package.initial_balance),
                metadata = {
                    {label = '价格', value = '$' .. package.price},
                    {label = '初始余额', value = '$' .. package.initial_balance}
                },
                onSelect = function()
                    -- 输入生成数量
                    local input = exports.ox_lib:inputDialog(_U('boss_generate_premium'), {
                        {
                            type = 'number',
                            label = _U('boss_generate_count'),
                            description = string.format("最小: %d, 最大: %d", 
                                Config.Boss.BatchGenerate.MinCount, 
                                Config.Boss.BatchGenerate.MaxCount),
                            required = true,
                            default = Config.Boss.BatchGenerate.DefaultCount,
                            min = Config.Boss.BatchGenerate.MinCount,
                            max = Config.Boss.BatchGenerate.MaxCount
                        }
                    })
                    
                    if input and input[1] then
                        local count = tonumber(input[1])
                        if count then
                            exports.ox_lib:notify({
                                title = "正在生成",
                                description = string.format("正在生成 %d 个靓号，请稍候...", count),
                                type = "info"
                            })
                            
                            ESX.TriggerServerCallback('lb-shoujika:boss:batchGeneratePremiumNumbers', function(success, message)
                                if success then
                                    exports.ox_lib:notify({
                                        title = "成功",
                                        description = message,
                                        type = "success"
                                    })
                                else
                                    exports.ox_lib:notify({
                                        title = "失败",
                                        description = message or "生成失败",
                                        type = "error"
                                    })
                                end
                            end, package.id, count)
                        end
                    end
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-boss-generate',
            title = _U('boss_select_package'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-boss-generate')
    end)
end

-- 查看已上架靓号列表
function OpenBossPremiumListMenu()
    ESX.TriggerServerCallback('lb-shoujika:boss:getPackages', function(packages)
        if not packages or #packages == 0 then
            exports.ox_lib:notify({
                title = "错误",
                description = "暂无可用套餐",
                type = "error"
            })
            return
        end
        
        local options = {}
        
        for _, package in ipairs(packages) do
            table.insert(options, {
                title = package.name,
                description = "查看该套餐的已上架靓号",
                onSelect = function()
                    ESX.TriggerServerCallback('lb-shoujika:boss:getPremiumNumbersList', function(premiumNumbers)
                        if not premiumNumbers or #premiumNumbers == 0 then
                            exports.ox_lib:notify({
                                title = "提示",
                                description = _U('boss_no_premium_numbers'),
                                type = "info"
                            })
                            return
                        end
                        
                        local listOptions = {}
                        
                        for _, premium in ipairs(premiumNumbers) do
                            local statusText = _U('boss_status_available')
                            if premium.status == 'sold' then
                                statusText = _U('boss_status_sold')
                            elseif premium.status == 'reserved' then
                                statusText = _U('boss_status_reserved')
                            end
                            
                            table.insert(listOptions, {
                                title = premium.phone_number,
                                description = string.format("%s | %s | $%d", 
                                    premium.premium_type or "普通", statusText, premium.final_price),
                                metadata = {
                                    {label = _U('boss_premium_type'), value = premium.premium_type or "普通"},
                                    {label = _U('boss_price_multiplier'), value = string.format("%.2fx", premium.price_multiplier)},
                                    {label = _U('boss_final_price'), value = '$' .. premium.final_price},
                                    {label = _U('boss_status'), value = statusText}
                                },
                                onSelect = function()
                                    if premium.status == 'available' then
                                        -- 下架确认
                                        local confirm = exports.ox_lib:alertDialog({
                                            header = _U('boss_remove_premium'),
                                            content = string.format(_U('boss_remove_confirm'), premium.phone_number),
                                            centered = true,
                                            cancel = true
                                        })
                                        
                                        if confirm == 'confirm' then
                                            ESX.TriggerServerCallback('lb-shoujika:boss:removePremiumNumber', function(success, message)
                                                if success then
                                                    exports.ox_lib:notify({
                                                        title = "成功",
                                                        description = message,
                                                        type = "success"
                                                    })
                                                    -- 刷新列表
                                                    OpenBossPremiumListMenu()
                                                else
                                                    exports.ox_lib:notify({
                                                        title = "失败",
                                                        description = message or "下架失败",
                                                        type = "error"
                                                    })
                                                end
                                            end, premium.id)
                                        end
                                    else
                                        exports.ox_lib:notify({
                                            title = "提示",
                                            description = "只有可购买状态的靓号才能下架",
                                            type = "info"
                                        })
                                    end
                                end
                            })
                        end
                        
                        exports.ox_lib:registerContext({
                            id = 'lb-shoujika-boss-list',
                            title = _U('boss_premium_list') .. " - " .. package.name,
                            options = listOptions
                        })
                        
                        exports.ox_lib:showContext('lb-shoujika-boss-list')
                    end, package.id, 'all')
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'lb-shoujika-boss-list-select',
            title = _U('boss_select_package'),
            options = options
        })
        
        exports.ox_lib:showContext('lb-shoujika-boss-list-select')
    end)
end
