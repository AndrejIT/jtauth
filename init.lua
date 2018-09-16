--

local userbase = jtdb:new(minetest.get_worldpath() .. "/auth")

-- if auth.txt present, import all records fron there and merge with existing data
-- then rename to auth.txt.jtbk
function authtxt_import()
    local authtxt = io.open(minetest.get_worldpath() .. "/auth.txt", "r")
    if not authtxt then
        -- no auth.txt, ok, fine.
        return
    end
    minetest.log("action", "Mod jtauth started import of auth.txt")
    local records = {}
    local n = 0
    for line in authtxt:lines() do
        if line and line ~= "" then
            local name, password, privilegestring, last_login = string.match(line, "([^:]*):([^:]*):([^:]*):([^:]*)")
            records[name] = line
        end
        n = n+1
        if n > 10000 then -- write records in chunks to avoid intensively rewriting jtdb index
            userbase:write_array(records)
            records = {}
            n = 0
        end
    end
    userbase:write_array(records) -- write remaining records
    os.rename(minetest.get_worldpath() .. "/auth.txt", minetest.get_worldpath() .. "/auth.txt.jtbk")
    minetest.log("action", "Mod jtauth imported auth.txt file and created backup in auth.txt.jtbk")
end
authtxt_import()

minetest.log("info", "Mod jtauth started. Files auth.jtdb and auth.jtdb and jtid are locked")

userbase.escape_value = true
userbase.use_cache = true
userbase.escape_v = function(value, key)
    assert(type(value) == "table",
        "Conversion from table to string will happen automatically!")
    assert(type(value.password) == "string")
    assert(type(value.privileges) == "table")
    assert(type(value.last_login) == "number")
    local name = key
    local privstring = minetest.privs_to_string(value.privileges)
    value = name..":"..value.password..":"..privstring..":"..value.last_login..'\n'
    -- additional '\n' is intentional to visually distinquish from regulat auth.txt
    return value
end
userbase.unescape_v = function(value, key)
    local name, password, privilegestring, last_login = string.match(value, "([^:]*):([^:]*):([^:]*):([^:]*)")
    if not name or not password or not privilegestring then
		error("Invalid line or corrypted auth.jtdb! "..dump(value))
	end
    local privileges = minetest.string_to_privs(privilegestring)
    value = {password=password, privileges=privileges, last_login=tonumber(last_login)}
    return value
end

minetest.register_authentication_handler({
	get_auth = function(name)
		assert(type(name) == "string")
		-- Figure out what password to use for a new player (singleplayer
		-- always has an empty password, otherwise use default, which is
		-- usually empty too)
		local new_password_hash = ""
		-- If not in authentication table, return nil
		if userbase.id[name] == nil then
			return nil
		end
        -- read data
        local user_record = userbase:read(name)
		-- Figure out what privileges the player should have.
		-- Take a copy of the privilege table
		local privileges = {}
		for priv, _ in pairs(user_record.privileges) do
			privileges[priv] = true
		end
		-- If singleplayer, give all privileges except those marked as give_to_singleplayer = false
		if minetest.is_singleplayer() then
			for priv, def in pairs(minetest.registered_privileges) do
				if def.give_to_singleplayer then
					privileges[priv] = true
				end
			end
		-- For the admin, give everything
		elseif name == minetest.setting_get("name") then
			for priv, def in pairs(minetest.registered_privileges) do
				privileges[priv] = true
			end
		end
		-- All done
		return {
			password = user_record.password,
			privileges = privileges,
            last_login = user_record.last_login,
		}
	end,
	create_auth = function(name, password)
		assert(type(name) == "string")
		assert(type(password) == "string")
		minetest.log('info', "Built-in authentication handler adding player '"..name.."'")
		local user_record = {
			password = password,
			privileges = minetest.string_to_privs(minetest.setting_get("default_privs")),
            last_login = os.time(),
		}
        userbase:write(name, user_record)
	end,
    delete_auth = function(name)
		assert(type(name) == "string")
        if userbase.id[name] ~= nil then
            userbase:delete(name)
            return true
        end
        return false
    end,
	set_password = function(name, password)
		assert(type(name) == "string")
		assert(type(password) == "string")
		if userbase.id[name] == nil then
			minetest.get_auth_handler().create_auth(name, password)
		else
            local user_record = userbase:read(name)
			minetest.log('info', "Built-in authentication handler setting password of player '"..name.."'")
			user_record.password = password
			userbase:write(name, user_record)
		end
	end,
	set_privileges = function(name, privileges)
		assert(type(name) == "string")
		assert(type(privileges) == "table")
		if userbase.id[name] == nil then
			minetest.get_auth_handler().create_auth(name, minetest.get_password_hash(name, minetest.setting_get("default_password")))
		end
        local user_record = userbase:read(name)
		user_record.privileges = privileges
        userbase:write(name, user_record)
		minetest.notify_authentication_modified(name)
	end,
    reload = function()
        return true
    end,
    record_login = function(name)
		assert(type(name) == 'string')
        if userbase.id[name] == nil then
            minetest.log('action', "Tried to record login of unexistent player '"..name.."'")
        else
            local user_record = userbase:read(name)
            user_record.last_login = os.time()
    		userbase:write(name, user_record)
        end
	end,
})

minetest.register_on_prejoinplayer(function(name, ip)
	if userbase.id[name] ~= nil then
		return
	end
	-- Forbid same names with different cases
	if userbase.id_lowercase[string.lower(name)] ~= nil then
		return ("\nName "..name.." already registered with different case symbols. \n"..
			" Check the case or use different name. ")
	end
end)

minetest.register_on_shutdown(function()
    userbase:close()
    minetest.log("action", "Mod jtauth did maintenance on it's main file auth.jtdb. Now it's content is equivalent to auth.txt")
end)
