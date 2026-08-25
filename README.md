# 🕹️ MUTRIS: SYNTHETIC TRANSCENDENCE
> **El Super-Hub definitivo de Puzzles Competitivos, Estación DAW & Combate Sinestésico.**  
> *Desarrollado bajo arquitectura estricta Zero-Garbage Collection, Motor de Layouts Paramétrico, Físicas Multi-Ruleset y Preparación para Audio ASMR en SuperCollider y Super-IA en Rust.*

---

> ⚠️ **DIRECTIVA PRIMARIA PERMANENTE (REGLA DE ORO):**  
> La marca de agua enriquecida permanente (`_G.ENGINE_VERSION .. " | SCENE: " .. scene_label .. " | SKIN: " .. skin_name .. " | " .. fps .. " FPS | RAM: " .. ram .. " MB"`) **debe permanecer siempre visible en la esquina inferior izquierda en todas las pantallas y estados del juego (x=16, y=698)** para garantizar la trazabilidad absoluta en capturas y telemetría.

---

# 📑 ÍNDICE GENERAL

1. [VISIÓN & LAS 5 DIMENSIONES DEL MOTOR](#-visión--las-5-dimensiones-del-motor)
2. [STACK TECNOLÓGICO MAESTRO & ARQUITECTURA HÍBRIDA](#-stack-tecnológico-maestro--arquitectura-híbrida)
3. [LOS 5 MANDAMIENTOS SAGRADOS ZERO-GC](#-los-5-mandamientos-sagrados-zero-gc)
4. [ÁRBOL DE DIRECTORIOS DEL REPOSITORIO](#-árbol-de-directorios-del-repositorio)
5. [SUBSISTEMAS ACTIVOS & REGLAS DE COMBATE](#-subsistemas-activos--reglas-de-combate)
   - 5.1. [Universal Multi-Ruleset Engine (Fase 21)](#51-universal-multi-ruleset-engine-fase-21)
   - 5.2. [Titan Boss Raid & Part Breaking (Fase 18)](#52-titan-boss-raid--part-breaking-fase-18)
   - 5.3. [The Hunter's Forge & Cyber-Palico Drone (Fase 20)](#53-the-hunters-forge--cyber-palico-drone-fase-20)
   - 5.4. [Kinetic Parry & Counter-Spikes (Fase 9)](#54-kinetic-parry--counter-spikes-fase-9)
   - 5.5. [LayoutSolver & Multi-Bot Battle Royale (Fase 4.8)](#55-layoutsolver--multi-bot-battle-royale-fase-48)
   - 5.6. [Audio Manager, Beat-Lock & Rotación de Pistas (Fases 2, 3 y 7)](#56-audio-manager-beat-lock--rotación-de-pistas-fases-2-3-y-7)
   - 5.7. [Pipeline Visual de 4 Skins & Shaders GLSL](#57-pipeline-visual-de-4-skins--shaders-glsl)
   - 5.8. [ARCHON DDA 2.0 & Pilot Benchmark Suite (Fases 12 y 13)](#58-archon-dda-20--pilot-benchmark-suite-fases-12-y-13)
6. [MAPEO UNIVERSAL DE CONTROLES & HOTKEYS](#-mapeo-universal-de-controles--hotkeys)

---

# 👁️ VISIÓN & LAS 5 DIMENSIONES DEL MOTOR

**MUTRIS** fusiona cinco dimensiones de alto rendimiento:

1. **La Precisión Competitiva:** Tiempos de entrada al milisegundo (DAS/ARR/SDF milimétricos estilo *Jstris/TETR.IO*), físicas desacopladas a 144Hz/240Hz y resolución nativa $1280 \times 720$ con escalado virtual centrado.
2. **El Motor Multi-Ruleset Universal:** Alternancia al vuelo entre reglas modernas *Guideline SRS 180°*, físicas clásicas de arcade *TGM 20G Shirase (ARS)*, reglas retro *NES 1989* y polígonos extendidos *Pentomino 18*.
3. **La Estación DAW & Audio Sinestésico:** Backend de sonido con síntesis procedural, subgraves de 30Hz con saturación `tanh`, reloj anclado a hardware (`Source:tell("seconds")`), modulación por rueda armónica Camelot y preparación para *SuperCollider scsynth*.
4. **La Cacería de Jefes & Forja (Monster Hunter DNA):** Batallas colosales con escala "David vs Goliat", desmembramiento anatómico por columnas (*Horns, Core, Tail*), botines (*Carves*), taller de joyas pasivas y dron orbital *Cyber-Palico*.
5. **Inteligencia Adaptativa & Battle Royale:** DDA ARCHON 2.0 que ajusta la velocidad del Bot al $110\%$ del ritmo del usuario, suite *Pilot Benchmark* y modo Multi-Bot "Último en Pie" (*Last Man Standing*).

---

# 🏗️ STACK TECNOLÓGICO MAESTRO

| Capa / Subsistema | Tecnología / Lenguaje | Función Principal |
| :--- | :--- | :--- |
| **Kernel / Loop Principal** | **LuaJIT + LÖVE2D (v11.5)** | Hot loop a 240Hz, inputs DAS/ARR, físicas de grilla y combate Zero-GC. |
| **Arquitectura de Layout** | **`core/layout_solver.lua`** | Anclas matemáticas y cálculo de zonas seguras con cero solapamientos. |
| **Super-IA Táctica** | **Rust** (`mutris_archon.dll`) | Alpha-Beta Beam Search, Bitboards de 64-bits y evaluación multihilo. |
| **Motor de Audio & ASMR** | **SuperCollider (`scsynth`)** | Síntesis analógica/FM viva, resonancia modal Klank y subgraves de 30Hz. |
| **Post-Procesado & Shaders** | **GLSL Multi-Pass** | Destellos neón Tanh, refracción GLSL y barrido blanco nuclear en tecla 'R'. |
| **Suite de Edición** | **Dear ImGui (FFI)** | Interfaz in-game para crear niveles, balancear jefes y editar timelines DAW. |
| **Persistencia** | **JSON Estricto** | Guardado de ajustes (`settings.json`), balance, perfiles y forja. |

---

# 📜 LOS 5 MANDAMIENTOS SAGRADOS ZERO-GC

* 🚫 **1. Cero Asignación en el Ciclo Principal (Zero-GC Loop):** Prohibido instanciar tablas vacías (`{}`), concatenar strings dinámicas con `..` dentro de `update` y `draw`, o crear fuentes al vuelo (usar estrictamente `FontCache.get(size)`).
* 🔊 **2. Reloj Amarrado a la Placa de Sonido:** Todo beat y cálculo de ventana rítmica pulsa según el contador de hardware de audio (`Source:tell("seconds")`).
* 👁️ **3. Prioridad Absoluta a la Legibilidad:** Ningún shader o halo puede comprometer la visibilidad milimétrica de la matriz y el *Ghost Piece* a velocidades extremas (3.0+ PPS).
* ⚙️ **4. Determinismo en Frame-Data:** Patadas de pared, ventanas de parry y colas de basura se calculan en matemática discreta sin aproximaciones de punto flotante.
* 🎻 **5. Síntesis de Subgraves Cooperativa:** Los efectos de sonido se modulan en octavas bajas (30 Hz - 180 Hz) como instrumentos armónicos afinados a la tonalidad modal de la canción.

---

# 🗂️ ÁRBOL DE DIRECTORIOS DEL REPOSITORIO

```text
MUTRIS/
├── conf.lua                     -- Configuración de ventana (1280x720 Widescreen, VSync, 240Hz)
├── main.lua                     -- Kernel maestro, despacho de escenas y marca de agua permanente
├── input.lua                    -- Motor DAS/ARR/SDF milimétrico y lectura de gamepad Zero-GC
├── settings_manager.lua         -- Serialización y persistencia de ajustes en settings.json
├── audio_manager.lua            -- Síntesis de subgraves 30Hz, sidechain ducking y rampa The Punch
├── music_manager.lua            -- Reloj de hardware de audio tell("seconds") y control de BGM
├── track_manager.lua            -- Extracción modal Camelot, mapeo cromático de notas y metadatos
├── track_editor.lua             -- Timeline DAW con Scrubber, analizador de espectro y curvas
│
├── core/                        -- Librerías base del motor y persistencia
│   ├── layout_solver.lua        -- [CORE] Solucionador de anclas y distribución paramétrica Zero-GC
│   ├── scene_manager.lua        -- Orquestador de escenas basado en pila (push/pop/setState)
│   ├── ruleset_manager.lua      -- Selector maestro de reglas: Guideline, TGM 20G, NES, Pento 18
│   ├── meta_balancer.lua        -- ARCHON AI: Auto-tuning autónomo y balance en game_balance.json
│   ├── benchmark_manager.lua    -- Suite de calibración de piloto en 3 etapas (Sprint/Duel/Pressure)
│   ├── blackbox.lua             -- Flight recorder de 128 eventos y telemetría central
│   ├── clip_recorder.lua        -- Grabador MP4 60FPS sin ventanas CMD vía pipe Win32 nativo (F9)
│   ├── screenshot_helper.lua    -- Captura HD directa a portapapeles Windows (CF_DIB vía FFI - F12)
│   └── replay_manager.lua       -- Grabación y reproducción de replays binarios (.mutrisrec)
│
├── combat/                      -- Módulos de combate y cacería
│   ├── kinetic_parry.lua        -- Ventana de 3 frames, absorción 100%, hitstop y Counter-Spike
│   ├── part_breaking.lua        -- Anatomía por columnas (Cuernos, Núcleo, Cola) y escombros físicos
│   └── hunting_forge.lua        -- Taller de forja, 5 joyas pasivas, 3 sockets y Dron Cyber-Palico
│
├── scenes/                      -- Escenas modulares del motor
│   ├── scene_game.lua           -- Escena principal de gameplay, Battle Royale y modal de victoria
│   └── scene_editor.lua         -- Selector interactivo de payloads y presets del Editor Lógico
│
├── tetris/                      -- Lógica pura de grilla, físicas y renderizado
│   ├── board.lua                -- Grid 10x40 (visible 21-40), marcos por skin y popups
│   ├── piece.lua                -- Físicas Multi-Ruleset (SRS 180°, ARS, NES), ghost y T-Spin 3-Corner
│   ├── ai_bot.lua               -- Bot heurístico con DDA adaptativo 2.0 y radar Hole-Seeking
│   ├── theme_manager.lua        -- Gestor de 4 Skins en vivo (F5), menús y Halo de Reinicio 'R'
│   ├── garbage_manager.lua      -- Offsetting reactivo de basura, colas de daño y combos
│   ├── anomaly_manager.lua      -- Gestor de 8 anomalías rítmicas con barra de progreso superior
│   ├── particle_system.lua      -- Pool de 200 partículas Zero-GC con estilos por skin
│   ├── pps_counter.lua          -- Búfer circular de 60 ranuras para media móvil de velocidad en 5s
│   ├── hud_center.lua           -- Marcador VS central temático paramétrico (Harmony / Speed)
│   ├── hud_panels.lua           -- Paneles HOLD/NEXT adaptativos de 56px con centrado submétrico
│   ├── telemetry.lua            -- Tarjeta central de telemetría y dashboard inferior Multi-Bot
│   ├── fog_layer.lua            -- Vignette volumétrica suave reactiva a la skin y al compás
│   ├── bloom_shader.lua         -- Shader GLSL con resplandor neón y shockwaves refractivas
│   ├── font_cache.lua           -- Caché de fuentes tipográficas rasterizadas
│   ├── shaker.lua               -- Micro-sismos aislados por matriz gráfica push/pop
│   ├── randomizers/7bag.lua     -- Generador estándar Guideline sin repetición
│   └── rotation_systems/        -- Tablas de patadas de pared (srs.lua, ars.lua, nes.lua)
│
├── music/                       -- Pistas de audio (.mp3/.ogg) y metadatos (.json)
├── screenshots/                 -- Capturas guardadas en formato PNG sin compresión
└── saves/                       -- Perfiles DDA, forja (hunter_forge.json), balance y reportes