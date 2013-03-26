-------------------------------------------------------------------------------
-- Copyright (c) 2012, 2013 Sierra Wireless and others.
-- All rights reserved. This program and the accompanying materials
-- are made available under the terms of the Eclipse Public License v1.0
-- which accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- Contributors:
--     Benjamin Cab�, Sierra Wireless - initial API and implementation
--     Ga�tan Morice, Sierra Wireless - initial API and implementation
--     Thibault Cantegrel, Sierra Wireless - Added: AirVantage
-------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- REQUIRES
-- ----------------------------------------------------------------------------

local sched  = require 'sched'
local modbus = require 'modbus'
local utils  = require 'utils'
local tableutils = require "utils.table"

-- Communication to server: (un)comment MQTT or AirVantage lines below (you can use both!)
--local mqtt   = require 'mqtt_library'
local airvantage = require 'airvantage'

-- ----------------------------------------------------------------------------
-- CONSTANTS
-- ----------------------------------------------------------------------------

local MQTT_DATA_PATH    = "/eclipsecon/demo-mihini/data/"
local MQTT_COMMAND_PATH = "/eclipsecon/demo-mihini/command/"
local MQTT_BROKER       = "m2m.eclipse.org"
local MQTT_PORT         = 1883

local AV_ASSET_ID = "GreenhouseDemo01"

local MODBUS_PORT = "/dev/ttyS0"     -- serial port on AirLink GX400
--local MODBUS_PORT = "/dev/ttyACM0" -- serial port on RaspPi
local MODBUS_CONF = {baudRate = 115200 }

local LOG_NAME = "GREENHOUSE_APP"

-- ----------------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
-- ----------------------------------------------------------------------------

local modbus_client
local modbus_client_pending_init = false
local av_asset
local mqtt_client


-- ----------------------------------------------------------------------------
-- DATA
-- ----------------------------------------------------------------------------

local modbus_address =
{luminosity  = 2,
 humidity    = 3,
 temperature = 1,
 switch      = 7}

local modbus_process =
{temperature = utils.processTemperature,
 humidity    = utils.processHumidity,
 luminosity  = utils.processLuminosity}

setmetatable(modbus_process,
             {__index = function (_, _) return utils.identity end})
   
-- ----------------------------------------------------------------------------
-- PROCESSES
-- ----------------------------------------------------------------------------

--- Init Modbus

local function init_modbus()
    if modbus_client_pending_init then return; end
    modbus_client_pending_init = true
	if modbus_client then modbus_client:close(); end
	sched.wait(1)
	modbus_client = modbus.new(MODBUS_PORT, MODBUS_CONF)
	sched.wait(1)
	log(LOG_NAME, "INFO", "Modbus client re-init'ed")
	modbus_client_pending_init = false
end


--- Read Modbus Register and send to MQTT or/and AirVantage

local last_values = {}

local function process_modbus ()
	if not modbus_client then 
		init_modbus()
		if not modbus_client then return; end
	end
	
	local values = modbus_client:readHoldingRegisters(1,0,9)
	
	if not values then
		log(LOG_NAME, "ERROR", "Unable to read modbus")
		init_modbus()
	return end
	
	local sval, val    -- value from sensor, data value computed from the sensor value
	local buffer = {}
	
	for data, address in pairs(modbus_address) do
		sval = utils.convertRegister(values, address)
		val = math.floor(modbus_process[data](sval))
		log(LOG_NAME, "INFO", "Read from modbus %s : %s", data, tostring(val))
		buffer[data] = val
	end
	
	-- Send to AirVantage if any value has changed
	for data, value in pairs(buffer) do
		local last_value = last_values[data]
		if value~=last_value then
			log(LOG_NAME, 'INFO', "Data changed: %s: %s->%s", data, tostring(last_value), tostring(value))
			last_values[data]=value
		else
			buffer[data]=nil
		end
	end
	if next(buffer) then
		-- mqtt_client:publish(MQTT_DATA_PATH..data, val)	-- uncomment to send to MQTT
		buffer.timestamp=os.time()
		log(LOG_NAME, 'INFO', "Sending to AirVantage. Date= %s", tostring(buffer.timestamp))
		av_asset :pushdata ('', buffer, 'now')	 -- uncomment to send to AirVantage
	end
end


--- Reacts to settings sent from MQTT by sending them to modbus

local function process_mqtt(topic, value)
	local data = utils.split(topic, "/")[4]
	log(LOG_NAME, "INFO", "Received from mqtt %s : %s", data, tostring(value))
	modbus_client:writeMultipleRegisters(1, modbus_address[data], string.pack("h", value))
end


--- Reacts to settings sent from AirVantage by sending them to modbus

local function process_airvantage(asset, buffer)
	for data, value in pairs(buffer) do
		log(LOG_NAME, "INFO", "Setting received from AirVantage %s : %s", data, tostring(value))
		modbus_client :writeMultipleRegisters (1, modbus_address[data], string.pack('h', value))
	end
	return 'ok'
end


--- Reacts to a request from AirVantage to toggle the switch
function process_av_toggleswitch(asset)
	log(LOG_NAME, "INFO", "ToggleSwitch command received from AirVantage")
	local value = last_values["switch"];
	if value == 0 then value = 1 else value = 0 end
	modbus_client :writeMultipleRegisters (1, modbus_address["switch"], string.pack('h', value))
	return 'ok'
end


-- ----------------------------------------------------------------------------
-- MAIN
-- ----------------------------------------------------------------------------

local function main()
	log.setlevel("INFO")
	log(LOG_NAME, "INFO", "Application started")
	
	modbus_client = modbus.new(MODBUS_PORT, MODBUS_CONF)
	log(LOG_NAME, "INFO", "Modbus           - OK")

	-- MQTT configuration
	-- mqtt_client = mqtt.client.create(MQTT_BROKER, MQTT_PORT, process_mqtt)
	-- log(LOG_NAME, "INFO", "MQTT Client - OK")
	-- mqtt_client:connect(LOG_NAME)
	-- mqtt_client:subscribe({MQTT_COMMAND_PATH.."#"})
    
    -- AirVantage agent configuration
    assert(airvantage.init())
    log(LOG_NAME, "INFO", "AirVantage agent - OK")
    
    av_asset = airvantage.newasset(AV_ASSET_ID)
    av_asset.tree.__default = process_airvantage
    av_asset.tree.commands.toggleswitch = process_av_toggleswitch
	av_asset :start()

    log(LOG_NAME, "INFO", "AirVantage asset - OK")
    
	log(LOG_NAME, "INFO", "Init done")
	
	sched.wait(2)
	while true do
		process_modbus()
		-- mqtt_client:handler()  -- comment if you don't use MQTT
		sched.wait(1)
	end
end

sched.run(main)
sched.loop()