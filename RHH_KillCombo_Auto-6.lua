--// ============================================
--// RedHood Hub — Kill Combo AUTO  v6
--// Kill Everyone → TP Safe Platform → Server Hop (12s)
--// + Watchdog: si el hop no ejecuta en 15s, fuerza Teleport directo
--// ============================================

-- Evitar doble ejecución
if _G.RHH_KillComboRunning then
    _G.RHH_KillComboRunning = false
    task.wait(0.3)
end
_G.RHH_KillComboRunning = true

-- ============================================
-- SERVICIOS
-- ============================================
local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")

local player      = Players.LocalPlayer
local muscleEvent = player:WaitForChild("muscleEvent")

-- ============================================
-- NOTIFY
-- ============================================
local function Notify(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "Kill Combo",
            Text     = msg,
            Duration = 5,
        })
    end)
end

-- ============================================
-- HELPERS
-- ============================================
local function checkCharacter()
    if not player.Character then
        repeat task.wait() until player.Character
    end
    return player.Character
end

local function isPlayerAlive(p)
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and
           p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0
end

-- ============================================
-- KILL PLAYER
-- ============================================
local function killPlayer(target)
    if not isPlayerAlive(target) then return end
    local char = checkCharacter()
    if char and char:FindFirstChild("LeftHand") then
        pcall(function()
            firetouchinterest(target.Character.HumanoidRootPart, char.LeftHand, 0)
            firetouchinterest(target.Character.HumanoidRootPart, char.LeftHand, 1)
            for _, v in pairs(player.Backpack:GetChildren()) do
                if v.Name == "Punch" and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:EquipTool(v)
                end
            end
            muscleEvent:FireServer("punch", "leftHand")
            task.wait(0.12)
            muscleEvent:FireServer("punch", "rightHand")
        end)
    end
end

-- ============================================
-- SAFE PLATFORM
-- ============================================
local _safePlatform    = nil
local _safePlatformPos = Vector3.new(7840, 300, 9345)

local function goToSafePlatform()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")

    if _safePlatform and _safePlatform.Parent then
        hrp.CFrame = CFrame.new(_safePlatform.Position + Vector3.new(0, 7, 0))
        Notify("TP a plataforma existente")
        return
    end

    local targetPos = _safePlatformPos
    local oldPos    = hrp.Position
    hrp.CFrame      = CFrame.new(targetPos)
    task.wait(0.5)
    if (hrp.Position - oldPos).Magnitude < 50 then
        targetPos  = targetPos + Vector3.new(0, 100, 0)
        hrp.CFrame = CFrame.new(targetPos)
    end

    local base = hrp.Position - Vector3.new(0, 4, 0)

    local platform = Instance.new("Part")
    platform.Name       = "RHH_Platform"
    platform.Size       = Vector3.new(80, 3, 80)
    platform.CFrame     = CFrame.new(base)
    platform.Anchored   = true
    platform.CanCollide = true
    platform.Color      = Color3.fromRGB(8, 3, 3)
    platform.Material   = Enum.Material.SmoothPlastic
    platform.Parent     = workspace
    _safePlatform       = platform

    local function makeBorder(size, pos, rot)
        local b = Instance.new("Part")
        b.Name        = "RHH_PlatBorder"
        b.Size        = size
        b.CFrame      = CFrame.new(base + pos) * rot
        b.Anchored    = true
        b.CanCollide  = false
        b.Color       = Color3.fromRGB(200, 30, 30)
        b.Material    = Enum.Material.Neon
        b.CastShadow  = false
        b.Parent      = workspace
    end

    local bLen, bThk, bH = 80, 0.5, 3.2
    makeBorder(Vector3.new(bLen, bH, bThk), Vector3.new(0,  0,  40), CFrame.new())
    makeBorder(Vector3.new(bLen, bH, bThk), Vector3.new(0,  0, -40), CFrame.new())
    makeBorder(Vector3.new(bThk, bH, bLen), Vector3.new( 40, 0,   0), CFrame.new())
    makeBorder(Vector3.new(bThk, bH, bLen), Vector3.new(-40, 0,   0), CFrame.new())

    local function makeGrid(size, pos)
        local g = Instance.new("Part")
        g.Name         = "RHH_PlatGrid"
        g.Size         = size
        g.CFrame       = CFrame.new(base + pos)
        g.Anchored     = true
        g.CanCollide   = false
        g.Color        = Color3.fromRGB(60, 8, 8)
        g.Material     = Enum.Material.Neon
        g.Transparency = 0.6
        g.CastShadow   = false
        g.Parent       = workspace
    end

    for i = -30, 30, 20 do
        makeGrid(Vector3.new(80, 0.12, 0.25), Vector3.new(0, 1.6,  i))
        makeGrid(Vector3.new(0.25, 0.12, 80), Vector3.new(i, 1.6,  0))
    end

    local decal         = Instance.new("Decal")
    decal.Texture       = "rbxassetid://95596426520626"
    decal.Face          = Enum.NormalId.Top
    decal.Transparency  = 0.6
    decal.Parent        = platform

    Notify("Plataforma creada  "
        .. math.floor(hrp.Position.X) .. ", "
        .. math.floor(hrp.Position.Y) .. ", "
        .. math.floor(hrp.Position.Z))
end

-- ============================================
-- SERVER HOP — busca servers con buena gente
-- ============================================
local function serverHop()
    Notify("Buscando server con gente...")

    local placeId   = game.PlaceId
    local currentId = game.JobId
    local target    = nil

    for attempt = 1, 2 do
        local threshold = attempt == 1 and 0.5 or 0.2
        local cursor    = nil

        for _ = 1, 5 do
            local url = "https://games.roblox.com/v1/games/"
                .. placeId
                .. "/servers/Public?sortOrder=Desc&limit=100"
                .. (cursor and ("&cursor=" .. cursor) or "")

            local ok, raw   = pcall(game.HttpGet, game, url)
            if not ok then break end

            local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
            if not ok2 or not data or not data.data then break end

            for _, srv in ipairs(data.data) do
                local ratio = srv.maxPlayers > 0
                    and (srv.playing / srv.maxPlayers) or 0
                local hasRoom = (srv.maxPlayers - srv.playing) >= 3
                if srv.id ~= currentId
                    and ratio >= threshold
                    and ratio < 0.85
                    and hasRoom
                then
                    target = srv.id
                    break
                end
            end

            if target then break end
            cursor = data.nextPageCursor
            if not cursor or cursor == "" then break end
            task.wait(0.2)
        end

        if target then break end
    end

    task.wait(0.5)

    if target then
        Notify("Hopping a server poblado...")
        pcall(TeleportService.TeleportToPlaceInstance, TeleportService, placeId, target, player)
    else
        Notify("Fallback hop...")
        pcall(TeleportService.Teleport, TeleportService, placeId, player)
    end
end

-- ============================================
-- SERVER HOP + WATCHDOG DE 15s
-- Si serverHop() se cuelga o tarda más de 15s,
-- el watchdog fuerza un Teleport directo.
-- ============================================
local function serverHopConWatchdog()
    local placeId  = game.PlaceId
    local _hopDone = false

    -- Watchdog paralelo
    task.spawn(function()
        task.wait(15)
        if not _hopDone then
            _hopDone = true
            Notify("Watchdog: forzando hop...")
            pcall(TeleportService.Teleport, TeleportService, placeId, player)
        end
    end)

    -- Hop normal
    serverHop()

    -- Marcar como done para que el watchdog no dispare de más
    _hopDone = true
end

-- ============================================
-- SECUENCIA PRINCIPAL
-- ============================================
local function runSequence()
    Notify("Kill Combo iniciado")

    -- FASE 1: Kill loop
    local killing = true
    task.spawn(function()
        while killing and _G.RHH_KillComboRunning do
            for _, p in ipairs(Players:GetPlayers()) do
                if not killing then break end
                if p ~= player then killPlayer(p) end
            end
            task.wait(0.15)
        end
    end)

    -- FASE 2: 1.5s → plataforma segura
    task.wait(1.5)
    goToSafePlatform()

    -- FASE 3: countdown 12s → server hop
    for i = 12, 1, -1 do
        if not _G.RHH_KillComboRunning then killing = false; return end
        if i == 12 or i == 5 or i <= 3 then
            Notify("Server hop en " .. i .. "s")
        end
        task.wait(1)
    end

    killing = false
    task.wait(0.3)
    serverHopConWatchdog()  -- << watchdog activo acá
    _G.RHH_KillComboRunning = false
end

-- ============================================
-- AUTOSTART
-- ============================================
local char = player.Character or player.CharacterAdded:Wait()
char:WaitForChild("HumanoidRootPart")
task.wait(1)
runSequence()
