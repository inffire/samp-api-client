script_author("inf")
script_moonloader(026)

local api = require "api"
local sampev = require "lib.samp.events"

api = API("token")

local playerBlips = {}

function api.onMapTarget(sender, timestamp, x, y)
	if placeWaypoint(x, y, 0) then
		print(string.format("{ffd666}onMapTarget@x=%.2f,y=%.2f from %s@%d", x, y, sender, timestamp))
	end
end

function api.onPlayerMarker(sender, timestamp, playerId, x, y, z, color)
	if playerBlips[playerId] then
		setBlipCoordinates(playerBlips[playerId]["blip"], x, y, z)
		changeBlipColour(playerBlips[playerId]["blip"], color)
	else
		playerBlips[playerId] = {}
		local blip = addBlipForCoord(x, y, z)
		changeBlipColour(blip, color)
		playerBlips[playerId]["blip"] = blip
	end
	playerBlips[playerId]["timestamp"] = os.clock()
	print(string.format("{ffd666}onPlayerMarker@id=%d,x=%.2f,y=%.2f,z=%.2f,color=0x%x from %s@%d", playerId, x, y, z, color, sender, timestamp))
end

function api.onMessage(sender, timestamp, text)
	sampAddChatMessage(string.format("{ffd666}%s{ffffff}: %s", sender, text), 0xffffffff)
	print(string.format("{ffd666}onMessage@text=%s from %s@%d", text, sender, timestamp))
end

function cmd_cloudChat(message)
	api:sendMessageAsync(message)
end

function cmd_markPlayer(arg)
	local playerId = tonumber(arg)
	if playerId then
		local result, ped = sampGetCharHandleBySampPlayerId(playerId)
		if result then
			lua_thread.create(function()
				while doesCharExist(ped) do
					local x, y, z = getCharCoordinates(ped)
					local color = sampGetPlayerColor(playerId)
					api:sendPlayer(playerId, x, y, z, color)
					wait(228)
				end
			end)
		end
	end
end

function main()
	if not isSampLoaded() or not isCleoLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end

	sampRegisterChatCommand("/", cmd_cloudChat)
	sampRegisterChatCommand("markplayer", cmd_markPlayer)

	while true do
		local response, code, headers, status = api:updateNetwork()
		if response then
			local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
			local x, y, z = getCharCoordinates(PLAYER_PED)
			api:sendPlayerAsync(id, x, y, z, 0xff00ffff)
		end

		-- clean outdated blips
		for i, v in pairs(playerBlips) do
			if os.clock() > v["timestamp"] + 5 then
				removeBlip(v["blip"])
				playerBlips[i] = nil
			end
		end
		wait(0)
	end
end

function sampev.onSendMapMarker(position)
	api:sendMapMarkerAsync(position.x, position.y)
end

function onScriptTerminate(LuaScript, quitGame)
	if LuaScript == thisScript() then
		for i, v in pairs(playerBlips) do removeBlip(v["blip"]) end
	end
end
