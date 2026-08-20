---@diagnostic disable: undefined-global
local SettingsManager = {}

SettingsManager.settings = {
    das = 0.094,       -- DAS en segundos (94 ms)
    arr = 0.008,       -- ARR en segundos (8 ms)
    sfx_vol = 1.0,     -- Volumen SFX (0.0 a 1.0)
    bgm_vol = 0.85     -- Volumen BGM (0.0 a 1.0)
}

local function serializeJSON(t)
    local s = "{\n"
    for k, v in pairs(t) do
        s = s .. '  "' .. tostring(k) .. '": ' .. tostring(v) .. ",\n"
    end
    s = s:sub(1, -3) .. "\n}"
    return s
end

local function parseSimpleJSON(str)
    local t = {}
    for k, v in str:gmatch('"([%w_]+)":%s*([%d%.]+)') do
        t[k] = tonumber(v)
    end
    return t
end

function SettingsManager.init()
    if love.filesystem.getInfo("settings.json") then
        local contents = love.filesystem.read("settings.json")
        if contents then
            local data = parseSimpleJSON(contents)
            if data.das then SettingsManager.settings.das = data.das end
            if data.arr then SettingsManager.settings.arr = data.arr end
            if data.sfx_vol then SettingsManager.settings.sfx_vol = data.sfx_vol end
            if data.bgm_vol then SettingsManager.settings.bgm_vol = data.bgm_vol end
        end
    end
end

function SettingsManager.save()
    love.filesystem.write("settings.json", serializeJSON(SettingsManager.settings))
end

return SettingsManager