local cjson = require "cjson"
local copas = require "copas"
local http = require "copas.http"
local encoding = require "encoding"
local sampev = require "lib.samp.events"

encoding.default = "cp1251"
u8 = encoding.UTF8

API = function(token)
	local obj = {
		end_point = "http://127.0.0.1:8000/api/v1/",
		access_token = token,
		debug = false
	}

	function obj:print(str)
		if self.debug then print(str) end
	end

	function obj:httpRequest(request, body, handler)
		--[[
			https://blast.hk/threads/20532/
			Исходник Гайд Асинхронные HTTP запросы в MoonLoader
			FYP 19 Ноя 2019
		]]--
		if not copas.running then
			copas.running = true
			lua_thread.create(function()
				wait(0)
				while not copas.finished() do
					local ok, err = copas.step(0)
					if ok == nil then error(err) end
					wait(0)
				end
				copas.running = false
			end)
		end
		if handler then
			return copas.addthread(function(r, b, h)
				copas.setErrorHandler(function(err) h(nil, err) end)
				h(http.request(r, b))
			end, request, body, handler)
		else
			local results
			local thread = copas.addthread(function(r, b)
				copas.setErrorHandler(function(err) results = {nil, err} end)
				results = table.pack(http.request(r, b))
			end, request, body)
			while coroutine.status(thread) ~= "dead" do wait(0) end
			return table.unpack(results)
		end
	end

	function obj:sendMessageAsync(message)
		if message and #message > 0 and #message < 96 then
			local body = cjson.encode({["text"] = message})
			body = u8:encode(body)
			self:httpRequest(self.end_point.."sendMessage?token="..self.access_token, body, function(response, code, headers, status)
				if response then
					self:print("sendMessageAsync() "..status)
				else
					print("sendMessageAsync() error:", code)
				end
			end)
		end
	end

	function obj:sendMapMarkerAsync(x, y)
		local body = cjson.encode({["x"] = x, ["y"] = y})
		body = u8:encode(body)
		self:httpRequest(self.end_point.."sendTarget?token="..self.access_token, body, function(response, code, headers, status)
			if response then
				self:print("sendMapMarkerAsync() "..status)
			else
				print("sendMapMarkerAsync() error:", code)
			end
		end)
	end

	function obj:sendPlayerAsync(id, x, y, z, color)
		local body = cjson.encode({["id"] = id, ["x"] = x, ["y"] = y, ["z"] = z, ["color"] = color})
		body = u8:encode(body)
		self:httpRequest(self.end_point.."sendPlayer?token="..self.access_token, body, function(response, code, headers, status)
			if response then
				self:print("sendPlayerAsync() "..status)
			else
				print("sendPlayerAsync() error:", code)
			end
		end)
	end

	function obj:sendPlayer(id, x, y, z, color)
		local body = cjson.encode({["id"] = id, ["x"] = x, ["y"] = y, ["z"] = z, ["color"] = color})
		body = u8:encode(body)
		local response, code, headers, status = self:httpRequest(self.end_point.."sendPlayer?token="..self.access_token, body)
		if response then
			self:print("sendPlayer() "..status)
		else
			print("sendPlayer() error:", code)
		end
		return response, code, headers, status
	end

	obj.onMapTarget = function(sender, timestamp, x, y) end

	obj.onPlayerMarker = function(sender, timestamp, playerId, x, y, z, color) end

	obj.onMessage = function(sender, timestamp, text) end

	function obj:updatesHandler(response, code, headers, status)
		if response then
			self:print("updateNetwork() "..status)
			local updates = cjson.decode(response)
			if #updates["response"] > 0 then
				for i, event in pairs(updates["response"]) do
					local sender = u8:decode(event["from"])
					local eventType = event["type"]

					if eventType == "MapTarget" then
						local x, y, z = tonumber(event["payload"]["x"]), tonumber(event["payload"]["y"]), 0
						local timestamp = event["timestamp"]
						self.onMapTarget(sender, timestamp, x, y)
						
					elseif eventType == "Player" then
						local playerId = tonumber(event["payload"]["id"])
						local x, y, z = tonumber(event["payload"]["x"]), tonumber(event["payload"]["y"]), tonumber(event["payload"]["z"])
						local color = event["payload"]["color"]
						local timestamp = event["timestamp"]
						self.onPlayerMarker(sender, timestamp, playerId, x, y, z, color)

					elseif eventType == "Message" then
						local text = u8:decode(event["payload"]["text"])
						local timestamp = event["timestamp"]
						self.onMessage(sender, timestamp, text)
					end
				end
			end
		end
		return response, code, headers, status
	end

	function obj:updateNetwork()
		local response, code, headers, status = self:updatesHandler(self:httpRequest(self.end_point.."getUpdates?token="..self.access_token))
		if not response then print("updateNetwork() error while connecting:", code) end
		return response, code, headers, status
	end

	setmetatable(obj, {})
	return obj
end

return API