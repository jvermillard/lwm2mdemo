local lwm2m = require 'lwm2m'
local socket = require 'socket'
local obj = require 'lwm2mobject'

-- Get script arguments.
local args = {...}
local serverip = args[1] or "54.228.25.31"
local serverport = args[2] or 5683
local deviceport = args[3] or 5682

-- Create UDP socket.
local udp = socket.udp();
udp:setsockname('*', deviceport)

-- Define a device object.
local deviceObj = obj.new(3, {
  [0]  = "Leshan Corp",                   -- manufacturer
  [1]  = "Demo Lightweight M2M Client",                 -- model number
  [2]  = "acme345000123",                              -- serial number
  [3]  = "0.1",                                    -- firmware version
  [10] = {read = function()
    local f = io.popen("vmstat -s -SB |grep 'free memory' | tr -s ' ' |cut -d ' ' -f 2 ") -- runs command
    local l = f:read("*a") -- read output of command
    print(l)
    f:close()
    return tonumber(l)
  end },
  [13] = {read = function() return os.time() end}, -- current time
})

local connMonitoring = obj.new(4, {
  [0] = 21,
  [2] = { read = function () 
    local f  = io.popen("cat /proc/net/wireless | tail -1 | tr -s ' ' | cut -d ' ' -f 5 | tr -d '.'")
    local l = f:read("*a")
    f:close()
    return tonumber(l)
  end},
  [3] = { read = function () 
    local f = io.popen("cat /proc/net/wireless | tail -1 | tr -s ' ' | cut -d ' ' -f 4 | tr -d '.'")
    local l = f:read("*a")
    f:close()
    return tonumber(l)
  end},
--  [4] = { read = function() 
--   local f = io.popen("/sbin/ifconfig wlan0 |head -2 |tail -1 | tr -s ' ' |cut -d ' ' -f 3 | cut -d ':' -f 2")
--    local l = f:read("*a")
--    f:close()
--    return l
--  end
--}
})

local location = obj.new(6, {
	[0] = "43.5723",
	[1] = "153.21760",
	[2] = "140",
	[3] = "15",
	[5] = {read = function() return os.time() end}
})

local connStats = obj.new(7, {
	[0] = 0,
	[1] = 0,
	[2] = { read = function() 
		local f = io.popen("/sbin/ifconfig wlan0 |tail -n 2 |head -n 1 | tr -s ' ' | cut -d ' ' -f 7 |cut -d ':'  -f 2")
		local l = f:read("*a")
		f:close()
		return tonumber(l)
	end},
	[3] = { read = function() 
		local f = io.popen("/sbin/ifconfig wlan0 |tail -n 2 |head -n 1 | tr -s ' ' | cut -d ' ' -f 3 |cut -d ':'  -f 2")
		local l = f:read("*a")
		f:close()
		return tonumber(l)
	end},
})
-- Initialize lwm2m client.
local ll = lwm2m.init("lua-client", {deviceObj, connMonitoring, connStats, location},
  function(data,host,port) udp:sendto(data,host,port) end)

-- Add server and register to it.
ll:addserver(123, serverip, serverport, 12345, "", "U")
ll:register()

-- set timeout for a non-blocking receivefrom call.
udp:settimeout(2)

-- Communicate ...
repeat
  ll:step()
  local data, ip, port, msg = udp:receivefrom()
  if data then
    ll:handle(data,ip,port)
  end
  -- notify the resource /3/0/13 change
  -- (every 5seconds because of the timeout configuration)
  ll:resourcechanged("/3/0/10")
  ll:resourcechanged("/3/0/13")
  ll:resourcechanged("/4/0/2")
until false
