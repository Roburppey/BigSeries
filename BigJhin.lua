--[[
    BigJhin
]]

if Player.CharName ~= "Jhin" then
    return false
end

module("BJhin", package.seeall, log.setup)
clean.module("BJhin", package.seeall, log.setup)



-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local os_clock = _G.os.clock
local Menu = Libs.NewMenu
local Prediction = Libs.Prediction
local HealthPred = _G.Libs.HealthPred
local DetectedSpell
local DashLib = _G.Libs.DashLib
local Orbwalker = Libs.Orbwalker
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local ImmobileLib = Libs.ImmobileLib
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
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };
local lastETime
local Player = ObjectManager.Player.AsHero
local qTimer = { nil, nil }
local coneCtor = _G.CoreEx.Geometry.Cone
local vecCtor = _G.CoreEx.Geometry.Vector
local HitChanceEnum = Enums.HitChance
local ScriptVersion = "1.2.0"
local ScriptLastUpdate = "3. May 2022"
local iTick = 0
local JhinRLoc = nil

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigJhin.lua", ScriptVersion)


-- Globals
local Jhin = {}
local Utils = {}

Jhin.TargetSelector = nil
Jhin.Logic = {}

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


-- Spells
Jhin.Q = SpellLib.Targeted({

    Slot = SpellSlots.Q,
    Range = 650,
    Radius = 400,
    Speed = math.huge,
    Delay = 0.25,
    Type = "Linear",
    Collisions = { Windwall = true }


})

Jhin.W = SpellLib.Skillshot({

    Slot = SpellSlots.W,
    Range = 2450,
    Radius = 45,
    Speed = 5000,
    Delay = 0.25,
    Type = "Linear",
    Collisions = { Heroes = true, Windwall = true }

})

Jhin.E = SpellLib.Skillshot({

    Slot = SpellSlots.E,
    Range = 750,
    Radius = 220,
    Speed = 1000,
    Delay = 0.25,
    Type = "Circular",
    Collisions = { Windwall = true }


})

Jhin.R = SpellLib.Skillshot({

    Slot = SpellSlots.R,
    Range = 3500,
    Radius = 80,
    Speed = 5000,
    Delay = 0.25,
    Type = "Linear",
    UseHitbox = true,
    Collisions = { Heroes = true, Windwall = true

    } })

-- Functions
function CheckIgniteSlot()
    local slots = { Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2 }

    local function IsIgnite(slot)
        return Player:GetSpell(slot).Name == "SummonerDot"
    end

    for _, slot in ipairs(slots) do
        if IsIgnite(slot) then
            if UsableSS.Ignite.Slot ~= slot then
                UsableSS.Ignite.Slot = slot
            end

            return
        end
    end

    if UsableSS.Ignite.Slot ~= nil then
        UsableSS.Ignite.Slot = nil
    end

end

function CheckFlashSlot()
    local slots = { Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2 }

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    for _, slot in ipairs(slots) do
        if IsFlash(slot) then
            if UsableSS.Flash.Slot ~= slot then
                UsableSS.Flash.Slot = slot
            end

            return
        end
    end

    if UsableSS.Flash.Slot ~= nil then
        UsableSS.Flash.Slot = nil
    end

end

function GetUltDmg(Target)


end

function IsReloading()

    if Utils.HasBuff(Player, "JhinPassiveReload") then
        return true

    end

    return false


end

function GetIgniteDmg(target)

    CheckIgniteSlot()

    if UsableSS.Ignite.Slot == nil then

        return 0
    end

    if Player:GetSpellState(UsableSS.Ignite.Slot) == nil then

        return 0

    end

    if not UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready then


        return 50 + (20 * Player.Level) - target.HealthRegen * 2.5

    end

    return 0


end

function CanKill(target)


end

local function GetWDmg(target)
    local playerAI = Player.AsAI
    local dmgR = 15 + 35 * Player:GetSpell(SpellSlots.W).Level
    local adDmg = playerAI.TotalAD * 0.5
    local totalDmg = dmgR + adDmg
    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

function GetQDmg(target)

    if target == nil then
        return 0
    end

    if not Jhin.Q:IsLearned() or not Jhin.Q:IsReady() then
        return 0

    end

    local baseDmg = ({ 45, 70, 95, 120, 145 })[Jhin.Q:GetLevel()]
    local ADModifier = ({ 0.35, 0.425, 0.50, 0.575, 0.65 })[Jhin.Q:GetLevel()]
    local bonusAdDmg = Player.TotalAD * ADModifier

    local totalDmg = (baseDmg + bonusAdDmg + (Player.TotalAP * 0.6))

    local multiplyArmorDecrease = 100 / (100 + target.Armor)

    return totalDmg * multiplyArmorDecrease

end

function Get4thAfterQDamage(target)

    if not target then return 0 end

    local tHealthMax = target.MaxHealth
    local tHealth = target.Health

    local currentMissingHp = tHealthMax - tHealth
    local currentMissingHpDamage = currentMissingHp * 0.15

    local missingHpAfterQ = tHealthMax - (tHealth + GetQDmg(target))
    local missingHpAfterQDamage = missingHpAfterQ * 0.15

    local missingHpDifferenceDmg = currentMissingHpDamage - missingHpAfterQDamage

    return DamageLib.GetAutoAttackDamage(Player, target, true) + missingHpDifferenceDmg

end

local function IsMarked(target)
    return target:GetBuff("jhinespotteddebuff");
end

function ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 and not minion.IsDead
end

-- Utils

function Utils.GetEDamage(target)


end

function Utils.IsGameAvailable()
    -- Is game available to automate stuff
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead)
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

function Utils.GetRTarget()

    local targetsUnfiltered = TS:GetTargets(Jhin.R.Range)
    local targetsFiltered = {}
    local target = nil

    if targetsUnfiltered then

        for i, v in pairs(targetsUnfiltered) do

            if Player.IsFacing(Player, v.Position, 30) then

                if target == nil then
                    target = v
                end

                if v.Health < target.Health then

                    target = v

                end


            end

        end

    end

    return target


end

function Utils.IsKillable(target)


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

function Utils.PrintBuffs(target)

    for i, v in pairs(target.Buffs) do

        if v.Name == "HeroRunCycleManager" then

        end


    end


end

function Utils.GetWDmg(target)


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

function Utils.GetGaleforceSlot()

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

function Utils.GaleForceDmg(target)

    if target == nil then
        return 0
    end

    local slot = Utils.GetGaleforceSlot()

    if slot == 100 then
        return 0
    end

    if slot ~= 100 then
        if Player.GetSpell(Player, slot).RemainingCooldown ~= 0 then
            return 0
        end
    end

    local playerLevel = Player.Level

    local magicDamage = 0

    if playerLevel < 10 then
        magicDamage = 180
    end
    if playerLevel == 10 then
        magicDamage = 195
    end
    if playerLevel == 11 then
        magicDamage = 210
    end
    if playerLevel == 12 then
        magicDamage = 225
    end
    if playerLevel == 13 then
        magicDamage = 240
    end
    if playerLevel == 14 then
        magicDamage = 255
    end
    if playerLevel == 15 then
        magicDamage = 270
    end
    if playerLevel == 16 then
        magicDamage = 285
    end
    if playerLevel == 17 then
        magicDamage = 300
    end
    if playerLevel == 18 then
        magicDamage = 315
    end

    local phyiscalDamage = Player.BonusAD * 0.45

    local executeDamage = 0
    local missingHealthPercent = ((target.MaxHealth - target.Health) / target.MaxHealth)

    if missingHealthPercent < 0.07 then
        executeDamage = 1

    end
    if missingHealthPercent >= 0.07 and missingHealthPercent < 0.14 then
        executeDamage = 1.05

    end
    if missingHealthPercent >= 0.14 and missingHealthPercent < 0.21 then
        executeDamage = 1.1

    end
    if missingHealthPercent >= 0.21 and missingHealthPercent < 0.28 then
        executeDamage = 1.15

    end
    if missingHealthPercent >= 0.28 and missingHealthPercent < 0.35 then
        executeDamage = 1.2

    end
    if missingHealthPercent >= 0.35 and missingHealthPercent < 0.42 then
        executeDamage = 1.25

    end
    if missingHealthPercent >= 0.42 and missingHealthPercent < 0.49 then
        executeDamage = 1.3

    end
    if missingHealthPercent >= 0.49 and missingHealthPercent < 0.56 then
        executeDamage = 1.35

    end
    if missingHealthPercent >= 0.56 and missingHealthPercent < 0.63 then
        executeDamage = 1.4

    end
    if missingHealthPercent >= 0.63 and missingHealthPercent < 0.70 then
        executeDamage = 1.45

    end
    if missingHealthPercent >= 0.7 then
        executeDamage = 1.5

    end

    return (magicDamage + phyiscalDamage) * executeDamage

end

function protectedNameRetrieval(v)

    local particleName = v.Name

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
            if Utils.IsValidTarget(Object) and
                (not Condition or Condition(Object))
            then
                local Distance = Target:Distance(Object.Position)
                if Distance <= Range then
                    Array[Index] = Object
                    Index = Index + 1
                end
            end
        end
    end

    return { Array = Array, Count = Index }
end

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

function Jhin.OnProcessSpell(Caster, SpellCast)


end

function Jhin.OnUpdate()

    iTick = iTick + 1
    if iTick > 4 then
        iTick = 0
    end

    return false

end

---@param args table
--- args has {Process,Target}
function Jhin.OnPreAttack(args)

    if args.Target.IsMinion then return end

    if Utils.HasBuff(Player, "jhinpassiveattackbuff") then
        if Jhin.Q:IsReady() and Jhin.Q:IsInRange(args.Target.Position) then

            local AutoAttackDamage = DamageLib.GetAutoAttackDamage(Player, args.Target, true)

            if AutoAttackDamage > args.Target.Health then return
            else
                if Get4thAfterQDamage(args.Target) > args.Target.Health then
                    if Jhin.Q:Cast(args.Target) then
                        return true
                    end

                end


            end
        end
    end



end

function Jhin.OnBuffGain(obj, buffInst)


end

function Jhin.OnBuffLost(obj, buffInst)

end

function Jhin.OnGapclose(source, dash)

    if Player:GetSpell(SpellSlots.R).Name == "JhinRShot" then
        return false
    end

    if not dash.IsGapClose then
        return false
    end

    local paths = dash.GetPaths(dash)

    local endTime = paths[1].EndTime

    local endPos = paths[1].EndPos

    if source.IsEnemy then


        if dash then

            local inERange = false

            if Utils.IsInRange(Player.Position, endPos, 0, Jhin.E.Range) then
                inERange = true
            end

            if Jhin.E:IsLearned() and Jhin.E:IsReady() then


                if inERange then
                    return Input.Cast(SpellSlots.E, endPos)
                end


            end

            if Jhin.W:IsLearned() and Jhin.W:IsReady() then

                if Utils.IsInRange(Player, endPos, 0, Jhin.W.Range) then

                    if not inERange then

                        if IsMarked(source) then
                            if endTime - Game.GetTime() <= 0.75 then

                                return Input.Cast(SpellSlots.W, endPos)

                            end

                        end

                    end

                    if endTime - Game.GetTime() <= 0.75 and inERange and Jhin.E:IsReady() then

                        return Input.Cast(SpellSlots.W, endPos)

                    end

                end


            end


        end


    end
    return false

end

function Jhin.Logic.R(Target)
    if Player:GetSpell(SpellSlots.R).Name ~= "JhinRShot" then
        return false
    end
    if not Target then
        return false
    end
    if Target.IsDead then
        return false
    end
    if not Target.IsTargetable then
        return false
    end

    if Jhin.R:IsReady() then


        if Player.IsFacing(Player, Target, 30) then
            return Jhin.R:CastOnHitChance(Target, 0.6)
        end


    end

end

function Jhin.Logic.Q(Target)


    local target = Target

    if target == nil then
        return false
    end
    if target.IsDead then
        return false
    end

    if not Jhin.Q:IsReady() then
        return false
    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Jhin.Q.Range) then


        if Player.GetBuff(Player, "JhinPassiveReload") ~= nil or not Orbwalker.IsWindingUp() and not Orbwalker.IsAttackReady() then

            return Jhin.Q:Cast(target)

        end
    end

    if not Utils.IsInRange(Player.Position, target.Position, 0, Jhin.Q.Range) then

        local nearbyMinions = {}
        local nearbyHeroes = {}

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
            table.insert(nearbyMinions, v)
        end

        for p, l in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            table.insert(nearbyHeroes, l)
        end

        for e, h in ipairs(nearbyHeroes) do

            if h ~= target then
                table.insert(nearbyMinions, h)
            end

        end

        for i, v in ipairs(nearbyMinions) do


            if v.Position:Distance(target.Position) <= 400 then

                if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.Q.Range) then

                    local counter = 0

                    for s, m in pairs(nearbyMinions) do

                        if m ~= v then

                            if v.Position:Distance(m.Position) <= 450 then
                                counter = counter + 1
                            end

                        end
                    end

                    if counter <= 2 then
                        return Input.Cast(SpellSlots.Q, v)

                    end

                end
            end
        end
    end

    return false


end

function Jhin.Logic.W(Target)

    local target = Target

    local hitchance = Menu.Get("W.HitChance")

    if target == nil then
        return false
    end
    if target.IsDead then
        return false
    end

    if not Menu.Get("Combo.W.Use") then
        return false
    end

    if Player:GetSpell(SpellSlots.R).Name == "JhinRShot" then
        return false
    end

    if not Jhin.W:IsLearned() then
        return false
    end

    if not Jhin.W:IsReady() then
        return false
    end

    if not Utils.IsInRange(Player.Position, target.Position, 0, Orbwalker.GetTrueAutoAttackRange(Player)) then

        if Utils.IsInRange(Player.Position, target.Position, 0, Jhin.W.Range) then

            if IsMarked(target) then
                return Jhin.W:CastOnHitChance(target, hitchance / 100)
            end

            if not Utils.HasBuff(Player, "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvestCooldown.lua") and
                Utils.HasBuff(Player, "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvest.lua") and
                target.Health < target.MaxHealth / 2 then

                return Jhin.W:CastOnHitChance(target, hitchance / 100)

            end

            if GetWDmg(target) > target.Health then
                return Jhin.W:CastOnHitChance(target, hitchance / 100)
            end


        end


    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Jhin.W.Range) then


        if Player.GetBuff(Player, "JhinPassiveReload") ~= nil or not Orbwalker.IsWindingUp() and not Orbwalker.IsAttackReady() then

            if (IsMarked(target)) then

                return Jhin.W:CastOnHitChance(target, hitchance / 100)

            end

        end
    end

    return false


end

function Jhin.Logic.E(Target)


    local target = Target

    if target == nil then
        return false
    end
    if target.IsDead then
        return false
    end
    if not Menu.Get("Combo.E.Use") then
        return false
    end

    if Player:GetSpell(SpellSlots.R).Name == "JhinRShot" then
        return false
    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Jhin.E.Range) then

        if Player.GetBuff(Player, "JhinPassiveReload") ~= nil or not Orbwalker.IsWindingUp() and not Orbwalker.IsAttackReady() then


            return Jhin.E:CastOnHitChance(target, 0.6)

        end
    end

    return false


end

function Jhin.Logic.Waveclear()


    local minionsInQRange = {}

    if Menu.Get("Waveclear.Q.Use") then

        if Player.Mana > Player.MaxMana * (Menu.Get("WCManaQ") / 100) then

            if Jhin.Q:IsLearned() and Jhin.Q:IsReady() then

                for k, v in pairs(ObjectManager.Get("enemy", "minions")) do

                    if ValidMinion(v) then

                        if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.Q.Range) then

                            table.insert(minionsInQRange, v)

                        end


                    end

                end

                for i, minion in pairs(minionsInQRange) do

                    if minion.AsAI.Health - GetQDmg(minion.AsAI) <= 0 then

                        return Input.Cast(Jhin.Q.Slot, minion)
                    end

                end

            end

        end

    end

    if Menu.Get("Waveclear.W.Use") then

        local pPos, pointsW = Player.Position, {}

        for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            if minion then
                local pos = minion:FastPrediction(Jhin.W.Delay)
                if pos:Distance(pPos) < Jhin.W.Range and minion.IsTargetable then
                    table.insert(pointsW, pos)
                end
            end
        end

        if Player.Mana > Player.MaxMana * (Menu.Get("WCManaW") / 100) then


            local bestPos, hitCount = Geometry.BestCoveringRectangle(pointsW, Player.Position, 90)

            if bestPos and hitCount > Menu.Get("wclearhc") and Input.Cast(Jhin.W.Slot, bestPos) then
                return
            end

        end
    end

    if Menu.Get("Waveclear.E.Use") then

        if Menu.Get("Keep.One.E") then

            if Player:GetSpell(SpellSlots.E).Ammo < 2 then
                return false
            end

        end

        if Player.Mana > Player.MaxMana * (Menu.Get("WCManaE") / 100) then
            local pPos, pointsE = Player.Position, {}

            for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
                local minion = v.AsAI
                if minion then
                    local pos = minion:FastPrediction(Jhin.E.Delay)
                    if pos:Distance(pPos) < Jhin.E.Range and minion.IsTargetable then
                        table.insert(pointsE, pos)
                    end
                end
            end

            local bestPos, hitCount = Geometry.BestCoveringCircle(pointsE, 260)

            if bestPos and hitCount > Menu.Get("eclearhc") and Input.Cast(Jhin.E.Slot, bestPos) then
                return
            end

        end
    end

    return false

end

function Jhin.Logic.Lasthit()
    local minionsInQRange = {}

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do

        if ValidMinion(v) and not Orbwalker.IsLasthitMinion(v) then

            if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.W.Range) then

                if Menu.Get("LastHit.W.Use") and Player.Mana >= Player.MaxMana / 100 * Menu.Get("LHManaW") then


                    if Jhin.W:IsReady() then
                        if Utils.HasBuff(Player, "JhinPassiveReload") or not Utils.IsInRange(Player.Position, v.Position, 0, Orbwalker.GetTrueAutoAttackRange(Player)) then


                            local hpPred = HealthPrediction.GetHealthPrediction(v, 0.75, false)

                            if hpPred > 0 and hpPred < GetWDmg(v) * 0.75 then


                                if Menu.Get("LastHit.W.Siege") and v.IsSiegeMinion then

                                    return Input.Cast(Jhin.W.Slot, v.Position)

                                end

                                if not Menu.Get("LastHit.W.Siege") then

                                    return Input.Cast(Jhin.W.Slot, v.Position)

                                end


                            end

                        end

                    end

                end
            end

            if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.Q.Range) then

                if Menu.Get("LastHit.Q.Use") and Player.Mana >= Player.MaxMana / 100 * Menu.Get("LHManaQ") then


                    if Jhin.Q:IsReady() then
                        if Utils.HasBuff(Player, "JhinPassiveReload") then


                            local hpPred = HealthPrediction.GetHealthPrediction(v, 0.3, false)

                            if hpPred > 0 and hpPred < GetQDmg(v) then
                                if Menu.Get("LastHit.Q.Siege") and v.IsSiegeMinion then

                                    return Input.Cast(Jhin.Q.Slot, v)

                                end

                                if not Menu.Get("LastHit.Q.Siege") then

                                    return Input.Cast(Jhin.Q.Slot, v)

                                end

                            end

                        end

                    end

                end
            end


        end

    end


end

function Jhin.Logic.Harass()


    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do

        if ValidMinion(v) and not Orbwalker.IsLasthitMinion(v) then

            if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.W.Range) then

                if Menu.Get("Harass.W.Farm") and Player.Mana >= Player.MaxMana / 100 * Menu.Get("HFManaW") then


                    if Jhin.W:IsReady() then
                        if Utils.HasBuff(Player, "JhinPassiveReload") or not Utils.IsInRange(Player.Position, v.Position, 0, Orbwalker.GetTrueAutoAttackRange(Player)) then


                            local hpPred = HealthPrediction.GetHealthPrediction(v, 0.75, false)

                            if hpPred > 0 and hpPred < GetWDmg(v) * 0.75 then


                                if Menu.Get("Harass.W.Siege") and v.IsSiegeMinion then

                                    return Input.Cast(Jhin.W.Slot, v.Position)

                                end

                                if not Menu.Get("Harass.W.Siege") then

                                    return Input.Cast(Jhin.W.Slot, v.Position)

                                end
                            end
                        end
                    end
                end
            end

            if Utils.IsInRange(Player.Position, v.Position, 0, Jhin.Q.Range) then

                if Menu.Get("Harass.Q.Farm") and Player.Mana >= Player.MaxMana / 100 * Menu.Get("HFManaQ") then


                    if Jhin.Q:IsReady() then
                        if Utils.HasBuff(Player, "JhinPassiveReload") then


                            local hpPred = HealthPrediction.GetHealthPrediction(v, 0.3, false)

                            if hpPred > 0 and hpPred < GetQDmg(v) then
                                if Menu.Get("Harass.Q.Siege") and v.IsSiegeMinion then

                                    return Input.Cast(Jhin.Q.Slot, v)

                                end

                                if not Menu.Get("Harass.Q.Siege") then

                                    return Input.Cast(Jhin.Q.Slot, v)

                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local target = TS:GetTarget(Jhin.W.Range)

    if target == nil then
        return
    end

    if Menu.Get("Harass.Q.Use") then

        if Jhin.Q:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Jhin.Q.Range) then

            if Player.Mana > Player.MaxMana * (Menu.Get("Harass.Q.Mana") / 100) then

                return Input.Cast(SpellSlots.Q, target)

            end
        end

    end

    if Menu.Get("Harass.W.Use") then

        if Player.Mana > Player.MaxMana * (Menu.Get("Harass.W.Mana") / 100) then


            if Jhin.W:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Jhin.W.Range) then

                return Jhin.W:CastOnHitChance(target, Menu.Get("Harass.W.HitChance") / 100)

            end

        end
    end

    return false


end

function Jhin.Logic.Combo()

    local Target = TS:GetTarget(Jhin.R.Range, true)

    if not Target then
        return false
    end

    if Player:GetSpell(SpellSlots.R).Name ~= "JhinR" then


        if Jhin.Logic.R(Utils.GetRTarget()) then
            return true
        end

        return true

    end

    if Jhin.Logic.Q(Target) then
        return true
    end

    if Jhin.Logic.W(Target) then
        return true
    end

    if Jhin.Logic.E(Target) then
        return true
    end

    return false


end

function Jhin.Logic.Flee()


end

function Jhin.OnExtremePriority()

    local spell = Player.ActiveSpell

    if spell then
        if spell.Name == "JhinR" then
            JhinRLoc = Player.Position
            Orbwalker.BlockMove(true)
            Orbwalker.BlockAttack(true)
        end
    end

end

function Jhin.OnDraw()

    if Menu.Get("Drawings.W") then
        Renderer.DrawCircle3D(Player.Position, Jhin.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, Jhin.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if not Player.IsOnScreen then
        return false
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, Jhin.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Jhin.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end


end

function Jhin.OnHeroImmobilized(Source, EndTime, IsStasis)

    if Player:GetSpell(SpellSlots.R).Name ~= "JhinR" then
        return false
    end

    if Player.ActiveSpell then
        if Player.ActiveSpell.Name == "JhinR" then
            return false
        end
    end
    -- if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "JhinR") then

    if Source.IsEnemy then
        if IsStasis then


            if Utils.IsInRange(Player.Position, Source.Position, 0, Jhin.W.Range) then
                if EndTime - Game.GetTime() < 0.7 then
                    return Jhin.W:Cast(Source.Position)
                end

            end

            if Utils.IsInRange(Player.Position, Source.Position, 0, Jhin.E.Range) then
                if Jhin.E:IsLearned() and Jhin.E:IsReady() then
                    return Jhin.E:Cast(Source.Position)
                end

            end

        end
    end


end

function Jhin.Logic.Auto()

    if Player.IsRecalling then
        return
    end

    if JhinRLoc ~= nil then

        if Player.Position == JhinRLoc then

            Orbwalker.BlockMove(true)
            Orbwalker.BlockAttack(true)

        end

    end

    if Player:GetSpell(SpellSlots.R).RemainingCooldown > 5 then

        Orbwalker.BlockMove(false)
        Orbwalker.BlockAttack(false)
        JhinRLoc = nil

    end

    --- SEMI R
    if Player.ActiveSpell and Player.ActiveSpell.Name == "JhinR" then

        if Menu.Get("SemiR") then
            local target = RB.GetClosestHeroTo(Renderer.GetMousePos(), "enemy", TS:GetTargets(Jhin.R.Range, true))
            if not target then goto skipSemiR end
            if Input.Cast(SpellSlots.R, target.Position) then return true end
        end


    end

    ::skipSemiR::
    --- SEMI W
    if Jhin.W:IsReady() then

        if Menu.Get("SemiW") then
            local target = RB.GetClosestHeroTo(Renderer.GetMousePos(), "enemy", TS:GetTargets(Jhin.W.Range, true))
            if not target then goto skipSemiW end
            if Input.Cast(SpellSlots.W, target.Position) then return true end
        end
    end

    ::skipSemiW::
    if Utils.NoLag(1) then


        if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "JhinR") then

            if Player.ActiveSpell then
                -- print(Player.ActiveSpell.Name)

            end
            if Menu.Get("Auto.Extend") then
                if Utils.HasBuff(Player, "jhinpassiveattackbuff") then

                    if Player.Buffs["jhinpassiveattackbuff"] ~= nil then

                        if Player.Buffs["jhinpassiveattackbuff"].DurationLeft < 1 and Jhin.E:IsReady() then

                            return Input.Cast(SpellSlots.E, Player.Position)

                        end
                    end

                end

            end

            local targets = ObjectManager.Get("enemy", "heroes")

            if Menu.Get("Auto.Galeforce.Use") then
                for i, v in pairs(targets) do

                    if Utils.IsInRange(Player.Position, v.Position, 0, 1100) then

                        if Utils.GaleForceDmg(v) > v.Health then

                            if not v.IsDead then

                                local slot = Utils.GetGaleforceSlot()

                                if slot ~= 100 then
                                    if Player.GetSpell(Player, slot).RemainingCooldown == 0 then
                                        return Input.Cast(slot, v.Position)
                                    end

                                end


                            end

                        end


                    end

                end

            end

            if Menu.Get("Auto.E.Chain") then

                if Player.GetBuff(Player, "JhinPassiveReload") ~= nil or not Orbwalker.IsWindingUp() and not Orbwalker.IsAttackReady() then
                    local pPos, wRange = Player.Position, Jhin.E.Range
                    if Jhin.E:IsReady() then


                        for i, v in pairs(targets) do
                            local hero = v.AsHero
                            if hero and hero.IsTargetable and Utils.IsInRange(Player.Position, hero.Position, 0, Jhin.E.Range) then

                                if not hero.CanMove or hero.IsSlowed or hero.IsTaunted or hero.IsGrounded then
                                    return Jhin.E:CastOnHitChance(hero, 0.6)
                                end


                            end
                        end

                    end

                end


            end

            if Menu.Get("Auto.W.Chain") then

                local pPos, wRange = Player.Position, Jhin.W.Range
                if Jhin.W:IsReady() then

                    for i, v in pairs(targets) do
                        local hero = v.AsHero
                        if hero and hero.IsTargetable and Utils.IsInRange(Player.Position, hero.Position, 0, Jhin.W.Range) then

                            if not hero.CanMove and not hero.IsDashing or hero.IsSlowed or hero.IsTaunted or hero.IsGrounded then

                                if IsMarked(hero) then

                                    return Jhin.W:CastOnHitChance(hero, 0.6)

                                end
                            end


                        end
                    end

                end


            end

        end

    end

end

function Jhin.OnDrawDamage(target, dmgList)

    if not Menu.Get("Draw.ComboDamage") then
        return
    end

    local totalDmg = 0

    totalDmg = totalDmg + DamageLib.GetAutoAttackDamage(Player, target, true)
    totalDmg = totalDmg + Utils.GaleForceDmg(target)
    totalDmg = totalDmg + GetQDmg(target)

    table.insert(dmgList, totalDmg)


end

function Jhin.OnTick()
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Jhin.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic() then
            return true
        end
    end

    if Jhin.Logic.Auto() then
        return true
    end

    return false

end

function Jhin.OnPostAttack(target)

end

function Jhin.LoadMenu()
    Menu.RegisterMenu("BigJhin", "BigJhin", function()
        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)

        Menu.NewTree("BigHeroCombo", "Combo", function()

            Menu.Text("")
            Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
            Menu.Checkbox("Combo.W.Use", "Cast [W]", true)
            Menu.ColoredText("Hitchance:", 0xE3FFDF)
            Menu.Slider("W.HitChance", "%", 60, 1, 100, 1)
            Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
            Menu.NextColumn()
            Menu.Text("")
            Menu.ColoredText("To ULT push [R] and then hold spacebar! ", 0xE3FFDF)
            Menu.Text("")

            Menu.ColoredText("[[ Semi Casts (Hitchance will be ignored) ]]", 0xD9EF47FF, true)
            Menu.Text("")

            Menu.Keybind("SemiR", "Semi [R] on closest target to mouse or forced target", string.byte("T"), false, false, false)
            Menu.Keybind("SemiW", "Semi [W] on closest target to mouse or forced target", string.byte("Y"), false, false, false)

            Menu.Text("")
        end)

        Menu.NewTree("BigHeroHarass", "Harass [C]", function()

            Menu.Text("")
            Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
            Menu.Text("Minimum Percentage Mana to Cast [Q]")
            Menu.Slider("Harass.Q.Mana", "%", 50, 0, 100, 5)

            Menu.Text("")
            Menu.Separator()
            Menu.Text("")

            Menu.Checkbox("Harass.W.Use", "Cast [W]", true)
            Menu.Text("Minimum Percentage Mana to Cast [W]")
            Menu.Slider("Harass.W.Mana", "%", 50, 0, 100, 5)
            Menu.ColoredText("[W] Hitchance", 0xE3FFDF)
            Menu.Slider("Harass.W.HitChance", "%", 60, 1, 100, 1)
            Menu.Text("")

            Menu.NewTree("HarassFarm", "Farming Options", function()

                Menu.Text("")
                Menu.Checkbox("Harass.Q.Farm", "Cast [Q] To Secure Minion", true)
                Menu.Checkbox("Harass.Q.Siege", "Cast Only On Cannon Minion", false)
                Menu.Text("Do Not Cast If Mana Below Percent")
                Menu.Slider("HFManaQ", "%", 30, 0, 100, 1)

                Menu.Text("")
                Menu.Separator()
                Menu.Text("")

                Menu.Checkbox("Harass.W.Farm", "Cast [W] To Secure Minion", true)
                Menu.Checkbox("Harass.W.Siege", "Cast Only On Cannon Minion", true)
                Menu.Text("Do Not Cast If Mana Below Percent")
                Menu.Slider("HFManaW", "%", 30, 0, 100, 1)
                Menu.Text("")

            end)
            Menu.Text("")

        end)

        Menu.NewTree("BigHeroLastHit", "LastHit Settings [X]", function()

            Menu.Text("")
            Menu.Checkbox("LastHit.Q.Use", "Cast [Q] To Secure Minion", true)
            Menu.Checkbox("LastHit.Q.Siege", "Cast Only On Cannon Minion", false)
            Menu.Text("Do Not Cast If Mana Below Percent")
            Menu.Slider("LHManaQ", "%", 30, 0, 100, 1)

            Menu.Text("")
            Menu.Separator()
            Menu.Text("")

            Menu.Checkbox("LastHit.W.Use", "Cast [W] To Secure Minion", true)
            Menu.Checkbox("LastHit.W.Siege", "Cast Only On Cannon Minion", true)
            Menu.Text("Do Not Cast If Mana Below Percent")
            Menu.Slider("LHManaW", "%", 30, 0, 100, 1)
            Menu.Text("")


        end)

        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()

            Menu.Text("")
            Menu.Checkbox("Waveclear.Q.Use", "Cast [Q] On Killable Minion", true)
            Menu.Text("Do Not Cast If Mana Below Percent")
            Menu.Slider("WCManaQ", "%", 30, 0, 100, 1)

            Menu.Text("")
            Menu.Separator()
            Menu.Text("")

            Menu.Checkbox("Waveclear.W.Use", "Cast [W] To Waveclear", true)
            Menu.Slider("wclearhc", "Minions Hit", 3, 0, 6, 1)
            Menu.Text("Do Not Cast If Mana Below Percent")
            Menu.Slider("WCManaW", "%", 30, 0, 100, 1)

            Menu.Text("")
            Menu.Separator()
            Menu.Text("")

            Menu.Checkbox("Waveclear.E.Use", "Cast [E] To Waveclear", true)
            Menu.Checkbox("Keep.One.E", "Keep One [E] Charge", true)
            Menu.Slider("eclearhc", "Minions Hit", 3, 0, 6, 1)
            Menu.Text("Do Not Cast If Mana Below Percent")
            Menu.Slider("WCManaE", "%", 30, 0, 100, 1)
            Menu.Text("")


        end)

        Menu.NewTree("Auto Settings", "Auto Settings", function()

            Menu.Checkbox("Auto.W.Chain", "Auto [W] CC Chain", true)
            Menu.Checkbox("Auto.E.Chain", "Auto [E] on CC", true)
            Menu.Checkbox("Auto.Galeforce.Use", "Cast Galeforce To Kill", true)
            Menu.Checkbox("Auto.Extend", "Use [E] To Extend Fourth Shot Timer", true)
            Menu.Text("This will cast [E] when your fourth shot is about to reload")
            Menu.Text("resetting the timer and giving you 2x or 3x as much time to shoot it")


        end)

        Menu.NewTree("Drawings", "Drawings", function()


            Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw [E] Range", true)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.W", "Draw [W] Range", true)
            Menu.ColorPicker("Drawings.W.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.R", "Draw [R] Range", true)
            Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)
            Menu.Checkbox("Draw.ComboDamage", "Draw Combo Damage [Next AA + Q + Galeforce]", true)


        end)
    end)
end

function OnLoad()

    INFO("Welcome to BigJhin, enjoy your stay")

    Jhin.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Jhin[EventName] then
            EventManager.RegisterCallback(EventId, Jhin[EventName])
        end
    end

    return true

end
