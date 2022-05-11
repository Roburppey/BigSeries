--[[
    BigSeraphine
]]

if Player.CharName ~= "Seraphine" then
    return false
end

module("Seraphine", package.seeall, log.setup)
clean.module("Seraphine", package.seeall, log.setup)


-- Globals
local CoreEx           = _G.CoreEx
local Libs             = _G.Libs
local Menu             = Libs.NewMenu
local Orbwalker        = Libs.Orbwalker
local DamageLib        = Libs.DamageLib
local SpellLib         = Libs.Spell
local TS               = Libs.TargetSelector()
local HealthPrediction = Libs.HealthPred
local ObjectManager    = CoreEx.ObjectManager
local EventManager     = CoreEx.EventManager
local Input            = CoreEx.Input
local Enums            = CoreEx.Enums
local Game             = CoreEx.Game
local Geometry         = CoreEx.Geometry
local Renderer         = CoreEx.Renderer
local Evade            = _G.CoreEx.EvadeAPI
local SpellSlots       = Enums.SpellSlots
local Events           = Enums.Events
local HitChance        = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };
local lastETime        = 0
local Player           = ObjectManager.Player.AsHero
local ScriptVersion    = "1.2.7"
local ScriptLastUpdate = "1. March 2022"
local PerkIDs          = _G.CoreEx.Enums.PerkIDs
local Colorblind       = false
local lastError        = ""
local passiveTracker   = ""
CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigSeraphine.lua", ScriptVersion)


-- Globals
local Seraphine = {}
local Utils     = {}

Seraphine.TargetSelector = nil
Seraphine.Logic          = {}

local UsableSS = {
    Ignite = {
        Slot  = nil,
        Range = 600
    },

    Flash = {
        Slot  = nil,
        Range = 400
    }
}


-- Seraphine Spells
Seraphine.Q  = SpellLib.Skillshot({

    Slot       = Enums.SpellSlots.Q,
    Range      = 900,
    Radius     = 100,
    Delay      = 0.25,
    Speed      = 1200,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type       = "Circular",


})
Seraphine.Q3 = SpellLib.Skillshot({

    Slot       = Enums.SpellSlots.Q,
    Range      = 900,
    Radius     = 100,
    Delay      = 0.55,
    Speed      = 1200,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type       = "Circular",


})
Seraphine.Q2 = SpellLib.Skillshot({

    Slot       = Enums.SpellSlots.Q,
    Range      = 900,
    Radius     = 370,
    Delay      = 0.675,
    Speed      = 1200,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type       = "Circular",


})
Seraphine.Q4 = SpellLib.Skillshot({

    Slot       = Enums.SpellSlots.Q,
    Range      = 900,
    Radius     = 370,
    Delay      = 0.975,
    Speed      = 1200,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type       = "Circular",


})
Seraphine.W  = SpellLib.Active({

    Slot   = Enums.SpellSlots.W,
    Range  = 0,
    Radius = 800,
    Delay  = 0.25,
    Type   = "Active",

})
Seraphine.E  = SpellLib.Skillshot({

    Slot          = Enums.SpellSlots.E,
    Range         = 1200,
    Radius        = 60,
    Delay         = 0.25,
    Speed         = 1200,
    Collisions    = { WindWall = true, Heroes = true, Minions = true },
    MaxCollisions = 999,
    Type          = "Linear",


})
Seraphine.E2 = SpellLib.Skillshot({

    Slot          = Enums.SpellSlots.E,
    Range         = 1200,
    Radius        = 60,
    Delay         = 0.55,
    Speed         = 1200,
    Collisions    = { WindWall = true, Heroes = true, Minions = true },
    MaxCollisions = 999,
    Type          = "Linear",


})
Seraphine.R  = SpellLib.Skillshot({

    Slot          = Enums.SpellSlots.R,
    Range         = 1000,
    Radius        = 140,
    Delay         = 0.5,
    Speed         = 1600,
    Type          = "Linear",
    UseHitbox     = true,
    Collisions    = { Heroes = true, Minions = false, WindWall = true },
    MaxCollisions = 99

})
Seraphine.R2 = SpellLib.Skillshot({

    Slot          = Enums.SpellSlots.R,
    Range         = 2200,
    Radius        = 120,
    Delay         = 0.5,
    Speed         = 1600,
    Type          = "Linear",
    UseHitbox     = true,
    Collisions    = { Heroes = true, Minions = false, WindWall = true },
    MaxCollisions = 99

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

function GetQDmg(target, isDoubleCast, missingPercent)

    if target == nil then
        return 0
    end

    if not Seraphine.Q:IsLearned() or not Seraphine.Q:IsReady() then
        return 0
    end

    local missingHealthPercent = 1 - Player.HealthPercent * 100

    if isDoubleCast then
        missingHealthPercent = missingPercent
    end
    local isBetween = function(num1Inclusive, num2Exclusive)
        return missingHealthPercent >= num1Inclusive and missingHealthPercent < num2Exclusive
    end

    local missingHealthDamageAmp = 1

    if isBetween(7.5, 15) then
        missingHealthDamageAmp = 1.05
    end
    if isBetween(15, 22.5) then
        missingHealthDamageAmp = 1.1
    end
    if isBetween(22.5, 30) then
        missingHealthDamageAmp = 1.15
    end
    if isBetween(30, 37.5) then
        missingHealthDamageAmp = 1.2
    end
    if isBetween(37.5, 45) then
        missingHealthDamageAmp = 1.25
    end
    if isBetween(45, 52.5) then
        missingHealthDamageAmp = 1.3
    end
    if isBetween(52.5, 60) then
        missingHealthDamageAmp = 1.35
    end
    if isBetween(60, 67.5) then
        missingHealthDamageAmp = 1.4
    end
    if isBetween(67.5, 75) then
        missingHealthDamageAmp = 1.45
    end
    if isBetween(75, 1000) then
        missingHealthDamageAmp = 1.5
    end

    local apScaling = ({ 0.45, 0.50, 0.55, 0.60, 0.65 })[Seraphine.Q:GetLevel()]

    -- 55 / 70 / 85 / 100 / 115 (+ 45 / 50 / 55 / 60 / 65% AP)


    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, ((55 + (Seraphine.Q:GetLevel() - 1) * 15) + (apScaling * Player.TotalAP)) * missingHealthDamageAmp)


end

function GetEDmg(target)

    if target == nil then
        return 0
    end

    if not Seraphine.E:IsReady() then
        return 0
    end

    -- 60 / 80 / 100 / 120 / 140 (+ 35% AP)

    local EBaseDmg = ({ 60, 80, 100, 120, 140 })[Seraphine.E:GetLevel()]
    local apDmg    = Player.TotalAP * 0.35

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, EBaseDmg + apDmg)


end

function GetRDmg(target)

    if target == nil then
        return 0
    end

    if not Seraphine.R:IsReady() then
        return 0
    end

    -- 150 / 200 / 250 (+ 60% AP)
    local EBaseDmg = ({ 150, 200, 250 })[Seraphine.R:GetLevel()]
    local apDmg    = Player.TotalAP * 0.6

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, EBaseDmg + apDmg)


end

function GetPassiveDamage(target)

    local baseDmg     = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg       = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)

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
    local Array   = {}
    local Index   = 0

    for _, Object in pairs(Objects) do
        if Object and Object ~= Target then
            Object = Object.AsAI
            if Utils.IsValidTarget(Object) and
                (not Condition or Condition(Object))
            then
                local Distance = Target:Distance(Object.Position)
                if Distance <= Range then
                    Array[Index] = Object
                    Index        = Index + 1
                end
            end
        end
    end

    return { Array = Array, Count = Index }
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

function Utils.ManaSlider(id, name, default)

    Menu.Slider(id, name, default, 0, 100, 5)
    local power  = 10 ^ 2
    local result = math.floor(Player.MaxMana / 100 * Menu.Get(id) * power) / power
    Menu.ColoredText(Menu.Get(id) .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)


end

function Utils.HitCountSlider(id, default, min, max)

    Menu.Slider(id, "  ", default, min, max, 1)
    Menu.ColoredText("Minimum Minions Hit", 0xE3FFDF)

end

function Utils.PassesMinimumMana(id)
    local power = 10 ^ 2
    return Player.Mana >= math.floor(Player.MaxMana / 100 * Menu.Get(id) * power) / power

end

function Utils.EnabledAndMinimumMana(useID, manaID)
    local power = 10 ^ 2
    return Menu.Get(useID) and Player.Mana >= math.floor(Player.MaxMana / 100 * Menu.Get(manaID) * power) / power

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

function Utils.SmartCheckbox(id, text, default)


    local ticked = default or true
    Menu.Checkbox(id, "", ticked)
    Menu.SameLine()
    Menu.ColoredText(text, Utils.GetMenuColor(id))

end

function Utils.MenuDivider(color, sym, am)

    local DivColor = color or 0xEFC347FF
    local string   = ""
    local amount   = 166 or am
    local symbol   = sym or "="

    for i = 1, 166 do

        string = string .. symbol

    end

    return Menu.ColoredText(string, DivColor, true)

end

function Utils.SmartQ(Target)

    pcall(function()

        if Menu.Get("ComboW") then
            if Seraphine.W:IsReady() then
                if passiveTracker == "Spell2" or passiveTracker == "Spell1" or passiveTracker == "Spell3" then
                    return Seraphine.W:Cast()
                end
            end

        end

        local q1Pred = Seraphine.Q:GetPrediction(Target)
        local q3Pred = Seraphine.Q3:GetPrediction(Target)
        local q2Pred = Seraphine.Q2:GetPrediction(Target)
        local q4Pred = Seraphine.Q4:GetPrediction(Target)

        local bestPred = q1Pred

        if q2Pred.HitChance > q1Pred.HitChance then
            bestPred = q2Pred
        end

        if q1Pred.HitChance >= Menu.Get("QHitChance") / 100 then
            if q2Pred.HitChance >= Menu.Get("QHitChance") / 100 then

                -- INFO("Q1 Pred was : ".. q1Pred.HitChance)
                -- INFO("Q2 Pred was : ".. q2Pred.HitChance)
                if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
                    if q4Pred.HitChance >= Menu.Get("QHitChance") / 100 then
                        -- INFO("Q4 Pred was : ".. q4Pred.HitChance)
                        return Seraphine.Q:Cast(bestPred.CastPosition)
                    end
                else
                    return Seraphine.Q:Cast(bestPred.CastPosition)
                end
            end
        end
    end)

end

function Utils.SmartE(Target)

    pcall(function()
        if Player:Distance(Target) >= Seraphine.E.Range then
            return false
        end
        local ePred  = Seraphine.E:GetPrediction(Target)
        local e2Pred = Seraphine.E2:GetPrediction(Target)

        if ePred.HitChance >= Menu.Get("EHitChance") / 100 then
            -- INFO("E1 Pred was : " .. ePred.HitChance)
            if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
                if e2Pred.HitChance >= Menu.Get("EHitChance") / 100 then
                    -- INFO("E2 Pred was : " .. e2Pred.HitChance)
                    return Seraphine.E:Cast(ePred.CastPosition)

                end
            else

                return Seraphine.E:Cast(ePred.CastPosition)

            end
        end
    end)

end

-- Event Functions
function Seraphine.OnProcessSpell(Caster, SpellCast)
    if Player.IsRecalling then
        return
    end

    if not Seraphine.W:IsReady() then
        return
    end

    if SpellCast.Target ~= nil then

        local target = SpellCast.Target
        if not target.IsHero then
            return
        end
        local caster = Caster

        if not target.IsAlly then
            return
        end

        if Player.Position:Distance(target.Position) < Seraphine.W.Radius then


            if caster.IsTurret then
                return Input.Cast(SpellSlots.W)
            end

            if caster.IsEnemy and caster.IsHero then
                return Input.Cast(SpellSlots.W)
            end

        end


    end

end

function Seraphine.OnUpdate()

end

function Seraphine.OnBuffGain(obj, buffInst)

end

function Seraphine.OnBuffLost(obj, buffInst)
end

function Seraphine.OnGapclose(source, dash)

    if Menu.Get("AutoEGap") then

        if Utils.IsInRange(Player.Position, source.Position, 0, Seraphine.E.Range) then
            if Seraphine.E:IsReady() then
                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then

                        local pred = Seraphine.E:GetPrediction(source)
                        if pred and pred.HitChanceEnum >= Enums.HitChance.Dashing then
                            if Seraphine.E:Cast(pred.CastPosition) then
                                return true
                            end
                        end

                    end
                end
            end
        end
    end
end

function Seraphine.OnExtremePriority(lagFree)
    if Menu.Get("AutoR") then

        if lagFree == 4 then

            if Seraphine.R:IsReady() then

                pcall(function()


                    local enemiesInInitialUltRange = {}
                    for i, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
                        if Player:Distance(v.Position) <= Seraphine.R.Range then

                            table.insert(enemiesInInitialUltRange, v)
                        end

                    end

                    for i, v in ipairs(enemiesInInitialUltRange) do

                        local predInt = Seraphine.R:GetPrediction(v)
                        local pred    = Seraphine.R2:GetPrediction(v)

                        if pred and predInt then

                            if pred.HitChance >= 0.75 and predInt.HitChance >= 0.75 then

                                local ultHitCounter = 1

                                for a, b in pairs(pred.CollisionObjects) do

                                    ultHitCounter = ultHitCounter + 1

                                end

                                if ultHitCounter >= Menu.Get("AutoRCount") then

                                    Seraphine.R:Cast(predInt.CastPosition)

                                end
                            end
                        end
                    end
                end)
            end

        end
    end
end

function Seraphine.OnCreateObject(obj, lagFree)

end

function Seraphine.OnTick(lagFree)


    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Seraphine.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Seraphine.Logic.Auto(lagFree) then
        return true
    end

    --[[


        --]]

end

function Seraphine.OnHeroImmobilized(Source, EndTime, IsStasis)

    if Menu.Get("ECC") then

        if not IsStasis then
            if Source.IsEnemy then
                if Source.IsHero then
                    if Source.IsTargetable then
                        if Source.IsAlive then
                            if EndTime - Game.GetTime() > 1 then
                                return
                            end

                            if Player.Position:Distance(Source.Position) <= Seraphine.E.Range then
                                if Seraphine.E:IsReady() then
                                    Utils.SmartE(Source)
                                end
                            end

                        end

                    end

                end
            end

        end

    end
end

function Seraphine.OnPreAttack(args)

end

function Seraphine.OnPostAttack(target)

end

function Seraphine.OnPlayAnimation(obj, animationName)

    if obj.IsMe then

        if animationName == "Spell2" or animationName == "Spell1" or animationName == "Spell3" or animationName == "P_Spell1" or animationName == "P_Spell2" or animationName == "P_Spell3" then
            -- print(animationName)
            passiveTracker = animationName
        end

    end

end

-- Drawings
function Seraphine.OnDrawDamage(target, dmgList)

    if not target then
        return
    end
    if not target.IsAlive then
        return
    end

    local DoubleCast = Utils.HasBuff(Player, "SeraphinePassiveEchoStage2")

    local alreadyAdded = false

    if DoubleCast then

        if not Seraphine.E:IsReady() then
            if Menu.Get("DmgDrawings.Q") then

                local dmg1 = GetQDmg(target, false, 0)
                local dmg2 = GetQDmg(target, true, (1 - (target.Health / target.MaxHealth)) * 100)

                -- Post Mitigation Damage  =  Raw Damage  ÷  (1  +  (Magic Resistance  ÷  100))
                table.insert(dmgList, dmg1)
                table.insert(dmgList, dmg2)
                alreadyAdded = true
            end
        else

            if Menu.Get("DmgDrawings.Q") then

                local dmg1 = GetQDmg(target, false, 0)
                table.insert(dmgList, dmg1)

            end

        end
    else
        if Menu.Get("DmgDrawings.Q") then

            local dmg1 = GetQDmg(target, false, 0)
            table.insert(dmgList, dmg1)

        end

    end

    if Menu.Get("DmgDrawings.E") then

        if DoubleCast then
            if not alreadyAdded then

                local dmg1 = GetEDmg(target)
                local dmg2 = GetEDmg(target)
                table.insert(dmgList, dmg1 + dmg2)

            end
        else
            local dmg1 = GetEDmg(target)
            table.insert(dmgList, dmg1)
        end

    end

    if Menu.Get("DmgDrawings.R") then
        table.insert(dmgList, GetRDmg(target))
    end

    if Menu.Get("DmgDrawings.Ludens") then
        table.insert(dmgList, Utils.GetLudensDmg())

    end

    local totaldmg = 0
    for i, v in pairs(dmgList) do
        totaldmg = totaldmg + v
    end

    --  print("Hp after: "..target.Health - totaldmg)

end

function Seraphine.OnDraw()

    if Seraphine.Q:IsLearned() then
        if Menu.Get("Drawings.Q") then
            Renderer.DrawCircle3D(Player.Position, Seraphine.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
        end

    end

    if Seraphine.R:IsLearned() then
        if Menu.Get("Drawings.R") then
            Renderer.DrawCircle3D(Player.Position, Seraphine.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
        end

    end

    if Seraphine.E:IsLearned() then
        if Menu.Get("Drawings.E") then
            Renderer.DrawCircle3D(Player.Position, Seraphine.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
        end

    end

    if Player.GetSpell(Player, SpellSlots.W).IsLearned then
        if Menu.Get("Drawings.W") then
            Renderer.DrawCircle3D(Player.Position, 800, 30, 1, Menu.Get("Drawings.W.Color"))
        end

    end

end

-- Spell Logic
function Seraphine.Logic.R(Target)

    if not Target then
        return false
    end

    local Name = Target.CharName
    if not Menu.Get("R" .. Name) then
        return false
    end

    if Seraphine.R:IsReady() then

        local enemiesInInitialUltRange = {}
        for i, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Player:Distance(v.Position) <= Seraphine.R.Range then
                table.insert(enemiesInInitialUltRange, v)
            end
        end

        for i, v in ipairs(enemiesInInitialUltRange) do

            local predInt = Seraphine.R:GetPrediction(v)

            if predInt then

                if predInt.HitChance >= Menu.Get("RHitChance") / 100 then

                    local ultHitCounter = 1

                    for a, b in pairs(predInt.CollisionObjects) do

                        ultHitCounter = ultHitCounter + 1

                    end

                    if ultHitCounter >= Menu.Get("RCSlider") then

                        Seraphine.R:Cast(predInt.CastPosition)

                    end
                end
            end
        end

        --[[
                if Seraphine.R:CastOnHitChance(Target, Menu.Get("RHitChance") / 100) then
                    return true
                end
                ]]


    end

    if Menu.Get("AllyR") then

        local pred = Seraphine.R2:GetPrediction(Target)

        if pred and pred.HitChance then

            if pred.HitChanceEnum < Menu.Get("RHitChance") / 100 then
                -- print("cant hit R2")
                return
            end

            local ultHitCounter = 1

            for i, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do

                if Player:Distance(v) <= Seraphine.R.Range then
                    local predAlly = Seraphine.R:GetPrediction(v)

                    if not predAlly then
                        return
                    end

                    if not v.IsMe then

                        local list = ({ predAlly.CastPosition, pred.CastPosition })

                        local bestPos, hitCount = Seraphine.R2:GetBestLinearCastPos(list)

                        if bestPos and hitCount >= 2 then

                            if Seraphine.R:IsReady() then
                                Seraphine.R:Cast(bestPos)
                            end
                        end

                    end

                end

            end


        end

    end

    return false

end

function Seraphine.Logic.Q(Target)

    local orbwalkerMode = Orbwalker.GetMode()
    local hitChance     = nil

    if orbwalkerMode == "Combo" then
        hitChance = Menu.Get("QHitChance")
    elseif orbwalkerMode == "Harass" then
        hitChance = Menu.Get("QHitChanceHarass")
    end

    if hitChance == nil then
        return
    end

    local prediction = Seraphine.Q:GetPrediction(Target)
    if not prediction then
        return false
    end
    if not prediction.HitChance then
        return false
    end

    if Seraphine.Q:IsReady() then
        return Utils.SmartQ(Target)
    end


end

function Seraphine.Logic.W(lagFree)

    local enemiesInWRange   = {}
    local alliesInWRange    = {}
    local lowAlliesInWRange = {}

    for _, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
        if Player:Distance(v.Position) <= 800 then
            table.insert(enemiesInWRange, v)
        end
    end

    for i, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do
        if Player:Distance(v.Position) <= 800 then
            table.insert(alliesInWRange, v)
        end
    end

    for i, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do
        if Player:Distance(v.Position) <= 800 then

            if v.Health < v.MaxHealth * 0.5 then
                table.insert(lowAlliesInWRange, v)
            end
        end
    end

    if #enemiesInWRange > 1 then
        if not Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
            return Input.Cast(SpellSlots.W)
        end
    end

    if #lowAlliesInWRange >= 2 then
        if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
            return Input.Cast(SpellSlots.W)
        end
    end

    if #alliesInWRange >= 2 and #enemiesInWRange >= 2 then
        return Input.Cast(SpellSlots.W)
    end

    if Player.Health <= Player.MaxHealth * 0.3 then
        if #alliesInWRange >= 2 or #enemiesInWRange >= 1 then
            if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
                return Input.Cast(SpellSlots.W)
            end
        end
    end

    if #enemiesInWRange >= 1 and #alliesInWRange >= 4 then
        return Input.Cast(SpellSlots.W)
    end

    return false

end

function Seraphine.Logic.E(Target)

    local prediction = Seraphine.E:GetPrediction(Target)
    if not prediction then
        return false
    end
    if not prediction.HitChance then
        return false
    end
    if not Seraphine.E:IsReady() then
        return false
    end

    if Seraphine.E:IsReady() then
        return Utils.SmartE(Target)
    end

    return false
end

-- Orbwalker Logic
function Seraphine.Logic.Lasthit(lagFree)

end

function Seraphine.Logic.Flee(lagFree)

end

function Seraphine.Logic.Waveclear(lagFree)

    if Utils.EnabledAndMinimumMana("UseQWaveclear", "QWaveclearMana") then
        local bestPos, hitCount = Seraphine.Q:GetBestCircularCastPos(Utils.EnemyMinionsInRange(Seraphine.Q.Range), 350)
        if bestPos and hitCount >= Menu.Get("QWaveclearHitcount") then
            if Seraphine.Q:IsReady() then
                Seraphine.Q:Cast(bestPos)
            end
        end

    end

    if Utils.EnabledAndMinimumMana("UseEWaveclear", "EWaveclearMana") then

        if Menu.Get("ENoDoubleCast") then
            if not Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then
                local bestPos2, hitCount2 = Seraphine.E:GetBestLinearCastPos(Utils.EnemyMinionsInRange(Seraphine.E.Range), Seraphine.E.Radius)
                if bestPos2 and hitCount2 >= Menu.Get("EWaveclearHitcount") then
                    return Seraphine.E:Cast(bestPos2)
                end

            end
        else
            local bestPos2, hitCount2 = Seraphine.E:GetBestLinearCastPos(Utils.EnemyMinionsInRange(Seraphine.E.Range), Seraphine.E.Radius)
            if bestPos2 and hitCount2 >= Menu.Get("EWaveclearHitcount") then
                return Seraphine.E:Cast(bestPos2)
            end

        end

    end


end

function Seraphine.Logic.Harass(lagFree)


    if Utils.EnabledAndMinimumMana("UseEHarass", "EHarassMana") then
        local Target = TS:GetTarget(Seraphine.E.Range)

        if Target then

            if Seraphine.Logic.E(Target) then
                return true
            end

        end

    end

    if Utils.EnabledAndMinimumMana("UseQHarass", "QHarassMana") then

        local Target = TS:GetTarget(Seraphine.Q.Range)

        if Target then

            if Seraphine.Logic.Q(Target) then
                return true
            end

        end

    end

    Seraphine.Logic.W()

    return false

end

function Seraphine.Logic.Combo(lagFree)


    if lagFree == 1 then

        local Target = TS:GetTarget(Seraphine.R2.Range)

        if Menu.Get("UseR") then
            Target = TS:GetTarget(Seraphine.R2.Range)

            if Target then

                if Seraphine.Logic.R(Target) then
                    return true
                end

            end

        end

        target = nil

        if Menu.Get("UseE") then

            Target = TS:GetTarget(Seraphine.E.Range)

            if Target then

                if Seraphine.Logic.E(Target) then
                    return true
                end

            end

        end

        target = nil

        if Menu.Get("UseQ") then
            Target = TS:GetTarget(Seraphine.Q.Range)

            if Target then

                if Seraphine.Logic.Q(Target) then
                    return true
                end

            end

        end

        if Seraphine.W:IsReady() then
            Seraphine.Logic.W()
        end

    end



end

function Seraphine.Logic.Auto(lagFree)


    if lagFree == 3 then

        if Menu.Get("QKS") then

            if Seraphine.Q:IsReady() then
                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                    if Player:Distance(v.Position) <= Seraphine.Q.Range then

                        local vHealth = v.Health

                        local dmg1 = GetQDmg(v, false, 0)
                        local dmg2 = GetQDmg(v, true, (1 - (v.Health / v.MaxHealth)) * 100)

                        if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then

                            if dmg1 + dmg2 >= vHealth then

                                if Seraphine.Q:CastOnHitChance(v, 0.6) then
                                    return true
                                end

                            end
                        else

                            if dmg1 >= vHealth then

                                if Seraphine.Q:CastOnHitChance(v, 0.6) then
                                    return true
                                end

                            end

                        end

                    end

                end

            end

        end

        if Menu.Get("EKS") then

            if Seraphine.E:IsReady() then
                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                    if Player:Distance(v.Position) <= Seraphine.E.Range then

                        local vHealth = v.Health

                        local dmg1 = GetEDmg(v)
                        local dmg2 = GetEDmg(v)

                        if Utils.HasBuff(Player, "SeraphinePassiveEchoStage2") then

                            if dmg1 + dmg2 >= vHealth then

                                if Seraphine.E:CastOnHitChance(v, 0.6) then
                                    return true
                                end

                            end

                        else

                            if dmg1 >= vHealth then

                                if Seraphine.E:CastOnHitChance(v, 0.6) then
                                    return true
                                end

                            end

                        end


                    end

                end

            end

        end



    end

    if lagFree == 2 then
        if Menu.Get("EnablePred") then
            local f = function()
                Seraphine.Q.Range  = Menu.Get("QRangeSlider")
                Seraphine.Q.Speed  = Menu.Get("QSpeedSlider")
                Seraphine.Q.Radius = Menu.Get("QRadiusSlider")
                Seraphine.Q.Delay  = Menu.Get("QDelaySlider") / 1000

                Seraphine.E.Range  = Menu.Get("ERangeSlider")
                Seraphine.E.Speed  = Menu.Get("ESpeedSlider")
                Seraphine.E.Radius = Menu.Get("ERadiusSlider") / 2
                Seraphine.E.Delay  = Menu.Get("EDelaySlider") / 1000

                Seraphine.R.Range  = Menu.Get("RRangeSlider")
                Seraphine.R.Speed  = Menu.Get("RSpeedSlider")
                Seraphine.R.Radius = Menu.Get("RRadiusSlider") / 2
                Seraphine.R.Delay  = Menu.Get("RDelaySlider") / 1000
            end

            local executed, error = xpcall(f, debug.traceback)

            if executed then

            else
                Seraphine.LoadMenu()
                if lastError ~= error then
                    -- WARN(error)
                    lastError = error
                end
            end

        else

            Seraphine.Q.Slot       = Enums.SpellSlots.Q
            Seraphine.Q.Range      = 900
            Seraphine.Q.Radius     = 100
            Seraphine.Q.Delay      = 0.25
            Seraphine.Q.Speed      = 1200
            Seraphine.Q.Collisions = { Heroes = false, Minions = false, WindWall = true }
            Seraphine.Q.Type       = "Circular"

            Seraphine.E.Slot          = Enums.SpellSlots.E
            Seraphine.E.Range         = 1200
            Seraphine.E.Radius        = 60
            Seraphine.E.Delay         = 0.25
            Seraphine.E.Speed         = 1200
            Seraphine.E.Collisions    = { WindWall = true, Heroes = true, Minions = true }
            Seraphine.E.MaxCollisions = 999
            Seraphine.E.Type          = "Linear"

            Seraphine.R.Slot          = Enums.SpellSlots.R
            Seraphine.R.Range         = 1100
            Seraphine.R.Radius        = 140
            Seraphine.R.Delay         = 0.5
            Seraphine.R.Speed         = 1600
            Seraphine.R.Type          = "Linear"
            Seraphine.R.UseHitbox     = true
            Seraphine.R.Collisions    = { Heroes = true, Minions = false, WindWall = true }
            Seraphine.R.MaxCollisions = 99

        end

    end

    local DetectedSkillshots = {}
    DetectedSkillshots       = Evade.GetDetectedSkillshots()

    for k, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do

        if Menu.Get("Ally.Shield.Skillshots") then

            for i, p in ipairs(DetectedSkillshots) do


                if not Menu.Get("Ally.Shield.AA") then
                    if p.IsBasicAttack then
                        return
                    end
                end

                if p:IsAboutToHit(1, v.Position) then

                    if Seraphine.W:IsReady() then

                        if Player.Position:Distance(v.Position) <= 800 then
                            Input.Cast(SpellSlots.W)

                        end

                    end
                end

            end

        end
    end

end

-- Menu
function Seraphine.LoadMenu()

    Menu.RegisterMenu("BiChampion", "BigSeraphine", function()
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
        Menu.Separator()
        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()

                Menu.Checkbox("UseQ", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [Q]", Utils.GetMenuColor("UseQ"))
                Menu.NextColumn()
                Menu.Slider("QHitChance", "HitChance %", 35, 1, 90, 1)
                Menu.NextColumn()
                Menu.Checkbox("UseE", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [E]", Utils.GetMenuColor("UseE"))
                Menu.NextColumn()
                Menu.Slider("EHitChance", "HitChance %", 60, 1, 90, 1)
                Menu.NextColumn()
                Menu.Checkbox("UseR", "", true)
                Menu.SameLine()
                Menu.ColoredText("Cast [R]", Utils.GetMenuColor("UseR"))
                Menu.NextColumn()
                Menu.Slider("RHitChance", "HitChance %", 90, 1, 90, 1)
                Menu.ColoredText("[R] Min Hitcount", 0xEFC347FF)
                Menu.Slider("RCSlider", " ", 1, 1, 5, 1)

            end)
            Menu.Text("")
            Menu.Checkbox("AllyR", "", true)
            Menu.SameLine()
            Menu.ColoredText("Use allies to hit [R]", Utils.GetMenuColor("AllyR"))
            Utils.SmartCheckbox("ComboW", "Use [W] To Double Cast [Q]", true)
            Menu.Text("")
            Menu.NewTree("RWhitelist", "R Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "Use [R] for " .. Name, true)
                end
            end)
            Menu.Text("")

        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroHarass", "Harass", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu2", "DrawMenu2", 2, true, function()

                Utils.SmartCheckbox("UseQHarass", "Cast [Q]")
                Menu.NextColumn()
                Menu.Slider("QHitChanceHarass", "HitChance %", 45, 1, 100, 1)
                Utils.ManaSlider("QHarassMana", "Min Mana", 50)
                Menu.NextColumn()
                Menu.Text("")

                Utils.SmartCheckbox("UseEHarass", "Cast [E]")
                Menu.NextColumn()
                Menu.Text("")

                Menu.Slider("EHitChanceHarass", "HitChance %", 60, 1, 100, 1)
                Utils.ManaSlider("EHarassMana", "Min Mana", 50)
                Menu.NextColumn()


            end)


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroWaveclear", "Waveclear", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu223", "DrawMenu223", 2, true, function()

                Utils.SmartCheckbox("UseQWaveclear", "Cast [Q]")
                Menu.NextColumn()
                Utils.ManaSlider("QWaveclearMana", "Min Mana", 35)
                Utils.HitCountSlider("QWaveclearHitcount", 3, 1, 6)
                Menu.NextColumn()
                Menu.Text("")
                Utils.SmartCheckbox("UseEWaveclear", "Cast [E]")
                Utils.SmartCheckbox("ENoDoubleCast", "Prevent double cast [E]")
                Menu.NextColumn()
                Menu.Text("")
                Utils.ManaSlider("EWaveclearMana", "Min Mana", 35)
                Utils.HitCountSlider("EWaveclearHitcount", 4, 1, 6)

                Menu.NextColumn()


            end)


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("BigHeroPrediction", "Custom Prediction Builder", function()
            Menu.Text("")
            Utils.SmartCheckbox("EnablePred", "Enable", false)
            if Menu.Get("EnablePred") then
                Menu.NewTree("BigHeroPredictionQ", "[Q] - High Note", function()
                    Menu.ColoredText("- [Q] High Note -", 0xE3FFDF, true)
                    Menu.Text("")

                    Menu.ColumnLayout("DrawMenu4", "DrawMenu2", 3, true, function()
                        Menu.Text("")
                        Menu.Text("Range: ", true)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Slider("QRangeSlider", " ", 900, 0, 900, 25)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Text("Default: 900")
                        Menu.NextColumn()
                        Menu.Text("Speed: ", true)
                        Menu.NextColumn()
                        Menu.Slider("QSpeedSlider", " ", 1200, 0, 1200, 25)
                        Menu.NextColumn()
                        Menu.Text("Default: 1200")
                        Menu.NextColumn()
                        Menu.Text("Radius: ", true)
                        Menu.NextColumn()
                        Menu.Slider("QRadiusSlider", " ", 350, 0, 350, 25)
                        Menu.NextColumn()
                        Menu.Text("Default: 350")
                        Menu.NextColumn()
                        Menu.Text("Cast Time (1000 = 1s): ", true)
                        Menu.NextColumn()
                        Menu.Slider("QDelaySlider", " ", 750, 0, 1000, 25)
                        Menu.NextColumn()

                        Menu.Text("Default: 750")

                    end)

                end)
                Menu.NewTree("BigHeroPredictionE", "[E] - Beat Drop", function()
                    Menu.ColoredText("- [E] Beat Drop -", 0xE3FFDF, true)
                    Menu.Text("")

                    Menu.ColumnLayout("DrawMenuE", "DrawMenu2", 3, true, function()
                        Menu.Text("")
                        Menu.Text("Range: ", true)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Slider("ERangeSlider", " ", 1200, 0, 1300, 25)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Text("Default: 1300")
                        Menu.NextColumn()
                        Menu.Text("Speed: ", true)
                        Menu.NextColumn()
                        Menu.Slider("ESpeedSlider", " ", 1200, 0, 1200, 25)
                        Menu.NextColumn()
                        Menu.Text("Default: 1200")
                        Menu.NextColumn()
                        Menu.Text("Width: ", true)
                        Menu.NextColumn()
                        Menu.Slider("ERadiusSlider", " ", 140, 0, 140, 5)
                        Menu.NextColumn()
                        Menu.Text("Default: 140")
                        Menu.NextColumn()
                        Menu.Text("Cast Time (1000 = 1s): ", true)
                        Menu.NextColumn()
                        Menu.Slider("EDelaySlider", " ", 250, 0, 1000, 25)
                        Menu.NextColumn()

                        Menu.Text("Default: 250")

                    end)

                end)
                Menu.NewTree("BigHeroPredictionR", "[R] - Encore", function()
                    Menu.ColoredText("- [R] Encore -", 0xE3FFDF, true)
                    Menu.Text("")

                    Menu.ColumnLayout("DrawMenuR", "DrawMenu2", 3, true, function()
                        Menu.Text("")
                        Menu.Text("Range: ", true)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Slider("RRangeSlider", " ", 1100, 0, 1200, 25)
                        Menu.NextColumn()
                        Menu.Text("")
                        Menu.Text("Default: 1200")
                        Menu.NextColumn()
                        Menu.Text("Speed: ", true)
                        Menu.NextColumn()
                        Menu.Slider("RSpeedSlider", " ", 1600, 0, 1600, 25)
                        Menu.NextColumn()
                        Menu.Text("Default: 1600")
                        Menu.NextColumn()
                        Menu.Text("Width: ", true)
                        Menu.NextColumn()
                        Menu.Slider("RRadiusSlider", " ", 300, 0, 320, 5)
                        Menu.NextColumn()
                        Menu.Text("Default: 320")
                        Menu.NextColumn()
                        Menu.Text("Cast Time (1000 = 1s): ", true)
                        Menu.NextColumn()
                        Menu.Slider("RDelaySlider", " ", 500, 0, 1000, 25)
                        Menu.NextColumn()

                        Menu.Text("Default: 500")

                    end)

                end)
                Menu.Text("")

            end


        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("Auto", "Auto", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMen32u223", "DrawMenu23223", 2, true, function()
                Utils.SmartCheckbox("AutoR", "Auto R")
                Menu.NextColumn()
                Menu.Slider("AutoRCount", "Min Enemies Hit", 3, 2, 5, 1)

            end)
            Menu.Text("")
            Menu.Separator()
            Utils.SmartCheckbox("QKS", "KS With [Q]")
            Utils.SmartCheckbox("EKS", "KS With [E]")
            Menu.Separator()
            Utils.SmartCheckbox("Ally.Shield.Skillshots", "Shield allies")
            Utils.SmartCheckbox("Ally.Shield.AA", "Shield from AA")
            Menu.Separator()
            Utils.SmartCheckbox("ECC", "Auto [E] On CC'd Enemy")
            Utils.SmartCheckbox("AutoEGap", "Auto [E] On Gapclose")
            Menu.Text("")
        end)
        Utils.MenuDivider(0x14138FFF, "-", nil)
        Menu.NewTree("Drawings", "Drawings", function()
            Menu.ColumnLayout("DrawMenu3", "DrawMenu2", 2, true, function()

                Menu.Text("")
                Menu.ColoredText("Range Drawings", 0xE3FFDF)
                Menu.Text("")
                Menu.Checkbox("Drawings.Q", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [Q] Range", Utils.GetMenuColor("Drawings.Q"))
                if Menu.Get("Drawings.Q") then
                    Menu.ColorPicker("Drawings.Q.Color", "", 0xFF5BDFFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.W", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [W] Range", Utils.GetMenuColor("Drawings.W"))
                if Menu.Get("Drawings.W") then
                    Menu.ColorPicker("Drawings.W.Color", "", 0xFF5BDFFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.E", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [E] Range", Utils.GetMenuColor("Drawings.E"))
                if Menu.Get("Drawings.E") then
                    Menu.ColorPicker("Drawings.E.Color", "", 0xFF5BDFFF)
                    Menu.Text("")
                end
                Menu.Checkbox("Drawings.R", "", true)
                Menu.SameLine()
                Menu.ColoredText("Draw [R] Range", Utils.GetMenuColor("Drawings.R"))
                if Menu.Get("Drawings.R") then
                    Menu.ColorPicker("Drawings.R.Color", "", 0xFF5BDFFF)
                    Menu.Text("")
                end
                Menu.Text("")
                Menu.NextColumn()
                Menu.Text("")
                Menu.ColoredText("Damage Drawings", 0xE3FFDF)
                Menu.Text("")
                Utils.SmartCheckbox("DmgDrawings.Q", "Draw [Q] Dmg")
                Utils.SmartCheckbox("DmgDrawings.E", "Draw [E] Dmg")
                Utils.SmartCheckbox("DmgDrawings.R", "Draw [R] Dmg")
                Utils.SmartCheckbox("DmgDrawings.Ludens", "Draw [Ludens] Dmg")

                Menu.Text("")
                Menu.NextColumn()

            end)

        end)


    end)
end

-- OnLoad
function OnLoad()

    INFO("Welcome to BigSeraphine, enjoy your stay")

    Seraphine.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Seraphine[EventName] then
            EventManager.RegisterCallback(EventId, Seraphine[EventName])
        end
    end

    return true

end
