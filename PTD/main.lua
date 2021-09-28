local function GetIndentStrings(indents)
  local buffer = ""

  for i = 0, indents do
    buffer = buffer .. "  "
  end

  return buffer
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

local function SetParamDefaults(depth, log, ignore, func)
  if not depth or depth <= 0 then
    depth = 1
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

  if func == nil then
    func = true
  end

  return depth, log, ignore, func
end

local tableList = { }
tableList.Names = { }
tableList.Addresses = { }
-- it's a table table O.O

local function RemoveRawTextFromAddress(text)
  if string.sub(text, 1, 1) == "t" then -- indicates raw tostring() text
    return string.sub(text, 7) -- length of raw text ("table: ")
  end
end

local function AppendTableList(nameData, depth)
  depth = depth > 0 and depth or 1

  table.insert(tableList.Names, depth, nameData[1])
  table.insert(tableList.Addresses, depth, RemoveRawTextFromAddress(nameData[2]))
end

local loopDepth = 0
local uniqueCall = true

---@param tbl table
---@param maxDepth? integer
---@param allowLogHeavyTables? boolean
---@param customNameForInitialLog? string
---@param tablesToIgnore? table|string
---@param skipFunctions? boolean
function PrintTableDeep(tbl, maxDepth, allowLogHeavyTables, customNameForInitialLog, tablesToIgnore, skipFunctions)
  if type(tbl) ~= "table" then
    log(tostring(tbl))
  return end

  maxDepth, allowLogHeavyTables, tablesToIgnore, skipFunctions = SetParamDefaults(maxDepth, allowLogHeavyTables, tablesToIgnore, skipFunctions)

  if loopDepth == 0 and uniqueCall then
    local initTableName = customNameForInitialLog or tostring(tbl)
    AppendTableList({ "", tostring(tbl) }, 1)

    log("PTD: Now printing: " .. initTableName)
    log("{")
    uniqueCall = false
  end

  for k, v in pairs(tbl) do
    local ind = GetIndentStrings(loopDepth)
    local logSTR = GetLogFormat(ind, k, v)

    if type(v) == "table" then
      local strK = tostring(k)
      local strV = tostring(v)

      local hasValues = table.size(v) > 0
      local isSafe, reason = CheckIfSafe(strK, allowLogHeavyTables)
      local ignoreTable = table.get_key(tablesToIgnore, strK)

      local function checkIfRecursive(tableToCheck)
        for nestK, nestV in pairs(tableToCheck) do
          if type(nestV) == "table" then
            local addressIndex = table.index_of(tableList.Addresses, RemoveRawTextFromAddress(tostring(nestV)))

            if addressIndex ~= -1 and addressIndex - 1 < loopDepth then
              return true
            end
          end
        end

        return false
      end

      local containsOwnParent = checkIfRecursive(v)

      if loopDepth < maxDepth and hasValues and isSafe and not ignoreTable and not containsOwnParent then
        AppendTableList({ strK, strV }, loopDepth + 1)

        log(logSTR)
        log(ind .. "{")

        loopDepth = loopDepth + 1

        PrintTableDeep(v, maxDepth, allowLogHeavyTables, nil, tablesToIgnore, skipFunctions)

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
      elseif containsOwnParent then
        logSTR = string.format("%s { [table blocked to stop recursive loop (\"%s\" contains \"%s\" which contains \"%s\")] }", logSTR, strK, tableList.Names[loopDepth], strK)
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