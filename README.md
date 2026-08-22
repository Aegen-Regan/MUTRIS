📄 README.md (COMPENDIO TÉCNICO MAESTRO — REESCRITURA COMPLETA)

# 🕹️ MUTRIS: SYNTHETIC TRANSCENDENCE
> **El Super-Hub definitivo de Puzzles Competitivos, Estación DAW & Combate Sinestésico.**  
> *Desarrollado bajo arquitectura estricta Zero-Garbage Collection, Sincronización Acústica por Hardware, Físicas Multi-Ruleset y Sistemas Soulsborne / Monster Hunter.*

---

> ⚠️ **DIRECTIVA PRIMARIA PERMANENTE (REGLA DE ORO):**  
> El identificador de versión y la skin activa (`_G.ENGINE_VERSION = "MUTRIS v1.0.0" | SKIN: [NOMBRE_SKIN]`) **deben permanecer siempre visibles en la esquina inferior izquierda en todas las pantallas y estados del juego** (Menú, Duelos, Boss Hunt, Forja, Benchmark, DAW Lab, Ajustes, Pausa y Game Over) para garantizar la trazabilidad absoluta en capturas de pantalla y telemetría.

---

# 📑 ÍNDICE GENERAL

1. [VISIÓN & LAS 6 DIMENSIONES DEL MOTOR](#-visión--las-6-dimensiones-del-motor)
2. [LOS 5 MANDAMIENTOS SAGRADOS ZERO-GC](#-los-5-mandamientos-sagrados-zero-gc)
3. [ÁRBOL DE DIRECTORIOS DEL REPOSITORIO](#-árbol-de-directorios-del-repositorio)
4. [MOTORES Y SUBSISTEMAS ACTIVOS (DOCUMENTACIÓN TÉCNICA)](#-motores-y-subsistemas-activos)
   - 4.1. [Universal Multi-Ruleset Engine (Fase 21)](#41-universal-multi-ruleset-engine-fase-21)
   - 4.2. [Titan Multi-Board Assault & Boss Dynamics (Fases 16 y 18)](#42-titan-multi-board-assault--boss-dynamics-fases-16-y-18)
   - 4.3. [The Hunter's Forge & Cyber-Palico Drone (Fase 20)](#43-the-hunters-forge--cyber-palico-drone-fase-20)
   - 4.4. [Status Blights Engine (Fase 17)](#44-status-blights-engine-fase-17)
   - 4.5. [Pilot Benchmark & Calibration Suite (Fases 12 y 13)](#45-pilot-benchmark--calibration-suite-fases-12-y-13)
   - 4.6. [Motor Universal de 4 Skins & Shaders GLSL](#46-motor-universal-de-4-skins--shaders-glsl)
   - 4.7. [Sincronización Acústica, Camelot & The Punch](#47-sincronización-acústica-camelot--the-punch)
5. [EL CRONOGRAMA MAESTRO ESTRATÉGICO (26 FASES EN 4 CLUSTERS)](#-el-cronograma-maestro-estratégico)
6. [PRESUPUESTO DE RENDIMIENTO POR FRAME (144Hz / 240Hz)](#-presupuesto-de-rendimiento-por-frame)
7. [MATRIZ DE DIAGNÓSTICO & RESOLUCIÓN DE BUGS (TROUBLESHOOTING)](#-matriz-de-diagnóstico--resolución-de-bugs)
8. [MAPEO UNIVERSAL DE CONTROLES & HOTKEYS](#-mapeo-universal-de-controles--hotkeys)
9. [PROTOCOLO DE CONTINUIDAD PARA SESIONES DE IA](#-protocolo-de-continuidad-para-sesiones-de-ia)

---

# 👁️ VISIÓN & LAS 6 DIMENSIONES DEL MOTOR

**MUTRIS** fusiona seis dimensiones interconectadas en un ecosistema nativo en LÖVE2D:

1. **La Precisión Competitiva:** Tiempos de entrada al milisegundo (DAS/ARR/SDF milimétricos estilo *Jstris/TETR.IO*), físicas desacopladas a 144Hz / 240Hz y resolución nativa $1280 \times 720$ con escalado virtual centrado (*Letterbox/Pillarbox*).
2. **El Motor Multi-Ruleset Universal:** Alternancia al vuelo entre reglas modernas *Guideline SRS 180°*, físicas clásicas de arcade *TGM 20G Shirase (ARS)*, reglas retro *NES 1989* y polígonos extendidos *Pentomino 18*.
3. **La Estación de Audio Digital (DAW):** El tablero actúa como un sintetizador procedural analógico con modulación armónica por tonalidades Camelot, analizador de espectro de 32 bandas, *Dynamic Sidechain Ducking* y Audición de SFX en vivo.
4. **El Combate de Lucha & Soulsborne:** Posturas conmutables (*Rush, Bastion, Resonance*), ventana de 3 frames de *Kinetic Parry* con *Counter-Spikes*, barras de postura (*Poise*), aturdimientos con daño crítico $\times2.5$ (*Visceral Clears*) y *Status Blights* (*Frostbite, Bleed, Corrupción*).
5. **La Cacería Colosal (Monster Hunter DNA):** Batallas contra Ciber-Jefes de 3 tableros consecutivos (*Titan Multi-Board Assault*) con desmembramiento anatómico por columnas (*Horns, Core, Tail*), recolección de materiales legendarios (*Carves*) y el taller de forja *The Hunter's Forge* para crear joyas pasivas y equipar al dron *Cyber-Palico*.
6. **Inteligencia Auto-Evolutiva & Benchmark:** El *ARCHON Meta-Balancer* y la suite de evaluación interactiva *Pilot Benchmark*, que mide el CPR del jugador en 3 etapas y auto-calibra constantes matemáticas en disco de forma autónoma.

---

# 📜 LOS 5 MANDAMIENTOS SAGRADOS ZERO-GC

Todo código añadido al repositorio debe respetar estas 5 leyes de hierro:

* 🚫 **1. Cero Asignación en el Ciclo Principal (Zero-GC Loop):** Prohibido instanciar tablas vacías (`{}`), concatenar strings dinámicas con `..` dentro de `love.update` y `love.draw`, o crear fuentes con `newFont()` al vuelo (usar estrictamente `FontCache.get(size)`). Todo vector, matriz, partícula o búfer se pre-aloca al iniciar el motor.
* 🔊 **2. Reloj Amarrado a la Placa de Sonido:** Ningún temporizador crítico, beat o ventana de parry depende del `dt` de pantalla; todo pulsa según el contador de hardware de audio (`Source:tell("seconds")`).
* 👁️ **3. Prioridad Absoluta a la Legibilidad:** Ningún shader, halo o colapso visual puede comprometer la visibilidad milimétrica de la matriz y el *Ghost Piece* a velocidades extremas (3.0+ PPS).
* ⚙️ **4. Determinismo en Frame-Data:** Las patadas de pared, cuadros de invulnerabilidad, ventanas de parry y colas de basura se calculan en matemática discreta sin aproximaciones de punto flotante.
* 🎻 **5. Síntesis de Subgraves Cooperativa:** Los efectos de sonido se modulan en octavas bajas (30 Hz - 180 Hz) como instrumentos armónicos afinados a la tonalidad modal de la canción, sin saturar la música del usuario.

---

# 🗂️ ÁRBOL DE DIRECTORIOS DEL REPOSITORIO

```text
MUTRIS/
├── conf.lua                     -- Configuración de ventana (1280x720 Widescreen, VSync, 144/240Hz)
├── main.lua                     -- Kernel maestro, despacho de estados, escalado y error handler
├── input.lua                    -- Motor DAS/ARR/SDF milimétrico, lectura gamepad y status offsets
├── settings_manager.lua         -- Serialización y persistencia de ajustes en settings.json
├── audio_manager.lua            -- Síntesis procedural senoidal, Sidechain Ducking y rampa The Punch
├── music_manager.lua            -- Reloj de hardware de audio amarrado a Source:tell("seconds")
├── track_manager.lua            -- Extracción modal Camelot, mapeo cromático de notas y metadatos
├── track_editor.lua             -- Laboratorio DAW Widescreen: Timeline con Scrubber y espectrograma
├── .luarc.json                  -- Configuración de linter LuaJIT para LÖVE2D
│
├── core/                        -- Librerías base del motor y persistencia
│   ├── blackbox.lua             -- Flight recorder de 128 eventos, telemetría lateral y autopsias
│   ├── meta_balancer.lua        -- [F12] ARCHON AI: Auto-tuning y balance en game_balance.json
│   ├── benchmark_manager.lua    -- [F13] Suite de calibración de piloto en 3 etapas (Sprint/Duel/Pressure)
│   ├── ruleset_manager.lua      -- [F21] Selector maestro de reglas: Guideline, TGM 20G, NES, Pento
│   ├── clip_recorder.lua        -- Grabador MP4 60FPS sin ventanas CMD vía pipe Win32 nativo (F9)
│   ├── screenshot_helper.lua    -- Captura HD directa a portapapeles Windows (CF_DIB vía FFI - F12)
│   └── replay_manager.lua       -- Grabación y reproducción de replays binarios deterministas (.mutrisrec)
│
├── combat/                      -- Módulos de combate, cacería y sistemas Soulsborne
│   ├── combat_stances.lua       -- [F8] Posturas: Rush (1.5x Atk), Bastion (Parry), Resonance (20G)
│   ├── kinetic_parry.lua        -- [F9] Ventana de 3 frames, absorción 100% y Counter-Spike del 50%
│   ├── poise_system.lua         -- [F16] Postura del jefe, aturdimiento de 6s, 2.5x Visceral Clears y Furia
│   ├── part_breaking.lua        -- [F18] Anatomía por columnas (Cuernos, Núcleo, Cola) y desmembramiento
│   ├── hunting_forge.lua        -- [F20] Taller de forja, 5 joyas pasivas, 3 sockets y Dron Cyber-Palico
│   └── status_blights.lua       -- [F17] Estados alterados: Frostbite (DAS/ARR), Bleed y Corrupción
│
├── tetris/                      -- Lógica pura de la grilla, físicas y renderizado
│   ├── board.lua                -- Grid 10x40 (visible 21-40), marcos por skin, ground slam y popups
│   ├── piece.lua                -- Físicas Multi-Ruleset (SRS 180°, ARS, NES), ghost temático y 20G
│   ├── ai_bot.lua               -- Bot heurístico con DDA adaptativo 2.0 y radar Hole-Seeking
│   ├── theme_manager.lua        -- Gestor de 4 Skins en vivo (F5), menús divergentes y halos sólidos
│   ├── garbage_manager.lua      -- Offsetting reactivo de basura, colas de daño y multiplicadores
│   ├── anomaly_manager.lua      -- Gestor de 8 anomalías rítmicas con barra de progreso superior
│   ├── particle_system.lua      -- Pool de 200 partículas Zero-GC con estilos por skin
│   ├── pps_counter.lua          -- Búfer circular de 60 ranuras para media móvil de velocidad en 5s
│   ├── hud_center.lua           -- Marcador VS central temático (CRT wave, Arcade, Glass, Mandala)
│   ├── hud_panels.lua           -- Paneles HOLD/NEXT con centrado submétrico y barras de Zone/dB
│   ├── telemetry.lua            -- Tarjeta central temática (FPS, Tiempo monospace, Adrenalina)
│   ├── fog_layer.lua            -- Vignette volumétrica suave reactiva a la skin y al compás
│   ├── bloom_shader.lua         -- Shader GLSL con resplandor neón, refracción de lente y shockwaves
│   ├── font_cache.lua           -- Caché de fuentes tipográficas rasterizadas
│   ├── shaker.lua               -- Micro-sismos aislados por matriz gráfica push/pop
│   ├── randomizers/
│   │   └── 7bag.lua             -- Generador estándar Guideline sin repetición
│   └── rotation_systems/
│       ├── srs.lua              -- Tablas de Wall-Kick tridimensionales SRS y 180°
│       ├── ars.lua              -- [F21] Sistema de rotación ARS clásico para TGM 20G
│       └── nes.lua              -- [F21] Sistema de rotación rígido NES 1989 sin kicks
│
├── music/                       -- Pistas de audio (.mp3/.ogg) y metadatos (.json)
├── screenshots/                 -- Capturas guardadas en formato PNG sin compresión
└── saves/                       -- Perfiles DDA, forja (hunter_forge.json), balance y reportes

⚙️ MOTORES Y SUBSISTEMAS ACTIVOS
4.1. Universal Multi-Ruleset Engine (Fase 21)

El motor permite alternar dinámicamente entre 4 conjuntos de reglas físicas en core/ruleset_manager.lua:
Ruleset	Sistema Rotación	Gravedad	Lock Delay	Wall-Kicks	Hold / Hard Drop	Ghost Piece
01 // GUIDELINE MODERN	SRS Standard	0.8s (DDA)	0.50s (15 resets)	SRS 180° Kicks	Permitido (Infinito)	Activo
02 // TGM 20G SHIRASE	ARS (Arika)	20G Instantánea	0.30s (Sin reset)	ARS Asimétrico	Permitido	Activo (Faint)
03 // NES 1989 RETRO	NES 8-Bits	Clásica 1/2G	0.001s (Instant)	Sin Kicks	Desactivado	Desactivado
04 // PENTOMINO 18	SRS Polyomino	0.8s	0.55s (15 resets)	Poly-Kicks	Permitido	Activo
4.2. Titan Multi-Board Assault & Boss Dynamics (Fases 16 y 18)

El modo CYBER-BEAST HUNT transforma el combate en una batalla de Raid Colosal de 3 fases consecutivas (combat/boss_phases.lua):
code Text

    Anatomía por Columnas (Part Breaking):

        Columnas 1-3 // CUERNOS (600 HP): Al destruirlos, se desactivan los pulsos láser del jefe. Otorga material CHRONO-HORN.

        Columnas 4-7 // NÚCLEO (1400 HP): Posee un escudo pasivo del

                
        25%
        25%

              

        de reducción de daño. Al romperlo, queda expuesto y recibe

                
        +50%
        +50%

              

        de daño permanente. Otorga LEVIATHAN-CORE.

        Columnas 8-10 // COLA (800 HP): Al cortarla (Tail Severed), la basura que envía el jefe se reduce un

                
        −50%
        −50%

              

        . Otorga SEVERED-TAIL.

    Souls Poise & Visceral Clears:

        Llenar la barra de postura (

                
        280 pts
        280 pts

              

        ) provoca un Aturdimiento de 6 segundos (Stun State). El jefe queda paralizado y todas las líneas limpiadas infligen Daño Crítico

                
        ×2.5
        ×2.5

              

        .

        Regeneración de Postura: Si el jugador pasa más de

                
        3.5s
        3.5s

              

        sin atacar, la barra de postura del jefe decae a razón de

                
        25 pts/s
        25 pts/s

              

        .

4.3. The Hunter's Forge & Cyber-Palico Drone (Fase 20)

    Taller de Forja Interactivo (combat/hunting_forge.lua):

        Permite fabricar y equipar hasta 3 Joyas Pasivas usando los materiales recolectados:

            01 // REFLEX JEWEL:

                    
            +1
            +1

                  

            Frame en la ventana de Parry (4f total). (Coste: 2 Horns).

            02 // GROOVE JEWEL:

                    
            +1
            +1

                  

            Línea de ataque en Beat-Lock Groove Strikes. (Coste: 2 Horns, 1 Core).

            03 // BREAKER JEWEL:

                    
            +35%
            +35%

                  

            Daño directo a columnas de Jefes. (Coste: 2 Cores, 1 Tail).

            04 // IRONCLAD JEWEL:

                    
            −25%
            −25%

                  

            Basura entrante recibida. (Coste: 2 Tails).

            05 // ACCELERATOR JEWEL:

                    
            −10ms
            −10ms

                  

            en el retraso DAS. (Coste: 1 Horn, 1 Tail).

    Dron Cyber-Palico:

        Dron de soporte flotante con físicas de órbita junto a la matriz del jugador.

        Protocolo de Rescate (Emergency Barrier): Si la matriz de P1 alcanza altura crítica

                
        ≥14/20
        ≥14/20

              

        , el dron detona un escudo que anula automáticamente 3 líneas de basura (enfriamiento:

                
        45s
        45s

              

        ).

4.4. Status Blights Engine (Fase 17)

Framework universal de estados alterados en combat/status_blights.lua:

    ❄️ Frostbite (Congelación): Infligido por Tetris (4 líneas). Añade

            
    +60ms
    +60ms

          

    al DAS y

            
    +15ms
    +15ms

          

    al ARR por

            
    5.0s
    5.0s

          

    , volviendo el manejo pesado y gélido.

    🩸 Bleed (Hemorragia): Infligido por T-Spin Double / Triple. Drena salud rítmicamente en cada compás musical. Si no se cauteriza limpiando líneas en

            
    6.0s
    6.0s

          

    , inyecta 2 líneas de basura sólida.

    ⚡ Corruption (Corrupción / Magnetismo): Distorsión que genera micro-desplazamientos laterales involuntarios de piezas hacia las paredes cada

            
    1.5s
    1.5s

          

    .

4.5. Pilot Benchmark & Calibration Suite (Fases 12 y 13)

Suite de evaluación interactiva en 3 etapas (core/benchmark_manager.lua):

    Etapa 1 // Kinetic Sprint: Limpiar 20 líneas a máxima velocidad para medir PPS puro y eficiencia de entrada.

    Etapa 2 // Tactical Duel: Combate de 35s contra Bot adaptativo para medir Downstacking y Parries.

    Etapa 3 // Titan Pressure: Sobrevivir 25s ante inyección continua de basura sólida pesada.

    Fórmula CPR:

            
    CPR=(PPS×650)+(Parries×60)+(SurvRatio×450)+(Clears×25)
    CPR=(PPS×650)+(Parries×60)+(SurvRatio×450)+(Clears×25)

          

    .

    Auto-Calibración Atómica: Escribe en disco (settings.json, ai_profile.json, game_balance.json) asignando rangos oficiales (APEX TIER S+, ELITE TIER A, VETERAN TIER B, CADET TIER C) y fijando la velocidad del Bot un

            
    8%
    8%

          

    a

            
    15%
    15%

          

    por encima del ritmo real del usuario.

4.6. Motor Universal de 4 Skins & Shaders GLSL

Conmutador en tiempo real con tecla F5 / F6 (tetris/theme_manager.lua):

    🎛️ Skin 01 — CYBER-DAW HARDWARE RACK: Menú consola de audio con vúmetros LED analógicos de 8 segmentos, monitor CRT de osciloscopio en vivo, marcos metálicos con escuadras a 45°, vúmetro de ganancia en dB para Zone y ghost piece de barrido CRT.

    ⚡ Skin 02 — NEO-KINETIC STRIKE (Persona 5 / Fighting Game): Cintas trapezoidales diagonales a 12°, tramas halftone de cómic, cajas RESERVE/INCOMING, barra BURST de pelea y esquinas de impacto.

    💎 Skin 03 — HYPER-CLEAN ESPORTS GLASS: Dashboard de torneo en 2 columnas, tarjetas de cristal esmerilado translúcido, coordenadas [P1 // MATRIX 10x20] y cápsula de precisión vertical.

    🌌 Skin 04 — SINESTESIA CÓSMICA: Vacío estelar profundo con diamantes procedurales ◇, mandala sagrado HARMONY, anillos orbitales en HUD y medidor astral de resonancia.

    Halos Sólidos de Reinicio (R): Ráfaga densa e instantánea de

            
    0.28s
    0.28s

          

    con destello blanco central y onda de choque refractiva GLSL en pantalla completa.

4.7. Sincronización Acústica, Camelot & The Punch

    Reloj de Hardware Puro: MusicManager.getTime() consulta directamente Source:tell("seconds"), garantizando

            
    0.0 ms
    0.0 ms

          

    de desfasaje acumulativo.

    The Punch (Rampa de Adrenalina): Modula la energía de post-procesado con curva cúbica hacia el Drop de la canción.

    Beat-Lock Timing: Mide si el Hard Drop cae en la ventana de

            
    ±35 ms
    ±35 ms

          

    (

            
    ±45 ms
    ±45 ms

          

    en Resonance) otorgando Groove Strikes (+1 línea) y golpe de subgraves a 30 Hz.

👑 EL CRONOGRAMA MAESTRO ESTRATÉGICO
(26 Fases Organizadas por Arquitectura de Sistemas)

========================================================================================================
                     MUTRIS ENGINE: ESTADO DE PRODUCCIÓN (SISTEMAS ESTRATÉGICOS)
========================================================================================================
 ESTADO:  [✔️] COMPLETO     [🚧] EN DESARROLLO     [⏳] PLANIFICADO
========================================================================================================

 ── CLUSTER 1: CIERRE DEL BUCLE RPG, COMBATE & AUDIO ──────────────────────────────────────────────────
 [✔️] FASE 1  │ Core Engine Zero-GC, SRS 180°, Offsetting & DAS/ARR Competitivo
 [✔️] FASE 2  │ Reloj de Hardware por Placa de Sonido & Sync de Beat Puro (0.0 ms Desfasaje)
 [✔️] FASE 3  │ Síntesis Acústica Cooperativa & Afinación Modal Camelot (Sub-Bajos 30Hz)
 [✔️] FASE 4  │ Mapeo Universal de Teclado/Mandos con Persistencia JSON (settings.json)
 [✔️] FASE 5  │ Timeline DAW Interactivo con Scrubber, Marcador de Drop y Curvas de Energía
 [✔️] FASE 6  │ Dynamic Sidechain Ducking, Rack de Saturación Tanh y Audición de SFX en Vivo
 [✔️] FASE 7  │ Beat-Lock Timing: Ventana ±35ms, Groove Strikes (+1 Línea) & Pulso Subgrave
 [✔️] FASE 8  │ Stance Switching System: Rush (1.5x Atk), Bastion (Parry) & Resonance (20G)
 [✔️] FASE 9  │ Kinetic Parry: Ventana de 3 Frames, 100% Absorción & Counter-Spike del 50%
 [✔️] FASE 10 │ Zone Mode 3-Tiers: Tier 1 Holo-Cyan, Tier 2 Hyper Gold, Tier 3 Supernova
 [✔️] FASE 11 │ Gestor de Anomalías V2: Torus, Wormhole, Laser, Swap, Flip, Drain, Speed, Eclipse
 [✔️] FASE 16 │ Souls Dynamics: Barra de Postura, Stun 6s, Visceral Clears 2.5x & Titan Colossus 3 Fases
 [✔️] FASE 18 │ Anatomía por Columnas & Part Breaking (Cuernos, Núcleo, Cola) con Escombros
 [✔️] FASE 20 │ The Hunter's Forge & Cyber-Palico: Taller de Crafteo, 5 Joyas y Dron de Soporte
 [✔️] FASE 17 │ Status Blights: Frostbite (DAS/ARR), Bleed Rítmico y Corrupción Magnética
 [⏳] FASE 19 │ Chroma-Weaver Engine: Pentagrama HUD, Acordes y Recital Melódico Activo [Q]

 ── CLUSTER 2: NÚCLEO UNIVERSAL DE FÍSICAS & REGLAS ───────────────────────────────────────────────────
 [✔️] FASE 21 │ Multi-Ruleset Engine: Guideline Moderno, TGM 20G Shirase (ARS), NES 1989, Pentomino 18
 [⏳] FASE 22 │ Modos Híbridos: Push 1v1 Tug-of-War, Sandtrix Granular y Dynamic Waveform Grid

 ── CLUSTER 3: INTELIGENCIA ARTIFICIAL, APRENDIZAJE & CREATIVIDAD ─────────────────────────────────────
 [✔️] FASE 12 │ ARCHON META-BALANCER: IA Interna de Auto-Equilibrio Estadístico y Auto-Patches
 [✔️] FASE 13 │ DDA Heurística 2.0 & Pilot Benchmark Suite (Calibración Oficial de 3 Etapas)
 [✔️] FASE 15 │ Telemetría Centralizada en Vivo (Watermark Dinámico, PPS Dual, Flight Recorder)
 [⏳] FASE 14 │ Trainer Lab & Asistente Holográfico de Aperturas (DT Cannon, TKI, PC con Undo en Vivo)
 [⏳] FASE 24 │ Lua Scripting API con Sandbox _ENV Seguro & Paquetes Todo-en-Uno (.mutrispack)
 [⏳] FASE 23 │ Mutris Architect Studio: Grid Painter, Timeline Tracker y Lógica por Nodos

 ── CLUSTER 4: INFRAESTRUCTURA DEPORTIVA, RED & TRANSCENDENCIA ──────────────────────────────────────────
 [✔️] FASE 25 │ Pipeline Multimedia: MP4 60FPS Win32 Pipe (F9), Replays .mutrisrec y Screenshot F12
 [⏳] FASE 25b│ Rollback Netcode P2P (GGPO determinista) & Broadcast Esports Spectator HUD
 [⏳] FASE 26 │ Modo Historia "Synthetic Transcendence", Shaders 3D Voxel y Lanzamiento Multiplataforma
========================================================================================================

⚡ PRESUPUESTO DE RENDIMIENTO POR FRAME (144Hz / 240Hz)
Subsistema / Módulo	Tiempo Asignado	Estrategia de Optimización
Input & DAS/ARR Sampling	0.12 ms	Consulta directa y suma escalar sin polling pesado.
Físicas Multi-Ruleset (SRS/ARS/NES)	0.45 ms	Tablas pre-indexadas y operaciones matemáticas discretas.
IA Heurística (Bot & DDA)	0.40 ms	Búfer plano _sim_grid reutilizable de 400 posiciones en 1 barrido.
Boss Phases & Status Blights	0.20 ms	Verificación escalar de timers y partículas estáticas pre-alocadas.
Síntesis de Audio & Sidechain	0.30 ms	Streaming continuo y modulación por curvas tanh pre-calculadas.
Renderizado, Bloom & Shaders	2.20 ms	Post-procesado en Canvas GLSL único y FontCache centralizado.
TOTAL FRAME BUDGET CONSUMIDO	~3.67 ms	Margen libre

        
>60%
>60%

      

en 144Hz (

        
6.94ms
6.94ms

      

) y

        
>12%
>12%

      

en 240Hz (

        
4.16ms
4.16ms

      

).
🔍 MATRIZ DE DIAGNÓSTICO & RESOLUCIÓN DE BUGS
Síntoma / Error en Consola	Causa Raíz Técnica	Solución Ingenieril Aplicada
Loop or previous error loading module	Dependencia circular (require mutuo en cabecera).	Aplicar resolución perezosa (Lazy require) dentro de funciones en runtime.
Attempt to index local 'item' (number)	Se esperaba una tabla {lines=X} pero se recibió un número plano.	Validación de tipos defensiva: type(item) == "number" and item or item.lines.
Cajones vacíos ▯ en textos de combate	Caracteres Unicode (⚠, ★, ◇) no incluidos en la fuente rasterizada.	Saneamiento estricto a caracteres ASCII imprimibles y dibujado procedural de polígonos.
Texto de Game Over ilegible / sucio	El Flight Recorder central se traslucía por detrás del modal de victoria.	Ocultar eventos centrales en gameover y aplicar fondo opaco 1.0 con drop shadow.
Micro-tirones cada 4 segundos (GC Stutter)	Creación de tablas {} o llamadas a newFont() en draw() o update().	Migración obligatoria a pools estáticos y FontCache.get(size).
🎮 MAPEO UNIVERSAL DE CONTROLES & HOTKEYS
Acción	Teclado Primario	Teclado Secundario	Gamepad / Mando
Mover Izquierda / Derecha	Left / Right	KP 4 / KP 6	D-Pad L/R o Stick Izq
Soft Drop (Caída Suave)	Down	KP 5	D-Pad Down o Stick Abajo
Hard Drop (Fijación Instantánea)	Space	—	RB / RT
Rotación Horaria (CW)	A	Z	Botón A / Botón B
Rotación Antihoraria (CCW)	D	X	Botón X / Botón Y
Rotación 180°	Up	KP 8	D-Pad Up
Hold (Reserva de Pieza)	S	C	LB / LT
Zone Mode / Recital Melódico	Q	E	Gatillo L2 / R2
Cambio de Postura (Stance Switch)	Tab	LShift / RShift	L3 / R3 / Back
Conmutador de Skin en Vivo	F5 (Next) / F6 (Prev)	—	—
Grabar Clip MP4 60FPS (Win32 Pipe)	F9	—	—
Captura HD Lossless a Portapapeles	F12	F2 / PrintScreen	—
Snapshot de Diagnóstico Blackbox	F8	—	—
Pantalla Completa (16:9 Nativo)	F11	Alt + Enter	—
Reinicio Rápido & Rotación de Track	R	—	Start
Menú / Pausa / Salir	Escape	—	Start / Back
📋 PROTOCOLO DE CONTINUIDAD PARA SESIONES DE IA

Para garantizar que cualquier sesión de desarrollo futura continúe sin romper la arquitectura:

    Regla de Oro de Código Completo: Todo archivo Lua entregado debe enviarse 100% completo, listo para copiar y pegar directamente, sin omitir funciones ni colocar comentarios tipo ... (resto del código igual).

    Entrega de main.lua en 2 Bloques: Por razones de extensión y límites de visualización, main.lua se entrega siempre dividido en PARTE 1 (Variables, Load, Update y Menús) y PARTE 2 (Draw, Eventos, Teclado, Ratón y Gamepad).

    Mantenimiento Zero-GC: Queda terminantemente prohibido instanciar tablas {} dentro de funciones que corran frame a frame (love.update, love.draw, Board:update, Piece:draw).

    Respeto a la Directiva de Marca: La marca _G.ENGINE_VERSION .. " | SKIN: " .. ThemeManager.getCurrent().name debe mantenerse siempre en pantalla en x=16, y=698.