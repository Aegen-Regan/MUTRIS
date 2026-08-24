-- ================================================================
-- FILE: core/editor_config.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS ENGINE: DATA-DRIVEN EDITOR CONFIGURATION
-- Defines presets for matrices, AI profiles, and match rules
-- ============================================================================
local EditorConfig = {}

EditorConfig.presets = {
    {
        name = "Classic Versus 1v1",
        description = "Standard 10x40 matrix duel against a normal AI.",
        mode = "versus",
        boards = {
            { x = 220, y = 120, type = "human", cols = 10, rows = 40, ai_profile = nil },
            { x = 820, y = 120, type = "bot",   cols = 10, rows = 40, ai_profile = "normal" }
        }
    },
    {
        name = "Tiny Matrix Blitz",
        description = "Intense combat in a claustrophobic 6x24 grid.",
        mode = "versus",
        boards = {
            { x = 300, y = 120, type = "human", cols = 6, rows = 24, ai_profile = nil },
            { x = 700, y = 120, type = "bot",   cols = 6, rows = 24, ai_profile = "aggressive" }
        }
    },
    {
        name = "Gigantic Boss Raid",
        description = "Face a massive 20x40 boss matrix.",
        mode = "boss_hunt",
        boards = {
            { x = 120, y = 120, type = "human", cols = 10, rows = 40, ai_profile = nil },
            { x = 600, y = 120, type = "bot",   cols = 20, rows = 40, ai_profile = "boss_colossus" }
        }
    },
    {
        name = "Multi-Bot Deathmatch (1v2)",
        description = "Survival against two distinct AI variants.",
        mode = "gauntlet",
        boards = {
            { x = 100, y = 120, type = "human", cols = 10, rows = 40, ai_profile = nil },
            { x = 500, y = 120, type = "bot",   cols = 10, rows = 40, ai_profile = "normal" },
            { x = 900, y = 120, type = "bot",   cols = 10, rows = 40, ai_profile = "erratic" }
        }
    }
}

EditorConfig.ai_profiles = {
    normal = {
        base_delay = 0.4,
        min_delay = 0.1,
        error_rate = 0.05,
        target_pps = 1.5,
        name = "Standard Bot"
    },
    aggressive = {
        base_delay = 0.2,
        min_delay = 0.05,
        error_rate = 0.02,
        target_pps = 3.0,
        name = "Blitz Bot"
    },
    erratic = {
        base_delay = 0.5,
        min_delay = 0.0,
        error_rate = 0.25,
        target_pps = 2.0,
        name = "Chaos Bot"
    },
    boss_colossus = {
        base_delay = 0.3,
        min_delay = 0.1,
        error_rate = 0.01,
        target_pps = 2.5,
        name = "Colossus AI"
    }
}

return EditorConfig
