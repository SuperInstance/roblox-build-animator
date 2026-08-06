"""
Test utilities for Luau→Lua5.1 preprocessing.

Provides strip_luau_types() and LuaRunner for use across all test modules.
"""
import os
import re
import subprocess
import tempfile

LUA_BIN = "/usr/bin/lua5.1"

MOCK_HARNESS_LUA = r"""
-- ===== Mock Roblox Environment for Lua 5.1 =====
-- Written as a proper Lua file (loaded via dofile from temp file).

local _inst_mt = {}
_inst_mt.__index = function(t, k)
    if k == "IsA" then return function(self, ty) return (self._isa and self._isa[ty]) or false end end
    if k == "FindFirstChild" then return function(self, n)
        if not self.children then return nil end
        for _, c in ipairs(self.children) do if c.Name == n then return c end end
        return nil
    end end
    if k == "WaitForChild" then return function(self, n)
        if not self.children then return nil end
        for _, c in ipairs(self.children) do if c.Name == n then return c end end
        return nil
    end end
    if k == "GetChildren" then return function(self) return self.children or {} end end
    if k == "Destroy" then return function(self) self.Parent = nil end end
    if k == "Play" then return function(self) self._played = true end end
    if k == "Stop" then return function(self) self._stopped = true end end
    if k == "Connect" then return function(self, ev, cb)
        return {Disconnect = function() end}
    end end
    if k == "GetPivot" then return function(self)
        return {Position = self.Position or {X=0, Y=0, Z=0}}
    end end
    if k == "GetPlayers" then return function(self) return self._players or {} end end
    if k == "GetPlayerFromCharacter" then return function(self, char)
        if not self._players then return nil end
        for _, p in ipairs(self._players) do if p.Character == char then return p end end
        return nil
    end end
    if k == "GetPartBoundsInRadius" then return function(self, pos, radius, params)
        return self._mockParts or {}
    end end
    if k == "AddItem" then return function(self, item, time) end end
    if k == "JSONEncode" then return function(self, t) return "{}" end end
    if k == "JSONDecode" then return function(self, s) return {decoded=true} end end
    if k == "GenerateGUID" then return function(self, wrap)
        _G._guid_counter = (_G._guid_counter or 0) + 1
        return "test-guid-" .. tostring(_G._guid_counter)
    end end
    if k == "PostAsync" then return function(self, url, body)
        _G._lastPostUrl = url
        _G._lastPostBody = body
        return '{"success": true, "assets": [{"name": "test", "type": "Part"}]}'
    end end
    if k == "StartListeningAsync" then return function(self, cb) end end
    if k == "StopListeningAsync" then return function(self) end end
    if k == "SynthesizeTextAsync" then return function(self, text, cb)
        if cb then cb({AudioUrl = "rbxassetid://fake"}) end
    end end
    if k == "Create" then return function(self, obj, info, props)
        return setmetatable({Play = function() end, _obj = obj, _props = props}, {
            __index = function(t, k2)
                if k2 == "Completed" then
                    return {Connect = function(_, cb) return {Disconnect = function() end} end}
                end
                return rawget(t, k2)
            end
        })
    end end
    if k == "ToHSV" then return function(self)
        return self.R or 0, self.G or 0, self.B or 0
    end end
    if k == "Emit" then return function(self, count) end end
    return rawget(t, k)
end

local function mkinst(cls)
    local inst = {
        ClassName = cls, Name = cls, children = {},
        _isa = {Instance = true},
        Position = {X = 0, Y = 0, Z = 0},
        Size = {X = 1, Y = 1, Z = 1},
        Material = {Name = "Plastic"},
        Color = {R = 0.5, G = 0.5, B = 0.5},
        Transparency = 0, Anchored = false,
        CanCollide = true, CanQuery = true,
        Volume = 1.0, PlaybackSpeed = 1.0,
        SoundId = "", Looped = false, TimeLength = 2.0,
        CFrame = {Position = {X=0, Y=0, Z=0}},
        X = 0, Y = 0, Z = 0,
    }
    inst._isa[cls] = true
    if cls == "BindableEvent" then
        inst.Event = {Connect = function(_, cb) return {Disconnect = function() end} end}
        inst.Fire = function() end
    end
    if cls == "Part" or cls == "MeshPart" then
        inst._isa.BasePart = true
        inst._isa.PVInstance = true
    end
    setmetatable(inst, _inst_mt)
    return inst
end

Instance = setmetatable({}, {
    __index = function(t, k)
        if k == "new" then return function(cls) return mkinst(cls) end end
    end
})

game = setmetatable({PlaceId = 12345, ClassName = "DataModel", _isa = {Instance=true}}, _inst_mt)
game.GetService = function(self, name) return mkinst(name) end

workspace = mkinst("Workspace")
workspace._isa.Workspace = true

Enum = setmetatable({}, {
    __index = function(t, k)
        local cat = setmetatable({}, {
            __index = function(_, k2)
                return {Name = k .. "." .. k2, Value = 0}
            end
        })
        rawset(t, k, cat)
        return cat
    end
})

local v3mt = {}
v3mt.__index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X^2 + t.Y^2 + t.Z^2) end
    return rawget(t, k)
end
v3mt.__add = function(a, b) return setmetatable({X=a.X+b.X, Y=a.Y+b.Y, Z=a.Z+b.Z}, v3mt) end
v3mt.__sub = function(a, b) return setmetatable({X=a.X-b.X, Y=a.Y-b.Y, Z=a.Z-b.Z}, v3mt) end
v3mt.__mul = function(a, s)
    if type(a) == "number" then a, s = s, a end
    return setmetatable({X=a.X*s, Y=a.Y*s, Z=a.Z*s}, v3mt)
end
v3mt.__tostring = function(self) return string.format("Vector3(%f, %f, %f)", self.X, self.Y, self.Z) end

Vector3 = {}
Vector3.new = function(x, y, z) return setmetatable({X=x, Y=y, Z=z}, v3mt) end
Vector3.Magnitude = function(v) return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end

CFrame = {}
CFrame.new = function(p)
    return setmetatable({Position = p, X = p.X, Y = p.Y, Z = p.Z}, {
        __sub = function(a, b)
            return setmetatable({X=a.X-b.X, Y=a.Y-b.Y, Z=a.Z-b.Z}, {__index = function() return nil end})
        end,
        __mul = function(a, b) return a end,
        __index = function(t, k) return rawget(t, k) end,
    })
end

Color3 = {}
Color3.new = function(r, g, b) return {R=r, G=g, B=b, ToHSV = function(self) return self.R, self.G, self.B end} end
Color3.fromRGB = function(r, g, b) return {R=r/255, G=g/255, B=b/255, ToHSV = function(self) return self.R, self.G, self.B end} end
Color3.fromHSV = function(h, s, v) return {R=h, G=s, B=v, ToHSV = function(self) return self.R, self.G, self.B end} end

ColorSequence = function(c) return {Color = c} end
NumberSequence = function(...) return {keypoints = {...}} end
NumberRange = function(a, b) return {min = a, max = b} end
Vector2 = {new = function(x, y) return {X=x, Y=y} end}
TweenInfo = {new = function() return {} end}
OverlapParams = {new = function() return {FilterType = {}, FilterDescendantsInstances = {}, MaxParts = 100} end}
Debris = {AddItem = function() end}

task = {delay = function() end, wait = function() end, spawn = function() end, clear = function(t) for k in pairs(t) do t[k] = nil end end}

script = {Parent = {}}
script.Parent.AmbientLayer = mkinst("ModuleScript")
script.Parent.AmbientLayer.Name = "AmbientLayer"

table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
if not table.clone then
    table.clone = function(t)
        local c = {}
        for k, v in pairs(t) do c[k] = v end
        setmetatable(c, getmetatable(t))
        return c
    end
end

unpack = unpack or table.unpack

local _orig_typeof = typeof or function(v) return type(v) end
typeof = function(v)
    local t = _orig_typeof(v)
    if t == "table" and v and v.ClassName then return "Instance" end
    return t
end

os.time = os.time or function() return 1700000000 end
os.clock = os.clock or function() return 0 end

-- require mock: returns a pre-loaded module table if available, else empty table
require = function(path)
    if type(path) == "string" then
        return _G[path] or {}
    end
    -- If path is a table (like script.Parent.AmbientLayer), look up by name
    if type(path) == "table" and path.Name then
        return _G[path.Name] or {}
    end
    return {}
end

math.clamp = math.clamp or function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
warn = function() end
print = function() end

-- ===== End Mock =====
"""


def strip_luau_types(code: str) -> str:
    """Strip Luau type annotations for Lua 5.1 compatibility.

    Handles: export type/type blocks, function param & return annotations,
    local var annotations, self.field annotations, table field annotations,
    compound assignment operators (+=, -=).
    """

    # Phase 1: Remove type declaration blocks (export type / type Name = { ... })
    lines = code.split('\n')
    result = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r'^\s*(export\s+)?type\s+\w+\s*=', line) and 'function' not in line:
            brace_count = line.count('{') - line.count('}')
            if brace_count > 0:
                # Multi-line: skip until braces balanced
                i += 1
                while i < len(lines) and brace_count > 0:
                    brace_count += lines[i].count('{') - lines[i].count('}')
                    i += 1
                continue
            elif '{' in line:
                # Single-line type with braces
                i += 1
                continue
            else:
                # type X = SomeReference (no braces)
                i += 1
                continue
        result.append(line)
        i += 1

    code = '\n'.join(result)

    # Phase 2: Per-line transformations
    lines = code.split('\n')
    result = []

    for line in lines:
        # ── Compound assignment ──
        m = re.match(r'^(\s*)([\w.\[\]"\'\]]+)\s*\+=\s*(.+)$', line)
        if m:
            line = f"{m.group(1)}{m.group(2)} = {m.group(2)} + ({m.group(3)})"
        m = re.match(r'^(\s*)([\w.\[\]"\'\]]+)\s*-=\s*(.+)$', line)
        if m:
            line = f"{m.group(1)}{m.group(2)} = {m.group(2)} - ({m.group(3)})"

        # ── Function definitions: strip params and return types ──
        # Unified handler for all function patterns
        fm = re.match(r'^(\s*)(local\s+)?function\s+([\w.:]+)\s*\(', line)
        if fm:
            indent = fm.group(1)
            local_kw = fm.group(2) or ''
            func_name = fm.group(3)
            paren_start = line.index('(', fm.start())

            # Find matching close paren
            depth = 0
            close_idx = -1
            for j in range(paren_start, len(line)):
                if line[j] == '(':
                    depth += 1
                elif line[j] == ')':
                    depth -= 1
                    if depth == 0:
                        close_idx = j
                        break

            if close_idx >= 0:
                # Strip param types
                params = line[paren_start + 1:close_idx]
                if params.strip():
                    params = re.sub(r'(\b\w+)\s*:\s*[^,)]+', r'\1', params)

                # Check for return type after )
                after = line[close_idx + 1:]
                cm = re.match(r'^\s*:\s*', after)
                if cm:
                    rest = after[cm.end():]
                    # Find where return type ends and function body begins
                    # Return types: table?, string?, { Instance }, { { ... } }, etc.
                    # Function body starts with '{' on its own (after type)
                    # Strategy: if rest starts with '{', check if there's another '{' after matching '}'
                    # Simpler: if the line ends with just '{' or is empty after stripping a type,
                    # the body starts at the first standalone '{'

                    # Track brace depth to find the body start
                    bdepth = 0
                    body_idx = -1
                    for j, ch in enumerate(rest):
                        if ch == '{':
                            if bdepth == 0:
                                # Potential body start
                                # Check if everything before was a valid type
                                # and if this brace is at the end of the line
                                after_brace = rest[j+1:].strip()
                                if bdepth == 0 and (after_brace == '' or after_brace.startswith('--')):
                                    body_idx = j
                                    break
                                # Otherwise it's part of a type like { Instance }
                            bdepth += 1
                        elif ch == '}':
                            bdepth -= 1

                    if body_idx >= 0:
                        body = rest[body_idx:]
                        line = indent + local_kw + 'function ' + func_name + '(' + params + ') ' + body
                    else:
                        # No body found — strip entire return type
                        line = indent + local_kw + 'function ' + func_name + '(' + params + ')'
                else:
                    line = indent + local_kw + 'function ' + func_name + '(' + params + ')' + line[close_idx + 1:]

        # ── Local variable type annotations ──
        m = re.match(r'^(\s*local\s+\w+)\s*:\s*', line)
        if m:
            name_part = m.group(1)
            rest = line[m.end():]
            depth = 0
            eq_idx = -1
            for j, ch in enumerate(rest):
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                elif ch == '=' and depth == 0:
                    eq_idx = j
                    break
            if eq_idx >= 0:
                line = name_part + ' ' + rest[eq_idx:]
            else:
                line = name_part

        # ── self.field type annotations ──
        # Only match if NOT a method call (self.folder:Destroy() should be left alone)
        # Match: self.field: followed by something that's NOT a method call
        m = re.match(r'^(\s*self\.\w+)\s*:\s*(?![A-Za-z_\w]*\s*\()', line)
        if m:
            name_part = m.group(1)
            rest = line[m.end(0):]  # end of entire match (including the colon)
            depth = 0
            eq_idx = -1
            for j, ch in enumerate(rest):
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                elif ch == '=' and depth == 0:
                    eq_idx = j
                    break
            if eq_idx >= 0:
                line = name_part + ' ' + rest[eq_idx:]
            elif rest.strip() == '':
                line = name_part
            # else: it's something else, leave line unchanged

        # ── Table field type annotations (in config tables) ──
        # Pattern: indent word: Type = value  →  indent word = value
        # Also: indent word: { (no = sign, Luau shorthand)  →  indent word = {
        m = re.match(r'^(\s+)(\w+)\s*:\s*(.+)$', line)
        if m:
            indent = m.group(1)
            field_name = m.group(2)
            rest = m.group(3)
            depth = 0
            eq_idx = -1
            for j, ch in enumerate(rest):
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                elif ch == '=' and depth == 0:
                    eq_idx = j
                    break
            if eq_idx >= 0:
                line = indent + field_name + ' ' + rest[eq_idx:].strip()
            else:
                # No '=' found — could be Luau shorthand: field: { value... }
                # Check if rest starts with '{' (a table value, not type annotation)
                if rest.strip().startswith('{'):
                    line = indent + field_name + ' = ' + rest.strip()

        # ── For loop variable types ──
        line = re.sub(r'(\b\w+)\s*:\s*[A-Za-z_][\w.?]*\b(\s+in\b)', r'\1\2', line)

        result.append(line)

    return '\n'.join(result)


class LuaRunner:
    """Manages a Lua mock harness and executes Lua test scripts."""

    _shared_runner = None

    def __init__(self, harness_code: str = MOCK_HARNESS_LUA):
        self.harness = harness_code
        self._harness_file = None

    @classmethod
    def shared(cls):
        if cls._shared_runner is None:
            cls._shared_runner = cls()
        return cls._shared_runner

    def _get_harness_file(self):
        if self._harness_file is None:
            fd, self._harness_file = tempfile.mkstemp(suffix='.lua', prefix='lua_mock_')
            with os.fdopen(fd, 'w') as f:
                f.write(self.harness)
        return self._harness_file

    def strip_and_load(self, lua_path: str, var_name: str) -> str:
        """Read, strip types, write to temp file, return loadable Lua code."""
        with open(lua_path) as f:
            code = f.read()
        stripped = strip_luau_types(code)

        # Write to temp file for dofile
        fd, module_file = tempfile.mkstemp(suffix='.lua', prefix=f'{var_name}_')
        with os.fdopen(fd, 'w') as f:
            f.write(stripped)
        self._cleanup_files = getattr(self, '_cleanup_files', [])
        self._cleanup_files.append(module_file)

        return f'{var_name} = dofile("{module_file}")\n'

    def run(self, script: str) -> str:
        """Run harness + script via lua5.1 CLI."""
        harness_file = self._get_harness_file()
        full = f'dofile("{harness_file}")\n' + script
        result = subprocess.run(
            [LUA_BIN, '-e', full],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            raise RuntimeError(f"Lua error:\n{result.stderr}\n--- stdout ---\n{result.stdout}")
        return result.stdout
