--[[
    BigVelkoz
]]
module("Velkoz", package.seeall, log.setup)
clean.module("Velkoz", package.seeall, log.setup)



-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local DamageLib = Libs.DamageLib
local SpellLib = Libs.Spell
local TS = Libs.TargetSelector()
local HealthPrediction = Libs.HealthPred
local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer
local Evade = _G.CoreEx.EvadeAPI
local SpellSlots = Enums.SpellSlots
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing",
    "Immobile" }
local lastETime = 0
local Player = ObjectManager.Player.AsHero
local ScriptVersion = "1.0.0"
local ScriptLastUpdate = "16. April 2022"
local VelQ = nil
local VelQCreatePos = nil
local Colorblind = false
local text = "Enable"
local Nav = _G.CoreEx.Nav
local Prediction = _G.Libs.Prediction

if Player.CharName ~= "Velkoz" then
    return false
end

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigVelkoz.lua", ScriptVersion)

-- Globals
---@class AIHeroClient
local Velkoz = {}
local Utils = {}

Velkoz.TargetSelector = nil
Velkoz.Logic = {}

local UsableSS = {
    Ignite = {
        Slot = nil,
        Range = 600
    },
    Flash = {
        Slot = nil,
        Range = 400
    }
}

-- ██████╗░██████╗░██╗░░░░░██╗██████╗░
-- ██╔══██╗██╔══██╗██║░░░░░██║██╔══██╗
-- ██████╔╝██████╦╝██║░░░░░██║██████╦╝
-- ██╔══██╗██╔══██╗██║░░░░░██║██╔══██╗
-- ██║░░██║██████╦╝███████╗██║██████╦╝
-- ╚═╝░░╚═╝╚═════╝░╚══════╝╚═╝╚═════╝░

-- A curation of useful functions.

local RB = {}

--- Gets the cast position that will hit the most minions
---@param minions table
---@param Width integer
---@param Range integer
---@param minimumHitcount integer
---@return Vector
function RB.GetBestLinearFarmPosition(minions, Width, Range, minimumHitcount)
    if #minions == 0 then
        return nil
    end

    local pPos, pointsW = Player.Position, {}

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            local pos = minion.Position
            if pos:Distance(pPos) < 500 and minion.IsTargetable then
                table.insert(pointsW, pos)
            end
        end
    end

    if #pointsW == 0 then
        return nil
    end
    local bestPos, hitCount = Vi.ClearQ:GetBestLinearCastPos(pointsW, Vi.ClearQ.Radius)

    return bestPos, hitCount
end

function RB.ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 and not minion.IsDead
end

function RB.IsGameAvailable()
    -- Is game available to automate stuff
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead)
end

function RB.CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjectManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end

function RB.IsInRange(From, To, Min, Max)
    -- Is Target in range
    local Distance = From:Distance(To)
    return Distance > Min and Distance <= Max
end

function RB.GetBoundingRadius(Target)
    if not Target then
        return 0
    end

    -- Bounding boxes
    return Player.BoundingRadius + Target.BoundingRadius
end

function RB.IsValidTarget(Target)
    return Target and Target.IsTargetable and Target.IsAlive
end

function RB.IsCasting()
    local spell = Player.ActiveSpell

    if spell then
        if spell.Name == "VelkozLightBinding" then
            return true
        end
        if spell.Name == "VelkozLightStrikeKugel" then
            return true
        end
    end

    return false
end

function RB.GetLudensSlot()
    local slot = 100

    if Player.Items[0] ~= nil then
        if Player.Items[0].ItemId == 6655 then
            slot = 6
        end
    end

    if Player.Items[1] ~= nil then
        if Player.Items[1].ItemId == 6655 then
            slot = 7
        end
    end

    if Player.Items[2] ~= nil then
        if Player.Items[2].ItemId == 6655 then
            slot = 8
        end
    end

    if Player.Items[3] ~= nil then
        if Player.Items[3].ItemId == 6655 then
            slot = 9
        end
    end

    if Player.Items[4] ~= nil then
        if Player.Items[4].ItemId == 6655 then
            slot = 10
        end
    end

    if Player.Items[5] ~= nil then
        if Player.Items[5].ItemId == 6655 then
            slot = 11
        end
    end

    return slot
end

function RB.GetLudensDmg()
    local slot = RB.GetLudensSlot()

    if slot == 100 then
        return 0
    end

    if Player.GetSpell(Player, slot).RemainingCooldown > 0 then
        return 0
    end

    return 100 + (Player.TotalAP * 0.1)
end

function RB.IsKillable(target)
    -- fix
end

function RB.GetItemSlot(ID)
    local slot = 100

    if Player.Items[0] ~= nil then
        if Player.Items[0].ItemId == ID then
            slot = 6
        end
    end

    if Player.Items[1] ~= nil then
        if Player.Items[1].ItemId == ID then
            slot = 7
        end
    end

    if Player.Items[2] ~= nil then
        if Player.Items[2].ItemId == ID then
            slot = 8
        end
    end

    if Player.Items[3] ~= nil then
        if Player.Items[3].ItemId == ID then
            slot = 9
        end
    end

    if Player.Items[4] ~= nil then
        if Player.Items[4].ItemId == ID then
            slot = 10
        end
    end

    if Player.Items[5] ~= nil then
        if Player.Items[5].ItemId == ID then
            slot = 11
        end
    end

    return slot
end

function RB.TargetsInRange(Target, Range, Team, Type, Condition)
    -- return target in range
    local Objects = ObjectManager.Get(Team, Type)
    local Array = {}
    local Index = 0

    for _, Object in pairs(Objects) do
        if Object and Object ~= Target then
            Object = Object.AsAI
            if RB.IsValidTarget(Object) and (not Condition or Condition(Object)) then
                local Distance = Target:Distance(Object.Position)
                if Distance <= Range then
                    Array[Index] = Object
                    Index = Index + 1
                end
            end
        end
    end

    return {
        Array = Array,
        Count = Index
    }
end

---@param targetOrPosition AIHeroClient | Vector
function RB.ReleaseOrStartCharging(targetOrPosition, chance)
    if not targetOrPosition then
        return false
    end

    if not Vi.Q:IsReady() then
        return false
    end

    -- check if target is a vector
    if targetOrPosition.Position == nil then
        local vector = targetOrPosition

        if Vi.Q.IsCharging then
            -- -- print(Vi.Q.Range)

            -- -- print(Game.GetTime() - Vi.Q.LastCastTime)
            if Vi.Q.Range >= 650 or Game.GetTime() - Vi.Q.LastCastTime >= 3.5 then
                -- -- print("Release")
                Input.Release(SpellSlots.Q, targetOrPosition)
            end
        else
            if Vi.Q:StartCharging() then
                return true
            end
        end

        return false
    end

    if targetOrPosition.IsMinion then
        -- ---- INFO("t is minion")
        if Vi.Q.IsCharging then
            if Vi.Q:Release(targetOrPosition) then
                return true
            end
        end

        --     if Vi.Q:IsInRange(target) then
        --         Vi.Q:Release(target)
        --         return true
        --     end
        -- else
        if targetOrPosition:Distance(Player) < (250) then
            if Vi.Q:StartCharging(targetOrPosition) then
                Vi.Q.Speed = 1250
                Vi.Q.Range = 250
                Vi.Q.LastCastTime = Game.GetTime()
                return true
            end
        end
        -- end
        return true
    end

    if Vi.Q.IsCharging then
        if Vi.Q:ReleaseOnHitChance(targetOrPosition, chance) then
            return true
        end
    else
        local dist = targetOrPosition:Distance(Player.Position)
        if dist < (250 - 100) then
            return Vi.Q:Cast(targetOrPosition.Position)
        elseif targetOrPosition:Distance(Player) < (725) then
            if Vi.Q:StartCharging() then
                Vi.Q.Speed = 1250
                Vi.Q.Range = 250
                Vi.Q.LastCastTime = Game.GetTime()
                return true
            end
        end
    end
end

function RB.GetArea()
    return Nav.GetMapArea(Player.Position)["Area"]
end

function RB.CountMinionsInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function RB.CountMonstersInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function RB.HasBuff(target, buff)
    for i, v in pairs(target.Buffs) do
        if v.Name == buff then
            return true
        end
    end

    return false
end

function RB.EnabledAndMinimumMana(useID, manaID)
    local power = 10 ^ 2
    return MGet(useID) and Player.Mana >= math.floor(Player.MaxMana / 100 * MGet(manaID) * power) / power
end

function RB.EnabledAndMinimumHealth(useID, manaID, target)
    local power = 10 ^ 2
    return MGet(useID) and target.Health <= math.floor(target.MaxHealth / 100 * MGet(manaID) * power) / power
end

function RB.GetMenuColor(id)
    local isOn = MGet(id)

    if not Colorblind then
        if isOn then
            return 0x2FBD09FF
        else
            return 0xFF4D4DFF
        end
    else
        if isOn then
            return 0x4C84FFFF
        else
            return 0xFF9D00FF
        end
    end
end

function RB.SmartCheckbox(id, text)
    Menu.Checkbox(id, "", true)
    Menu.SameLine()
    Menu.ColoredText(text, RB.GetMenuColor(id))
end

function RB.CheckFlashSlot()
    local slots = { Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2 }

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    for _, slot in ipairs(slots) do
        if IsFlash(slot) then
            if UsableSS.Flash.Slot ~= slot then
                UsableSS.Flash.Slot = slot
            end

            return true
        end
    end

    if UsableSS.Flash.Slot ~= nil then
        UsableSS.Flash.Slot = nil
        return false
    end
end

function RB.CountMinionsInRangeOf(pos, range, team)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(team, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            minion:Distance(pos) <= range then
            amount = amount + 1
        end
    end
    return amount
end

function RB.GetMinionsInRangeOf(pos, range, team, pos2, range2)
    local minions = {}

    for k, v in ipairs(ObjectManager.GetNearby(team, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
            if pos2 and range2 then
                if minion:Distance(pos) <= range and minion:Distance(pos2) <= range2 then
                    table.insert(minions, minion)
                end
            else
                if minion:Distance(pos) <= range then
                    table.insert(minions, minion)
                end
            end
        end
    end
    return minions
end

function RB.GetHeroesInRangeOf(pos, range, team, pos2, range2)
    local heroes = {}

    for k, v in ipairs(ObjectManager.GetNearby(team, "heroes")) do
        local hero = v
        if not hero.IsDead and hero.IsTargetable then
            if pos2 and range2 then
                if hero:Distance(pos) <= range and hero:Distance(pos2) <= range2 then
                    table.insert(heroes, hero)
                end
            else
                if hero:Distance(pos) <= range then
                    table.insert(heroes, hero)
                end
            end
        end
    end

    return heroes
end

function RB.GetClosestHeroTo(pos, team, list)
    -- ---- INFO("GETTING CLOSEST hero... ")

    local range = 9999
    local returnHero = nil

    if list then
        -- ---- INFO("LIST WITH ... " .. #list .. " heros")

        for k, v in ipairs(list) do
            local hero = v
            if not hero.IsDead and hero.IsTargetable and hero:Distance(pos) <= range then
                returnHero = v
                range = hero:Distance(pos)
            end
        end
    else
        for a, b in ipairs(ObjectManager.GetNearby(team, "heroes")) do
            local hero = b
            if not hero.IsDead and hero.IsTargetable and hero:Distance(pos) <= range then
                returnHero = b
                range = hero:Distance(pos)
            end
        end
    end

    if returnHero ~= nil then
        -- WARN("RETURNING hero")
    end

    return returnHero
end

function RB.EnemyMinionsInRange(range)
    local pointsE = {}

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and minion.MaxHealth > 6 and Player:Distance(minion) <= range then
                local pos = minion
                if pos:Distance(Player.Position) < range and minion.IsTargetable then
                    table.insert(pointsE, pos)
                end
            end
        end
    end

    return pointsE
end

function RB.GetClosestBigMonster()
    -- If Player is on lane return nil
    if Player.IsInBotLane or Player.IsInMidLane or Player.IsInTopLane then
        return nil
    end

    -- Get Monsters in range of 500
    local monsters = ObjectManager.GetNearby("neutral", "minions")
    local monstersInRange = {}
    for index, value in ipairs(monsters) do
        local monster = value.AsAI
        if monster then
            if monster.IsTargetable and monster.MaxHealth > 6 and Player:Distance(monster) <= 500 then
                table.insert(monstersInRange, value)
            end
        end
    end

    return RB.GetClosestMinionTo(Player.Position, "neutral", monstersInRange) or false
end

function RB.IsInLane(AttackableUnit)
    if AttackableUnit.IsInTopLane or AttackableUnit.IsInBotLane or AttackableUnit.IsInMidLane then
        return true
    end
    return false
end

function RB.GetClosestMinionTo(pos, team, list)
    -- ---- INFO("GETTING CLOSEST MINION... ")

    local range = 9999
    local returnminion = nil

    if list then
        -- ---- INFO("LIST WITH ... " .. #list .. " Minions")

        for k, v in ipairs(list) do
            local minion = v.AsMinion
            if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                minion:Distance(pos) <= range then
                returnminion = v
                range = minion:Distance(pos)
            end
        end
    else
        for a, b in ipairs(ObjectManager.GetNearby(team, "minions")) do
            local minion = v.AsMinion
            if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
                if minion:Distance(pos) <= range then
                    returnminion = b
                    range = minion:Distance(pos)
                end
            end
        end
    end

    if returnminion ~= nil then
        -- WARN("RETURNING MINION")
    end
end

---@param id string
---@param name string
---@param default integer
function RB.ManaSlider(id, name, default)
    Menu.ColoredText(name, 0xEFC347FF)
    Menu.Slider(id, " ", default, 0, 100, 5)
    local power = 10 ^ 2
    local result = math.floor(Player.MaxMana / 100 * MGet(id) * power) / power
    Menu.ColoredText(MGet(id) .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
end

function RB.HealthSlider(id, name, default)
    Menu.ColoredText(name, 0xEFC347FF)
    Menu.Slider(id, " ", default, 0, 100, 5)
end

--- @return integer slot
function RB.GetGaleforceSlot()
    local slot = 100

    if Player.Items[0] ~= nil then
        if Player.Items[0].ItemId == 6671 then
            slot = 6
        end
    end

    if Player.Items[1] ~= nil then
        if Player.Items[1].ItemId == 6671 then
            slot = 7
        end
    end

    if Player.Items[2] ~= nil then
        if Player.Items[2].ItemId == 6671 then
            slot = 8
        end
    end

    if Player.Items[3] ~= nil then
        if Player.Items[3].ItemId == 6671 then
            slot = 9
        end
    end

    if Player.Items[4] ~= nil then
        if Player.Items[4].ItemId == 6671 then
            slot = 10
        end
    end

    if Player.Items[5] ~= nil then
        if Player.Items[5].ItemId == 6671 then
            slot = 11
        end
    end

    return slot
end

--- Gets the distance to an AttackableUnit
--- @param target AttackableUnit Unit to get distance to
--- @return integer distance Distance to unit
function RB.GetDistanceTo(target)
    return Player:Distance(target)
end

-- Velkoz Spells
Velkoz.Q = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1100,
    Radius = 50,
    Delay = 0.25,
    Speed = 1300,
    Collisions = {
        Heroes = true,
        Minions = true,
        WindWall = true
    },
    Type = "Linear",
    UseHitbox = true
})
Velkoz.QSplit = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1100,
    Radius = 55,
    Delay = 0.25,
    Speed = 1300,
    Collisions = {
        Heroes = true,
        Minions = true,
        WindWall = true
    },
    Type = "Linear"
})
Velkoz.QDummy = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = math.sqrt(math.pow(Velkoz.Q.Range, 2) + math.pow(Velkoz.QSplit.Range, 2)),
    Radius = 55,
    Delay = 0.25,
    Speed = math.huge,
    Collisions = {
        Heroes = true,
        Minions = true,
        WindWall = true
    },
    Type = "Linear"
})

Velkoz.W = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.W,
    Range = 1100,
    Radius = 175 / 2,
    Delay = 0.25,
    Speed = 1700,
    Collisions = {
        WindWall = true
    },
    Type = "Linear"
})
Velkoz.E = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range = 800,
    Radius = 225,
    Delay = 1,
    Speed = math.huge,
    Collisions = {
        WindWall = true
    },
    Type = "Circular"
})
Velkoz.R = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.R,
    Range = 1550,
    Radius = 100,
    Delay = 2.6,
    Speed = math.huge,
    Type = "Linear",
    UseHitbox = true
})

-- Hero Specific Functions
function GetIgniteDmg(target)
    CheckIgniteSlot()

    if UsableSS.Ignite.Slot == nil then
        return 0
    end

    if Player:GetSpellState(UsableSS.Ignite.Slot) == nil then
        return 0
    end

    if not UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) == Enums.SpellStates.Ready then
        return 50 + (20 * Player.Level) - target.HealthRegen * 2.5
    end

    return 0
end

function CanKill(target)
end

function GetQDmg(target)
    if target == nil then
        return 0
    end

    if not Velkoz.Q:IsLearned() or not Velkoz.Q:IsReady() then
        return 0
    end

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target,
        (60 + (Velkoz.Q:GetLevel() - 1) * 45) + (0.65 * Player.TotalAP))
end

function GetRDmg(target)
    if target == nil then
        return 0
    end

    if not Velkoz.R:IsLearned() or not Velkoz.R:IsReady() then
        return 0
    end

    -- 450 / 625 / 800

    local baseDmg = ({ 450, 625, 800 })[Velkoz.R:GetLevel()]

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, baseDmg + (1.25 * Player.TotalAP))
end

function GetPDmg(target)
    if target == nil then
        return 0
    end

    if Utils.HasBuff(target, "velkozresearchedstack") then
        return 0
    end

    return 25 + (8 * Player.Level) + 0.5 * Player.TotalAP
end

function GetWDmg(target)
    if target == nil then
        return 0
    end

    if not Velkoz.W:IsReady() then
        return 0
    end

    -- 15 / 22.5 / 30 / 37.5 / 45 (+ 100% AD) (+ 50% AP)

    local EBaseDmg = ({ 70, 120, 170, 220, 270 })[Velkoz.E:GetLevel()]

    local apDmg = Player.TotalAP * 0.7

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, (15 + (Velkoz.W:GetLevel() - 1) * 7.5) +
    (0.5 * Player.TotalAP) + (Player.TotalAD))
end

function GetPassiveDamage(target)
    local baseDmg = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

function MGet(id)
    return Menu.Get(id)
end

-- Utils
function Utils.IsGameAvailable()
    -- Is game available to automate stuff
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead)
end

function Utils.CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjectManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end

function Utils.IsInRange(From, To, Min, Max)
    -- Is Target in range
    local Distance = From:Distance(To)
    return Distance > Min and Distance <= Max
end

function Utils.GetBoundingRadius(Target)
    if not Target then
        return 0
    end

    -- Bounding boxes
    return Player.BoundingRadius + Target.BoundingRadius
end

function Utils.IsValidTarget(Target)
    return Target and Target.IsTargetable and Target.IsAlive
end

function Utils.IsCasting()
    local spell = Player.ActiveSpell

    if spell then
        if spell.Name == "VelkozLightBinding" then
            return true
        end
        if spell.Name == "VelkozLightStrikeKugel" then
            return true
        end
    end

    return false
end

function Utils.GetLudensSlot()
    local slot = 100

    if Player.Items[0] ~= nil then
        if Player.Items[0].ItemId == 6655 then
            slot = 6
        end
    end

    if Player.Items[1] ~= nil then
        if Player.Items[1].ItemId == 6655 then
            slot = 7
        end
    end

    if Player.Items[2] ~= nil then
        if Player.Items[2].ItemId == 6655 then
            slot = 8
        end
    end

    if Player.Items[3] ~= nil then
        if Player.Items[3].ItemId == 6655 then
            slot = 9
        end
    end

    if Player.Items[4] ~= nil then
        if Player.Items[4].ItemId == 6655 then
            slot = 10
        end
    end

    if Player.Items[5] ~= nil then
        if Player.Items[5].ItemId == 6655 then
            slot = 11
        end
    end

    return slot
end

function Utils.GetLudensDmg()
    local slot = Utils.GetLudensSlot()

    if slot == 100 then
        return 0
    end

    if Player.GetSpell(Player, slot).RemainingCooldown > 0 then
        return 0
    end

    return 100 + (Player.TotalAP * 0.1)
end

function Utils.IsKillable(target)
    -- fix
end

function Utils.CountMinionsInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function Utils.CountMonstersInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function Utils.HasBuff(target, buff)
    for i, v in pairs(target.Buffs) do
        if v.Name == buff then
            return true
        end
    end

    return false
end

function Utils.NoLag(tick)
    if (iTick == tick) then
        return true
    else
        return false
    end
end

function Utils.GetItemSlot(ID)
    local slot = 100

    if Player.Items[0] ~= nil then
        if Player.Items[0].ItemId == ID then
            slot = 6
        end
    end

    if Player.Items[1] ~= nil then
        if Player.Items[1].ItemId == ID then
            slot = 7
        end
    end

    if Player.Items[2] ~= nil then
        if Player.Items[2].ItemId == ID then
            slot = 8
        end
    end

    if Player.Items[3] ~= nil then
        if Player.Items[3].ItemId == ID then
            slot = 9
        end
    end

    if Player.Items[4] ~= nil then
        if Player.Items[4].ItemId == ID then
            slot = 10
        end
    end

    if Player.Items[5] ~= nil then
        if Player.Items[5].ItemId == ID then
            slot = 11
        end
    end

    return slot
end

function Utils.ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

function Utils.TargetsInRange(Target, Range, Team, Type, Condition)
    -- return target in range
    local Objects = ObjectManager.Get(Team, Type)
    local Array = {}
    local Index = 0

    for _, Object in pairs(Objects) do
        if Object and Object ~= Target then
            Object = Object.AsAI
            if Utils.IsValidTarget(Object) and (not Condition or Condition(Object)) then
                local Distance = Target:Distance(Object.Position)
                if Distance <= Range then
                    Array[Index] = Object
                    Index = Index + 1
                end
            end
        end
    end

    return {
        Array = Array,
        Count = Index
    }
end

function Utils.GetMenuColor(id)
    local isOn = Menu.Get(id)

    if not Colorblind then
        if isOn then
            return 0x2FBD09FF
        else
            return 0xFF4D4DFF
        end
    else
        if isOn then
            return 0x4C84FFFF
        else
            return 0xFF9D00FF
        end
    end
end

function Utils.MenuDivider(color, sym, am)
    local DivColor = color or 0xEFC347FF
    local string = ""
    local amount = 166 or am
    local symbol = sym or "="

    for i = 1, 166 do
        string = string .. symbol
    end

    return Menu.ColoredText(string, DivColor, true)
end

function Utils.HitCountSlider(id, default, min, max, text, color)
    Menu.Slider(id, "  ", default, min, max, 1)
    Menu.ColoredText(text or "Minimum Minions Hit", color or 0xE3FFDF)
end

function Utils.ManaSlider(id, name, default)
    Menu.Slider(id, name, default, 0, 100, 5)
    local power = 10 ^ 2
    local result = math.floor(Player.MaxMana / 100 * Menu.Get(id) * power) / power
    Menu.ColoredText(Menu.Get(id) .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
end

function Utils.GetArea()
    return Nav.GetMapArea(Player.Position)["Area"]
end

function Utils.IsInJungle()
    if string.match(Utils.GetArea(), "Lane") then
        return false
    else
        return true
    end
end

function Utils.EnabledAndMinimumMana(useID, manaID)
    local power = 10 ^ 2
    return Menu.Get(useID) and Player.Mana >= math.floor(Player.MaxMana / 100 * Menu.Get(manaID) * power) / power
end

function Utils.GetMinionsInRangeOf(pos, range, team, pos2, range2)
    local minions = {}

    for k, v in ipairs(ObjectManager.GetNearby(team, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
            if pos2 and range2 then
                if minion:Distance(pos) <= range and minion:Distance(pos2) <= range2 then
                    table.insert(minions, minion)
                end
            else
                if minion:Distance(pos) <= range then
                    table.insert(minions, minion)
                end
            end
        end
    end
    return minions
end

function Utils.EnemyMinionsInRange(pos, range, pos2, range2)
    local minions = {}

    for k, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
            if pos2 and range2 then
                if minion:Distance(pos) <= range and minion:Distance(pos2) <= range2 then
                    table.insert(minions, minion)
                end
            else
                if minion:Distance(pos) <= range then
                    table.insert(minions, minion)
                end
            end
        end
    end
    return minions
end

function Utils.NeutralMinionsInRange(range)
    local pointsE = {}

    for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and minion.MaxHealth > 6 and Player:Distance(minion) <= range then
                local pos = minion
                if pos:Distance(Player.Position) < range and minion.IsTargetable then
                    table.insert(pointsE, pos)
                end
            end
        end
    end

    return pointsE
end

function Utils.SmartCheckbox(id, text)
    Menu.Checkbox(id, "", true)
    Menu.SameLine()
    Menu.ColoredText(text, Utils.GetMenuColor(id))
end

function Utils.SliderWithTitle(id, title, defaultValue, minimumValue, maximumValue, stepValue, color)
    Menu.ColoredText(title, color or 0xEFC347FF)
    Menu.Slider(id, " ", defaultValue, minimumValue, maximumValue, stepValue)
end

-- Event Functions’
function Velkoz.OnProcessSpell(Caster, spellCast)
end

function Velkoz.OnUpdate()
end

function Velkoz.OnBuffGain(obj, buffInst)
end

function Velkoz.OnBuffLost(obj, buffInst)
end

function Velkoz.OnGapclose(source, dashInstance)
    if source.IsHero and source.IsEnemy and Velkoz.E:IsInRange(source) then
        if Velkoz.E:IsReady() then
            local pred = Velkoz.E:GetPrediction(source)
            if pred and pred.HitChance >= 0.75 then
                if Velkoz.E:Cast(pred.CastPosition) then
                    return true
                end
            end
        end
    end

    if source.IsHero and source.IsEnemy and Velkoz.W:IsInRange(source) then
        if Velkoz.W:IsReady() and not Velkoz.E:IsReady() then
            local pred = Velkoz.W:GetPrediction(source)
            if pred and pred.HitChance >= 0.75 then
                if Velkoz.W:Cast(pred.CastPosition) then
                    return true
                end
            end
        end
    end
end

function Velkoz.OnExtremePriority(lagFree)
end

---@param obj MissileClient @The object that is being attacked
function Velkoz.OnCreateObject(obj, lagFree)

    if obj.Name == "VelkozQMissile" then
        -- INFO("Missile Created")

        VelQ = obj
        VelQCreatePos = obj.Position
    end
end

function Velkoz.OnDeleteObject(obj)
    if obj.Name == "VelkozQMissile" then
        -- INFO("Missile Gone")
        VelQ = nil
        VelQCreatePos = nil
    end
end

function Velkoz.OnTick(lagFree)
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Velkoz.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Velkoz.Logic.Auto(lagFree) then
        return true
    end

    --[[


        --]]
end

function Velkoz.OnHeroImmobilized(Source, EndTime, IsStasis)
end

function Velkoz.OnPreAttack(args)
end

function Velkoz.OnPostAttack(target)
end

function Velkoz.OnInterruptibleSpell(source, spellCast, danger, endTime, canMoveDuringChannel)

    if source.IsHero and source.IsEnemy and Velkoz.E:IsInRange(source) then
        if Velkoz.E:IsReady() and Menu.Get("EInterrupt") then
            if danger < 5 then

                local pred = Velkoz.E:GetPrediction(source)
                if pred and pred.HitChance >= 0.65 then
                    if Velkoz.E:Cast(pred.CastPosition) then
                        return
                    end
                end
            end
        end

    end

end

-- Drawings
function Velkoz.OnDrawDamage(target, dmgList)
    if not target then
        return
    end
    if not target.IsAlive then
        return
    end

    local totalDmg = 0

    if Velkoz.R:IsReady() then
        table.insert(dmgList, GetRDmg(target))
        totalDmg = totalDmg + GetRDmg(target)
    end

    table.insert(dmgList, GetPDmg(target))
    totalDmg = totalDmg + GetPDmg(target)
    -- if orbwalk mode is combo, -- print totalDmg
    if Orbwalker.GetMode() == "Combo" then
        -- print(totalDmg)
    end
end

function Velkoz.OnDraw()
    if not Utils.IsGameAvailable() then
        return false
    end

    if MGet("AutoQSplit") then
        local target = TS:GetTarget(2000)

        if target then
            if VelQ ~= nil then
                local AB = VelQCreatePos:Distance(VelQ.Position)
                local AC = VelQCreatePos:Distance(target.Position)
                local BC = VelQ:Distance(target.Position)

                local VelQCos = ((AB * AB) + (BC * BC) - (AC * AC)) / (2 * AB * BC)
                local angle = math.acos(VelQCos)

                if angle >= 1.70 and angle <= 1.75 then
                    -- WARN("Triggering Q at " .. angle)
                    Input.Cast(SpellSlots.Q)
                end

            end
        end
    end
    local hideDraw = Menu.Get("RangeDrawHide")

    if Menu.Get("Drawings.Q") then
        if hideDraw then
            if Velkoz.Q:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Velkoz.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Velkoz.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
        end
    end
    if Menu.Get("Drawings.W") then
        if hideDraw then
            if Velkoz.W:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Velkoz.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Velkoz.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
        end
    end
    if Menu.Get("Drawings.E") then
        if hideDraw then
            if Velkoz.E:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Velkoz.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Velkoz.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
        end
    end
    if Menu.Get("Drawings.R") then
        if hideDraw then
            if Velkoz.R:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Velkoz.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Velkoz.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
        end
    end


    if Velkoz.R:IsReady(2) then

        if not MGet("DrawRIndicator") then
            return true
        end

        local target = TS:GetTarget(1500)

        if target then

            local baseRadius = 400

            local totalDmg = GetRDmg(target) + GetPDmg(target)
            local fullHealthValue = target.MaxHealth - totalDmg

            local oneRadiusWorthOfHp = fullHealthValue / baseRadius
            local currentHealthValue = target.Health - totalDmg

            local Radius = currentHealthValue * (1 / oneRadiusWorthOfHp)



            local fullHealthRadius = target.MaxHealth - totalDmg
            local healthLeft = target.Health - totalDmg
            if healthLeft < 0 then
                healthLeft = 0
            end




            if healthLeft > fullHealthRadius / 1.5 then
                Renderer.DrawCircle3D(target.Position, Radius, 3, 20, 0x9100EBFF)
                return
            end
            if healthLeft < fullHealthRadius / 3 then
                Renderer.DrawCircle3D(target.Position, Radius, 3, 20, 0xFF0C00FF)
                return
            end
            if healthLeft < fullHealthRadius / 2 then
                Renderer.DrawCircle3D(target.Position, Radius, 3, 20, 0xE04605FF)
                return
            end
            if healthLeft < fullHealthRadius / 1.5 then
                Renderer.DrawCircle3D(target.Position, Radius, 3, 20, 0xEB6200FF)
                return
            end





        end
    end


end

-- Spell Logic
function Velkoz.Logic.R(Target)
    -- check if Target is in Whitelist
    if not MGet("UseR") then
        return false
    end
    if not Menu.Get("R" .. Target.CharName) then
        return false
    end

    if Velkoz.R:IsReady() then
        if Player:Distance(Target) < Velkoz.R.Range then
            if not Player.IsCasting then
                if ((Velkoz.R:GetKillstealHealth(Target) <= (GetPDmg(Target) + GetRDmg(Target))) and MGet("IgnoreWH")) or
                    RB.EnabledAndMinimumHealth("R" .. Target.CharName, "R" .. Target.CharName .. "Health", Target) then
                    --   if Target:Distance(Renderer.GetMousePos()) <= 600 then
                    if Velkoz.R:Cast(Target) then
                        return true
                    end

                    -- end
                end
            end
        end
    end
end

function Velkoz.Logic.Q(Target)
    if Velkoz.Q:IsReady() then
        if Orbwalker.GetMode() == "Combo" then
            if MGet("UseQ") then
                if Player:Distance(Target) < Velkoz.Q.Range then
                    if Player.GetSpell(Player, SpellSlots.Q).GetName ~= "VelkozQSplitActivate" then
                        if VelQ ~= nil then
                            return false
                        end
                        -- print(Player.GetSpell(Player, SpellSlots.Q).Name)
                        if Velkoz.Q:CastOnHitChance(Target, Menu.Get("QHitChance") / 100) then
                            return true
                        end
                    end
                end
            end
        end

        if Orbwalker.GetMode() == "Harass" then
            if Utils.EnabledAndMinimumMana("UseQHarass", "QHarassMana") then
                if Velkoz.Q:IsReady() then
                    if Player:Distance(Target) < Velkoz.Q.Range then
                        if Player.GetSpell(Player, SpellSlots.Q).GetName ~= "VelkozQSplitActivate" then
                            if VelQ ~= nil then
                                return false
                            end
                            -- print(Player.GetSpell(Player, SpellSlots.Q).Name)
                            if Velkoz.Q:CastOnHitChance(Target, Menu.Get("QHitChanceHarass") / 100) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function Velkoz.Logic.W(Target)
    if Velkoz.W:IsReady() then
        if Orbwalker.GetMode() == "Harass" then
            if Utils.EnabledAndMinimumMana("UseWHarass", "WHarassMana") then
                if Velkoz.W:IsReady() then
                    if Player:Distance(Target) < Velkoz.W.Range then
                        if Velkoz.W:CastOnHitChance(Target, Menu.Get("WHitChanceHarass") / 100) then
                            return true
                        end
                    end
                end
            end

            return
        end

        if MGet("UseW") then
            if Player:Distance(Target) < Velkoz.W.Range then
                if Velkoz.W:CastOnHitChance(Target, Menu.Get("WHitChance") / 100) then
                    return true
                end
            end
        end
    end
end

function Velkoz.Logic.E(Target)
    if Velkoz.E:IsReady() then
        if Orbwalker.GetMode() == "Harass" then
            if Utils.EnabledAndMinimumMana("UseEHarass", "EHarassMana") then
                if Player:Distance(Target) < Velkoz.E.Range then
                    if Velkoz.E:CastOnHitChance(Target, Menu.Get("EHitChance") / 100) then
                        return true
                    end
                end
            end
        else
            if MGet("UseE") then
                if Player:Distance(Target) < Velkoz.E.Range then
                    if Velkoz.E:CastOnHitChance(Target, Menu.Get("EHitChance") / 100) then
                        return true
                    end
                end
            end
        end
    end
end

-- Orbwalker Logic
function Velkoz.Logic.Lasthit(lagFree)
end

function Velkoz.Logic.Flee(lagFree)
end

function Velkoz.Logic.Waveclear(lagFree)
    if Utils.IsInJungle() then
        for i, v in ipairs(Utils.NeutralMinionsInRange(Velkoz.E.Range)) do
            if Velkoz.E:IsReady() then
                if Velkoz.E:Cast(v) then
                    return true
                end
            end

            if Velkoz.Q:IsReady() then
                return Velkoz.Q:Cast(v)
            end
        end

        local bestPos, hitCount = Velkoz.W:GetBestCircularCastPos(Utils.NeutralMinionsInRange(Velkoz.W.Range),
            Velkoz.W.Radius)
        if bestPos and hitCount >= 1 then
            if Velkoz.W:IsReady() then
                if Velkoz.W:IsInRange(bestPos) then
                    Velkoz.W:Cast(bestPos)
                end
            end
        end
    else


        if Velkoz.E:IsReady() then
            if Utils.EnabledAndMinimumMana("UseEWaveclear", "EWaveclearMana") then
                if #ObjectManager.GetNearby("enemy", "heroes") > 0 and MGet("EWCSafety") then
                    goto SafetySkip
                end

                local eMinions = Utils.GetMinionsInRangeOf(Player.Position, Velkoz.E.Range, "enemy")

                local pPos, pointsE = Player.Position, {}

                for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
                    local minion = v.AsAI
                    if minion then
                        local pos = minion.Position
                        if pos:Distance(pPos) < Velkoz.E.Range and minion.IsTargetable then
                            table.insert(pointsE, pos)
                        end
                    end
                end

                local bestPos, hitCount = Velkoz.E:GetBestCircularCastPos(pointsE, Velkoz.E.Radius)
                if bestPos and hitCount >= Menu.Get("EWaveclearHitcount") then
                    if Velkoz.E:Cast(bestPos) then
                        return true
                    end
                end
            end
        end

        ::SafetySkip::
        if Velkoz.W:IsReady() then
            if Utils.EnabledAndMinimumMana("UseWWaveclear", "WWaveclearMana") then
                local wCharges = Player:GetSpell(SpellSlots.W).Ammo

                if Menu.Get("KeepWCharge") then
                    if wCharges < 2 then
                        goto WSkip
                    end
                end

                local wMinions = Utils.GetMinionsInRangeOf(Player.Position, Velkoz.W.Range, "enemy")

                local pPos, pointsW = Player.Position, {}

                for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
                    local minion = v.AsAI
                    if minion then
                        local pos = minion.Position
                        if pos:Distance(pPos) < Velkoz.W.Range and minion.IsTargetable then
                            table.insert(pointsW, pos)
                        end
                    end
                end

                local bestPos, hitCount = Velkoz.W:GetBestLinearCastPos(pointsW)
                if bestPos and hitCount >= Menu.Get("WWaveclearHitcount") then
                    if Velkoz.W:IsReady() then
                        if Velkoz.W:IsInRange(bestPos) then
                            Velkoz.W:Cast(bestPos)
                        end
                    end
                end
            end
        end

        ::WSkip::
        if Menu.IsKeyPressed(1) then
            local QMinions = Utils.GetMinionsInRangeOf(Player.Position, Velkoz.Q.Range, "enemy")

            if Velkoz.Q:IsReady() then
                for i, v in ipairs(QMinions) do
                    if VelQ == nil then
                        if Input.Cast(SpellSlots.Q, v.Position) then
                            return true
                        end
                    end
                end
            end
        end

    end
end

function Velkoz.Logic.Harass(lagFree)
    if lagFree == 3 or lagFree == 4 then
        local t = TS:GetTarget(Velkoz.Q.Range)

        if not t then
            return false
        end

        if Velkoz.Logic.Q(t) then
            return true
        end

        t = TS:GetTarget(Velkoz.E.Range)
        if not t then
            return false
        end

        if Velkoz.Logic.E(t) then
            return true
        end

        t = TS:GetTarget(Velkoz.W.Range)
        if not t then
            return false
        end

        if Velkoz.Logic.W(t) then
            return true
        end
    end
end

function Velkoz.Logic.Combo(lagFree)
    local t = TS:GetTarget(Velkoz.Q.Range)

    if not t then
        return false
    end

    if Velkoz.Logic.Q(t) then
        return true
    end

    t = TS:GetTarget(Velkoz.R.Range)
    if not t then
        return false
    end

    if Velkoz.Logic.R(t) then
        return true
    end

    t = TS:GetTarget(Velkoz.E.Range)
    if not t then
        return false
    end

    if Velkoz.Logic.E(t) then
        return true
    end

    t = TS:GetTarget(Velkoz.W.Range)
    if not t then
        return false
    end

    if Velkoz.Logic.W(t) then
        return true
    end
end

function Velkoz.Logic.Auto(lagFree)
    -- get target in q range
    local t = TS:GetTarget(Velkoz.Q.Range)

    if not t then
        return false
    end

    if VelQ ~= nil then
        -- -- print(Velkoz.QDummy.Delay)
        Velkoz.QDummy.Delay = math.floor(.25 + Velkoz.Q.Range / Velkoz.Q.Speed * 1000 + Velkoz.QSplit.Range /
        Velkoz.QSplit.Speed * 1000) * 1000
        local ePred = Prediction.GetPredictedPosition(t, Velkoz.QDummy, VelQ.Position)
    end
end

-- Menu
function Velkoz.LoadMenu()
    Menu.RegisterMenu("BigVelkoz", "BigVelkoz", function()




        -- ______  _          _   _        _  _
        -- | ___ \(_)        | | | |      | || |
        -- | |_/ / _   __ _  | | | |  ___ | || | __  ___   ____
        -- | ___ \| | / _` | | | | | / _ \| || |/ / / _ \ |_  /
        -- | |_/ /| || (_| | \ \_/ /|  __/| ||   < | (_) | / /
        -- \____/ |_| \__, |  \___/  \___||_||_|\_\ \___/ /___|
        --             __/ |
        --            |___/

        Menu.Text("______  _          _   _        _  _                ", true)
        Menu.Text("| ___ \\(_)        | | | |      | || |                ", true)
        Menu.Text("| |_/ / _   __ _  | | | |  ___ | || | __  ___   ____ ", true)
        Menu.Text("| ___ \\| | / _` | | | | | / _ \\| || |/ / / _ \\ |_  / ", true)
        Menu.Text("| |_/ /| || (_| | \\ \\_/ /|  __/| ||   < | (_) | / /  ", true)
        Menu.Text("\\____/ |_| \\__, |  \\___/  \\___||_||_|\\_\\ \\___/ /___|", true)
        Menu.Text("             __/ |                                    ", true)
        Menu.Text("           |___/                                    ", true)




        Menu.ColoredText("Author:", 0xEFC347FF, true)
        Menu.SameLine()
        Menu.ColoredText("Roburppey", 0xD52CFFFF)
        Menu.ColoredText("Version:", 0xEFC347FF, true)
        Menu.SameLine()
        Menu.ColoredText(ScriptVersion, 0xE3FFDF)
        Menu.ColoredText("Last Updated:", 0xEFC347FF, true)
        Menu.SameLine()
        Menu.ColoredText(ScriptLastUpdate, 0xE3FFDF)
        Menu.Text("")
        Menu.ColoredText("[ Developer Notes ]", 0xE3FFDF, true)
        Menu.Text("Due To Technical Limitations Velkoz Can Start [R], But It Can't Follow.", true)
        Menu.Text("Optionally You Can Disable [R] Completely.", true)
        Menu.Text("")
        Menu.ColoredText("Colorblind Settings:", 0xEFC347FF)
        Menu.Button("Colorblind", "Toggle Colorblind Mode", function()
            if Colorblind then
                Colorblind = false
            else
                Colorblind = true
            end
        end)
        Menu.Text("")
        Menu.NewTree(
            "Changelog",
            "Changelog",
            function()
                Menu.Text("1.0.0 - Initial Release")
            end
        )

        Menu.Separator()
        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()
            Menu.Text("")
            Menu.ColoredText("[ Spell Settings ]", 0xEFC347FF, true)
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()

                Menu.Checkbox("UseQ", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [Q]", Utils.GetMenuColor("UseQ"))
                Utils.SmartCheckbox("AutoQSplit", "Automatically Split [Q] to hit target (BETA)")
                Menu.Text("")
                Menu.NextColumn()
                Menu.Slider("QHitChance", "HitChance %", 45, 1, 100, 1)
                Menu.NextColumn()

                Menu.Checkbox("UseE", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [E]", Utils.GetMenuColor("UseE"))
                RB.SmartCheckbox("EInterrupt", "Interrupt Enemy Spells With [E] ")
                Menu.Text("")
                Menu.NextColumn()
                Menu.Text("")
                Menu.Slider("EHitChance", "HitChance %", 45, 1, 100, 1)
                Menu.NextColumn()
                Menu.Checkbox("UseW", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [W]", Utils.GetMenuColor("UseW"))
                Menu.Text("")
                Menu.NextColumn()
                Menu.Text("")
                Menu.Slider("WHitChance", "HitChance %", 45, 1, 100, 1)
                Menu.NextColumn()
                Menu.Checkbox("UseR", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [R]", Utils.GetMenuColor("UseR"))

                Menu.NextColumn()
            end)
            Menu.Text("")
            Utils.SmartCheckbox("RSafety", "[R] Range Safety Check")
            if (MGet("RSafety")) then
                Utils.SmartCheckbox("RSafetyIgnoreTarget", "Ignore Range Check For Target")
                Utils.SliderWithTitle("RSafetySlider", "Do not use [R] if enemies are within range of: ", 300, 0,
                    Velkoz.R.Range, 100)
            end
            Menu.Text("")
            Menu.Text("")

            Menu.ColoredText("[ Whitelist ]", 0xEFC347FF, true)
            Menu.Text("")
            RB.SmartCheckbox("IgnoreWH", "Ignore Whitelist Health Check On Targets If They Are Killable")
            Menu.NewTree("RWhitelist", "R Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    Menu.NewTree(Object.CharName .. "2", Object.CharName, function()
                        local Name = Object.AsHero.CharName
                        RB.SmartCheckbox("R" .. Name, "Use [R] On " .. Object.CharName, true)

                        if MGet("R" .. Name) then
                            RB.HealthSlider("R" .. Name .. "Health", "Minimum Enemy Health Percentage To Use [R]", 25)
                        end
                    end)
                end
            end)
            Menu.Text("")
        end)
        Utils.MenuDivider(0xFF901CFF, "-", nil)
        Menu.NewTree("BigHeroHarass", "Harass", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu2", "DrawMenu2", 2, true, function()
                Utils.SmartCheckbox("UseQHarass", "Cast [Q]")
                Menu.NextColumn()
                Menu.Slider("QHitChanceHarass", "HitChance %", 45, 1, 100, 1)
                Utils.ManaSlider("QHarassMana", "Min Mana", 30)
                Menu.NextColumn()
                Menu.Text("")

                Utils.SmartCheckbox("UseEHarass", "Cast [E]")
                Menu.NextColumn()
                Menu.Text("")

                Menu.Slider("EHitChanceHarass", "HitChance %", 60, 1, 100, 1)
                Utils.ManaSlider("EHarassMana", "Min Mana", 30)
                Menu.NextColumn()

                Utils.SmartCheckbox("UseWHarass", "Cast [W]")
                Menu.NextColumn()
                Menu.Text("")

                Menu.Slider("WHitChanceHarass", "HitChance %", 60, 1, 100, 1)
                Utils.ManaSlider("WHarassMana", "Min Mana", 30)
                Menu.NextColumn()
            end)
        end)
        Utils.MenuDivider(0xFF901CFF, "-", nil)
        Menu.NewTree("BigHeroWaveclear", "Waveclear", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu223", "DrawMenu223", 2, true, function()
                Utils.SmartCheckbox("UseWWaveclear", "Cast [W]")
                Utils.SmartCheckbox("KeepWCharge", "Always keep 1 [W] Charge")
                Menu.NextColumn()
                Utils.ManaSlider("WWaveclearMana", "Min Mana", 35)
                Utils.HitCountSlider("WWaveclearHitcount", 4, 1, 6)
                Menu.NextColumn()
                Utils.SmartCheckbox("UseEWaveclear", "Cast [E]")
                Menu.NextColumn()
                Menu.Text("")
                Utils.ManaSlider("EWaveclearMana", "Min Mana", 35)
                Utils.HitCountSlider("EWaveclearHitcount", 4, 1, 6)
                Menu.NextColumn()
                Utils.SmartCheckbox("EWCSafety", "Don't use [E] if enemies are nearby")
            end)
        end)
        Utils.MenuDivider(0xFF901CFF, "-", nil)
        Menu.NewTree("Drawings", "Drawings", function()
            Menu.ColumnLayout("DrawMenu3", "DrawMenu2", 2, true, function()
                Menu.Text("")
                Menu.ColoredText("Range Drawings", 0xE3FFDF)
                Menu.Text("")
                Utils.SmartCheckbox("RangeDrawHide", "Hide Drawings Of Spells On CD")
                Menu.Text("")
                Menu.Checkbox("Drawings.Q", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [Q] Range", Utils.GetMenuColor("Drawings.Q"))
                if Menu.Get("Drawings.Q") then
                    Menu.ColorPicker("Drawings.Q.Color", "", 0x9100EBFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.W", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [W] Range", Utils.GetMenuColor("Drawings.W"))
                if Menu.Get("Drawings.W") then
                    Menu.ColorPicker("Drawings.W.Color", "", 0x9100EBFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.E", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [E] Range", Utils.GetMenuColor("Drawings.E"))
                if Menu.Get("Drawings.E") then
                    Menu.ColorPicker("Drawings.E.Color", "", 0x9100EBFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.R", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [R] Range", Utils.GetMenuColor("Drawings.R"))
                RB.SmartCheckbox("DrawRIndicator", "Draw [R] Indicator On Enemies")
                if Menu.Get("Drawings.R") then
                    Menu.ColorPicker("Drawings.R.Color", "", 0x9100EBFF)
                    Menu.Text("")
                end
                Menu.Text("")
                Menu.NextColumn()
                Menu.Text("")
                Menu.ColoredText("Damage Drawings", 0xE3FFDF)
                Menu.Text("")
                Utils.SmartCheckbox("DmgDrawings.Q", "Draw [Q] Dmg")
                Utils.SmartCheckbox("DmgDrawings.W", "Draw [Q] Dmg")
                Utils.SmartCheckbox("DmgDrawings.E", "Draw [E] Dmg")
                Utils.SmartCheckbox("DmgDrawings.R", "Draw [R] Dmg")
                Menu.SameLine()
                Menu.Text("")
                Utils.SmartCheckbox("DmgDrawings.P", "Draw Passive Dmg")
                Utils.SmartCheckbox("DmgDrawings.P2", "Draw Passive Explosion Dmg")
                Utils.SmartCheckbox("DmgDrawings.Ludens", "Draw [Ludens] Dmg")

                Menu.Text("")
                Menu.NextColumn()
            end)
        end)
    end)
end

-- OnLoad
function OnLoad()
    -- INFO("Welcome to BigVelkoz, enjoy your stay")

    Velkoz.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Velkoz[EventName] then
            EventManager.RegisterCallback(EventId, Velkoz[EventName])
        end
    end

    return true
end
