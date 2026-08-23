local Json = require("src.link.Json")

local DEFAULT_CONFIG = {
  nameChoices = {"KRIS", "AMANDA", "JUANA", "JODI"},
  genderMode = "girl",
}

local VALID_GENDER_MODES = { boy = true, girl = true, enby = true }
local SPRITES_DIR = "assets/sprites"

local function isNonEmptyStringArray(t)
  if type(t) ~= "table" then return false end
  local count = 0
  for k, v in pairs(t) do
    if type(k) ~= "number" or type(v) ~= "string" or v == "" then return false end
    count = count + 1
  end
  return count > 0
end

local function readMeta(mod, key)
  local metaPath = SPRITES_DIR .. "/" .. key .. "/meta.json"
  if not mod.assets:info(metaPath) then return nil end
  local ok, decoded = pcall(Json.decode, mod:read(metaPath))
  if ok and type(decoded) == "table" then return decoded end
  return nil
end

local M = {}

-- Scans every sprite folder's meta.json (same folders kris.lua already
-- discovers for sprite labels) for optional nameChoices/genderMode keys.
-- Any sprite folder may define them -- not just "original". If more than
-- one folder defines the same key, the last one wins in alphabetical
-- order by folder name.
function M.load(mod)
  local cfg = {
    nameChoices = DEFAULT_CONFIG.nameChoices,
    genderMode = DEFAULT_CONFIG.genderMode,
  }

  local keys = mod.assets:list(SPRITES_DIR) or {}
  table.sort(keys)

  for _, key in ipairs(keys) do
    local meta = readMeta(mod, key)
    if meta then
      if isNonEmptyStringArray(meta.nameChoices) then
        cfg.nameChoices = meta.nameChoices
      end
      if type(meta.genderMode) == "string" and VALID_GENDER_MODES[meta.genderMode] then
        cfg.genderMode = meta.genderMode
      end
    end
  end

  return cfg
end

return M
