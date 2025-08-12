local util = require("hooks.util")
local cmd = require("cmd")
local http = require("http")
local sep = package.config:sub(1,1)
local json = require("json")
local crypto = require("crypto")

local M = {}

function M.hash_env(version, products)
  local t = {}
  for prod in string.gmatch(products, "([^,]+)") do
    table.insert(t, prod:lower())
  end
  table.sort(t)
  local key = version .. ":" .. table.concat(t, ",")
  local hash = crypto.sha1(key):sub(1, 8)
  return hash
end

function M.read_manifest(env_dir)
  local path = env_dir .. "/manifest.json"
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return json.decode(content)
end

function M.write_manifest(env_dir, manifest)
  local path = env_dir .. "/manifest.json"
  local file = io.open(path, "w")
  file:write(json.encode(manifest))
  file:close()
end

function M.get_env_dir(base_dir, version, products)
  local hash = M.hash_env(version, products)
  return base_dir .. "/matlab-" .. version .. "-" .. hash
end

function M.ensure_mpm(parent_path, os_type)
  local mpm_exe
  if os_type == "windows" then
    mpm_exe = parent_path .. "\\mpm.exe"
  else
    mpm_exe = parent_path .. "/mpm"
  end

  local file = io.open(mpm_exe, "r")
  if file then file:close() return mpm_exe end

  local mpm_url
  if os_type == "linux" then
    mpm_url = "https://www.mathworks.com/mpm/glnxa64/mpm"
  elseif os_type == "windows" then
    mpm_url = "https://www.mathworks.com/mpm/win64/mpm"
  else
    mpm_url = "https://www.mathworks.com/mpm/maci64/mpm"
  end

  local err = http.download_file({
    url = mpm_url,
    headers = { ['User-Agent'] = "mpm-download" }
  }, mpm_exe)
  if err ~= nil then error("Download failed: " .. err) end

  if os_type ~= "windows" then
    cmd.exec('chmod +x "' .. mpm_exe .. '"')
  end

  return mpm_exe
end

return M