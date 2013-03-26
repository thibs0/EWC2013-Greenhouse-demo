-- Author: Thibault Cantegrel
-- see http://na.airvantage.net/develop/apiDocumentation/apiDocumentation

local json = require "json"

local A = { }  -- AirVantage Client Access


-- -----------------------------------------
-- AirVantage Authentication (simple, HTTPS)
-- -----------------------------------------

function onHttpResponse_Token( event )
    assert ( not event.isError, event.response )
    print ( "HTTP Response (token): ".. event.response )
    local response = json.decode( event.response )
	assert ( not response.error, "AirVantage error received: "..tostring(response.error) )

    A.access_token = assert ( response.access_token )
    A.refresh_token = response.refresh_token
    A.expiration_date = os.time() + response.expires_in
    A.token_required = false
end


function authenticate( user, passwd, client_id, client_secret )
    if A.token_required then return end
	A.token_required = true
	A.client_id = client_id
	A.client_secret = client_secret
	
	-- AirVantage simple authentication (HTTPS required in this case)
	network.request("https://na.m2mop.net/api/oauth/token?grant_type=password&username="..user.."&password="..passwd.."&client_id="..client_id.."&client_secret="..client_secret, "GET", onHttpResponse_Token)
end



-- -----------------------------------------
-- AirVantage Data Monitoring
-- -----------------------------------------


function onHttpResponse_LastDataValues( event )
    assert ( not event.isError, event.response )
    print ( "HTTP Response (last data values): ".. event.response )
	local response = json.decode( event.response )
	assert ( not response.error, "AirVantage error received: "..tostring(response.error) )
	
	A.monitor_callback ( response )
end


function onMonitoringTimer( event )
	print ("Monitoring cycle #"..tostring(event.count))
	
	if A.token_required then 
		print ("Skip monitoring cylcle (token being required)")
		return true
	end
		
	if A.expiration_date < os.time() then
		print ("Skip monitoring cylcle (token needs to be refreshed)")
		-- AirVantage refresh token
		A.token_required = true
		network.request("https://na.m2mop.net/api/oauth/token?grant_type=refresh_token&refresh_token="..A.refresh_token.."&client_id="..A.client_id.."&client_secret="..A.client_secret, "GET", onHttpResponse_Token)
		return true
	end

	-- AirVantage get last data values (HTTPS required in this case)
	network.request("https://na.m2mop.net/api/v1/systems/"..A.system.."/data?ids="..A.system_data.."&access_token=" .. A.access_token, "GET", onHttpResponse_LastDataValues)
end


function monitor_data(callback, delay, iterations, system, ...)

	A.monitor_callback = callback
	A.system = system
	A.system_data = ''
	for i,v in ipairs(arg) do
		if i == 1 then
			A.system_data = A.system_data .. v
		else
        	A.system_data = A.system_data .. "," .. v
        end
    end

	A.monitoringTimer = timer.performWithDelay(delay, onMonitoringTimer, iterations)
end


function pause_monitoring()
	if A.monitoringTimer then
		timer.pause(A.monitoringTimer)
	end
end

function resume_monitoring()
	if A.monitoringTimer then
		timer.resume(A.monitoringTimer)
	end
end



-- -----------------------------------------
-- AirVantage Send Command
-- -----------------------------------------


function onHttpResponse_command( event )
    assert ( not event.isError, event.response )
    print ( "HTTP Response (send command): ".. event.response )
	local response = json.decode( event.response )
	assert ( not response.error, "AirVantage error received: "..tostring(response.error) )
end


function send_command(app_name, app_rev, system_id, command_id)

	local headers = {
						["Content-Type"] = "application/json"
					}
	local body = {
					applicationName = app_name,
					applicationRevision = app_rev,
					systems = {
						uids = {
							system_id
						}
					},
					commandId = command_id,
				}
					
	local bodyString = json.encode(body);
	
	local params = {
				headers = headers,
				body = bodyString
				}
	
	-- AirVantage get last data values (HTTPS required in this case)
	network.request("https://na.m2mop.net/api/v1/operations/systems/command?access_token=" .. A.access_token, "POST", onHttpResponse_command, params)
end