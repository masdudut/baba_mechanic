-- qbx_mechitems/client.lua (FINAL - 2-stage engine/body + 3D /me nearby)

local inWorkshop = false
local workshopZones = {}
local activeMe = {}

local function getClosestVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return lib.getClosestVehicle(coords, 3.0, false)
end

local function progress(label, duration, anim)
    return lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim
    })
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 4000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return hash
end

local function spawnAndAttachPropToHand(propModel)
    local ped = PlayerPedId()
    local hash = loadModel(propModel)
    if not hash then return nil end

    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    local bone = GetPedBoneIndex(ped, 57005) -- right hand

    AttachEntityToEntity(
        obj, ped, bone,
        0.12, 0.02, -0.02,
        90.0, 180.0, 0.0,
        true, true, false, true, 1, true
    )

    return obj
end

local function deleteEntitySafe(ent)
    if ent and DoesEntityExist(ent) then
        DetachEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function faceEntityHard(ped, entity)
    local p = GetEntityCoords(ped)
    local e = GetEntityCoords(entity)
    local heading = GetHeadingFromVector_2d(e.x - p.x, e.y - p.y)
    SetEntityHeading(ped, heading)
end

-- ====== 3D /me style text ======
local function drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

RegisterNetEvent('qbx_mechitems:client:showMe3D', function(srcServerId, text, duration)
    local endAt = GetGameTimer() + (tonumber(duration) or 5000)
    activeMe[srcServerId] = { text = text, endAt = endAt }

    CreateThread(function()
        while activeMe[srcServerId] and GetGameTimer() < activeMe[srcServerId].endAt do
            Wait(0)
            local playerIdx = GetPlayerFromServerId(srcServerId)
            if playerIdx ~= -1 then
                local ped = GetPlayerPed(playerIdx)
                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    drawText3D(coords.x, coords.y, coords.z + 1.0, ("* %s *"):format(activeMe[srcServerId].text))
                end
            end
        end
        activeMe[srcServerId] = nil
    end)
end)

-- helper untuk broadcast /me text
local function meNearby(text, duration)
    TriggerServerEvent('qbx_mechitems:server:meNearby', text, 15.0, duration)
end

-- ====== WORKSHOP ZONES (BodyKit only) ======
CreateThread(function()
    for _, z in ipairs(Config.WorkshopZones or {}) do
        local zone = lib.zones.box({
            coords = z.coords,
            size = z.size,
            rotation = z.rotation or 0.0,
            debug = false,
            onEnter = function()
                inWorkshop = true
            end,
            onExit = function()
                inWorkshop = false
                local ped = PlayerPedId()
                local pcoords = GetEntityCoords(ped)
                for _, other in ipairs(workshopZones) do
                    if other:contains(pcoords) then
                        inWorkshop = true
                        break
                    end
                end
            end
        })

        workshopZones[#workshopZones + 1] = zone
    end
end)

-- ====== DURATIONS (lebih lama) ======
-- Kamu bisa override dari config.lua:
-- Config.Durations = { washing=7000, engineCheck=6000, engineRepair=12000, bodyCheck=6000, bodyRepair=14000 }
local D = Config.Durations or {}
local WASHING_DUR     = D.washing     or 7000
local ENGINE_CHECK_D  = D.engineCheck or 6000
local ENGINE_REPAIR_D = D.engineRepair or 12000
local BODY_CHECK_D    = D.bodyCheck   or 6000
local BODY_REPAIR_D   = D.bodyRepair  or 14000

local FIX_ANIM = { dict = 'mini@repair', clip = 'fixing_a_ped' }

-- ====== WASHING KIT ======
RegisterNetEvent('qbx_mechitems:client:useWashingKit', function()
    local veh = getClosestVehicle()
    if not veh or veh == 0 then
        return lib.notify({ type = 'error', description = 'Tidak ada kendaraan di dekatmu.' })
    end

    meNearby('sedang mencuci kendaraan', WASHING_DUR)

    local sponge = spawnAndAttachPropToHand(Config.SpongeProp or 'prop_sponge_01')

    local ok = progress('Mencuci kendaraan...', WASHING_DUR, {
        dict = 'amb@world_human_maid_clean@base',
        clip = 'base'
    })

    deleteEntitySafe(sponge)
    if not ok then return end

    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)

    TriggerServerEvent('qbx_mechitems:server:consumeItem', 'washingkit')
    lib.notify({ type = 'success', description = 'Kendaraan berhasil dibersihkan.' })
end)

-- ====== ENGINE KIT (2 tahap) ======
RegisterNetEvent('qbx_mechitems:client:useEngineKit', function()
    local veh = getClosestVehicle()
    if not veh or veh == 0 then
        return lib.notify({ type = 'error', description = 'Tidak ada kendaraan di dekatmu.' })
    end

    local hoodRatio = GetVehicleDoorAngleRatio(veh, 4)
    if hoodRatio < (Config.MinHoodOpenRatio or 0.15) then
        return lib.notify({ type = 'error', description = 'Buka kap mesin (hood) dulu sebelum service mesin.' })
    end

    local ped = PlayerPedId()
    ClearPedTasks(ped)
    faceEntityHard(ped, veh)

    -- Tahap 1: cek kondisi mesin
    meNearby('sedang memeriksa kondisi mesin', ENGINE_CHECK_D)
    local ok1 = progress('Memeriksa kondisi mesin...', ENGINE_CHECK_D, FIX_ANIM)
    if not ok1 then return end

    -- Tahap 2: perbaiki mesin
    meNearby('sedang memperbaiki mesin kendaraan', ENGINE_REPAIR_D)
    local ok2 = progress('Memperbaiki mesin kendaraan...', ENGINE_REPAIR_D, FIX_ANIM)
    if not ok2 then return end

    SetVehicleEngineHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)

    TriggerServerEvent('qbx_mechitems:server:consumeItem', 'enginekit')
    lib.notify({ type = 'success', description = 'Mesin kendaraan berhasil diperbaiki.' })
end)

-- ====== BODY KIT (2 tahap + body like new) ======
RegisterNetEvent('qbx_mechitems:client:useBodyKit', function()
    if not inWorkshop then
        return lib.notify({ type = 'error', description = 'BodyKit hanya bisa digunakan di zona bengkel.' })
    end

    local veh = getClosestVehicle()
    if not veh or veh == 0 then
        return lib.notify({ type = 'error', description = 'Tidak ada kendaraan di dekatmu.' })
    end

    local ped = PlayerPedId()
    ClearPedTasks(ped)
    faceEntityHard(ped, veh)

    -- simpan kondisi mesin supaya bodykit fokus body (tidak “ngangkat” mesin)
    local oldEngine = GetVehicleEngineHealth(veh)
    local oldTank = GetVehiclePetrolTankHealth(veh)

    -- Tahap 1: cek kondisi body
    meNearby('sedang memeriksa kondisi body kendaraan', BODY_CHECK_D)
    local ok1 = progress('Memeriksa kondisi body mobil...', BODY_CHECK_D, FIX_ANIM)
    if not ok1 then return end

    -- Tahap 2: perbaiki body penyok + gores (like new)
    meNearby('sedang memperbaiki body yang penyok', BODY_REPAIR_D)
    local ok2 = progress('Repairinf BodyWorks...', BODY_REPAIR_D, FIX_ANIM)
    if not ok2 then return end

    -- Hilangkan penyok/deformasi
    SetVehicleDeformationFixed(veh)

    -- Hilangkan damage visual (gores/lecet) => tampilan rapi lagi
    SetVehicleFixed(veh)

    -- Kembalikan mesin ke kondisi sebelumnya
    SetVehicleEngineHealth(veh, oldEngine)
    SetVehiclePetrolTankHealth(veh, oldTank)

    -- Body full (sesuai “seperti baru”)
    SetVehicleBodyHealth(veh, 1000.0)

    TriggerServerEvent('qbx_mechitems:server:consumeItem', 'bodykit')
    lib.notify({ type = 'success', description = 'Body kendaraan kembali bagus seperti baru.' })
end)
