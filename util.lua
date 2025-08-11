-- util.lua

local M = {}

local json = require("json")
local crypto = require("crypto")  -- vfox provides this for hashing

-- Sort and join toolboxes, then hash for unique env dir
function M.hash_env(version, products)
    -- products: comma-separated string
    local t = {}
    for prod in string.gmatch(products, "([^,]+)") do
        table.insert(t, prod:lower())
    end
    table.sort(t)
    local key = version .. ":" .. table.concat(t, ",")
    local hash = crypto.sha1(key):sub(1, 8)
    return hash
end

-- Read manifest.json from env dir
function M.read_manifest(env_dir)
    local path = env_dir .. "/manifest.json"
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return json.decode(content)
end

-- Write manifest.json to env dir
function M.write_manifest(env_dir, manifest)
    local path = env_dir .. "/manifest.json"
    local file = io.open(path, "w")
    file:write(json.encode(manifest))
    file:close()
end

-- Find existing env dir matching requirements
function M.find_existing_env(base_dir, version, products)
    local hash = M.hash_env(version, products)
    local env_dir = base_dir .. "/matlab-" .. version .. "-" .. hash
    local manifest = M.read_manifest(env_dir)
    if manifest and manifest.version == version then
        -- Compare sorted products
        local req = {}
        for prod in string.gmatch(products, "([^,]+)") do
            table.insert(req, prod:lower())
        end
        table.sort(req)
        local man = manifest.products or {}
        table.sort(man)
        if #req == #man then
            local match = true
            for i = 1, #req do
                if req[i] ~= man[i] then match = false break end
            end
            if match then return env_dir end
        end
    end
    return nil
end

return M