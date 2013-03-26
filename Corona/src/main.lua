--require('debugger')('127.0.0.1', 10000, 'corona-sim');
display.setStatusBar( display.HiddenStatusBar )

local airvantage = require("airvantage")

local SENSOR_LIFESPAN = 25000 -- in ms

local CLIENT_ID = "YOUR_CLIENT_ID"  -- replace me!
local CLIENT_SECRET = "YOUR_CLIENT_SECRET"  -- replace me!
local SYSTEM_ID = "YOUR_SYSTEM_ID"  -- replace me!
local APP_NAME = "GreenhouseDemo"
local APP_VERSION = "0.2"
local CMD_ID = "GreenhouseDemo01.toggleswitch"
local u = "YOUR_USER_ID"  -- replace me!
local p = "YOUR_USER_PASSWORD"  -- replace me!
local av_client = {}

system.activate( "multitouch" )

-----------------------------------------------
-- Initialize static UI elements
-----------------------------------------------
local bkg = display.newImage( "bg.jpg", true )
bkg.width = display.contentWidth
bkg.height = display.contentHeight
bkg.x = display.contentWidth/2
bkg.y = display.contentHeight/2

humidityGauge = display.newRect(display.contentWidth/2 - 200, display.contentHeight/2 - 42, 270, 260)
humidityGauge.yReference = display.contentHeight/2 - 42 - 340
humidityGauge.strokeWidth = 0
humidityGauge:setFillColor(20, 20, 240)
humidityGauge.alpha = 0.8

local flower = display.newImage( "flower.png", true )
flower.width = 411
flower.height = 625
flower.x = display.contentWidth/2 - 70
flower.y = display.contentHeight/2 + 195
--flower.alpha = 0.8

local lightBtnOff = display.newImage( "button_up.png", true )
lightBtnOff.width = 146
lightBtnOff.height = 208
lightBtnOff.x = 630
lightBtnOff.y = 350

local lightBtnOn = display.newImage( "button_down.png", true )
lightBtnOn.width = 146
lightBtnOn.height = 208
lightBtnOn.x = 630
lightBtnOn.y = 350
lightBtnOn.isVisible = false

local sensorsLabel = display.newText( "Greenhouse demo", 0, 0, native.systemFont, 36 )
sensorsLabel:setTextColor( 0, 0, 0 )
sensorsLabel.x = display.contentWidth/2 + 150
sensorsLabel.y = 150

local temperatureLabel= display.newText( "Temperature: 00.00 °C", 0, 0, native.systemFont, 36 )
temperatureLabel:setTextColor( 0, 0, 0 )
temperatureLabel.x = 292
temperatureLabel.y = 290

local luminosityLabel= display.newText( "Luminosity: 00.00 lx", 0, 0, native.systemFont, 36 )
luminosityLabel:setTextColor( 0, 0, 0 )
luminosityLabel.x = 280
luminosityLabel.y = 340

local sensorGroups = {}

local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function updateHumidity (humidity)
	humidityGauge.yScale = tonumber(humidity) / 100. + 0.01
end

local function updateTemperature(temperature)
	temperatureLabel.text = 'Temperature: ' .. round(tonumber(temperature), 2) .. ' °C'
end

local function updateLuminosity(luminosity)
	luminosityLabel.text = 'Luminosity: ' .. round(tonumber(luminosity), 2) .. ' lx'
end

local function updateSwitch(switchState)
	if (lightBtnOn.isVisible and tonumber(switchState) == 0) then
		lightBtnOn.isVisible = false
		lightBtnOff.isVisible = true
		system.vibrate()
	elseif (lightBtnOff.isVisible and tonumber(switchState) == 1) then
		lightBtnOn.isVisible = true
		lightBtnOff.isVisible = false
		system.vibrate()
	end
end


-- AirVantage data monitoring callback
function onDataUpdate(data)
	updateHumidity(data["GreenhouseDemo01.humidity"][1].value);
	updateTemperature(data["GreenhouseDemo01.temperature"][1].value);
	updateLuminosity(data["GreenhouseDemo01.luminosity"][1].value);
	updateSwitch(data["GreenhouseDemo01.switch"][1].value);
end


-- AirVantage authentication
authenticate(u, p, CLIENT_ID, CLIENT_SECRET);


-- React on switch touch => send command to AirVantage to toggle the switch
local function onTouch( event )
	if event.phase == "began" then
		if (event.target == lightBtnOn) then
			send_command(APP_NAME, APP_VERSION, SYSTEM_ID, CMD_ID)
		else
			send_command(APP_NAME, APP_VERSION, SYSTEM_ID, CMD_ID)
		end
		system.vibrate()
	end
	-- Important to return true. This tells the system that the event
	-- should not be propagated to listeners of any objects underneath.
	return true
end

lightBtnOff:addEventListener( "touch", onTouch )
lightBtnOn:addEventListener( "touch", onTouch )


-- Start the monitoring with AirVantage
monitor_data(onDataUpdate, 10000, 0, SYSTEM_ID, "GreenhouseDemo01.humidity", "GreenhouseDemo01.temperature", "GreenhouseDemo01.luminosity", "GreenhouseDemo01.switch")
