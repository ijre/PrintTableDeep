local function GetIndentStrings(indents)
  local buffer = ""

  for i = 0, indents do
    buffer = buffer .. "  "
  end

  return buffer
end

local function CheckIfSafe(name, allowLogHeavyTables)
  local alwaysBlock =
  {
    "__module__"
  }

  local unsafeTables =
  {
    "_state",
    "_state_data",
    "state",
    "__index",
    "super",
    "_mission_script"
  }

  local reason = table.contains(alwaysBlock, name) and "always" or (not allowLogHeavyTables and table.contains(unsafeTables, name)) and "unsafe" or nil

  return reason == nil, reason
end

local function GetLogFormat(ind, input, value)
  local str = ind

  if type(value) ~= "table" then
    str = str .. string.format("\"%s\" = %s", input, value)
  else
    str = str .. string.format("[\"%s\"] = table", input)
  end

  return str
end

local function SetParamDefaults(depth, func, log, ignore)
  if not depth or depth <= 0 then
    depth = 1
  end

  if func == nil then
    func = true
  end

  if log == nil then
    log = false
  end

  if type(ignore) == "string" or type(ignore) == "number" then
    local temp = ignore
    ignore = { tostring(temp) }
  elseif type(ignore) ~= "table" then
    ignore = { }
  end

  return depth, func, log, ignore
end

local loopDepth = 0
local uniqueCall = true

---@param tbl table
---@param maxDepth? integer
---@param customNameForInitialLog? string
---@param skipFunctions? boolean
---@param allowLogHeavyTables? boolean
---@param tablesToIgnore? table|string
function PrintTableDeep(tbl, maxDepth, customNameForInitialLog, skipFunctions, allowLogHeavyTables, tablesToIgnore)
  if type(tbl) ~= "table" then
    log(tostring(tbl))
  return end

  maxDepth, skipFunctions, allowLogHeavyTables, tablesToIgnore = SetParamDefaults(maxDepth, skipFunctions, allowLogHeavyTables, tablesToIgnore)

  if loopDepth == 0 and uniqueCall then
    local initTableName = customNameForInitialLog or tostring(tbl)

    log("PTD: Now printing: " .. initTableName)
    log("{")
    uniqueCall = false
  end

  for k, v in pairs(tbl) do
    local ind = GetIndentStrings(loopDepth)
    local logSTR = GetLogFormat(ind, k, v)

    if type(v) == "table" then
      local hasValues = table.size(v) > 0
      local isSafe, reason = CheckIfSafe(tostring(k), allowLogHeavyTables)
      local ignoreTable = table.get_key(tablesToIgnore, tostring(k))

      if loopDepth < maxDepth and hasValues and isSafe and not ignoreTable then
        log(logSTR)
        log(ind .. "{")

        loopDepth = loopDepth + 1

        PrintTableDeep(v, maxDepth, skipFunctions, allowLogHeavyTables, tablesToIgnore)

        loopDepth = loopDepth - 1

        logSTR = ind .. "}"
      elseif not hasValues then
        logSTR = logSTR .. " { }"
      elseif loopDepth >= maxDepth then
        logSTR = logSTR .. " { [maxDepth reached] }"
      elseif not isSafe then
        if reason == "always" then
          logSTR = logSTR .. " { [table considered irredeemably spammy, always blocked] }"
        elseif "unsafe" then
          logSTR = logSTR .. " { [table considered spammy, blocked by allowLogHeavyTables param] }"
        end
      elseif ignoreTable then
        logSTR = logSTR .. " { [table blocked by tablesToIgnore param] }"
      end
    end

    if type(v) ~= "function" or not skipFunctions then
      log(logSTR)
    end
  end

  if loopDepth == 0 then
    uniqueCall = true
    log("}")
  end
end