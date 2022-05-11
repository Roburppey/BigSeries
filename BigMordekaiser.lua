--[[
    BigMordekaiser
]]

if Player.CharName ~= "Mordekaiser" then
    return false
end

module("BMordekaiser", package.seeall, log.setup)
clean.module("BMordekaiser", package.seeall, log.setup)






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
local ScriptVersion = "1.0.1"
local ScriptLastUpdate = "10. November 2021"
local iTick = 0
local Vector = Geometry.Vector
local luxE = nil
local Prediction = _G.Libs.Prediction
local drawSpot = Player.Position
local middle = Vector(7500, 53, 7362)
local currentWAmount = 0

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigMordekaiser.lua", ScriptVersion)



-- Globals
local Mordekaiser = {}
local Utils = {}

Mordekaiser.TargetSelector = nil
Mordekaiser.Logic = {}

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


-- Mordekaiser
Mordekaiser.Q = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 625,
    Delay = 0.5,
    Radius = 80,
    Speed = math.huge,
    Key = "Q",
    Type = "Linear",
})
Mordekaiser.W = SpellLib.Active({
    Slot = Enums.SpellSlots.W,
    Key = "W"
})
Mordekaiser.E = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range = 900,
    Radius = 100,
    Speed = 3000,
    Delay = 0.75,
    Key = "E",
    Type = "Linear",
})
Mordekaiser.R = SpellLib.Targeted({
    Slot = Enums.SpellSlots.R,
    Delay = 0,
    Range = 650,
    Key = "R",
})

-- Ignite and Flash Functions

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

-- Damage Functions

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

function GetUltDmg(Target)

    if Target == nil then
        return 0
    end

    if not Mordekaiser.R:IsReady() then
        return 0
    end

    local markDmg = 0

    if IsMarked(Target) then
        markDmg = GetPassiveDamage(Target)
    end

    return DamageLib.CalculateMagicalDamage(Player, Target, (300 + (Mordekaiser.R:GetLevel() - 1) * 100) + (Player.TotalAP) + markDmg)

end

function GetQDmg(target)

    if target == nil then
        return 0
    end

    if not Mordekaiser.Q:IsLearned() or not Mordekaiser.Q:IsReady() then
        return 0
    end

    local qDmgTable = ({ 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 51, 61, 71, 81, 91, 107, 123, 139 })
    local qHeroLevelDamage = qDmgTable[Player.Level]
    local qBaseDamage = ({ 75, 95, 115, 135, 155 })[Mordekaiser.Q:GetLevel()]
    local qCritIncrease = ({ 1.4, 1.45, 1.5, 1.55, 1.60 })[Mordekaiser.Q:GetLevel()]

    local totalQDmg = qHeroLevelDamage + qBaseDamage + (Player.TotalAP * 0.6)
    local finalQDmg = totalQDmg * qCritIncrease

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, finalQDmg)

end

function GetEDmg(target)

    if target == nil then
        return 0
    end

    if not Mordekaiser.E:IsReady() then
        return 0
    end

    local EBaseDmg = ({ 80, 95, 110, 125, 140 })[Mordekaiser.E:GetLevel()]

    local apDmg = Player.TotalAP * 0.6

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, EBaseDmg + apDmg)


end

function ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 and not minion.IsDead
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

function Utils.IsCasting()

    local spell = Player.ActiveSpell

    if spell then

        if spell.Name == "LuxLightBinding" then
            return true
        end
        if spell.Name == "LuxLightStrikeKugel" then
            return true
        end

    end

    return false

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

function Utils.GetBuff(target, buff)


    for i, v in pairs(target.Buffs) do
        if v.Name == buff then

            return v
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

function Mordekaiser.OnProcessSpell(Caster, SpellCast)


    if Player.IsRecalling then
        return
    end

    if not Mordekaiser.W:IsReady() then
        return
    end

    if SpellCast.Target ~= nil then

        local target = SpellCast.Target
        local caster = Caster

        local weShield = target.CharName == "Mordekaiser"

        if SpellCast.IsBasicAttack and not Menu.Get("Ally.Shield.AA") then
            return false
        end

        if weShield then

            if Player.FirstResource > Player.FirstResourceMax / 2 then


                if caster.IsTurret then
                    return Mordekaiser.W:Cast()
                end

                if caster.IsEnemy and caster.IsHero then
                    return Mordekaiser.W:Cast()
                end

            end

        end

    end

end

function Mordekaiser.OnUpdate()


end

function Mordekaiser.OnBuffGain(obj, buffInst)


end

function Mordekaiser.OnBuffLost(obj, buffInst)

end

function Mordekaiser.OnGapclose(source, dash)


    if Menu.Get("AutoEGap") then

        if Utils.IsInRange(Player.Position, source.Position, 0, Mordekaiser.E.Range) then
            if Mordekaiser.E:IsReady() then

                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then
                        if Mordekaiser.E:CastOnHitChance(Hero, Enums.HitChance.VeryHigh) then
                            return
                        end

                    end

                end

            end

        end

    end


end

function protectedNameRetrieval(v, checkOnly)

    local particleName = v.Name

    if checkOnly then
        return true
    end

    local statusCode = 0

    if Orbwalker.GetMode() == "Flee" then
        return
    end

    if particleName == "Lux_Base_E_tar_aoe_sound" and Utils.CountEnemiesInRange(v.Position, 310) > 0 then

        if Mordekaiser.E2:Cast() then
            return true
        end


    end

    return statusCode

end

function Mordekaiser.Logic.R(Target)


    if not Target then
        return false
    end
    if Target.IsDead then
        return false
    end
    if not Target.IsTargetable then
        return false
    end

    return false

end

function Mordekaiser.Logic.Q(Target)


    local target = Target

    if target == nil then
        return false
    end
    if target.IsDead then
        return false
    end

    if not target.IsTargetable then
        return false
    end

    if Orbwalker.GetMode() == "Combo" then

        if not Menu.Get("Combo.Q.Use") then
            return false
        end

    end

    if not Mordekaiser.Q:IsReady() then
        return false
    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Mordekaiser.Q.Range) then


        return Mordekaiser.Q:CastOnHitChance(target, Menu.Get("Combo.Q.HitChance"))

    end

    return false


end

function Mordekaiser.Logic.W(Target)


    return false

end

function Mordekaiser.Logic.E(Target)


    local target = Target

    if target == nil then
        return false
    end
    if target.IsDead then
        return false
    end

    if Orbwalker.GetMode() == "Combo" then

        if not Menu.Get("Combo.E.Use") then
            return false
        end

    end

    local extraRange = 200

    if Player.Position:Distance(target) > 700 then
        extraRange = 900 - Player.Position:Distance(target)
    end

    local eCastPos = Player.Position:Extended(target.Position, Player.Position:Distance(target.Position) + extraRange)

    if Utils.IsInRange(Player.Position, target.Position, 0, Mordekaiser.E.Range) then


        local ePred = Prediction.GetPredictedPosition(Target, Mordekaiser.E, eCastPos)

        if ePred then

            if ePred.HitChanceEnum >= Menu.Get("Combo.E.HitChance") then


                if Player.Position:Distance(ePred.CastPosition) <= 600 then

                    local NewECastPos = Player.Position:Extended(ePred.CastPosition, Player.Position:Distance(ePred.CastPosition) + 100)

                    return Mordekaiser.E:Cast(NewECastPos)

                end

                return Mordekaiser.E:Cast(ePred.CastPosition)

            end

        end


    end

    return false

end

function Mordekaiser.Logic.Waveclear(lagFree)

    if lagFree == 1 then


        local Q = Menu.Get("Waveclear.Q.Use")
        local E = Menu.Get("Waveclear.E.Use")
        local QJ = Menu.Get("Jungle.Q.Use")
        local EJ = Menu.Get("Jungle.E.Use")

        local pPos, pointsQ = Player.Position, {}
        local pointsE = {}
        for k, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
            local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and Mordekaiser.Q:IsInRange(minion) then
                    local pos = minion.Position
                    if pos:Distance(pPos) < Mordekaiser.Q.Range and minion.IsTargetable then
                        table.insert(pointsQ, pos)
                    end
                end
            end
        end
        if Q and Mordekaiser.Q:IsReady() then
            local bestPos, hitCount = Mordekaiser.Q:GetBestLinearCastPos(pointsQ)

            if bestPos and hitCount >= Menu.Get("Lane.QH") then
                return Mordekaiser.Q:Cast(bestPos)
            end
        end

        for k, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
            local minion = v.AsAI
            if minion then
                if Mordekaiser.E:GetToggleState() == 2 then

                    if luxE ~= nil then


                        if protectedNameRetrieval(luxE, true) and v:Distance(minion) < Mordekaiser.E.Radius then
                            if Mordekaiser.E2:Cast() then
                                return
                            end
                        end

                    end


                end
                if minion.IsTargetable and minion.MaxHealth > 6 and Mordekaiser.E:IsInRange(minion) then
                    local pos = minion:FastPrediction(Game.GetLatency() + Mordekaiser.E.Delay)
                    if Mordekaiser.E:GetToggleState() == 0 and pos:Distance(pPos) < Mordekaiser.E.Range and minion.IsTargetable then
                        table.insert(pointsE, pos)
                    end
                end
            end
        end

        if E and Mordekaiser.E:IsReady() then
            local bestPos, hitCount = Mordekaiser.E:GetBestCircularCastPos(pointsE, Mordekaiser.E.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.EH") then


                if Menu.Get("SafeE") then

                    if #ObjectManager.GetNearby("enemy", "heroes") < 1 then
                        return Mordekaiser.E:Cast(bestPos)
                    end

                else

                    return Mordekaiser.E:Cast(bestPos)


                end

            end
        end
        if Mordekaiser.Q:IsReady() and QJ then
            for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
                local minion = v.AsAI
                local minionInRange = Mordekaiser.Q:IsInRange(minion)
                if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                    if Mordekaiser.Q:Cast(minion) then
                        return
                    end
                end
            end
        end
        if Mordekaiser.E:IsReady() and EJ then
            for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
                local minion = v.AsAI
                local minionInRange = Mordekaiser.E:IsInRange(minion)
                if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                    if Mordekaiser.E:GetToggleState() == 0 and Mordekaiser.E:Cast(minion) then
                        return
                    end
                    if Mordekaiser.E:GetToggleState() == 2 then

                        if luxE ~= nil then

                            if protectedNameRetrieval(luxE, true) and v:Distance(minion) < Mordekaiser.E.Radius then
                                if Mordekaiser.E2:Cast() then
                                    return
                                end
                            end

                        end

                    end
                end
            end
        end

    end


end

function Mordekaiser.Logic.Lasthit(lagFree)

end

function Mordekaiser.Logic.Harass(lagFree)


    local target = TS:GetTarget(1000)

    if target == nil then
        return
    end

    if Menu.Get("HarassE") and Mordekaiser.E:IsReady() then


        return Mordekaiser.Logic.E(target)

    end

    if Menu.Get("HarassQ") and Mordekaiser.Q:IsReady() then

        return Mordekaiser.Logic.Q(target)

    end

    return false


end

function Mordekaiser.Logic.Combo(lagFree)


    local Target = TS:GetTarget(1000, true)

    if not Target then
        return false
    end

    if not Target.IsTargetable then
        return false
    end

    if lagFree == 1 or lagFree == 2 then

        if Mordekaiser.Logic.E(Target) then
            return true
        end

    end

    if lagFree == 3 or lagFree == 4 then

        if Mordekaiser.Logic.Q(Target) then
            return true
        end

    end

    return false


end

function Mordekaiser.Logic.Flee(lagFree)

    local enemyHeroes = ObjectManager.GetNearby("enemy", "heroes")

    if #enemyHeroes < 1 then
        return
    end

    local closestRange = Mordekaiser.E.Range
    local closestEnemyPos = enemyHeroes[1]

    if #enemyHeroes == 1 then


        if Player:Distance(enemyHeroes[1]) > Mordekaiser.E.Range then

            return

        end
    end

    local eSpot = Player.Position:Extended(enemyHeroes[1].Position, -150)
    drawSpot = eSpot

    for i, v in pairs(enemyHeroes) do

        if Player.Position:Distance(v.Position) < closestRange then

            closestEnemyPos = v.Position
            closestRange = Player.Position:Distance(v.Position)

        end
    end

    local eSpot = Player.Position:Extended(closestEnemyPos, -150)
    drawSpot = eSpot

    if Player:Distance(closestEnemyPos) > 450 then

        return

    end

    if Mordekaiser.E:IsReady() then


        return Input.Cast(SpellSlots.E, eSpot)
    end


end

function Mordekaiser.OnDraw()

    local Target = TS:GetTarget(1000, true)

    if Menu.Get("Q.Preview") then

        local qLength = Player.Position:Distance(middle)
        local qEndPos = Player.Position:Extended(middle, qLength - qLength + Mordekaiser.Q.Range)

        Renderer.DrawFilledRect3D(Player.Position, qEndPos, Mordekaiser.Q.Radius * 2, 0xEF476FFF)


    end

    if Menu.Get("E.Preview") then

        local eLength = Player.Position:Distance(middle)
        local eEndPos = Player.Position:Extended(middle, eLength - eLength + Mordekaiser.E.Range)

        Renderer.DrawFilledRect3D(Player.Position, eEndPos, Mordekaiser.E.Radius * 2, 0xEF476FFF)


    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, Mordekaiser.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, Mordekaiser.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Mordekaiser.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end


end

function Mordekaiser.OnHeroImmobilized(Source, EndTime, IsStasis)
    if Player.IsRecalling then
        return
    end

    if Orbwalker.GetMode() ~= "Flee" then


        if Source.IsEnemy and Source.IsHero and not Source.IsDead and Source.IsTargetable then


        end

    end


end

function Mordekaiser.OnHighPriority(lagFree)

    if lagFree == 2 then

        if Menu.Get("AutoREnable") then

            if Mordekaiser.R:IsReady() then

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                    if Menu.Get("R" .. v.CharName) then

                        if Utils.IsInRange(Player.Position, v.Position, 0, Mordekaiser.R.Range) then


                            if v.IsTargetable then

                                Mordekaiser.R:Cast(v)

                            end


                        end


                    end


                end

            end

        end

    end




end

function Mordekaiser.Logic.Auto(lagFree)


    Mordekaiser.E.Range = Menu.Get("Combo.E.MaxRange")
    Mordekaiser.E.Radius = Menu.Get("Combo.E.MaxWidth") / 2
    Mordekaiser.Q.Range = Menu.Get("Combo.Q.MaxRange")
    Mordekaiser.Q.Radius = Menu.Get("Combo.Q.MaxWidth") / 2
    Mordekaiser.Q.Delay = Menu.Get("Combo.Q.Delay")

    if Menu.Get("SemiR") then

        if not Mordekaiser.R:IsReady() then
            return
        end

        local enemyHeroes = TS:GetTargets(Mordekaiser.R.Range)

        if #enemyHeroes < 1 then
            return
        end

        local closestEnemy = enemyHeroes[1]

        for i, v in pairs(enemyHeroes) do

            if Renderer.GetMousePos():Distance(v.Position) < Renderer.GetMousePos():Distance(closestEnemy.Position) then

                closestEnemy = v


            end

        end

        local target = TS:GetForcedTarget()

        if target then

            return Mordekaiser.R:Cast(target)

        end

        return Mordekaiser.R:Cast(closestEnemy)


    end


    if lagFree == 1 then


        if not Player.IsRecalling then

            if Menu.Get("Ally.Shield.Safe") then

                if Player.HealthPercent * 100 <= Menu.Get("HPShieldPercent") then
                    if Mordekaiser.W:IsReady() then
                        return Input.Cast(SpellSlots.W)
                    end
                end

            end

            if Menu.Get("ShieldHPReactivate") then

                if Mordekaiser.W:IsReady() then

                    if #ObjectManager.GetNearby("enemy", "heroes") == 0 then
                        if Player.FirstResource < currentWAmount then

                            if Player.FirstResource >= Player.FirstResourceMax * 0.85 then

                                currentWAmount = 0

                                return Input.Cast(SpellSlots.W)

                            end

                        end

                    end

                end

                if #ObjectManager.GetNearby("enemy", "heroes") == 0 then


                    if Utils.HasBuff(Player, "MordekaiserW") then

                        if Utils.GetBuff(Player, "MordekaiserW").DurationLeft < 4 then

                            --  print(Utils.GetBuff(Player, "MordekaiserW").DurationLeft)

                            return Input.Cast(SpellSlots.W)

                        end
                    end


                end

                local o = Player.FirstResource

                currentWAmount = o

            end


        end


    end

    if Menu.Get("ShieldHPWait") then

        if Player.HealthPercent * 100 > Menu.Get("HPShieldPercentWait") then

            return false

        end

    end

    if lagFree == 3 or lagFree == 4 then

        local DetectedSkillshots = {}
        DetectedSkillshots = Evade.GetDetectedSkillshots()

        if Utils.HasBuff(Player, "SummonerDot") then
            if Mordekaiser.W:IsReady() then

                if Player.FirstResource > Player.FirstResourceMax / 2 then

                    return Mordekaiser.W:Cast()

                end


            end
        end

        if not Evade.IsPointSafe(Player.Position) then

            for i, p in pairs(DetectedSkillshots) do


                if not p:GetCaster().IsHero then
                    return
                end

                if p:IsAboutToHit(1, Player.Position) then

                    if Mordekaiser.W:IsReady() then

                        if Player.FirstResource > Player.FirstResourceMax / 2 then
                            Mordekaiser.W:Cast()

                        end


                    end
                end
            end
        end

    end


end

function Mordekaiser.OnDrawDamage(target, dmgList)


    local totalDmg = 0

    if Menu.Get("DmgDrawings.Q") then
        totalDmg = totalDmg + GetQDmg(target)
    end

    if Menu.Get("DmgDrawings.E") then
        totalDmg = totalDmg + GetEDmg(target)
    end

    table.insert(dmgList, totalDmg)


end

function Mordekaiser.OnCreateObject(obj, lagFree)


end

function Mordekaiser.OnDeleteObject(obj, lagFree)


end

function Mordekaiser.OnTick(lagFree)

    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Mordekaiser.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Mordekaiser.Logic.Auto(lagFree) then
        return true
    end

    return false

end

function Mordekaiser.OnPostAttack(target)

end

function Mordekaiser.LoadMenu()

    Menu.RegisterMenu("BigMordekaiser", "BigMordekaiser", function()
        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)

        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()


            Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
            Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
            Menu.Text("")
            Menu.Keybind("SemiR", "[R] on closest target to mouse or forced target", string.byte("R"), false, false, false)
            Menu.Checkbox("AutoREnable", "Enable Auto [R]", true)
            Menu.NewTree("AutoR", "Auto Ult Whitelist", function()
                Menu.Text("Champions will be ulted as soon as they are in range if their box is ticked")
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, Name, false)
                end
            end)

        end)

        Menu.NewTree("Prediction Builder", "Prediction Builder", function()

            Menu.NewTree("QSettings", "[Q] Settings", function()

                Menu.Checkbox("Q.Preview", "Prediction Preview [DON'T FORGET TO TURN THIS BACK OFF]", false)
                Menu.Text("")
                Menu.Text("Hitchance")
                Menu.Dropdown("Combo.Q.HitChance", "HitChance", HitChance.Medium, HitChanceStrings)
                Menu.Text("")
                Menu.Text("[Q] Length")
                Menu.Slider("Combo.Q.MaxRange", "", 600, 0, 625, 10)
                Menu.ColoredText("Lowering Range of Q will result in better accuracy at the cost of range ", 0xE3FFDF)
                Menu.ColoredText("Recommended to reduce range by 50 or 100", 0xE3FFDF)

                Menu.Text("")
                Menu.Text("[Q] Width")
                Menu.Slider("Combo.Q.MaxWidth", "", 160, 0, 160, 10)
                Menu.ColoredText("Lowering Width of Q will result in better accuracy", 0xE3FFDF)
                Menu.ColoredText("Recommended to leave at default or reduce by a bit", 0xE3FFDF)

                Menu.Text("")
                Menu.Text("[Q] Cast Delay")
                Menu.Slider("Combo.Q.Delay", "", 0.5, 0, 1, 0.05)
                Menu.ColoredText("Adjusts how long the prediction assumes the spell takes to cast", 0xE3FFDF)
                Menu.ColoredText("Recommended to leave at default (0.5), experiment at your own risk", 0xE3FFDF)


            end)

            Menu.NewTree("ESettings", "[E] Settings", function()

                Menu.Checkbox("E.Preview", "Prediction Preview [DON'T FORGET TO TURN THIS BACK OFF]", false)
                Menu.Text("")
                Menu.Text("Hitchance")
                Menu.Dropdown("Combo.E.HitChance", "HitChance", HitChance.High, HitChanceStrings)
                Menu.Text("")
                Menu.Text("[E] Length")
                Menu.Slider("Combo.E.MaxRange", "", 880, 0, 880, 10)
                Menu.ColoredText("Lowering Range of E will result in better accuracy at the cost of range ", 0xE3FFDF)
                Menu.ColoredText("Recommended to reduce range by 50 or 100", 0xE3FFDF)

                Menu.Text("")
                Menu.Text("[E] Width")
                Menu.Slider("Combo.E.MaxWidth", "", 200, 0, 200, 10)
                Menu.ColoredText("Lowering Width of E will result in better accuracy", 0xE3FFDF)
                Menu.ColoredText("Recommended to leave at default or reduce by a bit", 0xE3FFDF)

                Menu.Text("")
                Menu.Text("[E] Cast Delay")
                Menu.Slider("Combo.E.Delay", "", 0.75, 0, 1, 0.05)
                Menu.ColoredText("Adjusts how long the prediction assumes the spell takes to cast", 0xE3FFDF)
                Menu.ColoredText("Recommended to leave at default (0.75), experiment at your own risk", 0xE3FFDF)


            end)


        end)

        Menu.NewTree("Shielding", "Shield [W] Settings", function()

            Menu.Text("")
            Menu.Checkbox("ShieldHPReactivate", "Consume shield if no enemies nearby", true)
            Menu.Text("")
            Menu.Separator()
            Menu.Text("")
            Menu.Checkbox("ShieldHPWait", "If above % hp wait for max shield before use", true)
            Menu.Slider("HPShieldPercentWait", "", 60, 0, 100)
            Menu.Checkbox("Ally.Shield.Safe", "Shield if hp falls below %", true)
            Menu.Slider("HPShieldPercent", "", 30, 0, 100)
            Menu.Text("")
            Menu.Checkbox("Ally.Shield.Targeted", "Shield targeted spells", true)
            Menu.Checkbox("Ally.Shield.AA", "Shield basic attacks", true)
            Menu.Checkbox("Ally.Shield.Skillshots", "Shield skillshots", true)

            Menu.Text("These will be shielded if you have at least half your shield bar")
            Menu.Text("")

        end)

        Menu.NewTree("BigHeroHarass", "Harass [C]", function()

            Menu.Text("")

            Menu.Checkbox("HarassQ", "Use [Q]", true)
            Menu.Checkbox("HarassE", "Use [E]", true)

            Menu.NextColumn()
            Menu.Text("")


        end)

        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()


            Menu.NewTree("Lane", "Laneclear Options", function()

                Menu.Checkbox("Waveclear.Q.Use", "Use [Q]", true)
                Menu.Slider("Lane.QH", "Minimum Minion Hitcount", 2, 1, 3)
                Menu.Text("")
                Menu.Checkbox("Waveclear.E.Use", "Use [E]", true)
                Menu.Slider("Lane.EH", "Minimum Minion Hitcount", 3, 1, 3)
                Menu.Checkbox("SafeE", "Only use E when no enemy nearby", true)

            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q.Use", "Use [Q]", true)
                Menu.Checkbox("Jungle.E.Use", "Use [E]", true)
            end)


        end)

        Menu.NewTree("Auto", "Auto", function()


            Menu.Checkbox("AutoEGap", "Cast [E] on gapclose", true)


        end)

        Menu.NewTree("Drawings", "Range Drawings", function()


            Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw [E] Range", true)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.R", "Draw [R] Range", true)
            Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)


        end)

        Menu.NewTree("DmgDrawings", "Damage Drawings", function()


            Menu.Checkbox("DmgDrawings.Q", "Draw [Q] Dmg", true)

            Menu.Checkbox("DmgDrawings.E", "Draw [E] Dmg", true)


        end)

    end)
end

function OnLoad()

    INFO("Welcome to BigMordekaiser, enjoy your stay")

    Mordekaiser.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Mordekaiser[EventName] then
            EventManager.RegisterCallback(EventId, Mordekaiser[EventName])
        end
    end

    return true

end
