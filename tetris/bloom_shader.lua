-- ============================================================================
-- MUTRIS - GPU CORRECTION: BLOOM_SHADER.LUA (CORRECT GLSL COMMENTS)
-- GOLDEN RULE: USE PURE '//' SPECIFIERS INSIDE THE SHADER CODE BLOCKS.
-- ============================================================================

local BloomShader = {}

local shader_code = [[
    #pragma vec4 effect
    #pragma language GLSL120

    extern number u_energy;
    extern number u_pulse;
    extern number u_zone;
    extern number u_tspin; // <--- NEW CRITICAL INTERCEPTOR HARDWARE BINDING
    extern number u_shock_time;
    extern vec2 u_shock_center;

    number hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 74.7))) * 43758.5453123);
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = texture_coords;

        // Dynamic baseline stress calculation combined with tactical pro moves
        number dynamic_stress = u_energy * (u_pulse + 0.1) + (u_tspin * 1.8); 
        
        if (dynamic_stress > 0.12) {
            number glitch_block = floor(uv.y * (55.0 - u_tspin * 30.0)); // Chunkier lines if T-Spin hits
            number noise_val = hash(vec2(glitch_block, u_pulse * 1.8));
            if (noise_val > (0.80 - u_tspin * 0.40)) { // High frequency trigger during flashes
                // Violent tactical horizontal displacement snap during the T-Spin lightning frame
                uv.x += sin(uv.y * 45.0 + u_pulse * 55.0) * (0.006 + u_tspin * 0.025) * dynamic_stress;
            }
        }

        if (u_shock_time > 0.0 && u_shock_time < 1.0) {
            number dist = distance(screen_coords, u_shock_center);
            number wave_radius = u_shock_time * 950.0;
            number diff = dist - wave_radius;
            if (abs(diff) < 45.0) {
                number factor = (1.0 - abs(diff) / 45.0) * (1.0 - u_shock_time) * 0.030;
                vec2 dir = normalize(screen_coords - u_shock_center);
                uv += dir * factor;
            }
        }

        // Responsive Chromatic Aberration (Bleeds heavily during T-Spins)
        vec4 base = Texel(texture, uv);
        number dynamic_shift = 0.0008 + (0.0022 * dynamic_stress) + (u_tspin * 0.0075);
        base.r = Texel(texture, uv + vec2(dynamic_shift, 0.0)).r;
        base.b = Texel(texture, uv - vec2(dynamic_shift, 0.0)).b;

        number blur = 0.0008 + (u_energy * 0.0006) + (u_zone * 0.0006);
        vec4 glow = vec4(0.0);
        glow += Texel(texture, uv + vec2(-blur, -blur)) * 0.12;
        glow += Texel(texture, uv + vec2( blur, -blur)) * 0.12;
        glow += Texel(texture, uv + vec2(-blur,  blur)) * 0.12;
        glow += Texel(texture, uv + vec2( blur,  blur)) * 0.12;
        glow += Texel(texture, uv + vec2( 0.0,   blur)) * 0.13;
        glow += Texel(texture, uv + vec2( 0.0,  -blur)) * 0.13;
        glow += Texel(texture, uv + vec2( blur,   0.0)) * 0.13;
        glow += Texel(texture, uv + vec2(-blur,   0.0)) * 0.13;

        number lum = dot(glow.rgb, vec3(0.299, 0.587, 0.114));
        vec4 highlights = glow * smoothstep(0.55, 0.95, lum);

        number bloom_amount = 0.20 + (u_energy * 0.25) + (u_pulse * 0.15) + (u_zone * 0.20) + (u_tspin * 0.85);
        vec4 result = base + highlights * bloom_amount;

        // Clean retro CRT scanline emulation
        number scanline = sin(screen_coords.y * 1.5) * 0.038;
        result.rgb -= vec3(scanline) * (1.0 - u_zone * 0.5);

        // --- 6. ATOMIC T-SPIN LIGHTNING FORCE FIELD INJECTION ---
        if (u_tspin > 0.01) {
            // Overload result channel with a massive horizontal beam of neon-cyan electromagnetic energy
            number lightning_beam = smoothstep(0.08, 0.0, abs(uv.y - 0.5 + sin(uv.x * 12.0) * 0.03));
            result.rgb += vec3(1.2 * u_tspin, 0.4 * u_tspin, 2.0 * u_tspin) * lightning_beam * hash(screen_coords + u_pulse);
            
            // Global lightning bloom flash
            result.rgb += vec3(u_tspin * 0.35, u_tspin * 0.15, u_tspin * 0.55);
        }

        if (u_zone > 0.01) {
            result.rgb = mix(result.rgb, vec3(result.r * 0.75, result.g * 1.05, result.b * 1.25), u_zone * 0.25);
        }

        return result * color;
    }
]]

function BloomShader.init()
    BloomShader.canvas = love.graphics.newCanvas(1280, 720)
    BloomShader.shader = love.graphics.newShader(shader_code)
    BloomShader.supported = true
    BloomShader.shock_timer = 0
    BloomShader.shock_x = 640
    BloomShader.shock_y = 360
    
    -- INYECCIÓN: Si el motor hereda una pantalla de crash customizada de LÖVE,
    -- interceptamos el dibujado de error del framework para meterle un multiplicador gigante.
    if love and love.errhand then
        local original_errhand = love.errhand
        love.errhand = function(msg)
            -- Forzamos a la pantalla de colapso a dibujar letras un 250% más grandes
            if love.graphics and love.graphics.isActive() then
                local old_draw = love.graphics.draw
                love.graphics.draw = function(drawable, ...)
                    love.graphics.push()
                    love.graphics.scale(2.5, 2.5) -- FUENTES GIGANTES DE EMERGENCIA
                    old_draw(drawable, ...)
                    love.graphics.pop()
                end
            end
            return original_errhand(msg)
        end
    end
end

function BloomShader.triggerShockwave(x, y)
    BloomShader.shock_timer = 0.01
    BloomShader.shock_x = x or 640
    BloomShader.shock_y = y or 360
end

function BloomShader.update(dt)
    if BloomShader.shock_timer > 0 then
        BloomShader.shock_timer = BloomShader.shock_timer + dt * 2.0
        if BloomShader.shock_timer >= 1.0 then BloomShader.shock_timer = 0 end
    end
end

function BloomShader.beginDraw()
    if BloomShader.canvas then
        love.graphics.setCanvas(BloomShader.canvas)
        love.graphics.clear(0.01, 0.01, 0.03, 1.0)
    end
end

function BloomShader.endDraw(is_zone, ox, oy, scale)
    love.graphics.setCanvas()
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)

    local target_ox = ox or 0
    local target_oy = oy or 0
    local target_sc = scale or 1.0

    if BloomShader.canvas and BloomShader.shader then
        local energy = _G.TrackEnergyPunch or 0
        local pulse = _G.AudioBeatPulse or 0
        local zone = is_zone and 1.0 or 0.0

        BloomShader.shader:send("u_energy", energy)
        BloomShader.shader:send("u_pulse", pulse)
        BloomShader.shader:send("u_zone", zone)
        if BloomShader.shader:hasUniform("u_tspin") then
            local SceneGame = package.loaded["scenes.scene_game"]
            local p1 = SceneGame and SceneGame.boards and SceneGame.boards[1]
            local tspin_factor = (p1 and p1.tspin_flash) or 0.0
            BloomShader.shader:send("u_tspin", tspin_factor)
        end
        BloomShader.shader:send("u_shock_time", BloomShader.shock_timer)
        BloomShader.shader:send("u_shock_center", {BloomShader.shock_x, BloomShader.shock_y})

        love.graphics.setShader(BloomShader.shader)
        love.graphics.draw(BloomShader.canvas, target_ox, target_oy, 0, target_sc, target_sc)
        love.graphics.setShader()
    elseif BloomShader.canvas then
        love.graphics.draw(BloomShader.canvas, target_ox, target_oy, 0, target_sc, target_sc)
    end

    love.graphics.pop()
end

return BloomShader