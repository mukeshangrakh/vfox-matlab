-- plugin.lua

PLUGIN = {
    name = "vfox-matlab",
    version = "1.0.0",
    description = "Backend plugin for mpm packages",
    author = "Ajay Puvvala"
}

local util = require("util")
local cmd = require("cmd")
local http = require("http")
local sep = package.config:sub(1,1)

-- Determine OS type
local function get_os_type()
    if sep == "\\" then return "windows" end
    local uname = cmd.exec("uname -s"):lower()
    if uname:find("linux") then return "linux"
    elseif uname:find("darwin") or uname:find("mac") then return "darwin"
    else return uname end
end

-- Find or create unique env directory for (version, products)
local function get_env_dir(base_dir, version, products)
    local hash = util.hash_env(version, products)
    return base_dir .. "/matlab-" .. version .. "-" .. hash
end

-- Download mpm if not present
local function ensure_mpm(parent_path, os_type)
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

-- Setup environment variables for activation
function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    return {
        env_vars = {
            { key = "PATH", value = install_path .. "/bin" }
        }
    }
end

-- Install MATLAB and toolboxes into unique env dir
function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool           -- e.g. "signal,image_processing"
    local version = ctx.version     -- e.g. "R2024a"
    local base_dir = ctx.install_path -- vfox base install path (global cache)
    local os_type = get_os_type()

    -- 1. Compute unique env dir
    local env_dir = get_env_dir(base_dir, version, tool)

    -- 2. Check if already exists and manifest matches
    local manifest = util.read_manifest(env_dir)
    if manifest then
        print("[INFO] Existing MATLAB env found: " .. env_dir)
        return {}
    end

    -- 3. Ensure mpm is present
    local parent_path = base_dir
    local mpm_exe = ensure_mpm(parent_path, os_type)

    -- 4. Prepare products
    local products = tool:gsub(",", " ")

    -- 5. Run mpm install
    local matlab_cmd = string.format('"%s" install --release=%s --destination="%s" --products=%s',
        mpm_exe, version, env_dir, products)
    print("[DEBUG] Running: " .. matlab_cmd)
    local result = cmd.exec(matlab_cmd)
    if result ~= 0 then
        error("mpm install failed with exit code: " .. tostring(result))
    end

    -- 6. Write manifest
    local t = {}
    for prod in string.gmatch(tool, "([^,]+)") do
        table.insert(t, prod:lower())
    end
    table.sort(t)
    util.write_manifest(env_dir, { version = version, products = t })

    print("[INFO] MATLAB environment ready at: " .. env_dir)
    return {}
end

function PLUGIN:BackendListVersions(ctx)
    -- In practice, you may query mpm or MathWorks API
    local versions = { "R2025a", "R2024b", "R2024a" }
    return { versions = versions }
end

return PLUGIN