function PLUGIN:BackendInstall(ctx)
  local util = require("hooks.util")
  local cmd = require("cmd")
  local http = require("http")
  local sep = package.config:sub(1,1)
  local tool = ctx.tool
  local version = ctx.version
  local base_dir = ctx.install_path
  local os_type = get_os_type()

  local env_dir = util.get_env_dir(base_dir, version, tool)
  local manifest = util.read_manifest(env_dir)
  if manifest then
    print("[INFO] Existing MATLAB env found: " .. env_dir)
    return {}
  end

  local parent_path = base_dir
  local mpm_exe = util.ensure_mpm(parent_path, os_type)

  local products = tool:gsub(",", " ")
  local matlab_cmd = string.format('"%s" install --release=%s --destination="%s" --products=%s',
      mpm_exe, version, env_dir, products)
  print("[DEBUG] Running: " .. matlab_cmd)
  local result = cmd.exec(matlab_cmd)
  if result ~= 0 then
    error("mpm install failed with exit code: " .. tostring(result))
  end

  local t = {}
  for prod in string.gmatch(tool, "([^,]+)") do
    table.insert(t, prod:lower())
  end
  table.sort(t)
  util.write_manifest(env_dir, { version = version, products = t })

  print("[INFO] MATLAB environment ready at: " .. env_dir)
  return {}
end

local function get_os_type()
  local util = require("hooks.util")
  local cmd = require("cmd")
  local http = require("http")
  local sep = package.config:sub(1,1)
  if sep == "\\" then return "windows" end
  local uname = cmd.exec("uname -s"):lower()
  if uname:find("linux") then return "linux"
  elseif uname:find("darwin") or uname:find("mac") then return "darwin"
  else return uname end
end