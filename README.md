# 🕹️ MUTRIS: SYNTHETIC TRANSCENDENCE
> **El Super-Hub definitivo de Puzzles Competitivos, Estación DAW & Combate Sinestésico.**  
> *Desarrollado bajo arquitectura estricta Zero-Garbage Collection, Sincronización Acústica por Hardware y Físicas SRS/ARS Deterministas.*

---

> ⚠️ **DIRECTIVA PRIMARIA PERMANENTE (REGLA DE ORO):**  
> El identificador de versión (`_G.ENGINE_VERSION = "MUTRIS v1.0.0"`) **debe permanecer siempre visible en la esquina inferior izquierda en todas las pantallas y estados del juego** (Menú, Duelos, Editor DAW, Ajustes, Pausa y Game Over) para garantizar la trazabilidad en capturas y telemetría.

---

# 📑 ÍNDICE GENERAL

1. [VISIÓN Y MANIFIESTO DEL PROYECTO](#-visión--manifiesto-del-proyecto)
2. [LOS 5 MANDAMIENTOS SAGRADOS DE CÓDIGO (ZERO-GC ENGINE)](#-los-5-mandamientos-sagrados-de-código-zero-gc-engine)
3. [DICCIONARIO DE ARQUITECTURA DEL REPOSITORIO](#-diccionario-de-arquitectura-del-repositorio)
4. [MOTORES INTERNOS ACTIVOS (MATEMÁTICAS & FÍSICAS)](#-motores-internos-activos)
5. [EL CRONOGRAMA MAESTRO: ROADMAP DE 26 FASES](#-el-cronograma-maestro-roadmap-de-26-fases)
6. [ESPECIFICACIÓN TÉCNICA DE SISTEMAS FUTUROS](#-especificación-técnica-de-sistemas-futuros)
7. [PRESUPUESTO DE RENDIMIENTO POR FRAME (144Hz / 240Hz TARGET)](#-presupuesto-de-rendimiento-por-frame)
8. [ÁRBOL DE DIRECTORIOS MODULAR](#-árbol-de-directorios-modular)
9. [GUÍA PASO A PASO "A PRUEBA DE TONTOS" (HOW-TOs)](#-guía-paso-a-paso-a-prueba-de-tontos)
10. [MATRIZ DE DIAGNÓSTICO & RESOLUCIÓN DE BUGS (TROUBLESHOOTING)](#-matriz-de-diagnóstico--resolución-de-bugs)
11. [MAPEO DE CONTROLES PREDETERMINADO](#-mapeo-de-controles-predeterminado)

---

# 👁️ VISIÓN & MANIFIESTO DEL PROYECTO

**MUTRIS** fusiona cinco dimensiones de juego en un único ecosistema:
1. **La Precisión Competitiva:** Tiempos de entrada al milisegundo (DAS/ARR/SDF estilo *Jstris/TETR.IO*), físicas SRS 180° y renderizado desacoplado a 144Hz / 240Hz.
2. **La Estación de Audio Digital (DAW):** El tablero es un sintetizador analógico procedural y secuenciador en tiempo real con analizador de espectro, sidechaining paramétrico y modulación por escala armónica Camelot.
3. **El Combate de Juegos de Lucha & Soulsborne:** Sistema de posturas en vivo (*Stances*), absorción de daño en ventana de 3 frames (*Kinetic Parry*), barras de postura con golpes críticos (*Riposte*) y efectos de estado (*Bleed, Frostbite, Corrupción*).
4. **La Cacería Estratégica (Monster Hunter DNA):** Cacería de jefes cibernéticos con desmembramiento anatómico por columnas (*Part Breaking*), estados de Furia/Fatiga y el cancionero cromático del Cuerno de Caza (*Chroma-Weaver*).
5. **Inteligencia Auto-Evolutiva:** El **ARCHON META-BALANCER**, una IA interna que analiza estadísticas globales de juego y auto-equilibra constantes matemáticas en disco de forma autónoma.

---

# 📜 LOS 5 MANDAMIENTOS SAGRADOS DE CÓDIGO (ZERO-GC ENGINE)

Todo módulo, script o aporte al repositorio debe respetar estas 5 leyes de hierro:

* 🚫 **1. Cero Recolección de Basura (Zero-GC Loop):** Prohibido instanciar tablas vacías (`{}`) o concatenar strings dentro de `love.update` y `love.draw`. Todo vector, matriz o estructura de partículas se pre-aloca al iniciar el motor.
* 🔊 **2. Reloj Amarrado a la Placa de Sonido:** Ningún temporizador crítico o ventana de parry depende del `dt` de pantalla; todo pulsa según el contador de hardware de audio (`Source:tell("seconds")`).
* 👁️ **3. Prioridad Absoluta a la Legibilidad:** Ningún shader o colapso visual puede comprometer la visibilidad milimétrica de la matriz y el *Ghost Piece* a velocidades extremas (6.0+ PPS).
* ⚙️ **4. Determinismo en Frame-Data:** Las patadas de pared, cuadros de invulnerabilidad (I-Frames) y offsets de basura se calculan en matemática discreta sin aproximaciones de punto flotante.
* 🎻 **5. Síntesis de Subgraves Cooperativa:** Los efectos de sonido se modulan en octavas bajas (30 Hz - 180 Hz) como instrumentos armónicos afinados a la tonalidad del tema, sin saturar la música del usuario.

---

# 🗂️ DICCIONARIO DE ARQUITECTURA DEL REPOSITORIO
MUTRIS/
├── conf.lua -- Configuración de ventana (800x600, VSync, V-Refresh 144/240Hz).
├── main.lua -- Kernel central, despacho de estados, RealMatchTimer e Hitstop.
├── input.lua -- Motor DAS/ARR milimétrico, lectura de Gamepad y remapeo.
├── settings_manager.lua -- Serialización y lectura de ajustes persistentes en settings.json.
├── audio_manager.lua -- Síntesis procedural senoidal, Sidechain Ducking y rampa de energía.
├── music_manager.lua -- Reloj de hardware de audio amarrado a Source:tell("seconds").
├── track_manager.lua -- Extracción modal Camelot, mapeo cromático de notas y metadatos.
├── track_editor.lua -- Laboratorio DAW: Timeline con Scrubber, espectrograma y rack SFX.
│
└── tetris/
├── ai_bot.lua -- IA heurística downstacker con memoria persistente (ai_profile.json).
├── anomaly_manager.lua -- Gestor de anomalías rítmicas (Torus, Laser, Swap, Eclipse).
├── bloom_shader.lua -- Shader GLSL con resplandor neón, aberración cromática y shockwaves.
├── board.lua -- Grid 10x40, render 21-40, implosión poliédrica de cristal y Zone.
├── fog_layer.lua -- Niebla volumétrica Z-Depth reactiva a la tonalidad Camelot.
├── font_cache.lua -- Caché de fuentes tipográficas para eliminar llamadas a newFont().
├── game_states.lua -- Pantallas de Menú Principal interactivo y Calibración de Inputs.
├── garbage_manager.lua -- Offsetting reactivo de basura, colas y multiplicadores Zone.
├── hud_center.lua -- Placa central flotante con PPS dual (Humano vs Bot) y pulso de beat.
├── hud_panels.lua -- Paneles laterales NEXT y HOLD centrados por tetromino + Barra Zone.
├── particle_system.lua -- Pool estático de 200 partículas reciclables para limpiezas de líneas.
├── piece.lua -- Físicas SRS, patadas de pared 180°, detección T-Spin y Lock Delay.
├── pps_counter.lua -- Buffer circular de 60 ranuras para media móvil de velocidad en 5s.
├── shaker.lua -- Micro-sismos desacoplados por matriz gráfica push/pop aislada.
├── telemetry.lua -- Panel de diagnóstico en vivo (FPS, Match Time, AI Base PPS).
├── randomizers/7bag.lua -- Generador estándar Guideline con bolsa aleatoria sin repetición.
└── rotation_systems/srs.lua -- Tablas de Wall-Kick tridimensionales para tetrominos I y JLSTZ.

---

# ⚙️ MOTORES INTERNOS ACTIVOS

### 1. Geometría Rígida de la Matriz (The Grid)
* **Dimensiones Totales:** `10 columnas x 40 filas`.
* **Filas 1 a 20 (Zona Oculta de Amortiguación):** Búfer aéreo de spawn, cálculo de patadas pesadas y evaluación predictiva de la IA.
* **Filas 21 a 40 (Zona Visible de Combate):** Renderizada en pantalla con traslación matemática:
  `Render_Y = Board.y + (row - 21) * 24`
* **Codificación Numérica de Celdas:**
  - `0`: Vacío absoluto.
  - `1`: Tetromino **I** (Cian).
  - `2`: Tetromino **J** (Azul).
  - `3`: Tetromino **L** (Naranja).
  - `4`: Tetromino **O** (Amarillo).
  - `5`: Tetromino **S** (Verde).
  - `6`: Tetromino **T** (Púrpura).
  - `7`: Tetromino **Z** (Rojo).
  - `8`: Bloque sólido de basura (*Garbage Block* gris metálico).

---

### 2. Motor de Entrada Competitivo DAS / ARR (`input.lua`)
* **DAS (Delayed Auto-Shift):** Clavado en `0.094 s` (~5.6 frames). Tiempo físico de espera antes de que la pieza se desplace automáticamente.
* **ARR (Auto-Repeat Rate):** Fijado en `0.008 s` (<0.5 frames). Intervalo de desplazamiento continuo tras vencer el DAS.
* **SDF (Soft Drop Factor):** Reducido a `0.001 s` para descenso vertical prácticamente instantáneo.
* **Lock Delay:** Margen de `0.5 s` con un límite estricto de **15 reinicios de movimiento** por rotación o traslación horizontal validada.

```lua
-- Algoritmo de consumo DAS/ARR Zero-GC
if move_left_held then
    if not Input.das_active.left then
        p:move(-1, 0) -- Tap inicial
        Input.das_active.left = true
        Input.timers.left = 0
    else
        Input.timers.left = Input.timers.left + dt
        while Input.timers.left >= das do
            if not p:move(-1, 0) then
                Input.timers.left = 0
                break
            end
            Input.timers.left = Input.timers.left - arr
        end
    end
else
    Input.das_active.left = false
end



3. Sincronización Acústica y The Punch System

    Reloj de Hardware de Audio: El temporizador principal del juego se amarra al contador interno de hardware de la placa de sonido mediante MusicManager.getTime() (que consulta Source:tell("seconds")), eliminando el desfasaje acumulativo (audio-drift:




local beat_duration = 60 / AudioManager.current_bpm
local current_beat = song_time / beat_duration
local fraction = current_beat - math.floor(current_beat)
if fraction < 0.08 and _G.AudioBeatPulse <= 0.1 then
    _G.AudioBeatPulse = 1.0
end

The Punch System (Rampa Maestra de Adrenalina): Calcula la intensidad energética fotograma a fotograma según el punto exacto de la canción:

local drop_point = current_track.drop_second or (bar_duration * 32)
local build_len  = current_track.build_duration or (bar_duration * 16)
local build_start = math.max(0, drop_point - build_len)

if song_time >= drop_point then
    _G.TrackEnergyPunch = 1.0
elseif song_time >= build_start then
    local progress = (song_time - build_start) / build_len
    _G.TrackEnergyPunch = progress * progress * progress -- Curva cúbica
else
    _G.TrackEnergyPunch = 0.0
end

Dynamic Sidechain Ducking: Atenúa automáticamente la música de fondo ante eventos de alto impacto para dar peso cinemático a la partida.

4. Físicas SRS y Detección Quirúrgica de T-Spin (3-Corners Rule)

    Super Rotation System (SRS): Soporte nativo para rotaciones horarias, antihorarias y giros completos de 180° mediante tablas de Wall-Kick tridimensionales.

    Detección T-Spin: Evaluada en tetris/piece.lua:

        La pieza activa debe ser id == 6 (Tetromino T).

        El último movimiento validado debe haber sido una rotación.

        Al menos 3 de las 4 esquinas de su matriz de 3x3 {(x, y), (x+2, y), (x, y+2), (x+2, y+2)} deben estar ocupadas por bloques fijos o bordes de la grilla.

5. Tabla de Ataques, Offsetting y Zone Mode

    Tabla Base de Daño: Single (0), Double (1), Triple (2), Tetris (4), T-Spin Single (2), T-Spin Double (4), T-Spin Triple (6), Back-to-Back (+1 línea), Combos (+0, +0, +1, +1, +1, +2, +2, +3, +3, +4, +4, +4, +5).

    Offsetting Activo: Si el jugador recibe un ataque, la basura se aloja en garbage_queue. Al limpiar líneas en la siguiente jugada, el ataque saliente cancela primero la deuda pendiente de su propia cola antes de enviar basura al oponente.

    Límite de Entrada: Máximo 8 líneas de basura transferidas a la grilla por pieza colocada.

    Zone Mode: Inmunidad total a la basura entrante y almacenamiento acumulado para un estallido único (Zone Burst):

        Tier 1 (25% - 99%): Holo-Cyan Matrix.

        Tier 2 (100%): Hyper Gold-Diamond Prism.

6. IA Heurística y DDA Persistente (ai_bot.lua, ai_profile.json)

    Registra el desempeño del usuario tras cada combate evaluando la Media Móvil Exponencial (EMA):
    PlayerAvgPPS = (PlayerAvgPPS * 0.70) + (PlayerLastMatchPPS * 0.30)

    Calibra la velocidad base del bot para situarse entre un 8% y 15% por encima del ritmo real del jugador.

    Radar de Agujeros (Hole-Seeking): Identifica la columna del agujero de escape en las líneas de basura para realizar un Downstacking quirúrgico sin tapar pozos.

👑 EL CRONOGRAMA MAESTRO: ROADMAP DE 26 FASES
code Code

========================================================================================================
                        MUTRIS ENGINE: CRONOGRAMA MAESTRO DE PRODUCCIÓN
========================================================================================================
 ESTADO:  [✔️] COMPLETO     [🚧] EN DESARROLLO     [⏳] PLANIFICADO
========================================================================================================

 ── ÉPOCA I: NÚCLEO ZERO-GC, HARDWARE AUDIO & ESTACIÓN DAW ─────────────────────────────────────────────
 [✔️] FASE 1  │ Core Engine Zero-GC, SRS 180°, Offsetting & DAS/ARR Competitivo
 [✔️] FASE 2  │ Reloj de Hardware por Placa de Sonido & Sync de Beat Puro (0.0 ms Desfasaje)
 [✔️] FASE 3  │ Síntesis Acústica Cooperativa & Afinación Modal Camelot (Sub-Bajos 30Hz)
 [✔️] FASE 4  │ Mapeo Universal de Teclado/Mandos con Persistencia JSON (settings.json)
 [✔️] FASE 5  │ Timeline DAW Interactivo con Scrubber, Marcador de Drop y Curvas de Energía
 [✔️] FASE 6  │ Dynamic Sidechain Ducking, Rack de Saturación Tanh y Audición de SFX en Vivo

 ── ÉPOCA II: COMBATE RÍTMICO, SINESTESIA & MECÁNICAS DE JUEGO DE LUCHA ────────────────────────────────
 [🚧] FASE 7  │ Beat-Lock Timing: Ventana de ±35ms, Groove Strikes y Multiplicadores de Tempo
 [⏳] FASE 8  │ Stance Switching System: Rush, Bastion y Resonance con físicas dinámicas
 [⏳] FASE 9  │ Kinetic Parry: Ventana de 3 Frames para Absorción y Contraataque de Basura (Spikes)
 [✔️] FASE 10 │ Zone Mode 3-Tiers: Tier 1 Holo-Cyan, Tier 2 Hyper Gold, Tier 3 Supernova Overdrive
 [✔️] FASE 11 │ Gestor de Anomalías V2: Torus Belt, Quantum Laser, Sudden Matrix Swap y Eclipse

 ── ÉPOCA III: INTELIGENCIA ARTIFICIAL, AUTO-BALANCE & ENTRENAMIENTO ───────────────────────────────────
 [🚧] FASE 12 │ ARCHON META-BALANCER: IA Interna de Auto-Equilibrio Estadístico y Auto-Patches
 [✔️] FASE 13 │ DDA Heurística 2.0 & Ghost AI Profiler: Clonación de Estilo de Juego del Usuario
 [⏳] FASE 14 │ Trainer Lab & Asistente Holográfico de Aperturas (T-Spins, DT Cannon, PC con Undo)
 [✔️] FASE 15 │ Telemetría Centralizada en Vivo (PPS Dual, FPS, Adrenalina Musical y Récords)

 ── ÉPOCA IV: SISTEMAS SOULSBORNE & MONSTER HUNTING ────────────────────────────────────────────────────
 [⏳] FASE 16 │ Souls Dynamics: Barra de Postura, Aturdimiento de Jefes, I-Frames & Visceral Clears
 [⏳] FASE 17 │ Status Blights: Hemorragia por T-Spins, Congelación de DAS/ARR y Corrupción de Matriz
 [⏳] FASE 18 │ Anatomía por Columnas & Part Breaking: Corte de Colas y Rotura de Cuernos en Jefes
 [⏳] FASE 19 │ Chroma-Weaver Engine: Pentagrama HUD, Fusión de Colores y Melodías Activas
 [⏳] FASE 20 │ The Hunter's Forge & Cyber-Palico: Sets de Armadura, Joyas Pasivas y Dron de Soporte

 ── ÉPOCA V: MULTI-RULESET UNIVERSAL, FÍSICAS & CREATIVIDAD ───────────────────────────────────────────
 [⏳] FASE 21 │ Multi-Ruleset Engine: Guideline Moderno, TGM 20G Shirase, NES 1989, Pentomino 18
 [⏳] FASE 22 │ Modos Híbridos: Push 1v1 Tug-of-War, Sandtrix Granular y Waveform Dynamic Grid
 [⏳] FASE 23 │ Mutris Architect Studio: Grid Painter, Timeline Tracker y Lógica por Nodos
 [⏳] FASE 24 │ Lua Scripting API con Sandbox _ENV Seguro & Paquetes Todo-en-Uno (.mutrispack)

 ── ÉPOCA VI: INFRAESTRUCTURA DEPORTIVA, RED & TRANSCENDENCIA ──────────────────────────────────────────
 [⏳] FASE 25 │ Rollback Netcode P2P (GGPO), Replays Binarios (.mutrisrec) y Broadcast Esports HUD
 [⏳] FASE 26 │ Modo Historia "Synthetic Transcendence", Shaders 3D Voxel y Lanzamiento Multiplataforma
========================================================================================================

🚀 ESPECIFICACIÓN TÉCNICA DE SISTEMAS FUTUROS
1. Beat-Lock Timing (Fase 7)

    Algoritmo: Evalúa si el Hard Drop aterriza en una ventana de

            
    ±35 ms
    ±35 ms

          

    respecto al tiempo fuerte del compás musical.

    Recompensa:

            
    +1
    +1

          

    línea de ataque enviada, pulso dorado en la grilla y disparo de transitorio percusivo de subgraves.

2. Stances & Kinetic Parry (Fases 8 y 9)

    Posturas Conmutables (Tab / L3):

        Rush: Ataque x1.5, Lock Delay 0.12s, ARR 0.001s.

        Bastion: Ataque x0.5, activa la ventana de Parry de 3 frames.

        Resonance: Carga de Zone x2, gravedad 20G instantánea.

    Kinetic Parry: Bloquear una pieza en los 3 frames previos a la entrada de basura anula el 100% del daño y devuelve un Counter-Spike del 50%.

3. Archon Meta-Balancer (Fase 12)

    Módulo: core/meta_balancer.lua y saves/game_balance.json.

    Función: Monitorea el Win Rate y la tasa de letalidad de cada modo/anomalía. Si un valor se desvía del equilibrio, auto-ajusta constantes en disco mediante descenso de gradiente e imprime notas de parche automáticas en el menú.

4. Sistemas Souls & Monster Hunting (Fases 16 a 20)

    Barra de Postura & Riposte: Llenar la postura del jefe causa un aturdimiento de 6s donde cada línea hace daño x3 (Visceral Clears).

    Part Breaking por Columnas: Columnas 1-3 (Cuernos), 4-7 (Núcleo), 8-10 (Cola). Romper partes desactiva ataques del monstruo y suelta materiales raros (Carves).

    Chroma-Weaver (Cuerno de Caza): Pentagrama HUD con 4 ranuras. Limpiar colores específicos completa recetas (ej. Cian+Violeta+Naranja = Attack Up [XL]) activables con el botón de Recital.

5. Mutris Architect & Lua Sandbox (Fases 23 y 24)

    Editor Integrado: Grid Painter de bloques elementales + Timeline Tracker DAW + Editor de Nodos visuales.

    Sandbox Seguro: Entorno cerrado con _ENV que expone solo funciones seguras de juego (GameAPI.*), bloqueando accesos peligrosos al sistema operativo.

⚡ PRESUPUESTO DE RENDIMIENTO POR FRAME
Subsistema / Módulo	Tiempo Asignado	Estrategia de Optimización
Input & DAS/ARR Sampling	0.15 ms	Consulta directa sin llamadas intermedias ni polling pesado.
Físicas SRS / Matriz de Bloques	0.60 ms	Tablas pre-indexadas y operaciones matemáticas escalares.
IA Heurística (Bot & DDA)	0.45 ms	Buffer plano reutilizable _overlay de 400 posiciones en 1 solo barrido.
Síntesis de Audio & Sidechain	0.30 ms	SoundData estático y modulación mediante curvas analógicas tanh.
Renderizado & Shaders (GPU)	2.50 ms	Dibujado por lotes, FontCache centralizado y postprocesado en Canvas.
TOTAL FRAME BUDGET CONSUMIDO	~4.00 ms	Margen libre superior al 60% en 144Hz (6.94ms) y 240Hz (4.16ms).
📂 ÁRBOL DE DIRECTORIOS MODULAR
code Code

MUTRIS/
├── main.lua                     -- Kernel maestro, despacho de estados e Hitstop
├── conf.lua                     -- Configuración de ventana LÖVE2D a 144/240Hz
├── input.lua                    -- Motor DAS/ARR/SDF y remapeo universal
├── audio_manager.lua            -- Síntesis procedural, Sidechain y Ducking
├── music_manager.lua            -- Reloj de hardware y streaming de audio
├── settings_manager.lua         -- Persistencia de controles y volumen (settings.json)
├── track_manager.lua            -- Extracción modal armónica y tablas Camelot
├── track_editor.lua             -- DAW Studio, Scrubber y colocación de Cues
│
├── core/                        -- Librerías base del motor
│   ├── meta_balancer.lua        -- [F12] ARCHON AI: Auto-tuning y balance interno
│   ├── ruleset_manager.lua      -- [F21] Selector Guideline, TGM 20G, NES, Push
│   ├── mod_loader.lua           -- [F24] Intérprete Sandbox Lua (_ENV) y .mutrispack
│   └── netcode_ggpo.lua         -- [F25] Rollback P2P y sincronización determinista
│
├── combat/                      -- Módulos de combate y sistemas de juego
│   ├── combat_stances.lua       -- [F8] Stances: Rush, Bastion, Resonance
│   ├── kinetic_parry.lua        -- [F9] Ventana de 3 frames y Counter-Spikes
│   ├── poise_system.lua         -- [F16] Postura, aturdimiento y golpes críticos
│   ├── part_breaking.lua        -- [F18] Anatomía por columnas y desmembramiento
│   ├── chroma_weaver.lua        -- [F19] Cancionero de acordes y buffs melódicos
│   └── hunting_forge.lua        -- [F20] Taller de forja, builds y dron Palico
│
├── tetris/                      -- Lógica pura de la grilla y físicas
│   ├── board.lua                -- Grid 10x40, animaciones y muerte en cristal
│   ├── piece.lua                -- Físicas SRS/ARS, 180° kicks y detección T-Spin
│   ├── garbage_manager.lua      -- Offsetting reactivo, colas y Zone Storage
│   ├── anomaly_manager.lua      -- Gestor de anomalías rítmicas e invasiones
│   ├── particle_system.lua      -- Pool estático de 200 partículas Zero-GC
│   ├── pps_counter.lua          -- Buffer circular de 60 ranuras para cálculo móvil
│   ├── font_cache.lua           -- Caché de fuentes tipográficas rasterizadas
│   ├── fog_layer.lua            -- Niebla cromática Z-Depth reactiva a Camelot
│   ├── bloom_shader.lua         -- Shaders de resplandor neón y ondas expansivas
│   ├── hud_panels.lua           -- Paneles NEXT/HOLD con centrado milimétrico
│   ├── hud_center.lua           -- Marcador VS central y medidor de compás
│   ├── telemetry.lua            -- Consola de diagnóstico y métricas en vivo
│   └── ai_bot.lua               -- Bot heurístico con DDA adaptativo 2.0
│
├── architect/                   -- Herramientas de creación
│   ├── grid_painter.lua         -- [F23] Diseñador visual de puzzles y metas
│   ├── timeline_sequencer.lua   -- [F23] Secuenciador de eventos musicales DAW
│   └── node_editor.lua          -- [F23] Lógica visual por cajas conectables
│
├── music/                       -- Pistas de audio (.mp3/.ogg) y metadatos (.json)
├── sfx/                         -- Soundpacks y voces del presentador
└── saves/                       -- Perfiles DDA, repeticiones .mutrisrec y niveles

🛠️ GUÍA PASO A PASO "A PRUEBA DE TONTOS"
1. ¿Cómo agregar una Nueva Anomalía Rítmica?

    Abre tetris/anomaly_manager.lua.

    En la tabla ANOMALY_POOL, añade una nueva entrada con su identificador, nombre y duración:
    code Lua

    { id = "mi_anomalia", name = "NOMBRE VISUAL EN PANTALLA", dur = 10.0 }

    En la tabla ANOMALY_THEMES, define sus colores neón y su etiqueta:
    code Lua

    mi_anomalia = { c1 = {1.0, 0.2, 0.5}, c2 = {1.0, 0.6, 0.8}, label = "MI ANOMALIA" }

    En AnomalyManager.update(dt, player, bot), programa la lógica matemática sin crear tablas {} en memoria.

2. ¿Cómo agregar una Canción Nueva Manualmente?

    Coloca tu archivo cancion.mp3 o cancion.ogg en la carpeta music/.

    Crea un archivo con el mismo nombre exacto pero extensión .json: music/cancion.json.

    Completa los metadatos:
    code JSON

    {
      "name": "MI CANCION",
      "bpm": 135,
      "root_note": "F#",
      "mode": "MINOR",
      "drop_second": 85.0,
      "build_duration": 30.0
    }

    Opcional: Abre el juego, ve a SOUNDTRACK & FX LAB, arrastra el archivo y calíbralo con el timeline.

3. ¿Cómo agregar un nuevo SFX sin romper el Zero-GC?

    Abre audio_manager.lua.

    En AudioManager.playImmediateSFX(type, is_bot, row_y), agrega tu nuevo elseif:
    code Lua

    elseif type == "mi_sonido" then
        AudioManager.playToneEx(freq, duration, volume, "sine", drive, decay, pitch_bend)
    end

    Dispara el sonido desde cualquier archivo con:
    code Lua

    local AudioManager = require "audio_manager"
    AudioManager.playImmediateSFX("mi_sonido", false)

4. ¿Cómo garantizar que tu nuevo código cumpla con Zero-GC?

Coloca temporalmente al final de love.update:
code Lua

local count = collectgarbage("count")
print(string.format("MEMORIA LUA EN VIVO: %.2f KB", count))

    Correcto: La memoria permanece fija en un número constante frame a frame durante el combate.

    Incorrecto: El número sube de forma continua. Revisa si dejaste tablas {} o llamadas a newFont() dentro de funciones de actualización o dibujado.

🔍 MATRIZ DE DIAGNÓSTICO & RESOLUCIÓN DE BUGS
code Code

┌──────────────────────────────────────┬────────────────────────────────┬────────────────────────────────────────────┐
│ SÍNTOMA / ERROR EN CONSOLA           │ CAUSA RAÍZ TÉCNICA             │ SOLUCIÓN INGENIERIL INMEDIATA              │
├──────────────────────────────────────┼────────────────────────────────┼────────────────────────────────────────────┤
│ Micro-congelamientos cada 4 segundos │ Asignación de tablas {} en     │ Mover variables a buffers pre-alocados en  │
│ (Garbage Collection Stutter)         │ love.update o love.draw.       │ el init() del módulo correspondiente.      │
├──────────────────────────────────────┼────────────────────────────────┼────────────────────────────────────────────┤
│ Desfase entre el bombo de la canción │ Se usó dt acumulado para medir │ Reemplazar por MusicManager.getTime() que  │
│ y el parpadeo neón tras 3 minutos    │ el compás en vez del hardware. │ consulta directamente Source:tell().       │
├──────────────────────────────────────┼────────────────────────────────┼────────────────────────────────────────────┤
│ Error 'attempt to index a nil value' │ La pieza intenta consultar     │ Validar siempre índices con:               │
│ al evaluar colisiones cerca del techo│ grid[y][x] con fila y < 1.     │ if y >= 1 and y <= 40 and x >= 1 and x <= 10│
├──────────────────────────────────────┼────────────────────────────────┼────────────────────────────────────────────┤
│ El temblor (Shaker) de un jugador    │ Falta de aislamiento de matriz │ Encapsular el bloque de dibujado entre:    │
│ sacude también el HUD del rival      │ gráfica en love.graphics.      │ love.graphics.push() y love.graphics.pop() │
├──────────────────────────────────────┼────────────────────────────────┼────────────────────────────────────────────┤
│ Crash por 'out of memory' en fuentes │ love.graphics.newFont() dentro │ Utilizar estrictamente FontCache.get(size).│
│ tipográficas al escalar textos       │ del ciclo de dibujado draw().  │                                            │
└──────────────────────────────────────┴────────────────────────────────┴────────────────────────────────────────────┘

🎮 MAPEO DE CONTROLES PREDETERMINADO
Acción	Teclado Primario	Teclado Secundario	Gamepad / Mando
Mover Izquierda / Derecha	Left / Right	KP 4 / KP 6	D-Pad L/R o Stick Izq
Soft Drop (Caída Suave)	Down	KP 5	D-Pad Down o Stick Abajo
Hard Drop (Fijación Instantánea)	Space	—	RB / RT
Rotación Horaria (CW)	A	Z	Botón A / Botón B
Rotación Antihoraria (CCW)	D	X	Botón X / Botón Y
Rotación 180°	Up	KP 8	D-Pad Up
Hold (Reserva)	S	C	LB / LT
Zone Mode / Recital Melódico	Q	E	Gatillo L2 / R2
Cambio de Postura (Stance)	Tab	Shift	L3 / R3 (Stick Click)
Reinicio Rápido	R	—	Start / Back
Menú de Ajustes / Salir	Escape	—	—
🏁 CERTIFICACIÓN TÉCNICA FINAL

Este compendio técnico unifica la totalidad del código vigente y las especificaciones completas para las Fases 7 a 26 de MUTRIS. Cualquier sesión de desarrollo futura puede ejecutarse tomando este archivo como referencia definitiva y absoluta.









# 🚀 REGISTRO DE PROGRESO & CHANGELOG TÉCNICO (FASE 7 A 13 + WIDESCREEN REFACTOR)

> **Estado del Repositorio:** `MUTRIS v1.0.0-PROD`  
> **Arquitectura:** Zero-Garbage Collection | Widescreen 16:9 Nativo (1280×720 @ 144/240Hz Target) | Win32 FFI Streaming

---

## 📑 RESUMEN DE SISTEMAS IMPLEMENTADOS
========================================================================================================
MUTRIS ENGINE: ESTADO DE ACTUALIZACIÓN DEL ROADMAP
[✔️] FASE 7 │ Beat-Lock Timing: Ventana ±35ms, Groove Strikes (+1 Línea) & Pulso Subgrave
[✔️] FASE 8 │ Stance Switching System: Rush (1.5x Atk), Bastion (Parry) & Resonance (20G / 2x Zone)
[✔️] FASE 9 │ Kinetic Parry: Ventana de 3 Frames, 100% Absorción & Counter-Spike del 50%
[✔️] FASE 12 │ ARCHON META-BALANCER 1.0: Auto-Equilibrio Estadístico por Descenso de Gradiente
[✔️] FASE 13 │ DDA Heurística 2.0: Clonación Adaptativa de PPS (+10%) & Radar Hole-Seeking
[✔️] FASE 25 │ Replay System (.mutrisrec) & Win32 Silent MP4 60FPS Video Pipeline (FFmpeg Pipe)

---

## 🕹️ DETALLE TÉCNICO DE NOVEDADES

### 1. 🥊 Motor de Combate & Sincronización Rítmica (Fases 7, 8 y 9)
* **Beat-Lock Timing (`tetris/beat_lock.lua`):**
  - Mide la diferencia temporal entre el *Hard Drop* y el pulso fuerte de la música mediante el reloj de hardware (`MusicManager.getTime()`).
  - Ventana de tolerancia: $\pm35\text{ ms}$ (ampliada a $\pm45\text{ ms}$ en *Resonance*).
  - Recompensa: Disparo de *Groove Strike* (+1 línea de ataque), onda de choque, transitorio de subgraves a 30 Hz y multiplicador de racha.
* **Sistema de Posturas Dinámicas (`combat/combat_stances.lua`):**
  - Conmutable al vuelo con `TAB`, `Shift` o `L3/R3` con auras neón dedicadas:
    - **RUSH (Bermellón):** Daño $\times1.5$, Lock Delay ultra-rápido ($0.12\text{ s}$), ARR instantáneo ($0.001\text{ s}$).
    - **BASTION (Zafiro):** Daño $\times0.5$, Lock Delay seguro ($0.50\text{ s}$), activa la absorción de daño por *Kinetic Parry*.
    - **RESONANCE (Amatista):** Carga de Zone $\times2.0$, gravedad forzada a $20\text{ G}$ instantánea.
* **Kinetic Parry & Anti-Recursión (`combat/kinetic_parry.lua`):**
  - Ventana de 3 frames ($\sim0.050\text{ s}$) al fijar una pieza para anular el $100\%$ de la basura entrante y devolver un *Counter-Spike* del $50\%$.
  - Implementado con flag `is_counter_spike` para evitar bucles infinitos de contraataques mutuos.

---

### 2. 🧠 Inteligencia Auto-Evolutiva (Fases 12 y 13)
* **ARCHON Meta-Balancer (`core/meta_balancer.lua`):**
  - Monitorea la tasa global de victorias (*Win Rate*) y la duración de partidas en `saves/game_balance.json`.
  - Si el usuario pierde persistentemente ($<35\%$), auto-calibra la tolerancia de *Beat-Lock*, la defensa de *Bastion* y el daño devuelto. Si domina ($>75\%$), ajusta la agresividad.
  - Imprime notas de parche automáticas en el menú principal (`[ ARCHON ] ...`).
* **DDA Heurístico 2.0 & Radar Hole-Seeking (`tetris/ai_bot.lua`):**
  - Ajusta el PPS base del Bot a través de una Media Móvil Exponencial (EMA) para situarse permanentemente un $10\%$ por encima de la velocidad real del jugador.
  - Algoritmo *Hole-Seeking*: Identifica la columna de escape en la basura para ejecutar *Downstacking* quirúrgico sin tapar pozos.
  - Sistema Anti-Atasco (*Anti-Stall Fallback*): Previene bloqueos lógicos en techos saturados forzando caídas deterministas.

---

### 3. 🖥️ Arquitectura Widescreen 16:9 & Telemetría Sin Solapamiento
* **Resolución Nativa 1280×720 (`conf.lua` & `main.lua`):**
  - Migración completa de 800×600 a 1280×720 Widescreen con escalado virtual centrado (*Letterbox/Pillarbox*) para monitores 1080p, 1440p y 4K (`F11`).
* **Blackbox Flight Recorder & Telemetría Permanente (`core/blackbox.lua`):**
  - Búfer circular de 128 eventos en memoria fija (Zero-GC) que registra cada acción crítica.
  - Distribución no obstructiva en pantalla:
    - **Ala Izquierda (x: 20..120):** Altura pico de P1, tamaño de cola de basura, Stance activa y registro de eventos locales.
    - **Ala Derecha (x: 1160..1260):** Altura pico del Bot, cola de basura, PPS objetivo y registro de decisiones de IA.
    - **Bahía Central (x: 480..800):** Historial cronológico en vivo (*Live Flight Recorder*), comparador PPS dual y barra de adrenalina (*The Punch*).
* **Crash-Proof Error Handler:**
  - Si ocurre cualquier excepción en Lua, el motor no se cierra: vuelca la autopsia con el rastro de la pila y los últimos 32 eventos a `saves/crash_report.txt` y mantiene el panel de diagnóstico en pantalla.

---

### 4. 🎥 Pipeline Multimedia & Captura de Alto Rendimiento
* **Grabador MP4 Silencioso a 60 FPS (`core/clip_recorder.lua`):**
  - Transmisión en tiempo real de fotogramas RGBA en crudo directo a `ffmpeg.exe` mediante la API Win32 nativa (`CreateProcessA` + `CREATE_NO_WINDOW`).
  - **Cero consolas de CMD abiertas, cero consumo de memoria RAM acumulativa y guardado instantáneo al presionar `F9`**.
  - El indicador `● REC 60FPS` se renderiza fuera del canvas del juego para no ensuciar el video final.
* **Captura Lossless Directa al Portapapeles (`core/screenshot_helper.lua`):**
  - Presionando `F12`, `F2` o `PrintScreen`, la imagen en resolución completa se inyecta directamente al portapapeles de Windows (`CF_DIB` vía FFI) para pegar con **`Ctrl + V`** al instante, guardando además una copia `.png` en `screenshots/`.
* **Replays Binarios Deterministas (`core/replay_manager.lua`):**
  - Grabación automática de partidas en archivos compactos **`.mutrisrec`** ($<10\text{ KB}$) con semilla RNG, marcas de tiempo y flujo de entradas de ambos jugadores.

---

### 5. 🛡️ Corrección de Físicas y Reglas de Techo (Lock-Out / Block-Out)
* **Lock-Out Oficial:** Si una pieza se fija con bloques en la zona superior de amortiguación ($ty \le 20$) sin limpiar líneas, se declara muerte inmediata.
* **Block-Out Oficial:** Si una pieza generada colisiona directamente en el punto de aparición $(4, 21)$, se declara muerte inmediata.
* **Top-Out Bounds Fix:** Se incluyó la validación estricta del límite superior (`ty < 1`) en `Board:canMove`, erradicando bloqueos infinitos durante la anomalía *Anti-Gravity Reverse*.
* **Death Timer Decrement:** Corregido el ciclo de muerte del tablero (`death_timer = death_timer - dt`) garantizando la transición fluida a la pantalla de victoria/derrota.

---

## 🎮 MAPEO DE CONTROLES ACTUALIZADO

| Acción | Teclado Primario | Teclado Secundario | Gamepad / Mando |
| :--- | :--- | :--- | :--- |
| **Mover Izquierda / Derecha** | `Left` / `Right` | `KP 4` / `KP 6` | D-Pad L/R o Stick Izq |
| **Soft Drop (Caída Suave)** | `Down` | `KP 5` | D-Pad Down o Stick Abajo |
| **Hard Drop (Fijación)** | `Space` | — | `RB` / `RT` |
| **Rotación Horaria (CW)** | `A` | `Z` | Botón `A` / `B` |
| **Rotación Antihoraria (CCW)** | `D` | `X` | Botón `X` / `Y` |
| **Rotación 180°** | `Up` | `KP 8` | D-Pad `Up` |
| **Hold (Reserva)** | `S` | `C` | `LB` / `LT` |
| **Zone Mode** | `Q` | `E` | Gatillo `L2` / `R2` |
| **Cambio de Postura (Stance)** | `Tab` | `LShift` / `RShift` | `L3` / `R3` / `Back` |
| **Grabar Clip MP4 60FPS** | `F9` | — | — |
| **Pantalla Completa (16:9)** | `F11` | `Alt + Enter` | — |
| **Captura HD a Portapapeles** | `F12` | `F2` / `PrintScreen` | — |
| **Snapshot de Diagnóstico** | `F8` | — | — |
| **Reinicio Rápido** | `R` | — | `Start` |
| **Menú / Salir** | `Escape` | — | — |