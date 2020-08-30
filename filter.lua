--[[
	The community driven filter module
	Contributors so far:
		- Semaphorism	
]]
local http = game:GetService("HttpService")
local module = {
	version = 1; -- Don't touch unless you don't care for updates later on, or are modifying it yourself
	lists = {
		"https://raw.githubusercontent.com/GalacticArc/robloxscripts/master/blacklist.json"; -- Default primary list, keep this if you want up to date spam filters
	};
	filters = {};
	setting = {
		interval = 60; -- Updates the filters every 60 minutes, this will keep servers up to date even if they run for days. 
		-- Avoid spamming requests as well.
		autoupdate = true;
		-- Whether you want it to auto update the filters
		versioncheck = true;
		-- Whether you want to be warned when theres a new version.
	};
	debugmode = false;
	-- Put this to true if you want it to output whats happening, otherwise its silent.
}

function module.print(...)
	local args = {...}
	if module.debugmode then
		print(table.unpack(args))
	end
end

function module.warn(...)
	local args = {...}
	if module.debugmode then
		warn(table.unpack(args))
	end
end

-- Processes new filters
function module.addFilter(j)
	for _,f in pairs(j.list) do
		f.text = string.lower(f.text)
		table.insert(module.filters, f)
		module.print("Added \"".. f.text.."\" all:".. tostring(f.all or false))
	end
end

-- The update function
function module.update()
	module.warn("Begin update all filters")
	local failures = 0
	module.filters = {}
	for _, data in pairs(module.lists) do
		if typeof(data) == "string" then
			local success, err = pcall(function()
				local response = http:RequestAsync(
					{
						Url = data;
						Method = "GET";
					}
				)
			 
				-- Inspect the response table
				if response.Success then
					module.addFilter(http:JSONDecode(response.Body))
					module.print("Loaded filters from ".. data)
				else
					module.warn("Error loading filters from ".. data)
					failures = failures + 1
				end
			end)
		elseif typeof(data) == "Instance" then -- Support for requiring module lists
			local list = require(data)
			module.addFilter(list)
		end
	end
end

-- Process text specifically, use this for custom chat.
function module.process(text)
	local newtext = text
	local all = false
	for _,w in pairs(module.filters) do
		local f = string.find(text, w.text)
		if f then
			if w.all then
				-- If it replaces all text, skip checking next filters
				all = true
				break 
			else
				local l = string.len(w.text)
				newtext = string.sub(text, 1, f-1) .. string.rep("#", l) .. string.sub(text, f+l)
			end
		end
	end
	
	if all then
		newtext = string.rep("#", string.len(text))
	end
	module.print("Process \""..text.."\" into \""..newtext.."\"")
	return newtext
end

-- Process default roblox chat
function module.onChat(sender, obj, channelName)
	local player = game:GetService("Players"):FindFirstChild(sender)
	local text = string.lower(obj.Message)
	

	obj.Message = module.process(text)
end

-- Version check
function module.checkVersion()
	if not module.setting.versioncheck then
		return
	end
	local success, err = pcall(function()
		local response = http:RequestAsync(
			{ Url = "https://raw.githubusercontent.com/GalacticArc/robloxscripts/master/filter-version.json"; Method = "GET"; }
		)
	 
		-- Inspect the response table
		if response.Success then
			local data = http:JSONDecode(response.Body)
			if tonumber(data.latest) > module.version then
				warn("Filter is out of date, update for more features!")
			end
		else
			module.warn("Error checking version")
		end
	end)
end

-- function for updating the lists every interval of minutes
function module.thread()
	if not module.setting.autoupdate then
		return
	end
	while true do
		module.update()
		wait(module.setting.interval*60) 
	end
end

spawn(module.thread)
spawn(module.checkVersion)

return function(ChatService)
	if not ChatService then
		return module
	end
	
	warn("Setting up filter for default chat")
	ChatService:RegisterFilterMessageFunction("filterspam", module.onChat)
end
