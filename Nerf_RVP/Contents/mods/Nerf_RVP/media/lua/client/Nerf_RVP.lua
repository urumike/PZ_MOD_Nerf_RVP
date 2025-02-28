-- Nerf_RVP Modified Code with SandboxVars

function ImpactCheckInit()
    DebugLog.log("Nerf_RVP Loaded!")
end

-- SandboxVars.NerfRVP が存在しない場合のデフォルト値
local function GetExtraDamageFactor(skill)
    local factor0 = 1.2  -- スキル0時の乗数（デフォルト：1.2＝20%増）
    local factor10 = 1.1 -- スキル10時の乗数（デフォルト：1.1＝10%増）
    if SandboxVars.NerfRVP then
        factor0 = SandboxVars.NerfRVP.FactorAtSkill0 or factor0
        factor10 = SandboxVars.NerfRVP.FactorAtSkill10 or factor10
    end
    -- 線形補間
    return factor0 - ((factor0 - factor10) / 10.0) * skill
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
        RemoveStatusTable(player)
    else
        if modData.VehicleImpactTable[0] == nil then
            BuildVehicleStatusTable(player, veh)
            DebugLog.log("Vehicle status table built.")
        end
        CheckPartChanges(player, veh)
    end
end

function RemoveStatusTable(player)
    local modData = player:getModData()
    if modData and type(modData) == "table" then
        modData.VehicleImpactTable = {}
        DebugLog.log("VehicleImpactTable removed.")
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
    local skill = player:getPerkLevel(Perks.VehicleDurability)
    local modData = player:getModData()
    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        local knownHP = modData.VehicleImpactTable[i]
        if (not part:getInventoryItem()) and (part:getTable("install")) and (knownHP ~= -1) then
            modData.VehicleImpactTable[i] = -1
        else
            local partHP = part:getCondition()
            if (knownHP ~= partHP) and (knownHP ~= -1) then
                local damage = knownHP - partHP -- 元の耐久度低下分（正の値）
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
        tostring(part:getId()), partHP, damage, extraDamage, newCondition))
    return extraDamage
end

Events.OnGameStart.Add(ImpactCheckInit)
Events.OnPlayerUpdate.Add(CheckVehicle)
