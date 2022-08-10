--[[
    BackportSniper

    Supported Champions:

    - Jinx
    - Ezreal
]]

module("BSniper", package.seeall, log.setup)
clean.module("BSniper", package.seeall, log.setup)



local debugging = false
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local Menu = Libs.NewMenu
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local SpellLib = Libs.Spell
local HealthPrediction = Libs.HealthPred
local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local SpellSlots = Enums.SpellSlots
local Events = Enums.Events
local Player = ObjectManager.Player.AsHero
local ScriptVersion = "0.7.0"
local ScriptLastUpdate = "August 10. 2022"
local champ = nil
local Renderer = CoreEx.Renderer
local ultTime = 0
local ultEnemy = ""

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BackportSniper.lua", ScriptVersion)


function checkChampions(list)

    local championName = Player.CharName

    for index, value in ipairs(list) do
        if championName == value then
            champ = value
            return championName
        end
    end

    return false

end

function MGet(string)
    return Menu.Get(string)
end

if not checkChampions({ "Jinx", "Ezreal" }) then return false end

-- Globals
local Enemies = {}
local Jinx = {}
local Ezreal = {}
local Sniper = {}

-- Spells
Jinx.R = SpellLib.Skillshot({
    Slot = SpellSlots.R,
    Range = math.huge,
    Speed = 1700,
    Delay = 0.6,
    Radius = 140,
    Type = "Linear",
    UseHitbox = true,
    Collisions = {
        Heroes = true,
        WindWall = true
    }
})
Ezreal.R = SpellLib.Skillshot({
    Slot = SpellSlots.R,
    Delay = 1,
    Speed = 2000,
    Radius = 160,
    Type = "Linear",
    Collisions = { WindWall = true },
    UseHitbox = true
})

function GetJinxRDmg(enemy, distance, health)
    local dmgDist = math.floor(math.floor(distance) / 100)
    local rLevel = Jinx.R:GetLevel()
    local baseDmg = ({ 250, 400, 550 })[rLevel] + (1.5 * Player.BonusAD)
    local dmg = ({ 0.25, 0.3, 0.35 })[rLevel] * (enemy.MaxHealth - health)
    if distance >= 1500 then
        dmg = dmg + baseDmg
    else
        dmg = dmg + (((10 + (6 * dmgDist)) * baseDmg) / 100)
    end
    return DamageLib.CalculatePhysicalDamage(Player, enemy, dmg)
end

function GetEzrealRDmg(enemy, distance, health)

    return DamageLib.CalculateMagicalDamage(Player, enemy, 200 + Ezreal.R:GetLevel() * 150) + (1.0 * Player.BonusAD) + (0.90 * Player.TotalAP)
end

function JinxCanKill(enemy, extraHP, buffer)
    local distanceToHit = Player:Distance(enemy.Position)
    local timeToHit = Jinx.R.Delay + distanceToHit / Jinx.R.Speed
    local healthPredicted = { HealthPrediction.GetKillstealHealth(enemy, timeToHit) }
    local dmg = GetJinxRDmg(enemy, distanceToHit, healthPredicted[1])

    return (healthPredicted[1] > 0) and (dmg > healthPredicted[1] + MGet("SnipeBuffer") + extraHP)
end

function EzrealCanKill(enemy, extraHP, buffer)
    local distanceToHit = Player:Distance(enemy.Position)
    local timeToHit = Ezreal.R.Delay + distanceToHit / Ezreal.R.Speed
    local healthPredicted = { HealthPrediction.GetKillstealHealth(enemy, timeToHit) }
    local dmg = GetEzrealRDmg(enemy, distanceToHit, healthPredicted[1])

    return (healthPredicted[1] > 0) and (dmg > healthPredicted[1] + MGet("SnipeBuffer") + extraHP)
end

function HasUnwantedBuffs(obj)

    -- Enemy Buffs
    local buffs = obj.Buffs

    -- Check for passives that we might not want to ult
    for index, value in ipairs(buffs) do
        if MGet("RBPAniviaCheck") then
            if value.Name == "rebirthready" then return true end
        end
        if MGet("RBPZacCheck") then
            if value.Name == "zacrebirthready" then return true end
        end
    end

    return false -- No unwanted buffs found

end

function IsColliding(obj, radius, speed, travelTime, blockedByYasuoWall, ignoreUnits)

    if blockedByYasuoWall then
        local windWallCollision = CollisionLib.SearchYasuoWall(Player.Position, obj.Position, radius * 2, speed, travelTime, 1, "enemy")
        if windWallCollision.Result == true then return true end
    end


    if ignoreUnits then return false end

    local collisionResult = CollisionLib.SearchHeroes(Player.Position, obj.Position, radius * 2, speed, travelTime, 1, "enemy", nil)
    for key, value in pairs(collisionResult.Objects) do
        if value.CharName ~= obj.CharName then
            return true
        end
    end

    return false
end

function round(number, decimals)
    local power = 10 ^ decimals
    return math.floor(number * power) / power
end

function IsTooCloseToEnemy()

    if MGet("RIsEnemyCloseSafetyCheck") then
        for index, value in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Player:Distance(value) < 600 then
                return true
            end
        end
    end

    return false

end

function SetValues(obj)
    for key, value in pairs(Enemies) do
        if value.char == obj.CharName then
            return { value.lastSeenTime, value.hpregen }
        end
    end
end

function IsAllyRecalling(obj)
    if obj.IsAlly then return true end
    return false
end

function IsObvious(distance, obj)



    if not MGet("RBPAntiObvious") then return false end
    local enemyMinions = ObjectManager.Get("enemy", "minions")
    local enemyHeroes = ObjectManager.Get("enemy", "heroes")


    -- check vision for minions
    for index, value in pairs(enemyMinions) do
        if Player:Distance(value.Position) <= 1100 then
            if Player.Position:IsGrass() and not value.Position:IsGrass() then goto next end
            if CollisionLib.SearchWall(Player.Position, value.Position, value.BoundingRadius, value.MoveSpeed, 0).Result then goto next end
            if distance < 3000 then
                return true
            end
            ::next::
        end
    end

    --  check vision for enemy heroes
    for index, value in pairs(enemyHeroes) do
        if Player:Distance(value.Position) <= 1200 then
            if Player.Position:IsGrass() and not value.Position:IsGrass() then goto next2 end
            if CollisionLib.SearchWall(Player.Position, value.Position, value.BoundingRadius, value.MoveSpeed, 0).Result then goto next2 end
            if distance < 3000 then
                return true
            end
            ::next2::
        end
    end

    -- check vision for target
    if distance <= 1200 then
        if Player.Position:IsGrass() and not obj.Position:IsGrass() then return false end
        if CollisionLib.SearchWall(Player.Position, obj.Position, obj.BoundingRadius, obj.MoveSpeed, 0).Result then return false end
        return true
    end
    return false

end

function CantCastSpell()
    if champ == "Jinx" then if not Jinx.R:IsReady() then return true end end

    return false
end

---@param obj AIHeroClient
function Sniper.OnVisionLost(obj)
    if obj.IsHero then
        for key, hero in pairs(Enemies) do
            if obj.CharName == hero.char then
                Enemies[key].hpregen = obj.HealthRegen
                Enemies[key].lastSeenTime = Game.GetTime()
            end
        end
    end

    if debugging then
        INFO("Enemy HP OnVisionLost = " .. obj.Health)
    end
end

---@param obj AIHeroClient
function Sniper.OnVisionGain(obj)
    if obj.IsHero then
        for key, hero in pairs(Enemies) do
            if obj.CharName == hero.char then
                Enemies[key].hpregen = obj.HealthRegen

                if debugging then
                    INFO("Enemy HP OnVisionGain = " .. obj.Health)
                end
            end
        end
    end
end

function Sniper.OnTeleport(obj, name, duration_secs, status)

    if obj.IsAlly then return end
    if status == "Interrupted" then ultTime = 0 end
    local distance = Player:EdgeDistance(obj.Position)
    if not MGet("ROnBackport") then return end
    if not MGet("RBP" .. obj.CharName) then return end
    if CantCastSpell() then return end
    if IsAllyRecalling(obj) then return end
    if IsTooCloseToEnemy() then return end
    if MGet("BadBuffCheck") and HasUnwantedBuffs(obj) then return end
    if IsObvious(distance, obj) then return end


    local enemyLastSeen, hpregen = SetValues(obj)[1], SetValues(obj)[2]


    if champ == "Jinx" then
        -- Speed and time calculations

        Jinx.R.Speed = distance > 1300 and (1300 * 1700 + ((distance - 1300) * 2200)) / distance or 1700
        local totalTime = (Game.GetTime() - enemyLastSeen) + (distance / Jinx.R.Speed) + Jinx.R.Delay
        local travelTime = (distance / Jinx.R.Speed) + Jinx.R.Delay

        -- Collision checks
        if IsColliding(obj, Jinx.R.Radius, Jinx.R.Speed, travelTime, true) then return end


        if travelTime > duration_secs then return false end
        if status ~= "Started" then return false end
        if MGet("RColTimeMax") < totalTime then return false end


        if JinxCanKill(obj, hpregen * totalTime) then
            local alliesNearTarget = 0

            for key, value in pairs(ObjectManager.Get("ally", "heroes")) do
                if not value.IsMe then
                    if value:Distance(obj.Position) < 1500 then
                        alliesNearTarget = alliesNearTarget + 1
                    end
                end
            end

            if alliesNearTarget > 0 then
                if MGet("RBPAllycheck") then
                    return true
                end
            end



            if debugging then INFO("Delay = " .. delayTime) end


            if MGet("RBPDelay") then
                local delayTime = 7.5 - travelTime + Game.GetLatency() / 1000
                ultTime = Game.GetTime() + delayTime
                ultEnemy = obj.CharName
                delay(delayTime * 1000, function()
                    if obj.IsRecalling then
                        return Input.Cast(SpellSlots.R, obj.Position)
                    end
                end)
            else
                Input.Cast(SpellSlots.R, obj.Position)
            end
        end
    end

    if champ == "Ezreal" then
        -- Speed and time calculations
        local totalTime = (Game.GetTime() - enemyLastSeen) + (distance / Ezreal.R.Speed) + Ezreal.R.Delay
        local travelTime = (distance / Ezreal.R.Speed) + Ezreal.R.Delay

        -- Collision checks
        if IsColliding(obj, Ezreal.R.Radius, Ezreal.R.Speed, travelTime, true, true) then return end


        if travelTime > duration_secs then return false end
        if status ~= "Started" then return false end
        if MGet("RColTimeMax") < totalTime then return false end


        if EzrealCanKill(obj, hpregen * totalTime) then
            local alliesNearTarget = 0

            for key, value in pairs(ObjectManager.Get("ally", "heroes")) do
                if not value.IsMe then
                    if value:Distance(obj.Position) < 1500 then
                        alliesNearTarget = alliesNearTarget + 1
                    end
                end
            end

            if alliesNearTarget > 0 then
                if MGet("RBPAllycheck") then
                    return true
                end
            end


            if debugging then INFO("Delay = " .. delayTime) end


            if MGet("RBPDelay") then

                local delayTime = 7.5 - travelTime + Game.GetLatency() / 1000
                ultTime = Game.GetTime() + delayTime
                ultEnemy = obj.CharName

                delay(delayTime * 1000, function()
                    if obj.IsRecalling then
                        
                        return Input.Cast(SpellSlots.R, obj.Position)
                    end
                end)
            else
                Input.Cast(SpellSlots.R, obj.Position)
            end


        end
    end


end

function Sniper.OnDraw()

    if MGet("ROnBackport") then
        Renderer.DrawTextOnPlayer("BP Sniper ON", 0x2FBD09FF)
    else
        Renderer.DrawTextOnPlayer("BP Sniper OFF", 0xFF4D4DFF)
    end

    if ultTime == 0 then return end
    if ultEnemy == "" then return end

    if ultTime > Game.GetTime() then
        Renderer.DrawTextOnPlayer("Sniping " .. ultEnemy .. " in .. " .. round(ultTime - Game.GetTime(), 2), 0xFF4D4DFF)
    end


end

function GetMenuColor(id)
    local isOn = MGet(id)

    if isOn then
        return 0x2FBD09FF
    else
        return 0xFF4D4DFF
    end

end

function SmartCheckbox(id, text, default)
    Menu.Checkbox(id, "", default or true)
    Menu.SameLine()
    Menu.ColoredText(text, GetMenuColor(id))
end

function MenuDivider(color, sym, am)
    local DivColor = color or 0xEFC347FF
    local string = ""
    local amount = 166 or am
    local symbol = sym or "="

    for i = 1, 166 do
        string = string .. symbol
    end

    return Menu.ColoredText(string, DivColor, true)
end

function Sniper.LoadMenu()
    Menu.RegisterMenu("BPSniper", "Backport Sniper", function()
        Menu.Separator("Backport Sniper")
        Menu.Keybind("ROnBackport", "Enable Backport Sniper", string.byte("Y"), true, true)
        Menu.Checkbox("RBPAllycheck", "Don't cast if an ally is near the target")
        Menu.Checkbox("RIsEnemyCloseSafetyCheck", "Don't cast if an enemy is close to you", false)
        Menu.Checkbox("BadBuffCheck", "Don't cast if target has Anivia or Zac passive", false)
        Menu.Checkbox("RBPDelay", "Delay cast so it hits the enemy right before recall is finished")
        Menu.Checkbox("RBPAntiObvious", "Anti obvious")
	Menu.Separator("Made By Roburppey")
        Menu.Slider("RColTimeMax", "Max time between last seen", 12, 5, 20, 1)
        Menu.Slider("SnipeBuffer", "Account for extra HP", 0, 0, 400, 10)
        Menu.NewTree("RBPWhitelist", "Snipe Whitelist", function()
            for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                local Name = Object.AsHero.CharName
                Menu.Checkbox("RBP" .. Name, "Snipe " .. Name, true)
            end
        end)

    end)

end

function OnLoad()

    Sniper.LoadMenu()
    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
        local Name = Object.AsHero.CharName
        table.insert(Enemies, { char = Name, hpregen = 1, lastSeenTime = 0, lastSeenPos = nil })
    end
    for EventName, EventId in pairs(Events) do
        if Sniper[EventName] then
            EventManager.RegisterCallback(EventId, Sniper[EventName])
        end
    end

    return true
end
