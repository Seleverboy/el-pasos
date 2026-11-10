--[[=================================================================
    EL PASO  •  v4.1  •  by selever_el
    LANDSCAPE EDITION
    ─────────────────────────────────────────────────────────────────
    • Landscape panel (840×520), centered on screen
    • Tabs on LEFT vertical sidebar
    • Misc is LAST tab
    • No Cooldown Jump replaces bunny hop (bypasses game jump debounce)
    • Delete All Gates + Tuned Car moved into Cheats tab
    • Frosted glass INSIDE the panel (no game blur)
    • 5 refined themes: Onyx · Sage · Ice · Crimson · Ivory
    • Lost Front–style splash
    =================================================================]]

local function Num(n) return tonumber(n) or 0 end
local function O(x) return x or 0 end

if _G.EP_Loaded then pcall(_G.EP_Unload) end
_G.EP_Loaded = true
_G.EP_Unloaded = false

--============== SERVICES ==============
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer

local loadTimer = 0
while not (game:IsLoaded() and workspace:FindFirstChild("GameManager") and RS:FindFirstChild("Packages")) and loadTimer < 20 do
    task.wait(0.5); loadTimer = loadTimer + 1;
end

--============== REMOVE STARTER PACK UI ==============
task.spawn(function()
    local PlayerGui = LP:WaitForChild("PlayerGui")
    
    local function destroyStarterPackUI(inst)
        -- Checks if the name matches any variation of "Starter Pack"
        if inst.Name == "StarterPack" or inst.Name == "Starterpack" or string.find(string.lower(inst.Name), "starterpack") then
            if inst:IsA("GuiObject") or inst:IsA("ScreenGui") or inst:IsA("BillboardGui") then
                inst:Destroy()
            end
        end
    end

    -- 1. Try to destroy it immediately if it's already loaded
    local main = PlayerGui:WaitForChild("Main", 5)
    if main then
        local sp = main:FindFirstChild("StarterPack")
        if sp then sp:Destroy() end
        local sp2 = main:FindFirstChild("Starterpack")
        if sp2 then sp2:Destroy() end
    end

    -- 2. Sweep the entire PlayerGui to catch any hiding elements
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        destroyStarterPackUI(v)
    end

    -- 3. Listen for it being added later (in case the game re-adds it)
    PlayerGui.DescendantAdded:Connect(destroyStarterPackUI)
    				
    -- 4. Just in case it's a BillboardGui attached to a part in the world
    for _, v in ipairs(workspace:GetDescendants()) do
        destroyStarterPackUI(v)
    end
    workspace.DescendantAdded:Connect(destroyStarterPackUI)
end)
--====================================================

--============== NET / REMOTE LOOKUP ==============
local Packages = RS:FindFirstChild("Packages")
local NetMod = nil
if Packages then
    local netFolder = Packages:FindFirstChild("Net")
    if netFolder then
        local ok, m = pcall(require, netFolder)
        if ok and m then NetMod = m end
    end
end

local function findRemote(name, class)
    if NetMod then
        local method = (class == "RemoteEvent") and "RemoteEvent" or "RemoteFunction"
        local ok, r = pcall(function() return NetMod[method](NetMod, name) end)
        if ok and typeof(r) == "Instance" then return r end
    end
    local function matches(i) return i:IsA(class) or i:IsA("UnreliableRemoteEvent") end
    local r = RS:FindFirstChild(name, true)
    if r and matches(r) then return r end
    local prefix = (class == "RemoteEvent") and "RE/" or "RF/"
    r = RS:FindFirstChild(prefix .. name, true)
    if r and matches(r) then return r end
    if Packages then
        local net = Packages:FindFirstChild("Net")
        if net then
            local sub = net:FindFirstChild((class == "RemoteEvent") and "RE" or "RF")
            if sub then
                local found = sub:FindFirstChild(name, true)
                if found then return found end
            end
        end
    end
    return nil
end

--============== STATE ==============
local State = {
    ESPEnabled=false, ESPTracers=false, ESPShowInfo=true,
    ESPMaxDistance=500, ESPFilter="All",
    AimEnabled=false, AimAutoEquip=false, AimSmoothness=0.6,
    AimMaxDistance=1500, AimUseHead=true,
    Godmode=false, AntiRagdoll=false, AntiArrest=false,
    SpeedEnabled=false, SpeedValue=55,
    JumpEnabled=false, JumpValue=120,
    FlyEnabled=false, FlySpeed=120,
    Noclip=false, InfiniteStamina=false,
    InfiniteAmmo=false, NoRecoil=false, AutoReload=false,
    AutoDaily=false, AutoLaunder=false, AutoTruck=false, AutoATM=false,
    ESPData={}, GodConn=nil, FlyBV=nil,
    Target=nil, TargetPart=nil,
    TunedCarEnabled=false,
    FullbrightEnabled=false, HitboxEnabled=false, HitboxSize=15,
    ClickTPEnabled=false, NoCooldownJump=false,
    CarTPAutoSpawn=true
}
_G.EP_State = State

-- Forward-declared so the Unload button (defined later) can close over them
local ClickTPConn, NoCDJumpConn, MainKeybindConn

-- NEW: pauses TunedCar while a trick is running
local EP_TrickActive = false
local EP_TrickUntil  = 0

--============== MAP DELETER STATE ==============
local HiddenFolder = Instance.new("Folder")
HiddenFolder.Name = "EP_HiddenMap_" .. tostring(math.random(1000, 9999))
HiddenFolder.Parent = RS

local DeletedParts = {}
local MapDeleted = false
local SafePlatform = nil
local MapBusy = false
--============== ROLE DETECTION ==============
local ROLE_COLORS = {
    Criminal = Color3.fromRGB(255, 70, 70), Civilian = Color3.fromRGB(70, 255, 100),
    Paramedic= Color3.fromRGB(255, 255, 255), Federal = Color3.fromRGB(70, 140, 255),
    Dead     = Color3.fromRGB(80, 80, 80), Other = Color3.fromRGB(190, 190, 190),
}
local FED_TEAM_COLORS = {
    ["Border Patrol"]=Color3.fromRGB(0,130,255),["Border Supervisor"]=Color3.fromRGB(255,140,0),
    ["BORTAC"]=Color3.fromRGB(0,170,80),["US Army"]=Color3.fromRGB(110,150,70),
    ["State Trooper"]=Color3.fromRGB(150,150,230),["FBI"]=Color3.fromRGB(230,210,60),
    ["HSI"]=Color3.fromRGB(0,210,210),["SWAT"]=Color3.fromRGB(90,90,230),
}
local function getRole(plr)
    if plr == LP then return "You","" end
    local char = plr.Character; if not char then return "None","" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return "Dead","" end
    local team = plr.Team; if not team then return "Other","" end
    local n = team.Name
    if n == "Civilian" then
        local rev = plr:GetAttribute("Revision"); local det = plr:GetAttribute("Detained")
        if rev=="Wanted" or rev=="Hostile" or det=="Detained" or det=="Arrested" then return "Criminal",n end
        return "Civilian",n
    end
    if n == "Paramedic" then return "Paramedic",n end
    if team:HasTag("Federal") then return "Federal",n end
    return "Other",n
end
local function getRoleColor(role, teamName)
    if role == "Federal" then return FED_TEAM_COLORS[teamName] or ROLE_COLORS.Federal end
    return ROLE_COLORS[role] or ROLE_COLORS.Other
end
local function getMyRole()
    local t = LP.Team; if not t then return "Other" end
    if t.Name == "Civilian" then return "Civilian" end
    if t.Name == "Paramedic" then return "Paramedic" end
    if t:HasTag("Federal") then return "Federal" end
    return "Other"
end

--============== REMOTES ==============
local RCache, FCache = {}, {}
local function R(name)
    if RCache[name] then return RCache[name] end
    local r = findRemote(name, "RemoteEvent")
    if r then RCache[name] = r end
    return r
end
local function F(name)
    if FCache[name] then return FCache[name] end
    local r = findRemote(name, "RemoteFunction")
    if r then FCache[name] = r end
    return r
end

--============== BETTER TELEPORT ==============
local function safeTeleport(targetCFrame)
    local char = LP.Character; if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    char:PivotTo(targetCFrame)
    hrp.CFrame = targetCFrame
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 1, 0)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    task.delay(0.1, function()
        if bv then bv:Destroy() end
        if hrp and hrp.Parent then hrp.AssemblyLinearVelocity = Vector3.zero end
    end)
    return true
end

--============== ESP ==============
local function destroyESP(plr)
    local d = State.ESPData[plr]; if not d then return end
    if d.hl and d.hl.Parent then d.hl:Destroy() end
    if d.bb and d.bb.Parent then d.bb:Destroy() end
    if d.tracer and d.tracer.Parent then d.tracer:Destroy() end
    if d.att1 and d.att1.Parent then d.att1:Destroy() end
    if d.att2 and d.att2.Parent then d.att2:Destroy() end
    State.ESPData[plr] = nil
end
local function createESP(plr)
    if plr == LP then return end
    local char = plr.Character; if not char then return end
    destroyESP(plr)
    local role, teamName = getRole(plr)
    local color = getRoleColor(role, teamName)
    local hl = Instance.new("Highlight")
    hl.Name = "EP_ESP_HL"; hl.FillColor = color; hl.FillTransparency = 0.72
    hl.OutlineColor = color; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char; hl.Parent = char
    local bb = Instance.new("BillboardGui")
    bb.Name = "EP_ESP_BB"; bb.Size = UDim2.fromOffset(220,52)
    bb.StudsOffsetWorldSpace = Vector3.new(0,2.6,0)
    bb.AlwaysOnTop = true; bb.LightInfluence = 0
    bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char
    bb.Parent = char
    local name = Instance.new("TextLabel", bb)
    name.Size = UDim2.new(1,0,0.4,0); name.BackgroundTransparency = 1
    name.TextColor3 = color; name.Font = Enum.Font.GothamBold; name.TextSize = 14
    name.TextStrokeTransparency = 0; name.TextStrokeColor3 = Color3.new(0,0,0)
    name.Text = plr.Name .. " @" .. plr.DisplayName
    local info = Instance.new("TextLabel", bb)
    info.Size = UDim2.new(1,0,0.3,0); info.Position = UDim2.new(0,0,0.4,0)
    info.BackgroundTransparency = 1; info.TextColor3 = Color3.new(1,1,1)
    info.Font = Enum.Font.Gotham; info.TextSize = 11
    info.TextStrokeTransparency = 0; info.TextStrokeColor3 = Color3.new(0,0,0)
    info.Text = role .. " • " .. teamName
    local dist = Instance.new("TextLabel", bb)
    dist.Size = UDim2.new(1,0,0.3,0); dist.Position = UDim2.new(0,0,0.7,0)
    dist.BackgroundTransparency = 1; dist.TextColor3 = Color3.fromRGB(200,200,200)
    dist.Font = Enum.Font.Gotham; dist.TextSize = 10
    dist.TextStrokeTransparency = 0; dist.TextStrokeColor3 = Color3.new(0,0,0)
    dist.Text = "0m"
    local tracer, att1, att2
    if State.ESPTracers then
        att1 = Instance.new("Attachment", workspace.CurrentCamera); att1.Name = "EP_TracerCam"
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if hrp then
            att2 = Instance.new("Attachment", hrp); att2.Name = "EP_TracerTarget"
            tracer = Instance.new("Beam")
            tracer.Name = "EP_ESP_Tracer"; tracer.Attachment0 = att1; tracer.Attachment1 = att2
            tracer.Width0 = 0.05; tracer.Width1 = 0.05; tracer.FaceCamera = true
            tracer.Color = ColorSequence.new(color); tracer.LightEmission = 1
            tracer.Transparency = NumberSequence.new(0.3); tracer.Parent = att1
        end
    end
    State.ESPData[plr] = {hl=hl,bb=bb,name=name,info=info,dist=dist,char=char,tracer=tracer,att1=att1,att2=att2}
end
local function refreshESPRole(plr)
    local d = State.ESPData[plr]; if not d or not d.bb.Parent then return end
    local role, teamName = getRole(plr)
    local color = getRoleColor(role, teamName)
    local isRobbing = plr:GetAttribute("BankRobberyVisible") or plr:GetAttribute("JewelryRobberyVisible")
    local bounty = plr:GetAttribute("Bounty") or 0
    local statusText = role .. " • " .. teamName
    if isRobbing then
        statusText = "ROBBING"
        d.info.TextColor3 = Color3.fromRGB(255,50,50)
        d.hl.FillColor = Color3.fromRGB(255,50,50); d.hl.OutlineColor = Color3.fromRGB(255,50,50)
        d.name.TextColor3 = Color3.fromRGB(255,50,50)
    else
        d.info.TextColor3 = Color3.new(1,1,1)
        d.hl.FillColor = color; d.hl.OutlineColor = color; d.name.TextColor3 = color
        if bounty > 0 then statusText = statusText .. " • $" .. tostring(bounty) end
    end
    d.info.Text = statusText
    if d.tracer then d.tracer.Color = ColorSequence.new(color) end
end
local function rebuildESP()
    for plr in pairs(State.ESPData) do destroyESP(plr) end
    if not State.ESPEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LP then createESP(plr) end end
end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() task.wait(0.3); if State.ESPEnabled then createESP(plr) end end)
end)
Players.PlayerRemoving:Connect(function(plr) destroyESP(plr) end)
RunService.Heartbeat:Connect(function()
    if not State.ESPEnabled then return end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myRole = getMyRole()
    for plr, d in pairs(State.ESPData) do
        if not d.char or not d.char.Parent then
            destroyESP(plr)
        else
            local hrp = d.char:FindFirstChild("HumanoidRootPart")
            if myRoot and hrp then
                local distance = (hrp.Position - myRoot.Position).Magnitude
                local isEnemy = false; local role = getRole(plr)
                if myRole == "Federal" and role == "Criminal" then isEnemy = true end
                if myRole == "Civilian" and role == "Federal" then isEnemy = true end
                local shouldShow = distance <= State.ESPMaxDistance
                if shouldShow and State.ESPFilter == "Enemies" and not isEnemy then shouldShow = false end
                d.hl.Enabled = shouldShow; d.bb.Enabled = shouldShow
                if d.tracer then d.tracer.Enabled = shouldShow end
                if shouldShow then d.dist.Text = math.floor(distance) .. "m" end
                local hum = d.char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health <= 0 then d.name.TextColor3 = ROLE_COLORS.Dead end
            else
                d.hl.Enabled = false; d.bb.Enabled = false
                if d.tracer then d.tracer.Enabled = false end
            end
        end
    end
end)
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(1)
        if State.ESPEnabled then
            for plr in pairs(State.ESPData) do pcall(refreshESPRole, plr) end
        end
    end
end)

--============== AIMBOT ==============
local function findTarget()
    local myRole = getMyRole()
    if myRole ~= "Federal" and myRole ~= "Civilian" then return nil end
    local char = LP.Character; if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end
    local myPos = myRoot.Position
    local best, bestD = nil, State.AimMaxDistance
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local role = getRole(plr)
            local want = (myRole=="Federal" and role=="Criminal") or (myRole=="Civilian" and role=="Federal")
            if want then
                local c = plr.Character
                if c then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    local tp = State.AimUseHead and c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and tp then
                        local d = (tp.Position - myPos).Magnitude
                        if d < bestD then best = plr; bestD = d end
                    end
                end
            end
        end
    end
    return best, bestD
end
local function aimAt(plr)
    local c = plr.Character; if not c then return end
    local tp = State.AimUseHead and c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    if not tp then return end
    local cam = workspace.CurrentCamera; if not cam then return end
    local mp = cam.CFrame.Position
    local dir = (tp.Position - mp).Unit
    local goal = CFrame.lookAt(mp, mp + dir)
    if State.AimSmoothness >= 1 then cam.CFrame = goal
    else cam.CFrame = cam.CFrame:Lerp(goal, State.AimSmoothness) end
end
local function equipBestGun()
    local char = LP.Character; if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and currentTool:FindFirstChild("GunSettings") then return currentTool end
    local priority = {"M249","M82","AK-47","AR-15","HK416","Benelli M4","MP5","Glock","M1911"}
    local backpack = LP:FindFirstChild("Backpack"); if not backpack then return nil end
    for _, gunName in ipairs(priority) do
        local gun = backpack:FindFirstChild(gunName)
        if gun and gun:IsA("Tool") and gun:FindFirstChild("GunSettings") then
            pcall(function() hum:EquipTool(gun) end); return gun
        end
    end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("GunSettings") then
            pcall(function() hum:EquipTool(tool) end); return tool
        end
    end
    return nil
end
local function unequipGun()
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local currentTool = char:FindFirstChildWhichIsA("Tool")
        if currentTool and currentTool:FindFirstChild("GunSettings") then
            pcall(function() hum:UnequipTools() end)
        end
    end
end
local lastTargetScan = 0
RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastTargetScan >= 0.1 then
        lastTargetScan = now
        local ok, plr = pcall(findTarget)
        State.Target = (ok and plr) or nil
        if State.AimAutoEquip then pcall(equipBestGun) end
    end
    if State.Target and (State.AimEnabled or State.AimAutoEquip) then
        pcall(aimAt, State.Target)
    end
end)

--============== SAFE CHEATS ==============
local function ToggleFullbright()
    State.FullbrightEnabled = not State.FullbrightEnabled
    if State.FullbrightEnabled then
        Lighting.Brightness = 3; Lighting.ClockTime = 14
        Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
    else
        Lighting.Brightness = 1; Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000; Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end
local originalSizes = {}
local hitboxESP = {}
local function updateHitbox()
    if State.HitboxEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local head = plr.Character:FindFirstChild("Head")
                if hrp then
                    if not originalSizes[hrp] then originalSizes[hrp] = hrp.Size end
                    hrp.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                    hrp.Transparency = 0.7
                    if not hitboxESP[hrp] or not hitboxESP[hrp].Parent then
                        local box = Instance.new("BoxHandleAdornment")
                        box.Size = hrp.Size; box.Adornee = hrp; box.AlwaysOnTop = true
                        box.ZIndex = 5; box.Transparency = 0.5; box.Color3 = Color3.fromRGB(255,0,0)
                        box.Parent = hrp; hitboxESP[hrp] = box
                    else hitboxESP[hrp].Size = hrp.Size end
                end
                if head then
                    if not originalSizes[head] then originalSizes[head] = head.Size end
                    head.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                    head.Transparency = 0.7
                end
            end
        end
    else
        for part, size in pairs(originalSizes) do
            if part and part.Parent then part.Size = size; part.Transparency = 0 end
        end
        table.clear(originalSizes)
        for part, box in pairs(hitboxESP) do if box and box.Parent then box:Destroy() end end
        table.clear(hitboxESP)
    end
end
task.spawn(function()
    while not _G.EP_Unloaded do task.wait(0.5); updateHitbox() end
end)
ClickTPConn = UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.T and State.ClickTPEnabled then
        local mouse = LP:GetMouse()
        local hit = mouse.Hit
        if hit then safeTeleport(CFrame.new(hit.Position + Vector3.new(0,3,0))) end
    end
end)

--============== NO COOLDOWN JUMP ==============
NoCDJumpConn = UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not State.NoCooldownJump then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end

    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end

    -- THIS IS THE FIX: If you are in the air, ignore the jump input completely.
    if hum.FloorMaterial == Enum.Material.Air then
        return
    end

    task.defer(function()
        if hum.Parent then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end)

--============== GODMODE ==============
local function clearRagdollState(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- 1) Character can survive without a neck joint (this is what makes you look dead)
    if hum.RequiresNeck then hum.RequiresNeck = false end

    -- 2) Prevent the client from ever entering ragdoll/death states
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,        false) end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics,     false) end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)

    -- 3) Rebuild RootJoint / Neck if the game ripped them out
    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local head  = char:FindFirstChild("Head")
    if hrp and torso then
        if not hrp:FindFirstChild("RootJoint") then
            local rj = Instance.new("Motor6D")
            rj.Name  = "RootJoint"
            rj.Part0 = hrp
            rj.Part1 = torso
            rj.C0    = CFrame.Angles(-math.pi/2, 0, math.pi)
            rj.C1    = CFrame.Angles(-math.pi/2, 0, math.pi)
            rj.Parent = hrp
        end
        if head and not torso:FindFirstChild("Neck") then
            local nk = Instance.new("Motor6D")
            nk.Name  = "Neck"
            nk.Part0 = torso
            nk.Part1 = head
            nk.C0    = CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
            nk.C1    = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
            nk.Parent = torso
        end
    end

    -- 4) Re-enable all disabled Motor6Ds (ACS uses this to ragdoll you)
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and not d.Enabled then d.Enabled = true end
    end

    -- 5) Un-ragdoll + restore health
    if hum.PlatformStand then hum.PlatformStand = false end
    if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end

    -- 6) Break out of any residual lock state
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Dead
        or st == Enum.HumanoidStateType.Physics
        or st == Enum.HumanoidStateType.FallingDown then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    -- 7) Clear ACS lock attributes on the character
    local ac = char:FindFirstChild("ACS_Client")
    if ac then
        for _, a in ipairs({"Collapsed","Injured","Bleeding","Dragging","Surrender","Tourniquet"}) do
            if ac:GetAttribute(a) == true then ac:SetAttribute(a, false) end
        end
    end

    -- 8) Clear player-level lock attributes
    pcall(function()
        if LP:GetAttribute("Ragdoll")      == true then LP:SetAttribute("Ragdoll", false) end
        if LP:GetAttribute("Electrocuted") == true then LP:SetAttribute("Electrocuted", false) end
    end)
end

local function enableGodmode(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if State.GodConn then State.GodConn:Disconnect() end
    State.GodConn = hum.HealthChanged:Connect(function(h)
        if State.Godmode then
            if h < hum.MaxHealth then hum.Health = hum.MaxHealth end
            clearRagdollState(char)
        end
    end)
    if State.Godmode then clearRagdollState(char) end
end

-- Godmode reset loop — runs every frame so there's no visible "dead" moment
task.spawn(function()
    while not _G.EP_Unloaded do
        if State.Godmode then
            local c = LP.Character
            if c then clearRagdollState(c) end
        end
        RunService.Heartbeat:Wait()
    end
end)

--============== ANTI-RAGDOLL / ANTI-ARREST ==============
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(0.5)
        if State.AntiRagdoll then
            pcall(function() if LP:GetAttribute("Ragdoll")==true then LP:SetAttribute("Ragdoll",false) end end)
        end
        if State.AntiArrest then
            pcall(function()
                local det = LP:GetAttribute("Detained")
                if det=="Detained" or det=="Arrested" then LP:SetAttribute("Detained","Not Detained") end
            end)
        end
    end
end)

LP.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    enableGodmode(char)
    if State.Godmode then clearRagdollState(char) end
end)

--============== ANTI ==============
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(0.5)
        if State.AntiRagdoll then
            pcall(function() if LP:GetAttribute("Ragdoll")==true then LP:SetAttribute("Ragdoll",false) end end)
        end
        if State.AntiArrest then
            pcall(function()
                local det = LP:GetAttribute("Detained")
                if det=="Detained" or det=="Arrested" then LP:SetAttribute("Detained","Not Detained") end
            end)
        end
    end
end)

--============== MOVEMENT ==============
RunService.Stepped:Connect(function()
    local c = LP.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if State.SpeedEnabled then hum.WalkSpeed = State.SpeedValue end
    if State.JumpEnabled then hum.JumpPower = State.JumpValue; hum.UseJumpPower = true end
    if State.InfiniteStamina then
        pcall(function()
            local ac = c:FindFirstChild("ACS_Client")
            if ac then
                local var = ac:FindFirstChild("Variaveis")
                local stam = var and var:FindFirstChild("Stamina")
                if stam then stam.Value = stam.MaxValue end
            end
        end)
    end
    if State.Noclip then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)
local function toggleFly(on)
    if on then
        local c = LP.Character; if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if State.FlyBV then State.FlyBV:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "EP_Fly"; bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
        bv.Velocity = Vector3.zero; bv.Parent = hrp; State.FlyBV = bv
    else
        if State.FlyBV then State.FlyBV:Destroy(); State.FlyBV = nil end
    end
end
RunService.RenderStepped:Connect(function()
    if not State.FlyEnabled or not State.FlyBV then return end
    local cam = workspace.CurrentCamera; local c = LP.Character
    if not c or not cam then return end
    local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local move = Vector3.zero
    if hum.MoveDirection.Magnitude > 0 then move = (cam.CFrame:VectorToWorldSpace(hum.MoveDirection)) * State.FlySpeed end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, State.FlySpeed, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, State.FlySpeed, 0) end
    State.FlyBV.Velocity = move
end)

--============== WEAPON PATCH ==============
local gsOriginals = setmetatable({}, {__mode = "k"})
local function patchTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local gsMod = tool:FindFirstChild("GunSettings"); if not gsMod then return end
    pcall(function()
        local gs = require(gsMod); if type(gs) ~= "table" then return end
        if not gsOriginals[gs] then
            gsOriginals[gs] = {
                Ammo=gs.Ammo, AmmoInGun=gs.AmmoInGun, StoredAmmo=gs.StoredAmmo,
                GLAmmo=gs.GLAmmo, GLStoredAmmo=gs.GLStoredAmmo,
                camRecoil=gs.camRecoil, gunRecoil=gs.gunRecoil,
            }
        end
        local o = gsOriginals[gs]
        if State.InfiniteAmmo then
            gs.Ammo=999; gs.AmmoInGun=999; gs.StoredAmmo=999; gs.GLAmmo=999; gs.GLStoredAmmo=999
        else
            gs.Ammo=o.Ammo; gs.AmmoInGun=o.AmmoInGun; gs.StoredAmmo=o.StoredAmmo
            gs.GLAmmo=o.GLAmmo; gs.GLStoredAmmo=o.GLStoredAmmo
        end
        if State.NoRecoil then
            gs.camRecoil = {camRecoilUp={0,0},camRecoilLeft={0,0},camRecoilRight={0,0},camRecoilTilt={0,0}}
            gs.gunRecoil = {gunRecoilUp={0,0},gunRecoilTilt={0,0},gunRecoilLeft={0,0},gunRecoilRight={0,0}}
        else
            if o.camRecoil then gs.camRecoil = o.camRecoil end
            if o.gunRecoil then gs.gunRecoil = o.gunRecoil end
        end
    end)
end
local function hookBag(bag)
    if not bag then return end
    for _, t in ipairs(bag:GetChildren()) do patchTool(t) end
    bag.ChildAdded:Connect(function(t) task.defer(patchTool, t) end)
end
if LP:FindFirstChild("Backpack") then hookBag(LP.Backpack) end
LP.ChildAdded:Connect(function(c) if c.Name=="Backpack" then hookBag(c) end end)
LP.CharacterAdded:Connect(function(c)
    c.ChildAdded:Connect(function(t) if t:IsA("Tool") then task.defer(patchTool,t) end end)
end)
if LP.Character then
    for _, t in ipairs(LP.Character:GetChildren()) do if t:IsA("Tool") then task.defer(patchTool,t) end end
end
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(2)
        pcall(function()
            if LP.Backpack then for _, t in ipairs(LP.Backpack:GetChildren()) do patchTool(t) end end
            if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do patchTool(t) end end
        end)
    end
end)
local function getAmmoRatio()
    local sg = LP.PlayerGui:FindFirstChild("StatusUI")
    local g = sg and sg:FindFirstChild("GunHUD")
    local a = g and g:FindFirstChild("AmmoCount")
    if a and a.Text then
        local cur, max = string.match(a.Text, "(%d+)/(%d+)")
        if cur and max then
            local curN = tonumber(cur)
            local maxN = tonumber(max)
            if curN and maxN and maxN > 0 then
                return curN / maxN
            end
        end
    end
    return 1
end
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(0.4)
        if State.AutoReload and getAmmoRatio() < 0.25 then
            pcall(function()
                UIS:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.05)
                UIS:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end)
        end
    end
end)

--============== AUTO FARM ==============
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(45)
        if State.AutoDaily then
            local r=R("DailyClaim"); if r then pcall(function() r:FireServer() end) end
        end
    end
end)
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(20)
        if State.AutoLaunder then
            local qf=F("LaunderQuote"); local lr=R("Launder")
            if qf and lr then
                local ok,q = pcall(function() return qf:InvokeServer() end)
                if ok and type(q)=="table" and q.Amount and q.Amount>0 and q.Enabled then
                    pcall(function() lr:FireServer() end)
                end
            end
        end
    end
end)
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(90)
        if State.AutoTruck then
            local r=R("TruckJob_Accept"); if r then pcall(function() r:FireServer("ChevlonExpress") end) end
        end
    end
end)
task.spawn(function()
    while not _G.EP_Unloaded do
        task.wait(5)
        if State.AutoATM then
            local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, atm in ipairs(CollectionService:GetTagged("ATM")) do
                    if atm:IsA("Model") then
                        local p = atm.PrimaryPart or atm:FindFirstChildWhichIsA("BasePart")
                        if p and (hrp.Position-p.Position).Magnitude<10 then
                            local r=R("RobATM"); if r then pcall(function() r:FireServer(atm) end) end
                        end
                    end
                end
            end
        end
    end
end)
local function deleteAllGates()
    local count = 0
    for _, g in pairs(CollectionService:GetTagged("BoomGate")) do g:Destroy(); count=count+1 end
    for _, g in pairs(CollectionService:GetTagged("VehicleGate")) do g:Destroy(); count=count+1 end
    for _, o in pairs(workspace:GetDescendants()) do
        if o:IsA("Model") and (o.Name:lower():find("gate") or o.Name:lower():find("barrier") or o.Name:lower():find("boom")) then
            o:Destroy(); count=count+1
        elseif o:IsA("ProximityPrompt") then
            local p = o.Parent
            if p and (p.Name:lower():find("gate") or p.Name:lower():find("barrier")) then o:Destroy() end
        end
    end
    return count
end

--============== TUNED CAR ==============
local TunedCar = {
    Car=nil, BodyVel=nil, BodyAng=nil, Root=nil, Speed=0, Turn=0,
    MaxSpeed=300, AccelRate=55, BrakeRate=140, CoastRate=20, TurnSpeed=1.8, ReverseSpeed=-60,
}
local function findCarRoot(car)
    if not car then return nil end
    if car.PrimaryPart then return car.PrimaryPart end
    local body = car:FindFirstChild("Body")
    if body then
        local cp = body:FindFirstChild("Collision_Part")
        if cp and cp:IsA("BasePart") then return cp end
    end
    local cp = car:FindFirstChild("Collision_Part", true)
    if cp and cp:IsA("BasePart") then return cp end
    return car:FindFirstChildWhichIsA("BasePart", true)
end

local function getCarAndSeat()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        local car = seat:FindFirstAncestorOfClass("Model")
        while car do
            if car:HasTag("Car")
               or car:GetAttribute("Owner") ~= nil
               or car:FindFirstChild("Body")
               or car:FindFirstChild("DriveSeat") then
                return car, seat
            end
            car = car:FindFirstAncestorOfClass("Model")
        end
    end
    return nil, nil
end
local function teardownTunedCar()
    if TunedCar.BodyVel then TunedCar.BodyVel:Destroy(); TunedCar.BodyVel = nil end
    if TunedCar.BodyAng then TunedCar.BodyAng:Destroy(); TunedCar.BodyAng = nil end
    TunedCar.Car = nil; TunedCar.Root = nil; TunedCar.Speed = 0; TunedCar.Turn = 0
end
RunService.Heartbeat:Connect(function(dt)
    if _G.EP_Unloaded then return end
    if not State.TunedCarEnabled then return end
    if EP_TrickActive and tick() < EP_TrickUntil then return end
    local car, seat = getCarAndSeat()
    if not car or not seat then teardownTunedCar(); return end
    if car ~= TunedCar.Car then
        TunedCar.Car = car
        if TunedCar.BodyVel then TunedCar.BodyVel:Destroy() end
        if TunedCar.BodyAng then TunedCar.BodyAng:Destroy() end
        local root = findCarRoot(car)
        TunedCar.Root = root
        if root then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(40000, 0, 40000)
            bv.Velocity = Vector3.zero; bv.Parent = root
            TunedCar.BodyVel = bv
            local ba = Instance.new("BodyAngularVelocity")
            ba.MaxTorque = Vector3.new(0, math.huge, 0)
            ba.AngularVelocity = Vector3.zero; ba.Parent = root
            TunedCar.BodyAng = ba
        end
    end
    local root = TunedCar.Root
    if TunedCar.BodyVel and TunedCar.BodyAng and root then
        local throttle = seat.ThrottleFloat; local steer = seat.SteerFloat
        if throttle > 0 then
            TunedCar.Speed = math.min(TunedCar.Speed + TunedCar.AccelRate * dt, TunedCar.MaxSpeed)
        elseif throttle < 0 then
            if TunedCar.Speed > 0 then
                TunedCar.Speed = math.max(TunedCar.Speed - TunedCar.BrakeRate * dt, 0)
            else
                TunedCar.Speed = math.max(TunedCar.Speed - TunedCar.AccelRate * dt, TunedCar.ReverseSpeed)
            end
        else
            if TunedCar.Speed > 0 then
                TunedCar.Speed = math.max(TunedCar.Speed - TunedCar.CoastRate * dt, 0)
            elseif TunedCar.Speed < 0 then
                TunedCar.Speed = math.min(TunedCar.Speed + TunedCar.CoastRate * dt, 0)
            end
        end
        local look = root.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit else flatLook = look.Unit end
        local actualVel = root.AssemblyLinearVelocity
        local forwardVel = actualVel:Dot(flatLook)
        if math.abs(TunedCar.Speed) > 15 and math.abs(forwardVel) < math.abs(TunedCar.Speed) * 0.5 then
            TunedCar.Speed = forwardVel
        end
        local safeYVelocity = actualVel.Y
        if safeYVelocity > 5 then safeYVelocity = 0 end
        TunedCar.BodyVel.Velocity = Vector3.new(flatLook.X * TunedCar.Speed, safeYVelocity, flatLook.Z * TunedCar.Speed)
        if math.abs(TunedCar.Speed) > 1 then
            local speedFactor = 1 - (math.abs(TunedCar.Speed) / TunedCar.MaxSpeed) * 0.4
            local targetTurn = -steer * TunedCar.TurnSpeed * speedFactor
            TunedCar.Turn = TunedCar.Turn + (targetTurn - TunedCar.Turn) * math.min(dt * 6, 1)
        else TunedCar.Turn = 0 end
        TunedCar.BodyAng.AngularVelocity = Vector3.new(0, TunedCar.Turn, 0)
    end
end)
_G.EP_TunedCar = TunedCar

--============== MAP DELETE / RESTORE ==============
local function getMyCar()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        local car = seat:FindFirstAncestorOfClass("Model")
        while car do
            if car:HasTag("Car") then return car end
            car = car:FindFirstAncestorOfClass("Model")
        end
    end
    return nil
end

local function DeleteMap()
    if MapDeleted or MapBusy then return end
    MapBusy = true

    local char = LP.Character
    local myCar = getMyCar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Invisible floor so you/car doesn't fall through
    if hrp then
        SafePlatform = Instance.new("Part")
        SafePlatform.Size = Vector3.new(2000, 5, 2000)
        SafePlatform.Position = hrp.Position - Vector3.new(0, 3.5, 0)
        SafePlatform.Anchored = true
        SafePlatform.CanCollide = true
        SafePlatform.CanQuery = false
        SafePlatform.CanTouch = false
        SafePlatform.Transparency = 1
        SafePlatform.Parent = workspace
    end

    table.clear(DeletedParts)

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name ~= "Camera" and obj.Name ~= "Terrain" and obj ~= SafePlatform then
            local isHumanoid = obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
            if not isHumanoid and obj ~= myCar then
                table.insert(DeletedParts, obj)
                obj.Parent = HiddenFolder
            end
        end
    end

    MapDeleted = true
    MapBusy = false
end

local function RestoreMap()
    if not MapDeleted or MapBusy then return end
    MapBusy = true

    local char = LP.Character
    local myCar = getMyCar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Lift car/player so they don't spawn inside a building
    if myCar and myCar.PrimaryPart then
        myCar:PivotTo(myCar:GetPivot() + Vector3.new(0, 50, 0))
        for _, part in ipairs(myCar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
    elseif hrp then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 15, 0)
    end

    if SafePlatform then
        SafePlatform:Destroy()
        SafePlatform = nil
    end

    -- Restore in chunks so the game doesn't freeze
    task.spawn(function()
        for i = 1, #DeletedParts do
            local obj = DeletedParts[i]
            if obj then
                pcall(function() obj.Parent = workspace end)
            end
            if i % 500 == 0 then task.wait() end
        end
        table.clear(DeletedParts)
        MapDeleted = false
        MapBusy = false
    end)
end

--=================================================================
--  THEMES (5 REFINED · Lost Front style)
--=================================================================
local Themes = {
    onyx = {
        Name = "Onyx",
        BG=Color3.fromRGB(8,8,10), Panel=Color3.fromRGB(16,16,20), Panel2=Color3.fromRGB(24,24,30),
        Card=Color3.fromRGB(20,20,26), CardHover=Color3.fromRGB(34,34,42),
        Accent=Color3.fromRGB(210,210,220), Accent2=Color3.fromRGB(255,255,255),
        Text=Color3.fromRGB(238,238,245), Dim=Color3.fromRGB(125,125,140),
        Border=Color3.fromRGB(42,42,52), BorderLight=Color3.fromRGB(88,88,102),
        Danger=Color3.fromRGB(230,90,110), Success=Color3.fromRGB(120,220,160),
        FogLight={Color3.fromRGB(130,130,145), Color3.fromRGB(165,165,185), Color3.fromRGB(110,110,125), Color3.fromRGB(195,195,215)},
        FogDark={Color3.fromRGB(4,4,6), Color3.fromRGB(2,2,4), Color3.fromRGB(14,14,18)},
        FogStreak=Color3.fromRGB(240,240,250), FogVignette=Color3.fromRGB(0,0,0),
    },
    sage = {
        Name = "Sage",
        BG=Color3.fromRGB(16,20,14), Panel=Color3.fromRGB(28,36,24), Panel2=Color3.fromRGB(38,48,32),
        Card=Color3.fromRGB(32,42,26), CardHover=Color3.fromRGB(46,60,38),
        Accent=Color3.fromRGB(168,196,128), Accent2=Color3.fromRGB(208,232,168),
        Text=Color3.fromRGB(228,238,215), Dim=Color3.fromRGB(130,148,112),
        Border=Color3.fromRGB(56,72,44), BorderLight=Color3.fromRGB(96,120,76),
        Danger=Color3.fromRGB(220,110,100), Success=Color3.fromRGB(140,220,120),
        FogLight={Color3.fromRGB(195,220,155), Color3.fromRGB(215,235,175), Color3.fromRGB(170,200,130), Color3.fromRGB(230,248,195)},
        FogDark={Color3.fromRGB(12,18,8), Color3.fromRGB(8,14,6), Color3.fromRGB(18,24,14)},
        FogStreak=Color3.fromRGB(240,250,220), FogVignette=Color3.fromRGB(4,8,2),
    },
    ice = {
        Name = "Ice",
        BG=Color3.fromRGB(14,18,26), Panel=Color3.fromRGB(24,32,42), Panel2=Color3.fromRGB(34,44,56),
        Card=Color3.fromRGB(28,38,50), CardHover=Color3.fromRGB(42,56,72),
        Accent=Color3.fromRGB(140,185,220), Accent2=Color3.fromRGB(185,220,250),
        Text=Color3.fromRGB(215,228,242), Dim=Color3.fromRGB(118,138,158),
        Border=Color3.fromRGB(48,66,86), BorderLight=Color3.fromRGB(80,110,140),
        Danger=Color3.fromRGB(220,100,120), Success=Color3.fromRGB(120,215,205),
        FogLight={Color3.fromRGB(165,205,235), Color3.fromRGB(190,225,255), Color3.fromRGB(145,185,215), Color3.fromRGB(210,240,255)},
        FogDark={Color3.fromRGB(8,14,22), Color3.fromRGB(4,10,18), Color3.fromRGB(12,20,30)},
        FogStreak=Color3.fromRGB(225,240,255), FogVignette=Color3.fromRGB(2,6,12),
    },
    crimson = {
        Name = "Crimson",
        BG=Color3.fromRGB(20,10,12), Panel=Color3.fromRGB(32,18,20), Panel2=Color3.fromRGB(44,24,28),
        Card=Color3.fromRGB(38,22,24), CardHover=Color3.fromRGB(56,30,34),
        Accent=Color3.fromRGB(220,110,120), Accent2=Color3.fromRGB(255,155,165),
        Text=Color3.fromRGB(240,220,225), Dim=Color3.fromRGB(148,110,118),
        Border=Color3.fromRGB(60,32,38), BorderLight=Color3.fromRGB(110,60,70),
        Danger=Color3.fromRGB(240,100,110), Success=Color3.fromRGB(150,215,140),
        FogLight={Color3.fromRGB(230,150,160), Color3.fromRGB(250,180,190), Color3.fromRGB(210,130,140), Color3.fromRGB(255,200,210)},
        FogDark={Color3.fromRGB(14,4,6), Color3.fromRGB(10,2,4), Color3.fromRGB(22,10,14)},
        FogStreak=Color3.fromRGB(255,235,240), FogVignette=Color3.fromRGB(8,0,2),
    },
    ivory = {
        Name = "Ivory",
        BG=Color3.fromRGB(240,242,248), Panel=Color3.fromRGB(255,255,255), Panel2=Color3.fromRGB(228,232,242),
        Card=Color3.fromRGB(248,250,255), CardHover=Color3.fromRGB(220,226,240),
        Accent=Color3.fromRGB(90,110,180), Accent2=Color3.fromRGB(140,160,220),
        Text=Color3.fromRGB(25,30,45), Dim=Color3.fromRGB(110,120,140),
        Border=Color3.fromRGB(200,208,222), BorderLight=Color3.fromRGB(165,175,195),
        Danger=Color3.fromRGB(210,70,80), Success=Color3.fromRGB(70,170,100),
        FogLight={Color3.fromRGB(200,215,240), Color3.fromRGB(220,230,250), Color3.fromRGB(180,200,235), Color3.fromRGB(240,245,255)},
        FogDark={Color3.fromRGB(180,195,225), Color3.fromRGB(195,210,235), Color3.fromRGB(170,185,220)},
        FogStreak=Color3.fromRGB(255,255,255), FogVignette=Color3.fromRGB(180,190,215),
    },
}
local ThemeOrder = {"onyx","sage","ice","crimson","ivory"}
local CurrentThemeName = "onyx"
local Theme = {}
for k,v in pairs(Themes[CurrentThemeName]) do Theme[k]=v end
local themeAppliers = {}
local function onTheme(fn) themeAppliers[#themeAppliers+1]=fn; pcall(fn) end
local function isLightTheme() return CurrentThemeName == "ivory" end

--=================================================================
--  GUI ROOT (LANDSCAPE)
--=================================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "EP_Ultimate"; Gui.ResetOnSpawn = false; Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = LP:WaitForChild("PlayerGui")

-- MAIN ROOT (opaque, frost is INSIDE)
local Root = Instance.new("Frame", Gui)
Root.Name = "EP_Root"; Root.Size = UDim2.fromOffset(840,520); Root.Position = UDim2.new(0.5,-420,0.5,-260)
Root.BorderSizePixel = 0; Root.Active = true; Root.ClipsDescendants = true
Root.ZIndex = 1; Root.Visible = false
Root.BackgroundColor3 = Theme.BG
Root.BackgroundTransparency = 0
Instance.new("UICorner", Root).CornerRadius = UDim.new(0, 14)
local rootStroke = Instance.new("UIStroke", Root); rootStroke.Thickness = 1; rootStroke.Transparency = 0.35
local rootGlowStroke = Instance.new("UIStroke", Root); rootGlowStroke.Thickness = 4; rootGlowStroke.Transparency = 1
onTheme(function()
    Root.BackgroundColor3 = Theme.BG
    rootStroke.Color = Theme.BorderLight
    rootGlowStroke.Color = Theme.Accent
end)
local rootScale = Instance.new("UIScale", Root); rootScale.Scale = 1


--=================================================================
--  FROST LAYER (Lost Front style, inside the panel)
--=================================================================
local Frost = Instance.new("Frame", Root)
Frost.Name = "Frost"
Frost.Size = UDim2.fromScale(1,1)
Frost.BackgroundTransparency = 1
Frost.BorderSizePixel = 0
Frost.ClipsDescendants = true
Frost.ZIndex = 0
Instance.new("UICorner", Frost).CornerRadius = UDim.new(0, 14)

local frostBlobs = {}

local function makeBlob(px, py, sz, color, transp, rot)
    local f = Instance.new("Frame", Frost)
    f.Size = UDim2.fromScale(sz, sz)
    f.Position = UDim2.fromScale(px, py)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color
    f.BackgroundTransparency = transp
    f.BorderSizePixel = 0
    f.Rotation = rot
    f.ZIndex = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    local g = Instance.new("UIGradient", f)
    g.Rotation = (rot * 0.5) % 360
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.45),
        NumberSequenceKeypoint.new(0.35, 0.72),
        NumberSequenceKeypoint.new(0.7, 0.88),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    return {f=f, g=g}
end

local lightDefs = {
    {0.12, 0.18, 0.95, 0.86, 40},
    {0.78, 0.28, 1.15, 0.88, 155},
    {0.42, 0.72, 0.88, 0.84, 220},
    {0.88, 0.85, 0.72, 0.90, 12},
    {0.28, 0.52, 1.30, 0.88, 95},
    {0.62, 0.08, 0.62, 0.89, 305},
    {0.05, 0.68, 0.78, 0.86, 65},
    {0.95, 0.12, 0.58, 0.92, 180},
    {0.50, 0.92, 0.68, 0.87, 275},
}
local darkDefs = {
    {0.22, 0.88, 0.82, 0.68, 0},
    {0.92, 0.48, 0.92, 0.70, 90},
    {0.48, 0.30, 0.72, 0.65, 45},
    {0.08, 0.42, 0.55, 0.72, 130},
}

for i, d in ipairs(lightDefs) do
    local b = makeBlob(d[1], d[2], d[3], Theme.FogLight[(i-1) % #Theme.FogLight + 1], d[4], d[5])
    b.isLight = true
    table.insert(frostBlobs, b)
end
for i, d in ipairs(darkDefs) do
    local b = makeBlob(d[1], d[2], d[3], Theme.FogDark[(i-1) % #Theme.FogDark + 1], d[4], d[5])
    b.isLight = false
    table.insert(frostBlobs, b)
end

local streak = Instance.new("Frame", Frost)
streak.Size = UDim2.new(2, 0, 0.4, 0)
streak.Position = UDim2.new(-0.5, 0, 0.14, 0)
streak.Rotation = -15
streak.BackgroundColor3 = Theme.FogStreak
streak.BackgroundTransparency = 0.9
streak.BorderSizePixel = 0
streak.ZIndex = 0
Instance.new("UICorner", streak).CornerRadius = UDim.new(1, 0)
local streakGrad = Instance.new("UIGradient", streak)
streakGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.5, 0.55),
    NumberSequenceKeypoint.new(1.0, 1.0),
})

local vigs = {}
local function makeVig(edge)
    local f = Instance.new("Frame", Frost)
    f.BackgroundColor3 = Theme.FogVignette
    f.BorderSizePixel = 0
    f.ZIndex = 0
    local g = Instance.new("UIGradient", f)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.42),
        NumberSequenceKeypoint.new(0.5, 0.78),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    if edge == "top" then
        f.Size = UDim2.fromScale(1, 0.35); f.Position = UDim2.fromScale(0, 0); g.Rotation = 90
    elseif edge == "bottom" then
        f.Size = UDim2.fromScale(1, 0.35); f.Position = UDim2.fromScale(0, 1); f.AnchorPoint = Vector2.new(0, 1); g.Rotation = -90
    elseif edge == "left" then
        f.Size = UDim2.fromScale(0.35, 1); f.Position = UDim2.fromScale(0, 0); g.Rotation = 0
    elseif edge == "right" then
        f.Size = UDim2.fromScale(0.35, 1); f.Position = UDim2.fromScale(1, 0); f.AnchorPoint = Vector2.new(1, 0); g.Rotation = 180
    end
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    table.insert(vigs, {f=f, g=g})
end
makeVig("top"); makeVig("bottom"); makeVig("left"); makeVig("right")

onTheme(function()
    local li, di = 0, 0
    for _, b in ipairs(frostBlobs) do
        if b.isLight then
            li = li + 1
            b.f.BackgroundColor3 = Theme.FogLight[(li-1) % #Theme.FogLight + 1]
        else
            di = di + 1
            b.f.BackgroundColor3 = Theme.FogDark[(di-1) % #Theme.FogDark + 1]
        end
    end
    streak.BackgroundColor3 = Theme.FogStreak
    for _, v in ipairs(vigs) do v.f.BackgroundColor3 = Theme.FogVignette end
end)

--=================================================================
--  SPLASH v6 (frost panel · matches GUI)
--  Drop-in replacement for the previous EP_Splash block.
--  Requires (already defined outside): Gui, Theme, Root, rootScale,
--  onTheme, themeAppliers
--=================================================================

local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local TextService     = game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService    = game:GetService("SoundService")

-- ── TWEAK THESE ──
local SPLASH_CFG = {
    Wordmark        = "EL PASO",
    Tagline         = "by selever_el  ·  v4.1",

    -- Timing (seconds)
    LetterDelay      = 0.045,
    LetterDuration   = 0.55,
    DividerDuration  = 0.35,
    MinProgressTime  = 0.60,
    MaxProgressTime  = 4.00,
    HoldAfterLoad    = 0.15,
    FadeOutDuration  = 0.40,

    -- Layout
    RowMaxWidth      = 480,
    LetterSize       = 56,
    TrackingPx       = 3,
    SpaceWidthPx     = 16,
    LetterRisePx     = 10,
    TrackingStart    = 0.90,
    RevealStyle      = "mask",
    ExitStyle        = "stagger",

    -- Frost background (matches GUI)
    FrostMode        = "panel",   -- "panel" (matches Root) | "screen" (full-screen)
    FrostPanelW      = 840,       -- only used when FrostMode == "panel"
    FrostPanelH      = 520,
    FrostUseStroke   = false,     -- true = adds a UIStroke matching Root's

    -- Features
    ShowPercentage   = false,
    SkipOnClick      = true,
    ReducedMotion    = false,
    BarShimmer       = true,
    LeadingDot       = true,
    Glow             = true,
    DividerSweep     = true,

    SoundIds = { Letter = "", Divider = "" },
    Assets = {},
}

if SPLASH_CFG.ReducedMotion then
    SPLASH_CFG.LetterDelay     = 0
    SPLASH_CFG.LetterDuration  = 0.15
    SPLASH_CFG.DividerDuration = 0.10
    SPLASH_CFG.MinProgressTime = 0.20
    SPLASH_CFG.FadeOutDuration = 0.15
    SPLASH_CFG.TrackingStart   = 1.0
    SPLASH_CFG.RevealStyle     = "fade"
    SPLASH_CFG.ExitStyle       = "fade"
    SPLASH_CFG.BarShimmer      = false
    SPLASH_CFG.Glow            = false
    SPLASH_CFG.LeadingDot      = false
    SPLASH_CFG.DividerSweep    = false
end

-- ── STATE ──
local SplashDying   = false
local skipRequested = false
local activeTweens  = {}

-- ── HOISTED REFS ──
local letters    = {}
local tagline, divider, glow
local progressFill, progressPct
local totalW = 1

-- ── HELPERS ──
local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    table.insert(activeTweens, t)
    t:Play()
    return t
end

local function cancelAllTweens()
    for _, t in ipairs(activeTweens) do
        pcall(function() t:Cancel() end)
    end
    table.clear(activeTweens)
end

local function waitOrSkip(seconds)
    local t0 = os.clock()
    while os.clock() - t0 < seconds do
        if skipRequested then return true end
        local remaining = seconds - (os.clock() - t0)
        task.wait(math.min(0.03, math.max(remaining, 0.001)))
    end
    return skipRequested
end

local function playSound(id, vol, pitch)
    if not id or id == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = id; s.Volume = vol or 0.4; s.PlaybackSpeed = pitch or 1
    s.Parent = SoundService; s:Play()
    s.Ended:Connect(function() s:Destroy() end)
end

local function measureGlyph(ch)
    if ch == " " then return SPLASH_CFG.SpaceWidthPx end
    local v = TextService:GetTextSize(
        ch, SPLASH_CFG.LetterSize, Enum.Font.GothamBlack,
        Vector2.new(math.huge, math.huge)
    )
    return v.X + SPLASH_CFG.TrackingPx
end

-- ── SPLASH FRAME ──
local Splash = Instance.new("Frame", Gui)
Splash.Name                   = "EP_Splash"
Splash.Size                   = UDim2.fromScale(1, 1)
Splash.BackgroundColor3       = Theme.BG
Splash.BackgroundTransparency = 1
Splash.BorderSizePixel        = 0
Splash.ZIndex                 = 500
Splash.ClipsDescendants       = true

--=================================================================
--  SPLASH FROST (matches GUI's panel frost)
--=================================================================
local SplashFrost = Instance.new("Frame", Splash)
SplashFrost.Name                   = "EP_SplashFrost"
SplashFrost.BackgroundColor3       = Theme.BG
SplashFrost.BackgroundTransparency = 1
SplashFrost.BorderSizePixel        = 0
SplashFrost.ClipsDescendants       = true
SplashFrost.ZIndex                 = 501
Instance.new("UICorner", SplashFrost).CornerRadius = UDim.new(0, 14)

-- Size & position: match Root (840×520 centered) or full-screen
do
    local vp = workspace.CurrentCamera.ViewportSize
    if SPLASH_CFG.FrostMode == "screen" then
        SplashFrost.Size     = UDim2.fromScale(1, 1)
        SplashFrost.Position = UDim2.fromScale(0, 0)
    else
        SplashFrost.Size     = UDim2.fromOffset(SPLASH_CFG.FrostPanelW, SPLASH_CFG.FrostPanelH)
        SplashFrost.Position = UDim2.new(0.5, -SPLASH_CFG.FrostPanelW/2, 0.5, -SPLASH_CFG.FrostPanelH/2)
        -- Shrink on small screens
        local fit = math.min(1,
            (vp.X - 40) / SPLASH_CFG.FrostPanelW,
            (vp.Y - 80) / SPLASH_CFG.FrostPanelH)
        if fit < 1 then
            Instance.new("UIScale", SplashFrost).Scale = fit
        end
    end
end

-- ── Frost element registry (for fade in/out) ──
local sfElements = {}       -- { {frame=Frame, target=number}, ... }
local sLightBlobs, sDarkBlobs, sVigs = {}, {}, {}
local sStreak
local sfStroke

local function sfRegister(frame, targetTransp)
    frame.BackgroundTransparency = 1
    table.insert(sfElements, { frame = frame, target = targetTransp })
end

sfRegister(SplashFrost, 0)

-- Optional stroke (matching Root's)
if SPLASH_CFG.FrostUseStroke then
    sfStroke = Instance.new("UIStroke", SplashFrost)
    sfStroke.Thickness      = 1
    sfStroke.Transparency   = 1
    sfStroke.Color          = Theme.BorderLight
end

-- Blob factory (mirrors the GUI's makeBlob exactly)
local function sMakeBlob(px, py, sz, color, transp, rot)
    local f = Instance.new("Frame", SplashFrost)
    f.Size             = UDim2.fromScale(sz, sz)
    f.Position         = UDim2.fromScale(px, py)
    f.AnchorPoint      = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color
    f.BorderSizePixel  = 0
    f.Rotation         = rot
    f.ZIndex           = 1
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    local g = Instance.new("UIGradient", f)
    g.Rotation = (rot * 0.5) % 360
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.45),
        NumberSequenceKeypoint.new(0.35, 0.72),
        NumberSequenceKeypoint.new(0.7, 0.88),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    sfRegister(f, transp)
    return f
end

-- Same defs as GUI's lightDefs / darkDefs
local sLightDefs = {
    {0.12, 0.18, 0.95, 0.86, 40},
    {0.78, 0.28, 1.15, 0.88, 155},
    {0.42, 0.72, 0.88, 0.84, 220},
    {0.88, 0.85, 0.72, 0.90, 12},
    {0.28, 0.52, 1.30, 0.88, 95},
    {0.62, 0.08, 0.62, 0.89, 305},
    {0.05, 0.68, 0.78, 0.86, 65},
    {0.95, 0.12, 0.58, 0.92, 180},
    {0.50, 0.92, 0.68, 0.87, 275},
}
local sDarkDefs = {
    {0.22, 0.88, 0.82, 0.68, 0},
    {0.92, 0.48, 0.92, 0.70, 90},
    {0.48, 0.30, 0.72, 0.65, 45},
    {0.08, 0.42, 0.55, 0.72, 130},
}

for i, d in ipairs(sLightDefs) do
    table.insert(sLightBlobs,
        sMakeBlob(d[1], d[2], d[3], Theme.FogLight[(i-1) % #Theme.FogLight + 1], d[4], d[5]))
end
for i, d in ipairs(sDarkDefs) do
    table.insert(sDarkBlobs,
        sMakeBlob(d[1], d[2], d[3], Theme.FogDark[(i-1) % #Theme.FogDark + 1], d[4], d[5]))
end

-- Streak
sStreak = Instance.new("Frame", SplashFrost)
sStreak.Size                   = UDim2.new(2, 0, 0.4, 0)
sStreak.Position               = UDim2.new(-0.5, 0, 0.14, 0)
sStreak.Rotation               = -15
sStreak.BackgroundColor3       = Theme.FogStreak
sStreak.BorderSizePixel        = 0
sStreak.ZIndex                 = 1
Instance.new("UICorner", sStreak).CornerRadius = UDim.new(1, 0)
local sStreakGrad = Instance.new("UIGradient", sStreak)
sStreakGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.5, 0.55),
    NumberSequenceKeypoint.new(1.0, 1.0),
})
sfRegister(sStreak, 0.9)

-- Vignettes
local function sMakeVig(edge)
    local f = Instance.new("Frame", SplashFrost)
    f.BackgroundColor3 = Theme.FogVignette
    f.BorderSizePixel  = 0
    f.ZIndex           = 1
    local g = Instance.new("UIGradient", f)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.42),
        NumberSequenceKeypoint.new(0.5, 0.78),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    if edge == "top" then
        f.Size = UDim2.fromScale(1, 0.35); f.Position = UDim2.fromScale(0, 0); g.Rotation = 90
    elseif edge == "bottom" then
        f.Size = UDim2.fromScale(1, 0.35); f.Position = UDim2.fromScale(0, 1); f.AnchorPoint = Vector2.new(0, 1); g.Rotation = -90
    elseif edge == "left" then
        f.Size = UDim2.fromScale(0.35, 1); f.Position = UDim2.fromScale(0, 0); g.Rotation = 0
    elseif edge == "right" then
        f.Size = UDim2.fromScale(0.35, 1); f.Position = UDim2.fromScale(1, 0); f.AnchorPoint = Vector2.new(1, 0); g.Rotation = 180
    end
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    table.insert(sVigs, f)
    sfRegister(f, 0)
end
sMakeVig("top"); sMakeVig("bottom"); sMakeVig("left"); sMakeVig("right")

-- ── Theme sync ──
onTheme(function()
    for i, f in ipairs(sLightBlobs) do
        f.BackgroundColor3 = Theme.FogLight[(i-1) % #Theme.FogLight + 1]
    end
    for i, f in ipairs(sDarkBlobs) do
        f.BackgroundColor3 = Theme.FogDark[(i-1) % #Theme.FogDark + 1]
    end
    if sStreak then sStreak.BackgroundColor3 = Theme.FogStreak end
    for _, f in ipairs(sVigs) do f.BackgroundColor3 = Theme.FogVignette end
    SplashFrost.BackgroundColor3 = Theme.BG
    if sfStroke then sfStroke.Color = Theme.BorderLight end
end)

--=================================================================
--  FADE OUT
--=================================================================
local function doFadeOut()
    if SplashDying then return end
    SplashDying = true

    if skipRequested then
        cancelAllTweens()
        if progressFill and progressFill.Parent then
            progressFill.Size = UDim2.new(1, 0, 1, 0)
        end
        if progressPct and progressPct.Parent then progressPct.Text = "100%" end
    end

    rootScale.Scale = 0.96
    Root.Visible    = true

    local dur = skipRequested and 0.18 or SPLASH_CFG.FadeOutDuration
    local fo  = TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    -- Splash BG
    tween(Splash, fo, { BackgroundTransparency = 1 })

    -- Frost panel (matches Root behind it → seamless crossfade)
    for _, e in ipairs(sfElements) do
        tween(e.frame, fo, { BackgroundTransparency = 1 })
    end
    if sfStroke then
        tween(sfStroke, fo, { Transparency = 1 })
    end

    -- Wordmark (staggered)
    local mid = (#letters + 1) / 2
    for i, d in ipairs(letters) do
        local exitDelay = 0
        if SPLASH_CFG.ExitStyle == "stagger" and not skipRequested then
            exitDelay = math.abs(i - mid) * 0.025
        end
        task.delay(exitDelay, function()
            if d.lbl and d.lbl.Parent then
                tween(d.lbl,
                    TweenInfo.new(dur * 0.7,
                        Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { TextTransparency = 1 })
            end
        end)
    end
    if tagline and tagline.Parent then
        tween(tagline,
            TweenInfo.new(dur * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 1 })
    end
    if divider and divider.Parent then
        tween(divider,
            TweenInfo.new(dur * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 })
    end
    if glow and glow.Parent then
        tween(glow,
            TweenInfo.new(dur * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 })
    end

    tween(rootScale,
        TweenInfo.new(dur + 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Scale = 1 })

    task.delay(dur + 0.15, function()
        if Splash.Parent then Splash:Destroy() end
    end)
end

-- ── SKIP HANDLER ──
if SPLASH_CFG.SkipOnClick then
    Splash.InputBegan:Connect(function(input)
        if SplashDying then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1
        or t == Enum.UserInputType.Touch then
            skipRequested = true
            doFadeOut()
        end
    end)
end

--=================================================================
--  MAIN SEQUENCE
--=================================================================
task.spawn(function()
    -- 1) Backdrop fade-in
    tween(Splash,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 })

    -- 2) Frost panel fades in alongside (slightly longer → resolves out of dark)
    for _, e in ipairs(sfElements) do
        tween(e.frame,
            TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = e.target })
    end
    if sfStroke then
        tween(sfStroke,
            TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 0.35 })
    end

    if waitOrSkip(0.25) then return end

    -- 3) Measure wordmark
    local chars = {}
    for i = 1, #SPLASH_CFG.Wordmark do
        chars[i] = string.sub(SPLASH_CFG.Wordmark, i, i)
    end
    if #chars == 0 then doFadeOut() return end

    local widths = {}
    totalW = 0
    for i, ch in ipairs(chars) do
        widths[i] = measureGlyph(ch)
        totalW    = totalW + widths[i]
    end
    totalW = math.max(totalW - SPLASH_CFG.TrackingPx, 1)

    -- 4) Responsive center stage
    local vp    = workspace.CurrentCamera.ViewportSize
    local maxW  = math.min(SPLASH_CFG.RowMaxWidth, vp.X - 40)
    local scale = math.min(1, maxW / totalW, (vp.Y - 80) / 200)

    local center = Instance.new("Frame", Splash)
    center.AnchorPoint            = Vector2.new(0.5, 0.5)
    center.Position               = UDim2.fromScale(0.5, 0.5)
    center.Size                   = UDim2.fromOffset(totalW, 160)
    center.BackgroundTransparency = 1
    center.ZIndex                 = 502
    if scale < 1 then
        Instance.new("UIScale", center).Scale = scale
    end

    -- 5) Radial glow behind the wordmark
    if SPLASH_CFG.Glow then
        glow = Instance.new("Frame", center)
        glow.AnchorPoint            = Vector2.new(0.5, 0.5)
        glow.Position               = UDim2.new(0.5, 0, 0.18, 0)
        glow.Size                   = UDim2.fromOffset(totalW * 2.0, 260)
        glow.BackgroundColor3       = Theme.Accent
        glow.BackgroundTransparency = 1
        glow.BorderSizePixel        = 0
        glow.ZIndex                 = 501
        Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
        local ggrad = Instance.new("UIGradient", glow)
        ggrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(1.0, 1.0),
        })
        tween(glow,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.88 })
        task.spawn(function()
            while glow and glow.Parent do
                local t = TweenService:Create(glow,
                    TweenInfo.new(3.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,
                        0, true),
                    { BackgroundTransparency = 0.92 })
                t:Play(); t.Completed:Wait()
            end
        end)
    end

    -- 6) Build letters (mask reveal + tracking)
    local maskMode = (SPLASH_CFG.RevealStyle == "mask")
    local rowH     = maskMode and (SPLASH_CFG.LetterSize + 14) or 70
    local midX     = totalW / 2
    local midIdx   = (#chars + 1) / 2
    local xCur     = 0

    for i, ch in ipairs(chars) do
        if ch ~= " " then
            local w = widths[i]
            if maskMode then
                local tf = Instance.new("Frame", center)
                tf.Size                   = UDim2.fromOffset(w, rowH)
                tf.AnchorPoint            = Vector2.new(0, 0.5)
                local finalX = xCur
                local startX = midX + (finalX - midX) * SPLASH_CFG.TrackingStart
                tf.Position               = UDim2.fromOffset(startX, 20)
                tf.BackgroundTransparency = 1
                tf.BorderSizePixel        = 0
                tf.ClipsDescendants       = true
                tf.ZIndex                 = 503

                local lbl = Instance.new("TextLabel", tf)
                lbl.Size                   = UDim2.fromScale(1, 1)
                lbl.Position               = UDim2.fromScale(0, 1)
                lbl.BackgroundTransparency = 1
                lbl.Font                   = Enum.Font.GothamBlack
                lbl.TextSize               = SPLASH_CFG.LetterSize
                lbl.TextColor3             = Theme.Accent2
                lbl.Text                   = ch
                lbl.TextXAlignment         = Enum.TextXAlignment.Center
                lbl.TextYAlignment         = Enum.TextYAlignment.Center
                lbl.ZIndex                 = 504
                local grad = Instance.new("UIGradient", lbl)
                grad.Color    = ColorSequence.new(Theme.Accent, Theme.Accent2)
                grad.Rotation = 90

                table.insert(letters, {
                    frame = tf, lbl = lbl,
                    x = finalX, startX = startX, index = i,
                    delay = math.abs(i - midIdx) * SPLASH_CFG.LetterDelay,
                    mask = true,
                })
            else
                local lbl = Instance.new("TextLabel", center)
                lbl.Size                   = UDim2.fromOffset(w, 70)
                lbl.AnchorPoint            = Vector2.new(0, 0.5)
                lbl.Position               = UDim2.fromOffset(xCur, 20 + SPLASH_CFG.LetterRisePx)
                lbl.BackgroundTransparency = 1
                lbl.Font                   = Enum.Font.GothamBlack
                lbl.TextSize               = SPLASH_CFG.LetterSize
                lbl.TextColor3             = Theme.Accent2
                lbl.TextTransparency       = 1
                lbl.TextXAlignment         = Enum.TextXAlignment.Center
                lbl.Text                   = ch
                lbl.ZIndex                 = 504
                local grad = Instance.new("UIGradient", lbl)
                grad.Color    = ColorSequence.new(Theme.Accent, Theme.Accent2)
                grad.Rotation = 90
                table.insert(letters, {
                    frame = lbl, lbl = lbl,
                    x = xCur, startX = xCur, index = i,
                    delay = math.abs(i - midIdx) * SPLASH_CFG.LetterDelay,
                    mask = false,
                })
            end
        end
        xCur = xCur + widths[i]
    end

    -- 7) Animate letters
    local maxDelay = 0
    for _, d in ipairs(letters) do
        if d.delay > maxDelay then maxDelay = d.delay end
        task.delay(d.delay, function()
            if not d.lbl or not d.lbl.Parent then return end
            if SPLASH_CFG.SoundIds.Letter ~= "" then
                playSound(SPLASH_CFG.SoundIds.Letter, 0.15,
                    1 + (d.index / #chars) * 0.12)
            end
            if d.mask then
                tween(d.frame,
                    TweenInfo.new(SPLASH_CFG.LetterDuration,
                        Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    { Position = UDim2.fromOffset(d.x, 20) })
                tween(d.lbl,
                    TweenInfo.new(SPLASH_CFG.LetterDuration,
                        Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Position = UDim2.fromScale(0, 0) })
            else
                tween(d.lbl,
                    TweenInfo.new(SPLASH_CFG.LetterDuration,
                        Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    { Position = UDim2.fromOffset(d.x, 20), TextTransparency = 0 })
            end
        end)
    end
    if waitOrSkip(maxDelay + SPLASH_CFG.LetterDuration * 0.55) then return end

    -- 8) Divider
    divider = Instance.new("Frame", center)
    divider.AnchorPoint            = Vector2.new(0.5, 0.5)
    divider.Position               = UDim2.fromScale(0.5, 0.64)
    divider.Size                   = UDim2.new(0, 0, 0, 1)
    divider.BackgroundColor3       = Theme.Accent
    divider.BackgroundTransparency = 0.45
    divider.BorderSizePixel        = 0
    divider.ZIndex                 = 503
    tween(divider,
        TweenInfo.new(SPLASH_CFG.DividerDuration,
            Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, math.clamp(totalW * 0.35, 32, 120), 0, 1) })

    if SPLASH_CFG.SoundIds.Divider ~= "" then
        playSound(SPLASH_CFG.SoundIds.Divider, 0.25, 1)
    end

    if SPLASH_CFG.DividerSweep then
        local dg = Instance.new("UIGradient", divider)
        dg.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.42, 1.0),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(0.58, 1.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        })
        dg.Offset = Vector2.new(-1, 0)
        task.delay(SPLASH_CFG.DividerDuration, function()
            if divider and divider.Parent then
                TweenService:Create(dg,
                    TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    { Offset = Vector2.new(1, 0) }):Play()
            end
        end)
    end
    if waitOrSkip(0.06) then return end

    -- 9) Tagline
    tagline = Instance.new("TextLabel", center)
    tagline.Size                   = UDim2.fromScale(1, 0)
    tagline.Position               = UDim2.fromScale(0, 0.74)
    tagline.BackgroundTransparency = 1
    tagline.Font                   = Enum.Font.GothamMedium
    tagline.TextSize               = 11
    tagline.TextColor3             = Theme.Dim
    tagline.TextTransparency       = 1
    tagline.Text                   = SPLASH_CFG.Tagline
    tagline.ZIndex                 = 503
    tween(tagline,
        TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextTransparency = 0 })

    -- 10) Progress bar
    local pTrack = Instance.new("Frame", Splash)
    pTrack.Size                   = UDim2.new(1, 0, 0, 2)
    pTrack.Position               = UDim2.new(0, 0, 1, -2)
    pTrack.BackgroundColor3       = Theme.Accent
    pTrack.BackgroundTransparency = 0.92
    pTrack.BorderSizePixel        = 0
    pTrack.ZIndex                 = 502

    progressFill = Instance.new("Frame", pTrack)
    progressFill.Size             = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Theme.Accent2
    progressFill.BorderSizePixel  = 0
    progressFill.ZIndex           = 503

    if SPLASH_CFG.BarShimmer then
        local grad = Instance.new("UIGradient", progressFill)
        grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(0.7,0.7,0.7))
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.5, 0.4),
            NumberSequenceKeypoint.new(1,   1),
        })
        task.spawn(function()
            while progressFill and progressFill.Parent do
                local t = TweenService:Create(grad,
                    TweenInfo.new(1.2, Enum.EasingStyle.Linear),
                    { Offset = Vector2.new(1, 0) })
                t:Play(); t.Completed:Wait()
                grad.Offset = Vector2.new(-1, 0)
            end
        end)
    end

    if SPLASH_CFG.LeadingDot then
        local dotGlow = Instance.new("Frame", progressFill)
        dotGlow.Size             = UDim2.fromOffset(14, 14)
        dotGlow.AnchorPoint      = Vector2.new(0.5, 0.5)
        dotGlow.Position         = UDim2.new(1, 0, 0.5, 0)
        dotGlow.BackgroundColor3 = Theme.Accent2
        dotGlow.BackgroundTransparency = 0.7
        dotGlow.BorderSizePixel  = 0
        dotGlow.ZIndex           = 504
        Instance.new("UICorner", dotGlow).CornerRadius = UDim.new(1, 0)

        local dot = Instance.new("Frame", progressFill)
        dot.Size             = UDim2.fromOffset(4, 4)
        dot.AnchorPoint      = Vector2.new(0.5, 0.5)
        dot.Position         = UDim2.new(1, 0, 0.5, 0)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BorderSizePixel  = 0
        dot.ZIndex           = 505
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    end

    if SPLASH_CFG.ShowPercentage then
        progressPct = Instance.new("TextLabel", Splash)
        progressPct.Size                   = UDim2.fromOffset(60, 14)
        progressPct.Position               = UDim2.new(1, -70, 1, -22)
        progressPct.BackgroundTransparency = 1
        progressPct.Font                   = Enum.Font.Code
        progressPct.TextSize               = 10
        progressPct.TextColor3             = Theme.Dim
        progressPct.TextXAlignment         = Enum.TextXAlignment.Right
        progressPct.Text                   = "0%"
        progressPct.ZIndex                 = 503
    end

    -- 11) Preload
    local preloadProgress = 0
    local preloadDone     = false
    task.spawn(function()
        if #SPLASH_CFG.Assets > 0 then
            for i, id in ipairs(SPLASH_CFG.Assets) do
                pcall(function() ContentProvider:PreloadAsync({ id }) end)
                preloadProgress = i / #SPLASH_CFG.Assets
            end
        else
            preloadProgress = 1
        end
        preloadDone = true
    end)

    -- 12) Drive bar
    local t0    = os.clock()
    local shown = 0
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        if not progressFill or not progressFill.Parent then
            conn:Disconnect()
            return
        end
        local elapsed  = os.clock() - t0
        local timeFrac = math.clamp(elapsed / SPLASH_CFG.MinProgressTime, 0, 1)
        local realFrac = preloadDone and 1 or preloadProgress
        local target
        if elapsed >= SPLASH_CFG.MaxProgressTime then
            target = 1
        elseif preloadDone and elapsed >= SPLASH_CFG.MinProgressTime then
            target = 1
        else
            target = math.min(realFrac, timeFrac)
        end
        shown = shown + (target - shown) * math.min(1, dt * 10)
        if shown > 0.998 then shown = 1 end
        progressFill.Size = UDim2.new(shown, 0, 1, 0)
        if progressPct and progressPct.Parent then
            progressPct.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
        end
    end)

    while not skipRequested do
        local elapsed = os.clock() - t0
        if elapsed >= SPLASH_CFG.MaxProgressTime then break end
        if shown >= 1 and preloadDone then break end
        RunService.Heartbeat:Wait()
    end
    conn:Disconnect()

    if skipRequested then return end

    if shown < 1 and progressFill and progressFill.Parent then
        progressFill.Size = UDim2.new(1, 0, 1, 0)
        if progressPct and progressPct.Parent then progressPct.Text = "100%" end
    end

    if waitOrSkip(SPLASH_CFG.HoldAfterLoad) then return end
    doFadeOut()
end)

--=================================================================
--  TOASTS
--=================================================================
local ToastHolder = Instance.new("Frame", Gui)
ToastHolder.Name = "EP_Toasts"; ToastHolder.AnchorPoint = Vector2.new(1,1)
ToastHolder.Position = UDim2.new(1, -20, 1, -20); ToastHolder.Size = UDim2.fromOffset(320, 500)
ToastHolder.BackgroundTransparency = 1; ToastHolder.ZIndex = 200
local toastLayout = Instance.new("UIListLayout", ToastHolder)
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.Padding = UDim.new(0, 8); toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
local toastOrder = 0

local function showToast(msg, kind)
    toastOrder = toastOrder + 1; kind = kind or "info"
    local color = Theme.Accent
    if kind=="success" then color = Theme.Success
    elseif kind=="warn" then color = Color3.fromRGB(240,190,80)
    elseif kind=="error" then color = Theme.Danger end
    local t = Instance.new("Frame", ToastHolder)
    t.Size = UDim2.fromOffset(300, 44); t.BackgroundColor3 = Theme.Panel
    t.BackgroundTransparency = 0.05; t.BorderSizePixel = 0; t.LayoutOrder = toastOrder
    t.ZIndex = 201; Instance.new("UICorner", t).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", t)
    stroke.Color = color; stroke.Thickness = 1; stroke.Transparency = 0.3
    local bar = Instance.new("Frame", t)
    bar.Size = UDim2.fromOffset(3,26); bar.Position = UDim2.fromOffset(10,9)
    bar.BackgroundColor3 = color; bar.BorderSizePixel = 0; bar.ZIndex = 202
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local lbl = Instance.new("TextLabel", t)
    lbl.Size = UDim2.new(1,-30,1,0); lbl.Position = UDim2.fromOffset(22,0)
    lbl.BackgroundTransparency = 1; lbl.Text = msg
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
    lbl.TextColor3 = Theme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.ZIndex = 202
    local sc = Instance.new("UIScale", t); sc.Scale = 0
    TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
    task.delay(3.2, function()
        if t and t.Parent then
            TweenService:Create(sc, TweenInfo.new(0.2), {Scale=0}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency=1}):Play()
            task.delay(0.22, function() if t and t.Parent then t:Destroy() end end)
        end
    end)
    return t
end

--=================================================================
--  TITLE BAR
--=================================================================
local TB = Instance.new("Frame", Root)
TB.Size = UDim2.new(1,0,0,54); TB.BackgroundTransparency = 1; TB.BorderSizePixel = 0; TB.ZIndex = 10

local DragZone = Instance.new("Frame", TB)
DragZone.Size = UDim2.new(1, -90, 1, 0); DragZone.BackgroundTransparency = 1
DragZone.BorderSizePixel = 0; DragZone.Active = true; DragZone.ZIndex = 11

local tbDragging = false; local tbDragStart, tbStartPos
DragZone.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tbDragging = true; tbDragStart = input.Position; tbStartPos = Root.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if tbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - tbDragStart
        Root.Position = UDim2.new(tbStartPos.X.Scale, tbStartPos.X.Offset + d.X, tbStartPos.Y.Scale, tbStartPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tbDragging = false
    end
end)

local TIcon = Instance.new("TextLabel", TB)
TIcon.Size = UDim2.fromOffset(28,28); TIcon.Position = UDim2.fromOffset(20,13)
TIcon.BackgroundTransparency = 1; TIcon.Text = "◈"
TIcon.Font = Enum.Font.GothamBold; TIcon.TextSize = 22; TIcon.ZIndex = 12
onTheme(function() TIcon.TextColor3 = Theme.Accent end)

local TT = Instance.new("TextLabel", TB)
TT.Size = UDim2.fromOffset(300,20); TT.Position = UDim2.fromOffset(54,8)
TT.BackgroundTransparency = 1; TT.Text = "EL PASO"
TT.Font = Enum.Font.GothamBold; TT.TextSize = 15
TT.TextXAlignment = Enum.TextXAlignment.Left; TT.ZIndex = 12
onTheme(function() TT.TextColor3 = Theme.Text end)

local TSub = Instance.new("TextLabel", TB)
TSub.Size = UDim2.fromOffset(300,12); TSub.Position = UDim2.fromOffset(54,28)
TSub.BackgroundTransparency = 1; TSub.Text = "by selever_el  •  v4.1 · Landscape"
TSub.Font = Enum.Font.Gotham; TSub.TextSize = 10
TSub.TextXAlignment = Enum.TextXAlignment.Left; TSub.ZIndex = 12
onTheme(function() TSub.TextColor3 = Theme.Dim end)


local function makeTitleBtn(glyph, xOff, cb)
    local b = Instance.new("TextButton", TB)
    b.Size = UDim2.fromOffset(28,28); b.Position = UDim2.new(1, xOff, 0.5, -14)
    b.Text = glyph; b.Font = Enum.Font.GothamBold; b.TextSize = 16
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.ClipsDescendants = true; b.ZIndex = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    onTheme(function() b.BackgroundColor3 = Theme.Panel; b.TextColor3 = Theme.Dim end)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Theme.CardHover, TextColor3=Theme.Accent}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Theme.Panel, TextColor3=Theme.Dim}):Play()
    end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

-- FLOATING CHIP (when minimized)
local Chip = Instance.new("TextButton", Gui)
Chip.Size = UDim2.fromOffset(52,52); Chip.Position = UDim2.new(0.5,-26,0.5,-26)
Chip.Text = "◈"; Chip.Font = Enum.Font.GothamBold; Chip.TextSize = 24
Chip.BorderSizePixel = 0; Chip.AutoButtonColor = false; Chip.Visible = false
Chip.ZIndex = 5; Chip.Active = true
Instance.new("UICorner", Chip).CornerRadius = UDim.new(0,14)
local chipStroke = Instance.new("UIStroke", Chip); chipStroke.Thickness = 1; chipStroke.Transparency = 0.3
onTheme(function() Chip.BackgroundColor3 = Theme.BG; Chip.TextColor3 = Theme.Accent; chipStroke.Color = Theme.BorderLight end)

local chipDragging, chipDragStart, chipStartPos = false, nil, nil
local chipDragDist = 0
Chip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        chipDragging = true; chipDragStart = input.Position; chipStartPos = Chip.Position; chipDragDist = 0
    end
end)
UIS.InputChanged:Connect(function(input)
    if chipDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - chipDragStart
        chipDragDist = math.max(chipDragDist, Vector2.new(d.X,d.Y).Magnitude)
        Chip.Position = UDim2.new(chipStartPos.X.Scale, chipStartPos.X.Offset + d.X, chipStartPos.Y.Scale, chipStartPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        chipDragging = false
    end
end)
Chip.MouseEnter:Connect(function() TweenService:Create(Chip, TweenInfo.new(0.15), {BackgroundColor3=Theme.Panel2}):Play() end)
Chip.MouseLeave:Connect(function() TweenService:Create(Chip, TweenInfo.new(0.15), {BackgroundColor3=Theme.BG}):Play() end)

local SearchBox
local minimized = false
local function minimize()
    if minimized then return end
    minimized = true
    if SearchBox then SearchBox.Text = "" end
    Chip.Position = Root.Position
    TweenService:Create(rootScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale=0}):Play()
    task.delay(0.25, function()
        if minimized then
            Root.Visible = false; Chip.Visible = true
            Chip.Size = UDim2.fromOffset(0,0)
            TweenService:Create(Chip, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(52,52)}):Play()
        end
    end)
end
local function restore()
    if not minimized then return end
    minimized = false; Chip.Visible = false; Root.Visible = true
    Root.Position = Chip.Position; rootScale.Scale = 0
    TweenService:Create(rootScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
end
Chip.MouseButton1Click:Connect(function() if chipDragDist < 5 then restore() end end)

local MinB = makeTitleBtn("−", -76, minimize)
local CloseB = makeTitleBtn("×", -42, function()
    if SearchBox then SearchBox.Text = "" end
    TweenService:Create(rootScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale=0.9}):Play()
    task.delay(0.15, function() Gui.Enabled = false; rootScale.Scale = 1 end)
end)
CloseB.TextSize = 18; MinB.TextSize = 20

-- Divider with scan line
local Div = Instance.new("Frame", Root)
Div.Size = UDim2.new(1,-32,0,1); Div.Position = UDim2.fromOffset(16,54)
Div.BorderSizePixel = 0; Div.ZIndex = 10; Div.ClipsDescendants = true
local divGrad = Instance.new("UIGradient", Div)
divGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.5,0.25), NumberSequenceKeypoint.new(1,1)
})
onTheme(function() Div.BackgroundColor3 = Theme.Accent end)
local scanLine = Instance.new("Frame", Div)
scanLine.Size = UDim2.new(0,40,1,0); scanLine.Position = UDim2.new(0,-40,0,0)
scanLine.BorderSizePixel = 0; scanLine.BackgroundTransparency = 0.4; scanLine.ZIndex = 11
onTheme(function() scanLine.BackgroundColor3 = Theme.Accent end)
local scanGrad = Instance.new("UIGradient", scanLine)
scanGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,1)
})
task.spawn(function()
    while not _G.EP_Unloaded do
        scanLine.Position = UDim2.new(0,-40,0,0)
        local t = TweenService:Create(scanLine, TweenInfo.new(2.4, Enum.EasingStyle.Linear), {Position = UDim2.new(1,0,0,0)})
        t:Play(); t.Completed:Wait(); task.wait(1.6)
    end
end)

--=================================================================
--  SEARCH BAR
--=================================================================
SearchBox = Instance.new("TextBox", Root)
SearchBox.Size = UDim2.new(1,-32,0,30); SearchBox.Position = UDim2.fromOffset(16,62)
SearchBox.BackgroundColor3 = Theme.Panel2; SearchBox.BorderSizePixel = 0
SearchBox.Text = ""; SearchBox.PlaceholderText = "Search..."
SearchBox.Font = Enum.Font.GothamMedium; SearchBox.TextSize = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false; SearchBox.ZIndex = 20
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0,8)
local searchStroke = Instance.new("UIStroke", SearchBox); searchStroke.Thickness = 1
onTheme(function()
    SearchBox.BackgroundColor3 = Theme.Panel2
    SearchBox.TextColor3 = Theme.Text
    SearchBox.PlaceholderColor3 = Theme.Dim
    searchStroke.Color = Theme.Border
end)
local sPad = Instance.new("UIPadding", SearchBox); sPad.PaddingLeft = UDim.new(0,12)


--=================================================================
--  TABS — LEFT SIDEBAR (LANDSCAPE)
--=================================================================
local TabBar = Instance.new("Frame", Root)
TabBar.Size = UDim2.fromOffset(110,404); TabBar.Position = UDim2.fromOffset(16,100)
TabBar.BackgroundColor3 = Theme.Panel2
TabBar.BackgroundTransparency = 0.85
TabBar.BorderSizePixel = 0; TabBar.ZIndex = 10
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0,10)
local tabBarStroke = Instance.new("UIStroke", TabBar); tabBarStroke.Thickness = 1; tabBarStroke.Transparency = 0.5
onTheme(function()
    TabBar.BackgroundColor3 = Theme.Panel2
    tabBarStroke.Color = Theme.Border
end)
local TL = Instance.new("UIListLayout", TabBar)
TL.FillDirection = Enum.FillDirection.Vertical; TL.Padding = UDim.new(0,6)
TL.HorizontalAlignment = Enum.HorizontalAlignment.Center
TL.VerticalAlignment = Enum.VerticalAlignment.Top
TL.SortOrder = Enum.SortOrder.LayoutOrder
local tlPad = Instance.new("UIPadding", TabBar)
tlPad.PaddingTop = UDim.new(0, 10)
tlPad.PaddingLeft = UDim.new(0, 8)
tlPad.PaddingRight = UDim.new(0, 8)

-- CONTENT AREA (right of sidebar)
local Pages = Instance.new("Frame", Root)
Pages.Size = UDim2.new(1,-150,1,-116); Pages.Position = UDim2.fromOffset(134,100)
Pages.BackgroundTransparency = 1; Pages.ZIndex = 10

local SearchResults = Instance.new("ScrollingFrame", Root)
SearchResults.Size = UDim2.new(1,-150,1,-116); SearchResults.Position = UDim2.fromOffset(134,100)
SearchResults.BackgroundTransparency = 1; SearchResults.BorderSizePixel = 0
SearchResults.ScrollBarThickness = 4; SearchResults.CanvasSize = UDim2.new(0,0,0,0)
SearchResults.AutomaticCanvasSize = Enum.AutomaticSize.Y
SearchResults.Visible = false; SearchResults.ZIndex = 100
local srLayout = Instance.new("UIListLayout", SearchResults)
srLayout.Padding = UDim.new(0,5); srLayout.SortOrder = Enum.SortOrder.LayoutOrder
local srPad = Instance.new("UIPadding", SearchResults)
srPad.PaddingTop = UDim.new(0,6); srPad.PaddingLeft = UDim.new(0,2)
srPad.PaddingRight = UDim.new(0,14)

local Tabs = {}
local currentTab = "ESP"

local function SelectTab(tabName)
    currentTab = tabName
    for name, v in pairs(Tabs) do
        local on = (name == tabName)
        v.page.Visible = on
        if on then
            v.page.Position = UDim2.fromOffset(0, 8)
            TweenService:Create(v.page, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0,0)}):Play()
        end
        local targetBg = on and Theme.Accent or Theme.Panel2
        local targetTxt = on and Theme.BG or Theme.Dim
        TweenService:Create(v.btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3=targetBg, TextColor3=targetTxt}):Play()
        if v.stroke then
            v.stroke.Color = Theme.Accent
            v.stroke.Transparency = on and 0.15 or 1
            v.stroke.Thickness = on and 1.5 or 1
        end
    end
end

local function MakePage()
    local s = Instance.new("ScrollingFrame", Pages)
    s.Size = UDim2.new(1,0,1,0); s.BackgroundTransparency = 1; s.BorderSizePixel = 0
    s.ScrollBarThickness = 4; s.ScrollBarImageTransparency = 0.35
    s.CanvasSize = UDim2.new(0,0,0,0); s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Visible = false; s.ZIndex = 10
    onTheme(function() s.ScrollBarImageColor3 = Theme.BorderLight end)
    local l = Instance.new("UIListLayout", s)
    l.Padding = UDim.new(0,6); l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.VerticalAlignment = Enum.VerticalAlignment.Top
    local p = Instance.new("UIPadding", s)
    p.PaddingTop = UDim.new(0,6); p.PaddingLeft = UDim.new(0,2)
    p.PaddingRight = UDim.new(0, 16); p.PaddingBottom = UDim.new(0,14)
    return s
end
local function MakeTab(name, order)
    local b = Instance.new("TextButton", TabBar)
    b.Size = UDim2.new(1, 0, 0, 32); b.BackgroundColor3 = Theme.Panel2
    b.Text = name
    b.TextColor3 = Theme.Dim
    b.Font = Enum.Font.GothamMedium; b.TextSize = 12; b.BorderSizePixel = 0
    b.LayoutOrder = order; b.AutoButtonColor = false; b.ClipsDescendants = true; b.ZIndex = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local s = Instance.new("UIStroke", b); s.Thickness = 1; s.Transparency = 1; s.Color = Theme.Accent
    Tabs[name] = { btn=b, page=MakePage(), stroke=s }
    b.MouseEnter:Connect(function()
        if Tabs[name].page.Visible then return end
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Theme.CardHover, TextColor3=Theme.Text}):Play()
    end)
    b.MouseLeave:Connect(function()
        if Tabs[name].page.Visible then return end
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Theme.Panel2, TextColor3=Theme.Dim}):Play()
    end)
    b.MouseButton1Click:Connect(function() SelectTab(name) end)
end

-- MISC moved to last slot
MakeTab("ESP",1); MakeTab("Aim",2); MakeTab("Farm",3)
MakeTab("Move",4); MakeTab("Weapon",5); MakeTab("Cheats",6)
MakeTab("Misc",7)
task.defer(function() task.wait(0.1); SelectTab("ESP") end)
onTheme(function() SelectTab(currentTab) end)

--============== LAYOUT (Landscape <-> Portrait) ==============
local PortraitMode = false

local LayoutConfig = {
    landscape = {
        RootSize   = UDim2.fromOffset(840, 520),
        RootPos    = UDim2.new(0.5, -420, 0.5, -260),
        TabBarSize = UDim2.fromOffset(110, 404),
        TabBarPos  = UDim2.fromOffset(16, 100),
        TabDir     = Enum.FillDirection.Vertical,
        TabPadTop  = 10,
        TabPadLR   = 8,
        TabBtnSize = UDim2.new(1, 0, 0, 32),
        PagesSize  = UDim2.new(1, -150, 1, -116),
        PagesPos   = UDim2.fromOffset(134, 100),
        SearchSize = UDim2.new(1, -150, 1, -116),
        SearchPos  = UDim2.fromOffset(134, 100),
        SearchFullSize = UDim2.new(1, -32, 1, -116),
        SearchFullPos  = UDim2.fromOffset(16, 100),
    },
    portrait = {
        RootSize   = UDim2.fromOffset(460, 660),
        RootPos    = UDim2.new(0.5, -230, 0.5, -330),
        TabBarSize = UDim2.new(1, -32, 0, 36),
        TabBarPos  = UDim2.fromOffset(16, 96),
        TabDir     = Enum.FillDirection.Horizontal,
        TabPadTop  = 0,
        TabPadLR   = 0,
        TabBtnSize = UDim2.fromOffset(48, 30),
        PagesSize  = UDim2.new(1, -32, 1, -154),
        PagesPos   = UDim2.fromOffset(16, 138),
        SearchSize = UDim2.new(1, -32, 1, -154),
        SearchPos  = UDim2.fromOffset(16, 138),
        SearchFullSize = UDim2.new(1, -32, 1, -96),
        SearchFullPos  = UDim2.fromOffset(16, 96),
    },
}

local function applyLayout(mode, animate)
    if mode ~= "portrait" then mode = "landscape" end
    PortraitMode = (mode == "portrait")

    -- Update the title-bar subtitle (fade-swap)
    if TSub and TSub.Parent then
        TweenService:Create(TSub, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextTransparency = 1}):Play()
        task.delay(0.15, function()
            if TSub and TSub.Parent then
                TSub.Text = "by selever_el  •  v4.1 · " .. (PortraitMode and "Portrait" or "Landscape")
                TweenService:Create(TSub, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
            end
        end)
    end

    local cfg = LayoutConfig[mode]

    local info = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

    -- Non-tweenable layout props get set first (they snap)
    TL.FillDirection = cfg.TabDir
    TL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TL.VerticalAlignment = (cfg.TabDir == Enum.FillDirection.Horizontal)
        and Enum.VerticalAlignment.Center
        or  Enum.VerticalAlignment.Top
    TL.Padding = UDim.new(0, (cfg.TabDir == Enum.FillDirection.Horizontal) and 4 or 6)

    if animate then
        TweenService:Create(Root, info, {
            Size     = cfg.RootSize,
            Position = cfg.RootPos,
        }):Play()
        TweenService:Create(TabBar, info, {
            Size     = cfg.TabBarSize,
            Position = cfg.TabBarPos,
        }):Play()
        TweenService:Create(tlPad, info, {
            PaddingTop   = UDim.new(0, cfg.TabPadTop),
            PaddingLeft  = UDim.new(0, cfg.TabPadLR),
            PaddingRight = UDim.new(0, cfg.TabPadLR),
        }):Play()
        TweenService:Create(Pages, info, {
            Size     = cfg.PagesSize,
            Position = cfg.PagesPos,
        }):Play()
        TweenService:Create(SearchResults, info, {
            Size     = cfg.SearchSize,
            Position = cfg.SearchPos,
        }):Play()
        for _, v in pairs(Tabs) do
            TweenService:Create(v.btn, info, {Size = cfg.TabBtnSize}):Play()
        end
    else
        Root.Size = cfg.RootSize;                 Root.Position = cfg.RootPos
        TabBar.Size = cfg.TabBarSize;             TabBar.Position = cfg.TabBarPos
        tlPad.PaddingTop   = UDim.new(0, cfg.TabPadTop)
        tlPad.PaddingLeft  = UDim.new(0, cfg.TabPadLR)
        tlPad.PaddingRight = UDim.new(0, cfg.TabPadLR)
        for _, v in pairs(Tabs) do v.btn.Size = cfg.TabBtnSize end
        Pages.Size = cfg.PagesSize;               Pages.Position = cfg.PagesPos
        SearchResults.Size = cfg.SearchSize;      SearchResults.Position = cfg.SearchPos
    end
end

--=================================================================
--  WIDGETS
--=================================================================
local refreshers = {}
local searchIndex = {}
local currentWidgetTab = "ESP"

local function Section(page, text, order)
    local c = Instance.new("Frame", page)
    c.Size = UDim2.new(1,-6,0,26); c.BackgroundTransparency = 1; c.LayoutOrder = order
    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.fromOffset(3,14); bar.Position = UDim2.fromOffset(4,6)
    bar.BorderSizePixel = 0; Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    onTheme(function() bar.BackgroundColor3 = Theme.Accent end)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-20,1,0); l.Position = UDim2.fromOffset(14,0)
    l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
    l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(text)
    onTheme(function() l.TextColor3 = Theme.Accent end)
    return c
end

local function Card(page, order, height)
    local c = Instance.new("Frame", page)
    c.Size = UDim2.new(1,-6,0, height or 34); c.BorderSizePixel = 0
    c.LayoutOrder = order; c.ClipsDescendants = true
    Instance.new("UICorner", c).CornerRadius = UDim.new(0,8)
    local grad = Instance.new("UIGradient", c); grad.Rotation = 90
    local s = Instance.new("UIStroke", c); s.Thickness = 1; s.Transparency = 0.35
    onTheme(function()
        c.BackgroundColor3 = Theme.Card
        grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Card),ColorSequenceKeypoint.new(1,Theme.Panel)})
        s.Color = Theme.Border
    end)
    return c
end

local function addRipple(btn)
    btn.ClipsDescendants = true
    btn.MouseButton1Down:Connect(function()
        local m = UIS:GetMouseLocation()
        local rx = m.X - btn.AbsolutePosition.X
        local ry = m.Y - btn.AbsolutePosition.Y
        local ripple = Instance.new("Frame")
        ripple.BackgroundColor3 = Color3.new(1,1,1); ripple.BackgroundTransparency = 0.7
        ripple.BorderSizePixel = 0; ripple.ZIndex = (btn.ZIndex or 3) + 5
        ripple.AnchorPoint = Vector2.new(0.5,0.5)
        ripple.Position = UDim2.fromOffset(rx,ry); ripple.Size = UDim2.fromOffset(0,0)
        Instance.new("UICorner", ripple).CornerRadius = UDim.new(1,0)
        ripple.Parent = btn
        local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.5
        TweenService:Create(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(maxSize,maxSize), BackgroundTransparency = 1
        }):Play()
        task.delay(0.55, function() if ripple and ripple.Parent then ripple:Destroy() end end)
    end)
end

local function Btn(page, order, label, cb, color)
    local c = Card(page, order, 34)
    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(1,0,1,0); b.BackgroundTransparency = 1
    b.Text = label; b.Font = Enum.Font.GothamMedium; b.TextSize = 12
    b.AutoButtonColor = false; b.ClipsDescendants = true; b.ZIndex = 13
    onTheme(function() b.TextColor3 = Theme.Text end)
    addRipple(b)
    b.MouseEnter:Connect(function()
        TweenService:Create(c, TweenInfo.new(0.12), {BackgroundColor3=color or Theme.CardHover}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(c, TweenInfo.new(0.12), {BackgroundColor3=Theme.Card}):Play()
    end)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then
            warn("[EP] " .. tostring(err))
            showToast("Error: "..tostring(err), "error")
        end
    end)
    table.insert(searchIndex, {tab=currentWidgetTab, label=label, card=c})
    return b, c
end
-- PREMIUM TOGGLE (Minimalist & Smaller)
local function Toggle(page, order, label, get, set)
    local c = Card(page, order, 34) -- Smaller height
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-74,1,0); l.Position = UDim2.fromOffset(14,0)
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 11 -- Smaller text
    l.TextXAlignment = Enum.TextXAlignment.Left
    onTheme(function() l.TextColor3 = Theme.Text end)

    local tr = Instance.new("Frame", c)
    tr.Size = UDim2.fromOffset(36,18); tr.Position = UDim2.new(1,-50,0.5,-9) -- Smaller track
    tr.BorderSizePixel = 0
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1,0)

    local trGrad = Instance.new("UIGradient", tr); trGrad.Rotation = 90
    local trStroke = Instance.new("UIStroke", tr); trStroke.Thickness = 1; trStroke.Transparency = 0.5

    local kn = Instance.new("Frame", tr)
    kn.Size = UDim2.fromOffset(14,14); kn.BorderSizePixel = 0 -- Smaller knob
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)

    local knGrad = Instance.new("UIGradient", kn); knGrad.Rotation = 90
    local knStroke = Instance.new("UIStroke", kn); knStroke.Thickness = 1; knStroke.Transparency = 0.6

    local function render()
        local on = get()
        TweenService:Create(tr, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundColor3 = on and Theme.Accent or Theme.Panel2
        }):Play()
        trGrad.Color = on and ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Accent2)
        }) or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Panel2),
            ColorSequenceKeypoint.new(1, Theme.Border)
        })
        
        TweenService:Create(kn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
            BackgroundColor3 = on and Theme.BG or Theme.Dim
        }):Play()
        
        trStroke.Color = on and Theme.Accent or Theme.Border
        trStroke.Transparency = on and 0.3 or 0.6
        knStroke.Color = on and Theme.Accent2 or Theme.BorderLight
        knStroke.Transparency = on and 0.5 or 0.7
    end
    render()
    refreshers[#refreshers+1] = render; onTheme(render)

    local click = Instance.new("TextButton", c)
    click.Size = UDim2.new(1,0,1,0); click.BackgroundTransparency = 1
    click.Text = ""; click.ClipsDescendants = true; click.ZIndex = 12
    addRipple(click)
    click.MouseButton1Click:Connect(function()
        set(not get()); render()
        pcall(function()
            if label:find("ESP") or label:find("Tracers") then rebuildESP() end
        end)
    end)


    table.insert(searchIndex, {tab=currentWidgetTab, label=label, card=c})
    return c
end

local ActiveSlider = nil
local function Slider(page, order, label, min, max, default, step, cb)
    min = tonumber(min) or 0; max = tonumber(max) or 1
    default = tonumber(default) or min; step = tonumber(step) or 1
    if step <= 0 then step = 1 end
    if max <= min then max = min + 1 end
    if default < min then default = min end
    if default > max then default = max end

    local c = Card(page, order, 40)
    
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.6,0,0,14); l.Position = UDim2.fromOffset(14,6)
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 11 
    l.TextXAlignment = Enum.TextXAlignment.Left
    onTheme(function() l.TextColor3 = Theme.Text end)

    local valLbl = Instance.new("TextLabel", c)
    valLbl.Size = UDim2.new(0.35,-14,0,14); valLbl.Position = UDim2.new(0.6,0,0,6)
    valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(default)
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    onTheme(function() valLbl.TextColor3 = Theme.Accent end)

    -- MOVED TRACK DOWN TO Y = 29 (was 26)
    local track = Instance.new("Frame", c)
    track.Size = UDim2.new(1,-28,0,3); track.Position = UDim2.new(0,14,0,27)
    track.BorderSizePixel = 0; track.BackgroundTransparency = 0.5; track.Active = true
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    onTheme(function() track.BackgroundColor3 = Theme.Border end)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0,0,1,0); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    onTheme(function() fill.BackgroundColor3 = Theme.Accent end)

    -- Circle remains the perfect 10x10 size
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.fromOffset(10,10); knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(0,0,0.5,0); knob.BorderSizePixel = 0; knob.Active = true
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    onTheme(function() knob.BackgroundColor3 = Theme.Accent end)
    
    local knStroke = Instance.new("UIStroke", knob); knStroke.Thickness = 1
    onTheme(function() knStroke.Color = Theme.Accent2 end)

    local currentValue = default
    local function setFromPct(pct)
        pct = math.clamp(pct, 0, 1)
        local raw = min + (max - min) * pct
        local rounded = math.floor((raw / step) + 0.5) * step
        rounded = math.clamp(rounded, min, max)
        currentValue = rounded
        local dp = (rounded - min) / (max - min)
        fill.Size = UDim2.fromScale(dp, 1)
        knob.Position = UDim2.new(dp,0,0.5,0)
        if step >= 1 then valLbl.Text = tostring(math.floor(rounded))
        else valLbl.Text = string.format("%.2f", rounded) end
        pcall(cb, rounded)
    end
    setFromPct((default - min) / (max - min))

    local function pctFromX(x) return (x - track.AbsolutePosition.X) / track.AbsoluteSize.X end
    local sliderCtx = { setFromPct = setFromPct, pctFromX = pctFromX }
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ActiveSlider = sliderCtx
            setFromPct(pctFromX(input.Position.X))
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ActiveSlider = sliderCtx
        end
    end)
    table.insert(searchIndex, {tab=currentWidgetTab, label=label, card=c})
    return c
end
UIS.InputChanged:Connect(function(input)
    if ActiveSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        ActiveSlider.setFromPct(ActiveSlider.pctFromX(input.Position.X))
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ActiveSlider = nil
    end
end)

local function refreshAll() for _, r in ipairs(refreshers) do pcall(r) end end

--=================================================================
--  ESP TAB
--=================================================================
currentWidgetTab = "ESP"
local P = Tabs.ESP.page
Section(P, "Main Toggle", 1)
Toggle(P, 2, "Enable ESP",
    function() return State.ESPEnabled end,
    function(v)
        State.ESPEnabled = v; rebuildESP()
        showToast("ESP "..(v and "Enabled" or "Disabled"), v and "success" or "info")
    end)
Toggle(P, 3, "ESP Tracers",
    function() return State.ESPTracers end,
    function(v) State.ESPTracers = v; rebuildESP() end)
Section(P, "Filtering", 5)
Toggle(P, 6, "Only show Enemies",
    function() return State.ESPFilter == "Enemies" end,
    function(v) State.ESPFilter = v and "Enemies" or "All" end)
Slider(P, 7, "Max Distance", 50, 5000, State.ESPMaxDistance, 50, function(v) State.ESPMaxDistance = v end)

Section(P, "Color Legend", 10)
local function legendLine(order, text, color)
    local c = Card(P, order, 28)
    local dot = Instance.new("Frame", c)
    dot.Size = UDim2.fromOffset(10,10); dot.Position = UDim2.fromOffset(14,9)
    dot.BackgroundColor3 = color; dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-40,1,0); l.Position = UDim2.fromOffset(32,0)
    l.BackgroundTransparency = 1; l.Text = text
    l.Font = Enum.Font.GothamMedium; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    onTheme(function() l.TextColor3 = Theme.Text end)
end
legendLine(11, "Criminal Civilian", ROLE_COLORS.Criminal)
legendLine(12, "Normal Civilian",   ROLE_COLORS.Civilian)
legendLine(13, "Paramedic",         ROLE_COLORS.Paramedic)
legendLine(14, "Border Patrol",     FED_TEAM_COLORS["Border Patrol"])
legendLine(15, "BORTAC",            FED_TEAM_COLORS["BORTAC"])
legendLine(16, "US Army",           FED_TEAM_COLORS["US Army"])
legendLine(17, "State Trooper",     FED_TEAM_COLORS["State Trooper"])
legendLine(18, "FBI",               FED_TEAM_COLORS["FBI"])
legendLine(19, "HSI",               FED_TEAM_COLORS["HSI"])
legendLine(20, "SWAT",              FED_TEAM_COLORS["SWAT"])
legendLine(21, "Border Supervisor", FED_TEAM_COLORS["Border Supervisor"])
legendLine(22, "Dead",              ROLE_COLORS.Dead)

Section(P, "Actions", 30)
Btn(P, 31, "Force Refresh ESP", function() rebuildESP(); showToast("ESP refreshed", "success") end)
Btn(P, 32, "Clear All ESP", function()
    for plr in pairs(State.ESPData) do destroyESP(plr) end
    showToast("ESP cleared", "info")
end)

--============== AIM TAB ==============
currentWidgetTab = "Aim"
P = Tabs.Aim.page
Section(P, "Targeting", 1)
Toggle(P, 2, "Aim Enabled",
    function() return State.AimEnabled end,
    function(v) State.AimEnabled = v; showToast("Aim "..(v and "Enabled" or "Disabled"), v and "success" or "info") end)
Toggle(P, 3, "Auto Equip Best Gun", function() return State.AimAutoEquip end, function(v)
    State.AimAutoEquip = v
    if not v then unequipGun() end
end)
Toggle(P, 4, "Aim Head (else Torso)", function() return State.AimUseHead end, function(v) State.AimUseHead = v end)
Slider(P, 5, "Max Distance", 100, 3000, State.AimMaxDistance, 50, function(v) State.AimMaxDistance = v end)
Slider(P, 6, "Smoothness", 0, 1, State.AimSmoothness, 0.05, function(v) State.AimSmoothness = v end)
Section(P, "Rules", 10)
local infoCard = Card(P, 11, 52)
local infoLabel = Instance.new("TextLabel", infoCard)
infoLabel.Size = UDim2.new(1,-20,1,0); infoLabel.Position = UDim2.fromOffset(12,0)
infoLabel.BackgroundTransparency = 1; infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Font = Enum.Font.Gotham; infoLabel.TextSize = 11; infoLabel.TextWrapped = true
infoLabel.Text = "Aimbot + Auto Equip is active.\nYOU MUST CLICK TO SHOOT."
onTheme(function() infoLabel.TextColor3 = Theme.Dim end)
Btn(P, 20, "Recalculate Target Now", function()
    local ok, t = pcall(findTarget)
    if ok and t then
        State.Target = t; aimAt(t)
        showToast("Target: "..t.Name.." ("..getRole(t)..")", "success")
    else
        showToast("No valid target found", "warn")
    end
end)

--============== FARM TAB ==============
currentWidgetTab = "Farm"
P = Tabs.Farm.page
Section(P, "Auto Actions", 1)
Toggle(P, 2, "Auto Daily Rewards", function() return State.AutoDaily end, function(v) State.AutoDaily = v; if v then showToast("Auto Daily ON", "success") end end)
Toggle(P, 3, "Auto Launder Dirty Cash", function() return State.AutoLaunder end, function(v) State.AutoLaunder = v; if v then showToast("Auto Launder ON", "success") end end)
Toggle(P, 4, "Auto Accept Truck Job", function() return State.AutoTruck end, function(v) State.AutoTruck = v; if v then showToast("Auto Truck ON", "success") end end)
Toggle(P, 5, "Auto Rob Nearby ATM", function() return State.AutoATM end, function(v) State.AutoATM = v; if v then showToast("Auto ATM ON", "success") end end)
Section(P, "Manual Triggers", 10)
Btn(P, 11, "Claim Daily Once", function()
    local r = R("DailyClaim")
    if r then pcall(function() r:FireServer() end); showToast("Daily claimed", "success")
    else showToast("DailyClaim remote not found", "warn") end
end)
Btn(P, 12, "Launder Now", function()
    local qf = F("LaunderQuote"); local lr = R("Launder")
    if qf and lr then
        local ok, q = pcall(function() return qf:InvokeServer() end)
        if ok and q and q.Amount > 0 and q.Enabled then
            pcall(function() lr:FireServer() end)
            showToast("Laundered $"..tostring(q.Amount), "success")
        else showToast("Nothing to launder", "warn") end
    else showToast("Launder remotes not found", "error") end
end)
Btn(P, 13, "Accept Truck Job", function()
    local r = R("TruckJob_Accept")
    if r then pcall(function() r:FireServer("ChevlonExpress") end); showToast("Truck job accepted", "success")
    else showToast("TruckJob_Accept not found", "warn") end
end)
Btn(P, 14, "Auto-Sell Excess (launder)", function()
    local qf = F("LaunderQuote"); local lr = R("Launder")
    if qf and lr then
        local ok, q = pcall(function() return qf:InvokeServer() end)
        if ok and q and q.Enabled then
            pcall(function() lr:FireServer() end)
            showToast("Auto-sell fired", "success")
        end
    end
end)

-- ───────── Car Teleport (sliding section) ─────────
-- Server trusts car position while you drive → PivotTo(car) = clean TP
local CTP_LOCATIONS = {
    {Name="Bank"}, {Name="Jewelry"}, {Name="PawnGuns"}, {Name="Goods"},
    {Name="BlackMarket"}, {Name="Containers"}, {Name="Fence"},
    {Name="GunBuyer"}, {Name="Hospital"}, {Name="Gymbro"},
    {Name="Laundry"}, {Name="Safety"}, {Name="Box"},
    {Name="Job"}, {Name="Scan"}, {Name="Pumpkin Candy"},
    {Name="NorthAccess"}, {Name="SouthAccess"},
}
local CTP_FALLBACK = {
    Bank     = "Workspace.Map.El Paso.Buildings.Bank",
    Jewelry  = "Workspace.Map.El Paso.Buildings.JEWELRY",
    PawnGuns = "Workspace.Map.El Paso.Buildings.PawnGuns_Muebles_Blockout",
}

local function CTP_resolvePath(path)
    local obj = workspace
    for seg in string.gmatch(path, "[^%.]+") do
        obj = obj:FindFirstChild(seg)
        if not obj then return nil end
    end
    return obj
end

local function CTP_getWaypointCF(name)
    local folder = workspace:FindFirstChild("_MapWaypoints_")
    if folder then
        local p = folder:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p.CFrame * CFrame.new(0, 3, 0) end
    end
    local path = CTP_FALLBACK[name]
    if path then
        local obj = CTP_resolvePath(path)
        if obj then
            local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if pp then return pp.CFrame * CFrame.new(0, 5, 0) end
        end
    end
    return nil
end


--═══════════════════════════════════════════════════════════════
--  Live "Pumpkin Candy" Scanner & Farm Loop (100% Fixed)
--═══════════════════════════════════════════════════════════════
local function PF_findNearestCandy()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local myPos = hrp.Position
    local best, bestD

    local function getPart(o)
        if not o or not o.Parent then return nil end
        if o:IsA("BasePart") then return o end
        if o:IsA("Model") then 
            return o.PrimaryPart or o:FindFirstChildWhichIsA("MeshPart") or o:FindFirstChildWhichIsA("BasePart") 
        end
        return nil
    end

    local function isValid(o)
        if not o then return false end
        if char and o:IsDescendantOf(char) then return false end
        if o:GetAttribute("Candy") ~= nil then return true end
        local n = o.Name:lower()
        if n == "candy" or n:find("pumpkincandy") or n:find("pumpkincoin") then return true end
        return false
    end

    local function consider(o)
        if isValid(o) then
            local part = getPart(o)
            if part then
                local d = (part.Position - myPos).Magnitude
                if not bestD or d < bestD then
                    best = part
                    bestD = d
                end
            end
        end
    end

    -- 1) Primary source
    local hgc = workspace:FindFirstChild("HalloweenGroundCandy")
    if hgc then
        for _, c in ipairs(hgc:GetDescendants()) do consider(c) end
    end

    -- 2) Global aggressive fallback (scans the entire map!)
    if not best then
        for _, c in ipairs(workspace:GetDescendants()) do
            if c.Name ~= "Workspace" and c.Name ~= "Camera" then
                consider(c)
            end
        end
    end

    return best, bestD
end

local RF_VehicleShop = findRemote("VehicleShopInteract", "RemoteFunction")
local function CTP_autoSpawnCar()
    if not RF_VehicleShop then return false, "VehicleShopInteract not found" end
    local myChar = LP.Character
    local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end
    
    -- Find nearest Car Spawner (Fixed to find the Part, not just a Prompt)
    local bestPart, bestDist
    for _, p in ipairs(CollectionService:GetTagged("InterfacePrompt")) do
        if p:GetAttribute("Interface") == "CarSpawner" then
            local bp = p
            if not bp:IsA("BasePart") then
                bp = bp.Parent
                if not bp or not bp:IsA("BasePart") then
                    bp = p:FindFirstChildWhichIsA("BasePart", true)
                end
            end
            if bp then
                local d = (bp.Position - hrp.Position).Magnitude
                if not bestDist or d < bestDist then bestPart, bestDist = bp, d end
            end
        end
    end
    
    -- Fallback: look for CarShopInterface parts directly
    if not bestPart then
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") and p.Name == "CarShopInterface" and p:GetAttribute("Interface") == "CarSpawner" then
                local d = (p.Position - hrp.Position).Magnitude
                if not bestDist or d < bestDist then bestPart, bestDist = p, d end
            end
        end
    end
    if not bestPart then return false, "No car spawner found on the map" end
    
    -- 1. TP player to spawner
    safeTeleport(CFrame.new(bestPart.Position + Vector3.new(0, 5, 0)))
    task.wait(0.5)
    
    -- 2. Spawn the car
    local ok, Vehicles = pcall(require, RS.Data.Vehicles)
    if not ok then return false, "Vehicles data missing" end
    local idx
    for i, v in ipairs(Vehicles) do
        if v.Name == "Hunda Civic" then idx = i; break end
    end
    if not idx then return false, "Hunda Civic not found" end
    
    local suc, err = pcall(function()
        return RF_VehicleShop:InvokeServer(idx, "Hunda Civic", nil, bestPart)
    end)
    
    if suc then
        task.wait(1.5) -- Wait for server to spawn it
        
        -- 3. Find the spawned car and sit the player
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local bestSeat, bestSeatDist = nil, math.huge
        
        for _, c in ipairs(CollectionService:GetTagged("Car")) do
            if c:IsA("Model") and c.Parent then
                local owner = c:GetAttribute("OwnerUserId") or c:GetAttribute("Owner")
                if owner == LP.UserId or owner == LP.Name or owner == LP.DisplayName then
                    local seat = c:FindFirstChild("DriveSeat") or c:FindFirstChildWhichIsA("VehicleSeat", true)
                    if seat then
                        local d = (seat.Position - hrp.Position).Magnitude
                        if d < bestSeatDist then
                            bestSeat = seat
                            bestSeatDist = d
                        end
                    end
                end
            end
        end
        
        if bestSeat and hum then
            safeTeleport(bestSeat.CFrame * CFrame.new(0, 2, 0))
            task.wait(0.2)
            pcall(function() bestSeat:Sit(hum) end)
            task.wait(0.5)
            return true
        end
        return false, "Spawned but could not find seat"
    end
    return false, tostring(err)
end

local CTP_snapLoops = {}
local function CTP_teleportCar(car, seat, targetCF)
    if not car.PrimaryPart then
        car.PrimaryPart = car:FindFirstChild("Collision_Part") or car:FindFirstChild("Body") or car:FindFirstChildWhichIsA("BasePart")
    end
    if not car.PrimaryPart then return false, "Car has no PrimaryPart" end

    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity  = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local seatOffset   = car.PrimaryPart.CFrame:ToObjectSpace(seat.CFrame)
    local newPrimaryCF = targetCF * seatOffset:Inverse()
    car:PivotTo(newPrimaryCF)

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")

    local function snap()
        if char and char.Parent and hum and hum.SeatPart and hrp then
            hrp.CFrame = hum.SeatPart.CFrame * CFrame.new(0, 1.5, 0)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    snap()
    task.delay(0.05, snap)
    task.delay(0.15, snap)
    return true
end

local CTP_lastTP = 0
local function CTP_doTeleport(cf, label)
    local now = tick()
    if now - CTP_lastTP < 0.5 then return false, "Wait a moment" end

    local car, seat = getCarAndSeat()
    if not car then
        if not State.CarTPAutoSpawn then return false, "You need to sit in the car!" end
        local ok, err = CTP_autoSpawnCar()
        if not ok then return false, "Auto-spawn failed: " .. tostring(err) end
        task.wait(1)
        car, seat = getCarAndSeat()
        if not car then return false, "Spawned but not seated — try again" end
    end

    CTP_lastTP = now
    return CTP_teleportCar(car, seat, cf)
end

-- Automated Farm Loop State
local PumpkinFarm = { Active = false, CoinCount = 0, StartedAt = 0 }

local function PF_loop()
    while PumpkinFarm.Active and not _G.EP_Unloaded do
        local char = LP.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        if not hum or not hrp or hum.Health <= 0 then task.wait(0.5); continue end

        -- 1. Ensure we are inside a car
        local car, seat = getCarAndSeat()
        if not car then
            if State.CarTPAutoSpawn then
                pcall(CTP_autoSpawnCar)
                task.wait(2)
                car, seat = getCarAndSeat()
            end
            if not car then task.wait(1); continue end
        end

        -- 2. Find nearest coin
        local candy, dist = PF_findNearestCandy()
        if not candy then task.wait(2); continue end

        -- 3. TP car next to coin
        local tpcf = CFrame.new(candy.Position + Vector3.new(0, 6, 0))
        pcall(CTP_doTeleport, tpcf, "PumpkinCoin")
        task.wait(0.5)

        -- 4. Exit car
        if hum.SeatPart then pcall(function() hum.Sit = false end); task.wait(0.25) end

        -- 5. TP character onto the coin
        if candy and candy.Parent then
            safeTeleport(CFrame.new(candy.Position + Vector3.new(0, 2, 0)))
        end

        -- 6. Try ProximityPrompt if present
        task.wait(0.1)
        if candy and candy.Parent then
            local prompt = candy:FindFirstChildWhichIsA("ProximityPrompt", true) or (candy.Parent and candy.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))
            if prompt then pcall(fireproximityprompt, prompt) end
        end

        -- 7. Wait for pickup
        task.wait(0.6)
        if not candy or not candy.Parent then
            PumpkinFarm.CoinCount = PumpkinFarm.CoinCount + 1
            showToast("Pumpkin coin collected (" .. PumpkinFarm.CoinCount .. ")", "success")
        end

        -- 8. Return to car & re-seat
        local car2, seat2 = getCarAndSeat()
        if seat2 then
            safeTeleport(seat2.CFrame * CFrame.new(0, 2, 0))
            task.wait(0.15)
            if hum and hum.Parent then
                pcall(function() seat2:Sit(hum) end)
                task.wait(0.15)
                if not hum.Sit then pcall(function() hum.Sit = true end) end
            end
            task.wait(0.35)
        end
    end
    PumpkinFarm.Active = false
end

local function PF_start()
    if PumpkinFarm.Active then return end
    PumpkinFarm.Active = true
    PumpkinFarm.CoinCount = 0
    PumpkinFarm.StartedAt = tick()
    showToast("Pumpkin Farm started!", "success")
    task.spawn(PF_loop)
end

local function PF_stop()
    local elapsed = math.floor(tick() - PumpkinFarm.StartedAt)
    PumpkinFarm.Active = false
    showToast(("Pumpkin Farm stopped (%d coins)"):format(PumpkinFarm.CoinCount), "info")
end

local function CTP_tpToName(name)
    if name == "Pumpkin Candy" then
        local candy, dist = PF_findNearestCandy()
        if not candy then return false, "No pumpkin candy found in the map" end
        local cf = CFrame.new(candy.Position + Vector3.new(0, 6, 0))
        return CTP_doTeleport(cf, ("Pumpkin Candy (%.0fm)"):format(dist or 0))
    end

    local cf = CTP_getWaypointCF(name)
    if not cf then return false, "Location '" .. name .. "' not found" end
    return CTP_doTeleport(cf, name)
end

local CTP_mapGui = nil
local function CTP_openMapPicker()
    if CTP_mapGui and CTP_mapGui.Parent then CTP_mapGui:Destroy() end
    CTP_mapGui = Instance.new("ScreenGui")
    CTP_mapGui.Name = "EP_CarTP_Map"
    CTP_mapGui.IgnoreGuiInset = true
    CTP_mapGui.ResetOnSpawn = false
    CTP_mapGui.DisplayOrder = 100
    CTP_mapGui.Parent = LP:WaitForChild("PlayerGui")

    local overlay = Instance.new("Frame", CTP_mapGui)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new()
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.Active = true

    local panel = Instance.new("Frame", overlay)
    panel.Size = UDim2.fromOffset(420, 280)
    panel.Position = UDim2.new(0.5, -210, 0.5, -140)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", panel); stroke.Thickness = 1
    panel.BackgroundColor3 = Theme.BG; stroke.Color = Theme.BorderLight
    onTheme(function() panel.BackgroundColor3 = Theme.BG; stroke.Color = Theme.BorderLight end)

    local lbl = Instance.new("TextLabel", panel)
    lbl.Size = UDim2.new(1, -90, 0, 28); lbl.Position = UDim2.fromOffset(12, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  Car Teleport — Crosshair"
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.Text
    onTheme(function() lbl.TextColor3 = Theme.Text end)

    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Size = UDim2.fromOffset(28, 28); closeBtn.Position = UDim2.new(1, -36, 0, 8)
    closeBtn.BorderSizePixel = 0; closeBtn.Text = "×"
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 18
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.BackgroundColor3 = Theme.Panel2; closeBtn.TextColor3 = Theme.Dim
    onTheme(function() closeBtn.BackgroundColor3 = Theme.Panel2; closeBtn.TextColor3 = Theme.Dim end)
    closeBtn.MouseButton1Click:Connect(function() CTP_mapGui:Destroy() end)

    local info = Instance.new("TextLabel", panel)
    info.Size = UDim2.new(1, -24, 0, 80); info.Position = UDim2.fromOffset(12, 48)
    info.BackgroundTransparency = 1
    info.Text = "Aim camera at the ground where you want the car to land, then click below.\n\nTip: waypoints are in the Farm tab's Car Teleport section."
    info.Font = Enum.Font.Gotham; info.TextSize = 11
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextColor3 = Theme.Dim
    onTheme(function() info.TextColor3 = Theme.Dim end)

    local tpBtn = Instance.new("TextButton", panel)
    tpBtn.Size = UDim2.new(1, -24, 0, 54); tpBtn.Position = UDim2.new(0, 12, 1, -66)
    tpBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
    tpBtn.BorderSizePixel = 0
    tpBtn.Text = "🎯  TELEPORT TO CROSSHAIR"
    tpBtn.Font = Enum.Font.GothamBold; tpBtn.TextSize = 13
    tpBtn.TextColor3 = Color3.new(1, 1, 1)
    tpBtn.AutoButtonColor = false
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 8)
    tpBtn.MouseEnter:Connect(function() TweenService:Create(tpBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(50, 110, 210)}):Play() end)
    tpBtn.MouseLeave:Connect(function() TweenService:Create(tpBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 90, 180)}):Play() end)
    tpBtn.MouseButton1Click:Connect(function()
        CTP_mapGui:Destroy()
        local cam = workspace.CurrentCamera
        local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LP.Character}
        local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if hit then
            local ok, err = CTP_doTeleport(CFrame.new(hit.Position + Vector3.new(0, 5, 0)), "Crosshair")
            if ok then showToast("Car TP → Crosshair", "success")
            else showToast(tostring(err), "warn") end
        else
            showToast("No ground hit — aim lower", "warn")
        end
    end)
end

-- Sliding UI section
Section(P, "Car Teleport (Exploit)", 20)

task.spawn(function() -- <--- THIS FIXES THE 200 LIMIT ERROR
    -- Height: status(34) + auto-spawn(34) + farm-loop(34) + grid(354) + cancel(34) + 4 gaps*6 + buffer
    local ctpContentHeight = 34 + 34 + 34 + 354 + 34 + (4 * 6) + 20
    local ctpContainer = Instance.new("Frame", P)
    ctpContainer.Size = UDim2.new(1, -6, 0, 0)
    ctpContainer.BackgroundTransparency = 1
    ctpContainer.ClipsDescendants = true
    ctpContainer.LayoutOrder = 22

    local ctpLayout = Instance.new("UIListLayout", ctpContainer)
    ctpLayout.Padding = UDim.new(0, 6)
    ctpLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Status card
    local ctpStatusCard = Card(ctpContainer, 1, 34)
    local ctpStatus = Instance.new("TextLabel", ctpStatusCard)
    ctpStatus.Size = UDim2.new(1, -20, 1, 0); ctpStatus.Position = UDim2.fromOffset(12, 0)
    ctpStatus.BackgroundTransparency = 1
    ctpStatus.Font = Enum.Font.GothamMedium; ctpStatus.TextSize = 11
    ctpStatus.TextXAlignment = Enum.TextXAlignment.Left
    ctpStatus.Text = " Not in a car"
    ctpStatus.TextColor3 = Theme.Dim
    onTheme(function() ctpStatus.TextColor3 = Theme.Dim end)

    -- Auto-spawn toggle
    Toggle(ctpContainer, 2, "Auto-spawn car on teleport", function() return State.CarTPAutoSpawn end, function(v)
        State.CarTPAutoSpawn = v
        showToast("Auto-spawn " .. (v and "ON" or "OFF"), v and "success" or "info")
    end)

    -- Auto Pumpkin Loop
    Toggle(ctpContainer, 6, "Auto Pumpkin Farm Loop", function() return PumpkinFarm.Active end, function(v)
        if v then PF_start() else PF_stop() end
    end)

    -- 2-column waypoint grid
    local ctpGridFrame = Instance.new("Frame", ctpContainer)
    ctpGridFrame.Size = UDim2.new(1, 0, 0, 354)
    ctpGridFrame.BackgroundTransparency = 1
    ctpGridFrame.LayoutOrder = 4

    local ctpGrid = Instance.new("UIGridLayout", ctpGridFrame)
    ctpGrid.CellSize = UDim2.new(0.5, -3, 0, 34)
    ctpGrid.CellPadding = UDim2.new(0, 6, 0, 6)
    ctpGrid.SortOrder = Enum.SortOrder.LayoutOrder

    local function ctpGridBtn(parent, order, label, cb)
        local b = Instance.new("TextButton", parent)
        b.BorderSizePixel = 0
        b.Text = label
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 10
        b.AutoButtonColor = false
        b.LayoutOrder = order
        b.TextTruncate = Enum.TextTruncate.AtEnd
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        local s = Instance.new("UIStroke", b); s.Thickness = 1; s.Transparency = 0.35
        b.BackgroundColor3 = Theme.Card; b.TextColor3 = Theme.Text; s.Color = Theme.Border
        onTheme(function() b.BackgroundColor3 = Theme.Card; b.TextColor3 = Theme.Text; s.Color = Theme.Border end)
        b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Theme.CardHover}):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Card}):Play() end)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(cb)
            if not ok then warn("[EP] " .. tostring(err)); showToast("Error: "..tostring(err), "error") end
        end)
        table.insert(searchIndex, {tab=currentWidgetTab, label=label, card=b})
        return b
    end

    for i, loc in ipairs(CTP_LOCATIONS) do
        ctpGridBtn(ctpGridFrame, i, " " .. loc.Name, function()
            local ok, err = CTP_tpToName(loc.Name)
            if ok then showToast("Car TP → " .. loc.Name, "success")
            else showToast(tostring(err), "warn") end
        end)
    end

    -- Stop Car (panic button)
    Btn(ctpContainer, 5, "Stop Car (kill momentum)", function()
        local car = getCarAndSeat()
        if car then
            for _, p in ipairs(car:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end
            end
            showToast("Car momentum stopped", "success")
        else
            showToast("Not in a car", "warn")
        end
    end, Color3.fromRGB(60, 24, 24))

    -- Sliding toggle button
    local ctpIsOpen = false
    local ctpToggleBtn
    ctpToggleBtn = Btn(P, 21, "Open Car Teleport", function()
        ctpIsOpen = not ctpIsOpen
        ctpToggleBtn.Text = ctpIsOpen and "Close Car Teleport" or "Open Car Teleport"
        local targetSize = ctpIsOpen and UDim2.new(1, -6, 0, ctpContentHeight) or UDim2.new(1, -6, 0, 0)
        TweenService:Create(ctpContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end, Color3.fromRGB(40, 90, 180))

    -- Live status loop
    task.spawn(function()
        while not _G.EP_Unloaded do
            task.wait(0.5)
            pcall(function()
                if not ctpStatus.Parent then return end
                local car = getCarAndSeat()
                if car then
                    ctpStatus.Text = " In car (" .. (car:GetAttribute("Owner") or "?") .. ") — ready"
                    ctpStatus.TextColor3 = Color3.fromRGB(130, 220, 150)
                else
                    ctpStatus.Text = if State.CarTPAutoSpawn
                        then " Not in a car — auto-spawn on TP"
                        else " Not in a car — auto-spawn OFF"
                    ctpStatus.TextColor3 = Color3.fromRGB(255, 200, 100)
                end
            end)
        end
    end)

    _G.EP_CarTP = { snapLoops = CTP_snapLoops, mapGui = CTP_mapGui, pumpkinFarm = PumpkinFarm }
end) -- <--- END OF THE FUNCTION

--============== MOVE TAB ==============
currentWidgetTab = "Move"
P = Tabs.Move.page
Section(P, "Locomotion", 1)
Toggle(P, 2, "Speed Hack", function() return State.SpeedEnabled end, function(v) State.SpeedEnabled = v; showToast("Speed "..(v and "ON" or "OFF"), v and "success" or "info") end)
Slider(P, 3, "Speed", 16, 500, State.SpeedValue, 1, function(v) State.SpeedValue = v end)
Toggle(P, 4, "Jump Power", function() return State.JumpEnabled end, function(v) State.JumpEnabled = v end)
Slider(P, 5, "Jump", 50, 500, State.JumpValue, 5, function(v) State.JumpValue = v end)
Section(P, "Flight & Collision", 10)
Toggle(P, 11, "Fly (Space=up, Shift=down)", function() return State.FlyEnabled end,
    function(v) State.FlyEnabled = v; toggleFly(v); showToast("Fly "..(v and "ON" or "OFF"), v and "success" or "info") end)
Slider(P, 12, "Fly Speed", 16, 500, State.FlySpeed, 1, function(v) State.FlySpeed = v end)
Toggle(P, 13, "Noclip", function() return State.Noclip end, function(v) State.Noclip = v end)
Toggle(P, 14, "Infinite Stamina", function() return State.InfiniteStamina end, function(v) State.InfiniteStamina = v end)

--============== WEAPON TAB ==============
currentWidgetTab = "Weapon"
P = Tabs.Weapon.page
Section(P, "Gun Modifications", 1)
Toggle(P, 2, "Infinite Ammo (999)", function() return State.InfiniteAmmo end, function(v)
    State.InfiniteAmmo = v
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do patchTool(t) end end
    if LP.Backpack then for _, t in ipairs(LP.Backpack:GetChildren()) do patchTool(t) end end
    showToast("Infinite Ammo "..(v and "ON" or "OFF"), v and "success" or "info")
end)
Toggle(P, 3, "No Recoil", function() return State.NoRecoil end, function(v)
    State.NoRecoil = v
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do patchTool(t) end end
    if LP.Backpack then for _, t in ipairs(LP.Backpack:GetChildren()) do patchTool(t) end end
    showToast("No Recoil "..(v and "ON" or "OFF"), v and "success" or "info")
end)
Toggle(P, 4, "Auto Reload When Low", function() return State.AutoReload end, function(v) State.AutoReload = v end)
Section(P, "Info", 10)
local wp = Card(P, 11, 88)
local wpl = Instance.new("TextLabel", wp)
wpl.Size = UDim2.new(1,-20,1,0); wpl.Position = UDim2.fromOffset(12,0)
wpl.BackgroundTransparency = 1; wpl.TextXAlignment = Enum.TextXAlignment.Left
wpl.Font = Enum.Font.Gotham; wpl.TextSize = 11; wpl.TextWrapped = true
wpl.Text = "Auto Fire has been removed to prevent\nserver kicks (Error 267).\n\nPatches apply to every GunSettings module."
onTheme(function() wpl.TextColor3 = Theme.Dim end)

--=================================================================
--  KEYBINDS
--=================================================================
local Keybinds = {
    ToggleGUI = Enum.KeyCode.RightShift, Aim = Enum.KeyCode.Insert,
    ESP = Enum.KeyCode.Delete, Godmode = Enum.KeyCode.End, Minimize = Enum.KeyCode.M,
    AutoEquip = Enum.KeyCode.F, ClickTP = Enum.KeyCode.T,
    JumpTrick = Enum.KeyCode.CapsLock
}
local KeybindLabels = {
    ToggleGUI = "Toggle GUI", Aim = "Toggle Aim", ESP = "Toggle ESP",
    Godmode = "Toggle Godmode", Minimize = "Minimize", AutoEquip = "Toggle Auto Equip",
    ClickTP = "Click Teleport Key",
    JumpTrick = "Car Jump Trick"
}
local KeybindOrder = {"ToggleGUI","Aim","AutoEquip","ESP","Godmode","Minimize","ClickTP","JumpTrick"}
--=================================================================
--  CHEATS TAB (includes Sliding Car Tricks, Tuned Car, etc.)
--=================================================================
currentWidgetTab = "Cheats"
P = Tabs.Cheats.page
task.spawn(function()
-- 1. First, we define the logic so the buttons can use it
local function GetCar()
    local char = LP.Character; if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    local seat = hum.SeatPart
    if seat:IsA("VehicleSeat") then
        local model = seat:FindFirstAncestorOfClass("Model")
        while model do
            if model:HasTag("Car") or model:FindFirstChild("Body") or model:FindFirstChild("Wheels") then return model end
            model = model:FindFirstAncestorOfClass("Model")
        end
    end
    return nil
end

local function ApplyTrick(trickType)
    local car = GetCar()
    if not car then 
        showToast("You must be in a car!", "error")
        return 
    end
    
    local root = car.PrimaryPart or car:FindFirstChild("Collision_Part") or car:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    showToast("Executing " .. trickType .. "...", "success")

    local duration = 0.3
    if trickType == "Nitro Boost" or trickType == "Helicopter" or trickType == "Donut Spin" then duration = 1.5 end
    if trickType == "Hover Mode" or trickType == "Lowrider Bounce" or trickType == "Earthquake" then duration = 2.0 end
    if trickType == "Backwards Launch" or trickType == "Sidestep" then duration = 1.0 end

    -- FIXED: Removed 'TunedCar.Car == car' so it pauses TunedCar 100% of the time.
    -- This guarantees TunedCar will NEVER fight the trick physics.
    local wasTuned = State.TunedCarEnabled and trickType ~= "Jump"
    if wasTuned then
        EP_TrickActive = true
        EP_TrickUntil  = tick() + duration + 0.3
        if TunedCar.BodyVel then TunedCar.BodyVel:Destroy(); TunedCar.BodyVel = nil end
        if TunedCar.BodyAng then TunedCar.BodyAng:Destroy(); TunedCar.BodyAng = nil end
        TunedCar.Car = nil
        TunedCar.Root = nil
    elseif State.TunedCarEnabled and trickType == "Jump" then
        -- If you spam "Jump" after another trick, ensure TunedCar is unpaused so it overrides the jump
        EP_TrickActive = false
    end

    local startTime = tick()
    local connection
    local didOnce = {tp = false, grav = false, wheel = false}

    connection = RunService.RenderStepped:Connect(function()
        if tick() - startTime > duration or not root or not root.Parent then
            if connection then connection:Disconnect() end
            if root and root.Parent then root.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end

            -- Hand control back to TunedCar seamlessly
            if wasTuned then
                EP_TrickActive = false
                if root and root.Parent then
                    local v = root.AssemblyLinearVelocity
                    local l = root.CFrame.LookVector
                    local flat = Vector3.new(l.X, 0, l.Z)
                    
                    if flat.Magnitude > 0.01 then
                        flat = flat.Unit
                        TunedCar.Speed = math.clamp(v:Dot(flat), TunedCar.ReverseSpeed, TunedCar.MaxSpeed)
                    else
                        -- FIXED: If car is pointing straight up/down mid-flip, keep the horizontal momentum
                        local hSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
                        TunedCar.Speed = math.clamp(hSpeed, TunedCar.ReverseSpeed, TunedCar.MaxSpeed)
                    end
                    TunedCar.Turn = 0
                end
            end
            return
        end

        local currentVel = root.AssemblyLinearVelocity
        local look = root.CFrame.LookVector
        local right = root.CFrame.RightVector

        if trickType == "Jump" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 60, currentVel.Z)
        elseif trickType == "Moon Jump" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 200, currentVel.Z)
        elseif trickType == "Frontflip" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 50, currentVel.Z); root.AssemblyAngularVelocity = right * 15
        elseif trickType == "Backflip" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 50, currentVel.Z); root.AssemblyAngularVelocity = right * -15
        elseif trickType == "Sideflip" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 50, currentVel.Z); root.AssemblyAngularVelocity = look * 15
        elseif trickType == "Double Flip" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 80, currentVel.Z); root.AssemblyAngularVelocity = right * 35
        elseif trickType == "Barrel Roll" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 30, currentVel.Z); root.AssemblyAngularVelocity = look * 20 
        elseif trickType == "Nitro Boost" then
            root.AssemblyLinearVelocity = look * 150
        elseif trickType == "Rocket Launch" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 150, currentVel.Z); root.AssemblyAngularVelocity = Vector3.new(0, 15, 0)
        elseif trickType == "Teleport Up" then
            if not didOnce.tp then
                didOnce.tp = true
                root.CFrame = root.CFrame + Vector3.new(0, 100, 0); root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            end
        elseif trickType == "Hover Mode" then
            if tick() - startTime < 1.0 then root.AssemblyLinearVelocity = Vector3.new(0, 30, 0) else root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
        elseif trickType == "Gravity Flip" then
            if not didOnce.grav then
                didOnce.grav = true
                root.CFrame = root.CFrame * CFrame.Angles(0, 0, math.pi)
            end
        elseif trickType == "Donut Spin" then
            root.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0); root.AssemblyAngularVelocity = Vector3.new(0, 15, 0)
        elseif trickType == "Drift Spin" then
            local sideVel = right * 50; root.AssemblyLinearVelocity = Vector3.new(sideVel.X, currentVel.Y, sideVel.Z); root.AssemblyAngularVelocity = Vector3.new(0, -10, 0)
        elseif trickType == "Sidestep" then
            root.AssemblyLinearVelocity = right * 100
        elseif trickType == "Helicopter" then
            root.AssemblyLinearVelocity = Vector3.new(currentVel.X, 30, currentVel.Z); root.AssemblyAngularVelocity = Vector3.new(0, 30, 0)
        elseif trickType == "Wheelie" then
            if not didOnce.wheel then
                didOnce.wheel = true
                root.CFrame = root.CFrame * CFrame.Angles(math.rad(-35), 0, 0)
            end
        elseif trickType == "Lowrider Bounce" then
            local bounce = math.sin(tick() * 15) * 20; root.AssemblyLinearVelocity = Vector3.new(currentVel.X, math.abs(bounce), currentVel.Z)
        elseif trickType == "Earthquake" then
            root.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.abs(math.sin(tick()*20))*10, math.random(-30, 30))
        elseif trickType == "Instant Brake" then
            root.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
        elseif trickType == "Anvil (Slam)" then
            root.AssemblyLinearVelocity = Vector3.new(0, -100, 0)
        elseif trickType == "Backwards Launch" then
            root.AssemblyLinearVelocity = -look * 100
        elseif trickType == "Black Hole" then
            root.AssemblyLinearVelocity = Vector3.new(0, -200, 0)
        end
    end)

    task.delay(duration + 0.05, function()
        if root and root.Parent then root.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end
        -- Failsafe
        if wasTuned and EP_TrickActive and tick() > EP_TrickUntil - 0.05 then
            EP_TrickActive = false
            if root and root.Parent then
                local v = root.AssemblyLinearVelocity
                local l = root.CFrame.LookVector
                local flat = Vector3.new(l.X, 0, l.Z)
                if flat.Magnitude > 0.01 then
                    flat = flat.Unit
                    TunedCar.Speed = math.clamp(v:Dot(flat), TunedCar.ReverseSpeed, TunedCar.MaxSpeed)
                else
                    local hSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
                    TunedCar.Speed = math.clamp(hSpeed, TunedCar.ReverseSpeed, TunedCar.MaxSpeed)
                end
                TunedCar.Turn = 0
            end
        end
    end)
end

-- 2. Build the UI
Section(P, "Visuals & Hitboxes", 1)
Toggle(P, 2, "Fullbright (No Shadows)", function() return State.FullbrightEnabled end, function(v)
    ToggleFullbright()
end)
Toggle(P, 3, "Hitbox Expander (Visible ESP)", function() return State.HitboxEnabled end, function(v)
    State.HitboxEnabled = v
    updateHitbox()
    showToast("Hitbox "..(v and "ON" or "OFF"), "success")
end)
Slider(P, 4, "Hitbox Size", 5, 50, State.HitboxSize, 1, function(v)
    State.HitboxSize = v
    updateHitbox()
end)

Section(P, "Movement", 10)
Toggle(P, 11, "Click Teleport (Press T)", function() return State.ClickTPEnabled end, function(v)
    State.ClickTPEnabled = v
    showToast("Click TP "..(v and "ON" or "OFF"), "success")
end)
Toggle(P, 12, "No Cooldown Jump", function() return State.NoCooldownJump end, function(v)
    State.NoCooldownJump = v
    showToast("Smart Jump "..(v and "ON" or "OFF"), "success")
end)

-- 3. The Sliding Car Tricks Menu
Section(P, "Troll", 15)

local trickList = {
    "Jump", "Moon Jump", "Frontflip", "Backflip", "Sideflip", "Double Flip",
    "Barrel Roll", "Nitro Boost", "Rocket Launch", "Teleport Up", "Hover Mode",
    "Gravity Flip", "Donut Spin", "Drift Spin", "Sidestep", "Helicopter",
    "Wheelie", "Lowrider Bounce", "Earthquake", "Instant Brake", "Anvil (Slam)",
    "Backwards Launch", "Black Hole"
}

-- We calculate exactly how tall the container needs to be (34px per button + 6px padding)
local totalHeight = (#trickList * 34) + ((#trickList - 1) * 6) + 10

-- The hidden container
local trickContainer = Instance.new("Frame", P)
trickContainer.Size = UDim2.new(1, -6, 0, 0) -- Starts closed
trickContainer.BackgroundTransparency = 1
trickContainer.ClipsDescendants = true
trickContainer.LayoutOrder = 17

local trickLayout = Instance.new("UIListLayout", trickContainer)
trickLayout.Padding = UDim.new(0, 6)
trickLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- The button that opens/closes the sliding menu
local isMenuOpen = false
local toggleBtn
toggleBtn = Btn(P, 16, "Open Car Tricks", function()
    isMenuOpen = not isMenuOpen
    
    -- Change text when opened/closed
    toggleBtn.Text = isMenuOpen and "Close Car Tricks" or "Open Car Tricks"
    
    -- Animate the slide effect
    local targetSize = isMenuOpen and UDim2.new(1, -6, 0, totalHeight) or UDim2.new(1, -6, 0, 0)
    TweenService:Create(trickContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end, Color3.fromRGB(40, 60, 90))

-- Populate the sliding container with the tricks
for i, trickName in ipairs(trickList) do
    Btn(trickContainer, i, trickName, function()
        ApplyTrick(trickName)
    end, Color3.fromRGB(40, 60, 90))
end

Section(P, "Vehicle", 50)
Toggle(P, 51, "Tuned Car (274 top speed)",
    function() return State.TunedCarEnabled end,
    function(v)
        State.TunedCarEnabled = v
        if v then showToast("Tuned Car ON - get in a Car", "success")
        else teardownTunedCar(); showToast("Tuned Car OFF", "info") end
    end)

Section(P, "World", 60)
Btn(P, 61, "Delete All Gates & Barriers", function()
    local n = deleteAllGates(); showToast("Deleted "..n.." gates/barriers", "success")
end, Color3.fromRGB(60,24,24))

Section(P, "Map", 70)
Btn(P, 71, "💥 Delete Map (keep yourself)", function()
    if MapDeleted then showToast("Map is already deleted", "warn"); return end
    DeleteMap()
    showToast("Map deleted — " .. #DeletedParts .. " objects hidden", "success")
end, Color3.fromRGB(80, 30, 30))

Btn(P, 72, "✨ Restore Map", function()
    if not MapDeleted then showToast("Nothing to restore", "warn"); return end
    RestoreMap()
    showToast("Restoring map in chunks...", "success")
end, Color3.fromRGB(30, 80, 40))
end)
--=================================================================
--  MISC TAB (now LAST tab)
--=================================================================
currentWidgetTab = "Misc"
P = Tabs.Misc.page
task.spawn(function()

Section(P, "Appearance", 1)
local themeCard = Card(P, 2, 70)
local themeGrid = Instance.new("Frame", themeCard)
themeGrid.Size = UDim2.new(1,-16,1,0); themeGrid.Position = UDim2.fromOffset(8,0)
themeGrid.BackgroundTransparency = 1
local tLayout = Instance.new("UIListLayout", themeGrid)
tLayout.FillDirection = Enum.FillDirection.Horizontal; tLayout.Padding = UDim.new(0,6)
tLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local themeButtons = {}
for _, name in ipairs(ThemeOrder) do
    local t = Themes[name]
    local b = Instance.new("TextButton", themeGrid)
    b.Size = UDim2.fromOffset(68,46); b.BackgroundColor3 = t.BG
    b.Text = ""; b.BorderSizePixel = 0; b.AutoButtonColor = false
    b.ClipsDescendants = true; b.ZIndex = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = t.Accent; stroke.Thickness = 2
    stroke.Transparency = (CurrentThemeName == name) and 0 or 1
    local dot = Instance.new("Frame", b)
    dot.Size = UDim2.fromOffset(14,14); dot.Position = UDim2.new(0.5,-7,0.35,-7)
    dot.BackgroundColor3 = t.Accent; dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local lbl = Instance.new("TextLabel", b)
    lbl.Size = UDim2.new(1,0,0,12); lbl.Position = UDim2.new(0,0,1,-16)
    lbl.BackgroundTransparency = 1; lbl.Text = t.Name
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 8; lbl.TextColor3 = t.Text
    addRipple(b)
    b.MouseButton1Click:Connect(function()
        for k,v in pairs(Themes[name]) do Theme[k]=v end
        CurrentThemeName = name
        for _, fn in ipairs(themeAppliers) do pcall(fn) end
        for n, btn in pairs(themeButtons) do
            local s = btn:FindFirstChildOfClass("UIStroke")
            if s then s.Transparency = (n == name) and 0 or 1 end
        end
        showToast("Theme: "..Themes[name].Name, "success")
    end)
    themeButtons[name] = b
end

Section(P, "Layout", 3)
Toggle(P, 4, "Portrait Mode",
    function() return PortraitMode end,
    function(v)
        applyLayout(v and "portrait" or "landscape", true)  -- true = animate
        if SearchBox then SearchBox.Text = "" end
        showToast("Layout: " .. (v and "Portrait" or "Landscape"), "success")
    end)

Section(P, "Godmode", 5)
Toggle(P, 6, "Godmode (Health = Max)", function() return State.Godmode end,
    function(v) State.Godmode = v; if v then enableGodmode(LP.Character) end; showToast("Godmode "..(v and "ON" or "OFF"), v and "success" or "info") end)
Toggle(P, 7, "Anti-Ragdoll", function() return State.AntiRagdoll end, function(v) State.AntiRagdoll = v end)
Toggle(P, 8, "Anti-Arrest (clears Detained)", function() return State.AntiArrest end, function(v) State.AntiArrest = v end)

Section(P, "Keybinds", 11)
local keybindButtons = {}
local waitingForKeybind = nil
local function updateKeybindUI()
    for action, btn in pairs(keybindButtons) do
        if Keybinds[action] then btn.Text = Keybinds[action].Name end
    end
end
local kbOrder = 12
for _, action in ipairs(KeybindOrder) do
    local c = Card(P, kbOrder, 34); kbOrder = kbOrder + 1
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.6,0,1,0); l.Position = UDim2.fromOffset(14,0)
    l.BackgroundTransparency = 1; l.Text = KeybindLabels[action]
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    onTheme(function() l.TextColor3 = Theme.Text end)
    local btn = Instance.new("TextButton", c)
    btn.Size = UDim2.new(0.36,-14,0,22); btn.Position = UDim2.new(0.62,0,0.5,-11)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    btn.Text = Keybinds[action].Name
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local s = Instance.new("UIStroke", btn); s.Thickness = 1
    onTheme(function() btn.BackgroundColor3 = Theme.Panel2; btn.TextColor3 = Theme.Accent; s.Color = Theme.Border end)
    btn.MouseButton1Click:Connect(function()
        waitingForKeybind = action; btn.Text = "Press a key..."
        showToast("Press a key to bind ("..KeybindLabels[action]..")", "info")
    end)
    keybindButtons[action] = btn
    table.insert(searchIndex, {tab="Misc", label="Keybind: "..KeybindLabels[action], card=c})
end
Btn(P, kbOrder, "Reset Keybinds to Default", function()
    Keybinds.ToggleGUI = Enum.KeyCode.RightShift
    Keybinds.Aim = Enum.KeyCode.Insert
    Keybinds.ESP = Enum.KeyCode.Delete
    Keybinds.Godmode = Enum.KeyCode.End
    Keybinds.Minimize = Enum.KeyCode.M
    Keybinds.AutoEquip = Enum.KeyCode.F
    Keybinds.ClickTP = Enum.KeyCode.T
    Keybinds.JumpTrick = Enum.KeyCode.CapsLock
    updateKeybindUI(); showToast("Keybinds reset", "success")
end)

Section(P, "Teleports", 25)
Btn(P, 26, "Teleport -> Selected Target", function()
    local t = State.Target
    if not t or not t.Character then showToast("No target", "warn"); return end
    local th = t.Character:FindFirstChild("HumanoidRootPart")
    if th then
        if safeTeleport(th.CFrame * CFrame.new(0,0,3)) then showToast("Teleported to "..t.Name, "success") end
    end
end)
Btn(P, 27, "Teleport -> Nearest Criminal", function()
    local best, bestD
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then showToast("No character", "warn"); return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and getRole(plr) == "Criminal" then
            local c = plr.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - myRoot.Position).Magnitude
                if not bestD or d < bestD then best, bestD = hrp, d end
            end
        end
    end
    if best then
        if safeTeleport(best.CFrame * CFrame.new(0,0,3)) then showToast("Teleported to nearest criminal", "success") end
    else showToast("No criminal found", "warn") end
end)

Section(P, "Waypoints", 30)
local wpButtons = {
    {"Bank","Bank"}, {"Jewelry","Jewelry"}, {"Laundromat","Laundromat"},
    {"Black Market","BlackMarket"}, {"Goods (Sell)","Goods"}, {"Containers","Containers"},
}
local wpOrder = 31
for _, pair in ipairs(wpButtons) do
    local label, target = pair[1], pair[2]
    Btn(P, wpOrder, "Teleport -> "..label, function()
        local wp = workspace:FindFirstChild("_MapWaypoints_")
        local part = wp and wp:FindFirstChild(target)
        if part then
            if safeTeleport(part.CFrame * CFrame.new(0,3,0)) then
                showToast("Teleported to "..label, "success")
            end
        else
            showToast("Waypoint '"..target.."' not found", "warn")
        end
    end)
    wpOrder = wpOrder + 1
end

Section(P, "Info", 40)
Btn(P, 41, "Print My Role & Team", function()
    showToast("You: "..getMyRole().." • "..(LP.Team and LP.Team.Name or "?"), "info")
end)
Btn(P, 42, "Dump All Players", function()
    for _, plr in ipairs(Players:GetPlayers()) do
        local role, team = getRole(plr)
        print(("[EP] %s -> %s (%s)"):format(plr.Name, role, team))
    end
    showToast("Dumped all players to console", "info")
end)

Section(P, "Credits", 44)
local creditCard = Card(P, 45, 34)
local creditLbl = Instance.new("TextLabel", creditCard)
creditLbl.Size = UDim2.new(1,-20,1,0); creditLbl.Position = UDim2.fromOffset(12,0)
creditLbl.BackgroundTransparency = 1; creditLbl.TextXAlignment = Enum.TextXAlignment.Left
creditLbl.Font = Enum.Font.GothamMedium; creditLbl.TextSize = 11
creditLbl.Text = "Made by selever_el  •  v4.1  •  Landscape Edition"
onTheme(function() creditLbl.TextColor3 = Theme.Dim end)

Section(P, "Unload", 50)
Btn(P, 51, "Unload Script", function()
    _G.EP_Unloaded = true

    -- 1. Kill state flags FIRST so any still-alive loops no-op
    State.ESPEnabled = false
    State.AimEnabled = false
    State.AimAutoEquip = false
    State.Godmode = false
    State.AntiRagdoll = false
    State.AntiArrest = false
    State.SpeedEnabled = false
    State.JumpEnabled = false
    State.FlyEnabled = false
    State.Noclip = false
    State.InfiniteStamina = false
    State.InfiniteAmmo = false
    State.NoRecoil = false
    State.AutoReload = false
    State.AutoDaily = false
    State.AutoLaunder = false
    State.AutoTruck = false
    State.AutoATM = false
    State.TunedCarEnabled = false
    local wasFullbright = State.FullbrightEnabled
    State.FullbrightEnabled = false
    State.HitboxEnabled = false
    State.ClickTPEnabled = false
    State.NoCooldownJump = false

    -- 2. Disconnect input handlers so keybinds stop firing
    pcall(function() if MainKeybindConn then MainKeybindConn:Disconnect() end end)
    pcall(function() if ClickTPConn then ClickTPConn:Disconnect() end end)
    pcall(function() if NoCDJumpConn then NoCDJumpConn:Disconnect() end end)

    -- 3. Clean up visuals / physics
    for plr in pairs(State.ESPData) do destroyESP(plr) end
    pcall(function() toggleFly(false) end)
    pcall(teardownTunedCar)
    pcall(updateHitbox)
    if _G.EP_CarTP and _G.EP_CarTP.pumpkinFarm then
        _G.EP_CarTP.pumpkinFarm.Active = false
    end
    if _G.EP_CarTP then
        for _car, tok in pairs(_G.EP_CarTP.snapLoops) do tok.Cancelled = true end
        table.clear(_G.EP_CarTP.snapLoops)
        if _G.EP_CarTP.mapGui and _G.EP_CarTP.mapGui.Parent then
            pcall(function() _G.EP_CarTP.mapGui:Destroy() end)
        end
    end
    if wasFullbright then
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end

     -- 4. Nuke GUI
    if HiddenFolder and HiddenFolder.Parent then HiddenFolder:Destroy() end
    Gui:Destroy()
    _G.EP_Loaded = false
end, Color3.fromRGB(60,24,24))
end) -- <--- ADD THIS

--=================================================================
--  SEARCH FUNCTION
--=================================================================
local function performSearch(query)
    for _, ch in ipairs(SearchResults:GetChildren()) do
        if ch:IsA("TextButton") or ch:IsA("Frame") then ch:Destroy() end
    end
    query = tostring(query):lower():gsub("^%s+",""):gsub("%s+$","")
    local cfg = LayoutConfig[PortraitMode and "portrait" or "landscape"]
    if query == "" then
        TabBar.Visible = true; Pages.Visible = true; SearchResults.Visible = false
        SearchResults.Position = cfg.SearchPos
        SearchResults.Size = cfg.SearchSize
        return
    end
    TabBar.Visible = false; Pages.Visible = false; SearchResults.Visible = true
    SearchResults.Position = cfg.SearchFullPos
    SearchResults.Size = cfg.SearchFullSize
    local matches = {}
    for _, entry in ipairs(searchIndex) do
        if entry.label:lower():find(query, 1, true) or entry.tab:lower():find(query, 1, true) then
            table.insert(matches, entry)
        end
    end
    if #matches == 0 then
        local empty = Instance.new("Frame", SearchResults)
        empty.Size = UDim2.new(1,-6,0,60); empty.BackgroundTransparency = 1
        local lbl = Instance.new("TextLabel", empty)
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = "No matches for \""..query.."\""
        lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
        onTheme(function() lbl.TextColor3 = Theme.Dim end)
        return
    end
    for i, entry in ipairs(matches) do
        local row = Instance.new("TextButton", SearchResults)
        row.Size = UDim2.new(1,-6,0,34); row.BackgroundColor3 = Theme.Card
        row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Text = ""
        row.LayoutOrder = i; row.ZIndex = 101
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Thickness = 1; rowStroke.Transparency = 0.4
        onTheme(function() row.BackgroundColor3 = Theme.Card; rowStroke.Color = Theme.Border end)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1,-100,1,0); lbl.Position = UDim2.fromOffset(14,0)
        lbl.BackgroundTransparency = 1; lbl.Text = entry.label
        lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        onTheme(function() lbl.TextColor3 = Theme.Text end)
        
        local tabLbl = Instance.new("TextLabel", row)
        tabLbl.Size = UDim2.new(0, 80, 1, 0); tabLbl.AnchorPoint = Vector2.new(1, 0)
        tabLbl.Position = UDim2.new(1, -14, 0, 0)
        tabLbl.TextYAlignment = Enum.TextYAlignment.Center
        tabLbl.BackgroundTransparency = 1; tabLbl.Text = entry.tab
        tabLbl.Font = Enum.Font.GothamBold; tabLbl.TextSize = 10
        tabLbl.TextXAlignment = Enum.TextXAlignment.Right
        onTheme(function() tabLbl.TextColor3 = Theme.Dim end)
        row.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3=Theme.CardHover}):Play() end)
        row.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3=Theme.Card}):Play() end)
        row.MouseButton1Click:Connect(function()
            local tabName = entry.tab; local card = entry.card
            SearchBox.Text = ""
            SelectTab(tabName)
            task.delay(0.25, function()
                local scroll = Tabs[tabName].page
                if scroll and card then
                    pcall(function()
                        local target = math.max(0, card.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 60)
                        scroll.CanvasPosition = Vector2.new(0, target)
                    end)
                end
            end)
            showToast("Jumped to: "..entry.label, "info")
        end)
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(function() performSearch(SearchBox.Text) end)

--=================================================================
--  MAIN KEYBIND HANDLER
--=================================================================
MainKeybindConn = UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if waitingForKeybind then
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingForKeybind = nil; updateKeybindUI()
            showToast("Keybind cancelled", "info"); return
        end
        if UIS:GetFocusedTextBox() then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local action = waitingForKeybind
            local newKey = input.KeyCode

            -- Loop through all keybinds and remove this key if another action is using it
            for act, key in pairs(Keybinds) do
                if key == newKey and act ~= action then
                    Keybinds[act] = Enum.KeyCode.Unknown -- Unbind the old action
                end
            end

            Keybinds[action] = newKey
            waitingForKeybind = nil; updateKeybindUI()
            showToast("Bound "..newKey.Name.." to "..KeybindLabels[action], "success")
        end
        return
    end
    if UIS:GetFocusedTextBox() then return end

    if input.KeyCode == Keybinds.ToggleGUI then
        if not Gui.Enabled then
            Gui.Enabled = true
            rootScale.Scale = 0.9
            TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
        else
            SearchBox.Text = ""
            Gui.Enabled = false
        end

    elseif input.KeyCode == Keybinds.Aim then
        State.AimEnabled = not State.AimEnabled; refreshAll()
        showToast("Aim "..(State.AimEnabled and "ON" or "OFF"), State.AimEnabled and "success" or "info")

    elseif input.KeyCode == Keybinds.AutoEquip then
        State.AimAutoEquip = not State.AimAutoEquip; refreshAll()
        if not State.AimAutoEquip then unequipGun() end
        showToast("Auto Equip "..(State.AimAutoEquip and "ON" or "OFF"), State.AimAutoEquip and "success" or "info")

    elseif input.KeyCode == Keybinds.ESP then
        State.ESPEnabled = not State.ESPEnabled; rebuildESP(); refreshAll()
        showToast("ESP "..(State.ESPEnabled and "ON" or "OFF"), State.ESPEnabled and "success" or "info")

    elseif input.KeyCode == Keybinds.Godmode then
        State.Godmode = not State.Godmode
        if State.Godmode then enableGodmode(LP.Character) end
        refreshAll()
        showToast("Godmode "..(State.Godmode and "ON" or "OFF"), State.Godmode and "success" or "info")
    elseif input.KeyCode == Keybinds.JumpTrick then
        pcall(ApplyTrick, "Jump")

    elseif input.KeyCode == Keybinds.Minimize then
        if minimized then restore() else minimize() end
    end
end)

--=================================================================
--  MOBILE HINT (bottom-left)
--=================================================================
do
    local hint = Instance.new("TextLabel", Gui)
    hint.Name = "EP_Hint"
    hint.Size = UDim2.fromOffset(220, 24)
    hint.Position = UDim2.new(0, 20, 1, -18)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.GothamMedium
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextColor3 = Theme.Dim
    hint.TextTransparency = 0.3
    hint.Text = "RightShift = Toggle GUI   •   M = Minimize"
    hint.ZIndex = 5
    onTheme(function() hint.TextColor3 = Theme.Dim end)
    task.delay(8, function()
        if hint and hint.Parent then
            TweenService:Create(hint, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {TextTransparency = 1}):Play()
            task.delay(1.6, function() if hint and hint.Parent then hint:Destroy() end end)
        end
    end)
end

-- Cleanup function for when the script is re-executed without using the Unload button
_G.EP_Unload = function()
    _G.EP_Unloaded = true
    pcall(function() if MainKeybindConn then MainKeybindConn:Disconnect() end end)
    pcall(function() if ClickTPConn then ClickTPConn:Disconnect() end end)
    pcall(function() if NoCDJumpConn then NoCDJumpConn:Disconnect() end end)
    pcall(teardownTunedCar)
    pcall(function() toggleFly(false) end)
    if _G.EP_CarTP then
        for _car, tok in pairs(_G.EP_CarTP.snapLoops) do tok.Cancelled = true end
        table.clear(_G.EP_CarTP.snapLoops)
        if _G.EP_CarTP.mapGui and _G.EP_CarTP.mapGui.Parent then
            pcall(function() _G.EP_CarTP.mapGui:Destroy() end)
        end
    end
end

print("[EL PASO] v4.1 · Landscape Edition loaded · Theme: " .. Theme.Name)
