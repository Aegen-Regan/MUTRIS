-- ================================================================
-- FILE: core/plugin_manager.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: PLUG & PLAY EXTENSION LOADER
-- Scans 'plugins/', registers hooks into EventBus, supports live Hot-Reloading
-- ============================================================================
local PluginManager = {}
local EventBus = require "core.event_bus"

local active_plugins = {}
local plugin_count = 0
local MAX_PLUGINS = 64

for i = 1, MAX_PLUGINS do
    active_plugins[i] = false
end

local function scanDirectory(dir)
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local full_path = dir .. "/" .. item
        local info = love.filesystem.getInfo(full_path)
        if info then
            if info.type == "directory" then
                scanDirectory(full_path)
            elseif info.type == "file" and item:match("%.lua$") then
                local mod_path = full_path:gsub("%.lua$", ""):gsub("/", ".")
                PluginManager.loadPlugin(mod_path)
            end
        end
    end
end

function PluginManager.init()
    EventBus.init()
    plugin_count = 0
    for i = 1, MAX_PLUGINS do active_plugins[i] = false end

    if not love.filesystem.getInfo("plugins") then
        love.filesystem.createDirectory("plugins")
        love.filesystem.createDirectory("plugins/anomalies")
        love.filesystem.createDirectory("plugins/custom_modes")
        love.filesystem.createDirectory("plugins/blights")
    end

    scanDirectory("plugins")
end

function PluginManager.loadPlugin(mod_path)
    package.loaded[mod_path] = nil
    local ok, plugin = pcall(require, mod_path)

    if ok and type(plugin) == "table" and plugin_count < MAX_PLUGINS then
        plugin_count = plugin_count + 1
        active_plugins[plugin_count] = plugin

        if plugin.init then
            pcall(plugin.init, EventBus)
        end

        if plugin.onBeat then EventBus.on(EventBus.ON_BEAT, plugin.onBeat) end
        if plugin.onPieceLock then EventBus.on(EventBus.ON_PIECE_LOCK, plugin.onPieceLock) end
        if plugin.onLineClear then EventBus.on(EventBus.ON_LINE_CLEAR, plugin.onLineClear) end
        if plugin.onParry then EventBus.on(EventBus.ON_PARRY, plugin.onParry) end
        if plugin.onZoneEnter then EventBus.on(EventBus.ON_ZONE_ENTER, plugin.onZoneEnter) end
        if plugin.onZoneExit then EventBus.on(EventBus.ON_ZONE_EXIT, plugin.onZoneExit) end
        if plugin.onBoardDeath then EventBus.on(EventBus.ON_BOARD_DEATH, plugin.onBoardDeath) end
        if plugin.onMatchRestart then EventBus.on(EventBus.ON_MATCH_RESTART, plugin.onMatchRestart) end
    end
end

function PluginManager.reloadAll()
    PluginManager.init()
    EventBus.emit(EventBus.ON_PLUGIN_RELOAD, plugin_count)
end

function PluginManager.update(dt)
    for i = 1, plugin_count do
        local p = active_plugins[i]
        if p and p.update then
            p.update(dt)
        end
    end
end

function PluginManager.draw()
    for i = 1, plugin_count do
        local p = active_plugins[i]
        if p and p.draw then
            p.draw()
        end
    end
end

function PluginManager.getCount()
    return plugin_count
end

return PluginManager