-- MKAVD.lua

function ImpactCheckInit()
    DebugLog.log("MKAVD Loaded!")

    -- DEBUG: サンドボックスオプションの確認
    DebugLog.log("MKAVD - DamageMultiplierAtSkill0: " .. tostring(SandboxVars.MKAVD_DamageMultiplierAtSkill0))
    DebugLog.log("MKAVD - DamageMultiplierAtSkill10: " .. tostring(SandboxVars.MKAVD_DamageMultiplierAtSkill10))
end

local function GetExtraDamageFactor(skill)
    local factor0 = SandboxVars.MKAVD_DamageMultiplierAtSkill0;
    local factor10 = SandboxVars.MKAVD_DamageMultiplierAtSkill10;

    return factor0 - ((factor0 - factor10) / 10.0) * skill;
end

function CheckVehicle(player, vehicle, args)
    if (not player) or (not instanceof(player, "IsoPlayer")) then
        return
    end

    local modData = player:getModData()
    if (not modData) or (type(modData) ~= "table") then
        return
    end

    if (not modData.VehicleImpactTable) or (type(modData.VehicleImpactTable) ~= "table") then
        modData.VehicleImpactTable = {}
        DebugLog.log("VehicleImpactTable initialized for player")
    end

    local veh = player:getVehicle()
    if (veh == nil) or (not veh:isDriver(player)) then
        if modData.VehicleImpactTable then
            modData.VehicleImpactTable = nil
            DebugLog.log("VehicleImpactTable removed.")
        end
    else
        if modData.VehicleImpactTable[0] == nil then
            BuildVehicleStatusTable(player, veh)
            DebugLog.log("Vehicle status table built.")
        end
        CheckPartChanges(player, veh)
    end
end

function BuildVehicleStatusTable(player, vehicle)
    local modData = player:getModData()
    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        if (not part:getInventoryItem()) and (part:getTable("install")) then
            modData.VehicleImpactTable[i] = -1
        else
            modData.VehicleImpactTable[i] = part:getCondition()
        end
    end
end

function CheckPartChanges(player, vehicle)
    local skill = player:getPerkLevel(Perks.VehicleHandling)
    local modData = player:getModData()
    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        local knownHP = modData.VehicleImpactTable[i]
        if (not part:getInventoryItem()) and (part:getTable("install")) and (knownHP ~= nil) then
            modData.VehicleImpactTable[i] = -1
        else
            local partHP = part:getCondition()
            if (knownHP ~= partHP) and (knownHP ~= nil) then
                local damage = knownHP - partHP
                if damage > 0 then
                    IncreaseTakenDamage(skill, part, partHP, damage)
                end
                modData.VehicleImpactTable[i] = partHP
            end
        end
    end
end

function IncreaseTakenDamage(skill, part, partHP, damage)
    local factor = GetExtraDamageFactor(skill)
    local extraDamage = damage * (factor - 1)
    local newCondition = partHP - extraDamage
    newCondition = math.max(newCondition, 0)
    part:setCondition(newCondition)
    DebugLog.log(string.format("Increased damage on part %s: oldHP=%.2f, damage=%.2f, extra=%.2f, newHP=%.2f",
        tostring(part:getPartType()), partHP, damage, extraDamage, newCondition))
    return extraDamage
end

Events.OnGameStart.Add(ImpactCheckInit)
Events.OnPlayerUpdate.Add(CheckVehicle)
