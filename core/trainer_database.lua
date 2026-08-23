-- ================================================================
-- FILE: core/trainer_database.lua
-- ================================================================
---@diagnostic disable: undefined-global
local TrainerDatabase = {}

TrainerDatabase.OPENERS = {
    {
        id = "tki_flat",
        tag = "01",
        name = "TKI 3 -- FLAT TOP",
        tab_label = "01 // TKI 3",
        difficulty = "INTERMEDIO",
        reward = "TSD (+4 LINEAS)",
        summary = "Apertura estandar de torneo. Ataque ultra-rapido de T-Spin Double en 3 segundos con base plana y estable.",
        queue = { 2, 7, 3, 5, 4, 1, 6 }, -- J, Z, L, S, O, I, T
        steps = {
            { 
                piece = 2, rot = 1, x = 1, y = 39, 
                desc = "Coloca la pieza J acostada en la esquina izquierda para formar la base plana.",
                keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 7, rot = 1, x = 1, y = 38, 
                desc = "Apila la pieza Z sobre la J para crear el saliente (overhang) izquierdo del T-Spin.",
                keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 3, rot = 1, x = 8, y = 39, 
                desc = "Coloca la pieza L plana en la esquina derecha para equilibrar la base del tablero.",
                keys = {"[ >> DAS DER ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 5, rot = 1, x = 7, y = 38, 
                desc = "Apila la pieza S a la derecha. Junto con la Z crea el pozo central de 3 columnas.",
                keys = {"[ > MOVER DER ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 4, rot = 1, x = 4, y = 39, 
                desc = "Centra el bloque O cuadrado en el fondo para sellar el piso del T-Spin.",
                keys = {"[ < MOVER IZQ ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 1, rot = 2, x = 8, y = 37, 
                desc = "Para la barra I vertical a la derecha para levantar la pared del pozo.",
                keys = {"[ >> DAS DER ]", "[ A ROTAR ]", "[ SPACE DROP ]"} 
            },
            { 
                piece = 6, rot = 3, x = 3, y = 37, 
                desc = "GOLPE FINAL! Desliza la pieza T en el pozo y rotala 180 grados para detonar el T-Spin Double.",
                keys = {"[ < MOVER IZQ ]", "[ UP ROTAR 180 ]", "[ TSD CLEAR! ]"} 
            }
        }
    },
    {
        id = "dt_cannon",
        tag = "02",
        name = "DT CANNON (DOUBLE-TRIPLE)",
        tab_label = "02 // DT CANNON",
        difficulty = "AVANZADO",
        reward = "TSD + TST (+11 LINEAS)",
        summary = "Construye una torre asimetrica que detona un T-Spin Double seguido inmediatamente por un devastador T-Spin Triple.",
        queue = { 4, 2, 3, 7, 5, 1, 6 }, -- O, J, L, Z, S, I, T
        steps = {
            { piece = 4, rot = 1, x = 1, y = 39, desc = "Coloca el bloque O en la esquina izquierda como cimiento del canon.", keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} },
            { piece = 2, rot = 2, x = 3, y = 38, desc = "Rota la J vertical junto al bloque O creando la camara del T-Spin Triple.", keys = {"[ < MOVER IZQ ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 3, rot = 4, x = 4, y = 38, desc = "Coloca la pieza L vertical formando la pared interna del canon.", keys = {"[ D ROTAR CCW ]", "[ SPACE DROP ]"} },
            { piece = 7, rot = 2, x = 3, y = 36, desc = "Apila la Z vertical para techar el T-Spin Triple.", keys = {"[ < MOVER IZQ ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 5, rot = 2, x = 4, y = 36, desc = "Apila la S vertical para armar el pozo superior del T-Spin Double.", keys = {"[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 1, rot = 1, x = 7, y = 40, desc = "Coloca la barra I horizontal plana a la derecha para soporte.", keys = {"[ >> DAS DER ]", "[ SPACE DROP ]"} },
            { piece = 6, rot = 1, x = 8, y = 39, desc = "Fija la T a la derecha para disparar el ciclo DT en cadena.", keys = {"[ >> DAS DER ]", "[ DT BURST! ]"} }
        }
    },
    {
        id = "pco",
        tag = "03",
        name = "PERFECT CLEAR (PCO)",
        tab_label = "03 // PCO 100%",
        difficulty = "EXPERTO",
        reward = "PERFECT CLEAR (+10 LINEAS)",
        summary = "Limpia la grilla por completo (100% vacia) en la primera bolsa de 7 piezas enviando un golpe letal.",
        queue = { 1, 2, 7, 3, 5, 4, 6 }, -- I, J, Z, L, S, O, T
        steps = {
            { piece = 1, rot = 1, x = 4, y = 40, desc = "Centra la barra I horizontal plana en el suelo (columnas 4 a 7).", keys = {"[ CENTRO ]", "[ SPACE DROP ]"} },
            { piece = 2, rot = 1, x = 1, y = 39, desc = "Coloca la J plana a la izquierda cubriendo columnas 1 a 3.", keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} },
            { piece = 7, rot = 1, x = 2, y = 38, desc = "Engancha la Z sobre la J para rellenar el hueco de la izquierda.", keys = {"[ < MOVER IZQ ]", "[ SPACE DROP ]"} },
            { piece = 3, rot = 1, x = 8, y = 39, desc = "Coloca la L plana en la esquina derecha cubriendo columnas 8 a 10.", keys = {"[ >> DAS DER ]", "[ SPACE DROP ]"} },
            { piece = 5, rot = 1, x = 7, y = 38, desc = "Engancha la S sobre la L para nivelar el lado derecho.", keys = {"[ > MOVER DER ]", "[ SPACE DROP ]"} },
            { piece = 4, rot = 1, x = 5, y = 38, desc = "Coloca el cubo O justo en el centro sobre la barra I.", keys = {"[ > MOVER DER ]", "[ SPACE DROP ]"} },
            { piece = 6, rot = 1, x = 4, y = 37, desc = "PERFECT CLEAR! Encaja la pieza T en el centro para evaporar la matriz entera.", keys = {"[ CENTRO ]", "[ PC COMPLETE! ]"} }
        }
    },
    {
        id = "mko",
        tag = "04",
        name = "MKO STACKING TSD",
        tab_label = "04 // MKO TSD",
        difficulty = "INTERMEDIO",
        reward = "TSD + DOWNSTACK (+4 LINEAS)",
        summary = "Apertura solida y flexible que permite una transicion limpia hacia el combate medio (Mid-Game).",
        queue = { 2, 4, 3, 7, 5, 1, 6 },
        steps = {
            { piece = 2, rot = 1, x = 1, y = 39, desc = "Coloca la J plana en la esquina izquierda.", keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} },
            { piece = 4, rot = 1, x = 4, y = 39, desc = "Coloca el bloque O junto a la J en el centro.", keys = {"[ < MOVER IZQ ]", "[ SPACE DROP ]"} },
            { piece = 3, rot = 2, x = 6, y = 38, desc = "Para la L vertical a la derecha del bloque O.", keys = {"[ > MOVER DER ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 7, rot = 1, x = 7, y = 40, desc = "Coloca la Z plana en la esquina derecha.", keys = {"[ >> DAS DER ]", "[ SPACE DROP ]"} },
            { piece = 5, rot = 1, x = 1, y = 37, desc = "Apila la S sobre la J a la izquierda formando el techo del TSD.", keys = {"[ << DAS IZQ ]", "[ SPACE DROP ]"} },
            { piece = 1, rot = 2, x = 8, y = 37, desc = "Para la barra I vertical en la pared derecha.", keys = {"[ >> DAS DER ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 6, rot = 3, x = 3, y = 37, desc = "Inserta la T en el pozo central y rota 180 grados para disparar el TSD.", keys = {"[ < MOVER IZQ ]", "[ UP ROTAR 180 ]", "[ TSD CLEAR! ]"} }
        }
    },
    {
        id = "stickspin",
        tag = "05",
        name = "STICKSPIN META BURST",
        tab_label = "05 // STICKSPIN",
        difficulty = "MAESTRO",
        reward = "TSD > TST > PC (+17 LINEAS)",
        summary = "Ruta ultra-agresiva de torneo que enlaza tres ataques letales consecutivos (Double -> Triple -> Perfect Clear).",
        queue = { 7, 5, 2, 4, 3, 1, 6 },
        steps = {
            { piece = 7, rot = 2, x = 1, y = 38, desc = "Para la Z vertical en la pared izquierda.", keys = {"[ << DAS IZQ ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 5, rot = 1, x = 2, y = 40, desc = "Coloca la S plana en la base.", keys = {"[ < MOVER IZQ ]", "[ SPACE DROP ]"} },
            { piece = 2, rot = 1, x = 4, y = 39, desc = "Coloca la J plana en el centro.", keys = {"[ CENTRO ]", "[ SPACE DROP ]"} },
            { piece = 4, rot = 1, x = 7, y = 39, desc = "Coloca el bloque O en la base derecha.", keys = {"[ > MOVER DER ]", "[ SPACE DROP ]"} },
            { piece = 3, rot = 3, x = 9, y = 39, desc = "Para la L vertical en la pared derecha.", keys = {"[ >> DAS DER ]", "[ UP ROTAR 180 ]", "[ SPACE DROP ]"} },
            { piece = 1, rot = 2, x = 8, y = 37, desc = "Coloca la barra I vertical levantando la columna derecha.", keys = {"[ >> DAS DER ]", "[ A ROTAR ]", "[ SPACE DROP ]"} },
            { piece = 6, rot = 1, x = 5, y = 37, desc = "DETONACION STICKSPIN! Ejecuta el T-Spin inicial para comenzar la cadena.", keys = {"[ > MOVER DER ]", "[ T-SPIN BURST! ]"} }
        }
    }
}

function TrainerDatabase.getOpener(index)
    return TrainerDatabase.OPENERS[index] or TrainerDatabase.OPENERS[1]
end

return TrainerDatabase