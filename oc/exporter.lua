-- GTNH base exporter for OpenComputers.
-- Reads GregTech machines through Adapters and POSTs a small JSON summary
-- that the Tidbyt app (main.star) could read later.
--
-- Setup: computer with an Internet Card; put an Adapter against your
-- Lapotronic Supercapacitor / battery buffer, and against any machines you
-- want counted (or use MFU / cable networks to reach many at once).

local component = require("component")
local internet = require("internet")

---------------- config ----------------
local UPLOAD_URL = "https://www.matthewsand.info/gtnhBase.php" -- your receiver
local TOKEN = "change-me"                                      -- shared secret
local ENERGY_ADDRESS = nil  -- address of the LSC/buffer; nil = first one with EU storage
local INTERVAL = 60         -- seconds between uploads
----------------------------------------

local function try(proxy, ...)
  for _, name in ipairs({...}) do
    if proxy[name] then
      local ok, v = pcall(proxy[name])
      if ok and v ~= nil then return v end
    end
  end
  return nil
end

-- LSC reports averages only in its sensor text, e.g. "Avg EU IN: 6,144".
local function fromSensor(proxy, label)
  local info = try(proxy, "getSensorInformation")
  if type(info) ~= "table" then return nil end
  for _, line in ipairs(info) do
    local clean = line:gsub("§.", "")
    if clean:find(label, 1, true) then
      local digits = clean:match(label .. "[^%d]*([%d,]+)")
      if digits then return tonumber((digits:gsub(",", ""))) end
    end
  end
  return nil
end

local function findEnergy()
  if ENERGY_ADDRESS then return component.proxy(ENERGY_ADDRESS) end
  local best, bestCap = nil, 0
  for addr in component.list("gt_machine") do
    local p = component.proxy(addr)
    local cap = try(p, "getEUMaxStored", "getEUCapacity") or 0
    if cap > bestCap then best, bestCap = p, cap end
  end
  return best
end

local function snapshot()
  local data = {}
  local energy = findEnergy()
  if energy then
    data.eu_stored = try(energy, "getEUStored", "getStoredEU")
    data.eu_capacity = try(energy, "getEUMaxStored", "getEUCapacity")
    data.eu_in = fromSensor(energy, "Avg EU IN") or try(energy, "getEUInputAverage", "getAverageElectricInput")
    data.eu_out = fromSensor(energy, "Avg EU OUT") or try(energy, "getEUOutputAverage", "getAverageElectricOutput")
  end

  local active, total = 0, 0
  for addr in component.list("gt_machine") do
    local p = component.proxy(addr)
    if not energy or addr ~= energy.address then
      local on = try(p, "isMachineActive")
      if on ~= nil then
        total = total + 1
        if on then active = active + 1 end
      end
    end
  end
  data.machines_active = active
  data.machines_total = total
  return data
end

-- Minimal JSON encoder for a flat table of numbers.
local function encode(t)
  local parts = {}
  for k, v in pairs(t) do
    parts[#parts + 1] = string.format("%q:%s", k, string.format("%.0f", v))
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function upload(body)
  local ok, err = pcall(function()
    local req = internet.request(UPLOAD_URL, body, {
      ["Content-Type"] = "application/json",
      ["X-Token"] = TOKEN,
    })
    for _ in req do end -- drain response so the request completes
  end)
  if not ok then io.stderr:write("upload failed: " .. tostring(err) .. "\n") end
end

while true do
  local data = snapshot()
  -- Tidbyt checks freshness against this. OC has no wall clock, so the
  -- receiver should overwrite "updated" with its own server time.
  data.updated = 0
  upload(encode(data))
  print(string.format("sent: %s EU, %d/%d machines on",
    tostring(data.eu_stored), data.machines_active, data.machines_total))
  os.sleep(INTERVAL)
end
