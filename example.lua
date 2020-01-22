script_author("inf")
script_moonloader(026)

local api = require "api"
local sampev = require "lib.samp.events"

api = API("token")
local playerBlips = {}

function api.onMapTarget(sender, x, y)
	if placeWaypoint(x, y, 0) then
		print(string.format("{ffd666}onMapTarget@x=%.2f,y=%.2f from %s", x, y, sender))
	end
end

function api.onPlayerMarker(sender, playerId, x, y, z, color)
	for i, v in pairs(playerBlips) do removeBlip(v) end
	local blip = addBlipForCoord(x, y, z)
	changeBlipColour(blip, color)
	playerBlips[#playerBlips+1] = blip
	print(string.format("{ffd666}onPlayerMarker@id=%d,x=%.2f,y=%.2f,z=%.2f,color=0x%x from %s", playerId, x, y, z, color, sender))
end

function api.onMessage(sender, text, timestamp)
	sampAddChatMessage(string.format("{ffd666}%s{ffffff}: %s", sender, text), 0xffffffff)
	print(string.format("{ffd666}onMessage@text=%s,timestamp=%d from %s", text, timestamp, sender))
end

function cmd_cloudChat(message)
	api:sendMessageAsync(message)
end

function main()
	if not isSampLoaded() or not isCleoLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end

	sampRegisterChatCommand("/", cmd_cloudChat)

	while true do
		api:updateNetwork()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		local x, y, z = getCharCoordinates(PLAYER_PED)
		api:sendPlayer(id, x, y, z)
		wait(70)
	end
end

function sampev.onSendMapMarker(position)
	api:sendMapMarkerAsync(position.x, position.y)
end

function onScriptTerminate(LuaScript, quitGame)
	if LuaScript == thisScript() then
		for i, v in pairs(playerBlips) do removeBlip(v) end
	end
end
