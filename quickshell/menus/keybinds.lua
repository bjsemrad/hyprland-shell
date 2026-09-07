Name = "keybinds"
NamePretty = "Keybinds"
Icon = "preferences-desktop-keyboard"
Description = "Search active keyboard shortcuts"
Action = "%VALUE%"
SearchName = true

local env = os.getenv

local function has(key)
  local v = env(key)
  return v ~= nil and v ~= ""
end

local function titleCase(str)
  return (str:gsub("(%a)([%w_]*)", function(a, w)
    return a:upper() .. w:lower()
  end))
end

local function configHome()
  return os.getenv("XDG_CONFIG_HOME") or (env("HOME") or "~") .. "/.config"
end

--- Hyprland ---------------------------------------------------------------

-- hyprctl binds -j reports the modifier bitmask; map bits to names.
local HYPR_MODS = {
  { 64, "SUPER" },
  { 32, "MOD3" },
  { 16, "MOD2" },
  { 8, "ALT" },
  { 4, "CTRL" },
  { 1, "SHIFT" },
  { 128, "MOD5" },
  { 2, "CAPS" },
}

local function modsString(mask)
  local parts = {}
  for _, m in ipairs(HYPR_MODS) do
    if math.floor(mask / m[1]) % 2 == 1 then
      table.insert(parts, m[2])
    end
  end
  return table.concat(parts, "+")
end

local KEY_LABELS = {
  RETURN = "Return",
  SPACE = "Space",
  TAB = "Tab",
  ESC = "Esc",
  LEFT = "Left",
  RIGHT = "Right",
  UP = "Up",
  DOWN = "Down",
  BACKSPACE = "Backspace",
  DELETE = "Delete",
  PERIOD = "Period",
}

local function keyLabel(k)
  if not k or k == "" then return "" end
  if KEY_LABELS[k] then return KEY_LABELS[k] end
  if #k == 1 then return k:upper() end
  if k:lower() == k then return titleCase(k) end
  return k
end

local DISPATCH_LABELS = {
  workspace = "Switch to workspace",
  workspaceSilent = "Switch to workspace (silent)",
  workspaceName = "Switch to workspace",
  killactive = "Close window",
  togglefloating = "Toggle floating",
  togglefullscreen = "Toggle fullscreen",
  fullscreen = "Toggle fullscreen",
  focuswindow = "Focus window",
  focusmonitor = "Focus monitor",
  focusurgentorlast = "Focus last window",
  movewindow = "Move window",
  movecursortocorner = "Move cursor to corner",
  layoutmsg = "Layout message",
}

local function dispatchLabel(disp, arg)
  local base = DISPATCH_LABELS[disp] or titleCase(disp:gsub("%.", " "))
  local a = tostring(arg)
  if a ~= "" then return base .. ": " .. a end
  return base
end

local function dispatchValue(disp, arg)
  local a = tostring(arg)
  if a == "" then return "hyprctl dispatch " .. disp end
  a = a:gsub("'", "'\\''")
  return "hyprctl dispatch " .. disp .. " '" .. a .. "'"
end

-- canonical, order-insensitive key chord used to join hyprctl binds with
-- hl.bind("...") strings from hyprland.lua
local CHORD_MODS = {
  ["super"] = "super", ["super_l"] = "super", ["super_r"] = "super",
  ["mod"] = "super", ["mod4"] = "super",
  ["ctrl"] = "ctrl", ["control"] = "ctrl",
  ["alt"] = "alt", ["mod1"] = "alt",
  ["shift"] = "shift",
  ["mod2"] = "mod2", ["mod3"] = "mod3", ["mod5"] = "mod5", ["caps"] = "caps",
}

local function canonicalChord(chord)
  local parts = {}
  for part in (chord:gsub("%s+", " ")):gmatch("[^%+]+") do
    local p = part:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    p = CHORD_MODS[p] or p
    table.insert(parts, p)
  end
  table.sort(parts)
  return table.concat(parts, "+")
end

local function hyprComboKey(b)
  local parts = {}
  for _, m in ipairs(HYPR_MODS) do
    if math.floor((b.modmask or 0) / m[1]) % 2 == 1 then
      table.insert(parts, m[2]:lower())
    end
  end
  local key = tostring(b.key or ""):lower()
  if key ~= "" then table.insert(parts, key) end
  table.sort(parts)
  return table.concat(parts, "+")
end

-- loop-generated binds like `hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))`
-- cannot be matched to source text, so infer them from the chord digits.
local function loopNumberLabel(combo)
  local t = combo:gsub("%s", ""):lower()
  local shift = false
  local m = t:match("^super%+(%d+)$")
  if not m then
    m = t:match("^super%+shift%+(%d+)$")
    shift = m ~= nil
  end
  if m then
    local ws = tonumber(m)
    if ws == 0 and #m == 1 then ws = 10 end
    if ws and ws >= 1 and ws <= 10 then
      return shift and ("Move to workspace " .. ws) or ("Focus workspace " .. ws)
    end
  end
  return nil
end

local WIN_LABELS = {
  close = "Close window",
  float = "Toggle floating",
  togglefloat = "Toggle floating",
  fullscreen = "Toggle fullscreen",
  togglefullscreen = "Toggle fullscreen",
  swap = "Move window",
  move = "Move window",
  center = "Center window",
  drag = "Drag window",
  resize = "Resize window",
}

-- turn the body of a hl.bind(...) call into a display text + runnable value
local function analyzeHyprLuaBody(body)
  local q = body:match('exec%s*%(%s*(%b"")') or body:match("exec%s*%(%s*(%b'')")
  if q then
    local cmd = q:sub(2, -2)
    if cmd ~= "" then
      return { text = "Run: " .. cmd, value = cmd }
    end
  end

  local act, arg = body:match('dispatch%s+([%w]+)%s*([^%)%{]*)')
  if act then
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "") or ""
    local label = DISPATCH_LABELS[act] or titleCase(act)
    if arg ~= "" then label = label .. ": " .. arg end
    local value = "hyprctl dispatch " .. act .. (arg ~= "" and (" " .. arg) or "")
    return { text = label, value = value }
  end

  local wsp = body:match('hl%.dsp%.focus%s*%(%s*{%s*workspace%s*=%s*["\']?([^"\'%,}]+)["\']?')
  if wsp then return { text = "Focus workspace " .. wsp, value = "" } end

  local mvWsp = body:match('hl%.dsp%.window%.move%s*%(%s*{%s*workspace%s*=%s*["\']?([^"\'%,}]+)["\']?')
  if mvWsp then return { text = "Move to workspace " .. mvWsp, value = "" } end

  local winOp = body:match('hl%.dsp%.window%.([%w_]+)')
  if winOp then
    return { text = WIN_LABELS[winOp] or ("hl.dsp.window." .. winOp), value = "" }
  end

  local lay = body:match('hl%.dsp%.layout%s*%(%s*["\']([^"\']*)["\']%s*%)')
  if lay then return { text = "Layout: " .. lay, value = "" } end

  local cfg = body:match('hl%.config%s*%(%s*{%s*general%s*=%s*{%s*layout%s*=%s*["\']([^"\']*)')
  if cfg then return { text = "Set layout: " .. cfg, value = "" } end

  if body:match('hl%.dsp%.focus') then return { text = "Focus window", value = "" } end

  local path = body:match('hl%.dsp%.([%w_%.]+)')
  if path then return { text = "Scripted: " .. titleCase(path:gsub("%.", " ")), value = "" } end

  return { text = "Scripted shortcut", value = "" }
end

-- parse ~/.config/hypr/hyprland.lua hl.bind calls -> canonical chord -> info
local function hyprLuaBinds()
  local path = configHome() .. "/hypr/hyprland.lua"
  local f = io.open(path, "r")
  if not f then return {} end
  local src = f:read("*a") or ""
  f:close()

  -- drop whole-line comments so commented-out binds stay unparsed
  local lines = {}
  for line in src:gmatch("[^\r\n]*") do
    local trimmed = (line:match("^%s*(.-)%s*$") or "")
    if not trimmed:match("^%-%-") then table.insert(lines, line) end
  end
  src = table.concat(lines, "\n")

  local map = {}
  local pos = 1
  while true do
    local s = src:find("hl.bind", pos, true)
    if not s then break end
    pos = s + 1
    local open = src:find("%(", s)
    if not open then goto continue end
    local q1 = src:find('"', open)
    if not q1 then goto continue end
    local q2 = src:find('"', q1 + 1)
    if not q2 then goto continue end
    local chord = src:sub(q1 + 1, q2 - 1)
    local comma = src:find(",", q2)
    if not comma then goto continue end
    local depth, i, closePos = 0, comma + 1, nil
    while i <= #src do
      local c = src:sub(i, i)
      if c == "(" then
        depth = depth + 1
      elseif c == ")" then
        if depth == 0 then
          closePos = i
          break
        end
        depth = depth - 1
      end
      i = i + 1
    end
    if closePos then
      local body = src:sub(comma + 1, closePos - 1)
      map[canonicalChord(chord)] = analyzeHyprLuaBody(body)
    end
    ::continue::
  end
  return map
end

local function hyprEntries()
  local handle = io.popen("hyprctl binds -j 2>/dev/null")
  if not handle then return {} end
  local raw = handle:read("*a")
  handle:close()
  if not raw or raw == "" then return {} end
  local ok, data = pcall(jsonDecode, raw)
  if not ok or type(data) ~= "table" then return {} end

  local luaMap = hyprLuaBinds()
  local entries = {}
  local seen = {}
  for _, b in ipairs(data) do
    if not b.mouse then
      local key = tostring(b.key or "")
      if key ~= "" then
        local combo = keyLabel(key)
        local mm = modsString(b.modmask or 0)
        if mm ~= "" then combo = mm .. "+" .. combo end

        local disp = tostring(b.dispatcher or "exec")
        local arg = tostring(b.arg or "")
        local text, value
        if disp == "__lua" then
          local info = luaMap[hyprComboKey(b)]
          if info then
            text, value = info.text, info.value
          else
            local num = loopNumberLabel(combo)
            if num then
              text, value = num, ""
            else
              text, value = "Scripted shortcut", ""
            end
          end
        else
          text = tostring(b.description or "")
          if text == "" then text = dispatchLabel(disp, arg) end
          value = dispatchValue(disp, arg)
        end

        local uniq = text .. "\0" .. combo
        if not seen[uniq] then
          seen[uniq] = true
          table.insert(entries, {
            Text = text,
            Subtext = combo,
            Icon = "input-keyboard",
            Value = value,
            Keywords = { disp, arg },
          })
        end
      end
    end
  end
  return entries
end

--- Niri -------------------------------------------------------------------

local function stripComments(s)
  local out = {}
  local i, n = 1, #s
  local inStr = false
  while i <= n do
    local c = s:sub(i, i)
    if inStr then
      table.insert(out, c)
      if c == "\\" then
        table.insert(out, s:sub(i + 1, i + 1))
        i = i + 2
      elseif c == '"' then
        inStr = false
        i = i + 1
      else
        i = i + 1
      end
    elseif c == '"' then
      inStr = true
      table.insert(out, c)
      i = i + 1
    elseif c == "/" and s:sub(i + 1, i + 1) == "/" then
      while i <= n and s:sub(i, i) ~= "\n" do i = i + 1 end
    else
      table.insert(out, c)
      i = i + 1
    end
  end
  return table.concat(out)
end

local function scanTokens(s)
  local toks = {}
  local i, n = 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c == '"' then
      local buf, j = {}, i + 1
      while j <= n do
        local cc = s:sub(j, j)
        if cc == "\\" then
          table.insert(buf, s:sub(j + 1, j + 1))
          j = j + 2
        elseif cc == '"' then
          j = j + 1
          break
        else
          table.insert(buf, cc)
          j = j + 1
        end
      end
      table.insert(toks, { type = "str", value = table.concat(buf) })
      i = j
    elseif c == "{" or c == "}" or c == "(" or c == ")" or c == ";" then
      table.insert(toks, { type = "punct", value = c })
      i = i + 1
    elseif c == "=" then
      table.insert(toks, { type = "eq", value = "=" })
      i = i + 1
    elseif c:match("%s") then
      i = i + 1
    else
      local j = i
      while j <= n do
        local cc = s:sub(j, j)
        if cc:match("%s") or cc == "{" or cc == "}" or cc == "(" or cc == ")" or cc == ";" or cc == '"' then
          break
        end
        j = j + 1
      end
      table.insert(toks, { type = "word", value = s:sub(i, j - 1) })
      i = j
    end
  end
  return toks
end

local function buildNiriEntry(cur)
  if not cur or #cur.head == 0 then return nil end
  local combo = cur.head[1].value

  local title = nil
  for i = 2, #cur.head do
    local t = cur.head[i]
    if t.type == "word" then
      local picked
      if t.value == "hotkey-overlay-title=" then
        picked = cur.head[i + 1]
      elseif t.value == "hotkey-overlay-title" then
        picked = cur.head[i + 2]
      end
      if picked and (picked.type == "str" or picked.type == "word") then
        title = picked.value
        break
      end
    end
  end

  local actionTokens = {}
  for _, t in ipairs(cur.actions) do
    if t.type ~= "punct" then table.insert(actionTokens, t) end
  end
  local name = actionTokens[1] and actionTokens[1].value or ""

  local function joinArgs()
    local parts = {}
    for i = 2, #actionTokens do
      table.insert(parts, actionTokens[i].value)
    end
    return table.concat(parts, " ")
  end

  local entry = {
    Subtext = combo,
    Icon = "input-keyboard",
  }

  if name == "spawn" then
    local argsToks = {}
    for i = 2, #actionTokens do
      table.insert(argsToks, actionTokens[i])
    end
    local displayParts, quotedParts = {}, {}
    for _, at in ipairs(argsToks) do
      table.insert(displayParts, at.value)
      table.insert(quotedParts, "'" .. tostring(at.value):gsub("'", "'\\''") .. "'")
    end
    local displayCmd = table.concat(displayParts, " ")
    local valueCmd = table.concat(quotedParts, " ")

    local first = (argsToks[1] and argsToks[1].value) or "command"
    local text
    if title ~= nil and title ~= "" then
      text = title
    elseif first == "bash" and argsToks[2] and argsToks[2].value == "-c" and argsToks[3] then
      text = argsToks[3].value
      if #text > 80 then text = text:sub(1, 80) .. " …" end
    else
      text = "Launch " .. (first:match("%S+") or first)
    end

    local entry2 = {
      Text = text,
      Subtext = combo .. "  ·  " .. displayCmd,
      Icon = "input-keyboard",
      Value = "niri msg action spawn -- " .. valueCmd,
      Keywords = { "spawn", displayCmd },
    }
    return entry2
  elseif name == "show-hotkey-overlay" then
    entry.Text = title or "Show hotkey overlay"
    entry.Value = "niri msg action show-hotkey-overlay"
    entry.Keywords = { "overlay", "hotkeys", "help" }
  else
    local rest = joinArgs()
    entry.Text = title or titleCase(name:gsub("-", " "))
    entry.Value = "niri msg action " .. name .. (rest ~= "" and (" " .. rest) or "")
    entry.Keywords = { name }
  end
  return entry
end

local function niriEntries()
  local path = configHome() .. "/niri/config.kdl"
  local f = io.open(path, "r")
  if not f then return {} end
  local src = f:read("*a") or ""
  f:close()
  src = stripComments(src)

  local toks = scanTokens(src)
  local entries = {}
  local seen = {}
  local inBinds = false
  local depth = 0
  local cur = nil

  local function flush()
    if cur then
      local e = buildNiriEntry(cur)
      if e then
        local uniq = e.Text .. "\0" .. e.Subtext
        if not seen[uniq] then
          seen[uniq] = true
          table.insert(entries, e)
        end
      end
      cur = nil
    end
  end

  for i = 1, #toks do
    local t = toks[i]
    if not inBinds then
      if t.type == "word" and t.value == "binds" then
        local nxt = toks[i + 1]
        if nxt and nxt.type == "punct" and nxt.value == "{" then
          inBinds = true
          depth = 0
        end
      end
    else
      if t.type == "punct" and t.value == "{" then
        depth = depth + 1
      elseif t.type == "punct" and t.value == "}" then
        depth = depth - 1
        if depth == 1 then
          flush()
        elseif depth == 0 then
          inBinds = false
        end
      elseif depth == 2 and cur then
        table.insert(cur.actions, t)
      elseif depth == 1 then
        if not cur then cur = { head = {}, actions = {} } end
        table.insert(cur.head, t)
      end
    end
  end
  flush()
  return entries
end

--- Entry point ------------------------------------------------------------

local function niriSocket()
  if has("NIRI_SOCKET") then return env("NIRI_SOCKET") end
  local rt = env("XDG_RUNTIME_DIR") or "/tmp"
  for _, p in ipairs({ rt .. "/niri.sock", rt .. "/niri-ipc/niri.sock" }) do
    local f = io.open(p, "r")
    if f then
      f:close()
      return p
    end
  end
  return nil
end

function GetEntries(query)
  if niriSocket() then return niriEntries() end
  if has("HYPRLAND_INSTANCE_SIGNATURE") then return hyprEntries() end
  return {}
end