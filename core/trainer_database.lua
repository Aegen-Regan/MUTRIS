-- ================================================================
-- FILE: core/trainer_database.lua
-- ================================================================
---@diagnostic disable: undefined-global
-- ============================================================================
-- MUTRIS TRAINER LAB: DETERMINISTIC OPENING DATABASE
-- Pieces: 1:I, 2:J, 3:L, 4:O, 5:S, 6:T, 7:Z
-- ============================================================================
local TrainerDatabase = {}

TrainerDatabase.OPENERS = {
    {
        id = "tki_flat",
        tag = "01",
        name = "TKI 3 — FLAT TOP",
        difficulty = "INTERMEDIO",
        reward = "TSD +4 LINEAS",
        desc = "Apertura estandar de torneo. Ataque rapido de T-Spin Double con base plana ultra-estable.",
        queue = { 2, 7, 3, 5, 4, 1, 6 }, -- J, Z, L, S, O, I, T
        steps = {
            { piece = 2, rot = 1, x = 1, y = 39, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 7, rot = 1, x = 1, y = 38, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 3, rot = 1, x = 8, y = 39, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
            { piece = 5, rot = 1, x = 7, y = 38, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
            { piece = 4, rot = 1, x = 4, y = 39, keys = {"[ < IZQ ]", "[ SPACE ]"} },
            { piece = 1, rot = 2, x = 8, y = 37, keys = {"[ >> DAS DER ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 6, rot = 3, x = 3, y = 37, keys = {"[ < IZQ ]", "[ ROTAR 180 ]", "[ TSD CLEAR ]"} },
        }
    },
    {
        id = "dt_cannon",
        tag = "02",
        name = "DT CANNON (Doble-Triple)",
        difficulty = "AVANZADO",
        reward = "TSD + TST (+11 LINEAS)",
        desc = "Construye una torre asimetrica que detona un TSD seguido de un devastador T-Spin Triple.",
        queue = { 4, 2, 3, 7, 5, 1, 6 }, -- O, J, L, Z, S, I, T
        steps = {
            { piece = 4, rot = 1, x = 1, y = 39, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 2, rot = 2, x = 3, y = 38, keys = {"[ < IZQ ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 3, rot = 4, x = 4, y = 38, keys = {"[ ROTAR D ]", "[ SPACE ]"} },
            { piece = 7, rot = 2, x = 3, y = 36, keys = {"[ < IZQ ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 5, rot = 2, x = 4, y = 36, keys = {"[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 1, rot = 1, x = 7, y = 40, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
            { piece = 6, rot = 1, x = 8, y = 39, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
        }
    },
    {
        id = "pco",
        tag = "03",
        name = "PERFECT CLEAR (PCO)",
        difficulty = "EXPERTO",
        reward = "PC (+10 LINEAS PURAS)",
        desc = "Limpia la grilla por completo en la 1ra bolsa. Inflige daño masivo instantaneo.",
        queue = { 1, 2, 7, 3, 5, 4, 6 }, -- I, J, Z, L, S, O, T
        steps = {
            { piece = 1, rot = 1, x = 4, y = 40, keys = {"[ CENTRO ]", "[ SPACE ]"} },
            { piece = 2, rot = 1, x = 1, y = 39, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 7, rot = 1, x = 2, y = 38, keys = {"[ < IZQ ]", "[ SPACE ]"} },
            { piece = 3, rot = 1, x = 8, y = 39, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
            { piece = 5, rot = 1, x = 7, y = 38, keys = {"[ > DER ]", "[ SPACE ]"} },
            { piece = 4, rot = 1, x = 5, y = 38, keys = {"[ > DER ]", "[ SPACE ]"} },
            { piece = 6, rot = 1, x = 4, y = 37, keys = {"[ CENTRO ]", "[ PERFECT CLEAR ]"} },
        }
    },
    {
        id = "mko",
        tag = "04",
        name = "MKO STACKING TSD",
        difficulty = "INTERMEDIO",
        reward = "TSD + DOWNSTACK",
        desc = "Apertura solida y flexible con transicion limpia hacia el combate medio.",
        queue = { 2, 4, 3, 7, 5, 1, 6 }, -- J, O, L, Z, S, I, T
        steps = {
            { piece = 2, rot = 1, x = 1, y = 39, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 4, rot = 1, x = 4, y = 39, keys = {"[ < IZQ ]", "[ SPACE ]"} },
            { piece = 3, rot = 2, x = 6, y = 38, keys = {"[ > DER ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 7, rot = 1, x = 7, y = 40, keys = {"[ >> DAS DER ]", "[ SPACE ]"} },
            { piece = 5, rot = 1, x = 1, y = 37, keys = {"[ << DAS IZQ ]", "[ SPACE ]"} },
            { piece = 1, rot = 2, x = 8, y = 37, keys = {"[ >> DAS DER ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 6, rot = 3, x = 3, y = 37, keys = {"[ < IZQ ]", "[ ROTAR 180 ]", "[ TSD CLEAR ]"} },
        }
    },
    {
        id = "stickspin",
        tag = "05",
        name = "STICKSPIN META BURST",
        difficulty = "MAESTRO",
        reward = "TSD > TST > PC",
        desc = "Ruta ultra-agresiva de torneo que enlaza tres ataques consecutivos.",
        queue = { 7, 5, 2, 4, 3, 1, 6 }, -- Z, S, J, O, L, I, T
        steps = {
            { piece = 7, rot = 2, x = 1, y = 38, keys = {"[ << DAS IZQ ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 5, rot = 1, x = 2, y = 40, keys = {"[ < IZQ ]", "[ SPACE ]"} },
            { piece = 2, rot = 1, x = 4, y = 39, keys = {"[ CENTRO ]", "[ SPACE ]"} },
            { piece = 4, rot = 1, x = 7, y = 39, keys = {"[ > DER ]", "[ SPACE ]"} },
            { piece = 3, rot = 3, x = 9, y = 39, keys = {"[ >> DAS DER ]", "[ ROTAR 180 ]", "[ SPACE ]"} },
            { piece = 1, rot = 2, x = 8, y = 37, keys = {"[ >> DAS DER ]", "[ ROTAR A ]", "[ SPACE ]"} },
            { piece = 6, rot = 1, x = 5, y = 37, keys = {"[ > DER ]", "[ T-SPIN BURST ]"} },
        }
    }
}

function TrainerDatabase.getOpener(index)
    return TrainerDatabase.OPENERS[index] or TrainerDatabase.OPENERS[1]
end

return TrainerDatabase