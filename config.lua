Config = {}

-- Job yang diizinkan pakai EngineKit & BodyKit
Config.AllowedJobs = {
    mechanic = true, -- default mechanic
    -- kalau job name kamu beda, tambahkan di sini:
    -- bennys = true
}

-- Zona bengkel untuk BodyKit (ubah sesuai bengkelmu)
Config.WorkshopZones = {
    {
        name = 'bengkel_1',
        coords = vector3(-339.5, -136.9, 39.0),
        size = vector3(20.0, 20.0, 6.0),
        rotation = 0.0,
    },
}

-- Validasi server: radius dari pusat zona (dibuat longgar biar nggak false reject)
Config.ServerWorkshopRadius = 35.0

-- BodyKit: berapa nambah body health per pemakaian
Config.BodyKitAdd = 400.0

-- EngineKit: minimal bukaan hood (0.0 - 1.0)
Config.MinHoodOpenRatio = 0.15

-- Durasi progress
Config.Durations = {
    washing     = 8000,
    engineCheck = 7000,
    engineRepair= 14000,
    bodyCheck   = 7000,
    bodyRepair  = 16000,
}


-- WashingKit prop (sponge)
Config.SpongeProp = 'prop_sponge_01'
