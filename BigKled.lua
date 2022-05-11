--[[
    BigKled
]]

if Player.CharName ~= "Kled" then
    return false
end



module("BKled", package.seeall, log.setup)
clean.module("BKled", package.seeall, log.setup)



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
local LocalPlayer = ObjectManager.Player.AsHero
local qTimer = { nil, nil }

local ScriptVersion = "1.1.0"
local ScriptLastUpdate = "21. February 2022"



CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigKled.lua", ScriptVersion)


-- Globals
local Kled = {}
local Utils = {}

Kled.TargetSelector = nil
Kled.Logic = {}

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
Kled.Q = SpellLib.Skillshot({

    Slot = SpellSlots.Q,
    Range = 830,
    Width = 90,
    Speed = 500,
    Type = "Linear",
    Collisions = { Wall = false, Heroes = true, Minions = false }


})
Kled.RiderQ = SpellLib.Skillshot({

    Slot = SpellSlots.Q,
    Range = 700,
    Width = 80,
    Angle = 20,
    Speed = 3000,
    Type = "Cone",
    Delay = 0.25


})
Kled.E = SpellLib.Skillshot({

    Slot = SpellSlots.E,
    Range = 600,
    Width = 230,
    Speed = 500,
    Type = "Linear",
    Collisions = { Wall = true, Heroes = true }


})
Kled.W = SpellLib.Active({

    Slot = SpellSlots.W,

})
Kled.R = SpellLib.Targeted({
    Slot = SpellSlots.R,
})

-- Functions
function CheckIgniteSlot()
    local slots = { Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2 }

    local function IsIgnite(slot)
        return LocalPlayer:GetSpell(slot).Name == "SummonerDot"
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
        return LocalPlayer:GetSpell(slot).Name == "SummonerFlash"
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

    if not Kled.R:IsLearned() then
        return 0
    end
    if not Kled.R:IsReady() then
        return 0
    end

    if Target == nil then
        return
    end

    local healthDmgModifier = ({ 4, 5, 6 })[LocalPlayer:GetSpell(SpellSlots.R).Level]

    local bonusAdModifier = 0

    if LocalPlayer.BonusAD >= 100 and LocalPlayer.BonusAD < 200 then
        bonusAdModifier = 4
    elseif LocalPlayer.BonusAD >= 200 and LocalPlayer.BonusAD < 300 then
        bonusAdModifier = 8
    elseif LocalPlayer.BonusAD >= 300 and LocalPlayer.BonusAD < 400 then
        bonusAdModifier = 16
    elseif LocalPlayer.BonusAD >= 400 and LocalPlayer.BonusAD < 499 then
        bonusAdModifier = 20
    end


    local totalModifier = bonusAdModifier + healthDmgModifier

    return Target.MaxHealth / 100 * totalModifier

end

function GetIgniteDmg(target)

    CheckIgniteSlot()

    if UsableSS.Ignite.Slot == nil then

        return 0
    end

    if LocalPlayer:GetSpellState(UsableSS.Ignite.Slot) == nil then

        return 0

    end

    if not UsableSS.Ignite.Slot ~= nil and LocalPlayer:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready then


        return 50 + (20 * LocalPlayer.Level) - target.HealthRegen * 2.5

    end

    return 0


end

function Utils.GetEDamage(target)

    if not Kled.E:IsLearned() or not Kled.E:IsReady() then
        return 0
    end

    local baseDmg = ({ 70, 120, 170, 220, 270 })[Kled.E:GetLevel()]

    local bonusAD = LocalPlayer.BonusAD * 1.2

    return DamageLib.CalculatePhysicalDamage(LocalPlayer, target, baseDmg + bonusAD)

end

function CanKill(target)

    if not Menu.Get("Draw.ComboDamage") then
        return
    end

    local damageToDeal = 0

    local useIgnite = false

    if GetIgniteDmg(target) ~= 0 then
        useIgnite = true
    end

    local useQ = Kled.Q:IsReady()
    local useE = false
    local useR = Kled.R:IsReady() and Menu.Get("Combo.R.Use")

    if useQ then

        damageToDeal = damageToDeal + GetQDmg(target)
    end

    if useIgnite then
        damageToDeal = damageToDeal + GetIgniteDmg(target)
    end

    if useR then
        damageToDeal = damageToDeal + GetUltDmg(target)
    end

    return target.Health + target.ShieldAll - damageToDeal <= 0

end

-- Utils


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

function Utils.IsKillable(target)

    local damageToDeal = 0

    local useQ = Kled.Q:IsReady() and Kled.Q:IsLearned() and Menu.Get("Combo.Q.Use")
    local useE = Kled.E:IsReady() and Kled.E:IsLearned() and Menu.Get("Combo.E.Use")
    local useR = Kled.R:IsReady() and Kled.R:IsLearned()

    if useQ then

        damageToDeal = damageToDeal + Utils.GetQDmg(target)
    end

    if useE then
        damageToDeal = damageToDeal + Utils.GetEDamage(target)
    end

    if Kled.W:IsLearned() and Kled.W:IsReady() then

        damageToDeal = damageToDeal + Utils.GetWDmg(target)

        local ammo = LocalPlayer:GetSpell(Kled.W.Slot).Ammo

        if ammo == -1 then
            damageToDeal = damageToDeal + Utils.GetWDmg(target) + DamageLib.GetAutoAttackDamage(LocalPlayer, target, true) * 4
        else
            damageToDeal = damageToDeal + Utils.GetWDmg(target) + DamageLib.GetAutoAttackDamage(LocalPlayer, target, true) * ammo

        end

        damageToDeal = damageToDeal + GetIgniteDmg(target)



    end

    if useR then
        damageToDeal = damageToDeal + GetUltDmg(target)
    end

    if target.Health - damageToDeal <= 0 then return true

    end

    return false

end

function Utils.CountMinionsInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            LocalPlayer:Distance(minion) < range then
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
            LocalPlayer:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function Utils.GetQDmg(target)

    if target == nil then
        return 0
    end

    if not Kled.Q:IsLearned() or not Kled.Q:IsReady() then
        return 0

    end

    local baseDmg = ({ 30, 55, 80, 105, 130 })[Kled.Q:GetLevel()]
    local bonusAdDmg = LocalPlayer.BonusAD * 0.6

    local totalDmg = (baseDmg + bonusAdDmg) * 2

    return DamageLib.CalculatePhysicalDamage(LocalPlayer, target, totalDmg)

end

function Utils.PrintBuffs(target)

    for i, v in pairs(target.Buffs) do

        if v.Name == "KledRunCycleManager" then
            print(v.Count)
            print(v.DurationLeft)
        end


    end


end

function Utils.GetWDmg(target)

    if target == nil then
        return 0
    end

    if not Kled.W:IsLearned() or not Kled.W:IsReady() then
        return 0

    end

    local bonusModifier = ({ 4.5, 5, 5.5, 6, 6.5 })[Kled.W:GetLevel()]
    local baseDmg = ({ 20, 30, 40, 50, 60 })[Kled.W:GetLevel()]

    local bonusAdModifier = 0

    if LocalPlayer.BonusAD >= 100 and LocalPlayer.BonusAD < 200 then
        bonusAdModifier = 5
    elseif LocalPlayer.BonusAD >= 200 and LocalPlayer.BonusAD < 300 then
        bonusAdModifier = 10
    elseif LocalPlayer.BonusAD >= 300 and LocalPlayer.BonusAD < 400 then
        bonusAdModifier = 15
    elseif LocalPlayer.BonusAD >= 400 and LocalPlayer.BonusAD < 499 then
        bonusAdModifier = 20
    end

    local totalModifier = bonusAdModifier + bonusModifier

    local totalDmg = baseDmg + target.MaxHealth / 100 * totalModifier

    return DamageLib.CalculatePhysicalDamage(LocalPlayer, target, totalDmg)

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

function Kled.OnProcessSpell(obj, SpellCast)

    if obj.IsMe then


    end


end

function Kled.OnBuffGain(obj, buffInst)

    if not obj then
        return
    end
    if not obj.IsEnemy then
        return
    end

    if not buffInst.Name == "kledqmark" then
        return
    end

    qTimer = { obj.AsAI, Game.GetTime() }

end

function Kled.OnBuffLost(obj, buffInst)

    if not obj then
        return
    end
    if not obj.IsEnemy then
        return
    end

    if not buffInst.Name == "kledqmark" then
        return
    end

    qTimer = { nil, nil }

end

function Kled.OnGapclose(source, dash)

    if not (source.IsEnemy) then
        return
    end

    if Kled.Q:IsReady() and Menu.Get("Auto.Q.GapClose") and Kled.Q:CastOnHitChance(source, Enums.HitChance.VeryHigh) then
        return
    end
end

function Kled.Logic.R(Target)


    if Target == nil then return false end
    if not Kled.R:IsLearned() or not Kled.R:IsReady() then return false end
    if not Menu.Get("Combo.R.Use") then return false end
    if not Menu.Get("R" .. Target.AsHero.CharName) then return false end

    if Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Kled.E.Range) and Utils.IsKillable(Target) and not Target.IsDead then
        return Input.Cast(SpellSlots.R, Target.Position)
    end


    return false
end

function Kled.Logic.Q(Target)

    if not Target then
        return false
    end

    if not Kled.Q:IsLearned() then
        return false
    end
    if not Kled.Q:IsReady() then
        return false
    end

    if LocalPlayer:GetSpell(SpellSlots.Q).Name == "KledRiderQ" then

        if LocalPlayer.FirstResource >= 75 then
            return Kled.RiderQ:CastOnHitChance(Target, Menu.Get("Combo.Q.HitChance") / 100)
        end

        if Kled.W:IsLearned() then

            if not Kled.W:IsReady() then

                local wCooldown = LocalPlayer:GetSpell(SpellSlots.W).RemainingCooldown

                if wCooldown >= 1 and LocalPlayer.FirstResource < 45 then


                    return Kled.RiderQ:CastOnHitChance(Target, Menu.Get("Combo.Q.HitChance") / 100)

                end

            end

        end

        return false

    end

    if Kled.Q:CastOnHitChance(Target, Menu.Get("Combo.Q.HitChance") / 100) then
        return true
    end

    return false

end

function Kled.Logic.E(Target)

    if not Target then
        return false
    end

    if not Kled.E:IsLearned() then
        return false
    end
    if not Kled.E:IsReady() then
        return false
    end

    local eBuff = nil
    local hasE2 = false

    for i, v in pairs(LocalPlayer.Buffs) do
        if v.Name == "KledE2" then
            hasE2 = true
            eBuff = v
        end
    end

    if not hasE2 then
        Kled.E:CastOnHitChance(Target, Menu.Get("Combo.E.HitChance") / 100)
        return true
    end

    if hasE2 and Target.IsDashing then
        Input.Cast(SpellSlots.E)
        return true
    end

    if qTimer[1] == nil then

        if hasE2 and not Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, LocalPlayer.BoundingRadius + 160) and not Target.IsDead then
            Input.Cast(SpellSlots.E)
            return true
        end

    end

    if qTimer[1] ~= nil then
        local radius = 840 - (Game.GetTime() - qTimer[2]) * 134.5
        local Distance = Target:Distance(LocalPlayer)
        if Distance + 50 >= radius then


            Input.Cast(SpellSlots.E)
            return true
        end
    end

    if hasE2 and eBuff.DurationLeft <= 0.2 and not Target.IsDead then
        Input.Cast(SpellSlots.E)
        return true
    end

    return false


end

function Kled.Logic.Waveclear()


    if Menu.Get("Wave.Spells.Safety") then

        local target = TS:GetTarget(Menu.Get("Wave.Safety.Slider"))

        if target then
            return true
        end

    end

    local pPos, pointsQ, pointsE = LocalPlayer.Position, {}, {}

    -- Enemy Minions
    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if Utils.ValidMinion(minion) then
            local posQ = minion:FastPrediction(Kled.Q.Delay)
            local posE = minion:FastPrediction(Kled.E.Delay)
            if posQ:Distance(pPos) < Kled.Q.Range and minion.IsTargetable then
                table.insert(pointsQ, posQ)
            end
            if posE:Distance(pPos) < Kled.E.Range and minion.IsTargetable then
                table.insert(pointsE, posE)
            end
        end
    end

    -- Jungle Minions
    if #pointsQ == 0 or pointsE == 0 then

        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            if Utils.ValidMinion(minion) then
                local posQ = minion:FastPrediction(Kled.Q.Delay)
                local posE = minion:FastPrediction(Kled.E.Delay)
                if posQ:Distance(pPos) < Kled.Q.Range then
                    table.insert(pointsQ, posQ)
                end
                if posE:Distance(pPos) < Kled.E.Range then
                    table.insert(pointsE, posE)
                end
            end
        end


    end

    local bestposQ, hitCountE = Geometry.BestCoveringRectangle(pointsQ, pPos, Kled.Q.Width)

    if bestposQ and hitCountE >= Menu.Get("Wave.Q.HitCount") and Menu.Get("Wave.Q.Use")
        and LocalPlayer:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Wave.Q.Use") then
        Input.Cast(SpellSlots.Q, bestposQ)
        return true
    end

    -- Find best position to cast E
    local bestposE, hitCountR = Geometry.BestCoveringRectangle(pointsE, pPos, Kled.E.Width)

    -- If Minions
    if bestposE and hitCountR >= Menu.Get("Wave.E.HitCount") and Menu.Get("Wave.E.Use") then

        Input.Cast(SpellSlots.E, bestposE)
        return true
    end

    return false

end

function Kled.Logic.Harass()

    -- Utils.PrintBuffs(LocalPlayer)


    local target = TS:GetTarget(Kled.Q.Range)

    if target == nil then
        return false
    end



    if Menu.Get("Harass.Q.Use") then


        if LocalPlayer:GetSpell(SpellSlots.Q).Name == "KledRiderQ" then
            return Kled.RiderQ:CastOnHitChance(target, Menu.Get("Harass.Q.HitChance") / 100)
        end

        return Kled.Q:CastOnHitChance(target, Menu.Get("Harass.Q.HitChance") / 100)

    end

end

function Kled.Logic.Combo()


    local Target = TS:GetTarget(1000, true)

    if not Target then
        return
    end

    if Kled.Logic.R(Target) then
        return true
    end

    if Kled.Logic.E(Target) then
        return true
    end

    if Kled.Logic.Q(Target) then
        return true
    end

    return false


end

function Kled.Logic.Flee()


end

function Kled.Logic.Auto()


end

function Kled.OnDrawDamage(target, dmgList)

    if not Menu.Get("Draw.ComboDamage") then
        return
    end

    local damageToDeal = 0

    local useQ = Kled.Q:IsReady() and Kled.Q:IsLearned() and Menu.Get("Combo.Q.Use")
    local useE = Kled.E:IsReady() and Kled.E:IsLearned() and Menu.Get("Combo.E.Use")
    local useR = Kled.R:IsReady() and Kled.R:IsLearned()

    if useQ then

        damageToDeal = damageToDeal + Utils.GetQDmg(target)
    end

    if useE then
        damageToDeal = damageToDeal + Utils.GetEDamage(target)
    end

    if Kled.W:IsLearned() and Kled.W:IsReady() then

        damageToDeal = damageToDeal + Utils.GetWDmg(target)

        local ammo = LocalPlayer:GetSpell(Kled.W.Slot).Ammo

        if ammo == -1 then
            damageToDeal = damageToDeal + Utils.GetWDmg(target) + DamageLib.GetAutoAttackDamage(LocalPlayer, target, true) * 4
        else
            damageToDeal = damageToDeal + Utils.GetWDmg(target) + DamageLib.GetAutoAttackDamage(LocalPlayer, target, true) * ammo

        end

        damageToDeal = damageToDeal + GetIgniteDmg(target)



    end

    if useR then
        damageToDeal = damageToDeal + GetUltDmg(target)
    end


    table.insert(dmgList, damageToDeal)



end

function Kled.OnDraw()

    if LocalPlayer:GetSpell(SpellSlots.Q).Name == "KledRiderQ" then

        Renderer.DrawTextOnPlayer("Kill " .. (math.floor((LocalPlayer.FirstResourceMax - LocalPlayer.FirstResource) / 4 + 0.5) .. " more minions to remount"))



    end




    -- If player is not on screen than don't draw
    if not LocalPlayer.IsOnScreen then
        return false
    end
    ;
    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(LocalPlayer.Position, Kled.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(LocalPlayer.Position, Kled.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end

    return true
end

function Kled.OnTick()
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Kled.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic() then
            return true
        end
    end

    if Kled.Logic.Auto() then
        return true
    end

    return false

end

function Kled.OnPostAttack(_target)

    local target = _target.AsAI
    if not target then
        return
    end

    local mode = Orbwalker.GetMode()
    local dist = target:Distance(LocalPlayer)

    if target.IsMonster and mode == "Waveclear" and target.MaxHealth > 6 then
        if dist < Kled.Q.Range and Kled.Q:Cast(target.Position) then
            return
        end

    end

end

function Kled.LoadMenu()
    Menu.RegisterMenu("BigKled", "BigKled", function()

        Menu.NewTree("BigKledCombo", "Combo", function()
            Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()
                Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [Q]:", 0xE3FFDF)
                Menu.Slider("Combo.Q.HitChance", "%", 35, 1, 100, 1)
                Menu.Text("")

            end)

            Menu.ColumnLayout("DrawMenu22", "DrawMenu22", 2, true, function()
                Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [E]:", 0xE3FFDF)
                Menu.Slider("Combo.E.HitChance", "%", 35, 1, 100, 1)
                Menu.Text("")

            end)
            Menu.Checkbox("Combo.R.Use", "Cast [R] if combo can kill", true)
            Menu.NewTree("R Menu", "Whitelist R", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "Use [R] for " .. Name, false)
                end
            end)


            Menu.NextColumn()
        end)

        Menu.NewTree("BigKledHarass", "Harass", function()

            Menu.ColumnLayout("DrawMenu3223", "DrawMenu32233", 2, true, function()
                Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [Q]:", 0xE3FFDF)
                Menu.Slider("Harass.Q.HitChance", "%", 35, 1, 100, 1)
                Menu.Text("")

            end)
        end)

        Menu.NewTree("BigKledWClear", "Waveclear", function()

            Menu.Checkbox("Wave.Spells.Safety", "Cast Spells only when no enemy in Range", true)
            Menu.Slider("Wave.Safety.Slider", "Safety Range", 1500, 100, 2000, 100)
            Menu.Checkbox("Wave.Q.Use", "Cast [Q]", true)
            Menu.Slider("Wave.Q.HitCount", "Minimum Minions Hit", 3, 1, 6, 1)
            Menu.Checkbox("Wave.E.Use", "Cast [E]", true)
            Menu.Slider("Wave.E.HitCount", "Minimum Minions Hit", 3, 1, 6, 1)

            Menu.NextColumn()
        end)

        Menu.NewTree("BigKledESettings", "E Settings", function()

            Menu.Checkbox("Cast.E.TimeOut", "Cast [E2] if its about to expire", true)
            Menu.Checkbox("Cast.E.AARange", "Cast [E2] if in combo and target leaves AA range", true)
            Menu.Checkbox("Cast.E.OnDash", "Cast [E2] if in combo and target dashes away", true)

            Menu.NextColumn()
        end)

        Menu.NewTree("Auto Settings", "Misc Settings", function()

            Menu.Checkbox("Auto.Q.GapClose", "Auto Q on gapclose", true)

        end)

        Menu.NewTree("Drawings", "Drawings", function()

            Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw [E] Range", true)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Draw.ComboDamage", "Draw Combo Damage", true)


        end)
    end)
end

function OnLoad()

    INFO("Welcome to BigKled, enjoy your stay")

    Kled.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Kled[EventName] then
            EventManager.RegisterCallback(EventId, Kled[EventName])
        end
    end

    return true

end
