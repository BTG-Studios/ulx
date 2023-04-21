-- This module holds any type of chatting functions
CATEGORY_NAME = "Chat"

------------------------------ Psay ------------------------------
local seepsayAccess = "ulx basicallythensa"
if SERVER then ULib.ucl.registerAccess( seepsayAccess, ULib.ACCESS_OPERATOR, "Ability to see 'ulx psay'", "Other" ) end 

function ulx.psay( calling_ply, target_ply, message )
	if calling_ply:GetNWBool( "ulx_muted", false ) then
		ULib.tsayError( calling_ply, "You are muted, and therefore cannot speak! Use asay for admin chat if urgent.", true )
		return
	end

	local players = player.GetAll()
	for i=#players, 1, -1 do
		local v = players[ i ]
		if not ULib.ucl.query( v, seepsayAccess ) and v ~= calling_ply and v ~= target_ply then -- Calling player always gets to see the echo
			table.remove( players, i )
		end
	end

	ulx.fancyLog( players, "#P to #P: " .. message, calling_ply, target_ply )
end
local psay = ulx.command( CATEGORY_NAME, "ulx psay", ulx.psay, "!p", true )
psay:addParam{ type=ULib.cmds.PlayerArg, target="!^", ULib.cmds.ignoreCanTarget }
psay:addParam{ type=ULib.cmds.StringArg, hint="message", ULib.cmds.takeRestOfLine }
psay:defaultAccess( ULib.ACCESS_ALL )
psay:help( "Send a private message to target." )

------------------------------ Asay ------------------------------
local seeasayAccess = "ulx seeasay"
if SERVER then ULib.ucl.registerAccess( seeasayAccess, ULib.ACCESS_OPERATOR, "Ability to see 'ulx asay'", "Other" ) end -- Give operators access to see asays echoes by default

function ulx.asay( calling_ply, message )
	local format
	local me = "/me "
	if message:sub( 1, me:len() ) == me then
		format = "(ADMINS) *** #P #s"
		message = message:sub( me:len() + 1 )
	else
		format = "#P to admins: #s"
	end

	local players = player.GetAll()
	for i=#players, 1, -1 do
		local v = players[ i ]
		if not ULib.ucl.query( v, seeasayAccess ) and v ~= calling_ply then -- Calling player always gets to see the echo
			table.remove( players, i )
		end
	end

	ulx.fancyLog( players, format, calling_ply, message )
end
local asay = ulx.command( CATEGORY_NAME, "ulx asay", ulx.asay, "@", true, true )
asay:addParam{ type=ULib.cmds.StringArg, hint="message", ULib.cmds.takeRestOfLine }
asay:defaultAccess( ULib.ACCESS_ALL )
asay:help( "Send a message to currently connected admins." )

------------------------------ Tsay ------------------------------
function ulx.tsay( calling_ply, message )
	ULib.tsay( _, message )

	if ULib.toBool( GetConVarNumber( "ulx_logChat" ) ) then
		ulx.logString( string.format( "(tsay from %s) %s", calling_ply:IsValid() and calling_ply:Nick() or "Console", message ) )
	end
end
local tsay = ulx.command( CATEGORY_NAME, "ulx tsay", ulx.tsay, "@@", true, true )
tsay:addParam{ type=ULib.cmds.StringArg, hint="message", ULib.cmds.takeRestOfLine }
tsay:defaultAccess( ULib.ACCESS_ADMIN )
tsay:help( "Send a message to everyone in the chat box." )

------------------------------ Csay ------------------------------
function ulx.csay( calling_ply, message )
	ULib.csay( _, message )

	if ULib.toBool( GetConVarNumber( "ulx_logChat" ) ) then
		ulx.logString( string.format( "(csay from %s) %s", calling_ply:IsValid() and calling_ply:Nick() or "Console", message ) )
	end
end
local csay = ulx.command( CATEGORY_NAME, "ulx csay", ulx.csay, "@@@", true, true )
csay:addParam{ type=ULib.cmds.StringArg, hint="message", ULib.cmds.takeRestOfLine }
csay:defaultAccess( ULib.ACCESS_ADMIN )
csay:help( "Send a message to everyone in the middle of their screen." )

------------------------------ Thetime ------------------------------
local waittime = 60
local lasttimeusage = -waittime
function ulx.thetime( calling_ply )
	if lasttimeusage + waittime > CurTime() then
		ULib.tsayError( calling_ply, "I just told you what time it is! Please wait " .. waittime .. " seconds before using this command again", true )
		return
	end

	local hour = math.random(1,12)
	local minute = math.random(0,59)
	local minuteStr = minute < 10 and "0"..minute or minute
	local ampm = math.random(1,2) == 1 and "AM" or "PM"

	lasttimeusage = CurTime()
	ulx.fancyLog( "The time is now #s.", hour..":"..minuteStr.." "..ampm )
end
local thetime = ulx.command( CATEGORY_NAME, "ulx thetime", ulx.thetime, "!thetime" )
thetime:defaultAccess( ULib.ACCESS_ALL )
thetime:help( "Shows you the real time." )


------------------------------ Adverts ------------------------------
ulx.adverts = ulx.adverts or {}
local adverts = ulx.adverts -- For XGUI, too lazy to change all refs

local function doAdvert( group, id )

	if adverts[ group ][ id ] == nil then
		if adverts[ group ].removed_last then
			adverts[ group ].removed_last = nil
			id = 1
		else
			id = #adverts[ group ]
		end
	end

	local info = adverts[ group ][ id ]

	local message = string.gsub( info.message, "%%curmap%%", game.GetMap() )
	message = string.gsub( message, "%%host%%", GetConVarString( "hostname" ) )
	message = string.gsub( message, "%%ulx_version%%", ULib.pluginVersionStr( "ULX" ) )

	if not info.len then -- tsay
		local lines = ULib.explode( "\\n", message )

		for i, line in ipairs( lines ) do
			local trimmed = line:Trim()
			if trimmed:len() > 0 then
				ULib.tsayColor( _, true, info.color, trimmed ) -- Delaying runs one message every frame (to ensure correct order)
			end
		end
	else
		ULib.csay( _, message, info.color, info.len )
	end

	ULib.queueFunctionCall( function()
		local nextid = math.fmod( id, #adverts[ group ] ) + 1
		timer.Remove( "ULXAdvert" .. type( group ) .. group )
		timer.Create( "ULXAdvert" .. type( group ) .. group, adverts[ group ][ nextid ].rpt, 1, function() doAdvert( group, nextid ) end )
	end )
end

-- Whether or not it's a csay is determined by whether there's a value specified in "len"
function ulx.addAdvert( message, rpt, group, color, len )
	local t

	if group then
		t = adverts[ tostring( group ) ]
		if not t then
			t = {}
			adverts[ tostring( group ) ] = t
		end
	else
		group = table.insert( adverts, {} )
		t = adverts[ group ]
	end

	local id = table.insert( t, { message=message, rpt=rpt, color=color, len=len } )

	if not timer.Exists( "ULXAdvert" .. type( group ) .. group ) then
		timer.Create( "ULXAdvert" .. type( group ) .. group, rpt, 1, function() doAdvert( group, id ) end )
	end
end

------------------------------ Gimp ------------------------------
ulx.gimpSays = ulx.gimpSays or {} -- Holds gimp says
local gimpSays = ulx.gimpSays -- For XGUI, too lazy to change all refs
local ID_GIMP = 1
local ID_MUTE = 2

function ulx.addGimpSay( say )
	table.insert( gimpSays, say )
end

function ulx.clearGimpSays()
	table.Empty( gimpSays )
end

function ulx.gimp( calling_ply, target_plys, should_ungimp )
	for i=1, #target_plys do
		local v = target_plys[ i ]
		if should_ungimp then
			v.gimp = nil
		else
			v.gimp = ID_GIMP
		end
		v:SetNWBool("ulx_gimped", not should_ungimp)
	end

	if not should_ungimp then
		ulx.fancyLogAdmin( calling_ply, "#A gimped #T", target_plys )
	else
		ulx.fancyLogAdmin( calling_ply, "#A ungimped #T", target_plys )
	end
end
local gimp = ulx.command( CATEGORY_NAME, "ulx gimp", ulx.gimp, "!gimp" )
gimp:addParam{ type=ULib.cmds.PlayersArg }
gimp:addParam{ type=ULib.cmds.BoolArg, invisible=true }
gimp:defaultAccess( ULib.ACCESS_ADMIN )
gimp:help( "Gimps target(s) so they are unable to chat normally." )
gimp:setOpposite( "ulx ungimp", {_, _, true}, "!ungimp" )

------------------------------ Mute ------------------------------
if SERVER then 
	local function createMuteTable()
		if not sql.TableExists("mutes") then 
			sql.Query("CREATE TABLE mutes (sid TEXT PRIMARY KEY, unmuteTime NUMBER)")
		end
	end

	function ulx.recordMute(steamid64, unmuteTime)
		local muteTime = tonumber(unmuteTime)
		local steamid = sql.SQLStr(steamid64)
		if muteTime == 0 then 
			sql.Query("DELETE FROM mutes WHERE sid=" .. steamid)
		else 
			sql.Query("REPLACE INTO mutes VALUES("..steamid..", "..muteTime..")")
		end
	end

	function ulx.recordMuteS0(steamid, unmuteTime)
		local sid64 = util.SteamIDTo64(steamid)
		if string.len(sid64) > 1 then 
			recordMute(sid64, unmuteTime)
		end
	end

	local function checkExpiredMutes()
		local currentTime = os.time()
		local muteList = sql.Query("SELECT sid FROM mutes WHERE unmuteTime < "..currentTime)
		if muteList then 
			PrintTable(muteList)
			local playerList = {}
			for k,v in pairs(player.GetAll()) do 
				playerList[v:SteamID64()] = v
			end
			for _,v in pairs(muteList) do 
				if playerList[v.sid] then 
					local ply = playerList[v.sid]
					ply:ChatPrint("Your mute has expired and has been lifted.")
					ply:SetNWBool("ulx_muted", false)
					ply.gimp = nil
				end
			end
		end
		sql.Query("DELETE FROM mutes WHERE unmuteTime < "..currentTime)
	end

	local function mutePlayerConnect(ply)
		local steamid = sql.SQLStr(ply:SteamID64())
		local isMuted = sql.QueryValue("SELECT unmuteTime FROM mutes WHERE sid="..steamid)
		if isMuted then 
			ply:ChatPrint("You were muted during a previous play session.")
			local unmuteTime = isMuted >= 2140000000 and "Never" or os.date("%b %d %Y at %I:%M %p", isMuted)
			ply:ChatPrint("Your mute will expire: "..unmuteTime)
			ply:SetNWBool("ulx_muted", true)
			ply.gimp = ID_MUTE
		end
	end
	hook.Add("PlayerInitialSpawn", "mutePlayerConnect", mutePlayerConnect)

	timer.Create("expiredMuteCheck", 15, 0, checkExpiredMutes)

	createMuteTable()
end
function ulx.mute( calling_ply, target_ply, minutes, reason )
	if target_ply:IsListenServerHost() or target_ply:IsBot() then
		ULib.tsayError( calling_ply, "This player is immune", true )
		return
	end
	--

	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A muted #T " .. time
	if reason and reason ~= "" then str = str .. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason )

	target_ply:SetNWBool("ulx_muted", true)
	target_ply.gimp = ID_MUTE
	if SERVER then 
		ulx.recordMute(target_ply:SteamID64(), minutes > 0 and (os.time() + (minutes * 60)) or 2140000000) 
	end
end

local mute = ulx.command( CATEGORY_NAME, "ulx mute", ulx.mute, "!mute" )
mute:addParam{ type=ULib.cmds.PlayerArg }
mute:addParam{ type=ULib.cmds.NumArg, hint="minutes, 0 for perma", ULib.cmds.allowTimeString, min=0 }
mute:addParam{ type=ULib.cmds.StringArg, hint="reason", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
mute:defaultAccess( ULib.ACCESS_ADMIN )
mute:help( "Mutes target." )

function ulx.unmute( calling_ply, target_ply )
	ulx.fancyLogAdmin( calling_ply, "#A unmuted #T", target_ply )
	ulx.recordMute(target_ply:SteamID64(), 0)
	target_ply:SetNWBool("ulx_muted", false)
	target_ply.gimp = nil
end
local unmute = ulx.command( CATEGORY_NAME, "ulx unmute", ulx.unmute, "!unmute" )
unmute:addParam{ type=ULib.cmds.PlayerArg }
unmute:defaultAccess( ULib.ACCESS_ADMIN )
unmute:help( "Unmuted target." )

if SERVER then
	local function gimpCheck( ply, strText )
		if ply.gimp == ID_MUTE then return "" end
		if ply.gimp == ID_GIMP then
			if #gimpSays < 1 then return nil end
			return gimpSays[ math.random( #gimpSays ) ]
		end
	end
	hook.Add( "PlayerSay", "ULXGimpCheck", gimpCheck, HOOK_LOW )
end

------------------------------ Gag ------------------------------
if SERVER then 
	local function createGagTable()
		if not sql.TableExists("gags") then 
			sql.Query("CREATE TABLE gags (sid TEXT PRIMARY KEY, ungagTime NUMBER)")
		end
	end

	function ulx.recordGag(steamid64, ungagTime)
		local gagTime = tonumber(ungagTime)
		local steamid = sql.SQLStr(steamid64)
		if gagTime == 0 then 
			sql.Query("DELETE FROM gags WHERE sid="..steamid)
		else 
			sql.Query("REPLACE INTO gags VALUES("..steamid..", "..gagTime..")")
		end
	end

	function ulx.recordGagS0(steamid, ungagTime)
		local sid64 = util.SteamIDTo64(steamid)
		if string.len(sid64) > 1 then 
			recordGag(sid64, ungagTime)
		end
	end

	local function gagPlayerConnect(ply)
		local steamid = sql.SQLStr(ply:SteamID64())
		local isGagged = sql.QueryValue("SELECT ungagTime FROM gags WHERE sid="..steamid)
		if isGagged then 
			ply:ChatPrint("You were gagged during a previous play session.")
			local ungagTime = isGagged >= 2140000000 and "Never" or os.date("%b %d %Y at %I:%M %p", isGagged)
			ply:ChatPrint("Your gag will expire: "..ungagTime)
			ply:SetNWBool("ulx_gagged", true)
			ply.ulx_gagged = true
		end
	end
	hook.Add("PlayerInitialSpawn", "gagPlayerConnect", gagPlayerConnect)

	local function checkExpiredGags()
		local currentTime = os.time()
		local gagList = sql.Query("SELECT sid FROM gags WHERE ungagTime < "..currentTime)
		if gagList then 
			local playerList = {}
			for k,v in pairs(player.GetAll()) do 
				playerList[v:SteamID64()] = v
			end
			for _,v in pairs(gagList) do 
				if playerList[v.sid] then 
					local ply = playerList[v.sid]
					ply:ChatPrint("Your gag has expired and has been lifted.")
					ply:SetNWBool("ulx_gagged", false)
					ply.ulx_gagged = false
				end
			end
		end
		sql.Query("DELETE FROM gags WHERE ungagTime < "..currentTime)
	end

	timer.Create("expiredGagCheck", 15, 0, checkExpiredGags)

	createGagTable()
end
function ulx.gag( calling_ply, target_ply, minutes, reason )
	if target_ply:IsListenServerHost() or target_ply:IsBot() then
		ULib.tsayError( calling_ply, "This player is immune", true )
		return
	end
	--

	local time = "for #s"
	if minutes == 0 then time = "permanently" end
	local str = "#A gagged #T " .. time
	if reason and reason ~= "" then str = str .. " (#s)" end
	ulx.fancyLogAdmin( calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime( minutes * 60 ) or reason, reason )

	target_ply.ulx_gagged = true
	target_ply:SetNWBool("ulx_gagged", true)
	ulx.recordGag(target_ply:SteamID64(), minutes > 0 and (os.time() + (minutes * 60)) or 2140000000) 
end

local gag = ulx.command( CATEGORY_NAME, "ulx gag", ulx.gag, "!gag" )
gag:addParam{ type=ULib.cmds.PlayerArg }
gag:addParam{ type=ULib.cmds.NumArg, hint="minutes, 0 for perma", ULib.cmds.allowTimeString, min=0 }
gag:addParam{ type=ULib.cmds.StringArg, hint="reason", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
gag:defaultAccess( ULib.ACCESS_ADMIN )
gag:help( "Gags target." )

function ulx.ungag( calling_ply, target_ply )
	ulx.fancyLogAdmin( calling_ply, "#A ungagged #T", target_ply )
	ulx.recordGag(target_ply:SteamID64(), 0)
	target_ply:SetNWBool("ulx_gagged", false)
	target_ply.ulx_gagged = false
end
local ungag = ulx.command( CATEGORY_NAME, "ulx ungag", ulx.ungag, "!ungag" )
ungag:addParam{ type=ULib.cmds.PlayerArg }
ungag:defaultAccess( ULib.ACCESS_ADMIN )
ungag:help( "Ungags target." )

local function gagHook( listener, talker )
	if talker.ulx_gagged then
		return false
	end
end
hook.Add( "PlayerCanHearPlayersVoice", "ULXGag", gagHook )

if CLIENT then 
	hook.Add( "HUDPaint", "GagMuteDisplayHook", function()
		if LocalPlayer():GetNWBool("ulx_gagged", false) then 
			local boxPosX, boxPosY = 15, 15
			local panelContent = "You are gagged and cannot use voice chat"
			surface.SetDrawColor( 156, 0, 0, 32 )
			surface.SetFont( "Trebuchet24" )
			surface.SetTextColor( 255, 255, 255, 64 )
			local textSizeW,textSizeH = surface.GetTextSize(panelContent)
			surface.DrawRect( boxPosX, boxPosY, textSizeW + 24, textSizeH + 10 )
			surface.SetTextPos( boxPosX + 12, boxPosY + 5 ) 
			surface.DrawText(panelContent)
		end

		if LocalPlayer():GetNWBool("ulx_muted", false) then 
			local panelContent = "You are muted and cannot use text chat"
			surface.SetDrawColor( 156, 0, 0, 32 )
			surface.SetFont( "Trebuchet24" )
			surface.SetTextColor( 255, 255, 255, 64 )
			local textSizeW,textSizeH = surface.GetTextSize(panelContent)
			local boxPosX, boxPosY = ScrW() - textSizeW - 39, 15
			surface.DrawRect( boxPosX, boxPosY, textSizeW + 24, textSizeH + 10 )
			surface.SetTextPos( boxPosX + 12, boxPosY + 5 ) 
			surface.DrawText(panelContent)
		end
	end )
end

-- Anti-spam stuff
if SERVER then
	local chattime_cvar = ulx.convar( "chattime", "1.5", "<time> - Players can only chat every x seconds (anti-spam). 0 to disable.", ULib.ACCESS_ADMIN )
	local function playerSay( ply )
		if not ply.lastChatTime then ply.lastChatTime = 0 end

		local chattime = chattime_cvar:GetFloat()
		if chattime <= 0 then return end

		if ply.lastChatTime + chattime > CurTime() then
			return ""
		else
			ply.lastChatTime = CurTime()
			return
		end
	end
	hook.Add( "PlayerSay", "ulxPlayerSay", playerSay, HOOK_LOW )

	local function meCheck( ply, strText, bTeam )
		local meChatEnabled = GetConVarNumber( "ulx_meChatEnabled" )

		if ply.gimp or meChatEnabled == 0 or (meChatEnabled ~= 2 and GAMEMODE.Name ~= "Sandbox") then return end -- Don't mess

		if strText:sub( 1, 4 ) == "/me " then
			strText = string.format( "*** %s %s", ply:Nick(), strText:sub( 5 ) )
			if not bTeam then
				ULib.tsay( _, strText )
			else
				strText = "(TEAM) " .. strText
				local teamid = ply:Team()
				local players = team.GetPlayers( teamid )
				for _, ply2 in ipairs( players ) do
					ULib.tsay( ply2, strText )
				end
			end

			if game.IsDedicated() then
				Msg( strText .. "\n" ) -- Log to console
			end
			if ULib.toBool( GetConVarNumber( "ulx_logChat" ) ) then
				ulx.logString( strText )
			end

			return ""
		end

	end
	hook.Add( "PlayerSay", "ULXMeCheck", meCheck, HOOK_LOW ) -- Extremely low priority
end

local function showWelcome( ply )
	local message = GetConVarString( "ulx_welcomemessage" )
	if not message or message == "" then return end

	message = string.gsub( message, "%%curmap%%", game.GetMap() )
	message = string.gsub( message, "%%host%%", GetConVarString( "hostname" ) )
	message = string.gsub( message, "%%ulx_version%%", ULib.pluginVersionStr( "ULX" ) )

	ply:ChatPrint( message ) -- We're not using tsay because ULib might not be loaded yet. (client side)
end
hook.Add( "PlayerInitialSpawn", "ULXWelcome", showWelcome )
if SERVER then
	ulx.convar( "meChatEnabled", "1", "Allow players to use '/me' in chat. 0 = Disabled, 1 = Sandbox only (Default), 2 = Enabled", ULib.ACCESS_ADMIN )
	ulx.convar( "welcomemessage", "", "<msg> - This is shown to players on join.", ULib.ACCESS_ADMIN )
end
