--[[
    BigVi
]]
if Player.CharName ~= "Vi" then
    return false
end

module("Vi", package.seeall, log.setup)
clean.module("Vi", package.seeall, log.setup)

-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
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
local HitChanceStrings = {
    "Collision",
    "OutOfRange",
    "VeryLow",
    "Low",
    "Medium",
    "High",
    "VeryHigh",
    "Dashing",
    "Immobile"
}
local lastETime = 0
local ItemIDs = require("lol\\Modules\\Common\\ItemID")
local Player = ObjectManager.Player.AsHero
local ScriptVersion = "1.0.1"
local ScriptLastUpdate = "09. April 2022"
local DamageLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local Nav = _G.CoreEx.Nav
local Colorblind = false
local Vector = _G.CoreEx.Geometry.Vector
CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigVi.lua", ScriptVersion)

-- Globals
local Vi = {}
local RB = {}
Vi.TargetSelector = nil
Vi.Logic = {}

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

-- ░██████╗██████╗░███████╗██╗░░░░░██╗░░░░░  ██████╗░░█████╗░████████╗░█████╗░
-- ██╔════╝██╔══██╗██╔════╝██║░░░░░██║░░░░░  ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
-- ╚█████╗░██████╔╝█████╗░░██║░░░░░██║░░░░░  ██║░░██║███████║░░░██║░░░███████║
-- ░╚═══██╗██╔═══╝░██╔══╝░░██║░░░░░██║░░░░░  ██║░░██║██╔══██║░░░██║░░░██╔══██║
-- ██████╔╝██║░░░░░███████╗███████╗███████╗  ██████╔╝██║░░██║░░░██║░░░██║░░██║
-- ╚═════╝░╚═╝░░░░░╚══════╝╚══════╝╚══════╝  ╚═════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░╚═╝

Vi.Q =
    SpellLib.Chargeable(
    {
        Slot = Enums.SpellSlots.Q,
        Range = 725,
        Radius = 55 / 2,
        Delay = 0,
        Speed = 1250,
        Collisions = {Heroes = true, Minions = false, WindWall = false},
        Type = "Linear",
        UseHitbox = true,
        IsCharging = false,
        MinRange = 250,
        MaxRange = 725,
        FullChargeTime = 1.25,
        ChargeStartTime = 0,
        ChargeSentTime = 0,
        ReleaseSentTime = 0,
        LastCastTime = 0
    }
)
Vi.ClearQ =
    SpellLib.Skillshot(
    {
        Slot = Enums.SpellSlots.Q,
        Range = 725,
        Speed = 1250,
        Width = 55,
        Collision = false,
        Type = "Linear",
        Radius = 55 / 2
    }
)

Vi.W =
    SpellLib.Active(
    {
        Slot = Enums.SpellSlots.W,
        Range = 1175,
        Radius = 110,
        Delay = 0.25,
        Type = "Active"
    }
)
Vi.E =
    SpellLib.Active(
    {
        Slot = Enums.SpellSlots.E,
        Range = 1100,
        Radius = 300,
        Delay = 0.25,
        Speed = 1200,
        Collisions = {WindWall = true},
        Type = "Circular",
        UseHitbox = true
    }
)
Vi.R =
    SpellLib.Targeted(
    {
        Slot = Enums.SpellSlots.R,
        Range = 800,
        Radius = 100,
        Delay = 1,
        Speed = math.huge,
        UseHitbox = true
    }
)

-- ██████╗░███╗░░░███╗░██████╗░  ░█████╗░░█████╗░██╗░░░░░░█████╗░
-- ██╔══██╗████╗░████║██╔════╝░  ██╔══██╗██╔══██╗██║░░░░░██╔══██╗
-- ██║░░██║██╔████╔██║██║░░██╗░  ██║░░╚═╝███████║██║░░░░░██║░░╚═╝
-- ██║░░██║██║╚██╔╝██║██║░░╚██╗  ██║░░██╗██╔══██║██║░░░░░██║░░██╗
-- ██████╔╝██║░╚═╝░██║╚██████╔╝  ╚█████╔╝██║░░██║███████╗╚█████╔╝
-- ╚═════╝░╚═╝░░░░░╚═╝░╚═════╝░  ░╚════╝░╚═╝░░╚═╝╚══════╝░╚════╝░

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

    if not Vi.Q:IsLearned() or not Vi.Q:IsReady() and not Vi.Q.IsCharging then
        return 0
    end

    -- 110 / 160 / 210 / 260 / 310 (+ 140% bonus AD)

    return DamageLib.CalculatePhysicalDamage(
        Player.AsAI,
        target,
        (110 + (Vi.Q:GetLevel() - 1) * 50) + (1.4 * Player.TotalAD)
    )
end
function GetEDmg(target)
    if target == nil then
        return 0
    end

    if not Vi.E:IsLearned() or not Vi.E:IsReady() then
        return 0
    end

    --10 / 30 / 50 / 70 / 90 (+ 110% AD) (+ 90% AP)

    return DamageLib.CalculatePhysicalDamage(
        Player.AsAI,
        target,
        (10 + (Vi.E:GetLevel() - 1) * 20) + (0.9 * Player.TotalAP) + (0.9 * Player.TotalAD)
    )
end

function GetWDmg(target)
    if target == nil then
        return 0
    end

    if not Vi.W:IsLearned() then
        return 0
    end

    -- 4 / 5.5 / 7 / 8.5 / 10% (+「 1% per 35 」bonus AD) of target's maximum health

    local WBasePercent = ({0.04, 0.055, 0.07, 0.085, 0.1})[Vi.W:GetLevel()]

    local WADPercent = (math.floor(Player.BonusAD / 30) - 1) / 100

    local WDmg = (WBasePercent + WADPercent) * target.MaxHealth

    return DamageLib.CalculatePhysicalDamage(Player.AsAI, target, WDmg)
end
function GetRDmg(target)
    if target == nil then
        return 0
    end
    if not Vi.R:IsReady() then
        return 0
    end

    -- 150 / 325 / 500 (+ 110% bonus AD)

    return DamageLib.CalculatePhysicalDamage(
        Player.AsAI,
        target,
        (150 + (Vi.R:GetLevel() - 1) * 175) + (1.1 * Player.BonusAD)
    )
end
function GetPassiveDamage(target)
    local baseDmg = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

-- ██████╗░██████╗░██╗░░░░░██╗██████╗░
-- ██╔══██╗██╔══██╗██║░░░░░██║██╔══██╗
-- ██████╔╝██████╦╝██║░░░░░██║██████╦╝
-- ██╔══██╗██╔══██╗██║░░░░░██║██╔══██╗
-- ██║░░██║██████╦╝███████╗██║██████╦╝
-- ╚═╝░░╚═╝╚═════╝░╚══════╝╚═╝╚═════╝░

-- A curation of useful functions.

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
        if spell.Name == "ChampionLightBinding" then
            return true
        end
        if spell.Name == "ChampionLightStrikeKugel" then
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

    return {Array = Array, Count = Index}
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
            -- print(Vi.Q.Range)

            -- print(Game.GetTime() - Vi.Q.LastCastTime)
            if Vi.Q.Range >= 650 or Game.GetTime() - Vi.Q.LastCastTime >= 3.5 then
                -- print("Release")
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
        -- -- INFO("t is minion")
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
        if
            not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                Player:Distance(minion) < range
         then
            amount = amount + 1
        end
    end
    return amount
end
function RB.CountMonstersInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if
            not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                Player:Distance(minion) < range
         then
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
    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

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
        if
            not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                minion:Distance(pos) <= range
         then
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
    -- -- INFO("GETTING CLOSEST hero... ")

    local range = 9999
    local returnHero = nil

    if list then
        -- -- INFO("LIST WITH ... " .. #list .. " heros")

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
    -- -- INFO("GETTING CLOSEST MINION... ")

    local range = 9999
    local returnminion = nil

    if list then
        -- -- INFO("LIST WITH ... " .. #list .. " Minions")

        for k, v in ipairs(list) do
            local minion = v.AsMinion
            if
                not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                    minion:Distance(pos) <= range
             then
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
    local power = 10 ^ 2
    local result = math.floor(Player.MaxHealth / 100 * MGet(id) * power) / power
    Menu.ColoredText(MGet(id) .. " Percent Is Equal To " .. result .. " Health", 0xE3FFDF)
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

-- ███████╗██╗░░░██╗███████╗███╗░░██╗████████╗░██████╗
-- ██╔════╝██║░░░██║██╔════╝████╗░██║╚══██╔══╝██╔════╝
-- █████╗░░╚██╗░██╔╝█████╗░░██╔██╗██║░░░██║░░░╚█████╗░
-- ██╔══╝░░░╚████╔╝░██╔══╝░░██║╚████║░░░██║░░░░╚═══██╗
-- ███████╗░░╚██╔╝░░███████╗██║░╚███║░░░██║░░░██████╔╝
-- ╚══════╝░░░╚═╝░░░╚══════╝╚═╝░░╚══╝░░░╚═╝░░░╚═════╝░

--- @param Caster GameObject
--- @param SpellCast SpellCast
function Vi.OnProcessSpell(Caster, SpellCast)
    if Caster.IsMe then
        if SpellCast.Name == "ViQ" then
            Vi.Q.LastCastTime = Game.GetTime()
        end
    end
end
function Vi.OnUpdate()
end
function Vi.OnBuffGain(obj, buffInst)
end
function Vi.OnBuffLost(obj, buffInst)
end
function Vi.OnGapclose(source, dash)
end
function Vi.OnExtremePriority(lagFree)
    -- testing, doesn't work propperly
    if false then
        -- get a target in range of 2000
        local t = TS:GetTarget(2000)

        -- Check if target is valid
        if not t then
            return
        end

        -- get distance of player to target
        local distance = RB.GetDistanceTo(t)

        -- if the distance is smaller than vi boundingRadius then

        if t:EdgeDistance(Player) < 195 and t:EdgeDistance(Player) > 185 then
            -- get galeforce slot
            local gf = RB.GetItemSlot(ItemIDs.Galeforce)

            if gf then
                -- if galeforce is ready then

                if Player:GetSpell(gf).RemainingCooldown == 0 then
                    -- cast galeforce on target
                    -- extend vector from target to player + 450
                    local target = t
                    local extend = t.Position:Extended(Player.Position, Player:Distance(t.Position) + 450)

                    -- cast galeforce on extended vector
                    print("DISTANCE: " .. tostring(extend))
                    if Input.Cast(gf, extend) then
                        -- INFO("Cast at distance: " .. t:EdgeDistance(Player))
                        return true
                    end
                end
            end
        end
    end

    --- Raising Q Speed based on Vi.Q.LastCastTime
    -- formula = 1250 + 15 per 0.125 seconds
    -- This is capped at 1.25 seconds

    Vi.Q.Speed = 1250 + 15 * ((Game.GetTime() - Vi.Q.LastCastTime) / 0.125)
    if Vi.Q.Speed > 1400 then
        Vi.Q.Speed = 1400
    end

    local newQRange = 250 + (47.5 * ((Game.GetTime() - Vi.Q.LastCastTime) / 0.125))
    if newQRange > 725 then
        newQRange = 725
    end
    Vi.Q.Range = newQRange

    -- print("Q Speed: " .. tostring(Vi.Q.Speed))
    -- print("Q Range: " .. tostring(Vi.Q.Range))
end
function Vi.OnCreateObject(obj, lagFree)
end
function Vi.OnTick(lagFree)
    if not RB.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Vi.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Vi.Logic.Auto(lagFree) then
        return true
    end

    --[[


        --]]
end
function Vi.OnHeroImmobilized(Source, EndTime, IsStasis)
end
function Vi.OnPreAttack(args)
end
---@param target AttackableUnit
function Vi.OnPostAttack(target)
    if Orbwalker.GetMode() == "Waveclear" then
        if RB.EnabledAndMinimumMana("UseEWaveclear", "EManaSlider") then
            -- create a list of minions that are in Vi.E.Range
            if Vi.E:IsReady() then
                Vi.E:Cast()
            end
        end
    end

    if Orbwalker.GetMode() == "Harass" then
        if RB.EnabledAndMinimumMana("EHarass", "EMana") then
            if Vi.E:IsReady() then
                Vi.E:Cast()
            end
        end
        return true
    end
    if Orbwalker.GetMode() == "Combo" then
        if MGet("ECombo") then
            if Vi.E:IsReady() then
                Vi.E:Cast()
            end
        end
        return true
    end

    if not target.IsValid then
        return
    end
    if not target.IsAlive then
        return
    end
    if not target.IsTargetable then
        return
    end

    if target.IsHero or target.IsTurret or target.IsInDragonPit or target.IsInBaronPit then
        if Vi.E.IsReady then
            if Vi.E:Cast() then
                return true
            end
        end
    else
        if string.find(RB.GetArea(), "Jungle") or string.find(RB.GetArea(), "River") then
            if Vi.E.IsReady then
                if Vi.E:Cast() then
                    return true
                end
            end
        end
    end
end

-- ██████╗░██████╗░░█████╗░░██╗░░░░░░░██╗██╗███╗░░██╗░██████╗░░██████╗
-- ██╔══██╗██╔══██╗██╔══██╗░██║░░██╗░░██║██║████╗░██║██╔════╝░██╔════╝
-- ██║░░██║██████╔╝███████║░╚██╗████╗██╔╝██║██╔██╗██║██║░░██╗░╚█████╗░
-- ██║░░██║██╔══██╗██╔══██║░░████╔═████║░██║██║╚████║██║░░╚██╗░╚═══██╗
-- ██████╔╝██║░░██║██║░░██║░░╚██╔╝░╚██╔╝░██║██║░╚███║╚██████╔╝██████╔╝
-- ╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚══╝░╚═════╝░╚═════╝░

function Vi.OnDrawDamage(target, dmgList)
    if not target then
        return
    end
    if not target.IsAlive then
        return
    end

    local Q = MGet("DrawQDamage")
    local E = MGet("DrawEDamage")
    local W = MGet("DrawWDamage")
    local R = MGet("DrawRDamage")

    if Q then
        table.insert(dmgList, GetQDmg(target))
    end
    if E then
        table.insert(dmgList, GetEDmg(target))
    end
    if W then
        table.insert(dmgList, GetWDmg(target))
    end
    if R then
        table.insert(dmgList, GetRDmg(target))
    end
end
function Vi.OnDraw()
    local Q = MGet("DrawQ")
    local R = MGet("DrawR")

    if Q then
        Renderer.DrawCircle3D(Player.Position, 725, 5, 3, MGet("QColor"))
    end
    if R then
        Renderer.DrawCircle3D(Player.Position, 800, 5, 3, MGet("RColor"))
    end

    if Vi.Q.IsCharging then
        local color = 0xFF901CFF
        -- -- INFO("Speed " .. Vi.Q.Speed)
        -- -- INFO("Range " .. Vi.Q.Range)
        local pos = Player.Position

        Renderer.DrawCircle3D(pos, Vi.Q.Range, 3, 3, color)
    end
end

-- ░██████╗██████╗░███████╗██╗░░░░░██╗░░░░░  ██╗░░░░░░█████╗░░██████╗░██╗░█████╗░
-- ██╔════╝██╔══██╗██╔════╝██║░░░░░██║░░░░░  ██║░░░░░██╔══██╗██╔════╝░██║██╔══██╗
-- ╚█████╗░██████╔╝█████╗░░██║░░░░░██║░░░░░  ██║░░░░░██║░░██║██║░░██╗░██║██║░░╚═╝
-- ░╚═══██╗██╔═══╝░██╔══╝░░██║░░░░░██║░░░░░  ██║░░░░░██║░░██║██║░░╚██╗██║██║░░██╗
-- ██████╔╝██║░░░░░███████╗███████╗███████╗  ███████╗╚█████╔╝╚██████╔╝██║╚█████╔╝
-- ╚═════╝░╚═╝░░░░░╚══════╝╚══════╝╚══════╝  ╚══════╝░╚════╝░░╚═════╝░╚═╝░╚════╝░

function Vi.Logic.R(Target)
    if not Target then
        return false
    end
    if not Vi.R:IsInRange(Target) then
        return false
    end
    if not Vi.R:IsReady() then
        return false
    end

    if RB.EnabledAndMinimumHealth("R" .. Target.CharName, "R" .. Target.CharName .. "Health", Target) then
        if Vi.R:Cast(Target) then
            return true
        end
    end

    if TS:GetForcedTarget() then
        if TS:GetForcedTarget() == Target then
            if Vi.R:Cast(Target) then
                return true
            end
        end
    end

    return false
end
function Vi.Logic.Q(Target)
end
function Vi.Logic.W(lagFree)
end
function Vi.Logic.E(Target)
end

-- ░█████╗░██████╗░██████╗░░██╗░░░░░░░██╗░█████╗░██╗░░░░░██╗░░██╗███████╗██████╗░  ███╗░░░███╗░█████╗░██████╗░███████╗░██████╗
-- ██╔══██╗██╔══██╗██╔══██╗░██║░░██╗░░██║██╔══██╗██║░░░░░██║░██╔╝██╔════╝██╔══██╗  ████╗░████║██╔══██╗██╔══██╗██╔════╝██╔════╝
-- ██║░░██║██████╔╝██████╦╝░╚██╗████╗██╔╝███████║██║░░░░░█████═╝░█████╗░░██████╔╝  ██╔████╔██║██║░░██║██║░░██║█████╗░░╚█████╗░
-- ██║░░██║██╔══██╗██╔══██╗░░████╔═████║░██╔══██║██║░░░░░██╔═██╗░██╔══╝░░██╔══██╗  ██║╚██╔╝██║██║░░██║██║░░██║██╔══╝░░░╚═══██╗
-- ╚█████╔╝██║░░██║██████╦╝░░╚██╔╝░╚██╔╝░██║░░██║███████╗██║░╚██╗███████╗██║░░██║  ██║░╚═╝░██║╚█████╔╝██████╔╝███████╗██████╔╝
-- ░╚════╝░╚═╝░░╚═╝╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝  ╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚══════╝╚═════╝░

function Vi.Logic.Lasthit(lagFree)
end
function Vi.Logic.Flee(lagFree)
end
function Vi.Logic.Waveclear(lagFree)
    -- check if the Players position is on a lane
    if RB.IsInLane(Player) then
        --  print("On Lane")
        -- check if waveclear q is Enabled

        if RB.EnabledAndMinimumMana("UseQWaveclear", "QManaSlider") or Vi.Q.IsCharging then
            -- create a list of minions that are in Vi.Q.Range
            local minions = RB.GetMinionsInRangeOf(Player.Position, Vi.ClearQ.Range, "enemy")
            --  print("Minions: " .. #minions)
            -- find the best cast position
            local bestPos, hitCount =
                RB.GetBestLinearFarmPosition(minions, Vi.ClearQ.Radius * 2, 725, MGet("QHCSlider"))

            if bestPos then
                -- print("Best Pos: " .. bestPos.x .. " " .. bestPos.z)
                -- print("Hit Count: " .. hitCount)
                if hitCount >= MGet("QHCSlider") or (Vi.Q.IsCharging and Game.GetTime() - Vi.Q.LastCastTime >= 1.25) then
                    RB.ReleaseOrStartCharging(bestPos, 0.35)
                end
            end
        end
    end

    -- Get Monsters in range of 500
    local monsters = ObjectManager.GetNearby("neutral", "minions")
    local monstersInRange = {}
    for index, value in ipairs(monsters) do
        local monster = value.AsAI
        if monster then
            if monster.IsTargetable and monster.MaxHealth > 6 and Player:Distance(monster) <= 725 then
                table.insert(monstersInRange, value)
            end
        end
    end

    local t = nil

    for index2, value2 in ipairs(monstersInRange) do
        if string.find(value2.Name, "Gromp") then
            t = value2
        end
        if string.find(value2.Name, "Blue") then
            t = value2
        end
        if string.find(value2.Name, "Murkwolf") and not string.find(value2.Name, "MurkwolfMini") then
            t = value2
        end
        if string.find(value2.Name, "Razorbeak") and not string.find(value2.Name, "RazorbeakMini") then
            t = value2
        end
        if string.find(value2.Name, "Red") then
            t = value2
        end
        if string.find(value2.Name, "Krug") then
            t = value2
        end
        if string.find(value2.Name, "Rift") then
            t = value2
        end
        if string.find(value2.Name, "Crab") then
            t = value2
        end
        if string.find(value2.Name, "Dragon") then
            t = value2
        end
        if string.find(value2.Name, "Baron") then
            t = value2
        end
    end

    if t == nil then
        if #monstersInRange >= 1 then
            t = RB.GetClosestMinionTo(Player.Position, "neutral", monstersInRange)
        end
    end

    RB.ReleaseOrStartCharging(t, 0.35)

    if Orbwalker.IsAttackReady() then
        if t then
            if Orbwalker.CanAttack() then
                -- if in t is in auto attack range
                if Player:Distance(t) <= Player.AttackRange then
                    Orbwalker.Attack(t)
                end
            end
        end
    end
end
function Vi.Logic.Harass(lagFree)
    -- Get initial target
    local t = TS:GetTarget(2000)

    -- Check if target is valid
    if not t then
        return
    end

    -- check if harass q is enabled
    if RB.EnabledAndMinimumMana("QHarass", "QMana") or Vi.Q.IsCharging then
        RB.ReleaseOrStartCharging(t, 0.35)
    end

    -- Cast R on target
end
function Vi.Logic.Combo(lagFree)
    local Q = MGet("QCombo")
    local E = MGet("ECombo")
    local R = MGet("RCombo")

    -- Get initial target
    local t = TS:GetTarget(800)

    -- Check if target is valid
    if not t then
        return
    end

    if TS:GetForcedTarget() then
        t = TS:GetForcedTarget()
    end

    if Q or Vi.Q.IsCharging then
        if RB.ReleaseOrStartCharging(t, 0.35) then
            return true
        end
    end
    if R then
        if Vi.R:IsReady() then
            if Vi.Logic.R(t) then
                return true
            end
        end
    end
end
function Vi.Logic.Auto(lagFree)
end

-- ███╗░░░███╗███████╗███╗░░██╗██╗░░░██╗
-- ████╗░████║██╔════╝████╗░██║██║░░░██║
-- ██╔████╔██║█████╗░░██╔██╗██║██║░░░██║
-- ██║╚██╔╝██║██╔══╝░░██║╚████║██║░░░██║
-- ██║░╚═╝░██║███████╗██║░╚███║╚██████╔╝
-- ╚═╝░░░░░╚═╝╚══════╝╚═╝░░╚══╝░╚═════╝░

local RBMenu = {}
---@return function
function MGet(id)
    return Menu.Get(id)
end
function RBMenu.Divider(color, sym, am)
    local DivColor = color or 0xEFC347FF
    local string = ""
    local amount = 166 or am
    local symbol = sym or "="

    for i = 1, 166 do
        string = string .. symbol
    end

    return Menu.ColoredText(string, DivColor, true)
end
function RBMenu.Description()
    --[[
  ____ _____ _____  __      _______ 
 |  _ \_   _/ ____| \ \    / /_   _|
 | |_) || || |  __   \ \  / /  | |  
 |  _ < | || | |_ |   \ \/ /   | |  
 | |_) || || |__| |    \  /   _| |_ 
 |____/_____\_____|     \/   |_____|
                                    
                                    
--]]
    Menu.Text("  ____ _____ _____  __      _______ ", true)
    Menu.Text(" |  _ \\_   _/ ____| \\ \\    / /_   _|", true)
    Menu.Text(" | |_) || || |  __   \\ \\  / /  | |  ", true)
    Menu.Text(" |  _ < | || | |_ |   \\ \\/ /   | |  ", true)
    Menu.Text(" | |_) || || |__| |    \\  /   _| |_ ", true)
    Menu.Text(" |____/_____\\_____|     \\/   |_____|", true)
    Menu.Text("                                     ", true)

    Menu.Text("")
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

    Menu.ColoredText("Colorblind Settings:", 0xEFC347FF)
    Menu.Button(
        "Colorblind",
        "Toggle Colorblind Mode",
        function()
            if Colorblind then
                Colorblind = false
            else
                Colorblind = true
            end
        end
    )
    Menu.Text("")
    Menu.NewTree(
        "Changelog",
        "Changelog",
        function()
            Menu.Text("1.0.1 - Menu Fixes")
            Menu.Text("1.0.0 - Initial Release")
        end
    )
    Menu.Separator()
    Menu.Text("")
end
function RBMenu.Combo()
    Menu.NewTree(
        "BigHeroCombo",
        "Combo",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu",
                "DrawMenu",
                2,
                true,
                function()
                    RB.SmartCheckbox("QCombo", "Use [Q]")
                    Menu.NextColumn()
                    Menu.Slider("QHitChance", "HitChance %", 35, 1, 100, 1)
                    Menu.NextColumn()
                    -- RB.SmartCheckbox("UseW", "Use [W]", true)
                    RB.SmartCheckbox("ECombo", "Use [E]")
                    RB.SmartCheckbox("RCombo", "Use [R]")
                    Menu.ColoredText("R Uses Whitelist, Forced Targt Is Also Possible", 0xEFC347FF)
                end
            )

            Menu.Text("")
            Menu.NewTree(
                "RWhitelist",
                "R Whitelist",
                function()
                    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                        Menu.NewTree(
                            Object.CharName .. "2",
                            Object.CharName,
                            function()
                                local Name = Object.AsHero.CharName
                                RB.SmartCheckbox("R" .. Name, "Use [R]", true)

                                if MGet("R" .. Name) then
                                    RB.HealthSlider("R" .. Name .. "Health", "Minimum Health To Use [R]", 100)
                                end
                            end
                        )
                    end
                end
            )
            Menu.Text("")
        end
    )
end
function RBMenu.Harass()
    Menu.NewTree(
        "BigHeroHarass",
        "Harass",
        function()
            RB.SmartCheckbox("QHarass", "Use [Q]")
            -- Minimum enemies hit Slider
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("QHarass")) then
                RB.ManaSlider("QMana", "[Q] Min Mana", 50)
            end
            Menu.Text("")
            Menu.NextColumn()
            RB.SmartCheckbox("EHarass", "Use [E]")
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("EHarass")) then
                RB.ManaSlider("EMana", "[E] Min Mana", 50)
            end
        end
    )
end
function RBMenu.Waveclear()
    Menu.NewTree(
        "BigHeroWaveclear",
        "Waveclear",
        function()
            RB.SmartCheckbox("UseQWaveclear", "Use [Q]")
            Menu.Text("")
            -- Minimum enemies hit Slider
            Menu.NextColumn()
            if (MGet("UseQWaveclear")) then
                Menu.ColoredText("[Q] Min Hitcount", 0xEFC347FF)
                Menu.Slider("QHCSlider", " ", 2, 1, 5, 1)
                -- Q Mana Slider
                RB.ManaSlider("QManaSlider", "[Q] Min Mana", 50)
            end
            Menu.Text("")
            Menu.NextColumn()
            RB.SmartCheckbox("UseEWaveclear", "Use [E]")
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("UseEWaveclear")) then
                RB.ManaSlider("EManaSlider", "[E] Min Mana", 50)
            end

            Menu.Text("")
            Menu.Text("")
        end
    )
end
function RBMenu.Jungleclear()
    Menu.NewTree(
        "BigHeroJungleclear",
        "Jungleclear",
        function()
            Menu.Text("")

            RB.SmartCheckbox("UseQJungleclear", "Use [Q]")
            RB.SmartCheckbox("UseEJungleclear", "Use [E]")
            Menu.NextColumn()

            Menu.Text("")
            Menu.Text("")
        end
    )
end
function RBMenu.Killsteal()
    Menu.NewTree(
        "BigHeroKillsteal",
        "Killsteal",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu5",
                "DrawMenu5",
                2,
                true,
                function()
                    RB.SmartCheckbox("UseQKillsteal", "Use [Q]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseWKillsteal", "Use [W]")
                    RB.SmartCheckbox("UseEKillsteal", "Use [E]")
                    RB.SmartCheckbox("UseRKillsteal", "Use [R]")
                end
            )
            Menu.Text("")
            Menu.Text("")
        end
    )
end
function RBMenu.Draw()
    Menu.NewTree(
        "BigHeroDraw",
        "Draw",
        function()
            Menu.NewTree(
                "DrawQMenu",
                "[Q] Drawings",
                function()
                    RB.SmartCheckbox("DrawQ", "Draw [Q] Range")
                    Menu.ColorPicker("QColor", "", 0xFF4646FF)
                    RB.SmartCheckbox("DrawQDamage", "Draw [Q] Damage")
                end
            )
            Menu.NewTree(
                "DrawWMenu",
                "[W] Drawings",
                function()
                    RB.SmartCheckbox("DrawWDamage", "Draw [W] Damage")
                end
            )
            Menu.NewTree(
                "DrawEMenu",
                "[E] Drawings",
                function()
                    RB.SmartCheckbox("DrawEDamage", "Draw [E] Damage")
                end
            )
            Menu.NewTree(
                "DrawRMenu",
                "[R] Drawings",
                function()
                    RB.SmartCheckbox("DrawR", "Draw [R] Range")
                    Menu.ColorPicker("RColor", "", 0xFF4646FF)
                    RB.SmartCheckbox("DrawRDamage", "Draw [R] Damage")
                end
            )
        end
    )
end
function RBMenu.Misc()
    Menu.NewTree(
        "BigHeroMisc",
        "Misc",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu7",
                "DrawMenu7",
                2,
                true,
                function()
                    RB.SmartCheckbox("UseQMisc", "Use [Q]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseWMisc", "Use [W]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseEMisc", "Use [E]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseRMisc", "Use [R]")
                end
            )
            Menu.Text("")
            Menu.Text("")
        end
    )
end

---@param id string
---@param title string
---@param defaultValue integer
---@param minimumValue integer
---@param maximumValue integer
---@param stepValue integer
function RBMenu.SliderWithTitle(id, title, defaultValue, minimumValue, maximumValue, stepValue, color)
    return function()
        Menu.ColoredText(title,color or 0xEFC347FF)
        Menu.Slider(id,"",defaultValue,minimumValue,maximumValue,stepValue)
    end
end

function Vi.LoadMenu()
    Menu.RegisterMenu(
        "BigVi",
        "BigVi",
        function()
            RBMenu.Description()
            RBMenu.Combo()
            RBMenu.Divider(0xFF901CFF, "-", nil)
            RBMenu.Harass()
            RBMenu.Divider(0xFF901CFF, "-", nil)
            RBMenu.Waveclear()
            RBMenu.Divider(0xFF901CFF, "-", nil)
            RBMenu.Jungleclear()
            RBMenu.Divider(0xFF901CFF, "-", nil)
            RBMenu.Draw()
            RBMenu.Divider(0xFF901CFF, "-", nil)
        end
    )
end

-- ░█████╗░███╗░░██╗██╗░░░░░░█████╗░░█████╗░██████╗░
-- ██╔══██╗████╗░██║██║░░░░░██╔══██╗██╔══██╗██╔══██╗
-- ██║░░██║██╔██╗██║██║░░░░░██║░░██║███████║██║░░██║
-- ██║░░██║██║╚████║██║░░░░░██║░░██║██╔══██║██║░░██║
-- ╚█████╔╝██║░╚███║███████╗╚█████╔╝██║░░██║██████╔╝
-- ░╚════╝░╚═╝░░╚══╝╚══════╝░╚════╝░╚═╝░░╚═╝╚═════╝░

function OnLoad()
    -- INFO("Welcome to BigChampion, enjoy your stay")

    Vi.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Vi[EventName] then
            EventManager.RegisterCallback(EventId, Vi[EventName])
        end
    end

    return true
end
