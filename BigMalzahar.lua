--[[
    BigMalzahar
]]

if Player.CharName ~= "Malzahar" then
    return false
end

module("Malzahar", package.seeall, log.setup)
clean.module("Malzahar", package.seeall, log.setup)






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
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };
local lastETime = 0
local Player = ObjectManager.Player.AsHero
local ScriptVersion = "1.1.3"
local ScriptLastUpdate = "26. February 2022"
local buffCount = 0
local Nav = _G.CoreEx.Nav
local Colorblind = false
local text = "Enable"
local BuffTypes
BuffTypes = _G.CoreEx.Enums.BuffTypes
CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigMalzahar.lua", ScriptVersion)


-- Globals
local Malzahar = {}
local Utils = {}

Malzahar.TargetSelector = nil
Malzahar.Logic = {}

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


-- Malzahar Spells
Malzahar.Q = SpellLib.Skillshot({


    -- Edit
    --Call of the Void
    --TARGET RANGE: 900
    --CAST TIME: 0.25
    --COST: 80 MANA
    --COOLDOWN: 6

    Slot = Enums.SpellSlots.Q,
    Range = 900,
    Radius = 90,
    Delay = 0.65,
    Speed = math.huge,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type = "Circular",
    UseHitbox = true


})
Malzahar.W = SpellLib.Active({

    Slot = Enums.SpellSlots.W,
    Type = "Active",

})
Malzahar.E = SpellLib.Targeted({

    -- TARGET RANGE: 650
    --EFFECT RADIUS: 650
    --CAST TIME: 0.25

    Slot = Enums.SpellSlots.E,
    Range = 650,
    Radius = 650,
    Delay = 0.25,


})
Malzahar.R = SpellLib.Targeted({

    Slot = Enums.SpellSlots.R,
    Range = 700,
    Delay = 0.005

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

    if not UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
            Enums.SpellStates.Ready then


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

    if not Malzahar.Q:IsLearned() or not Malzahar.Q:IsReady() then
        return 0

    end

    local dmg = 55 * Malzahar.Q:GetLevel() + 25 + 0.8 * Player.TotalAP

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, dmg)

end
function GetWDmg(target)

    if target == nil then
        return 0
    end

    if not Malzahar.W:IsReady() then
        return 0
    end

    -- 15 / 22.5 / 30 / 37.5 / 45 (+ 100% AD) (+ 50% AP)

    local dmg = 3 + 1 * Malzahar.W:GetLevel() + 0.1 * Player.TotalAP * target.MaxHealth / 100
    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, dmg)


end
function GetRDmg(target)

    if target == nil then
        return 0
    end

    if not Malzahar.R:IsReady() then
        return 0
    end

    -- 15 / 22.5 / 30 / 37.5 / 45 (+ 100% AD) (+ 50% AP)

    local dmg = 150 * Malzahar.R:GetLevel() + 100 + 1.3 * Player.TotalAP

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, dmg)


end
function GetEDmg(target)

    if target == nil then
        return 0
    end

    if not Malzahar.E:IsReady() then
        return 0
    end

    local dmg = 60 * Malzahar.E:GetLevel() + 20 + .8 * Player.TotalAP

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, dmg)


end
function GetPassiveDamage(target)

    local baseDmg = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)

end
function QEUnavailable()

    local q = Malzahar.Q:IsReady()
    local e = Malzahar.E:IsReady()

    if not q and not e then
        return true
    end

    return false


end

-- Utils
function Utils.ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 and not minion.IsDead
end
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
function Utils.AlliesInRangeOfTarget(target, range)

    local NumberOfAlliesInRange = 0

    if not target then
        WARN("AlliesInRangeOfTarget called without a Target")
        return
    end

    for i, ally in pairs(ObjectManager.Get("ally", "heroes")) do

        if not ally.IsMe then

            if ally:Distance(target.Position) <= range then
                NumberOfAlliesInRange = NumberOfAlliesInRange + 1
            end

        end

    end

    return NumberOfAlliesInRange

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

        if spell.Name == "ChampionLightBinding" then
            return true
        end
        if spell.Name == "ChampionLightStrikeKugel" then
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
function Utils.HasSashReady(t)


    local slot = 100

    if t.Items[0] ~= nil then
        if t.Items[0].ItemId == 3140 or t.Items[0].ItemId == 3139 or t.Items[0].ItemId == 6035  then
            slot = 6


        end
    end

    if t.Items[1] ~= nil then
        if t.Items[1].ItemId == 3140 or t.Items[1].ItemId == 3139 or t.Items[1].ItemId == 6035  then
            slot = 7

        end
    end

    if t.Items[2] ~= nil then
        if t.Items[2].ItemId == 3140 or t.Items[2].ItemId == 3139 or t.Items[2].ItemId == 6035  then
            slot = 8

        end
    end

    if t.Items[3] ~= nil then
        if t.Items[3].ItemId == 3140 or t.Items[3].ItemId == 3139 or t.Items[3].ItemId == 6035  then
            slot = 9

        end
    end

    if t.Items[4] ~= nil then
        if t.Items[4].ItemId == 3140 or t.Items[4].ItemId == 3139 or t.Items[4].ItemId == 6035  then
            slot = 10

        end
    end

    if t.Items[5] ~= nil then
        if t.Items[5].ItemId == 3140 or t.Items[5].ItemId == 3139 or t.Items[5].ItemId == 6035  then
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
function Utils.CountMinionsInRangeOf(target, range, type)
    local amount = 0

    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and target:Distance(minion) < range then
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
function Utils.GetBuff(target, buff)

    local returnBuff = nil

    for i, v in pairs(target.Buffs) do
        if v.Name == buff then
            return v
        end

    end

    return returnBuff

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
            if
            Utils.IsValidTarget(Object) and
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
function Utils.EnabledAndMinimumMana(useID, manaID)
    local power = 10 ^ 2
    return Menu.Get(useID) and Player.Mana >= math.floor(Player.MaxMana / 100 * Menu.Get(manaID) * power) / power
end
function Utils.EnemyMinionsInRange(range)

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
function Utils.GetArea()
    return Nav.GetMapArea(Player.Position)["Area"]
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
function Utils.IsInJungle()
    if string.match(Utils.GetArea(), "Lane") then
        return false
    else
        return true
    end
end


-- Event Functions
function Malzahar.OnProcessSpell(Caster, SpellCast)


end
function Malzahar.OnUpdate()


end
function Malzahar.OnBuffGain(obj, buffInst)


end
function Malzahar.OnBuffLost(obj, buffInst)


end
function Malzahar.OnExtremePriority(lagFree)


end
function Malzahar.OnCreateObject(obj, lagFree)


end
function Malzahar.OnTick(lagFree)

    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Malzahar.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Malzahar.Logic.Auto(lagFree) then
        return true
    end

    --[[


        --]]

end
function Malzahar.OnHeroImmobilized(Source, EndTime, IsStasis)

end
function Malzahar.OnPreAttack(args)


end
function Malzahar.OnPostAttack(target)

end
function Malzahar.OnInterruptibleSpell(source, spellCast, danger, endTime, canMoveDuringChannel)

    if source.IsHero and source.IsEnemy and Malzahar.Q:IsInRange(source) then
        if Malzahar.Q:IsReady() and Menu.Get("QCancel") then
            if danger < 5 then

                local pred = Malzahar.Q:GetPrediction(source)
                if pred and pred.HitChance >= 0.35 then
                    if Malzahar.Q:Cast(pred.CastPosition) then
                        return
                    end
                end
            end
        end

    end

end
function Malzahar.OnGapclose(source, dashInstance)

    if source.IsHero and source.IsEnemy and Malzahar.Q:IsInRange(source) then
        if Malzahar.Q:IsReady() and Menu.Get("QDash") then

            local pred = Malzahar.Q:GetPrediction(source)
            if pred and pred.HitChance >= 0.75 then
                if Malzahar.Q:Cast(pred.CastPosition) then
                    return
                end
            end

        end
    end
end


-- Drawings
function Malzahar.OnDrawDamage(target, dmgList)

    if not target then
        return
    end
    if not target.IsAlive then
        return
    end

    if Menu.Get("DmgDrawings.Q") then
        table.insert(dmgList, GetQDmg(target))

    end
    if Menu.Get("DmgDrawings.E") then
        table.insert(dmgList, GetEDmg(target))

    end

    if Menu.Get("DmgDrawings.R") then
        table.insert(dmgList, GetRDmg(target))

    end

end
function Malzahar.OnDraw()


    if not Player.IsOnScreen then
        return false
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, Malzahar.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, Malzahar.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Malzahar.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end

    local enemiesWithSpaceAidsList = {}
    for i, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do

        if not v.IsAlive then
            return false
        end

        local targetHasEBuff = false

        if Utils.GetBuff(v, "MalzaharE") ~= nil then
            targetHasEBuff = true
        end

        if targetHasEBuff then
            table.insert(enemiesWithSpaceAidsList, v)
        end


    end
    -- Renderer.DrawCircle3D(Renderer.GetMousePos(), 100, 5, 5, 0xEF476FFF, false)


end


-- Spell Logic
function Malzahar.Logic.R(Target)


end
function Malzahar.Logic.Q(Target)


end
function Malzahar.Logic.W(lagFree)


end
function Malzahar.Logic.E(Target)

end



-- Orbwalker Logic
function Malzahar.Logic.Lasthit(lagFree)

end
function Malzahar.Logic.Flee(lagFree)


end
function Malzahar.Logic.Waveclear(lagFree)

    if lagFree == 4 then
        if Menu.Get("WPush") then
            if Malzahar.W:IsReady() then
                local WaveTarget = Orbwalker.GetLastTarget()
                if WaveTarget then
                    if WaveTarget.IsTurret then
                        if Orbwalker:TimeSinceLastAttack() < 1 then
                            if Utils.CountMinionsInRangeOf(WaveTarget, 500, "ally") >= 1 then
                                if Malzahar.W:Cast() then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end

        for i, v in ipairs(Utils.EnemyMinionsInRange(Malzahar.E.Range)) do


            if Utils.EnabledAndMinimumMana("Waveclear.E.Use", "Waveclear.E.Mana") then
                if Malzahar.E:IsReady() then
                    if v.Health < GetEDmg(v) then
                        if Utils.GetBuff(v, "MalzaharE") == nil then

                            if Utils.CountMinionsInRangeOf(v, 650, "enemy") > Menu.Get("EWaveclearHitCount") then
                                if Malzahar.E:Cast(v) then
                                    WARN("Casting E Because " .. Utils.CountMinionsInRangeOf(v, 650, "enemy") .. " are in range of target")
                                    return true
                                end
                            end
                        end
                    end
                end
            end

            if Utils.GetBuff(v, "MalzaharE") ~= nil then

                if Utils.EnabledAndMinimumMana("Waveclear.W.Use", "Waveclear.W.Mana") then

                    if Malzahar.W:IsReady() then
                        return Malzahar.W:Cast()
                    end

                end

                if Utils.EnabledAndMinimumMana("Waveclear.Q.Use", "Waveclear.Q.Mana") then

                    if Malzahar.Q:IsReady() then
                        return Malzahar.Q:Cast(v)

                    end

                end


            end


        end
        if Utils.EnabledAndMinimumMana("Waveclear.Q.Use", "Waveclear.Q.Mana") then
            local bestPos, hitCount = Malzahar.Q:GetBestCircularCastPos(Utils.EnemyMinionsInRange(Malzahar.Q.Range), Malzahar.Q.Radius)
            if bestPos and hitCount >= Menu.Get("QWaveclearHitCount") then
                if Malzahar.Q:IsReady() then
                    Malzahar.Q:Cast(bestPos)
                end
            end

        end

        if Utils.IsInJungle() then

            for i, v in ipairs(Utils.NeutralMinionsInRange(Malzahar.E.Range)) do


                if Malzahar.E:IsReady() then

                    if Malzahar.E:Cast(v) then
                        return true
                    end

                end

                if Utils.GetBuff(v, "MalzaharE") ~= nil then

                    if Malzahar.W:IsReady() then
                        return Malzahar.W:Cast()
                    end

                    if Malzahar.Q:IsReady() then
                        return Malzahar.Q:Cast(v)

                    end


                end


            end

            local bestPos, hitCount = Malzahar.Q:GetBestCircularCastPos(Utils.NeutralMinionsInRange(Malzahar.Q.Range), Malzahar.Q.Radius)
            if bestPos and hitCount >= 1 then
                if Malzahar.Q:IsReady() then

                    if Malzahar.Q:IsInRange(bestPos) then
                        Malzahar.Q:Cast(bestPos)
                    end
                end
            end

        end

    end


end
function Malzahar.Logic.Harass(lagFree)
    local t = TS:GetTarget(Malzahar.Q.Range)
    if not t then
        return false
    end

    buffCount = nil
    local targetHasEBuff = false
    local playerHasWBuff = false

    if Utils.GetBuff(Player, "MalzaharW") ~= nil then
        buffCount = Utils.GetBuff(Player, "MalzaharW").Count
        playerHasWBuff = true
    end

    if Utils.GetBuff(t, "MalzaharE") ~= nil then
        targetHasEBuff = true
    end

    if QEUnavailable() then
        if Menu.Get("despairW") then
            if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
                if Utils.EnabledAndMinimumMana("Harass.W.Use", "Harass.W.Mana") and Malzahar.W:Cast() then
                    return true
                end
            end

        end
    end

    if targetHasEBuff then
        if playerHasWBuff then
            if buffCount and buffCount == 2 then

                if Malzahar.W:IsReady() then
                    if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                        if Utils.EnabledAndMinimumMana("Harass.W.Use", "Harass.W.Mana") and Malzahar.W:Cast() then
                            return true
                        end
                    end

                end

            end

        end
    end

    if targetHasEBuff then

        if playerHasWBuff then
            if buffCount ~= nil then
                if buffCount == 2 then

                    if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
                        if Malzahar.W:IsReady() then
                            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                                if Utils.EnabledAndMinimumMana("Harass.W.Use", "Harass.W.Mana") and Malzahar.W:Cast() then
                                    return true
                                end

                            end

                        end
                    end

                end

            end

        end
    end

    if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
        if Malzahar.E:IsReady() then
            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                if Utils.EnabledAndMinimumMana("Harass.E.Use", "Harass.E.Mana") and Malzahar.E:Cast(t) then
                    return true
                end

            end

        end
    end

    if targetHasEBuff then

        if Utils.GetBuff(Player, "MalzaharW") ~= nil then
            if buffCount ~= nil then
                if buffCount == 2 then
                    if Malzahar.W:IsReady() then
                        if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                            if Utils.EnabledAndMinimumMana("Harass.W.Use", "Harass.W.Mana") and Malzahar.W:Cast() then
                                return true
                            end

                        end

                    end

                end

            end

        end
    end

    if Malzahar.Q:IsReady() then
        if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
            if Utils.EnabledAndMinimumMana("Harass.Q.Use", "Harass.Q.Mana") and Malzahar.Q:CastOnHitChance(t, Menu.Get("Harass.Q.HitChance") / 100) then
                return true
            end

        end

    end

    if targetHasEBuff then
        if Malzahar.E:IsReady() then
            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                if Utils.EnabledAndMinimumMana("Harass.W.Use", "Harass.W.Mana") and Malzahar.W:Cast() then
                    return true
                end

            end

        end
    end
end
function Malzahar.Logic.Combo(lagFree)



    if lagFree == 2 or lagFree == 1 then

        local t = TS:GetTarget(Malzahar.Q.Range)
        if not t then
            return false
        end

        buffCount = nil
        local targetHasEBuff = false
        local playerHasWBuff = false

        if Utils.GetBuff(Player, "MalzaharW") ~= nil then
            buffCount = Utils.GetBuff(Player, "MalzaharW").Count
            playerHasWBuff = true
        end

        if Utils.GetBuff(t, "MalzaharE") ~= nil then
            targetHasEBuff = true
        end

        if QEUnavailable() then
            if Menu.Get("despairW") then
                if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
                    if Menu.Get("UseW") then
                        if Malzahar.W:Cast() then
                            return true
                        end
                    end
                end
            end
        end

        if targetHasEBuff then
            if playerHasWBuff then
                if buffCount ~= nil then
                    if buffCount == 2 then
                        if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
                            if Malzahar.W:IsReady() then
                                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                                    if Menu.Get("UseW") then
                                        if Malzahar.W:Cast() then
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
            if Malzahar.E:IsReady() then
                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                    if Menu.Get("UseE") then
                        if Malzahar.E:Cast(t) then
                            return true
                        end
                    end
                end
            end
        end

        if targetHasEBuff then
            if playerHasWBuff then
                if buffCount ~= nil then
                    if buffCount == 2 then
                        if Utils.IsInRange(Player.Position, t.Position, 0, Malzahar.E.Range) then
                            if Malzahar.W:IsReady() then
                                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                                    if Menu.Get("UseW") then
                                        if Malzahar.W:Cast() then
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if Menu.Get("R" .. t.CharName) then
            if Malzahar.R:IsReady() then
                if Utils.IsInRange(t.Position, Player.Position, 0, Malzahar.R.Range) then
                    if Malzahar.E:IsReady() then
                        if Utils.IsInRange(t.Position, Player.Position, 0, Malzahar.E.Range) then
                            if Malzahar.E:IsReady() then


                                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                                    if Menu.Get("UseE") then
                                        if Malzahar.E:Cast(t) then
                                            return true
                                        end

                                    end

                                end

                            end
                        end
                    end
                    if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                        if Malzahar.W:IsReady() then
                            if Menu.Get("UseW") then
                                return Input.Cast(SpellSlots.W)

                            end
                        end

                    end
                    if Menu.Get("UseR") then
                        if not t.HasBuffOfType(t, BuffTypes.SpellImmunity) then
                            if not t.HasBuffOfType(t, BuffTypes.SpellShield) then


                                if not Menu.Get("SashCheck") then
                                    if Input.Cast(SpellSlots.R, t) then
                                        return true
                                    end
                                end

                                if Menu.Get("SashCheck") then

                                    local slot = Utils.HasSashReady(t)

                                    if slot ~= 100 then
                                        if Player.GetSpell(t, slot).RemainingCooldown > 2.5 then
                                            if Input.Cast(SpellSlots.R, t) then
                                                return true
                                            end
                                        end
                                    else
                                        if Input.Cast(SpellSlots.R, t) then
                                            return true
                                        end
                                    end

                                end

                            end
                        end
                    end
                end
            end
        end

        if Malzahar.Q:IsReady() then
            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                if Menu.Get("UseQ") then
                    if Malzahar.Q:CastOnHitChance(t, Menu.Get("QHitChance") / 100) then
                        return true
                    end
                end
            end
        end

        if targetHasEBuff then
            if Malzahar.E:IsReady() then
                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                    if Menu.Get("UseW") then
                        if Malzahar.W:Cast() then
                            return true
                        end
                    end
                end
            end
        end

    end


end
function Malzahar.Logic.Auto(lagFree)


    if Colorblind then
        text = "Disable"
    end

    if Menu.Get("ERCombo") then

        if lagFree == 4 or lagFree == 3 then
            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                Input.MoveTo(Renderer.GetMousePos())
            end
        end

        local target = TS:GetTarget(Malzahar.E.Range)
        if target then

            if Malzahar.E:IsReady() then
                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then

                    if Malzahar.E:Cast(target) then
                        return true
                    end
                end
            end

            if Malzahar.R:IsReady() then
                if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                    if not target.HasBuffOfType(target, BuffTypes.SpellImmunity) then
                        if not target.HasBuffOfType(target, BuffTypes.SpellShield) then
                            if Malzahar.R:Cast(target) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    if Menu.Get("SemiR") then
        if lagFree == 4 or lagFree == 3 then
            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then
                Input.MoveTo(Renderer.GetMousePos())
            end
        end

        if not Malzahar.R:IsReady() then
            return
        end

        local enemyHeroes = TS:GetTargets(Malzahar.R.Range)

        if #enemyHeroes < 1 then
            return
        end

        local closestEnemy = enemyHeroes[1]

        for i, v in pairs(enemyHeroes) do
            if Renderer.GetMousePos():Distance(v.Position) < Renderer.GetMousePos():Distance(closestEnemy.Position) then
                closestEnemy = v
            end
        end

        if not closestEnemy.HasBuffOfType(closestEnemy, BuffTypes.SpellImmunity) then
            if not closestEnemy.HasBuffOfType(closestEnemy, BuffTypes.SpellShield) then
                if Malzahar.R:Cast(closestEnemy) then
                    return true
                end
            end
        end
    end

    if lagFree == 1 then


        if Menu.Get("rForce") then

            if Malzahar.E:IsReady() then
                Malzahar.R.Range = Malzahar.E.Range
            end


        end

        if not Malzahar.E:IsReady() or not Menu.Get("rForce") then
            Malzahar.R.Range = 700
        end

    end

    if lagFree == 2 then


        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do


            if Menu.Get("Qkill") then
                if HealthPrediction.GetKillstealHealth(v, 0, "Magical") <= GetQDmg(v) then
                    if Malzahar.Q:IsReady() then
                        if Malzahar.Q:IsInRange(v) then
                            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then

                                if Menu.Get("QKS") then
                                    if Malzahar.Q:CastOnHitChance(v, 0.45) then
                                        return true
                                    end
                                else

                                    if Utils.AlliesInRangeOfTarget(v, 600) == 0 then
                                        if Malzahar.Q:CastOnHitChance(v, 0.45) then
                                            return true
                                        end
                                    end

                                end


                            end

                        end
                    end
                end
            end

            if Menu.Get("Ekill") then
                if HealthPrediction.GetKillstealHealth(v, 0, "Magical") <= GetEDmg(v) then
                    if Malzahar.E:IsReady() then
                        if Malzahar.E:IsInRange(v) then
                            if not Player.ActiveSpell or (Player.ActiveSpell and Player.ActiveSpell.Name ~= "MalzaharR") then

                                if Menu.Get("EKS") then
                                    if Malzahar.E:Cast(v) then
                                        return true
                                    end
                                else

                                    if Utils.AlliesInRangeOfTarget(v, 600) == 0 then
                                        if Malzahar.E:Cast(v) then
                                            return true
                                        end
                                    end

                                end

                            end

                        end
                    end
                end
            end
        end

    end


end

-- Menu
function Malzahar.LoadMenu()

    Menu.RegisterMenu("BigMalzahar", "BigMalzahar", function()
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
        Menu.Button("Colorblind", "Toggle Colorblind Mode", function()
            if Colorblind then
                Colorblind = false
            else
                Colorblind = true
            end

        end)
        Menu.Text("")
        Menu.Text("")
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

                Menu.NextColumn()
                Menu.Slider("QHitChance", "HitChance %", 45, 1, 100, 1)
                Menu.NextColumn()
                Menu.Checkbox("UseE", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [E]", Utils.GetMenuColor("UseE"))
                Menu.NextColumn()
                Menu.Text("")
                Menu.NextColumn()
                Menu.Checkbox("UseW", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [W]", Utils.GetMenuColor("UseW"))
                Menu.NextColumn()
                Menu.Text("")
                Menu.NextColumn()
                Menu.Checkbox("UseR", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [R]", Utils.GetMenuColor("UseR"))
                Menu.NextColumn()
                Menu.Text("")

            end)
            Menu.Text("")
            Menu.Text("")
            Menu.Text("")
            Menu.ColoredText("[ Hotkeys ]", 0xEFC347FF, true)
            Menu.Text("")

            Menu.Keybind("ERCombo", "[E] ~> [R]", string.byte("T"), false, false, false)
            Menu.Keybind("SemiR", "[R] On Closest To Mouse", string.byte("Y"), false, false, false)

            Menu.Text("")
            Menu.ColoredText("[ Extra Combo Settings ]", 0xEFC347FF, true)
            Menu.Text("")
            Menu.Text("")
            Menu.Checkbox("rForce", "", true)
            Menu.SameLine()
            Menu.ColoredText("Force [E] Before [R] If Available", Utils.GetMenuColor("rForce"))
            Menu.Checkbox("despairW", "", true)
            Menu.SameLine()
            Menu.ColoredText("Use [W] When Everything Else Is On CD", Utils.GetMenuColor("despairW"))
            Menu.Text("")
            Menu.ColoredText("[ Whitelist ]", 0xEFC347FF, true)
            Menu.Text("")
            Menu.NewTree("RWhitelist", "R Whitelist", function()
                Menu.Text("")
                Menu.Checkbox("SashCheck", "", true)
                Menu.SameLine()
                Menu.ColoredText("Use Smart Anti-Sash", Utils.GetMenuColor("SashCheck"))
                Menu.Text("")
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "", true)
                    Menu.SameLine()
                    Menu.ColoredText("Use [R] for " .. Name, Utils.GetMenuColor("R" .. Name))
                end
            end)
            Menu.Text("")


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroHarass", "Harass [C]", function()


            Menu.Text("")
            Menu.ColumnLayout("DrawMenu2", "DrawMenu2", 2, true, function()
                Menu.Checkbox("Harass.Q.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [Q]", Utils.GetMenuColor("Harass.Q.Use"))
                Menu.NextColumn()
                Menu.Slider("Harass.Q.HitChance", "HitChance %", 45, 1, 100, 1)
                Menu.NextColumn()
                Menu.Checkbox("Harass.E.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [E]", Utils.GetMenuColor("Harass.E.Use"))
                Menu.Checkbox("Harass.W.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [W]", Utils.GetMenuColor("Harass.W.Use"))

            end)
            Menu.Text("")
            Menu.ColoredText("[Q] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Harass.Q.Mana", "%", 20, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Harass.Q.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Harass.Q.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)

            Menu.NextColumn()
            Menu.Text("")

            Menu.ColoredText("[E] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Harass.E.Mana", "%", 20, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Harass.E.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Harass.E.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
            Menu.NextColumn()
            Menu.Text("")

            Menu.ColoredText("[W] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Harass.W.Mana", "%", 20, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Harass.W.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Harass.W.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
            Menu.NextColumn()
            Menu.Text("")


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenuwewe", "DrawMeweewnu", 2, true, function()
                Menu.Checkbox("Waveclear.Q.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [Q]", Utils.GetMenuColor("Waveclear.Q.Use"))
                Menu.NextColumn()
                Utils.HitCountSlider("QWaveclearHitCount", 2, 1, 6, "Minimum HitCount To Cast [Q]")
                Menu.NextColumn()
                Menu.Checkbox("Waveclear.E.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [E]", Utils.GetMenuColor("Waveclear.E.Use"))
                Menu.NextColumn()
                Utils.HitCountSlider("EWaveclearHitCount", 2, 1, 6, "Minimum Minions To Cast [E]")
                Menu.NextColumn()
                Menu.Checkbox("Waveclear.W.Use", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [W]", Utils.GetMenuColor("Waveclear.W.Use"))
                Menu.Checkbox("WPush", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [W] To Siege Towers", Utils.GetMenuColor("WPush"))

                Menu.NextColumn()


            end)

            Menu.Text("")
            Menu.Text("")
            Menu.ColoredText("[Q] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Waveclear.Q.Mana", "%", 50, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Waveclear.Q.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Waveclear.Q.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)

            Menu.NextColumn()
            Menu.Text("")

            Menu.ColoredText("[E] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Waveclear.E.Mana", "%", 0, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Waveclear.E.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Waveclear.E.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
            Menu.NextColumn()
            Menu.Text("")

            Menu.ColoredText("[W] Min Mana Percent", 0xEFC347FF)
            Menu.Slider("Waveclear.W.Mana", "%", 10, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Waveclear.W.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Waveclear.W.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
            Menu.NextColumn()
            Menu.Text("")


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroAuto", "Auto Settings", function()
            Menu.Text("")
            Menu.ColoredText("[Gapclose & Interrupt]", 0xEFC347FF)
            Menu.Text("")
            Menu.Checkbox("QCancel", "", true)
            Menu.SameLine()
            Menu.ColoredText("Cancel Enemy Spells With [Q]", Utils.GetMenuColor("QCancel"))
            Menu.Checkbox("QDash", "", true)
            Menu.SameLine()
            Menu.ColoredText("Cast [Q] On Enemy Dash Location", Utils.GetMenuColor("QDash"))
            Menu.Text("")
            Menu.ColoredText("[On Killable]", 0xEFC347FF)
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu23232323", "DrawMenu232323", 2, true, function()
                Menu.Checkbox("Qkill", "", true)
                Menu.SameLine()
                Menu.ColoredText("Automatically Cast [Q] To Kill", Utils.GetMenuColor("Qkill"))
                Menu.NextColumn()
                if Menu.Get("Qkill") then
                    Menu.Checkbox("QKS", "", false)
                    Menu.SameLine()
                    Menu.ColoredText("Enable KS", Utils.GetMenuColor("QKS"))
                end
                Menu.NextColumn()
                Menu.Checkbox("Ekill", "", true)
                Menu.SameLine()
                Menu.ColoredText("Automatically Cast [E] To Kill", Utils.GetMenuColor("Ekill"))
                Menu.NextColumn()
                if Menu.Get("Ekill") then
                    Menu.Checkbox("EKS", "", false)
                    Menu.SameLine()
                    Menu.ColoredText("Enable KS", Utils.GetMenuColor("EKS"))
                end

            end)
            Menu.Text("")


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("Drawings", "Drawings", function()
            Menu.Text("")
            Menu.Checkbox("Drawings.Q", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [Q] Range", Utils.GetMenuColor("Drawings.Q"))
            if Menu.Get("Drawings.Q") then
                Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
                Menu.Text("")
            end
            Menu.Checkbox("Drawings.E", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [E] Range", Utils.GetMenuColor("Drawings.E"))
            if Menu.Get("Drawings.E") then
                Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
                Menu.Text("")
            end
            Menu.Checkbox("Drawings.R", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [R] Range", Utils.GetMenuColor("Drawings.R"))
            if Menu.Get("Drawings.R") then
                Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)
            end
            Menu.Text("")

        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("DmgDrawings", "Damage Drawings", function()
            Menu.Text("")
            Menu.Checkbox("DmgDrawings.Q", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [Q] Damage", Utils.GetMenuColor("DmgDrawings.Q"))
            Menu.Checkbox("DmgDrawings.E", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [E] Damage", Utils.GetMenuColor("DmgDrawings.E"))
            Menu.Checkbox("DmgDrawings.R", "", true)
            Menu.SameLine()
            Menu.ColoredText("Draw [R] Damage", Utils.GetMenuColor("DmgDrawings.R"))
            Menu.Text("")

        end)


    end)
end


-- OnLoad
function OnLoad()

    INFO("Big Malzahar Loaded")

    Malzahar.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Malzahar[EventName] then
            EventManager.RegisterCallback(EventId, Malzahar[EventName])
        end
    end

    return true

end
