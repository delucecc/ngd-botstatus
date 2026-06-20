local INGEST_URL = GetConvar('ngd_botstatus_url', 'https://nemesisbot.dev/api/game/ingest')
local TOKEN      = GetConvar('ngd_botstatus_token', '')
local INTERVAL   = 45000

local function pushStatus()
    local payload = json.encode({
        players     = #GetPlayers(),
        max_players = GetConvarInt('sv_maxClients', 48),
        hostname    = GetConvar('sv_hostname', 'FXServer'),
        gametype    = GetConvar('gametype', ''),
        mapname     = GetConvar('mapname', ''),
        uptime      = math.floor(GetGameTimer() / 1000),
        connect     = GetConvar('ngd_botstatus_connect', ''),
    })
    PerformHttpRequest(INGEST_URL, function(status, body)
        if status ~= 200 and status ~= 204 then
            print('push failed: HTTP ' .. tostring(status) .. ' ' .. tostring(body))
        end
    end, 'POST', payload, {
        ['Content-Type']  = 'application/json',
        ['Authorization'] = 'Bearer ' .. TOKEN,
    })
end

CreateThread(function()
    if TOKEN == '' then
        print('ERROR: ngd_botstatus_token is not set. Copy it from your NemesisBot dashboard (Game Servers) into server.cfg.')
        return
    end
    print('reporting every 45s -> ' .. INGEST_URL)
    while true do
        pushStatus()
        Wait(INTERVAL)
    end
end)

local WL_ENABLED = GetConvarInt('ngd_botstatus_whitelist', 0) == 1
local WL_URL     = GetConvar('ngd_botstatus_wl_url',       'https://nemesisbot.dev/api/game/whitelist')
local CHECK_URL  = GetConvar('ngd_botstatus_wl_check_url', 'https://nemesisbot.dev/api/game/whitelist/check')

local WL   = {}
local ETAG = nil

local function deny(deferrals, entry)
    local msg = entry.title .. '\n\n' .. entry.text
    local discord = Config.Discord
    if discord and discord.url and discord.url ~= '' then
        msg = msg .. '\n\nJoin us: ' .. discord.url
    end
    deferrals.done(msg)
end

local function refreshWhitelist()
    local headers = { ['Authorization'] = 'Bearer ' .. TOKEN }
    if ETAG then headers['If-None-Match'] = ETAG end
    PerformHttpRequest(WL_URL, function(status, body, rh)
        if status == 304 then return end
        if status ~= 200 or not body then
            print('whitelist refresh failed: HTTP ' .. tostring(status))
            return
        end
        local ok, data = pcall(json.decode, body)
        if not ok or type(data) ~= 'table' then
            print('whitelist refresh: bad JSON response; keeping cache')
            return
        end
        local set = {}
        for _, id in ipairs(data.discord_ids or {}) do set[tostring(id)] = true end
        WL = set
        if type(rh) == 'table' then
            for k, v in pairs(rh) do
                if tostring(k):lower() == 'etag' then ETAG = v; break end
            end
        end
        print('whitelist refreshed: ' .. #(data.discord_ids or {}) .. ' entries')
    end, 'GET', '', headers)
end

local function discordIdOf(src)
    for _, ident in ipairs(GetPlayerIdentifiers(src)) do
        local d = ident:match('^discord:(%d+)$')
        if d then return d end
    end
    return nil
end

if WL_ENABLED then
    CreateThread(function()
        if TOKEN == '' then
            print('whitelist enabled but token not set — skipping whitelist thread.')
            return
        end
        print('whitelist enforcement enabled, pulling from ' .. WL_URL)
        while true do
            refreshWhitelist()
            Wait(30000)
        end
    end)

    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        local src = source
        deferrals.defer()
        Wait(0)
        local settled = false
        local function settle(fn)
            if settled then return end
            settled = true
            fn()
        end

        local ok = pcall(function()
            deferrals.update(Config.CheckingStatus)
            Wait(0)
            local did = discordIdOf(src)
            if not did then
                settle(function() deny(deferrals, Config.Cards.NoDiscord) end)
                return
            end
            if WL[did] then
                settle(function() deferrals.done() end)
                return
            end
            PerformHttpRequest(
                CHECK_URL .. '?discord_id=' .. did,
                function(status, body)
                    local allowed = false
                    if status == 200 and body then
                        local ok2, res = pcall(json.decode, body)
                        if ok2 and type(res) == 'table' then
                            allowed = res.allowed == true
                        end
                    end
                    settle(function()
                        if allowed then
                            deferrals.done()
                        else
                            deny(deferrals, Config.Cards.NotWhitelisted)
                        end
                    end)
                end,
                'GET', '', { ['Authorization'] = 'Bearer ' .. TOKEN }
            )
            SetTimeout(5000, function()
                settle(function() deny(deferrals, Config.Cards.Unavailable) end)
            end)
        end)
        if not ok then
            print('whitelist: unexpected error in playerConnecting; failing open')
            settle(function() deferrals.done() end)
        end
    end)
end
