--[[
    BigLux
]]

if Player.CharName ~= "Lux" then
    return false
end

module("BLux", package.seeall, log.setup)
clean.module("BLux", package.seeall, log.setup)






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
local ScriptLastUpdate = "11. March 2022"
local iTick            = 0
local luxE             = nil

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigLux.lua", ScriptVersion)


-- Globals
local Lux          = {}
local Utils        = {}

Lux.TargetSelector = nil
Lux.Logic          = {}

local UsableSS     = {
    Ignite = {
        Slot  = nil,
        Range = 600
    },

    Flash  = {
        Slot  = nil,
        Range = 400
    }
}


-- Lux
Lux.Q              = SpellLib.Skillshot({

    Slot          = Enums.SpellSlots.Q,
    Range         = 1240,
    Radius        = 70,
    Delay         = 0.25,
    Speed         = 1200,
    Collisions    = { Heroes = true, Minions = true, WindWall = true },
    MaxCollisions = 2,
    Type          = "Linear",
    UseHitbox     = true


})
Lux.W              = SpellLib.Skillshot({

    Slot   = Enums.SpellSlots.W,
    Range  = 1175,
    Radius = 110,
    Delay  = 0.25,
    Type   = "Linear",

})
Lux.E              = SpellLib.Skillshot({

    Slot       = Enums.SpellSlots.E,
    Range      = 1100,
    Radius     = 300,
    Delay      = 0.25,
    Speed      = 1200,
    Collisions = { WindWall = true },
    Type       = "Circular",
    UseHitbox  = true


})
Lux.E2             = SpellLib.Active({

    Slot = Enums.SpellSlots.E,

})
Lux.R              = SpellLib.Skillshot({

    Slot      = Enums.SpellSlots.R,
    Range     = 3400,
    Radius    = 195 / 2,
    Delay     = 1,
    Speed     = math.huge,
    Type      = "Linear",
    UseHitbox = true

})

-- Functions
local function IsMarked(target)
    return target:GetBuff("LuxIlluminatedFraulein");
end
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

    if not Lux.R:IsReady() then
        return 0
    end

    local markDmg = 0

    if IsMarked(Target) then
        markDmg = GetPassiveDamage(Target)
    end

    return DamageLib.CalculateMagicalDamage(Player, Target, (300 + (Lux.R:GetLevel() - 1) * 100) + (Player.TotalAP) + markDmg)

end
function GetQDmg(target)

    if target == nil then
        return 0
    end

    if not Lux.Q:IsLearned() or not Lux.Q:IsReady() then
        return 0

    end

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, (80 + (Lux.Q:GetLevel() - 1) * 45) + (0.6 * Player.TotalAP))

end
function GetEDmg(target)

    if target == nil then
        return 0
    end

    if not Lux.E:IsReady() then
        return 0
    end

    local EBaseDmg = ({ 70, 120, 170, 220, 270 })[Lux.E:GetLevel()]

    local apDmg    = Player.TotalAP * 0.7

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, EBaseDmg + apDmg)


end
function GetPassiveDamage(target)

    local baseDmg     = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg       = Player.TotalAP * 0.2

    local totalDmg    = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)

end
function ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6 and not minion.IsDead
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

        if Lux.E2:Cast() then
            return true
        end

    end

    return statusCode

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
            if
            Utils.IsValidTarget(Object) and
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

-- Events
function Lux.OnProcessSpell(Caster, SpellCast)

    if Player:Distance(Caster.Position) > 5000 or Caster.IsAlly then return false end

    if Player.IsRecalling then
        return
    end

    if not Lux.W:IsReady() then
        return
    end

    if SpellCast.Target ~= nil then

        if not Menu.Get("Ally.Shield.Targeted") then
            return
        end

        local target   = SpellCast.Target
        local caster   = Caster

        local weShield = target.CharName == "Lux" or target.IsAlly and target.IsHero

        if SpellCast.IsBasicAttack and not Menu.Get("Ally.Shield.AA") then
            return false
        end

        if Player.Position:Distance(target.Position) < Lux.W.Range then

            if weShield then


                if caster.IsTurret then
                    return Lux.W:Cast(target)
                end

                if caster.IsEnemy and caster.IsHero then
                    return Lux.W:Cast(target)

                end
            end
        end
    end
end
function Lux.OnGapclose(source, dash, lagFree)

    if lagFree == 4 or lagFree == 3 then
        if Menu.Get("AutoQGap") then

            if Utils.IsInRange(Player.Position, source.Position, 0, Lux.Q.Range) then
                if Lux.Q:IsReady() then

                    local Hero = source.AsHero

                    if not Hero.IsDead then
                        if Hero.IsEnemy then
                            if Lux.Q:CastOnHitChance(Hero, HitChance.Dashing) then
                                return
                            end

                        end

                    end

                end

            end

        end

        if Menu.Get("AutoEGap") then

            if Utils.IsInRange(Player.Position, source.Position, 0, Lux.E.Range) then
                if Lux.E:IsReady() then

                    local Hero = source.AsHero

                    if not Hero.IsDead then
                        if Hero.IsEnemy then
                            if Lux.E:CastOnHitChance(Hero, 0.60) then
                                return true
                            end

                        end

                    end

                end

            end

        end

    end
end
function Lux.OnDraw()

    if Menu.Get("Drawings.W") then
        Renderer.DrawCircle3D(Player.Position, Lux.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, Lux.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, Lux.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Lux.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end

    local screenPosition = Renderer.GetMousePos():ToScreen()
    screenPosition.y     = screenPosition.y + 50
    screenPosition.x     = screenPosition.x - 75
    local BaronText      = "Baron/Dragon/Buff Steal [ON]"
    local BaronColor     = 0x3DC800FF

    if not Menu.Get("BaronKS") then
        BaronText        = "Baron/Dragon/Buff Steal [OFF]"
        BaronColor       = 0xFF0239FF

        screenPosition   = Player.Position:ToScreen()
        screenPosition.y = screenPosition.y + 20
        screenPosition.x = screenPosition.x - 90
    end

    Renderer.DrawText(screenPosition, Geometry.Vector(30), BaronText, BaronColor)


end
function Lux.OnHeroImmobilized(Source, EndTime, IsStasis)
    if Player.IsRecalling then
        return
    end

    if not Utils.IsInRange(Player.Position, Source.Position, 0, Lux.R.Range) then
        return
    end

    if Orbwalker.GetMode() ~= "Flee" then

        if Source.IsEnemy and Source.IsHero and not Source.IsDead and Source.IsTargetable then


            local manaPercent = Player.ManaPercent * 100

            if manaPercent >= Menu.Get("Auto.Poke.Mana") then

                if EndTime - Game.GetTime() > 0.3 then
                    return
                end

                if IsStasis then

                    if Player.Position:Distance(Source.Position) <= Lux.E.Range then
                        if Lux.E:IsReady() then
                            Input.Cast(SpellSlots.E, Source.Position)
                        end
                    end

                    return
                end

                if Menu.Get("AutoQ") then

                    if Utils.IsInRange(Player.Position, Source.Position, 0, Lux.Q.Range) then

                        if Lux.Q:IsReady() then

                            return Lux.Q:CastOnHitChance(Source, 0.35)

                        end

                    end
                end

                if Utils.IsInRange(Player.Position, Source.Position, 0, Lux.E.Range) then

                    if Menu.Get("AutoE") then

                        if Lux.E:IsReady() then

                            if Lux.E:CastOnHitChance(Source, 0.65) then
                                return true
                            end

                        end

                    end

                    local damageCanDeal = 0

                    if Lux.E:IsReady() then
                        if Utils.IsInRange(Player.Position, Source.Position, 0, Lux.E.Range) then
                            damageCanDeal = damageCanDeal + GetEDmg(Source)
                        end

                    end

                    if Source.Health - (damageCanDeal + GetUltDmg(Source) + Utils.GetLudensDmg(Source)) < 0 then

                        if Menu.Get("R" .. Source.AsHero.CharName) then
                            return Lux.R:CastOnHitChance(Source, 0.40)

                        end

                    end


                end
            end
        end

    end


end
function Lux.OnDrawDamage(target, dmgList)


    local totalDmg = 0

    if Menu.Get("DmgDrawings.Q") then
        totalDmg = totalDmg + GetQDmg(target)
    end

    if Menu.Get("DmgDrawings.R") then
        totalDmg = totalDmg + GetUltDmg(target)
    end

    if Menu.Get("DmgDrawings.E") then
        totalDmg = totalDmg + GetEDmg(target)
    end

    if Menu.Get("DmgDrawings.Ludens") then
        totalDmg = totalDmg + Utils.GetLudensDmg()

    end

    table.insert(dmgList, totalDmg)


end
function Lux.OnCreateObject(obj, lagFree)

end
function Lux.OnDeleteObject(obj, lagFree)

    if lagFree == 2 then

        if protectedNameRetrieval(obj, true) then

            if obj.Name == "Lux_Base_E_tar_aoe_sound" then
                luxE = nil
                return
            end

        end

    end

end
function Lux.OnTick(lagFree)

    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode  = Orbwalker.GetMode()

    local OrbwalkerLogic = Lux.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Lux.Logic.Auto(lagFree) then
        return true
    end

    return false

end
function Lux.OnPreAttack(args)

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
function Lux.OnPostAttack(target)

end
function Lux.Logic.Auto(lagFree)
    if lagFree == 1 then
        if Lux.E:IsReady() and (Lux.E:GetToggleState() == 2) then
            if Orbwalker.GetMode() ~= "Flee" then
                return Lux.E2:Cast()
            end
        end

        if Menu.Get("SemiR") then

            if not Lux.R:IsReady() then
                return
            end

            local enemyHeroes = TS:GetTargets(Lux.R.Range)

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

                return Lux.R:CastOnHitChance(target, Menu.Get("SemiR.HitChance") / 100)

            end

            return Lux.R:CastOnHitChance(closestEnemy, Menu.Get("SemiR.HitChance") / 100)


        end

        if Menu.Get("BaronKS") then

            for k, v in pairs(ObjectManager.Get("neutral", "minions")) do

                if ValidMinion(v) then

                    if v.IsDragon or v.IsBaron or v.IsHerald or v.IsBlueBuff or v.IsRedBuff then

                        if Utils.IsInRange(Player.Position, v.Position, 0, Lux.R.Range) then

                            if Lux.R:IsReady() then

                                local hpPred = HealthPrediction.GetHealthPrediction(v, Lux.R.Delay, false)

                                if hpPred < GetUltDmg(v) then

                                    return Input.Cast(Lux.R.Slot, v.Position)

                                end


                            end
                        end
                    end
                end
            end
        end

        if Player.IsRecalling then
            return
        end

        -- if lagFree == 1 then


        if Menu.Get("QKS") and Lux.Q:IsReady() then

            for i, v in ipairs(ObjectManager.GetNearby("enemy","heroes")) do

                if Lux.Q:IsInRange(v) then
                    if v.IsEnemy and v.IsHero and not v.IsDead and v.IsTargetable then

                        if v.Health < GetQDmg(v) + Utils.GetLudensDmg() then


                            if DamageLib.GetAutoAttackDamage(Player, v, true) > v.Health then

                                if Orbwalker.GetTrueAutoAttackRange(Player) >= Player:Distance(v) then
                                    return true
                                end
                            end

                            return Lux.Q:CastOnHitChance(v, 0.5)

                        end

                    end

                end
            end
        end

        if Menu.Get("EKS") and Lux.E:IsReady() then

            if not Orbwalker.GetMode() == "Flee" then
                if Lux.E:IsReady() and (Lux.E:GetToggleState() == 2 or Lux.E:GetToggleState() == 1) then
                    return Lux.E2:Cast()
                end
            end
            for i, v in pairs(TS:GetTargets(Lux.E.Range)) do

                if v.IsEnemy and v.IsHero and not v.IsDead and v.IsTargetable then

                    if DamageLib.GetAutoAttackDamage(Player, v, true) > v.Health then

                        if Orbwalker.GetTrueAutoAttackRange(Player) >= Player:Distance(v) then
                            return true
                        end
                    end

                    if v.Health < GetEDmg(v) + Utils.GetLudensDmg() then

                        if Lux.E:CastOnHitChance(v, 0.35) then
                            return true
                        end

                    end

                end
            end
        end

        if Menu.Get("RKS") and Lux.R:IsReady() then

            for i, v in pairs(TS:GetTargets(Lux.R.Range)) do

                if Menu.Get("QKS") then

                    if Lux.Q:IsReady() then
                        if Utils.IsInRange(Player.Position, v.Position, 0, Lux.Q.Range) then
                            if v.Health < (GetQDmg(v) + Utils.GetLudensDmg(v)) then
                                return
                            end
                        end
                    end

                end

                if Menu.Get("EKS") then

                    if Lux.E:IsReady() then
                        if Utils.IsInRange(Player.Position, v.Position, 0, Lux.E.Range) then

                            if v.Health < (GetEDmg(v) + Utils.GetLudensDmg(v)) then
                                return
                            end
                        end
                    end

                end

                if v.IsEnemy and v.IsHero and not v.IsDead and v.IsTargetable then

                    if DamageLib.GetAutoAttackDamage(Player, v, true) > v.Health then

                        if Orbwalker.GetTrueAutoAttackRange(Player) >= Player:Distance(v) then
                            return
                        end
                    end

                    if Utils.IsCasting() then
                        return
                    end

                    local rPred = HealthPrediction.GetKillstealHealth(v, Lux.R.Delay, Enums.DamageTypes.Magical)

                    if rPred < GetUltDmg(v) + Utils.GetLudensDmg() and rPred > 0 then

                        if Menu.Get("R" .. v.CharName) then
                            Lux.R:CastOnHitChance(v, 0.45)

                        end

                    end

                end
            end
        end
        --  end

        --  if lagFree == 2 then
        if Orbwalker.GetMode() ~= "Flee" then

            if Lux.E:IsReady() and Menu.Get("Auto.E.Harass") then


                local manaPercent = Player.ManaPercent * 100

                if manaPercent >= Menu.Get("Auto.E.Mana") then


                    local enemies       = {}
                    local predLocations = {}

                    for k, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                        if Player.Position:Distance(v.Position) <= Lux.E.Range + 200 then

                            if v.IsTargetable and not v.IsDead then

                                table.insert(enemies, v)

                            end

                        end

                    end

                    if #enemies >= 2 then


                        for i, v in ipairs(enemies) do


                            local prediction = Lux.E:GetPrediction(v)

                            if prediction then

                                if Player:Distance(prediction.CastPosition) <= Lux.E.Range then

                                    table.insert(predLocations, prediction.CastPosition)

                                end

                            end


                        end

                        local bestCovCircle, hits = Geometry.BestCoveringCircle(predLocations, 300)

                        if bestCovCircle and hits >= Menu.Get("Auto.E.Slider") then

                            if Lux.E:Cast(bestCovCircle) then
                                return true
                            end
                        end
                    end
                end
            end
        end
        -- end

        -- if lagFree == 3 or lagFree == 4 then


        local DetectedSkillshots = {}
        DetectedSkillshots       = Evade.GetDetectedSkillshots()

        for k, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do

            if Menu.Get("Ally.Shield.Ignite") then

                if Utils.HasBuff(v, "SummonerDot") then
                    if Lux.W:IsReady() then
                        if Player.Position:Distance(v.Position) <= Lux.W.Range then
                            return Lux.W:CastOnHitChance(v, 0.35)

                        end

                    end
                end

            end

            if Menu.Get("Ally.Shield.Skillshots") then

                if Evade.IsPointSafe(Player.Position) then

                    for i, p in ipairs(DetectedSkillshots) do


                        if not Menu.Get("Ally.Shield.AA") then
                            if p.IsBasicAttack then
                                return
                            end
                        end

                        if p:IsAboutToHit(1, v.Position) then

                            if Lux.W:IsReady() then

                                if Player.Position:Distance(v.Position) <= Lux.W.Range then
                                    Lux.W:CastOnHitChance(v, 0.35)

                                end

                            end
                        end
                    end
                end

            end
        end
        -- end

    end
end

-- Spell Logic
function Lux.Logic.R(Target)


    if not Target then
        return false
    end
    if Target.IsDead then
        return false
    end
    if not Target.IsTargetable then
        return false
    end

    if Menu.Get("RC" .. Target.CharName) then

        if not Menu.Get("Combo.R.Use") then
            return false
        end

        if Lux.R:IsReady() then

            if Menu.Get("Combo.R.CheckHP") then

                if Target.Health < GetUltDmg(Target) then

                    return Lux.R:CastOnHitChance(Target, Menu.Get("Combo.R.HitChance") / 100)

                end

            else

                return Lux.R:CastOnHitChance(Target, Menu.Get("Combo.R.HitChance") / 100)

            end
        end

    end

    return false

end
function Lux.Logic.Q(Target)


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

    if not Menu.Get("Combo.Q.Use") then
        return false
    end

    if not Lux.Q:IsReady() then
        return false
    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Menu.Get("Combo.Q.MaxRange")) then

        if Lux.Q:CastOnHitChance(target, Menu.Get("Combo.Q.HitChance") / 100) then
            return true
        end

    end

    return false


end
function Lux.Logic.E(Target)


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

    if Utils.IsInRange(Player.Position, target.Position, 0, Menu.Get("Combo.E.MaxRange")) then

        local ePred = Lux.E:GetPrediction(target)

        if Lux.E:IsReady() and (Lux.E:GetToggleState() == 2 or Lux.E:GetToggleState() == 1) then
            return Lux.E2:Cast()
        end

        if Lux.E:CastOnHitChance(target, Menu.Get("Combo.E.HitChance") / 100) then
            return true
        end

        return false

    end
end


-- Orbwalker Modes
function Lux.Logic.Waveclear(lagFree)

    if Lux.E:IsReady() and Lux.E:GetToggleState() == 2 or Lux.E:GetToggleState() == 1 then

        return Lux.E2:Cast()

    end

    local Q             = Menu.Get("Waveclear.Q.Use")
    local E             = Menu.Get("Waveclear.E.Use")
    local QJ            = Menu.Get("Jungle.Q.Use")
    local EJ            = Menu.Get("Jungle.E.Use")

    local pPos, pointsQ = Player.Position, {}
    local pointsE       = {}
    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and minion.MaxHealth > 6 and Lux.Q:IsInRange(minion) then
                local pos = minion:FastPrediction(Game.GetLatency() + Lux.Q.Delay)
                if pos:Distance(pPos) < Lux.Q.Range and minion.IsTargetable then
                    table.insert(pointsQ, pos)
                end
            end
        end
    end
    if Q and Lux.Q:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then
        local bestPos, hitCount = Lux.Q:GetBestLinearCastPos(pointsQ, Lux.Q.Radius)
        if bestPos and hitCount > 1 then
            Lux.Q:Cast(bestPos)
        end
    end

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if Lux.E:GetToggleState() == 2 then

                if luxE ~= nil then

                    if protectedNameRetrieval(luxE, true) and v:Distance(minion) < Lux.E.Radius then
                        if Lux.E2:Cast() then
                            return
                        end
                    end

                end

            end
            if minion.IsTargetable and minion.MaxHealth > 6 and Lux.E:IsInRange(minion) then
                local pos = minion:FastPrediction(Game.GetLatency() + Lux.E.Delay)
                if Lux.E:GetToggleState() == 0 and pos:Distance(pPos) < Lux.E.Range and minion.IsTargetable then
                    table.insert(pointsE, pos)
                end
            end
        end
    end

    if E and Lux.E:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then
        local bestPos, hitCount = Lux.E:GetBestCircularCastPos(pointsE, Lux.E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            if Lux.E:Cast(bestPos) then
                return true
            end
        end
    end
    if Lux.Q:IsReady() and QJ then
        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion        = v.AsAI
            local minionInRange = Lux.Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if Lux.Q:Cast(minion) then
                    return
                end
            end
        end
    end
    if Lux.E:IsReady() and EJ then
        for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
            local minion        = v.AsAI
            local minionInRange = Lux.E:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if Lux.E:GetToggleState() == 0 and Lux.E:Cast(minion) then
                    return
                end
                if Lux.E:GetToggleState() == 2 then

                    if Lux.E2:Cast() then
                        return
                    end

                end
            end
        end
    end

end
function Lux.Logic.Lasthit(lagFree)

    for k, v in pairs(ObjectManager.Get("enemy", "minions")) do

        if not Orbwalker.IsLasthitMinion(v) then

            if Utils.IsInRange(Player.Position, v.Position, 0, Lux.E.Range) then

                if Menu.Get("LastHit.E.Use") and v.IsSiegeMinion then

                    if Lux.E:IsReady() then
                        if not Utils.IsInRange(Player.Position, v.Position, 0, Orbwalker.GetTrueAutoAttackRange(Player)) then


                            local hpPred = HealthPrediction.GetHealthPrediction(v, Lux.E.Delay, false)

                            if hpPred > 0 and hpPred < GetEDmg(v) then

                                return Input.Cast(Lux.E.Slot, v.Position)

                            end

                        end
                    end
                end
            end
        end
    end
end
function Lux.Logic.Harass(lagFree)


    local target = TS:GetTarget(Lux.Q.Range)

    if target == nil then
        return
    end

    if Menu.Get("Harass.Q.Use") then

        if Lux.Q:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Lux.Q.Range) and Menu.Get("Harass.Q.Mana") < (Player.ManaPercent * 100) then

            if Player.Mana > Player.MaxMana * (Menu.Get("Harass.Q.Mana") / 100) then

                return Lux.Q:CastOnHitChance(target, Menu.Get("Harass.Q.HitChance") / 100)

            end
        end
    end

    if Menu.Get("Harass.E.Use") then

        if Lux.E:IsReady() and (Lux.E:GetToggleState() == 2 or Lux.E:GetToggleState() == 1) then
            return Lux.E2:Cast()
        end

        if Player.Mana > Player.MaxMana * (Menu.Get("Harass.E.Mana") / 100) then
            if Lux.E:IsReady() and Utils.IsInRange(Player.Position, target.Position, 0, Lux.E.Range) and Menu.Get("Harass.E.Mana") < (Player.ManaPercent * 100) then

                if Lux.E:CastOnHitChance(target, Menu.Get("Harass.E.HitChance") / 100) then
                    return true
                end

            end
        end
    end

    return false


end
function Lux.Logic.Combo(lagFree)
    local Target = TS:GetTarget(Lux.Q.Range, true)

    if lagFree == 1 then

        if Target then
            if Target.IsTargetable then
                if Lux.Logic.Q(Target) then
                    return true
                end
            end
        end

    end

    if lagFree == 2 then
        Target = TS:GetTarget(Lux.E.Range)

        if Target then
            if Target.IsTargetable then
                if Lux.Logic.E(Target) then
                    return true
                end
            end
        end

    end

    if lagFree == 3 then
        Target = TS:GetTarget(Lux.R.Range)

        if Target then

            if DamageLib.GetAutoAttackDamage(Player, Target, true) > Target.Health then

                if Orbwalker.GetTrueAutoAttackRange(Player) >= Player:Distance(Target) then
                    return true
                end
            end

            if Target.IsTargetable then
                if Lux.Logic.R(Target) then
                    return true
                end
            end
        end

    end

    return false


end
function Lux.Logic.Flee(lagFree)

    if lastETime == 0 or Game.GetTime() - lastETime > 2 then

        if lagFree == 1 then

            local enemyHeroes = ObjectManager.GetNearby("enemy", "heroes")

            if #enemyHeroes < 1 then
                return
            end

            local closestRange    = 2000
            local closestEnemyPos = enemyHeroes[1]

            if #enemyHeroes == 1 then

                local middleSpot = Player.Position:Extended(enemyHeroes[1].Position, Player.Position:Distance(enemyHeroes[1].Position) - Player.Position:Distance(enemyHeroes[1].Position) / 2)

                if not Utils.IsInRange(Player.Position, middleSpot, 0, Lux.E.Range) then
                    return
                end

                if Lux.Q:IsReady() then
                    return Input.Cast(SpellSlots.Q, middleSpot)
                end

                if Lux.E:GetToggleState() == 0 then

                    if Lux.E:IsReady() then
                        lastETime = Game.GetTime()
                        return Input.Cast(SpellSlots.E, middleSpot)
                    end
                end
            end

            for i, v in pairs(enemyHeroes) do

                if Player.Position:Distance(v.Position) < closestRange then

                    closestEnemyPos = v.Position
                    closestRange    = Player.Position:Distance(v.Position)

                end
            end

            local middleSpot2 = Player.Position:Extended(closestEnemyPos, Player.Position:Distance(closestEnemyPos) - Player.Position:Distance(closestEnemyPos) / 2)

            if not Utils.IsInRange(Player.Position, middleSpot2, 0, Lux.E.Range) then
                return
            end

            if Lux.Q:IsReady() then
                return Input.Cast(SpellSlots.Q, middleSpot2)
            end

            if Lux.E:GetToggleState() == 0 then

                lastETime = Game.GetTime()

                if Lux.E:IsReady() then
                    return Input.Cast(SpellSlots.E, middleSpot2)
                end

            end
        end
    end

end

-- Load
function Lux.LoadMenu()

    Menu.RegisterMenu("BigLux", "BigLux", function()
        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)

        Menu.Checkbox("Support", "Support Mode", false)
        Menu.Keybind("BaronKS", "Auto Steal Baron,Dragon,Buffs.. [HOLD]", string.byte("Y"), false, false, false)
        Menu.Keybind("SemiR", "Semi [R] on closest target to mouse or forced target", string.byte("T"), false, false, false)
        Menu.Text("Hold the Semi ult Key and Lux will ult when the hitchance is high enough")
        Menu.Slider("SemiR.HitChance", "HitChance %", 55, 1, 100, 1)
        Menu.Separator()

        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()

            Menu.Text("")

            Menu.NewTree("QSettings", "[Q] Settings", function()
                Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
                Menu.Slider("Combo.Q.HitChance", "HitChance %", 45, 1, 100, 1)
                Menu.Slider("Combo.Q.MaxRange", "Max Range", Lux.Q.Range, 0, Lux.Q.Range, 10)


            end)

            Menu.NewTree("ESettings", "[E] Settings", function()
                Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
                Menu.Slider("Combo.E.HitChance", "%", 35, 1, 100, 1)
                Menu.Slider("Combo.E.MaxRange", "Max Range", Lux.E.Range, 0, Lux.E.Range, 10)


            end)

            Menu.NewTree("RSettings", "[R] Settings", function()
                Menu.Checkbox("Combo.R.Use", "Cast [R]", true)
                Menu.Checkbox("Combo.R.CheckHP", "Cast [R] only if it kills", true)
                Menu.Slider("Combo.R.HitChance", "HitChance %", 55, 1, 100, 1)
                Menu.Slider("Combo.R.MaxRange", "Max Range", Lux.R.Range, 0, Lux.R.Range, 10)
                Menu.ColoredText("Recommended to reduce by 50 to prevent missed max range ults ", 0xE3FFDF)
                Menu.NewTree("RComboWhitelist", "[R] Whitelist", function()
                    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                        local Name = Object.AsHero.CharName
                        Menu.Checkbox("RC" .. Name, "Use [R] for " .. Name, true)
                    end
                end)


            end)

            Menu.NextColumn()
            Menu.Text("")

        end)

        Menu.NewTree("Shielding", "Shield [W] Settings", function()

            Menu.Checkbox("Ally.Shield.Targeted", "Shield targeted spells", true)
            Menu.Checkbox("Ally.Shield.AA", "Shield basic attacks", true)
            Menu.Checkbox("Ally.Shield.Skillshots", "Shield skillshots", true)
            Menu.Checkbox("Ally.Shield.Ignite", "Shield Ignited ally", true)
            Menu.Checkbox("Ally.Shield.pred", "Shield if predicted hp will be 0", true)


        end)

        Menu.NewTree("BigHeroHarass", "Harass [C]", function()

            Menu.Text("")

            Menu.NewTree("QHarass", "[Q] Settings", function()

                Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
                Menu.Slider("Harass.Q.HitChance", "HitChance %", 55, 1, 100, 1)
                Menu.Slider("Harass.Q.Mana", "Mana %", 50, 0, 100)
                Menu.Slider("Harass.Q.MaxRange", "Max Range", Lux.Q.Range, 0, Lux.Q.Range, 10)


            end)

            Menu.NewTree("EHarass", "[E] Settings", function()

                Menu.Checkbox("Harass.E.Use", "Cast [E]", true)
                Menu.Slider("Harass.E.HitChance", "HitChance %", 35, 1, 100, 1)
                Menu.Slider("Harass.E.Mana", "Mana %", 50, 0, 100)
                Menu.Slider("Harass.E.MaxRange", "Max Range", Lux.E.Range, 0, Lux.E.Range, 10)


            end)

            Menu.NextColumn()
            Menu.Text("")


        end)

        Menu.NewTree("BigHeroLastHit", "LastHit Settings [X]", function()

            Menu.Checkbox("LastHit.E.Use", "Cast [E] to secure cannon when out of AA range", true)

        end)

        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()


            Menu.NewTree("Lane", "Laneclear Options", function()

                Menu.Checkbox("Waveclear.Q.Use", "Use [Q]", true)
                Menu.Checkbox("Waveclear.E.Use", "Use [E]", true)
                Menu.Text("Minimum percent mana to use spells")
                Menu.Slider("Lane.Mana", "Mana %", 50, 0, 100)
                Menu.Text("Minimum amount of minions hit to cast [E]")
                Menu.Slider("Lane.EH", "E Hitcount", 2, 1, 5)
            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q.Use", "Use [Q]", true)
                Menu.Checkbox("Jungle.E.Use", "Use [E]", true)
            end)


        end)

        Menu.NewTree("Auto Settings", "Auto Settings", function()


            Menu.Checkbox("AutoQGap", "Auto [Q] on gapclose", true)
            Menu.Checkbox("AutoEGap", "Auto [E] on gapclose", true)
            Menu.Separator()
            Menu.Checkbox("QKS", "Auto [Q] KS", true)
            Menu.Checkbox("EKS", "Auto [E] KS", true)
            Menu.Checkbox("RKS", "Auto [R] KS", true)
            Menu.NewTree("RKSWhitelist", "RKS Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "Use [R] for " .. Name, true)
                end
            end)
            Menu.Separator()
            Menu.Checkbox("AutoQ", "Auto [Q] if enemy is mid animation and hitchance => very high", true)
            Menu.Checkbox("AutoE", "Auto [E] if enemy is mid animation and hitchance => very high", true)
            Menu.Slider("Auto.Poke.Mana", "Min Mana Percent", 30, 0, 100, 10)
            Menu.Separator()
            Menu.Checkbox("Auto.E.Harass", "Auto Cast [E] if can hit X champions", true)
            Menu.Slider("Auto.E.Slider", "Min Hitcount", 2, 1, 5, 1)
            Menu.Slider("Auto.E.Mana", "Min Mana Percent", 30, 0, 100, 10)


        end)

        Menu.NewTree("Drawings", "Range Drawings", function()


            Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
            Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.E", "Draw [E] Range", true)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.W", "Draw [W] Range", true)
            Menu.ColorPicker("Drawings.W.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.R", "Draw [R] Range", true)
            Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)


        end)

        Menu.NewTree("DmgDrawings", "Damage Drawings", function()


            Menu.Checkbox("DmgDrawings.Q", "Draw [Q] Dmg", true)

            Menu.Checkbox("DmgDrawings.E", "Draw [E] Dmg", true)

            Menu.Checkbox("DmgDrawings.R", "Draw [R] Dmg", true)
            Menu.Checkbox("DmgDrawings.Ludens", "Draw [Ludens] Dmg", true)


        end)

    end)
end
function OnLoad()

    INFO("Big Lux Version " .. ScriptVersion .. " loaded.")
    INFO("For Bugs and Requests Please Contact Roburppey")
    INFO("Replies usually within 24 hours")

    Lux.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Lux[EventName] then
            EventManager.RegisterCallback(EventId, Lux[EventName])
        end
    end

    return true

end
