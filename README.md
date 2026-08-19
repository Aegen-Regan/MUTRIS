# 🕹️ TETRIS VERSUS OPT — ARCHIVO MAESTRO COMPLETO
## COMPENDIO TÉCNICO DE ARQUITECTURA, ZERO-GC, FÍSICA SRS & INYECCIÓN ACÚSTICA POR HARDWARE
### 🛠️ ESTADO DE SISTEMA: FASE 6 (PULIDO VISUAL) — VERSIÓN ESTABLE DESBUGUEADA AL 100%

---

## 💾 PARTE 1: CORE ENGINE, GRAVEDAD ZERO-GC & ENTORNO DE INPUT (DAS/ARR)

### 1. Estrategia Estricta Zero-Garbage Collection (Zero-GC)
Para garantizar un rendimiento estricto de **60 FPS estables** tanto en PC como en entornos embebidos (como la arquitectura ARM de la consola Nintendo 3DS), el bucle entero se diseñó bajo una política rígida de cero recolección de basura:

*   🚫 **Pre-alocación de Matrices:** Prohibido instanciar tablas vacías (`{}`) o duplicar diccionarios adentro de las funciones críticas `love.update` o `love.draw`.
*   🔄 **Reciclaje de Vectores:** Estructuras volátiles como la previsualización del panel NEXT (HUD), el cálculo de posiciones fantasmas (*Ghost Piece*) y las coordenadas de partículas se limpian reescribiendo valores numéricos en variables primitivas o tablas estáticas de fábrica.
*   🛡️ **Inmunidad al Linter:** Toda la manipulación de variables globales y puenteos cruzados se blindó mediante la inyección superior de directivas: 
    `---@diagnostic disable: undefined-global, param-type-mismatch`.

---

### 2. Geometría Rígida de la Rejilla Matrix (The Grid)
El campo de juego opera con una matriz matemática interna pura de **10 columnas de ancho por 40 filas de alto**:

*   👁️ **Filas Ocultas de Amortiguación (1 a 20):** Funcionan como el búfer de entrada de piezas aéreas, entorno de cálculo de Wall-Kicks pesados y la zona muerta donde el Bot Master analiza sus jugadas de forma predictiva.
*   📺 **Filas Visibles en Pantalla (21 a 40):** La ventana gráfica corta el renderizado aplicando un desplazamiento vertical matemático:
    `by = self.y + (r - 21) * 24 + 1`
    De esta forma, el usuario solo visualiza el bloque clásico inferior de combate de 20 filas de alto.
*   🔢 **Codificación Numérica Rígida de Celdas:**
    *   `0`: Vacío absoluto (Espacio reactivo a la opacidad del pulso musical).
    *   `1` a `7`: Segmentos fijos (*Tetrominos*) fijados con color neón nativo permanente.
    *   `8`: Bloques sólidos de líneas de basura (*Garbage Blocks*) pintados en gris metálico.

---

### 3. Parámetros Críticos de Competición de Entrada (`input.lua`)
Los motores de autorepetición rítmica se calibraron de forma matemática para simular las latencias exactas del Tetris de alta gama competitiva (*Guideline/Jstris/Tetrio*):

*   ⏱️ **DAS (Delayed Auto-Shift):** Clavado de forma estricta en **0.094 segundos** (~5.6 frames). Tiempo físico de espera con la tecla presionada antes de que el bloque empiece a patinar solo hacia el lateral.
*   ⚡ **ARR (Auto-Repeat Rate):** Fijado de forma matemática en **0.008 segundos** (<0.5 frames). Una vez vencido el DAS, el consumo iterativo de tiempo (`while Input.timers.left >= DAS do`) desplaza la pieza al borde instantáneamente.
*   🔽 **Soft Drop Factor (Caída Suave):** Reducido de forma masiva a **0.005 segundos**. Gatillado con la tecla `kp5`, genera un descenso inmediato vertical que se bloquea si el contador `spawn_timer > 0` para evitar escapes truchos de piezas o overlaps fantasma.
*   ⌨️ **Mapeo Físico de Teclas de Combate:**
    *   *Desplazamiento horizontal:* `kp4` (Izquierda) / `kp6` (Derecha), guiados por DAS/ARR.
    *   *Rotaciones:* `a` (Giro horario CW), `d` (Giro antihorario CCW).
    *   *Rotación Extrema 180°:* Mapeada en `kp8`.
    *   *Mecánica Global de Hold:* `s` (Intercambio de pieza en espera).
    *   *Activación Zone Mode:* `q` (Congelamiento temporal del tiempo).
    *   *Hard Drop Instantáneo:* `space` (Fija al cuadro y reinicia el ciclo).
    *   *Freno/Reinicio:* `r` (Dispara la rutina limpia de vaciado estructural `GlobalRestart`).

---

## 🔄 PARTE 2: SUPER ROTATION SYSTEM (SRS) & MECÁNICAS DE COMBATE AVANZADAS

### 1. Matrices de Rotación SRS y Wall-Kicks de Gracia
El motor implementa de forma matemática estricta la especificación del **Super Rotation System (SRS)** de competición, mapeando las colisiones a través de un búfer tridimensional precargado:

*   🔄 **Giro de Gracia 180°:** Integrado nativamente. Resuelve de forma instantánea desvíos complejos en pasillos de un solo bloque y permite la ejecución limpia de setups de alta gama como el *DT Cannon*.
*   ⏳ **Move Reset de Fijación:** El *Lock Delay* otorga un margen de **0.5 segundos** una vez que la pieza toca una superficie sólida. Cada rotación o desplazamiento horizontal exitoso (validado solo si la posición horizontal real cambia en `piece.lua`) reinicia el temporizador de fijación, con un límite máximo infranqueable de **15 movimientos consecutivos** para mitigar el estancamiento infinito.
*   🎯 **Detección Quirúrgica de T-Spin:** Evaluada en el archivo `tetris/piece.lua`. Revisa la geometría del tetromino T chequeando la ocupación de las **4 esquinas de la matriz de la pieza de 3x3**. Si al menos 3 esquinas están bloqueadas al momento de rotar, el juego convalida un *T-Spin*, multiplicando la salida del daño de ataque.


### 2. Tabla de Ataques y Multiplicadores Competitivos
La distribución del daño saliente por cada borrado de líneas se procesa a través del archivo modular `tetris/garbage_manager.lua`, guiado por la siguiente escala base de impacto:

*   💥 **Single / Double / Triple:** 0, 1 y 2 líneas enviadas respectivamente al oponente.
*   🔥 **Tetris (4 líneas):** 4 líneas de basura directa.
*   ⚡ **T-Spin Single / Double / Triple:** 2, 4 y 6 líneas enviadas respectivamente.
*   ⭐ **B2B (Back-to-Back Bonus):** Si ejecutas dos Tetris o dos T-Spins consecutivos sin limpiezas simples intermedias, se inyecta **+1 línea de basura extra** a la cola del rival.
*   📊 **Multiplicador de Combos:** Cada borrado consecutivo dentro de la misma ráfaga de piezas incrementa el daño de forma lineal continua (`+1, +1, +2, +2...`), premiando las jugadas de velocidad.

---

### 3. Cancelación de Ataques (Offsetting) y Deuda de Líneas
El sistema de defensa del juego opera con un buffer reactivo asimétrico para permitir el contraataque estratégico en tiempo real:

*   🛡️ **Offsetting Activo:** Si recibes un ataque del rival, la basura no entra inmediatamente a tu grilla. Se aloja en una cola lateral de espera (`garbage_queue`). Si en la siguiente jugada limpias líneas, estas **cancelan la basura en cola de forma matemática instantánea**, anulando el impacto del rival.
*   🕳️ **Agujeros Alineados:** Las líneas de basura que logran superar el offset e ingresan a la grilla se generan con un agujero de escape vertical alineado mediante una ranura aleatoria fija por ráfaga, permitiendo al jugador realizar un *Downstack* fluido.
*   🛑 **Límite de Entrada por Pieza:** Para evitar muertes súbitas injustas, se clavó un límite estricto de ingreso de un **máximo de 8 líneas de basura por cada pieza colocada**, inyectándose en el momento exacto del bloqueo de la pieza (`locked`) antes de spawnear el nuevo tetromino.

---

## 🎛️ PARTE 3: LAB DE INYECCIÓN EN LOTES (BATCH), MOUSE DROPDOWNS & PERMISOS FÍSICOS

### 1. Automatización Completa de la Carpeta `music/`
Se eliminó del código duro cualquier dependencia de archivos de audio por defecto. Al arrancar, el juego inicializa su lista escaneando directamente el directorio físico real `music/` dentro del Escritorio de Windows de forma automatizada mediante `TrackManager.init()`:

*   📁 **Detección Inteligente de Metadatos:** El juego escanea la carpeta. Si encuentra una pista (`base.mp3`), busca de inmediato un archivo `.json` de configuración acoplado (`base.json`). Si existe, precarga sus valores reales de BPM y Camelot; de lo contrario, la expone con el valor base (120 BPM) listo para calibrar en el Lab.

---

### 2. Suite Batch por Lotes e Interfaz Dinámica por Ratón
La suite de inyección admite arrastres masivos y control absoluto mediante el puntero del mouse, eliminando las configuraciones tediosas por teclado en el menú:

*   📦 **Modo Batch Continuo:** El usuario puede arrastrar y soltar múltiples canciones juntas sobre la ventana. El sistema las absorbe, limpia el búfer transitorio y las encola de forma secuencial en una lista de procesamiento masivo.
*   🖱️ **Menús Desplegables (Dropdown Overlays):** Al hacer clic con el mouse sobre las cajas flotantes del laboratorio, se despliegan capas visuales interactivas para modificar la raíz cromática fundamental (`C`, `C#`, `F#`...) y el modo armónico Camelot (`MAJOR` o `MINOR`).
*   🎛️ **Sliders de Regulación:** El BPM se regula manteniendo presionadas las flechas del teclado en ráfagas continuas automáticas fluidas guiadas por un entorno DAS/ARR interno en el propio editor de pistas.

---

### 3. Inyector `io.open` de Permisos Nativos de Windows
Para que las canciones no tengan que configurarse cada vez que se abre el videojuego, implementamos un bypass directo al sistema de archivos restringido de LÖVE2D:

*   🔓 **Bypass de Sandbox:** LÖVE2D obliga a escribir dentro de la carpeta oculta de AppData. Modificamos el backend en `track_manager.lua` para que use el módulo **`io.open` de Lua puro**.
*   💾 **Escritura Persistente al Lado del MP3:** Al darle al botón de Confirmar en el Lab, el juego inyecta el archivo `.json` de metadatos **físicamente adentro de la carpeta `music/` real de Windows, exactamente al lado de tu pista de audio**. Al iniciar el juego, este leerá la configuración acoplada de fábrica para siempre.

---

## 📊 PARTE 4: RELOJ DE HARDWARE, MICRO-SISMOS EN VIVO & THE DROP PUNCH SYSTEM

### 1. Detector Audio-Driven Sync (Reloj de Hardware)
Los temporizadores de parpadeo visual guiados por el procesador (`dt` en `love.update`) sufren de acumulación de micro-retrasos (*frame-dropping*), lo que causaba que la grilla se desfasara de la música a los pocos minutos de partida:

*   🔊 **Sincronización por Placa de Sonido:** Modificamos el reloj principal en `audio_manager.lua` para engancharlo al contador de hardware del canal de reproducción de audio activo (`MusicManager.getTime()`, que consulta `Source:tell("seconds")`).
*   🎯 **Precisión Milimétrica Inmune:** El pulso visual neón lee en qué milisegundo real está reproduciéndose el archivo de audio, calculando la fracción exacta del tempo (`fraction = current_beat - math.floor(current_beat)`). El parpadeo y bombeo del escenario van clavados al ritmo del Kick físico de tu tema, **garantizando un desfasaje de cero absoluto a lo largo del tiempo**.

---

### 2. Analizador de Espectrograma RMS en Vivo
Al cargar la canción, el juego simula un analizador de energía estructural basado en el reloj de hardware para generar la vibración envolvente del ambiente al estilo de los visualizadores clásicos de Windows Media Player:

*   📊 **32 Barras de Frecuencia Dinámicas:** Dibuja un ecualizador interactivo flotante en la base del laboratorio de sonido. Las barras calculan oscilaciones asimétricas de picos RMS en base al milisegundo de reproducción activa del stream.
*   📈 **Interpolación Lineal Suave (Lerp):** El suavizado de las barras evita saltos toscos o tirones visuales (`bars[i] = bars[i] + (target - bars[i]) * 15 * dt`), logrando una estela fluida de alta fidelidad que reacciona de inmediato si el tema se pone en pausa o se detiene.

---

### 3. El Motor de Adrenalina Visual (The Punch System)
El juego calcula segundo a segundo la intensidad de la canción en base a los metadatos de BPM, Nota y Modo Camelot configurados de forma permanente, desatando el caos visual de forma automatizada:

*   🌋 **Fase de Build-Up (Micro-Sismos Constantes):** Al ingresar a las subidas o partes tensas del tema menor, la rejilla de los bloques experimenta micro-sismos rítmicos constantes que se sacuden en `shaker.lua` al compás del bombo (`shake_x = shake_x + math.random(-4 * active_punch, 4 * active_punch)`).
*   🌈 **Fase de THE DROP (Clímax Psicodélico):** Cuando el contador de la placa de sonido cruza el umbral de energía (`_G.TrackEnergyPunch >= 0.95`), el marco neón grueso abandona su color cian estable y empieza a mutar cíclicamente por todo el espectro cromático del arcoíris mediante ondas senoidales de tiempo, expandiendo la caja del tablero un **6% extra** en cada pulso de bajo.

---

## 🎻 PARTE 5: SÍNTESIS ACÚSTICA COOPERATIVA & ORQUESTACIÓN DE EFECTOS DE CRISTAL

### 1. Afinación Acústica Cooperativa de Sub-Bajos Senoidales
Se erradicó por completo la música sintética procedural del pasado sobre los sonidos del juego para eliminar los choques rítmicos espantosos sobre tus pistas de audio personalizadas. Toda la síntesis analógica de LÖVE2D en `audio_manager.lua` se reenfocó estrictamente en efectos de sonido (SFX) que interactúan como **instrumentos integrados a la producción armónica de tu canción**:

*   🎹 **Transposición Grave de dos Octavas:** Mudamos las frecuencias base de `_G.PLAYER_NOTES` y `_G.BOT_NOTES` hacia las octavas profundas (`C2` a `B2` y `C3` a `B3`). Al emitirse como sub-bajos limpios, se empastan *por debajo* de tu `.mp3` sin molestar ni pinchar el oído.
*   🔗 **Afinación Simétrica Unificada:** Se eliminó la disonancia del Bot. Ahora, tanto tú como la Inteligencia Artificial comparten **estrictamente las mismas notas exactas de la escala Camelot activa** configurada en el Lab, transformando la partida entera en un remix armónico en vivo.
*   🌌 **Efecto de Eco Espacial (Estela de Aire):** Los clicks secos se reemplazaron por ondas senoidales etéreas con desvanecimientos exponenciales suaves (`math.exp(-decay * t)`) y un colchón de ruido blanco altamente amortiguado de fondo. Esto emula una reverberación espacial tridimensional, haciendo que los SFX parezcan nacer desde adentro de la mezcla de tu música.

---

### 2. Orquestación de Efectos Interactivos (Tetris Effect Vibe)
Cada movimiento y colocación de piezas añade arreglos musicales coherentes al entorno sonoro:

*   🎵 **Desplazamientos Melódicos:** Mover las piezas hacia los costados (`move`) ejecuta notas numéricas individuales de forma consecutiva, saltando cíclicamente entre la tónica, tercera y quinta del acorde Camelot activo. Desplazar la pieza arma una melodía fluida en tiempo real (`AudioManager.melody_step`).
*   💎 **Giro Armónico Suave:** Rotar la pieza (`rotate`) extrae el segundo índice de la tabla Camelot y lo duplica en frecuencia, generando un destello esbelto de cristal senoidal libre de colapsos matemáticos.
*   💨 **Hard Drop de Cristal Embozado:** Se eliminaron las ondas de sierra rústicas invasivas. Al clavar una pieza con Hard Drop, se dispara un acorde etéreo difuminado en bloque de tres notas senoidales en combinación con un sutil soplido de viento largo que decae en el fondo, modulando su afinación de tono según la fila física real (`self.y`) donde impactó la pieza.

✨ Cascadas Celestiales (Tetris & T-Spins): Completar un Tetris detona un arpegio polifónico glorioso ascendente a toda velocidad a través de AudioManager.playArpeggio que recorre la escala musical entera subiendo y bajando en octavas brillantes, coronado con un remate de impacto cinemático largo que celebra la jugada masiva.


## 🎛️ PARTE 6: AUDIO-DRIVEN ARCHITECTURE, INYECTOR DINÁMICO DE CANCIONES Y RELOJ MAESTRO

### 1. Backend de Extracción y Traducción Armónica (`track_manager.lua`)
La música de fondo (`BGM`) no es un elemento pasivo, sino el **núcleo modular que altera los parámetros físicos y la afinación armónica** de todo el juego:

*   📂 **Aislamiento de Archivos Nativos:** El juego inicializa su playlist escaneando el directorio físico real `music/`. Detecta archivos `.mp3` u `.ogg` y busca de forma binaria su contraparte `.json` acoplada de metadatos.
*   🎹 **Mapeo de Frecuencias Camelot:** Al cargar una pista, el inyector extrae los metadatos de Nota Raíz y Modo (`MAJOR` o `MINOR`). El motor traduce esa nota en hercios puros usando la tabla de intervalos estáticos `TrackManager.MODES` cruzados con la nota fundamental de `TrackManager.NOTE_FREQS` (ej: `["A"] = 440.00`).
*   ⚡ **Inyección Renglón por Renglón (Anti-Collision):** Para evitar que el recolector de basura de Lua colapse o que se multipliquen tablas enteras, la escala musical se desestructura de forma escalar estricta directo a las variables globales:
    `_G.PLAYER_NOTES = { base_octave * (scale_intervals or 1.0), base_octave * (scale_intervals or 1.189), ... }`
    Esto alimenta al sintetizador procedimental de `audio_manager.lua`, garantizando que cada sonido del juego esté perfectamente afinado con el acorde de la canción de fondo actual.

---

### 2. El Reloj Maestro por Hardware de la Placa de Sonido
Se eliminaron por completo los contadores basados en el delta time del frame (`dt`), ya que producían micro-desfasajes acumulativos inevitables (*audio-drift*):

*   🔊 **Anclaje al Stream de Audio:** El temporizador principal del juego se amarra directamente al contador interno de hardware de la placa de sonido mediante la función `MusicManager.getTime()`, la cual consulta directamente el búfer de reproducción del motor a través de `Source:tell("seconds")`.
*   🔢 **Matemática de Compás Pura (Inmunidad al Lag):** El cálculo del parpadeo del escenario se procesa frame a frame midiendo la fracción exacta del tempo de la canción según el BPM actual:
    `local beat_duration = (60 / AudioManager.current_bpm)`
    `local current_beat = play_time / beat_duration`
    `local fraction = current_beat - math.floor(current_beat)`
    Si `fraction < 0.09`, el flag `_G.AudioBeatPulse` se clava en `1.0`, logrando que el bombeo visual neón vaya perfectamente clavado al *Kick* físico de tu tema musical de forma de bucle infinita.

---

### 3. Rampa Maestra de Adrenalina (`The Punch System`)
La intensidad visual del escenario y las acciones de la Inteligencia Artificial se rigen de forma matemática lineal y cúbica a través de las variables globales de energía, calculadas de forma fotométrica según el punto exacto de la canción:

*   📈 **Procesamiento de Rampa Cúbica Progresiva:** En base a los segundos configurados para el Drop (`drop_second`) y la subida (`build_duration`), el juego procesa fotograma a fotograma el factor de adrenalina utilizando una progresión de suavizado cúbico:
    `local progress = (song_time - build_start) / build_len`
    `_G.TrackEnergyPunch = progress * progress * progress`
*   🤖 **Modulación de PPS del Bot Master:** La velocidad del rival es directamente proporcional a la adrenalina de la música. En la intro se mantiene frío en su base (`self.base_pps`), pero a medida que el tema sube, la rampa inyecta velocidad pura: `self.pps = self.base_pps + (_G.TrackEnergyPunch * 8.0)`, forzando al Bot Master a jugar a su clímax de 12.0 PPS en pleno Drop musical.
*   💾 **Bypass de Persistencia Física:** Al confirmar las ediciones en el Lab de Soundtrack, el módulo `io.open` rompe el sandbox restringido de LÖVE2D y genera el archivo `.json` de metadatos **directamente en el disco duro de Windows al lado de tu tema musical**, automatizando las cargas futuras de fábrica para siempre.

---

## 📈 PARTE 7: ROADMAP INMEDIATO DE DESARROLLO (FUTURO CERCANO)

Habiendo consolidado el Lab Batch interactivo por ratón, la persistencia física en disco de Windows, el motor acústico de sub-bajos etéreos, la barra de alerta de peligro roja interna estilo Jstris y la consola de diagnóstico en tiempo real de `telemetry.lua`, la agenda estricta del proyecto marca las siguientes prioridades:

1.  🎯 **Contador de PPS Flotantes en el Pasillo Central:** Diseñar e inyectar el cálculo matemático de piezas colocadas por segundo (Humano vs Bot) analizando los últimos 5 segundos de combate móvil a través del buffer circular de 60 ranuras. El indicador flotará con estética neón en medio del pasillo central (el espacio vacío entre ambos tableros) y encenderá alertas rojas si el Bot te supera en velocidad, o destellos cian si mantienes el liderazgo de carrera.
2.  🤖 **Calibración Heurística de la IA Master:** Pulir los pesos evaluadores de la Inteligencia Artificial en base a los combos del nuevo motor, impidiendo atascos algorítmicos en piezas simétricas (como la barra I o el cuadrado O) y optimizando su rendimiento en la ráfaga máxima de 12.0 PPS en dificultad Master durante el Drop.


---

## 🔍 CONSIDERACIONES TÉCNICAS FINALES & COMPORTAMIENTO DEL ENTORNO

### 1. Gestión de Estados Globales (`game_states.lua` & `main.lua`)
*   🎛️ **Menú de Selección de Dificultades:** Opera de forma estática leyendo la tabla `difficulties`. El cambio de nivel altera directamente el parámetro de velocidad base de la Inteligencia Artificial (`pps`) previo a la llamada limpia de `GlobalRestart()`.
*   💀 **Rutina de Game Over:** Se gatilla de forma simétrica si la pieza humana recién spawneada en el búfer de entrada (fila 21) da colisión negativa con `canMove`. Al presionar `space` o `return`, el estado limpia el tablero y regresa al menú de selección principal de forma segura.

---

### 🖼️ 2. Jerarquía de Renderizado y Máscaras Gráficas
*   📈 **Aislamiento de Matrices Gráficas:** Cada tablero encapsula sus efectos de sacudida llamando a `Shaker.apply(self)` e inyectando un bloque cerrado de `love.graphics.push()` y `love.graphics.pop()` de forma simétrica. Esto evita que el temblor de la grilla de un jugador contamine las coordenadas de renderizado del rival o desplace el marcador central del HUD.
*   🎭 **Recorte Visual de la Grilla (Fila 21 a 40):** El motor gráfico dibuja únicamente los bloques cuyos índices de fila estén por encima de 20. Los tetrominos que se deslicen o roten en el espacio de amortiguación aéreo (filas 1 a 20) se procesan matemáticamente en la lógica, pero permanecen completamente invisibles para el usuario humano para simular la interfaz oficial competitiva.

---

### ⚙️ 3. Sincronización del Rendimiento (Threading & Garbage Collector)
*   ⏳ **Inmunidad al Stuttering por Latencia:** Al haber extraído la carga de dependencias dinámicas (`require`) y la instanciación de objetos (`Piece.new`) fuera de las funciones críticas de dibujado (paneles NEXT y HOLD), el juego se encuentra operando bajo una arquitectura *Zero-GC compliant*. La recolección de basura de Lua permanece inactiva durante la partida, eliminando micro-tirones y congelamientos frame a frame.
*   🎮 **Bucle de Ejecución de Inputs Competitivos:** Para que los valores milimétricos del DAS y el ARR estilo *Jstris/Tetrio* se apliquen sin tirones, la lectura del teclado con `Input.update(dt)` corre de forma obligatoria al principio absoluto del frame dentro de `love.update(dt)`, procesando las banderas de movimiento de las piezas antes de que el motor gráfico calcule la gravedad de descenso vertical o el arrastre de las líneas de basura.







# 🕹️ MUTRIS v0.8.5 - ETHEREAL ENGINE
## ESTADO DE SISTEMA: FASE 6 (PULIDO AUDIOVISUAL FINAL)

---

## 💎 NUEVAS MECÁNICAS DE ESTA VERSIÓN

### 1. Sistema de "Ethereal Trails" (Estelas de Polvo Estelar)
Se eliminaron las estelas sólidas por un sistema de **haces de luz volumétricos** con decaimiento cuadrático.
*   **Partículas Internas:** Cada estela genera motas de polvo que caen físicamente hacia el tablero.
*   **Flicker Aditivo:** Las estelas parpadean aleatoriamente para simular descargas de energía.

### 2. Ghost Piece "Wired" (Estructura de Alambre Eléctrica)
La sombra ya no es un bloque; es un **contorno ondulante** reactivo.
*   **Danger Reaction:** A medida que la pila de bloques sube hacia el límite, la ondulación del Ghost se vuelve más violenta y errática.
*   **Beat Sync:** El esqueleto de la pieza vibra físicamente con cada pulso de bajo detectado por el hardware.

### 3. Kinetic Impact (Impacto de Suelo)
Los bloques que ya están fijos en el tablero tienen "conciencia" del aterrizaje de nuevas piezas.
*   **Lock Impact:** Al fijar una pieza, todo el tablero experimenta un pulso de escala (se agranda un 10%) y un destello interno masivo.
*   **Aura Disco:** Los bloques mantienen un núcleo oscuro y bordes eléctricos para garantizar legibilidad en altas velocidades.

---

## 🗺️ ROADMAP ACTUALIZADO (PROXIMOS PASOS)

1.  **SFX Harmonization:** Implementar un motor de reverberación para los efectos de sonido que escale con el `TrackEnergyPunch`. Los sonidos deben sonar "secos" en la intro y "espaciales" en el Drop.
2.  **Master AI Heuristics:** Calibrar el Bot para que realice T-Spins de forma intencional en dificultad Master durante el clímax musical.
3.  **Z-Depth Layering:** Añadir una capa de "niebla de color" detrás de los tableros que cambie de tono según la escala Camelot del track actual.

---

## 🛠️ CONSIDERACIONES TÉCNICAS
*   **Zero-GC Compliant:** Todo el sistema de estelas y partículas utiliza pools estáticos pre-alocados.
*   **Hardware Sync:** El parpadeo y la ondulación están anclados al buffer de la placa de sonido, garantizando desfasaje cero.