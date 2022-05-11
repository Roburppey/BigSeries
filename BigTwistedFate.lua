--[[
    BigTwistedFate
]]

if Player.CharName ~= "TwistedFate" then
    return false
end

module("BTwistedFate", package.seeall, log.setup)
clean.module("BTwistedFate", package.seeall, log.setup)






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
local ScriptVersion = "1.1.0"
local ScriptLastUpdate = "9. March 2022"
local iTick = 0
local TwistedFateE = nil
local spell = nil
local lastTeleportTime = nil
local lastPickACardTime = nil
local cardExecuter = nil
--[[Card Locker]]
local NONE, RED, BLUE, YELLOW = 0, 1, 2, 3
local READY, SELECTING, SELECTED = 0, 1, 2, 3
local Status = READY
local Action = "IDLE"
local CardColor = NONE
local ToSelect = NONE
local LastCard = NONE
local AutoYellowCard = "OFF"
local CardStarter = "OFF"
local CastW = "OFF"
local lastRedW = nil
local redListener = "OFF"
local redStarter = "OFF"
local wholeAction = nil
local yellowPicker = "OFF"
local cardToPick = "NONE"
local lastPrinted = "oof"
local pullYellow = "OFF"
local pullRed = "OFF"
local dontOpenCards = false
local pullBlue = "OFF"
local pullYellowUlt = "OFF"
local lastTrigger = nil
local triggerW = "OFF"
local currentCard = "NONE"
local hasPickACardBuff = false
local openCardsTime = nil
CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigTwistedFate.lua", ScriptVersion)


-- Globals
local TwistedFate = {}
local Utils = {}

TwistedFate.TargetSelector = nil
TwistedFate.Logic = {}

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


-- TwistedFate
TwistedFate.Q = SpellLib.Skillshot({

    Slot = Enums.SpellSlots.Q,
    Range = 1450,
    Radius = 40,
    Delay = 0.25,
    Speed = 1000,
    Collisions = { Heroes = false, Minions = false, WindWall = true },
    Type = "Linear",
    UseHitbox = true


})
TwistedFate.W = SpellLib.Active({

    Slot = Enums.SpellSlots.W,
    Range = 1175,
    Radius = 110,
    Delay = 0.25,
    Type = "Active",

})
TwistedFate.E = SpellLib.Skillshot({

    Slot = Enums.SpellSlots.E,
    Range = 1100,
    Radius = 300,
    Delay = 0.25,
    Speed = 1200,
    Collisions = { WindWall = true },
    Type = "Circular",
    UseHitbox = true


})
TwistedFate.E2 = SpellLib.Active({

    Slot = Enums.SpellSlots.E,

})
TwistedFate.R = SpellLib.Skillshot({

    Slot = Enums.SpellSlots.R,
    Range = 5500,
    Radius = 100,
    Delay = 1,
    Speed = math.huge,
    Type = "Linear",
    UseHitbox = true

})

-- Functions

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

    if not TwistedFate.Q:IsLearned() or not TwistedFate.Q:IsReady() then
        return 0

    end

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, (60 + (TwistedFate.Q:GetLevel() - 1) * 45) + (0.65 * Player.TotalAP))

end

function GetWDmg(target)

    if target == nil then
        return 0
    end

    if not TwistedFate.W:IsReady() then
        return 0
    end

    -- 15 / 22.5 / 30 / 37.5 / 45 (+ 100% AD) (+ 50% AP)

    local EBaseDmg = ({ 70, 120, 170, 220, 270 })[TwistedFate.E:GetLevel()]

    local apDmg = Player.TotalAP * 0.7

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, (15 + (TwistedFate.W:GetLevel() - 1) * 7.5) + (0.5 * Player.TotalAP) + (Player.TotalAD))


end
function SelectYellow()
    if Status == READY then
        ToSelect = YELLOW
        Input.Cast(SpellSlots.W)
    end
end
function GetPassiveDamage(target)

    local baseDmg = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)

end
function round(number, decimals)
    local power = 10 ^ decimals
    return math.floor(number * power) / power
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

function Utils.IsCasting()

    local spell = Player.ActiveSpell

    if spell then

        if spell.Name == "TwistedFateLightBinding" then
            return true
        end
        if spell.Name == "TwistedFateLightStrikeKugel" then
            return true
        end

    end

    return false

end
function Utils.CastW()
    CastW = "ON"
    Input.Cast(SpellSlots.W)
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
function PickACard()

    if CardColor == cardToPick then
        cardToPick = NONE
        Status = READY
        return Input.Cast(SpellSlots.W)
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
function Utils.CastW()
    CastW = "ON"
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

function TwistedFate.OnProcessSpell(Caster, SpellCast)


    if Caster.IsMe then

        if SpellCast.Name == "PickACard" then
            -- print("setting dontOpenCards TRUE")
            currentCard = "SELECTING"
            dontOpenCards = true
        end

        if SpellCast.Name == "GoldCardLock" or SpellCast.name == "BlueCardLock" or SpellCast.name == "RedCardLock" then
            -- print("setting dontOpenCards FALSE")
            currentCard = "NONE"
            pullYellowUlt = "OFF"
            pullYellow = "OFF"
            pullBlue = "OFF"
            pullRed = "OFF"
            dontOpenCards = false
        end

        if SpellCast.Name == "Gate" then


        end

    end


end

function TwistedFate.OnUpdate()


end

function SelectCard(color)


end

function OpenCards()

    -- -- print(currentCard)

    if pullYellowUlt == "ON" then
        if not dontOpenCards then

            -- print("got here")
            if Input.Cast(SpellSlots.W) then
                -- print("triggering W from OpenCards. new one")
                dontOpenCards = true
                openCardsTime = Game.GetTime()
            end

        end
    end

    if currentCard == "YELLOW" then
        return
    end

    if currentCard == "RED" then
        return
    end

    if currentCard == "BLUE" then
        return
    end

    if openCardsTime == nil then

        if not hasPickACardBuff then

            if Input.Cast(SpellSlots.W) then
                dontOpenCards = true
                -- print("triggering W from OpenCards. top one")
                openCardsTime = Game.GetTime()
            end
        end


    end

    if not hasPickACardBuff then

        if TwistedFate.W:IsReady() then

            if openCardsTime == nil then
                if Input.Cast(SpellSlots.W) then
                    -- print("triggering W from OpenCards. middle one")
                    dontOpenCards = true
                    openCardsTime = Game.GetTime()
                end
                return
            end

            if Game.GetTime() - openCardsTime > 2 then

                if Input.Cast(SpellSlots.W) then
                    -- print("triggering W from OpenCards. bottom one")
                    dontOpenCards = true
                    openCardsTime = Game.GetTime()
                end


            end

        end
    end


end

function TwistedFate.OnBuffGain(obj, buffInst)


end

function TwistedFate.OnBuffLost(obj, buffInst)

    if obj.IsMe then
        if buffInst.Name == "pickacard_tracker" then
            CardColor = NONE
        end
    end

end

function TwistedFate.OnGapclose(source, dash)


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

    if particleName == "TwistedFate_Base_E_tar_aoe_sound" and Utils.CountEnemiesInRange(v.Position, 310) > 0 then

        if TwistedFate.E2:Cast() then
            return true
        end


    end

    return statusCode

end

function TwistedFate.Logic.R(Target)


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

function TwistedFate.Logic.Q(Target)


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

    if not TwistedFate.Q:IsReady() then
        return false
    end

    if Utils.HasBuff(Player, "GoldCardPreAttack") then
        return
    end

    if Menu.Get("ADTF") then

        local distanceTarget = Player:Distance(Target.Position)
        local AARange = Orbwalker.GetTrueAutoAttackRange(Player, Target)

        if distanceTarget <= AARange then
            return
        end

    end

    if Utils.IsInRange(Player.Position, target.Position, 0, TwistedFate.Q.Range) then

        TwistedFate.Q:CastOnHitChance(Target, Menu.Get("Combo.Q.HitChance"))

    end

    return false


end

function TwistedFate.Logic.W(lagFree)


end

function TwistedFate.Logic.E(Target)


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

    if TwistedFate.E:IsReady() and TwistedFate.E:GetToggleState() == 2 then


    end

    if Utils.IsInRange(Player.Position, target.Position, 0, Menu.Get("Combo.E.MaxRange")) then

        local ePred = TwistedFate.E:GetPrediction(target)

        if ePred and ePred.HitChanceEnum >= Menu.Get("Combo.E.HitChance") then

            if Player.Position:Distance(ePred.CastPosition) <= Menu.Get("Combo.E.MaxRange") then

                if TwistedFate.E:Cast(ePred.CastPosition) then
                    return true
                end
            end
        end

        return false

    end
end

function TwistedFate.Logic.Flee(lagFree)


    if lastETime == 0 or Game.GetTime() - lastETime > 2 then


        if lagFree == 1 then

            local enemyHeroes = ObjectManager.GetNearby("enemy", "heroes")

            if #enemyHeroes < 1 then
                return
            end

            local closestRange = 2000
            local closestEnemyPos = enemyHeroes[1]

            if #enemyHeroes == 1 then

                local middleSpot = Player.Position:Extended(enemyHeroes[1].Position, Player.Position:Distance(enemyHeroes[1].Position) - Player.Position:Distance(enemyHeroes[1].Position) / 2)

                if not Utils.IsInRange(Player.Position, middleSpot, 0, TwistedFate.E.Range) then
                    return
                end

                if TwistedFate.Q:IsReady() then
                    return Input.Cast(SpellSlots.Q, middleSpot)
                end

                if TwistedFate.E:GetToggleState() == 0 then

                    if TwistedFate.E:IsReady() then
                        lastETime = Game.GetTime()
                        return Input.Cast(SpellSlots.E, middleSpot)
                    end
                end
            end

            for i, v in pairs(enemyHeroes) do

                if Player.Position:Distance(v.Position) < closestRange then

                    closestEnemyPos = v.Position
                    closestRange = Player.Position:Distance(v.Position)

                end
            end

            local middleSpot2 = Player.Position:Extended(closestEnemyPos, Player.Position:Distance(closestEnemyPos) - Player.Position:Distance(closestEnemyPos) / 2)

            if not Utils.IsInRange(Player.Position, middleSpot2, 0, TwistedFate.E.Range) then
                return
            end

            if TwistedFate.Q:IsReady() then
                return Input.Cast(SpellSlots.Q, middleSpot2)
            end

            if TwistedFate.E:GetToggleState() == 0 then

                lastETime = Game.GetTime()

                if TwistedFate.E:IsReady() then
                    return Input.Cast(SpellSlots.E, middleSpot2)
                end

            end
        end
    end

end

function TwistedFate.OnDraw()

    if Menu.Get("WPreview") then
        Renderer.DrawCircle3D(Player.Position, Menu.Get("WRange"), 30, 1, 0xFF0000FF)
    end

    if Menu.Get("Drawings.R") then
        Renderer.DrawCircle3D(Player.Position, TwistedFate.R.Range, 30, 7, Menu.Get("Drawings.R.Color"))
    end

    if Menu.Get("Drawings.Q") then
        Renderer.DrawCircle3D(Player.Position, TwistedFate.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
    end

    local lowHpEnemies = { }

    for i, v in pairs(ObjectManager.Get("enemy", "heroes")) do

        if v.IsAlive then

            if Utils.IsInRange(Player.Position, v.Position, 0, 5500) then

                if v.Health < v.MaxHealth * 0.35 then
                    table.insert(lowHpEnemies, v)
                end
            end
        end
    end

    local lowEnemies = ""

    for i, v in ipairs(lowHpEnemies) do
        lowEnemies = lowEnemies .. v.CharName .. " "
    end

    if #lowEnemies >= 1 then
        Renderer.DrawTextOnPlayer("Low HP enemies in [R] Range: ", 0x00FFFAFF)
        Renderer.DrawTextOnPlayer(lowEnemies, 0xFF0000FF)

    end

    if TwistedFate.R:IsReady() or Utils.HasBuff(Player, "destiny_marker") then

        if Menu.Get("Draw.Minimap") then

            Renderer.DrawCircleMM(Player.Position, 5500, 3, 0x00FFFAFF, true)

        end
        for i, v in ipairs(lowHpEnemies) do


            if Menu.Get("RMark") then
                Renderer.DrawCircleMM(v.Position, 700, 3, 0x08FF00FF, true)
                Renderer.DrawLine(Renderer.WorldToMinimap(Player.Position), Renderer.WorldToMinimap(v.Position:Extended(Player.Position, 700)), 3, 0x08FF00FF)
            end
        end


    end

    local screenPosition = Renderer.GetMousePos():ToScreen()
    screenPosition.y = screenPosition.y + 50
    screenPosition.x = screenPosition.x - 75
    local BaronText = "Baron/Dragon/Buff Steal [ON]"
    local BaronColor = 0x3DC800FF


end

function TwistedFate.OnHeroImmobilized(Source, EndTime, IsStasis)

end

function TwistedFate.Logic.Auto(lagFree)


    if Player.IsDead then
        dontOpenCards = false
    end
    if Player.GetSpell(Player, SpellSlots.W).RemainingCooldown > 1 then
        dontOpenCards = false
       -- print("falsing!!!!!!")
    end

end

function TwistedFate.OnExtremePriority(lagFree)
    if openCardsTime then

        if not Utils.HasBuff(Player, "pickacard_tracker") then

            if Game.GetTime() - openCardsTime > 0.25 then
                if dontOpenCards then
                    dontOpenCards = false

                end

            end

        end

    end

    if Utils.HasBuff(Player, "pickacard_tracker") then


        hasPickACardBuff = true
    else
        hasPickACardBuff = false
    end

    if pullYellowUlt == "ON" and not dontOpenCards then

        if Input.Cast(SpellSlots.W) then
            pullYellow = "ON"
            dontOpenCards = true
        end

    end

    if lastTeleportTime ~= nil then


    end

    if Orbwalker.GetMode() == "nil" then
        pullYellow = "OFF"
        pullRed = "OFF"
        pullBlue = "OFF"
    end

    if Player.IsDead then
        dontOpenCards = "FALSE"
    end

    if CastW == "ON" then
        if Game.GetTime() - lastTeleportTime > 0.5 then
            if TwistedFate.W:Cast() then
                CastW = "OFF"
            end
        end
    end

end
function TwistedFate.OnDrawDamage(target, dmgList)

    if not target then
        return
    end
    if not target.IsAlive then
        return
    end

    if Menu.Get("DmgDrawings.Q") then

        table.insert(dmgList, GetQDmg(target))

    end

    if Menu.Get("DmgDrawings.W") then

        table.insert(dmgList, GetWDmg(target))

    end

    if Menu.Get("DmgDrawings.Ludens") then

        table.insert(dmgList, Utils.GetLudensDmg())

    end


end

function TwistedFate.OnCreateObject(obj, lagFree)


    if obj.Name == "TwistedFate_Base_W_GoldCard" then
        currentCard = "YELLOW"
        -- print("HOLDING YELLOW")
        dontOpenCards = "true"

        if pullYellow == "ON" then
            -- print("Pulling YELLOW card from on create")
            if Input.Cast(SpellSlots.W) then
                pullYellow = "OFF"
            end

        end

    end

    if obj.Name == "TwistedFate_Base_W_BlueCard" then

        currentCard = "BLUE"
        -- print("HOLDING BLUE")
        dontOpenCards = "true"
        if currentCard == "BLUE" then
            if pullBlue == "ON" then
                -- print("Pulling BLUE card from on create")

                if Input.Cast(SpellSlots.W) then
                    pullBlue = "OFF"
                end

            end
        end


    end

    if obj.Name == "TwistedFate_Base_W_RedCard" then
        dontOpenCards = "true"
        currentCard = "RED"
        -- print("HOLDING RED")

        if currentCard == "RED" then
            if pullRed == "ON" then


                if Input.Cast(SpellSlots.W) then
                    -- print("Pulling RED card from on create")
                    pullRed = "OFF"
                end

            end
        end


    end

end

function TwistedFate.OnDeleteObject(obj, lagFree)
    if obj.Name == "TwistedFate_Base_W_GoldCard" then

        currentCard = "SELECTING"
    end

    if obj.Name == "TwistedFate_Base_W_BlueCard" then
        currentCard = "SELECTING"
    end
    if obj.Name == "TwistedFate_Base_W_RedCard" then
        currentCard = "SELECTING"
    end

end

function TwistedFate.OnTick(lagFree)

    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = TwistedFate.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if TwistedFate.Logic.Auto(lagFree) then
        return true
    end

    --[[


        --]]

end
function TwistedFate.Logic.Waveclear(lagFree)


    local attackingTurret = false
    local attackingScuttle = false
    local attackingEpicMinion = false
    local attackingGromp = false
    local attackingBuff = false

    local WaveTarget = Orbwalker.GetLastTarget()
    if WaveTarget then


        if WaveTarget.IsTurret then
            if Orbwalker:TimeSinceLastAttack() < 1 then
                attackingTurret = true

            end
        end

        local minion = WaveTarget.AsAI
        if not minion then
            return
        end

        if minion.IsEpicMinion then
            attackingEpicMinion = true

            -- print("Attacking " .. minion.Name)
        end

        if WaveTarget.CharName then

            if WaveTarget.CharName == "SRU_Gromp" then
                attackingGromp = true
                -- print("attacking Gromp")
            end

            if WaveTarget.CharName == "SRU_Red" or WaveTarget.CharName == "SRU_Blue" then
                attackingBuff = true
                -- print("attacking buff")
            end

            if WaveTarget.CharName == "Sru_Crab" then
                if Orbwalker:TimeSinceLastAttack() < 1 then
                    -- print("attacking crab")
                    attackingScuttle = true
                end

            end


        end

    end

    local WaveMode = "normal"

    if Menu.IsKeyPressed(1) then
        WaveMode = "mana"
    end

    if pullYellow == "ON" then
        pullYellow = "OFF"
    end

    if Menu.Get("AutoManaWave") then
        if Player.Mana < Player.MaxMana * (Menu.Get("ManaWaveSlider") / 100) then
            WaveMode = "mana"
        end

    end

    if Utils.HasBuff(Player, "pickacard_tracker") then

        if Menu.IsKeyPressed(1) then

            if Menu.Get("Wave.BlueCard.Use") then
                pullBlue = "ON"
                pullRed = "OFF"

            end


        else

        end

        if Utils.CountMinionsInRange(600, "enemy") > 1 then
            pullBlue = "OFF"
            pullRed = "ON"
        elseif Utils.CountMinionsInRange(600, "enemy") == 1 then
            pullBlue = "ON"
            pullRed = "OFF"

        end

        if Utils.CountMinionsInRange(600, "enemy") == 0 then
            if Utils.CountMonstersInRange(600, "neutral") == 1 then

                -- print("ye")

                pullBlue = "ON"
                pullRed = "OFF"
            end
        end

        if Menu.Get("AutoManaWave") then

            if Player.Mana < Player.MaxMana * (Menu.Get("ManaWaveSlider") / 100) then

                pullBlue = "ON"
                pullRed = "OFF"
            else

                pullBlue = "OFF"
                pullRed = "ON"


            end
        end

        if Menu.Get("AutoManaWave") then

            if Player.Mana < Player.MaxMana * (Menu.Get("ManaWaveSlider") / 100) then

                pullBlue = "ON"
                pullRed = "OFF"
            else

                pullBlue = "OFF"
                pullRed = "ON"


            end
        end

        if attackingTurret then
            if Menu.Get("TurretBlueCard") then
                pullRed = "OFF"
                pullBlue = "ON"
                pullYellow = "OFF"
                return true
            end
        end

        if attackingEpicMinion then
            if Menu.Get("EpicBlueCard") then
                pullRed = "OFF"
                pullBlue = "ON"
                pullYellow = "OFF"
            end
        end

        if attackingScuttle then
            if Menu.Get("ScuttleGoldCard") then
                pullRed = "OFF"
                pullBlue = "OFF"
                pullYellow = "ON"
            end
        end

        if attackingGromp then


            if Player.Health > Player.MaxHealth * 0.7 then
                pullRed = "OFF"
                pullBlue = "ON"
                pullYellow = "OFF"
            else
                pullRed = "OFF"
                pullBlue = "OFF"
                pullYellow = "ON"
            end

        end

        if attackingBuff then


            if Player.Health > Player.MaxHealth * 0.7 then
                pullRed = "OFF"
                pullBlue = "ON"
                pullYellow = "OFF"
            else
                pullRed = "OFF"
                pullBlue = "OFF"
                pullYellow = "ON"
            end

        end


    end

    if WaveMode == "mana" then


        if Menu.Get("WaveMana.Q.Use") then

            if TwistedFate.Q:IsReady() then

                local pPos, pointsQ = Player.Position, {}
                local pointsE = {}

                for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
                    local minion = v.AsAI
                    if minion then
                        if minion.IsTargetable and minion.MaxHealth > 6 and TwistedFate.Q:IsInRange(minion) then
                            local pos = minion:FastPrediction(Game.GetLatency() + TwistedFate.Q.Delay)
                            if pos:Distance(pPos) < TwistedFate.Q.Range and minion.IsTargetable then
                                table.insert(pointsQ, pos)
                            end
                        end
                    end
                end

                for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
                    local minion = v.AsAI
                    if minion then
                        if minion.IsTargetable and minion.MaxHealth > 6 and TwistedFate.Q:IsInRange(minion) then
                            local pos = minion:FastPrediction(Game.GetLatency() + TwistedFate.Q.Delay)
                            if pos:Distance(pPos) < TwistedFate.Q.Range and minion.IsTargetable then
                                -- print("Inserted " .. v.CharName)
                                table.insert(pointsQ, pos)
                            end
                        end
                    end
                end

                local bestPos, hitCount = TwistedFate.Q:GetBestLinearCastPos(pointsQ, TwistedFate.Q.Radius)
                if bestPos and hitCount >= Menu.Get("Q.ManaWave.Min") then
                    TwistedFate.Q:Cast(bestPos)
                end
            end

        end
    end

    if WaveMode == "normal" then

        if Menu.Get("Wave.Q.Use") and TwistedFate.Q:IsReady() then

            local pPos, pointsQ = Player.Position, {}
            local pointsE = {}

            for k, v in pairs(ObjectManager.Get("enemy", "minions")) do
                local minion = v.AsAI
                if minion then
                    if minion.IsTargetable and minion.MaxHealth > 6 and TwistedFate.Q:IsInRange(minion) then
                        local pos = minion:FastPrediction(Game.GetLatency() + TwistedFate.Q.Delay)
                        if pos:Distance(pPos) < TwistedFate.Q.Range and minion.IsTargetable then
                            table.insert(pointsQ, pos)
                        end
                    end
                end
            end

            for k, v in pairs(ObjectManager.Get("neutral", "minions")) do
                local minion = v.AsAI
                if minion then
                    if minion.IsTargetable and minion.MaxHealth > 6 and TwistedFate.Q:IsInRange(minion) then
                        local pos = minion:FastPrediction(Game.GetLatency() + TwistedFate.Q.Delay)
                        if pos:Distance(pPos) < TwistedFate.Q.Range and minion.IsTargetable then
                            -- print("Inserted " .. v.CharName)
                            table.insert(pointsQ, pos)
                        end
                    end
                end
            end

            local bestPos, hitCount = TwistedFate.Q:GetBestLinearCastPos(pointsQ, TwistedFate.Q.Radius)
            if bestPos and hitCount >= Menu.Get("Q.Wave.Min") then
                TwistedFate.Q:Cast(bestPos)
            end


        end


    end

    if lagFree == 2 then

        if TwistedFate.W:IsReady() then

            if attackingTurret then
                if Menu.Get("TurretBlueCard") then
                    OpenCards()
                    return true
                end
            end

            if attackingEpicMinion then
                if Menu.Get("EpicBlueCard") then
                    OpenCards()
                    return true
                end
            end

            if attackingScuttle then
                if Menu.Get("ScuttleGoldCard") then
                    OpenCards()
                    return true
                end
            end

            if not Menu.IsKeyPressed(1) then

                if Menu.Get("Wave.RedCard.Use") then


                    if Utils.CountMinionsInRange(600, "enemy") >= 1 or Utils.CountMinionsInRange(600, "neutral") >= 1 then
                        OpenCards()
                    end
                end

            else

                if Menu.Get("Wave.BlueCard.Use") then
                    if Utils.CountMinionsInRange(600, "enemy") >= 1 or Utils.CountMinionsInRange(600, "neutral") >= 1 then
                        OpenCards()
                    end

                end
            end

        end

    end


end

function TwistedFate.Logic.Lasthit(lagFree)

end

function TwistedFate.Logic.Harass(lagFree)

    local Target = TS:GetTarget(2000)

    if not Target then
        return
    end

    if Menu.Get("Harass.Q.Use") then
        if Player.Mana > Player.MaxMana * (Menu.Get("Harass.Q.Mana") / 100) then


            TwistedFate.Logic.Q(Target)


        end

    end


end
function TwistedFate.Logic.Combo(lagFree)


    if pullBlue == "ON" then
        pullBlue = "OFF"
    end

    if pullRed == "ON" then
        pullRed = "OFF"
    end

    local Target = TS:GetTarget(2000)

    if not Target then


        if TwistedFate.R:IsLearned() then
            if Player:GetSpellState(SpellSlots.R) == 32 then

                if Player.GetSpell(Player, SpellSlots.R).RemainingCooldown > 0 and Player.GetSpell(Player, SpellSlots.R).RemainingCooldown < Player.GetSpell(Player, SpellSlots.R).TotalCooldown and Player.GetSpell(Player, SpellSlots.R).RemainingCooldown > Player.GetSpell(Player, SpellSlots.R).TotalCooldown * 0.9 then
                    OpenCards()
                    pullYellow = "ON"

                end

                return
            end

        end

    end

    if Target then

        if lagFree == 1 then

            local cardOpen = false

            for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do

                if Player:Distance(v) <= Menu.Get("WRange") then
                    cardOpen = true
                    pullYellow = "ON"
                end

            end

            if cardOpen then

                OpenCards()
                pullYellow = "ON"

            end
        end

        if Player:Distance(Target.Position) > Orbwalker.GetTrueAutoAttackRange(Player, Target) or not TwistedFate.W:IsReady() then


            if lagFree == 2 then

                if Menu.IsKeyPressed(1) then
                    return
                end

                TwistedFate.Logic.Q(Target)
            end
        end

    end


end

function TwistedFate.OnPreAttack(args)

    local mode = Orbwalker.GetMode()


end

function TwistedFate.OnPostAttack(target)

end

function TwistedFate.LoadMenu()

    Menu.RegisterMenu("BigTwistedFate", "BigTwistedFate", function()
        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)
        Menu.Text("")
        Menu.ColoredText("Note:", 0x00C900FF)
        Menu.ColoredText("Holding [LMB] during combo disables AA and [Q] ", 0xE3FFDF)
        Menu.ColoredText("So you don't lose speed to AA or [Q] when chasing", 0xE3FFDF)
        Menu.ColoredText("Remember to let go of [LMB] when you want to throw Gold Card", 0xE3FFDF)
        Menu.Text("")
        Menu.Checkbox("ADTF", "AD Twisted Fate Mode", false)
        Menu.ColoredText("This will only use [Q] when not in range for an AA", 0xE3FFDF)
        Menu.ColoredText("If you want to disable [Q] completely, go to combo settings", 0xE3FFDF)

        Menu.Text("")
        Menu.Separator()

        Menu.Text("")
        Menu.NewTree("BigHeroCombo", "Combo", function()
            Menu.Text("")

            Menu.NewTree("QSettings", "[Q] Settings", function()
                Menu.Text("")
                Menu.Checkbox("Combo.Q.Use", "Cast [Q]", true)
                Menu.Dropdown("Combo.Q.HitChance", "HitChance", HitChance.High, HitChanceStrings)
                Menu.Text("")
            end)

            Menu.NewTree("WSettings", "[W] Settings", function()
                Menu.Text("")
                Menu.Checkbox("Combo.W.Use", "Cast [W]", true)
                Menu.Text("")
                Menu.Text("Use [W] When Enemy Is Within X Range: ")
                Menu.ColoredText("Tip: TF [Q] Range is 1450", 0xE3FFDF)
                Menu.Slider("WRange", "", 1200, 550, 2000, 50)
                Menu.Checkbox("WPreview", "Enable Preview Range Drawing For [W] Activation", false)
                Menu.Text("")
            end)

            Menu.NextColumn()
            Menu.Text("")

        end)

        Menu.NewTree("BigHeroHarass", "Harass [C]", function()

            Menu.Text("")

            Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
            Menu.Dropdown("Harass.Q.HitChance", "", HitChance.High, HitChanceStrings)

            Menu.Text("")
            Menu.Text("[Q] Min Mana Percent")
            Menu.Slider("Harass.Q.Mana", "%", 50, 0, 100)
            local power = 10 ^ 2
            local result = math.floor(Player.MaxMana / 100 * Menu.Get("Harass.Q.Mana") * power) / power
            Menu.ColoredText(Menu.Get("Harass.Q.Mana") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)

            Menu.NextColumn()
            Menu.Text("")


        end)

        Menu.NewTree("BigHeroWaveclear", "Waveclear Settings [V]", function()
            Menu.Text("")
            Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()

                Menu.ColoredText(" Normal Waveclear Mode - Red Card", 0xFFD200FF)
                Menu.Text("")
                Menu.Checkbox("Wave.Q.Use", "Use [Q] for Waveclear", true)
                Menu.Checkbox("Wave.RedCard.Use", "Use [W] Red Card for Waveclear", true)
                Menu.Text("Minimum Minions Hit With [Q]")
                Menu.Slider("Q.Wave.Min", "        ", 3, 1, 6, 1)
                Menu.Text("")

                Menu.Text("")
                Menu.ColoredText(" Mana Waveclear Mode [V + LMB] - Blue Card", 0xFFD200FF)
                Menu.Text("")
                Menu.Checkbox("WaveMana.Q.Use", "Use [Q] during Mana Mode", true)
                Menu.Checkbox("Wave.BlueCard.Use", "Use [W] Blue Card for mana mode", true)
                Menu.Text("Minimum Minions Hit With [Q]")
                Menu.Slider("Q.ManaWave.Min", "        ", 6, 1, 6, 1)
                Menu.Checkbox("AutoManaWave", "Auto switch to Mana Mode if below ...              ", true)
                Menu.Slider("ManaWaveSlider", "Percent      ", 60, 0, 100, 5)
                local power = 10 ^ 2
                local result = math.floor(Player.MaxMana / 100 * Menu.Get("ManaWaveSlider") * power) / power
                Menu.ColoredText(Menu.Get("ManaWaveSlider") .. " Percent Is Equal To " .. result .. " Mana", 0xE3FFDF)
                Menu.Text("")
                Menu.Text("")
                Menu.NextColumn()

                Menu.ColoredText(" Auto Convenience Cards", 0xFFD200FF)
                Menu.Text("")

                Menu.Checkbox("TurretBlueCard", "Always Use Blue Card on Turrets", true)
                Menu.Checkbox("EpicBlueCard", "Always Use Blue Card on Epic Minions", true)
                Menu.Checkbox("ScuttleGoldCard", "Always Use Gold Card on Scuttle", true)
                Menu.Text("")

            end)
            Menu.Text("")

        end)

        Menu.NewTree("Drawings", "Drawings", function()
            Menu.ColumnLayout("DrawMenu2", "DrawMenu2", 2, true, function()

                Menu.Text("")
                Menu.ColoredText("Range Drawings", 0xE3FFDF)
                Menu.Text("")
                Menu.Checkbox("Drawings.Q", "Draw [Q] Range", true)
                Menu.ColorPicker("Drawings.Q.Color", "", 0xEF476FFF)
                Menu.Checkbox("Drawings.R", "Draw [R] Range", true)
                Menu.ColorPicker("Drawings.R.Color", "", 0xEF476FFF)
                Menu.Checkbox("Draw.Minimap", "Draw [R] On Minimap", true)
                Menu.Text("")
                Menu.NextColumn()
                Menu.Text("")
                Menu.ColoredText("Damage Drawings", 0xE3FFDF)
                Menu.Text("")
                Menu.Checkbox("DmgDrawings.Q", "Draw [Q] Dmg", true)

                Menu.Checkbox("DmgDrawings.W", "Draw [W] Dmg", true)

                Menu.Checkbox("DmgDrawings.Ludens", "Draw [Ludens] Dmg", true)
                Menu.Text("")
                Menu.NextColumn()

            end)
            Menu.Separator()
            Menu.Text("")

            Menu.ColoredText("Extra Drawings", 0xE3FFDF)
            Menu.Text("")
            Menu.Checkbox("RMark", "Mark Low HP Enemies On Minimap", true)


        end)


    end)
end

function OnLoad()

    INFO("Welcome to BigTwistedFate, enjoy your stay")

    TwistedFate.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if TwistedFate[EventName] then
            EventManager.RegisterCallback(EventId, TwistedFate[EventName])
        end
    end

    return true

end
