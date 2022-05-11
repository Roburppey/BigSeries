--[[
    BigJinx
]]
if Player.CharName ~= "Jinx" then
    return false
end

module("BJinx", package.seeall, log.setup)
clean.module("BJinx", package.seeall, log.setup)

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
local Vector = Geometry.Vector
local Renderer = CoreEx.Renderer
local tick = 1
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing",
    "Immobile" }
local ComboModeStrings = { "[Q] -> [E] -> [W]", "[E] -> [Q] -> [W]", "[E] -> [W] -> [Q]" }
local Player = ObjectManager.Player.AsHero
local isFishBones = not Player:GetBuff("JinxQ")
local ScriptVersion = "1.3.4"
local middle = Vector(7500, 53, 7362)
local ScriptLastUpdate = "April 10. 2022"

CoreEx.AutoUpdate("https://raw.githubusercontent.com/Roburppey/BigSeries/main/BigJinx.lua", ScriptVersion)

-- Globals
local Jinx = {}
local Utils = {}

Jinx.TargetSelector = nil
Jinx.Logic = {}

-- Spells
Jinx.Q = SpellLib.Active({
    Slot = SpellSlots.Q,
    Type = "Active"
})
Jinx.W = SpellLib.Skillshot({
    Slot = SpellSlots.W,
    Range = 1400,
    Speed = 3300,
    Delay = 0.6,
    Radius = 60,
    Type = "Linear",
    UseHitbox = true,
    Collisions = {
        Heroes = true,
        Minions = true,
        WindWall = true
    }
})
Jinx.E = SpellLib.Skillshot({
    Slot = SpellSlots.E,
    Range = 900,
    Speed = 1750,
    Delay = 0.9,
    Radius = 115,
    Type = "Circular",
    UseHitbox = false,
    Collisions = {
        WindWall = true
    }
})
Jinx.R = SpellLib.Skillshot({
    Slot = SpellSlots.R,
    Range = math.huge,
    Speed = 1700,
    Delay = 0.6,
    Radius = 140,
    Type = "Linear",
    UseHitbox = true,
    Collisions = {
        Heroes = true,
        WindWall = true
    }
})

-- Functions

function GetRDmg(enemy, distance, health)
    local dmgDist = math.floor(math.floor(distance) / 100)
    local rLevel = Jinx.R:GetLevel()
    local baseDmg = ({ 250, 400, 550 })[rLevel] + (1.5 * Player.BonusAD)
    local dmg = ({ 0.25, 0.3, 0.35 })[rLevel] * (enemy.MaxHealth - health)
    if distance >= 1500 then
        dmg = dmg + baseDmg
    else
        dmg = dmg + (((10 + (6 * dmgDist)) * baseDmg) / 100)
    end
    return DamageLib.CalculatePhysicalDamage(Player, enemy, dmg)
end

function CanKill(enemy)
    local distanceToHit = Player:Distance(enemy.Position)
    local timeToHit = Jinx.R.Delay + distanceToHit / Jinx.R.Speed
    local healthPredicted = { HealthPrediction.GetKillstealHealth(enemy, timeToHit) }
    local dmg = GetRDmg(enemy, distanceToHit, healthPredicted[1])
    return (healthPredicted[1] > 0) and (dmg > healthPredicted[1])
end

function getWDmg(Target)
    if not Jinx.W:IsLearned() then
        return 0
    end

    if not Jinx.W:IsReady() then
        return 0
    end

    return DamageLib.CalculatePhysicalDamage(Player, Target, (10 + (Jinx.W:GetLevel() - 1) * 50) + Player.TotalAD * 1.6)
end

function HasRFC()
    for key, item in pairs(Player.Items) do
        if item and (item.ItemId == 3094) then
            local statikBuff = Player:GetBuff("itemstatikshankcharge")
            if statikBuff then
                if statikBuff.Count == 100 then
                    return true
                end
            end
        end
    end
    return false
end

function getQDmgOnMinion(Target)
end

function getQDmg(Target)
end

function executeCombo(mode)
end

function GetRealPowPowRange()
    local static = 0
    if HasRFC() then
        static = 150
    end

    return Player.BoundingRadius + 25 + (Jinx.Q:GetLevel() * 25) + 600 + static
end

function adjustWSpeed()
    local asm = Player.AttackSpeedMod

    if asm < 1.25 then
        Jinx.W.Delay = 0.6
    end
    if asm >= 1.25 and asm < 1.5 then
        Jinx.W.Delay = 0.58
    end
    if asm >= 1.5 and asm < 1.75 then
        Jinx.W.Delay = 0.54
    end
    if asm >= 1.75 and asm < 2 then
        Jinx.W.Delay = 0.52
    end
    if asm >= 2 and asm < 2.25 then
        Jinx.W.Delay = 0.50
    end
    if asm >= 2.25 and asm < 2.5 then
        Jinx.W.Delay = 0.48
    end
    if asm >= 2.5 and asm < 2.75 then
        Jinx.W.Delay = 0.46
    end
    if asm >= 2.75 and asm < 3 then
        Jinx.W.Delay = 0.44
    end
    if asm >= 3 and asm < 3.25 then
        Jinx.W.Delay = 0.42
    end
    if asm >= 3.25 and asm < 3.5 then
        Jinx.W.Delay = 0.40
    end

    return
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

function Utils.TargetsInRange(Target, Range, Team, Type)
    -- return target in range
    local Objects = ObjectManager.GetNearby(Team, Type)
    local Array = {}
    local Index = 0

    for _, Object in ipairs(Objects) do
        if Object and Object ~= Target then
            Object = Object.AsAI
            if Utils.IsValidTarget(Object) then
                local Distance = Target:Distance(Object.Position)
                if Distance <= Range then
                    Index = Index + 1
                end
            end
        end
    end

    return Index
end

function Utils.HasBuff(target, buff)
    for i, v in pairs(target.Buffs) do
        if v.Name == buff then
            return true
        end
    end

    return false
end

function Utils.EnabledAndMinimumMana(useID, manaID)
    local power = 10 ^ 2
    return MGet(useID) and Player.Mana >= math.floor(Player.MaxMana / 100 * MGet(manaID) * power) / power
end

function Jinx.OnHeroImmobilized(Source, EndTime, IsStasis)
    if Source.IsEnemy then
        if Source.IsHero then
            if EndTime - Game.GetTime() < 0.65 then
                return
            end

            if Player.Position:Distance(Source.Position) <= Jinx.E.Range then
                if Jinx.E:IsReady() then
                    if Jinx.E:CastOnHitChance(Source, Menu.Get("Combo.E.HitChance") / 100) then
                        -- print(EndTime - Game.GetTime())
                        INFO("Casting E from Immobilized")

                        return true
                    end
                end
            end
        end
    end
end

function Jinx.OnExtremePriority(lagFree)
    if Menu.Get("SemiR") then
        if Jinx.R:IsReady() then
            local enemyHeroes = ObjectManager.Get("enemy", "heroes")

            local closestEnemy = nil

            for i, v in pairs(enemyHeroes) do
                if closestEnemy == nil then
                    closestEnemy = v
                end

                if Renderer.GetMousePos():Distance(v.Position) < Renderer.GetMousePos():Distance(closestEnemy.Position) or
                    closestEnemy == nil then
                    closestEnemy = v
                end
            end

            if closestEnemy == nil then
                return false
            end

            if Menu.Get("IgnoreSemiChance") then
                return Input.Cast(SpellSlots.R, closestEnemy.Position)
            end

            return Jinx.R:CastOnHitChance(closestEnemy, Menu.Get("Combo.R.HitChance") / 100)
        end
    end

    if Menu.Get("RKS") then
        local enemies = ObjectManager.Get("enemy", "heroes")

        -- RKS
        for i, v in pairs(enemies) do
            if Menu.Get("R" .. v.CharName) then
                Jinx.Logic.R(v)
            end
        end
    end
end

function Jinx.OnCreateObject(obj, lagFree)
end

---@param Target GameObject
function Jinx.OnPostAttack(Target)
    if Target.IsMinion or Target.IsTurret or Target.IsNexus or Target.IsInhibitor then
        return
    end



    -- This switches from Rocketlauncher to Minigun if the enemy is close enough
    if Player:Distance(Target) <= Player.BoundingRadius + 525 then
        if MGet("QFinisher") then
            if (MGet("QFinisherSlider") / 100) * Target.MaxHealth < Target.Health then
                if Player:GetBuff("JinxQ") then
                    -- WARN("switched from Rocketlauncher to Minigun, enemy is close enough")
                    Input.Cast(SpellSlots.Q)
                end
            end
        else
            if Player:GetBuff("JinxQ") then
                Input.Cast(SpellSlots.Q)
            end
        end
    end

    -- This switches from Minigun to Rocketlauncher if enemy has less than 10% of health
    if MGet("QFinisher") then
        if Player:Distance(Target) <= Player.BoundingRadius + Target.BoundingRadius + 525 then
            if Target.Health <= Target.MaxHealth * (MGet("QFinisherSlider") / 100) then
                if not Player:GetBuff("JinxQ") then
                    Input.Cast(SpellSlots.Q)
                end
            end
        end
    end

end

function Jinx.OnPreAttack(Target)

end

function Jinx.OnGapclose(source, dash)
    if Menu.Get("AutoEGap") then
        if Utils.IsInRange(Player.Position, source.Position, 0, Jinx.E.Range) then
            if Jinx.E:IsReady() then
                local Hero = source.AsHero

                if not Hero.IsDead then
                    if Hero.IsEnemy then
                        local pred = Jinx.E:GetPrediction(source)
                        if pred and pred.HitChanceEnum >= Enums.HitChance.Dashing then
                            if Jinx.E:Cast(pred.CastPosition) then
                                INFO("Casting E from ON Gapclose")
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    if Menu.Get("AutoWGap") then
        if Utils.IsInRange(Player.Position, source.Position, 0, Jinx.W.Range) then
            if not Utils.IsInRange(Player.Position, source.Position, 0, GetRealPowPowRange()) then
                if Jinx.W:IsReady() then
                    local Hero = source.AsHero

                    if not Hero.IsDead then
                        if Hero.IsEnemy then
                            local pred = Jinx.W:GetPrediction(source)
                            if pred and pred.HitChanceEnum >= Enums.HitChance.Dashing then
                                if Jinx.W:Cast(pred.CastPosition) then
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

function Jinx.Logic.W()
    if Jinx.W:IsReady() then
        adjustWSpeed()

        local target = TS:GetTarget(Jinx.W.Range, true)
        if Utils.IsValidTarget(target) then
            if Utils.HasBuff(Player, "BlindingDart") then
                return Jinx.W:CastOnHitChance(target, Menu.Get("Combo.W.HitChance") / 100)
            end

            if Utils.TargetsInRange(Player, 400, "enemy", "heroes") == 0 then
                if (Player:Distance(target) > GetRealPowPowRange(target)) then
                    return Jinx.W:CastOnHitChance(target, Menu.Get("Combo.W.HitChance") / 100)
                end
            end
        end
    end

    return false
end

function Jinx.Logic.Q()
    local Target = TS:GetTarget(GetRealPowPowRange())
    if not Jinx.Q:IsReady() then
        return
    end

    if not Target then
        if Player:GetBuff("JinxQ") then
            Input.Cast(SpellSlots.Q)
        end
    end

    if not Utils.IsValidTarget(Target) then
        return
    end

    local fishBonesBuff = Player:GetBuff("jinxqramp")

    -- enable Q if enemy out of minigun range but in rocket range
    if Player:Distance(Target) > Player.BoundingRadius + 525 then
        if Player:Distance(Target) <= GetRealPowPowRange(Target) then
            if not Player:GetBuff("JinxQ") then
                Input.Cast(SpellSlots.Q)
            end
        end
    end

    -- enable Q if enemy in aoe range
    if Utils.EnabledAndMinimumMana("Aoe.Q", "Combo.Q.Mana") then

        for i, v in pairs(ObjectManager.Get("enemy", "heroes")) do
            if v:Distance(Target.Position) > 5 and v:Distance(Target.Position) < 250 then
                if not Player:GetBuff("JinxQ") then
                    -- WARN("Casting Q from AOE")
                    Input.Cast(SpellSlots.Q)
                end
            end
        end
    end


    return true
end

function Jinx.Logic.E()
    if Jinx.E:IsReady() then
        local t = TS:GetTarget(Jinx.E.Range, true)

        if not Utils.IsValidTarget(t) then
            return
        end

        return Jinx.E:CastOnHitChance(t, Menu.Get("Combo.E.HitChance") / 100)
    end

    return false
end

function Jinx.Logic.R(Target)
    if not Target then
        return
    end
    if not Target.IsTargetable then
        return
    end
    if not Target.IsAlive then
        return
    end

    if Jinx.R:IsReady() then
        if Menu.Get("RMateCheck") then
            for i, v in pairs(ObjectManager.Get("ally", "heroes")) do
                if v:Distance(Target) < 500 then
                    return
                end
            end
        end

        if Player:Distance(Target) < Menu.Get("R.Max.Range") and Player:Distance(Target) >= Menu.Get("R.Min.Range") then
            local distance = Player:EdgeDistance(Target.Position)
            Jinx.R.Speed = distance > 1300 and (1300 * 1700 + ((distance - 1300) * 2200)) / distance or 1700

            if CanKill(Target) then
                Jinx.R:CastOnHitChance(Target, Menu.Get("Combo.R.HitChance") / 100)
            end
        end
    end

    return false
end

function Jinx.Logic.Waveclear(lagFree)
    if Jinx.Q:IsReady() then
        if Menu.IsKeyPressed(1) then
            if not Player:GetBuff("JinxQ") then
                return Input.Cast(SpellSlots.Q)
            end
        else
            if Player:GetBuff("JinxQ") then
                return Input.Cast(SpellSlots.Q)
            end
        end
    end
end

function Jinx.Logic.Harass()
    if Menu.Get("Harass.W.Use") then
        if Menu.Get("Harass.W.Mana") < (Player.ManaPercent * 100) then
            if Jinx.Logic.W() then
                return true
            end
        end
    end

    if Menu.Get("Harass.Q.Use") then
        if Menu.Get("Harass.Q.Mana") < (Player.ManaPercent * 100) then
            Jinx.Logic.Q()
        end
    end
end

function Jinx.Logic.Combo(lagFree)
    local Target = TS:GetTarget(16000, true)

    if not Target then
        return false
    end

    if Menu.Get("RC" .. Target.CharName) then
        if Jinx.Logic.R(Target) then
            return true
        end
    end

    if MGet("Combo.E.Use") then
        if Jinx.Logic.E() then
            return true
        end
    end

    if MGet("Combo.W.Use") then
        if Jinx.Logic.W() then
            return true
        end
    end

    if Jinx.Logic.Q() then
        return true
    end

    return false
end

function Jinx.Logic.Auto(lag)

    if lag == 1 then

        tick = tick + 1


        if tick == 5 then

            if MGet("EOnTp") then

                for i, minion in ipairs(ObjectManager.GetNearby("enemy", "minions")) do
                    for k, buff in pairs(minion.Buffs) do
                        if buff.Name == "teleport_target" then
                            if Jinx.E:IsReady() then
                                if Player:Distance(minion.Position) <= Jinx.E.Range then
                                    if Jinx.E:Cast(minion.Position) then
                                    end
                                end
                            end
                        end
                    end
                end
            end

            tick = 0

        end



    end





    local enemies = ObjectManager.Get("enemy", "heroes")

    for key, obj in pairs(enemies) do
        local enemy = obj
        if enemy.IsTeleporting then
            local teleport = enemy.ActiveSpell
            if teleport and teleport.Target then
                local teleportPosition = teleport.Target.Position
                if teleportPosition:Distance(Player) < Jinx.E.Range then
                    return Jinx.E:Cast(teleportPosition)
                end
            end
        else
            local zhonya = enemy:GetBuff("zhonyasringshield")
            if zhonya then
                if enemy.Position:Distance(Player) < Jinx.E.Range then
                    return Jinx.E:Cast(enemy.Position)
                end
            end
        end
    end

    -- Panic E
    if Menu.Get("Panic.E.Use") then
        for i, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
            if Player.Position:Distance(v.Position) < 200 then
                if not v.IsHero then
                    return
                end
                if v.IsMinion then
                    return
                end
                if not v.IsEnemy then
                    return
                end
                if not v.IsTargetable then
                    return
                end
                if not v.IsAlive then
                    return
                end

                if Jinx.E:IsReady() then
                    if Input.Cast(SpellSlots.E, Player.Location) then
                        INFO("Casting E from Panic")
                        return true
                    end
                end
            end
        end
    end
end

function Jinx.OnInterruptibleSpell(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)
    if Menu.Get("AutoEInterrupt") then
        if Danger < 3 or CanMoveDuringChannel or not Source.IsEnemy then
            return false
        end

        if SpellCast.IsBasicAttack then
            return false
        end

        if Jinx.E:IsReady() then
            if Jinx.E:CastOnHitChance(Source, 0.7) then
                INFO("Casting E from On Interrupt")
                return true
            end
        end
    end
end

local RBMenu = {}
---@return function
function MGet(id)
    return Menu.Get(id)
end

function RBMenu.Divider(color, sym, am)
    local DivColor = color or 0xEFC347FF
    local string = ""
    local amount = 166 or am
    local symbol = sym or "="

    for i = 1, 166 do
        string = string .. symbol
    end

    return Menu.ColoredText(string, DivColor, true)
end

function RBMenu.Description()
    --[[
  ____ _____ _____  __      _______ 
 |  _ \_   _/ ____| \ \    / /_   _|
 | |_) || || |  __   \ \  / /  | |  
 |  _ < | || | |_ |   \ \/ /   | |  
 | |_) || || |__| |    \  /   _| |_ 
 |____/_____\_____|     \/   |_____|
                                    
                                    
--]]
    Menu.Text("  ____ _____ _____  __      _______ ", true)
    Menu.Text(" |  _ \\_   _/ ____| \\ \\    / /_   _|", true)
    Menu.Text(" | |_) || || |  __   \\ \\  / /  | |  ", true)
    Menu.Text(" |  _ < | || | |_ |   \\ \\/ /   | |  ", true)
    Menu.Text(" | |_) || || |__| |    \\  /   _| |_ ", true)
    Menu.Text(" |____/_____\\_____|     \\/   |_____|", true)
    Menu.Text("                                     ", true)

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

            Menu.Text("1.0.1 - Menu Fixes")
            Menu.Text("1.0.0 - Initial Release")
        end
    )
    Menu.Separator()
    Menu.Text("")
end

function RBMenu.Combo()
    Menu.NewTree(
        "BigHeroCombo",
        "Combo",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu",
                "DrawMenu",
                2,
                true,
                function()
                    RB.SmartCheckbox("QCombo", "Use [Q]")
                    Menu.NextColumn()
                    Menu.Slider("QHitChance", "HitChance %", 35, 1, 100, 1)
                    Menu.NextColumn()
                    -- RB.SmartCheckbox("UseW", "Use [W]", true)
                    RB.SmartCheckbox("ECombo", "Use [E]")
                    RB.SmartCheckbox("RCombo", "Use [R]")
                    Menu.ColoredText("R Uses Whitelist, Forced Targt Is Also Possible", 0xEFC347FF)
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
                                RB.SmartCheckbox("R" .. Name, "Use [R]", true)

                                if MGet("R" .. Name) then
                                    RB.HealthSlider("R" .. Name .. "Health", "Minimum Health To Use [R]", 100)
                                end
                            end
                        )
                    end
                end
            )
            Menu.Text("")
        end
    )
end

function RBMenu.Harass()
    Menu.NewTree(
        "BigHeroHarass",
        "Harass",
        function()
            RB.SmartCheckbox("QHarass", "Use [Q]")
            -- Minimum enemies hit Slider
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("QHarass")) then
                RB.ManaSlider("QMana", "[Q] Min Mana", 50)
            end
            Menu.Text("")
            Menu.NextColumn()
            RB.SmartCheckbox("EHarass", "Use [E]")
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("EHarass")) then
                RB.ManaSlider("EMana", "[E] Min Mana", 50)
            end
        end
    )
end

function RBMenu.Waveclear()
    Menu.NewTree(
        "BigHeroWaveclear",
        "Waveclear",
        function()
            RB.SmartCheckbox("UseQWaveclear", "Use [Q]")
            Menu.Text("")
            -- Minimum enemies hit Slider
            Menu.NextColumn()
            if (MGet("UseQWaveclear")) then
                Menu.ColoredText("[Q] Min Hitcount", 0xEFC347FF)
                Menu.Slider("QHCSlider", " ", 2, 1, 5, 1)
                -- Q Mana Slider
                RB.ManaSlider("QManaSlider", "[Q] Min Mana", 50)
            end
            Menu.Text("")
            Menu.NextColumn()
            RB.SmartCheckbox("UseEWaveclear", "Use [E]")
            Menu.Text("")
            Menu.NextColumn()
            if (MGet("UseEWaveclear")) then
                RB.ManaSlider("EManaSlider", "[E] Min Mana", 50)
            end

            Menu.Text("")
            Menu.Text("")
        end
    )
end

function RBMenu.Jungleclear()
    Menu.NewTree(
        "BigHeroJungleclear",
        "Jungleclear",
        function()
            Menu.Text("")

            RB.SmartCheckbox("UseQJungleclear", "Use [Q]")
            RB.SmartCheckbox("UseEJungleclear", "Use [E]")
            Menu.NextColumn()

            Menu.Text("")
            Menu.Text("")
        end
    )
end

function RBMenu.Killsteal()
    Menu.NewTree(
        "BigHeroKillsteal",
        "Killsteal",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu5",
                "DrawMenu5",
                2,
                true,
                function()
                    RB.SmartCheckbox("UseQKillsteal", "Use [Q]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseWKillsteal", "Use [W]")
                    RB.SmartCheckbox("UseEKillsteal", "Use [E]")
                    RB.SmartCheckbox("UseRKillsteal", "Use [R]")
                end
            )
            Menu.Text("")
            Menu.Text("")
        end
    )
end

function RBMenu.Draw()
    Menu.NewTree(
        "BigHeroDraw",
        "Draw",
        function()
            Menu.NewTree(
                "DrawQMenu",
                "[Q] Drawings",
                function()
                    RB.SmartCheckbox("DrawQ", "Draw [Q] Range")
                    Menu.ColorPicker("QColor", "", 0xFF4646FF)
                    RB.SmartCheckbox("DrawQDamage", "Draw [Q] Damage")
                end
            )
            Menu.NewTree(
                "DrawWMenu",
                "[W] Drawings",
                function()
                    RB.SmartCheckbox("DrawWDamage", "Draw [W] Damage")
                end
            )
            Menu.NewTree(
                "DrawEMenu",
                "[E] Drawings",
                function()
                    RB.SmartCheckbox("DrawEDamage", "Draw [E] Damage")
                end
            )
            Menu.NewTree(
                "DrawRMenu",
                "[R] Drawings",
                function()
                    RB.SmartCheckbox("DrawR", "Draw [R] Range")
                    Menu.ColorPicker("RColor", "", 0xFF4646FF)
                    RB.SmartCheckbox("DrawRDamage", "Draw [R] Damage")
                end
            )
        end
    )
end

function RBMenu.Misc()
    Menu.NewTree(
        "BigHeroMisc",
        "Misc",
        function()
            Menu.Text("")
            Menu.Text("")
            Menu.ColumnLayout(
                "DrawMenu7",
                "DrawMenu7",
                2,
                true,
                function()
                    RB.SmartCheckbox("UseQMisc", "Use [Q]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseWMisc", "Use [W]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseEMisc", "Use [E]")
                    Menu.NextColumn()
                    RB.SmartCheckbox("UseRMisc", "Use [R]")
                end
            )
            Menu.Text("")
            Menu.Text("")
        end
    )
end

function RBMenu.SliderWithTitle(id, title, defaultValue, minimumValue, maximumValue, stepValue, color)

    Menu.ColoredText(title, color or 0xEFC347FF)
    Menu.Slider(id, "", defaultValue, minimumValue, maximumValue, stepValue)

end

function Jinx.LoadMenu()
    Menu.RegisterMenu("BigJinx", "BigJinx", function()
        Menu.Text("Author: Roburppey", true)
        Menu.Text("Version: " .. ScriptVersion, true)
        Menu.Text("Last Update: " .. ScriptLastUpdate, true)
        Menu.Separator()
        Menu.Text("")
        Menu.ColoredText("-- Hold Left Mouse Button to farm with Rockets :)", 0xE3FFDF)
        Menu.ColoredText("-- Script uses default Baseult, please adjust settings in Awareness", 0xE3FFDF)

        Menu.Text("")
        Menu.Keybind("SemiR", "Semi [R] on closest enemy to mouse", string.byte("T"), false, false, false)
        Menu.Checkbox("IgnoreSemiChance", "Ignore HitChance", false)
        Menu.Text("")
        Menu.Text("")
        Menu.NewTree("Changelog", "Changelog", function()
            Menu.Text("1.3.3 - Fixed Bug Introduced With Last Update")
            Menu.Text("1.3.2 - Smoother Q Logic, More Customization")
            Menu.Text("1.3.1 - Improved performance of [E] on TP")
            Menu.Text("1.3.0 - Added More options to Combo [Q]")
            Menu.Text("1.2.8 - Excluded Turrets, Inhibs and Nexus from [Q] Logic")
        end)
        Menu.Separator()
        Menu.Text("")
        RBMenu.Divider(0xFF901CFF, "-", nil)
        Menu.NewTree("BigHeroCombo", "Combo", function()
            Menu.Text("")
            Menu.NewTree("QSettings", "[Q] Settings", function()
                Menu.Text("")
                Menu.Checkbox("QFinisher", "Use Rockets If Target HP is Below X HP")
                if MGet("QFinisher") then
                    RBMenu.SliderWithTitle("QFinisherSlider", "Target HP Percent", 5, 1, 100, 1)
                    Menu.Text("")
                end
                Menu.Checkbox("Aoe.Q", "Use Rockets if they would hit multiple enemies", false)
                Menu.Text("Minimum Percentage Mana To Use Rockets")
                Menu.Slider("Combo.Q.Mana", "Mana %", 50, 0, 100)
                Menu.Text("")
            end)

            Menu.NewTree("ESettings", "[E] Settings", function()
                Menu.Text("")
                Menu.ColumnLayout("DrawMenu2", "DrawMenu2", 2, true, function()
                    Menu.Checkbox("Combo.E.Use", "Cast [E]", true)
                    Menu.NextColumn()
                    Menu.ColoredText("Hitchance:", 0xE3FFDF)
                    Menu.Slider("Combo.E.HitChance", "%", 70, 1, 100, 1)
                end)
                Menu.Text("")
            end)

            Menu.NewTree("WSettings", "[W] Settings", function()
                Menu.Text("")
                Menu.ColumnLayout("DrawMenu", "DrawMenu", 2, true, function()
                    Menu.Checkbox("Combo.W.Use", "Cast [W]", true)
                    Menu.Checkbox("Combo.W.OutOfRange", "Cast [W] Only when out of rocket range", true)
                    Menu.NextColumn()
                    Menu.ColoredText("Hitchance:", 0xE3FFDF)
                    Menu.Slider("Combo.W.HitChance", "%", 60, 1, 100, 1)
                    Menu.Text("")
                end)
            end)

            Menu.NewTree("RSettings", "[R] Settings", function()
                Menu.Text("")
                Menu.ColumnLayout("DrawMenu33", "DrawMenu33", 2, true, function()
                    Menu.Checkbox("Combo.R.Use", "Cast [R]", true)
                    Menu.NextColumn()
                    Menu.ColoredText("Hitchance:", 0xE3FFDF)
                    Menu.Slider("Combo.R.HitChance", "%", 50, 1, 100, 1)
                    Menu.NextColumn()
                    Menu.Text("[R] Minimum Range To Cast")
                    Menu.NextColumn()
                    Menu.Slider("R.Min.Range", " ", 1000, 100, 2300, 100)
                    Menu.NextColumn()
                    Menu.Text("[R] Maximum Range To Cast")
                    Menu.NextColumn()

                    Menu.Slider("R.Max.Range", " ", 6000, Menu.Get("R.Min.Range") + 1000, 15000, 100)
                end)
                Menu.Text("")

                Menu.Checkbox("R.Min.Preview", "Preview Min [R] Range", false)
                Menu.NextColumn()
                Menu.NextColumn()
                Menu.Checkbox("RMateCheck", "Don't ult an enemy if a team mate is right next to them", true)
                Menu.Text("")
                Menu.NewTree("RComboWhitelist", "[R] Whitelist", function()
                    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                        local Name = Object.AsHero.CharName
                        Menu.Checkbox("RC" .. Name, "Use [R] for " .. Name, true)
                    end
                end)
                Menu.Text("")
            end)

            Menu.NextColumn()
            Menu.Text("")
        end)
        RBMenu.Divider(0xFF901CFF, "-", nil)
        Menu.NewTree("BigHeroHarass", "Harass [C]", function()
            Menu.Text("")

            Menu.NewTree("QHarass", "[Q] Settings", function()
                Menu.Checkbox("Harass.Q.Use", "Cast [Q]", true)
                Menu.Text("Minimum percent mana to use [Q]")
                Menu.Slider("Harass.Q.Mana", "Mana %", 50, 0, 100)
            end)

            Menu.NewTree("WHarass", "[W] Settings", function()
                Menu.Checkbox("Harass.W.Use", "Cast [W]", true)
                Menu.Dropdown("Harass.W.HitChance", "HitChance", HitChance.High, HitChanceStrings)
                Menu.Text("Minimum percent mana to use [W]")
                Menu.Slider("Harass.W.Mana", "Mana %", 50, 0, 100)
            end)

            Menu.NextColumn()
            Menu.Text("")
        end)
        RBMenu.Divider(0xFF901CFF, "-", nil)
        Menu.NewTree("Auto Settings", "Auto Settings", function()
            Menu.Text("")
            Menu.Checkbox("Panic.E.Use", "Panic cast [E] on self if enemy in melee range", true)
            Menu.Text("")
            Menu.Checkbox("AutoWGap", "Auto [W] on gapclose", true)
            Menu.Checkbox("AutoEGap", "Auto [E] on gapclose", true)

            Menu.Checkbox("AutoEInterrupt", "Auto [E] on Interruptable Spells", true)
            Menu.Checkbox("EOnTp", "Auto [E] on minions that enemies are teleporting onto", true)
            Menu.Text("")
            Menu.Checkbox("RKS", "Auto [R] KS", true)
            Menu.NewTree("RKSWhitelist", "RKS Whitelist", function()
                for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("R" .. Name, "Use [R] for " .. Name, true)
                end
            end)
            Menu.Text("")
            Menu.Separator()
        end)
        RBMenu.Divider(0xFF901CFF, "-", nil)
        Menu.NewTree("Drawings", "Range Drawings", function()
            Menu.Checkbox("Drawings.E", "Draw [E] Range", false)
            Menu.ColorPicker("Drawings.E.Color", "", 0xEF476FFF)
            Menu.Checkbox("Drawings.W", "Draw [W] Range", false)
            Menu.ColorPicker("Drawings.W.Color", "", 0xEF476FFF)
        end)
        RBMenu.Divider(0xFF901CFF, "-", nil)
        Menu.NewTree("DmgDrawings", "Damage Drawings", function()
            Menu.Checkbox("DmgDrawings.W", "Draw [W] Dmg", true)

            Menu.Checkbox("DmgDrawings.R", "Draw [R] Dmg", true)
        end)
        RBMenu.Divider(0xFF901CFF, "-", nil)
    end)
end

function Jinx.OnDrawDamage(target, dmgList)
    if not target then
        return false
    end

    if Menu.Get("DmgDrawings.W") then
        if Jinx.W:IsReady() then
            table.insert(dmgList, getWDmg(target))
        end
    end

    if Menu.Get("DmgDrawings.R") then
        if Jinx.R:IsReady() then
            table.insert(dmgList, GetRDmg(target, Player:Distance(target.Position), target.Health))
        end
    end
end

function Jinx.OnDraw()
    if Menu.Get("R.Min.Preview") then
        local qLength = Player.Position:Distance(middle)
        local qEndPos = Player.Position:Extended(middle, qLength - qLength + Menu.Get("R.Min.Range"))

        Renderer.DrawFilledRect3D(Player.Position, qEndPos, Jinx.R.Radius * 2, 0xEF476FFF)
    end

    if Menu.Get("Drawings.E") then
        Renderer.DrawCircle3D(Player.Position, Jinx.E.Range, 30, 1, Menu.Get("Drawings.E.Color"))
    end

    if Menu.Get("Drawings.W") then
        Renderer.DrawCircle3D(Player.Position, Jinx.W.Range, 30, 1, Menu.Get("Drawings.W.Color"))
    end
end

function Jinx.OnTick(lag)
    if not Utils.IsGameAvailable() then
        return false
    end

    local OrbwalkerMode = Orbwalker.GetMode()

    local OrbwalkerLogic = Jinx.Logic[OrbwalkerMode]

    if OrbwalkerLogic then
        -- Calculate spell data

        -- Do logic
        if OrbwalkerLogic(lag) then
            return true
        end
    end

    if Jinx.Logic.Auto(lag) then
        return true
    end

    return false
end

function OnLoad()
    INFO("Welcome to BigJinx, enjoy your stay")
    Jinx.LoadMenu()

    for EventName, EventId in pairs(Events) do
        if Jinx[EventName] then
            EventManager.RegisterCallback(EventId, Jinx[EventName])
        end
    end

    return true
end
