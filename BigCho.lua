--[[
    BigCho
]]

if Player.CharName ~= "Chogath" then
    return false
end

module("BCho", package.seeall, log.setup)
clean.module("BCho", package.seeall, log.setup)


-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local os_clock = _G.os.clock
local Menu = Libs.NewMenu
local Prediction = Libs.Prediction

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

local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };

local LocalPlayer = ObjectManager.Player.AsHero

local ScriptVersion = "1.0.5"
local ScriptLastUpdate = "12/21/2021"

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigCho.lua", ScriptVersion)

-- Check if we are using the right champion

local flashSpell = nil
-- Check if Player has flash
if string.find(string.lower(LocalPlayer:GetSpell(SpellSlots.Summoner1).Name), "flash") then
    flashSpell = SpellSlots.Summoner1
elseif string.find(string.lower(LocalPlayer:GetSpell(SpellSlots.Summoner2).Name), "flash") then
    flashSpell = SpellSlots.Summoner2
end



-- Globals
local Cho = {}
local Utils = {}

Cho.TargetSelector = nil
Cho.Logic = {}

-- Spells
Cho.Q = SpellLib.Skillshot({
    Slot = SpellSlots.Q,
    Range = 950,
    Radius = 175,
    Delay = 1.125,
    Speed = math.huge,
    Type = "Circular"
})

Cho.W = SpellLib.Skillshot({
    Slot = SpellSlots.W,
    Range = 650,
    Speed = math.huge,
    Delay = 0.5,
    Angle = 60,
    Radius = 60,
    Type = "Cone"
})

Cho.E = SpellLib.Active({
    Slot = SpellSlots.E,
    Range = 175,

})

Cho.R = SpellLib.Targeted({
    Slot = SpellSlots.R,
    Range = LocalPlayer.BoundingRadius + 175,
    Delay = 0.25,
    Type = "Targeted",


})

Cho.Flash = SpellLib.Targeted({
    Slot = SpellSlots.Summoner1,
    Range = 400,
    Delay = 0,
    Type = "Targeted",

})

-- Utils


local CastSpell = function(slot, position, condition)
    local tick = os_clock()
    if LastCastT[slot] + 0.1 < tick then
        if Input.Cast(slot, position) then
            LastCastT[slot] = tick
            if condition ~= nil then
                return true and (type(condition) == "function" and condition() or type(condition) == "boolean" and condition)
            end
            return true
        end
    end
    return false
end

function Utils.GetEBonusRange()


    local ultLevel = Cho.R:GetLevel()

    if ultLevel == 0 then
        return 50
    end

    local stacks = Utils.addStackRange()

    local rangeModifier = ({ 4.5, 6, 7.5 })[Cho.R:GetLevel()]

    local rangeAdded = (stacks * rangeModifier) + 50

    if rangeAdded >= 75 then
        return 75
    end

    return rangeAdded

end

function Utils.addStackRange()

    local buffs = LocalPlayer.Buffs

    for k, v in pairs(buffs) do

        if (v.Name == "Feast") then


            return v.Count

        end


    end

    return 0

end

function getUltDmg()

    local dmgR = 125 + 175 * LocalPlayer:GetSpell(SpellSlots.R).Level
    local bonusDmg = LocalPlayer.TotalAP / 2 + LocalPlayer.BonusHealth / 10

    return dmgR + bonusDmg

end

function getWDmg(Target)

    if not Cho.W:IsLearned() then
        return 0

    end

    if not Cho.W:IsReady() then
        return 0

    end

    local baseDmg = ({ 75, 125, 175, 225, 275 })[Cho.W:GetLevel()]

    local apDmg = LocalPlayer.TotalAP * 0.7

    local totalDmg = baseDmg + apDmg

    return DamageLib.CalculateMagicalDamage(LocalPlayer, Target, totalDmg)


end

function getQDmg(Target)

    if not Cho.Q:IsLearned() then
        return 0

    end

    if not Cho.Q:IsReady() then
        return 0

    end

    local baseDmg = ({ 80, 135, 190, 245, 300 })[Cho.Q:GetLevel()]

    local apDmg = LocalPlayer.TotalAP

    local totalDmg = baseDmg + apDmg

    return DamageLib.CalculateMagicalDamage(LocalPlayer, Target, totalDmg)


end

function getUltMinionDmg()

    local dmgR = 1000
    local bonusDmg = LocalPlayer.TotalAP / 2 + LocalPlayer.BonusHealth / 10

    return dmgR + bonusDmg

end

function Utils.IsGameAvailable()
    -- Is game available to automate stuff
    return not (Game.IsChatOpen() or Game.IsMinimized() or LocalPlayer.IsDead)
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
    return LocalPlayer.BoundingRadius + Target.BoundingRadius
end

function Utils.IsValidTarget(Target)
    return Target and Target.IsTargetable and Target.IsAlive
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

function Cho.Logic.W(Target, Enable, HitChance)


    if not Cho.W:IsReady() then
        return
    end

    if not Utils.IsValidTarget(Target) then
        return
    end

    if not HitChance == nil and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Cho.W.Range) then

        Input.Cast(SpellSlots.W, Target)

    end

    if Enable and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Cho.W.Range) then

        Cho.W:Cast(Target)

        return true
    end

end

function Cho.Logic.Q(Target, Hitchance, Enable, Auto)

    local weqd = false

    if not Cho.Q:IsReady() then
        return
    end
    if not Utils.IsValidTarget(Target) then
        return
    end

    if Enable and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Cho.Q.Range) then


        if Auto then

            Cho.Q:CastOnHitChance(Target, Hitchance)


        end


    end

    if Enable and Hitchance >= Menu.Get("Combo.Q.HitChance") then

        Cho.Q:CastOnHitChance(Target, Hitchance)
        return true

    end


end

function Cho.Logic.E(Target, Enable)
    if not Cho.E:IsReady() then
        return false
    end

    if not Utils.IsValidTarget(Target) then
        return false
    end

    if Enable and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, 160 + LocalPlayer.BoundingRadius + Utils.GetEBonusRange()) then


        return Cho.E:Cast()
    end
end

function Cho.Logic.R(Target, Enable, EnableFlash)

    if not Cho.R:IsReady() then
        return false
    end

    if not Utils.IsValidTarget(Target) then
        return false
    end

    if Target.HasUndyingBuff then
        return false
    end

    if Enable and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Cho.R.Range) then
        return Input.Cast(Cho.R.Slot, Target)

    elseif Enable and EnableFlash and Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, LocalPlayer.BoundingRadius + Cho.R.Range + 375) then

        if flashSpell ~= nil then

            Input.Cast(flashSpell, Target.Position)

            return Input.Cast(Cho.R.Slot, Target)

        end


    end

    return false
end

function Cho.Logic.Waveclear()

    if Menu.Get("Wave.E.Use") then
        Cho.E:Cast()
    end

    local pPos, pointsE, pointsR = LocalPlayer.Position, {}, {}

    -- Enemy Minions
    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if Utils.ValidMinion(minion) then
            local posE = minion:FastPrediction(Cho.Q.Delay)
            local posR = minion:FastPrediction(Cho.W.Delay)
            if posE:Distance(pPos) < Cho.Q.Range and minion.IsTargetable then
                table.insert(pointsE, posE)
            end
            if posR:Distance(pPos) < Cho.W.Range and minion.IsTargetable then
                table.insert(pointsR, posR)
            end
        end
    end

    -- Jungle Minions
    if #pointsE == 0 or pointsR == 0 then
        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            if Utils.ValidMinion(minion) then
                local posE = minion:FastPrediction(Cho.Q.Delay)
                local posR = minion:FastPrediction(Cho.W.Delay)
                if posE:Distance(pPos) < Cho.Q.Range then
                    table.insert(pointsE, posE)
                end
                if posR:Distance(pPos) < Cho.W.Range then
                    table.insert(pointsR, posR)
                end
            end
        end
    end

    local bestPosE, hitCountE = Geometry.BestCoveringCircle(pointsE, Cho.Q.Radius)
    if bestPosE and hitCountE >= Menu.Get("Wave.Q.HitCount")
        and LocalPlayer:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Wave.Q.Use")
        and LocalPlayer.Mana >= (Menu.Get("Wave.Q.MinMana") / 100) * LocalPlayer.MaxMana then
        Input.Cast(SpellSlots.Q, bestPosE)
    end

    local bestPosR, hitCountR = Geometry.BestCoveringCone(pointsR, pPos, Cho.W.Radius)
    if bestPosR and hitCountR >= Menu.Get("Wave.W.HitCount")
        and LocalPlayer:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Wave.W.Use")
        and LocalPlayer.Mana >= (Menu.Get("Wave.W.MinMana") / 100) * LocalPlayer.MaxMana then
        Input.Cast(SpellSlots.W, bestPosR)
    end
end

function Cho.Logic.Harass()

    local Target = TS:GetTarget(Cho.Q.Range, true)

    if LocalPlayer.Mana >= (Menu.Get("Harass.Q.MinMana") / 100) * LocalPlayer.MaxMana then

        if Cho.Logic.Q(Target, Menu.Get("Harass.Q.HitChance"), Menu.Get("Harass.Q.Use"), false) then
            return true
        end

    end

    if LocalPlayer.Mana >= (Menu.Get("Harass.W.MinMana") / 100) * LocalPlayer.MaxMana then

        if Cho.Logic.W(Target, Menu.Get("Harass.W.Use"), nil) then
            return true
        end

    end


end

function Cho.Logic.Combo()


    local Target = TS:GetTarget(Cho.Q.Range, true)

    --print(LocalPlayer.AttackRange)
    -- print(LocalPlayer.BoundingRadius)

    if Target then


        if Cho.R:IsReady() then

            if (getUltDmg() >= Target.Health + 15) then

                if LocalPlayer:GetSpellState(SpellSlots.R) == SpellStates.Ready then
                    Cho.Logic.R(Target, Menu.Get("Combo.R.Use"), Menu.Get("Combo.R.Flash.Use"))

                    return true
                end

            end

        end
    end

    if Cho.Logic.E(Target, Menu.Get("Combo.E.Use")) then
        return true
    end

    if Cho.Logic.Q(Target, Menu.Get("Combo.Q.HitChance"), Menu.Get("Combo.Q.Use"), false) then
        return true
    end

    if Cho.Logic.W(Target, Menu.Get("Combo.W.Use"), nil) then
        return true
    end

    return false

end

function Cho.LoadMenu()
    Menu.RegisterMenu("BigCho", "BigCho", function()

        Menu.NewTree("BigChoCombo", "Combo", function()

            Menu.Checkbox("Combo.Q.Use", "Cast Q", true)
            Menu.Dropdown("Combo.Q.HitChance", "HitChance", 6, HitChanceStrings)
            Menu.Checkbox("Combo.W.Use", "Cast W", true)
            Menu.Checkbox("Combo.E.Use", "Cast E", true)
            Menu.Checkbox("Combo.R.Use", "Cast R", true)
            Menu.Checkbox("Combo.R.Flash.Use", "Use Flash to R", true)

            Menu.NextColumn()
        end)

        Menu.NewTree("BigChoWClear", "Waveclear", function()

            Menu.Checkbox("Wave.Safety.Use", "Only use spells when no enemy champions nearby", true)
            Menu.Checkbox("Wave.Q.Use", "Cast Q", true)
            Menu.Slider("Wave.Q.HitCount", "Minimum number of minions hit", 3, 1, 6, 1)
            Menu.Slider("Wave.Q.MinMana", "Q % Min. Mana", 50, 1, 100, 1)
            Menu.Checkbox("Wave.W.Use", "Cast W", true)
            Menu.Slider("Wave.W.HitCount", "Minimum number of minions hit", 3, 1, 6, 1)
            Menu.Slider("Wave.W.MinMana", "W % Min. Mana", 50, 1, 100, 1)
            Menu.Checkbox("Wave.E.Use", "Cast E", true)
            Menu.Slider("Wave.E.MinMana", "E % Min. Mana", 50, 1, 100, 1)

            Menu.NextColumn()
        end)

        Menu.NewTree("BigChoHarass", "Harass", function()

            Menu.Checkbox("Harass.Q.Use", "Cast Q", true)
            Menu.Dropdown("Harass.Q.HitChance", "HitChance", 6, HitChanceStrings)
            Menu.Slider("Harass.Q.MinMana", "Q % Min. Mana", 50, 1, 100, 1)
            Menu.Checkbox("Harass.W.Use", "Cast W", true)
            Menu.Slider("Harass.W.MinMana", "W % Min. Mana", 50, 1, 100, 1)

            Menu.NextColumn()
        end)

        Menu.NewTree("BigChoAutoR", "Auto Settings", function()
            Menu.Checkbox("Auto.R.RareMinion", "Auto R Baron, Herald, Dragon", true)
            Menu.Checkbox("Auto.R.Hero", "Auto R killable champions in range", true)
            Menu.Checkbox("Auto.Q.GapClose", "Auto Q on gap close or immobile targets", true)
            Menu.Checkbox("Auto.W.GapClose", "Auto W on gap close or immobile targets", true)

        end)

        Menu.NewTree("Drawings", "Drawings", function()
            Menu.Checkbox("Drawings.Q", "Draw Q", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw E", true)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.W", "Draw W", true)
            Menu.ColorPicker("Drawings.W.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.R", "Draw R", true)
            Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)
            Menu.Checkbox("Draw.ComboDamage", "Draw Combo Damage", true)

        end)
    end)
end

function Cho.Logic.Auto()


    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
        local minion = v.AsMinion
        if v.IsBaron or v.IsHerald or v.IsDragon then

            if minion.Health <= getUltMinionDmg() and Menu.Get("Auto.R.RareMinion") then
                Input.Cast(Cho.R.Slot, minion)
                return true
            end

        end

    end

    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
        local enemy = v.AsHero

        local target = TS:GetTarget(Cho.R.Range + LocalPlayer.BoundingRadius, true)

        if target then

            if target.Health <= getUltDmg() and Menu.Get("Auto.R.Hero") then


                Input.Cast(Cho.R.Slot, enemy)
                return true

            end


        end


    end

    if Menu.Get("Auto.Q.GapClose") then

        for _, Target in pairs(ObjectManager.Get("enemy", "heroes")) do

            if Target then
                Target = Target.AsAI

                if Cho.Logic.Q(Target, HitChance.Dashing, true, true) then

                    return true

                end

                if Cho.Logic.Q(Target, HitChance.Immobile, true, true) then

                    return true


                end

                if Cho.Logic.W(Target, true, HitChance.Dashing) then

                    return true

                end

                if Cho.Logic.W(Target, true, HitChance.Immobile) then

                    return true


                end

                return true
            end


        end

    end

    return false

end

function Cho.OnDrawDamage(target, dmgList)
    if not Menu.Get("Draw.ComboDamage") then
        return
    end

    local damageToDeal = 0

    local useQ = Cho.Q:IsReady() and Menu.Get("Combo.Q.Use")
    local useW = Cho.W:IsReady() and Menu.Get("Combo.W.Use")
    local useR = Cho.R:IsReady() and Menu.Get("Combo.R.Use")

    if useQ then

        damageToDeal = damageToDeal + getQDmg(target)
    end

    if useW then

        damageToDeal = damageToDeal + getWDmg(target)
    end

    if useR then
        damageToDeal = damageToDeal + getUltDmg()
    end

    table.insert(dmgList, damageToDeal)
end

function Cho.OnDraw()
    -- If player is not on screen than don't draw
    if not LocalPlayer.IsOnScreen then
        return false
    end
    ;
    -- Get spells ranges
    local Spells = { Q = Cho.Q, W = Cho.W, E = Cho.E, R = Cho.R }

    -- Draw them all

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(LocalPlayer.Position, 160 + LocalPlayer.BoundingRadius + Utils.GetEBonusRange(), 30, 1, Menu.Get("Drawings.E.Color"))
    end
    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(LocalPlayer.Position, Cho.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(LocalPlayer.Position, Cho.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.W") then
        Renderer.DrawCircle3D(LocalPlayer.Position, Cho.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
    end

    return true
end

function Cho.OnTick()
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Cho.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic() then
            return true
        end
    end

    if Cho.Logic.Auto() then
        return true
    end

    return false

end

function OnLoad()

    INFO("Welcome to BigCho, enjoy your stay")
    Cho.LoadMenu()

    for EventName, EventId in pairs(Events) do
        if Cho[EventName] then
            EventManager.RegisterCallback(EventId, Cho[EventName])
        end
    end

    return true

end
