--[[
    BigVeigar
]]

if Player.CharName ~= "Veigar" then
    return false
end

module("BVeigar", package.seeall, log.setup)
clean.module("BVeigar", package.seeall, log.setup)


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
local tick = 1
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };
local ComboModeStrings = { "[Q] -> [E] -> [W]", "[E] -> [Q] -> [W]", "[E] -> [W] -> [Q]" };
local Player = ObjectManager.Player.AsHero

local ScriptVersion = "1.1.0"
local ScriptLastUpdate = "15 December 2021 -- Veigar Stun Adjustments, will cage more often instead of waiting for stun."
CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigVeigar.lua", ScriptVersion)


-- Globals
local Veigar = {}
local Utils = {}

Veigar.TargetSelector = nil
Veigar.Logic = {}


-- Spells
Veigar.Q = SpellLib.Skillshot({
    Slot = SpellSlots.Q,
    Delay = 0.25,
    Range = 875,
    Collisions = { Heroes = true, Minions = true, WindWall = true },
    MaxCollisions = 2,
    Radius = 70,
    Speed = 2200,
    Type = "Linear"
})
Veigar.W = SpellLib.Skillshot({
    Slot = SpellSlots.W,
    Range = 900,
    Speed = math.huge,
    Delay = 1.25,
    Radius = 235,
    Type = "Circular"
})
Veigar.E = SpellLib.Skillshot({
    Slot = SpellSlots.E,
    Range = 700,
    Delay = 1.25,
    Speed = math.huge,
    Radius = 375,
    Type = "Circular"

})
Veigar.E.Stunlock = SpellLib.Skillshot({
    Slot = SpellSlots.E,
    Range = 700,
    Delay = 1.25,
    Speed = math.huge,
    Radius = 20,
    Type = "Linear"

})
Veigar.R = SpellLib.Targeted({
    Slot = SpellSlots.R,
    Range = 650,
    Delay = 0.25,
    Type = "Targeted",
    Collisions = { WindWall = true }

})
Veigar.Flash = SpellLib.Targeted({
    Slot = SpellSlots.Summoner1,
    Range = 400,
    Delay = 0,
    Type = "Targeted",

})

-- Functions



function Utils.GetELoc(target)
    local myLoc = Player.Position
    local targetLoc = Prediction.GetPredictedPosition(target, Veigar.E.Stunlock, Player.Position)

    if not targetLoc then
        return false
    end

    local HighChance = HitChance.High
    local EChance = targetLoc.HitChance

    if not (EChance >= 0.8) then
        return
    end

    local targetLoc = targetLoc.TargetPosition

    local stunLoc = targetLoc - (targetLoc - myLoc):Normalized() * Veigar.E.Radius

    -- print(Player.Position:Distance(stunLoc))

    if Player.Position:Distance(stunLoc) < Veigar.E.Range then
        return stunLoc
    end

    return false
end
function getUltDmg(Target)

    if not Veigar.R:IsReady() then
        return 0
    end

    local dmgR = ({ 175, 212.5, 250, 287.5, 325 })[Player:GetSpell(SpellSlots.R).Level]
    local apDmg = Player.TotalAP * 0.75
    local normalDmg = dmgR + apDmg
    local TargetMissingHealth = 1 - Target.HealthPercent
    local MissingHealthModifier = 1

    if TargetMissingHealth >= 0.0667 then
        MissingHealthModifier = 1.1
    end
    if TargetMissingHealth >= 0.1333 then
        MissingHealthModifier = 1.2
    end
    if TargetMissingHealth >= 0.2 then
        MissingHealthModifier = 1.3
    end
    if TargetMissingHealth >= 0.2667 then
        MissingHealthModifier = 1.4
    end
    if TargetMissingHealth >= 0.3333 then
        MissingHealthModifier = 1.5
    end
    if TargetMissingHealth >= 0.4 then
        MissingHealthModifier = 1.6
    end
    if TargetMissingHealth >= 0.4667 then
        MissingHealthModifier = 1.7
    end
    if TargetMissingHealth >= 0.5333 then
        MissingHealthModifier = 1.8
    end
    if TargetMissingHealth >= 0.6 then
        MissingHealthModifier = 1.9
    end
    if TargetMissingHealth >= 0.6667 then
        MissingHealthModifier = 2
    end

    local totalUltDamage = normalDmg * MissingHealthModifier

    return DamageLib.CalculateMagicalDamage(Player, Target, totalUltDamage)

end
function getWDmg(Target)

    if not Veigar.W:IsLearned() then
        return 0

    end

    if not Veigar.W:IsReady() then
        return 0

    end

    local baseDmg = ({ 100, 150, 200, 250, 300 })[Veigar.W:GetLevel()]

    local apDmg = Player.TotalAP

    local totalDmg = baseDmg + apDmg

    return DamageLib.CalculateMagicalDamage(Player, Target, totalDmg)


end
function getQDmgOnMinion(Target)

    if not Veigar.Q:IsLearned() then
        return 0
    end

    local baseDmg = ({ 80, 120, 160, 200, 240 })[Veigar.Q:GetLevel()]

    local totalDmg = baseDmg + (Player.TotalAP * 0.6)

    return DamageLib.CalculateMagicalDamage(Player, Target, totalDmg)


end
function getQDmg(Target)

    if not Veigar.Q:IsLearned() then
        return 0

    end

    if not Veigar.Q:IsReady() then
        return 0

    end

    local baseDmg = ({ 80, 120, 160, 200, 240 })[Veigar.Q:GetLevel()]

    local totalDmg = baseDmg + (Player.TotalAP * 0.6)

    return DamageLib.CalculateMagicalDamage(Player, Target, totalDmg)


end
function executeCombo(mode)

    mode = Menu.Get("Combo.Mode")

    if mode == 0 then

        local Target = TS:GetTarget(1500)

        if not Target then
            return
        end

        if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.R.Range) then

            if Veigar.R:IsReady() then

                if HealthPrediction.GetKillstealHealth(Target, 0.25, "Magical") <= getUltDmg(Target) then

                    if Menu.Get("RC" .. Target.CharName) then
                        return Veigar.R:Cast(Target)
                    end
                end

            end

        end

        if Veigar.Logic.Q(Target, false) then
            return
        end

        if Veigar.Logic.E(Target, false) then
            return
        end

        if Veigar.Logic.W(Target, false) then
            return
        end

        return


    end

    if mode == 1 then


        local Target = TS:GetTarget(1500)

        if not Target then
            return
        end

        if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.R.Range) then

            if Veigar.R:IsReady() then

                if HealthPrediction.GetKillstealHealth(Target, 0.25, "Magical") <= getUltDmg(Target) then

                    if Menu.Get("RC" .. Target.CharName) then
                        return Veigar.R:Cast(Target)
                    end
                end

            end

        end

        if Veigar.Logic.E(Target, false) then
            return
        end

        if Veigar.Logic.Q(Target, false) then
            return
        end

        if Veigar.Logic.W(Target, false) then
            return
        end

        return

    end

    if mode == 2 then


        local Target = TS:GetTarget(1500)

        if not Target then
            return
        end

        if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.R.Range) then

            if Veigar.R:IsReady() then

                if HealthPrediction.GetKillstealHealth(Target, 0.25, "Magical") <= getUltDmg(Target) then

                    if Menu.Get("RC" .. Target.CharName) then
                        return Veigar.R:Cast(Target)
                    end
                end

            end

        end

        if Veigar.Logic.E(Target, false) then
            return
        end

        if Veigar.Logic.W(Target, false) then
            return
        end

        if Veigar.Logic.Q(Target, false) then
            return
        end

        return

    end


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
function Utils.AutoKS()

    for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do


        local Target = v

        if not Target then
            return
        end

        if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.R.Range) then

            if Veigar.R:IsReady() then
                if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.R.Range) then


                    if HealthPrediction.GetKillstealHealth(Target, 0.25, "Magical") <= getUltDmg(Target) then

                        if Menu.Get("R" .. Target.CharName) then
                            return Veigar.R:Cast(Target)
                        end
                    end


                end

            end

        end

        if Veigar.Q:IsReady() then
            if Utils.IsInRange(Player.Position, Target.Position, 0, 925) then

                if Veigar.Q:IsReady() then

                    if HealthPrediction.GetKillstealHealth(Target, 0.25, "Magical") <= getQDmg(Target) then
                        return Veigar.Q:CastOnHitChance(Target, 0.35)
                    end

                end

            end

        end


    end

end

function Veigar.OnHeroImmobilized(Source, EndTime, IsStasis)


    if Source.IsEnemy then
        if IsStasis then


            if Veigar.E:IsReady() then

                if Utils.IsInRange(Player.Position, Source.Position, 0, Veigar.E.Range) then
                    if EndTime - Game.GetTime() <= 1.5 then
                        local stunLoc = Utils.GetELoc(Source)

                        if stunLoc then
                            return Veigar.E:Cast(stunLoc)
                        end

                    end

                end

            end

            if Utils.IsInRange(Player.Position, Source.Position, 0, Veigar.W.Range) then
                if EndTime - Game.GetTime() <= 1.25 then
                    return Veigar.W:Cast(Source.Position)
                end

            end


        end
    end


end
function Veigar.OnExtremePriority(lagFree)


    if lagFree == 2 then

        Utils.AutoKS()

    end


end
function Veigar.OnCreateObject(obj, lagFree)


    --if obj.Name == "VeigarBalefulStrikeMis" then

    --print(obj.AsMissile.Speed)
    -- print(obj.AsMissile.Width)
    -- print(obj.SpellCastInfo.CastDelay)
    -- print(obj.SpellCastInfo.SpellData.DisplayRange)
    --print(obj.AsMissile.SpellCastInfo.SpellData.MissileSpeed)

    -- end


end
function Veigar.OnGapclose(source, dash)

    if Menu.Get("AutoWGap") then

        if Utils.IsInRange(Player.Position, source.Position, 0, Veigar.W.Range) then
            if Veigar.W:IsReady() then

                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then
                        if Veigar.W:CastOnHitChance(Hero, 0.7) then
                            return
                        end

                    end

                end

            end

        end

    end
    if Menu.Get("AutoEGap") then

        if Utils.IsInRange(Player.Position, source.Position, 0, Veigar.E.Range) then
            if Veigar.E:IsReady() then

                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then
                        if Veigar.E:CastOnHitChance(Hero, 0.70) then
                            return
                        end

                    end

                end

            end

        end

    end

end
function Veigar.OnPreAttack(args)

    local mode = Orbwalker.GetMode()

    if Menu.Get("Support") and args.Target.IsMinion and not args.Target.IsMonster and #ObjectManager.GetNearby("ally", "heroes") > 1 then

        if mode == "Harass" then
            args.Process = false
            return
        end
        if mode ~= "Waveclear" then
            return
        end
        args.Process = false
    end

end

function Veigar.Logic.W(Target)

    if Menu.Get("Combo.W.Use") then

        if Veigar.W:IsReady() then

            if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.W.Range) then

                return Veigar.W:CastOnHitChance(Target, Menu.Get("Combo.W.HitChance") / 100)

            end

        end

    end

    return false


end
function Veigar.Logic.Q(Target, Hitchance, Enable, Auto)


    if Menu.Get("Combo.Q.Use") then

        if Veigar.Q:IsReady() then

            if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.Q.Range) then
                return Veigar.Q:CastOnHitChance(Target, Menu.Get("Combo.Q.HitChance") / 100)

            end

        end

    end

    return false

end
function Veigar.Logic.E(Target, Enable)

    if Menu.Get("Combo.E.Use") then

        if Veigar.E:IsReady() then

            if Utils.IsInRange(Player.Position, Target.Position, 0, Veigar.E.Range + 150) then

                local eLoc = Utils.GetELoc(Target)

                if eLoc then

                    return Veigar.E:Cast(eLoc)

                end


            end

            if Utils.IsInRange(Player.Position, Target.Position, 0, 700) then
                return Veigar.E:CastOnHitChance(Target, Menu.Get("Combo.E.HitChance") / 100)
            end


        end

    end

    return false

end
function Veigar.Logic.R(Target, Enable, EnableFlash)


end

function Veigar.Logic.Waveclear(lagFree)

    if Menu.Get("LMBClear") then
        if not Menu.IsKeyPressed(1) then
            return
        end
    end

    local Q = Menu.Get("Waveclear.Q.Use")
    local E = Menu.Get("Waveclear.W.Use")
    local QJ = Menu.Get("Jungle.Q.Use")
    local EJ = Menu.Get("Jungle.W.Use")

    local pPos, pointsQ = Player.Position, {}
    local pointsE = {}

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and minion.MaxHealth > 6 and Veigar.Q:IsInRange(minion) then
                local pos = minion:FastPrediction(Game.GetLatency() + Veigar.Q.Delay)
                if pos:Distance(pPos) < Veigar.Q.Range and minion.IsTargetable then
                    table.insert(pointsQ, pos)
                end
            end
        end
    end

    if Q and Veigar.Q:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then
        local bestPos, hitCount = Veigar.Q:GetBestLinearCastPos(pointsQ, Veigar.Q.Radius)
        if bestPos and hitCount > 1 then
            Veigar.Q:Cast(bestPos)
        end
    end

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and minion.MaxHealth > 6 and Veigar.W:IsInRange(minion) then
                local pos = minion:FastPrediction(Game.GetLatency() + Veigar.W.Delay)
                if Veigar.W:GetToggleState() == 0 and pos:Distance(pPos) < Veigar.W.Range and minion.IsTargetable then
                    table.insert(pointsE, pos)
                end
            end
        end
    end

    if E and Veigar.W:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then
        local bestPos, hitCount = Veigar.W:GetBestCircularCastPos(pointsE, Veigar.W.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            Veigar.W:Cast(bestPos)
        end
    end
    if Veigar.Q:IsReady() and QJ then
        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = Veigar.Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if Veigar.Q:Cast(minion) then
                    return
                end
            end
        end
    end
    if Veigar.W:IsReady() and EJ then
        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = Veigar.W:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if Veigar.W:GetToggleState() == 0 and Veigar.W:Cast(minion) then
                    return
                end
                if Veigar.W:GetToggleState() == 2 then

                    if luxE ~= nil then

                        if protectedNameRetrieval(luxE, true) and v:Distance(minion) < Veigar.W.Radius then
                            if Veigar.E2:Cast() then
                                return
                            end
                        end

                    end

                end
            end
        end
    end

end
function Veigar.Logic.Harass()
    local target = TS:GetTarget(Veigar.Q.Range)

    if target == nil then
        return
    end

    if Menu.Get("Harass.Q.Use") then

        if Veigar.Q:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Veigar.Q.Range) and Menu.Get("Harass.Q.Mana") < (Player.ManaPercent * 100) then

            if Player.Mana > Player.MaxMana * (Menu.Get("Harass.Q.Mana") / 100) then

                return Veigar.Q:CastOnHitChance(target, Menu.Get("Harass.Q.HitChance")/100)

            end
        end
    end

    if Menu.Get("Harass.W.Use") then

        if Player.Mana > Player.MaxMana * (Menu.Get("Harass.W.Mana") / 100) then


            if Veigar.W:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Veigar.W.Range) and Menu.Get("Harass.W.Mana") < (Player.ManaPercent * 100) then

                return Veigar.W:CastOnHitChance(target, Menu.Get("Harass.W.HitChance")/100)

            end
        end
    end

    return false
end
function Veigar.Logic.Combo(lagFree)

    executeCombo(Menu.Get("Combo.Mode"))
    return

end
function Veigar.Logic.Auto(lag)


    if lag == 1 then
        if Menu.Get("AutoQFarm") then

            if Orbwalker.GetMode() == "Combo" then
                return
            end
            if Orbwalker.GetMode() == "Flee" then
                return
            end

            if not Veigar.Q:IsReady() then
                return
            end

            local manaPercent = Player.ManaPercent * 100

            if manaPercent >= Menu.Get("Auto.Stack.Mana") then

                local minionList = {}
                local canonWave = false

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do

                    if Utils.ValidMinion(v) then

                        if not v.IsDead then
                            table.insert(minionList, v)
                            if v.IsSiegeMinion then
                                canonWave = true
                            end

                        end

                    end

                    if canonWave then
                        if v.IsSiegeMinion then

                            local killableWithQ = HealthPrediction.GetHealthPrediction(v, Veigar.Q.Delay, false) <= getQDmgOnMinion(v) and HealthPrediction.GetHealthPrediction(v, 0.35, true) > 0

                            if Utils.IsInRange(Player.Position, v.Position, 0, Veigar.Q.Range) then


                                if killableWithQ then

                                    if Utils.ValidMinion(v) then
                                        Veigar.Q:CastOnHitChance(v, 0.55)
                                    end

                                end
                            end

                        end
                        return

                    else
                        local killableWithQ = HealthPrediction.GetHealthPrediction(v, Veigar.Q.Delay, false) <= getQDmgOnMinion(v) and HealthPrediction.GetHealthPrediction(v, 0.35, true) > 0

                        if Utils.IsInRange(Player.Position, v.Position, 0, Veigar.Q.Range) then


                            if killableWithQ then

                                if Utils.ValidMinion(v) then
                                    Veigar.Q:CastOnHitChance(v, 0.35)

                                end

                            end
                        end

                    end
                end
            end

        end
    end

    if lag == 2 then


        if Menu.Get("AutoQPoke") then

            if Orbwalker.GetMode() == "Combo" then
                return
            end
            if Orbwalker.GetMode() == "Flee" then
                return
            end

            if not Veigar.Q:IsReady() then
                return
            end

            for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                if Utils.IsInRange(Player.Position, v.Position, 0, Veigar.Q.Range) then

                    local manaPercent = Player.ManaPercent * 100

                    if manaPercent >= Menu.Get("Auto.Poke.Mana") then

                        if v.IsTargetable then

                            return Veigar.Q:CastOnHitChance(v, 0.55)

                        end

                    end

                end

            end
        end

    end

    if lag == 3 then
        if Menu.Get("AutoCage") then
            if Orbwalker.GetMode() ~= "Flee" then

                if Veigar.E:IsReady() then


                    local manaPercent = Player.ManaPercent * 100

                    local enemies = {}
                    local predLocations = {}

                    for k, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                        if Player.Position:Distance(v.Position) <= Veigar.E.Range + 200 then

                            if v.IsTargetable and not v.IsDead then

                                table.insert(enemies, v)

                            end

                        end

                    end

                    if #enemies >= 2 then


                        for i, v in ipairs(enemies) do


                            local prediction = Veigar.E:GetPrediction(v)

                            if prediction then

                                if Player:Distance(prediction.CastPosition) <= Veigar.E.Range then

                                    table.insert(predLocations, prediction.CastPosition)

                                end

                            end


                        end

                        local bestCovCircle, hits = Geometry.BestCoveringCircle(predLocations, 350)

                        if bestCovCircle then

                            Veigar.E:Cast(bestCovCircle)

                        end


                    end
                end

            end

        end
    end


end

function Veigar.LoadMenu()
    Menu.RegisterMenu("BigVeigarMain", "BigVeigar", function()


        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)
        Menu.Checkbox("Support", "Support Mode", false)
        Menu.Checkbox("Indicator", "Draw [Q] Indicator On Minions", true)
        Menu.Separator()

        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()

            Menu.Text("")
            Menu.Text("Combo Order")
            Menu.Dropdown("Combo.Mode", "", 0, ComboModeStrings)
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()


                Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [Q]:", 0xE3FFDF)
                Menu.Slider("Combo.Q.HitChance", "%", 35, 1, 100, 1)
                Menu.NextColumn()

                Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
                Menu.NextColumn()

                Menu.ColoredText("Hitchance [E]:", 0xE3FFDF)
                Menu.Slider("Combo.E.HitChance", "%", 55, 1, 100, 1)
                Menu.NextColumn()

                Menu.Checkbox("Combo.W.Use", "Cast [W]", true)
                Menu.NextColumn()

                Menu.ColoredText("Hitchance [W]:", 0xE3FFDF)
                Menu.Slider("Combo.W.HitChance", "%", 60, 1, 100, 1)

                Menu.Text("")

            end)
            Menu.Checkbox("Combo.R.Use", "Cast [R]", true)
            Menu.NewTree("RComboWhitelist", "[R] Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("RC" .. Name, "Use [R] for " .. Name, true)
                end
            end)

            Menu.Text("")

        end)
        Menu.NewTree("BigHeroHarass", "Harass [C]", function()

            Menu.Text("")
            Menu.ColumnLayout("DrawMenu222", "DrawMenu222", 2, true, function()
                Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [Q]:", 0xE3FFDF)
                Menu.Slider("Harass.Q.HitChance", "%", 35, 1, 100, 1)
                Menu.ColoredText("Minimum percent mana to use [Q]", 0xE3FFDF)
                Menu.Slider("Harass.Q.Mana", "Mana %", 50, 0, 100)
                Menu.NextColumn()
            end)
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu2223", "DrawMenu2232", 2, true, function()
                Menu.Checkbox("Harass.W.Use", "Cast [W]", true)
                Menu.NextColumn()
                Menu.ColoredText("Hitchance [W]:", 0xE3FFDF)
                Menu.Slider("Harass.W.HitChance", "%", 55, 1, 100, 1)
                Menu.ColoredText("Minimum percent mana to use [W]", 0xE3FFDF)
                Menu.Slider("Harass.W.Mana", "Mana %", 50, 0, 100)
                Menu.NextColumn()

                Menu.NextColumn()

            end)
            Menu.Text("")


        end)
        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()

            Menu.Checkbox("LMBClear", "Only Use Spells when Left Mouse Button Is Held", false)
            Menu.NewTree("Lane", "Laneclear Options", function()

                Menu.Checkbox("Waveclear.Q.Use", "Use [Q]", true)
                Menu.Checkbox("Waveclear.W.Use", "Use [W]", true)
                Menu.Text("Minimum percent mana to use spells")
                Menu.Slider("Lane.Mana", "Mana %", 50, 0, 100)
                Menu.Text("Minimum amount of minions hit to cast [W]")
                Menu.Slider("Lane.EH", "W Hitcount", 2, 1, 5)
            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q.Use", "Use [Q]", true)
                Menu.Checkbox("Jungle.W.Use", "Use [W]", true)
            end)


        end)
        Menu.NewTree("Auto Settings", "Auto Settings", function()
            Menu.Text("")
            Menu.Text("Auto [Q] Mana Settings")
            Menu.Text("")
            Menu.Text("Auto Stack Min Mana Percent")
            Menu.Slider("Auto.Stack.Mana", "", 30, 0, 100, 10)
            Menu.Text("")
            Menu.Text("Auto Harass Min Mana Percent")
            Menu.Slider("Auto.Poke.Mana", "", 30, 0, 100, 10)
            Menu.Separator()
            Menu.Checkbox("AutoCage", "Auto [E] if enemies hit is 2 or more", true)
            Menu.Separator()
            Menu.Checkbox("AutoWGap", "Auto [W] on gapclose", true)
            Menu.Checkbox("AutoEGap", "Auto [E] on gapclose", true)
            Menu.Separator()
            Menu.Checkbox("QKS", "Auto [Q] KS", true)
            Menu.Checkbox("RKS", "Auto [R] KS", true)
            Menu.NewTree("RKSWhitelist", "RKS Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "Use [R] for " .. Name, true)
                end
            end)
            Menu.Separator()


        end)
        Menu.NewTree("Drawings", "Range Drawings", function()


            Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw [E] Range", false)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.W", "Draw [W] Range", false)
            Menu.ColorPicker("Drawings.W.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.R", "Draw [R] Range", false)
            Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)


        end)
        Menu.NewTree("DmgDrawings", "Damage Drawings", function()


            Menu.Checkbox("DmgDrawings.Q", "Draw [Q] Dmg", true)

            Menu.Checkbox("DmgDrawings.W", "Draw [W] Dmg", true)

            Menu.Checkbox("DmgDrawings.R", "Draw [R] Dmg", true)


        end)

    end)
    Menu.RegisterPermashow("BigVeigar", "      BigVeigar  Settings      ", function()
        Menu.Keybind("AutoQFarm", "Auto Stack [Q]", string.byte("U"), true, true)
        Menu.Keybind("AutoQPoke", "Auto Harass [Q]", string.byte("L"), true, true)
    end, function()
        return true
    end)

end
function Veigar.OnDrawDamage(target, dmgList)

    local totalDmg = 0

    if Menu.Get("DmgDrawings.Q") then
        totalDmg = totalDmg + getQDmg(target)
    end

    if Menu.Get("DmgDrawings.R") then
        totalDmg = totalDmg + getUltDmg(target)
    end

    if Menu.Get("DmgDrawings.W") then
        totalDmg = totalDmg + getWDmg(target)
    end

    table.insert(dmgList, totalDmg)


end
function Veigar.OnDraw()
    if Menu.Get("Drawings.W") then
        Renderer.DrawCircle3D(Player.Position, Veigar.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, Veigar.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, Veigar.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Veigar.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end

    if Menu.Get("Indicator") then

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do

            if Utils.ValidMinion(v) then
                if not v.IsDead and not v.isTurret then

                    local killableWithQ = getQDmgOnMinion(v) >= v.Health

                    if killableWithQ then

                        if v.IsSiegeMinion then
                            Renderer.DrawCircle3D(v.Position, 100, 5, 5, 0x42FF00FF, false)
                        else
                            Renderer.DrawCircle3D(v.Position, 50, 5, 5, 0x42FF00FF, false)

                        end


                    else

                        if v.IsSiegeMinion then
                            Renderer.DrawCircle3D(v.Position, 100, 5, 5, 0xEF476FFF, false)
                        else
                            Renderer.DrawCircle3D(v.Position, 50, 5, 5, 0xEF476FFF, false)

                        end
                    end

                end

            end


        end

    end


end
function Veigar.OnTick(lag)


    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Veigar.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lag) then
            return true
        end
    end

    if Veigar.Logic.Auto(lag) then
        return true
    end

    return false

end
function OnLoad()

    INFO("Welcome to BigVeigar, enjoy your stay")
    Veigar.LoadMenu()

    for EventName, EventId in pairs(Events) do
        if Veigar[EventName] then
            EventManager.RegisterCallback(EventId, Veigar[EventName])
        end
    end

    return true

end
