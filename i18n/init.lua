local i18n = {}
local store
local locale

-- private stuff

local function dotSplit(str)
  local fields, length = {},0
    str:gsub("[^%.]+", function(c)
    length = length + 1
    fields[length] = c
  end)
  return fields, length
end

local function appendArray(destination, length, elements, elementsLength)
  elementsLength = elementsLength or #elements
  for i=1, elementsLength do
    destination[length + i] = elements[i]
  end
  return destination, length + elementsLength
end

local function subArray(source, start, finish)
  local result, length = {}, finish - start + 1
  for i=1,length do
    result[i] = source[start + i - 1]
  end
  return result
end

local function arrayCopy(source)
  local result, length = {}, #source
  for i=1,length do result[i] = source[i] end
  return result, length
end

local function isPluralTable(t)
  return type(t) == 'table' and type(t.one) == 'string' and type(t.other) == 'string'
end

local function isPresent(str)
  return type(str) == 'string' and #str > 0
end

local function assertPresent(functionName, paramName, value)
  if isPresent(value) then return end

  local msg = "i18n.%s requires a non-empty string on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrPlural(functionName, paramName, value)
  if isPresent(value) or isPluralTable(value) then return end

  local msg = "i18n.%s requires a non-empty string or plural-form table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrTable(functionName, paramName, value)
  if isPresent(value) or type(value) == 'table' then return end

  local msg = "i18n.%s requires a non-empty string or table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function parseArgs(param1, param2, ...)
  local args, length = dotSplit(param1)
  args[length + 1] = param2
  return appendArray(args, length + 1, {...})
end

local function localizeArgs(args, length)
  local newArgs, newLength = arrayCopy(locale)
  return appendArray(newArgs, newLength, args, length)
end

local function interpolateString(str, data)
  return str:gsub("%%{(.-)}", function(w) return tostring(data[w]) end)
end

local function interpolatePluralTable(t, data)
  assertPresentOrPlural('interpolatePluralTable', 't', t)
  data = data or {}
  local count = data.count or 1
  local term = count == 1 and t.one or t.other
  return interpolateString(term, data)
end

local function interpolate(node, data)
  return type(node) == 'string' and interpolateString(node, data) or interpolatePluralTable(node, data)
end

local function recursiveLoad(currentContext, data)
  local composedKey
  for k,v in pairs(data) do
    composedKey = (currentContext and (currentContext .. '.') or "") .. tostring(k)
    assertPresent('load', composedKey, k)
    assertPresentOrTable('load', composedKey, v)
    if type(v) == 'string' or isPluralTable(v) then
      i18n.set(composedKey, v)
    else
      recursiveLoad(composedKey, v)
    end
  end
end

-- public stuff

function i18n.set(param1, param2, ...)
  assertPresent('set', 'first parameter', param1)
  assertPresentOrPlural('set', 'second parameter', param2)

  local args, length = parseArgs(param1, param2, ...)
  local node = store

  for i=1, length-2 do
    key = args[i]
    node[key] = node[key] or {}
    node = node[key]
  end

  local lastKey, value = args[length-1], args[length]
  node[lastKey] = value
end

function i18n.translate(param1, ...)
  assertPresent('translate', 'first parameter', param1)

  local args, length = localizeArgs(parseArgs(param1, ...))
  local lastParam    = args[length]
  local node, i      = store, 1

  while i < length do
    node = node[args[i]]
    if not node then return nil end
    if type(node) == 'string' or isPluralTable(node) then break end
    i = i + 1
  end

  if i < length then
    return interpolate(node, lastParam)
  else
    return node[args[length]]
  end
end

function i18n.setLocale(param1, ...)
  if param1 == nil then
    locale = {}
  else
    assertPresent('setLocale', 'first parameter', param1)
    locale = parseArgs(param1, ...)
  end
end

function i18n.getLocale()
  return table.concat(locale, '.')
end

function i18n.reset()
  store = {}
  i18n.setLocale()
end

function i18n.load(data)
  recursiveLoad(nil, data)
end

function i18n.loadFile(path)
  local chunk = assert(loadfile(path))
  local data = chunk()
  i18n.load(data)
end

setmetatable(i18n, {__call = function(_, ...) return i18n.translate(...) end})

i18n.reset()

return i18n