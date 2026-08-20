---@diagnostic disable: undefined-global
local BloomShader = {}

local shader_code = [[
    extern number u_energy;
    extern number u_pulse;
    extern number u_zone;
    extern number u_shock_time;
    extern vec2 u_shock_center;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = texture_coords;

        // Onda expansiva de distorsión (Shockwave)
        if (u_shock_time > 0.0 && u_shock_time < 1.0) {
            number dist = distance(screen_coords, u_shock_center);
            number wave_radius = u_shock_time * 650.0;
            number diff = dist - wave_radius;
            if (abs(diff) < 40.0) {
                number factor = (1.0 - abs(diff) / 40.0) * (1.0 - u_shock_time) * 0.025;
                vec2 dir = normalize(screen_coords - u_shock_center);
                uv += dir * factor;
            }
        }

        vec4 base = Texel(texture, uv);
        
        if (u_energy > 0.4 || u_zone > 0.05) {
            number shift = 0.0007 * (u_energy * 0.4 + u_zone * 0.6);
            base.r = Texel(texture, uv + vec2(shift, 0.0)).r;
            base.b = Texel(texture, uv - vec2(shift, 0.0)).b;
        }

        number blur = 0.0010 + (u_energy * 0.0006) + (u_zone * 0.0008);
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
        vec4 highlights = glow * smoothstep(0.60, 0.98, lum);

        number bloom_amount = 0.20 + (u_energy * 0.20) + (u_pulse * 0.10) + (u_zone * 0.20);
        vec4 result = base + highlights * bloom_amount;

        if (u_zone > 0.01) {
            result.rgb = mix(result.rgb, vec3(result.r * 0.85, result.g * 1.05, result.b * 1.25), u_zone * 0.25);
        }

        return result * color;
    }
]]

function BloomShader.init()
    BloomShader.supported = false
    BloomShader.shock_timer = 0
    BloomShader.shock_x = 400
    BloomShader.shock_y = 300
    local status_canvas, canvas = pcall(love.graphics.newCanvas, 800, 600)
    local status_shader, shader = pcall(love.graphics.newShader, shader_code)
    
    if status_canvas and status_shader then
        BloomShader.canvas = canvas
        BloomShader.shader = shader
        BloomShader.supported = true
    end
end

function BloomShader.triggerShockwave(x, y)
    BloomShader.shock_timer = 0.01
    BloomShader.shock_x = x or 400
    BloomShader.shock_y = y or 300
end

function BloomShader.update(dt)
    if BloomShader.shock_timer > 0 then
        BloomShader.shock_timer = BloomShader.shock_timer + dt * 1.8
        if BloomShader.shock_timer >= 1.0 then BloomShader.shock_timer = 0 end
    end
end

function BloomShader.beginDraw()
    if BloomShader.supported and BloomShader.canvas then
        love.graphics.setCanvas(BloomShader.canvas)
        love.graphics.clear(0, 0, 0, 0)
    end
end

function BloomShader.endDraw(is_zone)
    if BloomShader.supported and BloomShader.canvas and BloomShader.shader then
        love.graphics.setCanvas()
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 1)
        
        local energy = _G.TrackEnergyPunch or 0
        local pulse = _G.AudioBeatPulse or 0
        local zone = is_zone and 1.0 or 0.0

        BloomShader.shader:send("u_energy", energy)
        BloomShader.shader:send("u_pulse", pulse)
        BloomShader.shader:send("u_zone", zone)
        BloomShader.shader:send("u_shock_time", BloomShader.shock_timer)
        BloomShader.shader:send("u_shock_center", {BloomShader.shock_x, BloomShader.shock_y})

        love.graphics.setShader(BloomShader.shader)
        love.graphics.draw(BloomShader.canvas, 0, 0)
        love.graphics.setShader()
        love.graphics.pop()
    end
end

return BloomShader