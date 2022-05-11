--[[
    BigBrand
]]
if Player.CharName ~= "Brand" then
    return false
end

module("Brand", package.seeall, log.setup)
clean.module("Brand", package.seeall, log.setup)

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
local Player = ObjectManager.Player.AsHero
local ScriptVersion = "1.1.0"
local ScriptLastUpdate = "10. April 2022"
local Colorblind = false
local isComboing = false
local lastBurs
local lastBurstTime = nil
local lastPrint = ""
local DamageTypes = _G.CoreEx.Enums.DamageTypes
local Nav = _G.CoreEx.Nav

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigBrand.lua", ScriptVersion)

-- Globals
local Brand = {}
local Utils = {}

Brand.TargetSelector = nil
Brand.Logic = {}

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

-- Brand Spells
Brand.Q = SpellLib.Skillshot(
    {
        -- RANGE: Range center.png 1100 / Range model.png 1040
        --WIDTH: Range model.png 120
        --SPEED: 1600
        --CAST TIME: 0.25
        --COST: 50 MANA

        Slot = Enums.SpellSlots.Q,
        Range = 1000,
        Radius = 60,
        Delay = 0.25,
        Speed = 1600,
        Collisions = { Heroes = true, Minions = true, WindWall = true },
        Type = "Linear"
    }
)
Brand.W = SpellLib.Skillshot(
    {
        -- TARGET RANGE: 900
        --EFFECT RADIUS: Range center.png 260
        --CAST TIME: 0.25

        Slot = Enums.SpellSlots.W,
        Range = 900,
        Radius = 260,
        Delay = 0.25 + 0.627,
        Type = "Circular"
    }
)
Brand.E = SpellLib.Targeted(
    {
        -- TARGET RANGE: Range center.png 675
        --EFFECT RADIUS: Range center.png 300 / 600
        --CAST TIME: 0.25

        Slot = Enums.SpellSlots.E,
        Range = 675,
        Radius = 300,
        EffectRadius = 600,
        Delay = 0.25
    }
)
Brand.R = SpellLib.Targeted(
    {
        --   Range center.png 750
        --EFFECT RADIUS: Range center.png 600
        --SPEED: 750 - 3000

        Slot = Enums.SpellSlots.R,
        Range = 750,
        Delay = 0.25,
        Speed = math.huge,
        Type = "Targeted",
        Collisions = { WindWall = true }
    }
)

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

function Utils.GetArea()
    return Nav.GetMapArea(Player.Position)["Area"]
end

function Utils.IsInJungle()
    if string.match(Utils.GetArea(), "Lane") then
        return false
    else
        return true
    end
end

function Utils.CountMonstersInRange(range, type)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range
        then
            amount = amount + 1
        end
    end
    return amount
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
    local Array = {}
    local Index = 0

    for _, Object in pairs(Objects) do
        if Object and Object ~= Target then
            Object = Object.AsAI
            if Utils.IsValidTarget(Object) and (not Condition or Condition(Object)) then
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

function Utils.ManaSlider(id, name, default)
    Menu.Slider(id, name, default, 0, 100, 5)
    local power = 10 ^ 2
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

function Utils.HealthSlider(id, name, default)
    Menu.ColoredText(name, 0xEFC347FF)
    Menu.Text("")
    Menu.ColoredText("Health Percent Slider:", 0xE3FFDF)
    Menu.Slider(id, "", default, 0, 100, 5)
    local power = 10 ^ 2
    local result = math.floor(Player.MaxHealth / 100 * Menu.Get(id) * power) / power
    Menu.ColoredText(Menu.Get(id) .. " Percent Is Equal To " .. result .. " Health", 0xE3FFDF)
end

function Utils.EnabledAndMinimumHealth(useID, manaID, target)
    local power = 10 ^ 2
    return Menu.Get(useID) and target.Health <= math.floor(target.MaxHealth / 100 * Menu.Get(manaID) * power) / power
end

-- Hero Specific Functions
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
    -- 80 / 110 / 140 / 170 / 200 (+ 55% AP)
    if not Brand.Q:IsLearned() or not Brand.Q:IsReady() then
        return 0
    end

    return DamageLib.CalculateMagicalDamage(
        Player.AsAI,
        target,
        (80 + (Brand.Q:GetLevel() - 1) * 30) + (0.55 * Player.TotalAP)
    )
end

function GetWDmg(target)
    if target == nil then
        return 0
    end

    if not Brand.W:IsReady() then
        return 0
    end

    -- 75 / 120 / 165 / 210 / 255 (+ 60% AP)
    -- 93.75 / 150 / 206.25 / 262.5 / 318.75 (+ 75% AP)

    local EBaseDmg = ({ 70, 120, 170, 220, 270 })[Brand.E:GetLevel()]

    local apDmg = Player.TotalAP * 0.7

    if Utils.HasBuff(target, "BrandAblaze") then
        return DamageLib.CalculateMagicalDamage(
            Player.AsAI,
            target,
            (93.75 + (Brand.W:GetLevel() - 1) * 56.25) + (0.75 * Player.TotalAP)
        )
    end

    return DamageLib.CalculateMagicalDamage(
        Player.AsAI,
        target,
        (75 + (Brand.W:GetLevel() - 1) * 45) + (0.6 * Player.TotalAP)
    )
end

function GetEDmg(target)
    if target == nil then
        return 0
    end

    if not Brand.E:IsReady() then
        return 0
    end

    -- 70 / 95 / 120 / 145 / 170 (+ 45% AP)

    return DamageLib.CalculateMagicalDamage(
        Player.AsAI,
        target,
        (70 + (Brand.W:GetLevel() - 1) * 25) + (0.45 * Player.TotalAP)
    )
end

function GetRDmg(target)
    if target == nil then
        return 0
    end

    if not Brand.R:IsReady() then
        return 0
    end

    local bounces = Menu.Get("RBounceDmgDraw")

    -- 100 / 200 / 300 (+ 25% AP)

    return DamageLib.CalculateMagicalDamage(
        Player.AsAI,
        target,
        (100 + (Brand.W:GetLevel() - 1) * 100) + (0.25 * Player.TotalAP)
    ) * bounces
end

function GetPDmg(target)
    if target == nil then
        return 0
    end

    if not Brand.R:IsReady() then
        return 0
    end

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, target.MaxHealth * 0.03) * 2
end

function GetP2Dmg(target)
    if target == nil then
        return 0
    end

    local healthPercentDmg =
    ({
        0.10,
        0.1025,
        0.1050,
        0.1075,
        0.11,
        0.1125,
        0.1150,
        0.1175,
        0.12,
        0.1225,
        0.1250,
        0.1275,
        0.13,
        0.1325,
        0.1350,
        0.1375,
        0.14,
        0.14
    })[Player.Level]
    local apPercentDmg = 0.02 * Player.TotalAP / 100
    local totalPercentDmg = target.MaxHealth * (apPercentDmg + healthPercentDmg)

    return DamageLib.CalculateMagicalDamage(Player.AsAI, target, totalPercentDmg)
end

function CastSpell(letter, target)
    if not letter then
        return false
    end
    if not target then
        return false
    end

    if Menu.Get(letter .. "KS") then
        if letter == "Q" then
            if Brand.Q:IsInRange(target) then
                return Brand.Q:Cast(target)
            end
        end

        if letter == "W" then
            if Brand.W:IsInRange(target) then
                if Brand.W:Cast(target) then
                    return true
                end
            end
        end

        if letter == "E" then
            if Brand.E:IsInRange(target) then
                return Brand.E:Cast(target)
            end
        end
    else
        local amount = 0

        for i, v in ipairs(ObjectManager.GetNearby("ally", "heroes")) do
            if not v.IsMe then
                if v:Distance(target.Position) <= 600 then
                    amount = amount + 1
                end
            end
        end

        if amount == 0 then
            if letter == "Q" then
                if Brand.Q:IsInRange(target) then
                    return Brand.Q:Cast(target)
                end
            end

            if letter == "W" then
                if Brand.W:IsInRange(target) then
                    if Brand.W:Caste(target) then
                        return true
                    end
                end
            end

            if letter == "E" then
                if Brand.E:IsInRange(target) then
                    return Brand.E:Cast(target)
                end
            end
        end
    end
end

function GetPassiveDamage(target)
    local baseDmg = 10
    local dmgPerLevel = 10 * Player.Level
    local APDmg = Player.TotalAP * 0.2

    local totalDmg = baseDmg + dmgPerLevel + APDmg

    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

function doCombo()
    local Target = TS:GetTarget(Brand.Q.Range)

    for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
        if Brand.Q:IsInRange(v) then
            if Utils.HasBuff(v, "BrandAblaze") then
                Target = v
            end
        end
    end

    if Target then
        if Utils.IsInRange(Player.Position, Target.Position, 450, 600) and Brand.E:IsReady() then
            if Brand.Logic.Q(Target) then
                return true
            end
        end

        Target = TS:GetTarget(Brand.E.Range)

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Brand.E:IsInRange(v) then
                if Utils.HasBuff(v, "BrandAblaze") then
                    Target = v
                end
            end
        end

        if Brand.Logic.E(Target) then
            return true
        end

        Target = TS:GetTarget(Brand.Q.Range)

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Brand.Q:IsInRange(v) then
                if Utils.HasBuff(v, "BrandAblaze") then
                    Target = v
                end
            end
        end

        if Target then
            if Brand.Logic.Q(Target) then
                return true
            end
        end

        Target = TS:GetTarget(Brand.W.Range)

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Brand.W:IsInRange(v) then
                if Utils.HasBuff(v, "BrandAblaze") then
                    Target = v
                end
            end
        end

        if Target then
            if Brand.Logic.W(Target) then
                return true
            end
        end

        Target = TS:GetTarget(Brand.R.Range)

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Brand.R:IsInRange(v) then
                if Utils.HasBuff(v, "BrandAblaze") then
                    Target = v
                end
            end
        end

        if Target then
            if Brand.Logic.R(Target) then
                return true
            end
        end
    end
end

function doBurstCombo(Target)
    if not Target then
        return false
    end

    if Brand.E:IsReady() and Brand.Q:IsReady() then
        if Brand.Q:Cast(Target) then
            -- WARN("BURSTING NOW!!!")
            delay(
                100,
                function()
                    if Input.Cast(SpellSlots.E, Target) then
                        delay(
                            100,
                            function()
                                if Input.Cast(UsableSS.Flash.Slot, Target.Position) then
                                end
                            end
                        )
                    else
                    end
                end
            )
        else
        end
    end
end

-- Roburppey Lib
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

function Utils.SmartCheckbox(id, text)
    Menu.Checkbox(id, "", true)
    Menu.SameLine()
    Menu.ColoredText(text, Utils.GetMenuColor(id))
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

function Utils.CheckFlashSlot()
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

function Utils.CountMinionsInRangeOf(pos, range, team)
    local amount = 0
    for k, v in ipairs(ObjectManager.GetNearby(team, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            minion:Distance(pos) <= range
        then
            amount = amount + 1
        end
    end
    return amount
end

function Utils.GetMinionsInRangeOf(pos, range, team, pos2, range2)
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

function Utils.GetHeroesInRangeOf(pos, range, team, pos2, range2)
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

function Utils.GetClosestMinionTo(pos, team, list)
    -- INFO("GETTING CLOSEST MINION... ")

    local range = 9999
    local returnminion = nil

    if list then
        -- INFO("LIST WITH ... " .. #list .. " Minions")

        for k, v in ipairs(list) do
            local minion = v.AsMinion
            if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                minion:Distance(pos) <= range
            then
                returnminion = v
                range = minion:Distance(pos)
            end
        end
    else
        for a, b in ipairs(ObjectManager.GetNearby(team, "minions")) do
            local minion = v.AsMinion
            if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
                minion:Distance(pos) <= range
            then
                returnminion = b
                range = minion:Distance(pos)
            end
        end
    end

    if returnminion ~= nil then
        -- WARN("RETURNING MINION")
    end

    return returnminion
end

function Utils.GetClosestHeroTo(pos, team, list)
    -- INFO("GETTING CLOSEST hero... ")

    local range = 9999
    local returnHero = nil

    if list then
        -- INFO("LIST WITH ... " .. #list .. " heros")

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

-- Event Functions
function Brand.OnProcessSpell(Caster, SpellCast)
end

function Brand.OnUpdate()
end

function Brand.OnBuffGain(obj, buffInst)
end

function Brand.OnGapclose(source, dash)
    if true then
        if Utils.IsInRange(Player.Position, source.Position, 0, Brand.W.Range) then
            if Brand.W:IsReady() then
                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then
                        local pred = Brand.W:GetPrediction(source)
                        if pred and pred.HitChanceEnum >= Enums.HitChance.Dashing then
                            if Brand.W:Cast(pred.CastPosition) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function Brand.OnExtremePriority(lagFree)
end

function Brand.OnHighPriority(lagFree)
    if Player.IsDead then
        isComboing = false
    end

    if Utils.CheckFlashSlot() or UsableSS.Flash.Slot ~= nil then
        if Player:GetSpell(UsableSS.Flash.Slot).RemainingCooldown > 0 then
            isComboing = false
        end
    end

    if Menu.IsKeyPressed(string.byte("T")) then
        local Target = TS:GetTarget(1500)

        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Brand.Q:IsInRange(v) then
                if Utils.HasBuff(v, "BrandAblaze") then
                    Target = v
                end
            end
        end

        if Target then
            if Orbwalker.Orbwalk(Renderer.GetMousePos(), Target) then
                goto continue
            end

            --  Input.MoveTo(Renderer.GetMousePos())

            ::continue::
            if Utils.CheckFlashSlot() or UsableSS.Flash.Slot ~= nil then
                if Player:GetSpell(UsableSS.Flash.Slot).RemainingCooldown == 0 then
                    if Utils.IsInRange(Player.Position, Target.Position, 0, Brand.E.Range + 350) then
                        if lastBurstTime == nil then
                            lastBurstTime = Game.GetTime()
                            -- WARN("Running burst because its first time")
                            doBurstCombo(Target)
                        end

                        if Game.GetTime() - lastBurstTime > 0.25 then
                            lastBurstTime = Game.GetTime()
                            doBurstCombo(Target)
                        end
                    end
                elseif Player:GetSpell(UsableSS.Flash.Slot).RemainingCooldown > 0 then
                    doCombo()
                end
            end
        else
            Orbwalker.Orbwalk(Renderer.GetMousePos())
        end
    end
end

function Brand.OnCreateObject(obj, lagFree)
end

function Brand.OnTick(lagFree)
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Brand.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lagFree) then
            return true
        end
    end

    if Brand.Logic.Auto(lagFree) then
        return true
    end

    return true

    --[[


        --]]
end

function Brand.OnHeroImmobilized(Source, EndTime, IsStasis)
end

function Brand.OnPreAttack(args)
end

function Brand.OnPostAttack(target)
end

-- Drawings
function Brand.OnDrawDamage(target, dmgList)
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
    if Menu.Get("DmgDrawings.E") then
        table.insert(dmgList, GetEDmg(target))
    end
    if Menu.Get("DmgDrawings.R") then
        table.insert(dmgList, GetRDmg(target))
    end
    if Menu.Get("DmgDrawings.P") then
        table.insert(dmgList, GetPDmg(target))
    end
    if Menu.Get("DmgDrawings.P2") then
        table.insert(dmgList, GetP2Dmg(target))
    end
end

function Brand.OnDraw()
    local hideDraw = Menu.Get("RangeDrawHide")

    if Menu.Get("Drawings.Q") then
        if hideDraw then
            if Brand.Q:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Brand.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Brand.Q.Range, 30, 1, Menu.Get("Drawings.Q.Color"))
        end
    end
    if Menu.Get("Drawings.W") then
        if hideDraw then
            if Brand.W:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Brand.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Brand.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
        end
    end
    if Menu.Get("Drawings.E") then
        if hideDraw then
            if Brand.E:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Brand.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Brand.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
        end
    end
    if Menu.Get("Drawings.R") then
        if hideDraw then
            if Brand.R:IsReady() then
                Renderer.DrawCircle3D(Player.Position, Brand.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
            end
        else
            Renderer.DrawCircle3D(Player.Position, Brand.R.Range, 30, 1, Menu.Get("Drawings.R.Color"))
        end
    end
    if Menu.IsKeyPressed(string.byte("T")) then
        local Target = TS:GetTarget(2000)

        if Target then
            Renderer.DrawCircle3D(Target.Position, Brand.E.Range + 350, 30, 10, Menu.Get("Drawings.R.Color"))
            Renderer.DrawTextOnPlayer("Burst Mode Enabled", Menu.Get("Drawings.R.Color"))
            Renderer.DrawTextOnPlayer("Burst Range Indicator Is Being Drawn", Menu.Get("Drawings.R.Color"))
        end
    end
end

-- Spell Logic
function Brand.Logic.R(Target)
    local bounceEngage = Menu.Get("BounceEngage")

    if Menu.IsKeyPressed(1) then
        if not Target then
            return false
        end
        if not Brand.R:IsReady() then
            return false
        end

        return Brand.R:Cast(Target)
    end

    if not Menu.Get("UseR") then
        return false
    end

    if not Menu.Get("R" .. Target.CharName) then
        return false
    end

    if not Target then
        return false
    end

    if Brand.R:IsReady() then
        -- INFO("BRAND R IS READY")
        if Brand.R:IsInRange(Target) then
            -- INFO("TARGET IS IN RANGE")
            if Menu.Get("RBounce") then
                -- print("Enemy heroes ~> " .. Utils.CountEnemiesInRange(Target, 600) - 1)
                -- print("Enemy minions ~> " .. Utils.CountMinionsInRangeOf(Target.Position,600,"enemy"))
                -- print("Neutral minions ~> " .. Utils.CountMinionsInRangeOf(Target.Position,600,"neutral"))

                if Utils.CountEnemiesInRange(Target, 600) - 1 >= 1 or Player:Distance(Target.Position) <= 600 then
                    if Input.Cast(SpellSlots.R, Target) then
                        return true
                    end
                end
            else
                if Input.Cast(SpellSlots.R, Target) then
                    return true
                end
            end
        elseif not Brand.R:IsInRange(Target) then
            -- WARN("TARGET OUT OF RANGE")

            if bounceEngage then
                -- WARN("BOUNCE ENGAGE ON")

                local enemyMinionsInRangeOfTargetAndPlayer =
                Utils.GetMinionsInRangeOf(Target.Position, 300, "enemy", Player.Position, 750)

                -- WARN("FOUND " .. #enemyMinionsInRangeOfTargetAndPlayer .. " MINIONS IN RANGE")

                if #enemyMinionsInRangeOfTargetAndPlayer >= 1 and #enemyMinionsInRangeOfTargetAndPlayer < 3 then
                    local closestMinion =
                    Utils.GetClosestMinionTo(Player.Position, "enemy", enemyMinionsInRangeOfTargetAndPlayer)

                    if closestMinion ~= nil then
                        -- print(#enemyMinionsInRangeOfTargetAndPlayer)
                        return Input.Cast(SpellSlots.R, closestMinion)
                    end
                end

                local enemyHeroes = Utils.GetHeroesInRangeOf(Target.Position, 600, "enemy", Player.Position, 750)

                if #enemyHeroes >= 1 then
                    local closestHero = Utils.GetClosestHeroTo(Player.Position, "enemy", enemyHeroes)

                    if closestHero ~= nil then
                        return Input.Cast(SpellSlots.R, closestHero)
                    end
                end
            end
        end
    end
end

function Brand.Logic.Q(Target)
    if not Menu.Get("UseQ") then
        return false
    end

    if not Target then
        return false
    end

    if Brand.Q:IsReady() and Brand.Q:IsInRange(Target) then
        if Menu.Get("ForceQ") then
            if Utils.HasBuff(Target, "BrandAblaze") then
                pcall(
                    function()
                        if Brand.Q:CastOnHitChance(Target, Menu.Get("QHitChance") / 100) then
                            return true
                        end
                    end
                )
            end

            if Menu.Get("IgnoreFQCD") then
                if Player:GetSpell(SpellSlots.Q).RemainingCooldown > Menu.Get("IgnoreFQCDCount") and
                    Player:GetSpell(SpellSlots.E).RemainingCooldown > Menu.Get("IgnoreFQCDCount")
                then
                    if Brand.Q:CastOnHitChance(Target, Menu.Get("QHitChance") / 100) then
                        return true
                    end
                end
            end

            if Menu.Get("IgnoreFQWK") then
                if HealthPrediction.GetKillstealHealth(Target, 0.5, DamageTypes.Magical) <= GetQDmg(Target) then
                    if Brand.Q:CastOnHitChance(Target, Menu.Get("QHitChance") / 100) then
                        return true
                    end
                end
            end
        else
            if Brand.Q:CastOnHitChance(Target, Menu.Get("QHitChance") / 100) then
                return true
            end
        end
    end
end

function Brand.Logic.W(Target)
    if not Menu.Get("UseW") then
        return false
    end

    if not Target then
        return false
    end

    if Brand.W:IsReady() and Brand.W:IsInRange(Target) then
        return Brand.W:CastOnHitChance(Target, Menu.Get("WHitChance") / 100)
    end
end

function Brand.Logic.E(Target)
    if not Menu.Get("UseE") then
        return false
    end

    if not Target then
        return false
    end

    if Brand.E:IsReady() then
        if Utils.IsInRange(Player.Position, Target.Position, 0, Brand.E.Range) then
            if Brand.E:Cast(Target) then
                return true
            end
        end
    end
end

-- Orbwalker Logic
function Brand.Logic.Lasthit(lagFree)
end

function Brand.Logic.Flee(lagFree)
end

function Brand.Logic.Waveclear(lagFree)
    if Utils.IsInJungle() then
        for i, v in ipairs(Utils.NeutralMinionsInRange(Brand.E.Range)) do
            if Brand.E:IsReady() then
                if Brand.E:Cast(v) then
                    return true
                end
            end

            if Brand.Q:IsReady() then
                return Brand.Q:Cast(v)
            end
        end

        local bestPos, hitCount =
        Brand.W:GetBestCircularCastPos(Utils.NeutralMinionsInRange(Brand.W.Range), Brand.W.Radius)
        if bestPos and hitCount >= 1 then
            if Brand.W:IsReady() then
                if Brand.W:IsInRange(bestPos) then
                    Brand.W:Cast(bestPos)
                end
            end
        end
    else
        if Brand.Q:IsReady() then
            if Utils.EnabledAndMinimumMana("UseQWaveclear", "QWaveclearMana") then
                local bestPos2, hitCount2 = Brand.Q:GetBestLinearCastPos(Utils.EnemyMinionsInRange(Brand.Q.Range))
                if bestPos2 and hitCount2 >= Menu.Get("QWaveclearHitcount") then
                    return Brand.Q:Cast(bestPos2)
                end
            end
        end

        if Brand.E:IsReady() then
            if Utils.EnabledAndMinimumMana("UseEWaveclear", "EWaveclearMana") then
                local eMinions = Utils.GetMinionsInRangeOf(Player.Position, Brand.E.Range, "enemy")

                if #eMinions >= 1 then
                    local mostBurnMinion = eMinions[1]
                    local mostBurn = 0

                    for i, v in ipairs(eMinions) do
                        if Utils.HasBuff(v, "BrandAblaze") then
                            local bMinions = Utils.GetMinionsInRangeOf(v.Position, 580, "enemy")
                            if #bMinions >= Menu.Get("EWaveclearHitcount") then
                                if #bMinions > mostBurn then
                                    mostBurn = #bMinions
                                    mostBurnMinion = v
                                end
                            end
                        end
                    end

                    if mostBurn > 1 then
                        return Brand.E:Cast(mostBurnMinion)
                    end
                end
            end
        end

        local bestPos, hitCount =
        Brand.W:GetBestCircularCastPos(Utils.EnemyMinionsInRange(Brand.W.Range), Brand.W.Radius)
        if bestPos and hitCount >= 1 then
            if Brand.W:IsReady() then
                if Brand.W:IsInRange(bestPos) then
                    Brand.W:Cast(bestPos)
                end
            end
        end
    end
end

function Brand.Logic.Harass(lagFree)
    if lagFree == 3 or lagFree == 4 then
        if pcall(
            function()
                local Target = TS:GetTarget(Brand.Q.Range)

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                    if Brand.Q:IsInRange(v) then
                        if Utils.HasBuff(v, "BrandAblaze") then
                            Target = v
                        end
                    end
                end

                if Target then
                    if Utils.EnabledAndMinimumMana("UseQHarass", "QHarassMana") and
                        Utils.EnabledAndMinimumMana("UseEHarass", "EHarassMana")
                    then
                        if Utils.IsInRange(Player.Position, Target.Position, 450, 600) and Brand.E:IsReady() then
                            if Brand.Logic.Q(Target) then
                                return true
                            end
                        end
                    end

                    if Utils.EnabledAndMinimumMana("UseEHarass", "EHarassMana") then
                        Target = TS:GetTarget(Brand.E.Range)

                        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                            if Brand.E:IsInRange(v) then
                                if Utils.HasBuff(v, "BrandAblaze") then
                                    Target = v
                                end
                            end
                        end

                        if Brand.Logic.E(Target) then
                            return true
                        end
                    end

                    if Utils.EnabledAndMinimumMana("UseQHarass", "QHarassMana") then
                        Target = TS:GetTarget(Brand.Q.Range)

                        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                            if Brand.Q:IsInRange(v) then
                                if Utils.HasBuff(v, "BrandAblaze") then
                                    Target = v
                                end
                            end
                        end

                        if Target then
                            if Brand.Logic.Q(Target) then
                                return true
                            end
                        end
                    end

                    if Utils.EnabledAndMinimumMana("UseWHarass", "WHarassMana") then
                        Target = TS:GetTarget(Brand.W.Range)

                        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                            if Brand.W:IsInRange(v) then
                                if Utils.HasBuff(v, "BrandAblaze") then
                                    Target = v
                                end
                            end
                        end

                        if Target then
                            if Brand.Logic.W(Target) then
                                return true
                            end
                        end
                    end
                end
            end
        )
        then
            return true
        end
    end
end

function Brand.Logic.Combo(lagFree)
    if pcall(
        function()
            local Target = TS:GetForcedTarget() or TS:GetTarget(1500, true)

            for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                if Brand.Q:IsInRange(v) then
                    if Utils.HasBuff(v, "BrandAblaze") then
                        Target = v
                    end
                end
            end

            if Target then
                if Utils.IsInRange(Player.Position, Target.Position, 450, 600) and Brand.E:IsReady() then
                    if Brand.Logic.Q(Target) then
                        return true
                    end
                end

                Target = TS:GetForcedTarget() or TS:GetTarget(Brand.E.Range)

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                    if Brand.E:IsInRange(v) then
                        if Utils.HasBuff(v, "BrandAblaze") then
                            Target = v
                        end
                    end
                end

                if Brand.Logic.E(Target) then
                    return true
                end

                Target = TS:GetForcedTarget() or TS:GetTarget(Brand.Q.Range)

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                    if Brand.Q:IsInRange(v) then
                        if Utils.HasBuff(v, "BrandAblaze") then
                            Target = v
                        end
                    end
                end

                if Target then
                    if Brand.Logic.Q(Target) then
                        return true
                    end
                end

                Target = TS:GetForcedTarget() or TS:GetTarget(Brand.W.Range)

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                    if Brand.W:IsInRange(v) then
                        if Utils.HasBuff(v, "BrandAblaze") then
                            Target = v
                        end
                    end
                end

                if Target then
                    if pcall(
                        function()
                            Brand.Logic.W(Target)
                        end
                    )
                    then
                    else
                        -- WARN("W Logic Was Not Executed Propperly")
                    end
                end

                Target = TS:GetTarget(Brand.R.Range + 600)

                for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                    if Brand.R:IsInRange(v) then
                        if Utils.HasBuff(v, "BrandAblaze") then
                            Target = v
                        end
                    end
                end

                if Target then
                    if Menu.Get("R" .. Target.CharName .. "Kill") then
                        if GetRDmg(Target) >= Target.Health then
                            if Brand.Logic.R(Target) then
                                return true
                            end
                        end
                    end

                    if Utils.EnabledAndMinimumHealth(
                        "R" .. Target.CharName,
                        "R" .. Target.CharName .. "Health",
                        Target
                    )
                    then
                        if Brand.Logic.R(Target) then
                            return true
                        end
                    end
                end
            end
        end
    )
    then
        return true
    end
end

function Brand.Logic.Auto(lagFree)
    if pcall(
        function()
            if lagFree == 4 then
                if Utils.EnabledAndMinimumMana("AutoE", "EPokeMana") then
                    for i, v in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
                        if Utils.HasBuff(v, "BrandAblaze") then
                            for step, champ in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
                                if champ:Distance(v.Position) <= 600 then
                                    if Utils.IsInRange(Player.Position, v.Position, 0, Brand.E.Range) then
                                        return Brand.E:Cast(v)
                                    end
                                end
                            end
                        end
                    end
                end

                local enemies = ObjectManager.GetNearby("enemy", "heroes")

                for i, v in ipairs(enemies) do
                    if Menu.Get("Qkill") then
                        local canKill =
                        HealthPrediction.GetKillstealHealth(v, 0.5, DamageTypes.Magical) <=
                            GetQDmg(v) + GetPDmg(v)

                        if canKill then
                            CastSpell("Q", v)
                        end
                    end

                    if Menu.Get("Wkill") then
                        local canKill =
                        HealthPrediction.GetKillstealHealth(v, 0.5, DamageTypes.Magical) <=
                            GetWDmg(v) + GetPDmg(v)

                        if canKill then
                            -- print("w can kill")
                            CastSpell("W", v)
                        end
                    end

                    if Menu.Get("Ekill") then
                        local canKill =
                        HealthPrediction.GetKillstealHealth(v, 0.5, DamageTypes.Magical) <=
                            GetEDmg(v) + GetPDmg(v)

                        if canKill then
                            CastSpell("E", v)
                        end
                    end
                end
            end
        end
    )
    then
        return true
    else
        -- WARN("Auto Blaze Was Not Executed Propperly")
    end
end

-- Menu
function Brand.LoadMenu()
    Menu.RegisterMenu(
        "BigBrand",
        "BigBrand",
        function()
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
                    Menu.Text("1.1.0 - Cleared up Harass Menu and Logic")
                    Menu.Text("1.0.5 - Added Additional Options To [R]")
                end
            )
            Menu.Text("")
            Menu.Separator()
            Menu.Text("")
            Menu.NewTree(
                "BigHeroCombo",
                "Combo",
                function()
                    Menu.Text("")
                    Menu.ColoredText("Hold [T] For Q -> Flash -> E Burst Combo.", 0xEFC347FF, true)
                    Menu.Text("")
                    Menu.ColumnLayout(
                        "DrawMenu",
                        "DrawMenu",
                        2,
                        true,
                        function()
                            Menu.Separator()
                            Menu.Checkbox("UseQ", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Cast [Q]", Utils.GetMenuColor("UseQ"))
                            Menu.SameLine()

                            if Menu.Get("UseQ") then
                                Utils.SmartCheckbox("ForceQ", "Only Q Ablaze Enemies")

                                if Menu.Get("ForceQ") then
                                    Menu.Text("")
                                    Menu.ColoredText("Ignore Ablaze Check If:", 0xEFC347FF)
                                    Menu.Text("")
                                    Utils.SmartCheckbox("IgnoreFQCD", "[E] and [W] Are On CD >")
                                    Menu.SameLine()
                                    Menu.Slider("IgnoreFQCDCount", " Seconds", 2, 1, 3, 1)
                                    Utils.SmartCheckbox("IgnoreFQWK", "[Q] Can Kill")
                                end
                            end

                            Menu.NextColumn()
                            Menu.Slider("QHitChance", "HitChance %", 50, 1, 100, 1)
                            Menu.NextColumn()
                            Menu.Separator()
                            Menu.Checkbox("UseW", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Cast [W]", Utils.GetMenuColor("UseW"))
                            Menu.NextColumn()
                            Menu.Slider("WHitChance", "HitChance %", 75, 1, 100, 1)
                            Menu.NextColumn()
                            Menu.Separator()

                            Menu.Checkbox("UseE", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Cast [E]", Utils.GetMenuColor("UseE"))
                            Menu.NextColumn()
                            Menu.NextColumn()
                            Menu.Separator()

                            Menu.Checkbox("UseR", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Cast [R]", Utils.GetMenuColor("UseR"))
                            Menu.Text("")
                            Menu.Checkbox("RBounce", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Only Cast [R] If It Can Bounce", Utils.GetMenuColor("RBounce"))
                            Utils.SmartCheckbox("BounceEngage", "Allow Casting [R] On Minion To Engage")
                            Menu.NextColumn()

                            if Menu.Get("BounceEngage") then
                                Menu.Text("")

                                Menu.ColoredText("Bounce Options: ", 0xE3FFDF)
                                Menu.Dropdown(
                                    "ooga",
                                    " ",
                                    0,
                                    ({ "From Hero OR Minion -> Target", "From Hero -> Target" })
                                )
                            end
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
                                        Utils.SmartCheckbox("R" .. Name, "Use [R]")

                                        if Menu.Get("R" .. Name) then
                                            Utils.HealthSlider(
                                                "R" .. Name .. "Health",
                                                "Use [R] On " .. Name .. " When HP Below:",
                                                100
                                            )
                                            Utils.SmartCheckbox(
                                                "R" .. Name .. "Kill",
                                                "Ignore Health Check If [R] Can Kill"
                                            )
                                        end
                                    end
                                )
                            end
                        end
                    )
                    Menu.Text("")
                end
            )
            Utils.MenuDivider(0xFF901CFF, "-", nil)
            Menu.NewTree(
                "BigHeroHarass",
                "Harass",
                function()
                    Menu.Text("")
                    Menu.ColumnLayout(
                        "DrawMenu2",
                        "DrawMenu2",
                        2,
                        true,
                        function()
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
                            Menu.Text("")
                            Menu.NextColumn()
                            Menu.Text("")
                            Utils.SmartCheckbox("UseWHarass", "Cast [W]")
                            Menu.NextColumn()
                            Menu.Slider("WHitChanceHarass", "HitChance %", 45, 1, 100, 1)
                            Utils.ManaSlider("WHarassMana", "Min Mana", 50)
                            Menu.NextColumn()
                            Menu.Text("")
                        end
                    )
                end
            )
            Utils.MenuDivider(0xFF901CFF, "-", nil)
            Menu.NewTree(
                "BigHeroWaveclear",
                "Waveclear",
                function()
                    Menu.Text("")
                    Menu.ColumnLayout(
                        "DrawMenu223",
                        "DrawMenu223",
                        2,
                        true,
                        function()
                            Utils.SmartCheckbox("UseQWaveclear", "Cast [Q]")
                            Menu.NextColumn()
                            Utils.ManaSlider("QWaveclearMana", "Min Mana", 35)
                            Utils.HitCountSlider("QWaveclearHitcount", 3, 1, 6)
                            Menu.NextColumn()
                            Menu.Text("")
                            Utils.SmartCheckbox("UseWWaveclear", "Cast [W]")
                            Menu.NextColumn()
                            Menu.Text("")
                            Utils.ManaSlider("WWaveclearMana", "Min Mana", 35)
                            Utils.HitCountSlider("WWaveclearHitcount", 4, 1, 6)
                            Menu.NextColumn()
                            Utils.SmartCheckbox("UseEWaveclear", "Cast [E]")
                            Menu.NextColumn()
                            Menu.Text("")
                            Utils.ManaSlider("EWaveclearMana", "Min Mana", 35)
                            Utils.HitCountSlider("EWaveclearHitcount", 4, 1, 6)

                            Menu.NextColumn()
                        end
                    )
                end
            )
            Utils.MenuDivider(0xFF901CFF, "-", nil)
            Menu.NewTree(
                "Auto",
                "Auto",
                function()
                    Menu.Text("")
                    Menu.ColumnLayout(
                        "DrawMenu233232323",
                        "DrawMenu23232323",
                        2,
                        true,
                        function()
                            Utils.SmartCheckbox("AutoE", "Auto [E] Poke")
                            Menu.NextColumn()
                            Menu.Slider("EPokeMana", "Minimum Mana %", 45, 1, 100, 1)
                        end
                    )
                    Menu.Separator()
                    Menu.ColumnLayout(
                        "DrawMenu23232323",
                        "DrawMenu232323",
                        2,
                        true,
                        function()
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
                            Menu.Checkbox("Wkill", "", true)
                            Menu.SameLine()
                            Menu.ColoredText("Automatically Cast [W] To Kill", Utils.GetMenuColor("Wkill"))
                            Menu.NextColumn()
                            if Menu.Get("Wkill") then
                                Menu.Checkbox("WKS", "", false)
                                Menu.SameLine()
                                Menu.ColoredText("Enable KS", Utils.GetMenuColor("WKS"))
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
                        end
                    )
                    Menu.Text("")
                end
            )
            Utils.MenuDivider(0xFF901CFF, "-", nil)
            Menu.NewTree(
                "Drawings",
                "Drawings",
                function()
                    Menu.ColumnLayout(
                        "DrawMenu3",
                        "DrawMenu2",
                        2,
                        true,
                        function()
                            Menu.Text("")
                            Menu.ColoredText("Range Drawings", 0xE3FFDF)
                            Menu.Text("")
                            Utils.SmartCheckbox("RangeDrawHide", "Hide Drawings Of Spells On CD")
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
                            Utils.SmartCheckbox("DmgDrawings.W", "Draw [Q] Dmg")
                            Utils.SmartCheckbox("DmgDrawings.E", "Draw [E] Dmg")
                            Utils.SmartCheckbox("DmgDrawings.R", "Draw [R] Dmg")
                            Menu.SameLine()
                            Menu.Slider("RBounceDmgDraw", "Amount Of Bounces", 3, 1, 3, 1)
                            Menu.Text("")
                            Utils.SmartCheckbox("DmgDrawings.P", "Draw Passive Dmg")
                            Utils.SmartCheckbox("DmgDrawings.P2", "Draw Passive Explosion Dmg")
                            Menu.Text("")

                            Utils.SmartCheckbox("DmgDrawings.Ludens", "Draw [Ludens] Dmg")

                            Menu.Text("")
                            Menu.NextColumn()
                        end
                    )
                end
            )
        end
    )
end

-- OnLoad
function OnLoad()
    INFO("Big Brand Version " .. ScriptVersion .. " loaded.")
    INFO("For Bugs and Requests Please Contact Roburppey")
    INFO("Replies usually within 24 hours")

    Brand.LoadMenu()
    for EventName, EventId in pairs(Events) do
        if Brand[EventName] then
            EventManager.RegisterCallback(EventId, Brand[EventName])
        end
    end

    return true
end
