--[[
    xerox.tech - Universal Script
    Создано на основе Octohook UI Library
]]

-- Глобальная таблица переменных
local vars = {
    -- Сервисы
    Camera = workspace.CurrentCamera,
    Players = cloneref(game:GetService("Players")),
    RunService = cloneref(game:GetService("RunService")),
    Workspace = workspace,
    
    -- UI функции
    UDim2FromOffset = UDim2.fromOffset,
    UDim2New = UDim2.new,
    Color3FromRGB = Color3.fromRGB,
    
    -- Математические функции
    Vector2New = Vector2.new,
    Vector3New = Vector3.new,
    CFrameLookAt = CFrame.lookAt,
    
    -- Другие функции
    InstanceNew = Instance.new,
    RaycastParamsNew = RaycastParams.new,
    NumberSequenceNew = NumberSequence.new,
    
    -- R6 Hitparts
    HitParts = {
        "Head",
        "Torso", 
        "Left Arm",
        "Right Arm",
        "Left Leg",
        "Right Leg"
    },
    
    -- Приоритет hitparts (от лучшего к худшему)
    HitPartPriority = {
        ["Head"] = 1,
        ["Torso"] = 2,
        ["Left Arm"] = 3,
        ["Right Arm"] = 3,
        ["Left Leg"] = 4,
        ["Right Leg"] = 4
    },
}

-- Инициализация основных переменных
vars.LocalPlayer = vars.Players.LocalPlayer

-- Загрузка библиотеки
local Library, Esp, MiscOptions, Options = loadstring(game:HttpGet("https://raw.githubusercontent.com/OnChangedCallback/CkRemake/refs/heads/main/library"))()

-- Создание главного окна
local Holder = Library:Window({Name = "xerox.tech"})

-- Создание панели меню
local Window = Holder:Panel({
    Name = "xerox.tech", 
    ButtonName = "Menu", 
    Size = vars.UDim2FromOffset(550, 709), 
    Position = vars.UDim2New(0, (vars.Camera.ViewportSize.X / 2) - 550/2, 0, (vars.Camera.ViewportSize.Y / 2) - 709/2),
})

-- Создание вкладок
local Tabs = {
    Combat = Window:Tab({Name = "Combat"}),
    Visuals = Window:Tab({Name = "Visuals"}),
    Players = Window:Tab({Name = "Players"}),
}

-- Utility функции
do
    local utility = {}
    
    utility.new_connection = function(type, callback)
        local connection = type:Connect(callback)
        return connection
    end
    
    utility.getLocalPlayer = function()
        return vars.LocalPlayer
    end
    
    utility.getCharacter = function(player)
        player = player or vars.LocalPlayer
        return player and player.Character
    end
    
    utility.getHumanoid = function(character)
        return character and character:FindFirstChildOfClass("Humanoid")
    end
    
    utility.getHumanoidRootPart = function(character)
        return character and character:FindFirstChild("HumanoidRootPart")
    end
    
    utility.getHead = function(character)
        return character and character:FindFirstChild("Head")
    end
    
    utility.isAlive = function(character)
        local humanoid = utility.getHumanoid(character)
        return humanoid and humanoid.Health > 0
    end
    
    utility.hasForceField = function(character)
        return character and character:FindFirstChild("ForceField") ~= nil
    end
    
    utility.worldToViewportPoint = function(position)
        return vars.Camera:WorldToViewportPoint(position)
    end
    
    utility.getScreenCenter = function()
        return vars.Vector2New(vars.Camera.ViewportSize.X / 2, vars.Camera.ViewportSize.Y / 2)
    end
    
    utility.getMouse = function()
        return vars.LocalPlayer:GetMouse()
    end
    
    utility.getHitPart = function(character, hitPartName)
        if not character then return nil end
        
        -- Проверяем стандартные R6 части
        local hitPart = character:FindFirstChild(hitPartName)
        if hitPart then return hitPart end
        
        -- Дополнительная проверка для левых частей (могут называться по-разному)
        if hitPartName == "Left Arm" then
            return character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftArm")
        elseif hitPartName == "Right Arm" then
            return character:FindFirstChild("Right Arm") or character:FindFirstChild("RightArm")
        elseif hitPartName == "Left Leg" then
            return character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLeg")
        elseif hitPartName == "Right Leg" then
            return character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLeg")
        end
        
        return nil
    end
    
    utility.getBulletStart = function()
        local character = vars.utility.getCharacter()
        if not character then return nil end
        
        for _, tool in pairs(character:GetChildren()) do
            if tool and tool:IsA("Tool") then
                local bulletStart = tool:FindFirstChild("BulletStart")
                if bulletStart then
                    return bulletStart
                end
            end
        end
        return nil
    end
    
    utility.isHitPartValid = function(character, hitPartName)
        local hitPart = utility.getHitPart(character, hitPartName)
        return hitPart ~= nil
    end
    
    vars.utility = utility
end

-- Framework функции (должны быть объявлены ДО UI)
do
    local framework = {}
    local cachedFilterList = nil
    local lastCacheTime = 0
    
    -- Переменные для режимов таргетинга
    local targetingMode = "CursorNearest"
    local priorityMode = "LowestHealth"
    local selectedHitParts = {"Head", "Torso"} -- По умолчанию голова и торс
    
    -- Кэш для оптимизации
    local cachedPenetrableObjects = {}
    local lastPenetrableCacheTime = 0
    
    framework.getTarget = function()
        local character = vars.utility.getCharacter()
        local humanoidRootPart = vars.utility.getHumanoidRootPart(character)
        if not humanoidRootPart then return nil end
        
        local mouse = vars.utility.getMouse()
        local localPosition = humanoidRootPart.Position
        local screenCenter = vars.utility.getScreenCenter()
        
        local validTargets = {}
        
        -- Собираем всех валидных целей
        for _, player in pairs(vars.Players:GetPlayers()) do
            if player ~= vars.LocalPlayer then
                local targetChar = vars.utility.getCharacter(player)
                local humanoid = vars.utility.getHumanoid(targetChar)
                local targetHRP = vars.utility.getHumanoidRootPart(targetChar)
                local head = vars.utility.getHead(targetChar)
                
                if humanoid and targetHRP and head and humanoid.Health > 0 and not vars.utility.hasForceField(targetChar) then
                    local targetValue = math.huge
                    
                    if targetingMode == "CursorNearest" then
                        local screenPos, onScreen = vars.utility.worldToViewportPoint(head.Position)
                        if onScreen then
                            local mousePos = vars.Vector2New(mouse.X, mouse.Y)
                            local screenPoint = vars.Vector2New(screenPos.X, screenPos.Y)
                            targetValue = (mousePos - screenPoint).Magnitude
                        else
                            targetValue = (vars.Camera.CFrame.Position - head.Position).Magnitude + 10000
                        end
                        
                    elseif targetingMode == "CenterNearest" then
                        local screenPos, onScreen = vars.utility.worldToViewportPoint(head.Position)
                        if onScreen then
                            local screenPoint = vars.Vector2New(screenPos.X, screenPos.Y)
                            targetValue = (screenCenter - screenPoint).Magnitude
                        else
                            targetValue = (vars.Camera.CFrame.Position - head.Position).Magnitude + 10000
                        end
                        
                    elseif targetingMode == "HealthBased" then
                        targetValue = humanoid.Health
                        
                    elseif targetingMode == "ClosestLocalDist" then
                        targetValue = (localPosition - targetHRP.Position).Magnitude
                    end
                    
                    table.insert(validTargets, {
                        player = player,
                        value = targetValue,
                        humanoid = humanoid,
                        humanoidRootPart = targetHRP,
                        head = head
                    })
                end
            end
        end
        
        if #validTargets == 0 then return nil end
        
        -- Сортируем по основному критерию
        table.sort(validTargets, function(a, b)
            return a.value < b.value
        end)
        
        -- Если несколько целей с одинаковым значением, применяем приоритет
        local bestTargets = {}
        local bestValue = validTargets[1].value
        local tolerance = (targetingMode == "HealthBased") and 10 or (bestValue * 0.1)
        
        for _, target in pairs(validTargets) do
            if math.abs(target.value - bestValue) <= tolerance then
                table.insert(bestTargets, target)
            else
                break
            end
        end
        
        if #bestTargets == 1 then
            return bestTargets[1].player
        end
        
        -- Применяем приоритет для выбора между похожими целями
        local finalTarget = bestTargets[1]
        
        if priorityMode == "LowestHealth" then
            for _, target in pairs(bestTargets) do
                if target.humanoid.Health < finalTarget.humanoid.Health then
                    finalTarget = target
                end
            end
            
        elseif priorityMode == "NotCovered" then
            for _, target in pairs(bestTargets) do
                local startPos = vars.Camera.CFrame.Position
                local direction = (target.head.Position - startPos).Unit
                local canHit, _, hitModel = vars.framework.raycastTarget(startPos, direction)
                
                if canHit and hitModel == target.player.Character then
                    finalTarget = target
                    break
                end
            end
            
        elseif priorityMode == "NearestToLocalPlayer" then
            for _, target in pairs(bestTargets) do
                local distance = (localPosition - target.humanoidRootPart.Position).Magnitude
                local finalDistance = (localPosition - finalTarget.humanoidRootPart.Position).Magnitude
                
                if distance < finalDistance then
                    finalTarget = target
                end
            end
        end
        
        return finalTarget.player
    end
    
    framework.canShoot = function()
        local character = vars.utility.getCharacter()
        return vars.utility.isAlive(character)
    end
    
    framework.raycastTarget = function(startPos, direction)
        local currentTime = tick()
        
        -- Обновляем кэш только раз в 0.1 секунды для оптимизации
        if not cachedFilterList or currentTime - lastCacheTime > 0.1 then
            cachedFilterList = {vars.utility.getCharacter()}
            
            local character = vars.utility.getCharacter()
            if character then
                for _, child in ipairs(character:GetChildren()) do
                    table.insert(cachedFilterList, child)
                end
            end
            
            lastCacheTime = currentTime
        end
        
        local raycastParams = vars.RaycastParamsNew()
        raycastParams.FilterDescendantsInstances = cachedFilterList
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local raycastResult = vars.Workspace:Raycast(startPos, direction * 200, raycastParams)
        if raycastResult then
            local targetModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
            if targetModel then
                local humanoid = vars.utility.getHumanoid(targetModel)
                if humanoid and humanoid.Health > 0 and not vars.utility.hasForceField(targetModel) then
                    return true, raycastResult.Position, targetModel
                end
            end
        end
        return false
    end
    
    framework.createTracer = function(startPos, endPos, color, transparency)
        local distance = (endPos - startPos).Magnitude
        local midPoint = (startPos + endPos) / 2
        
        local tracerPart = vars.InstanceNew("Part")
        tracerPart.Name = "AimbotTracer"
        tracerPart.Anchored = true
        tracerPart.CanCollide = false
        tracerPart.Material = Enum.Material.Neon
        tracerPart.Shape = Enum.PartType.Block
        tracerPart.Size = vars.Vector3New(0.1, 0.1, distance)
        tracerPart.Color = color
        tracerPart.Transparency = transparency
        tracerPart.CFrame = vars.CFrameLookAt(midPoint, endPos)
        tracerPart.Parent = vars.Workspace
        
        return tracerPart
    end
    
    framework.setTargetingMode = function(mode)
        targetingMode = mode
    end
    
    framework.setPriorityMode = function(mode)
        priorityMode = mode
    end
    
    framework.setSelectedHitParts = function(hitParts)
        selectedHitParts = hitParts
    end
    
    framework.updatePenetrableCache = function()
        local currentTime = tick()
        if currentTime - lastPenetrableCacheTime > 1.0 then
            cachedPenetrableObjects = {}
            for _, obj in ipairs(vars.Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name == "Penetrable" or obj.Name == "BulletHole" or obj.Name == "BulletHoleFlesh") then
                    table.insert(cachedPenetrableObjects, obj)
                end
            end
            lastPenetrableCacheTime = currentTime
        end
    end
    
    framework.getAvailableHitParts = function(player)
        local bulletStart = vars.utility.getBulletStart()
        if not bulletStart then return {} end
        
        local targetChar = vars.utility.getCharacter(player)
        if not targetChar then return {} end
        
        -- Обновляем кэш penetrable объектов
        framework.updatePenetrableCache()
        
        local startPos = bulletStart.Position
        local availableHitParts = {}
        
        -- Создаем параметры рейкаста
        local raycastParams = RaycastParams.new()
        local filterList = {}
        
        -- Исключаем локального игрока и все его вложения
        local localChar = vars.utility.getCharacter()
        if localChar then
            table.insert(filterList, localChar)
            for _, descendant in pairs(localChar:GetDescendants()) do
                if descendant:IsA("BasePart") or descendant:IsA("Accessory") or descendant:IsA("Tool") then
                    table.insert(filterList, descendant)
                end
            end
        end
        
        -- Добавляем кэшированные penetrable объекты
        for _, obj in ipairs(cachedPenetrableObjects) do
            table.insert(filterList, obj)
        end
        
        raycastParams.FilterDescendantsInstances = filterList
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        
        -- Проверяем каждый выбранный hitpart отдельным рейкастом
        for _, hitPartName in ipairs(selectedHitParts) do
            local hitPart = vars.utility.getHitPart(targetChar, hitPartName)
            if hitPart then
                local direction = (hitPart.Position - startPos).Unit
                local distance = (hitPart.Position - startPos).Magnitude + 5
                
                local raycastResult = vars.Workspace:Raycast(startPos, direction * distance, raycastParams)
                
                if raycastResult then
                    local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
                    if hitModel == targetChar then
                        -- Попали в игрока - добавляем именно ту часть в которую попали
                        table.insert(availableHitParts, {
                            name = raycastResult.Instance.Name,
                            priority = vars.HitPartPriority[raycastResult.Instance.Name] or 999,
                            part = raycastResult.Instance
                        })
                    end
                else
                    -- Рейкаст не попал ни во что - hitpart видим
                    table.insert(availableHitParts, {
                        name = hitPartName,
                        priority = vars.HitPartPriority[hitPartName] or 999,
                        part = hitPart
                    })
                end
            end
        end
        
        return availableHitParts
    end
    
    framework.getBestAvailableHitPart = function(player)
        local availableHitParts = framework.getAvailableHitParts(player)
        
        if #availableHitParts == 0 then return nil end
        
        -- Сортируем по приоритету (меньше = лучше)
        table.sort(availableHitParts, function(a, b)
            return a.priority < b.priority
        end)
        
        return availableHitParts[1]
    end
    
    
    vars.framework = framework
end

-- Вкладка Combat
do
    local CombatColumn = Tabs.Combat:Column()
    local RageBotSection = CombatColumn:Section({Name = "RageBot"})
    
    -- RageBot переменные
    local rageBotEnabled = false
    local rageBotConnection = nil
    local showAimbotEnabled = false
    local currentTracer = nil
    local tracerColor = vars.Color3FromRGB(255, 0, 0)
    local tracerTransparency = 0.5
    local lastTargetCheck = 0
    
    RageBotSection:Toggle({
        Name = "Enable RageBot",
        Flag = "RageBotEnabled",
        Default = false,
        Callback = function(value)
            rageBotEnabled = value
            
            if rageBotEnabled then
                -- Используем RenderStepped для лучшей производительности
                local lastUpdate = 0
                rageBotConnection = vars.utility.new_connection(vars.RunService.RenderStepped, function()
                    -- Ограничиваем до 100 FPS для высокой точности
                    local currentTime = tick()
                    if currentTime - lastUpdate < (1/100) then return end
                    lastUpdate = currentTime
                    if not vars.framework.canShoot() then return end
                    
                    local target = vars.framework.getTarget()
                    if not target or not target.Character then 
                        -- Отключаем autoshoot если нет цели
                        if vars.LocalPlayer.Character then
                            local autoShoot = vars.LocalPlayer.Character:FindFirstChild("autoshoot")
                            if autoShoot then autoShoot.Value = false end
                        end
                        return 
                    end
                    
                    -- Получаем лучший доступный hitpart
                    local bestHitPart = vars.framework.getBestAvailableHitPart(target)
                    if not bestHitPart or not bestHitPart.part then
                        -- Отключаем autoshoot если нет доступных hitparts
                        if vars.LocalPlayer.Character then
                            local autoShoot = vars.LocalPlayer.Character:FindFirstChild("autoshoot")
                            if autoShoot then autoShoot.Value = false end
                        end
                        return
                    end
                    
                    -- Создаем/обновляем значения для gunshoot framework
                    if vars.LocalPlayer.Character then
                        local autoShoot = vars.LocalPlayer.Character:FindFirstChild("autoshoot")
                        if not autoShoot then
                            autoShoot = Instance.new("BoolValue")
                            autoShoot.Name = "autoshoot"
                            autoShoot.Parent = vars.LocalPlayer.Character
                        end
                        autoShoot.Value = true
                        
                        local rageAim = vars.LocalPlayer.Character:FindFirstChild("rageaim")
                        if not rageAim then
                            rageAim = Instance.new("BoolValue")
                            rageAim.Name = "rageaim"
                            rageAim.Parent = vars.LocalPlayer.Character
                        end
                        rageAim.Value = true
                        
                        local aimPos = vars.LocalPlayer.Character:FindFirstChild("aimpos")
                        if not aimPos then
                            aimPos = Instance.new("Vector3Value")
                            aimPos.Name = "aimpos"
                            aimPos.Parent = vars.LocalPlayer.Character
                        end
                        aimPos.Value = bestHitPart.part.Position
                        
                        -- Показываем трейсер если включен
                        if showAimbotEnabled then
                            -- Удаляем старый трейсер
                            if currentTracer then
                                currentTracer:Destroy()
                            end
                            
                            -- Находим BulletStart для трейсера
                            local bulletStart = nil
                            for _, tool in pairs(vars.LocalPlayer.Character:GetChildren()) do
                                if tool:IsA("Tool") then
                                    bulletStart = tool:FindFirstChild("BulletStart")
                                    if bulletStart then break end
                                end
                            end
                            
                            if bulletStart then
                                currentTracer = vars.framework.createTracer(
                                    bulletStart.Position,
                                    bestHitPart.part.Position,
                                    tracerColor,
                                    tracerTransparency
                                )
                                
                                -- Автоматически удаляем трейсер через 0.1 секунды
                                task.delay(0.1, function()
                                    if currentTracer then
                                        currentTracer:Destroy()
                                        currentTracer = nil
                                    end
                                end)
                            end
                        end
                    end
                end)
            else
                if rageBotConnection then
                    rageBotConnection:Disconnect()
                    rageBotConnection = nil
                end
                
                -- Удаляем трейсер
                if currentTracer then
                    currentTracer:Destroy()
                    currentTracer = nil
                end
                
                -- Отключаем все значения
                if vars.LocalPlayer.Character then
                    local autoShoot = vars.LocalPlayer.Character:FindFirstChild("autoshoot")
                    if autoShoot then autoShoot.Value = false end
                    
                    local rageAim = vars.LocalPlayer.Character:FindFirstChild("rageaim")
                    if rageAim then rageAim.Value = false end
                end
            end
        end
    })
    
    -- Show Aimbot Toggle с Colorpicker
    local showAimbotToggle = RageBotSection:Toggle({
        Name = "Show Aimbot",
        Flag = "ShowAimbotEnabled",
        Default = false,
        Callback = function(value)
            showAimbotEnabled = value
            
            if not showAimbotEnabled and currentTracer then
                currentTracer:Destroy()
                currentTracer = nil
            end
        end
    })
    
    showAimbotToggle:Colorpicker({
        Name = "Tracer Color",
        Flag = "TracerColor",
        Default = vars.Color3FromRGB(255, 0, 0),
        Transparency = 0.5,
        Callback = function(color, transparency)
            tracerColor = color
            tracerTransparency = transparency
        end
    })
    
    -- Targeting Mode Dropdown
    RageBotSection:Dropdown({
        Name = "Target Selection",
        Flag = "TargetingMode",
        Default = "CursorNearest",
        Options = {"CursorNearest", "CenterNearest", "HealthBased", "ClosestLocalDist"},
        Callback = function(value)
            vars.framework.setTargetingMode(value)
        end
    })
    
    RageBotSection:Dropdown({
        Name = "Priority Mode",
        Flag = "PriorityMode",
        Default = {},
        Options = {"LowestHealth", "NotCovered", "NearestToLocalPlayer"},
        Multi = true,
        Callback = function(value)
            -- Берем первый выбранный приоритет
            if value and #value > 0 then
                vars.framework.setPriorityMode(value[1])
            end
        end
    })
    
    -- HitParts Selection Dropdown
    RageBotSection:Dropdown({
        Name = "Hit Parts",
        Flag = "HitPartsSelection", 
        Default = {"Head", "Torso"},
        Options = vars.HitParts,
        Multi = true,
        Callback = function(value)
            -- Обновляем выбранные hitparts
            if value and #value > 0 then
                vars.framework.setSelectedHitParts(value)
            else
                -- Если ничего не выбрано, ставим по умолчанию голову
                vars.framework.setSelectedHitParts({"Head"})
            end
        end
    })
end

-- Вкладка Players с ESP и Chams
do
    local Column = Tabs.Players:Column()
    local EspPreviewSection = Column:Section({Name = "ESP"})
    local EspPreview = EspPreviewSection:EspPreview({})
    local PlayersTab = EspPreview:AddTab({
        Name = "Players", 
        Model = "rbxassetid://14966982841",
        Chams = true
    })
    
    PlayersTab.AddBar({Name = "Healthbar", Prefix = "Healthbar"})
    PlayersTab.AddText({Name = "Name", Prefix = "Name"})
    PlayersTab.AddText({Name = "Distance", Prefix = "Distance"})
    PlayersTab.AddBox({Name = "Box"})
    
    local Column2 = Tabs.Players:Column()
end

-- Вкладка Visuals (пустая)
do
    -- Пустая вкладка для будущих визуальных функций
end

-- Настройки
local SettingsTab = Window:Tab({Name = "Settings"})
Library:Configs(Holder, SettingsTab)

-- Обновление заголовка окна
do
    vars.utility.new_connection(vars.RunService.Heartbeat, function()
        if Holder.Items.Holder.Visible then
            Holder.ChangeMenuTitle(string.format("xerox.tech - universal - %s", os.date("%H:%M:%S")))
        end
    end)
end

-- Инициализация ESP
do
    -- Инициализация MiscOptions
    for index, value in MiscOptions do 
        Options[index] = value
    end
    
    -- Создание ESP объектов для существующих игроков
    for _, player in vars.Players:GetPlayers() do 
        if player == vars.LocalPlayer then 
            continue 
        end 
        Esp.CreateObject(player)
    end 
    
    -- Подключение событий
    Esp:Connection(vars.Players.PlayerRemoving, Esp.RemovePlayer)
    Esp:Connection(vars.Players.PlayerAdded, function(player)
        Esp.CreateObject(player)
        
        for index, value in MiscOptions do 
            Options[index] = value
        end 
    end)
end
