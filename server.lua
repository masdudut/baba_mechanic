-- qbx_mechitems/server.lua (FINAL - ox_inventory compatible + 3D me nearby)

local function getPlayerJobName(source)
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            return Player.PlayerData.job.name
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            return Player.PlayerData.job.name
        end
    end

    return nil
end

local function isAllowedMechanic(source)
    local job = getPlayerJobName(source)
    return job and Config.AllowedJobs and Config.AllowedJobs[job] == true
end

local function isNearAnyWorkshopZone(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local pcoords = GetEntityCoords(ped)
    local radius = Config.ServerWorkshopRadius or 35.0

    for _, zone in ipairs(Config.WorkshopZones or {}) do
        if #(pcoords - zone.coords) <= radius then
            return true
        end
    end

    return false
end

-- Dipanggil client setelah progress sukses
RegisterNetEvent('qbx_mechitems:server:consumeItem', function(itemName)
    local src = source
    if type(itemName) ~= 'string' then return end

    if itemName == 'enginekit' or itemName == 'bodykit' then
        if not isAllowedMechanic(src) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Hanya mechanic yang bisa menggunakan item ini.' })
            return
        end
    end

    if itemName == 'bodykit' then
        if not isNearAnyWorkshopZone(src) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'BodyKit hanya bisa digunakan di zona bengkel.' })
            return
        end
    end

    local itemCount = exports.ox_inventory:GetItemCount(src, itemName)
    if not itemCount or itemCount < 1 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Item tidak ditemukan di inventory.' })
        return
    end

    exports.ox_inventory:RemoveItem(src, itemName, 1)
end)

-- 3D /me style text yang terlihat player sekitar
RegisterNetEvent('qbx_mechitems:server:meNearby', function(text, radius, duration)
    local src = source
    if type(text) ~= 'string' then return end

    radius = tonumber(radius) or 15.0
    duration = tonumber(duration) or 5000

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end
    local srcCoords = GetEntityCoords(srcPed)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                if #(coords - srcCoords) <= radius then
                    TriggerClientEvent('qbx_mechitems:client:showMe3D', pid, src, text, duration)
                end
            end
        end
    end
end)
