os.execute('color 0')

-- Libraries
require('addon')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8
local effil = require 'effil'
local sampev = require('samp.events')
local vector3d = require('libs.vector3d')
local requests = require('requests')
local json = require('dkjson')
local ffi = require('ffi')
local socket = require 'socket'
local inicfg = require('inicfg')
local cfg = inicfg.load(nil, 'E-Settings')

local configtg = {
    token = cfg.telegram.tokenbot,
    chat_id = cfg.telegram.chatid
}

math.randomseed(os.time() * os.clock() * math.random())
math.random(); math.random(); math.random()

local specialKey = nil
local SPECIAL_KEYS = {
    Y = 1,
    N = 2,
    H = 3
}

function pressSpecialKey(key)
    if not SPECIAL_KEYS[key] then return false end
    specialKey = SPECIAL_KEYS[key]
    updateSync()
end

function sampev.onSendPlayerSync(data)
	if rep then
		return false
	end
	if specialKey then
		data.specialKey = specialKey
		specialKey = nil
	end
end

-- Proxy
local proxys = {}
local my_proxy_ip

-- ������� ��� �������� ���������� ������������� ������ �� JSON
function loadProxyUsage()
    local file = io.open("scripts/proxy_usage.json", "r")
    if not file then
        return {}  -- ���� ���� �� ����������, ���������� ������ �������
    end
    local data = file:read("*all")
    file:close()
    
    local proxy_usage = json.decode(data)
    return proxy_usage or {}  -- ���������� ������ �������, ���� ������ ���������
end

-- ������� ��� ���������� ���������� ������������� ������ � JSON
function saveProxyUsage(proxy_usage)
    local file = io.open("scripts/proxy_usage.json", "w")
    if file then
        file:write(json.encode(proxy_usage, {indent = true}))
        file:close()
    else
        print("[������] �� ������� ��������� ���������� �� ������.")
    end
end

-- ������� ��� ���������� ���������� ������������� ������
function updateProxyUsage(proxy_ip)
    local proxy_usage = loadProxyUsage()
    
    -- ���� ������ ��� ���� � ����������
    if proxy_usage[proxy_ip] then
        proxy_usage[proxy_ip].count = proxy_usage[proxy_ip].count + 1
        proxy_usage[proxy_ip].last_used = os.time()  -- ��������� ����� ���������� �������������
    else
        -- ���� ������ ���, ��������� ��� � ����������
        proxy_usage[proxy_ip] = { count = 1, last_used = os.time() }
    end

    -- ��������� ���������� ����������
    saveProxyUsage(proxy_usage)
end

-- ������� ��� �������� ���������� � ����������� �� �����������
function checkProxyLimit(proxy_ip)
    local proxy_usage = loadProxyUsage()
    
    -- ���� ������ ���� � ����������, ��������� ���������� �����������
    if proxy_usage[proxy_ip] then
        if proxy_usage[proxy_ip].count >= 2 then
            print("[������] ��������� ������������ ���������� ����������� ��� IP: " .. proxy_ip)
            connect_random_proxy()  -- ����������� �� ����������� � ����� IP
        end
    end

    -- ���� ���������� ����������� �� ��������� 2, ��������� �����������
    return true
end

-- ������� ��� ����������� � ������
function connect_random_proxy()
    if isProxyConnected() then
        proxyDisconnect()
    end
    local new_proxy = proxys[math.random(1, #proxys)]
    my_proxy_ip = new_proxy.ip

    -- ��������� ����� �����������
    if checkProxyLimit(my_proxy_ip) then
        proxyConnect(new_proxy.ip, new_proxy.user, new_proxy.pass)
        updateProxyUsage(my_proxy_ip)  -- ��������� ���������� ������������� ������
    else
        print("[������] ����������� � ���� ������ ���������� ��-�� ����������� �� ���������� �����������.")
    end
end

-- ������� ��� ���������� ������ �� �����
function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- ������� ��� �������� ������ ������ �� �����
function load_proxys(filename)
    local file = io.open(filename, "r")
    if not file then
        sendTG("������ � ��������� ������")
        return
    end
    for line in file:lines() do
        local info = split(line, ":")
        proxys[#proxys + 1] = {ip = info[1]..":"..info[2], user = info[3], pass = info[4]}
    end
    file:close()
end

-- ��������� ������ � ������������, ���� proxy ��������
if cfg.main.proxy == 1 then
    load_proxys("config\\proxy.txt")
    connect_random_proxy()
end

----------------------------------------------------------------������----------------------------------------------------------------

-- ������� ��� ��������� ��������� ������ �������� ����� ��� Windows
local requests = require('requests')
local json = require('dkjson')

-- ������� ��� ��������� ��������� ������ ����������
local function getCpuSerial()
    local handle = io.popen("wmic csproduct get UUID")
    local result = handle:read("*a")
    handle:close()
    
    -- ��������� �������� ����� �� ���������� �������
    local serial = result:match("([%w%d]+)%s*$")
    return serial
end

-- ������� ��� �������� ����������� �������� ������� � GitHub
local function loadAllowedSerials()
    local url = "https://raw.githubusercontent.com/sakutov/Evolved/refs/heads/main/HWID.json"
    local response = requests.get(url)
    if response.status_code == 200 then
        local data = json.decode(response.text)
        if data and data.allowed_serials then
            return data.allowed_serials
        else
            print("[������] ������ ������ � GitHub �����������.")
            return nil
        end
    else
        print("[������] �� ������� ��������� ���� � ������������ ��������� ��������.")
        return nil
    end
end

-- ������� ��� ��������, �������� �� �������� �����
local function checkIfSerialAllowed(serial)
    local allowedSerials = loadAllowedSerials()
    if allowedSerials then
        for _, allowedSerial in ipairs(allowedSerials) do
            if allowedSerial == serial then
                return true
            end
        end
    end
    return false
end

-- ������� ��� �������� �������� ������� �� �����
local function loadSerialsFromFile()
    local file = io.open("scripts/HWID.json", "r")
    if not file then
        return {}  -- ���� ���� �� ����������, ���������� ������ �������
    end
    
    local data = file:read("*all")
    file:close()
    
    local serials = json.decode(data)
    return serials or {}  -- ���������� ������ �������, ���� ������ ���������
end

-- ������� ��� ���������� �������� ������� � ����
local function saveSerialsToFile(serials)
    local file = io.open("scripts/HWID.json", "w")
    if not file then
        print("[������] �� ������� ������� ���� ��� ������ �������� �������.")
        return
    end
    file:write(json.encode(serials, {indent = true}))
    file:close()
end

-- ������� ��� ���������� ��������� ������ � ����
local function addSerialToFile(serial)
    local serials = loadSerialsFromFile()
    
    -- ���������, ���� �� ��� ���� �������� ����� � �����
    for _, existingSerial in ipairs(serials) do
        if existingSerial == serial then
            print("�������� ����� ��� ��������.")
            return  -- ���� �������� ����� ��� ����, ������ �� ������
        end
    end
    
    -- ���� ���, ��������� ����� �������� �����
    table.insert(serials, serial)
    saveSerialsToFile(serials)
    print("�������� ����� �������� � ��������.")
end

-- �������� ������� �������� ����� ����������
local currentSerial = getCpuSerial()  -- �������� �������� �����

-- ��������� �������� ����� � ���� �� ��� ��������
addSerialToFile(currentSerial)

-- ���������, �������� �� �������� �����
if checkIfSerialAllowed(currentSerial) then
    print("�������� ����� ��������.")
else
    print("�������� ����� �� ��������, ���������� ������� ��������������.")
    return  -- ������ ���������� ���������� ������� ��� ���������� ���������
end

-- �������� �������
function onLoad()
    if cfg.main.finishLVL < 1 then
        cfg.main.finishLVL = 1
    end
    newTask(function()
        while true do
            wait(1)
            local lvl = getBotScore()
            local nick = getBotNick()
            local money = getBotMoney()
            setWindowTitle('[XYECOC] '..nick..' | Level: '..lvl..'')
        end
        local score = getBotScore()
        if score == cfg.main.finishLVL and napisal == true then
            sampstoreupload()
            napisal = false
        end
    end)
    if cfg.main.randomnick == 1 then
        generatenick()
    end
    print('\x1b[0;36m------------------------------------------------------------------------\x1b[37m')
    print('')
    print('			\x1b[0;33m        XYECOC\x1b[37m  - \x1b[0;32m�����������\x1b[37m           ')
    print('           \x1b[0;33m        Lile Scott & Hiko Warrior = ������                 \x1b[37m                                         ')
    print('')
    print('                           \x1b[37m   \x1b[0;32mfor help use !xyecoc ( ENGLISH ) | <3 \x1b[37m             ')
    print('\x1b[0;36m------------------------------------------------------------------------\x1b[37m')
end

-- ��� �����������
function onConnect()
	serverip = getServerAddress()
	if serverip == '185.169.134.67:7777' then
		servername = ('Evolve 01')
	end
    if serverip == '185.169.134.68:7777' then
        servername = ('Evolve 02')
    end
    if serverip == 's1.evolve-rp.net' then
        servername = ('Evolve 01')
    end
    if serverip == 's2.evolve-rp.net' then
        servername = ('Evolve 02')
    end
end

-- telegram

function char_to_hex(str)

  return ('%%%02X'):format(str:byte())

end



function url_encode(str)

  return str:gsub('([^%w])', char_to_hex)

end



function sendtg(text)

  local params = {

    chat_id = configtg.chat_id,

    text = url_encode(u8(text))

  }

  local url = ('https://api.telegram.org/bot%s/sendMessage'):format(configtg.token)

  local response = requests.get({url, params=params})

end

-----���� ������� + ��� ������
function random(min, max)
	math.randomseed(os.time()*os.clock())
	return math.random(min, max)
end

-----��������� ������ ����
function generatenick()
	local names_and_surnames = {}
	for line in io.lines(getPath('config\\randomnick.txt')) do
		names_and_surnames[#names_and_surnames + 1] = line
	end
	local name = names_and_surnames[random(1, 5162)]
    local surname = names_and_surnames[random(5163, 81533)]
    local nick = ('%s_%s'):format(name, surname)
    setBotNick(nick)
	print('[\x1b[0;33mXYECOC\x1b[37m] \x1b[0;36m�������� ��� ��: \x1b[0;32m'..getBotNick()..'\x1b[37m.')
	reconnect(1)
end

-- ������� ��� ������ � ����
local function writeToFile(fileName, text)
    local file = io.open(fileName, "a")  -- �������� ����� ��� ��������
    if file then
        file:write(text .. "\n")  -- ���������� ����� � ����� ������
        file:close()  -- ��������� ����
    else
        print("�� ������� ������� ���� ��� ������: " .. fileName)
    end
end

-- ������� ��� �������� ������ � ������
local function checkAndWriteLevel()
    while true do
        -- �������� ������� �������
        local score = getBotScore()
        -- �������, � ������� ����������
        local requiredLevel = tonumber(cfg.main.finishLVL)

        print("������� �������: " .. score)
        print("����������� �������: " .. requiredLevel)

        -- �������� ������
        if score >= requiredLevel then
            print("������� ����������, ��������� � ����...")  -- �������� ������ � ����
            writeToFile("config\\accounts.txt", ("%s | %s | %s | %s"):format(getBotNick(), tostring(cfg.main.password), score, servername))
            vkacheno()
            generatenick()
        else
            print("������� ������������ ��� ������.")
        end
        
        -- ����� �� 30 ������
        wait(30000)  -- 30000 ����������� = 30 ������
    end
end

-- ����� ������� ��� ������
newTask(checkAndWriteLevel)

-----�������
function sampev.onShowDialog(id, style, title, btn1, btn2, text)
    newTask(function()
        if title:find("{FFFFFF}����������� | {ae433d}�������� ������") then
            sendDialogResponse(id, 1, 0, tostring(cfg.main.password)) -- �������������� � ������
        end
        if title:find('������� �������') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('E-mail') then
            sendDialogResponse(id, 1, 0, 'nomail@mail.ru')
        end
        if title:find('�����������') then
            sendDialogResponse(id, 1, 0, '#warrior')
        end
        if title:find('���') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('���� ������') then
            sendDialogResponse(id, 1, 0, tostring(cfg.main.password))
        end
        if title:find('������� �������') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('�����������') then
			sendDialogResponse(id, 1, 0, '')
		end
        if title:find('����������') then
			sendDialogResponse(id, 1, 0, '')
		end
        if id == 4423 then 
            sendDialogResponse(4423, 1, 0, "")
            printm("��������� �� ������ ��������!")
            gruzchik()
            return false
        end
        if title:find('����������') then
			noipban()
        end
    end)
end

-----������� �� �����
function sampev.onServerMessage(color, text)
	if text:match('����� ���������� �� {ae433d}Evolve Role Play') then
	end
	if text:match('�� ����� �������� ������!') then
		generatenick()
	end
	if text:match('�����������') then
        pressSpecialKey('Y')
	end
	if text:match('�� ��������� ������������ ����� �����������') then
		connect_random_proxy()
	end
	if text:match('^�� ��������� ���������� �������%. �� ��������� �� �������$') then
		generatenick()
	end
end

-- RPC TEXT
function onprintLog(text)
	if text:match('^%[NET%] Bad nickname$') then
		generatenick()
	end
	if text:match('[NET] You are banned. Reconnecting') then
		count = count + 1
		if count == 20 then
			ipban()
        end
    end
    if text:match('[NET] Bad nickname') then
        generatenick()
    end
end

-----����������
function sampev.onShowTextDraw(id, data)
	if data.selectable and data.text == 'selecticon2' and data.position.x == 396.0 and data.position.y == 315.0 then --Dimiano - ������
        for i = 1, random(1, 10) do newTask(sendClickTextdraw, i * 500, id) end
    elseif data.selectable and data.text == 'selecticon3' and data.position.x == 233.0 and data.position.y == 337.0 then
        newTask(sendClickTextdraw, 6000, id)
    end
	if id == 462 then
        sendClickTextdraw(462)
    end
	if id == 2084 then
		sendClickTextdraw(2084) -- 2084 ������ �����, 2080 ����� �����
	end
	if id == 2164 then
		sendClickTextdraw(2164)
	end
	if id == 2174 then
		sendClickTextdraw(2174)
	end
end

-- ����������� � ��������
function sampev.onSetPlayerPos(position)
    local posx, posy, posz = getBotPosition()
    if position.x == posx and position.y == posy and position.z ~= posz then
        slapuved()
    end
end

function slapuved()
	if cfg.telegram.slapuved == 1 then
		msg = ([[
		[XYECOC]
				
		��������.					
		Nick: %s
        Server: %s
		User: %s
		]]):format(getBotNick(), servername, cfg.telegram.user)
		newTask(sendtg, false, msg)
	end
end

function vkacheno()
    if cfg.telegram and cfg.telegram.vkacheno == 1 then
        local msg = ([[  
        [XYECOC]  

        ������� ������. 
        Nick: %s
        LVL: %s
        Server: %s
        User: %s  
        ]]):format(getBotNick(), getBotScore(), servername, cfg.telegram.user)

        sendtg(msg)
    end
end

function noipban()
	if cfg.telegram.noipban == 1 then
		msg = ([[
		[FUCK U BITCHEZZ]
		
		������� �������������.	
		Nick: %s
        Server: %s
		User: %s
		]]):format(getBotNick(), servername, cfg.telegram.user)
		newTask(sendtg, false, msg)
	end
	generatenick()
end

function ipban()
	if cfg.telegram.ipbanuved == 1 then
		msg = ([[
		[FUCK U BITCHEZZ]
		
		������� ������������� �� IP.	
		Nick: %s
        IP: %s
        Server: %s
        User: %s
			
		������� ������: %s �. %s ���. %s �.
		]]):format(getBotNick(), my_proxy_ip, servername, cfg.telegram.user)
		newTask(sendtg, false, msg)
	end
    generatenick()
end

-- �������
function onRunCommand(cmd)
	if cmd:find'!test' then
		msg = ('[XYECOC]\n\n���� ����������� Telegram\nUser: '..cfg.telegram.user)
		msg = ([[
		[XYECOC]
		
		������������ ����������� Telegram.	
		User: %s
        Server: %s
		]]):format(cfg.telegram.user, servername)
		newTask(sendtg, false, msg)
	end
    if cmd:find'!quest' then
        nagruz()
    end
    if cmd:find'!fspawn' then
        fspawn()
    end
    if cmd:find'!xyecoc' then
        print('\x1b[0;36m==================== ��������������� ���������� ====================\x1b[37m')
        print('\x1b[0;32m����� ��� ��������� ������� �� ���� config/E-Settings.ini.\x1b[37m')
        print('\x1b[0;32m�������� ��� �������� ����������� � ��������� true or false: 1 - ��, 0 - ���.\x1b[37m')
        print('\x1b[0;32m!quest - ������� ��������� ������ ����� �� ��������� �����.\x1b[37m')
        print('\x1b[0;32m!fspawn - ������� ������������� ����� �� �������� ����.\x1b[37m')
        print('\x1b[0;32m���� ���� �����������, ������, ��������, ����� �� ������� ���� ��������� ������.\x1b[37m')
        print('\x1b[0;36m====================================================\x1b[37m')
    end
end

function fspawn()
    sendInput('/setspawn')
end

-- ���������� ������� 


-- �������� 
function printm(text)
	print("\x1b[0;36m[XYECOC]:\x1b[37m \x1b[0;32m"..text.."\x1b[37m")
end

function tp(toX, toY, toZ, noExitCar) 
	needX, needY, needZ = toX, toY, toZ
	coordStart(toX, toY, toZ, 30, 2, true)
	while isCoordActive() do
		wait(0)
	end
	if not noExitCar then
		setBotVehicle(0, 0)
		setBotVehicle(0, 0)
		setBotVehicle(0, 0)
		setPos(toX, toY, toZ)
	end
end

function setPos(toX, toY, toZ) 
	x, y, z = getBotPosition()
	if getDistanceBetweenCoords3d(x, y, z, toX, toY, toZ) < 15 then
		setBotPosition(toX, toY, toZ)
	end
end

function getDistanceBetweenCoords3d(x1, y1, z1, x2, y2, z2) 
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

function nagruz()
    newTask(function()
        tp(1158.7135009766, -1753.1791992188, 13.600618362427)
        updateSync()
        printm("�������������� �������� ���������.")
        tp(2137.8679199219, -2282.1091308594, 20.671875)
    end)
end

function gruzchik()
    -- 1 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 2 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 3 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 4 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 5 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 6 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 7 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 8 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 9 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 10 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 11 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 12 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    --13 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 14 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    -- 15 ����
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("���� ����� � ������. ��� 15 ������ ����� ��������� �� ��� ���� ���-�� �� �������.")
    wait(15000)
end

-- ����� �� ������
function pobeg()
    if cfg.main.runspawn == 1 then
        newTask(function()
            wait(44444)
            local x, y = getBotPosition()
            if x >= -1950 and x <= -1999 and y >= 170 and y <= 100 then -- San Fierro spawn
                print('[\x1b[0;33mEVOLVED\x1b[37m] \x1b[0;36m�� �� ���� ������.\x1b[0;37m')
                local put = random(1,15)
                runRoute('!play sf'..put)
            elseif x >= 1000 and x <= 1200 and y >= -1900 and y <= -1700 then  -- Los Santos spawn
                print('[\x1b[0;33mEVOLVED\x1b[37m] \x1b[0;36m�� �� ���� ������.\x1b[0;37m')
                local put = random(1,15)
                runRoute('!play ls'..put)
            else
                print('[\x1b[0;33mEVOLVED\x1b[37m] \x1b[0;36mC����� �� ���� ���������� �����.\x1b[0;37m')
            end
        end)
    end
end

local rep = false
local loop = false
local packet, veh = {}, {}
local counter = 0

local trailerId = 0

local bitstream = {
	onfoot = bitStream.new(),
	incar = bitStream.new(),
	aim = bitStream.new()
}

function sampev.onSendVehicleSync(data)
	if rep then return false end
end

function sampev.onSendPlayerSync(data)
	if rep then return false end
end

function sampev.onVehicleStreamIn(vehid, data)
	veh[vehid] = data.health
end


function check_update()
	if rep then
		local ok = fillBitStream(getBotVehicle() ~= 0 and 2 or 1) 
		if ok then
			if getBotVehicle() ~= 0 then bitstream.incar:sendPacket() else bitstream.onfoot:sendPacket() end
			setBotPosition(packet[counter].x, packet[counter].y, packet[counter].z)
			counter = counter + 1
			if counter%20 == 0 then
				local aok = fillBitStream(3)
				if aok then 
					bitstream.aim:sendPacket()
				else 
					err()
				end
			end
		else
			err()
		end
					
		bitstream.onfoot:reset()
		bitstream.incar:reset()
		bitstream.aim:reset()
					
		if counter == #packet then
			if not loop then
				rep = false
				setBotPosition(packet[counter].x, packet[counter].y, packet[counter].z)
				setBotQuaternion(packet[counter].qw, packet[counter].qx, packet[counter].qy, packet[counter].qz)
				print('������� ��������.')
				packet = {}
			end
			counter = 1
		end
	end
end

newTask(function()
	while true do
		check_update()
		wait(60)
	end
end)

local print = function(arg) return print('\x1b[0;33mEVOLVED\x1b[37m] '..arg) end

function err()
	rep = false
	packet = {}
	counter = 1
	print('������ ������ ��������.')
end


function fillBitStream(mode)
	if mode == 2 then
		local data = samp_create_sync_data("vehicle")
			data.vehicleId = getBotVehicle()
			data.leftRightKeys = packet[counter].lr
			data.upDownKeys = packet[counter].ud
			data.keysData = packet[counter].keys
			data.quaternion = {packet[counter].qw, packet[counter].qx, packet[counter].qy, packet[counter].qz}
			data.position = {packet[counter].x, packet[counter].y, packet[counter].z}
			data.moveSpeed = {packet[counter].sx, packet[counter].sy, packet[counter].sz}
			data.vehicleHealth = veh[getBotVehicle()]
			data.playerHealth = getBotHealth()
			data.armor = getBotArmor()
			data.currentWeapon = 0
			data.specialKey = 0
			data.siren = 0
			data.landingGearState = 0
			data.trailerId = trailerId
			data.bikeLean = packet[counter].lean
			data.send()
		local data = samp_create_sync_data("trailer")
		    data.position = {packet[counter].trx, packet[counter].try, packet[counter].trz}
		    data.moveSpeed = {packet[counter].trsx, packet[counter].trsy, packet[counter].trsz}
		    data.quaternion = {packet[counter].tqw, packet[counter].tqx, packet[counter].tqy, packet[counter].tqz}
			data.trailerId = trailerId
			data.direction = {packet[counter].tdx, packet[counter].tdy, packet[counter].tdz}
		    data.send()
	elseif mode == 1 then
		local data = samp_create_sync_data("player")
			data.leftRightKeys = packet[counter].lr
			data.upDownKeys = packet[counter].ud
			data.keysData = packet[counter].keys
			data.quaternion = {packet[counter].qw, packet[counter].qx, packet[counter].qy, packet[counter].qz}
			data.position = {packet[counter].x, packet[counter].y, packet[counter].z}
			data.moveSpeed = {packet[counter].sx, packet[counter].sy, packet[counter].sz}
			data.health = getBotHealth()
			data.armor = getBotArmor()
			data.specialAction = packet[counter].sa
			data.animationId = packet[counter].anim
			data.animationFlags = packet[counter].flags
			data.send()
	elseif mode == 3 then
		local data = samp_create_sync_data("aim")
			data.camMode = packet[counter].mode
			data.camFront = {packet[counter].cx, packet[counter].cy, packet[counter].cz}
			data.camPos = {packet[counter].px, packet[counter].py, packet[counter].pz}
			data.aimZ = packet[counter].az
			data.camExtZoom = packet[counter].zoom
			data.weaponState = packet[counter].wstate
			data.send()
	else return false end
	return true
end

function runRoute(act)
    if rep then
        print('[\x1b[0;33mEVOLVED\x1b[37m] \x1b[0;36m������� ��� �������, ��������� ��������� ��������.\x1b[0;37m')
        return
    end

    if act:find('!play .*') then
        packet = loadIni(getPath()..'routes\\'..act:match('!play (.*)')..'.rt')
        if packet then
            local time = #packet * 0.06 / 60
            local timesec = #packet * 0.06 - math.floor(time) * 60
            local timems = #packet * 60
            print('������� �������: "'..act:match('!play (.*)')..'". ������������ ��������: '..math.floor(time)..' ����� '..math.floor(timesec)..' ������. � ��: '..timems)
            counter = 1
            rep = true
            loop = false
        else
            print('����� ������ ���.')
        end
    elseif act:find('!loop') then
        if rep then loop = not loop; print(loop and '������������ �������� ��������.' or '������������ ����������.') else print('������� �� �������������.') end
    elseif act:find('!stop') then
        if counter > 1 then rep = not rep else print('������� �� �������������.') end
        if not rep then setBotQuaternion(packet[counter].qw, packet[counter].qx, packet[counter].qy, packet[counter].qz) end
        print(rep and '������� �����������.' or '����������� �� ������: '.. counter)
    end
end

function loadIni(fileName)
	local file = io.open(fileName, 'r')
	if file then
		local data = {}
		local number
		for line in file:lines() do
			local packetNumber = line:match('^%[([^%[%]]+)%]$') --��������� ����������� ������ ������
			if packetNumber then
				number = tonumber(packetNumber) and tonumber(packetNumber) or packetNumber
				data[number] = data[number] or {}
			end
			local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$') --��������� �������� � ������
			if param and value ~= nil then
				if tonumber(value) then
					value = tonumber(value)
				elseif value == 'true' then
					value = true
				elseif value == 'false' then
					value = false
				end
				if tonumber(param) then
					param = tonumber(param)
				end
				data[number][param] = value
			end
		end
		file:close()
		return data
	end
	return false
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    -- from SAMP.Lua
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
        trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData},
        unoccupied = {'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil},
        bullet = {'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil},
        spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil}
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    -- copy player's sync data to the allocated memory
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end
    -- function to send packet
    local func_send = function()
        local bs = bitStream.new()
        bs:writeInt8(sync_info[2])
        bs:writeBuffer(raw_data_ptr, ffi.sizeof(data))
        bs:sendPacketEx(sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        bs:reset()
    end
    -- metatable to access sync data and 'send' function
    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({send = func_send}, mt)
end
-- �������� ������������ ��� c�����, �� ��������� ����������

function sampev.onSendSpawn()
    newTask(function()
        wait(11111)
        if cfg.main.runspawn == 1 then
            pobeg()
        else
            printm("[INFO] ����� �� ������ ��������.")
        end
    end)
end

-- ����� � ������

-- hit fix
local e_set = {
	anim_fight = {
		{id = 1136, dmg = 1.3200000524521, offset = -0.11}, -- FIGHTA_1
		{id = 1137, dmg = 2.3100001811981, offset = -0.09}, -- FIGHTA_2
		{id = 1138, dmg = 3.960000038147, offset = -0.1}, 	-- FIGHTA_3
		{id = 1141, dmg = 1.3200000524521, offset = -0.11}, -- FIGHTA_M
		{id = 504, dmg = 1.9800000190735, offset = -0.07}, 	-- FIGHTKICK
		{id = 505, dmg = 5.2800002098083, offset = -0.05},	-- FIGHTKICK_B
		{id = 472, dmg = 2.6400001049042, offset = -0.03}, 	-- FIGHTB_1
		{id = 473, dmg = 1.6500000953674, offset = -0.07}, 	-- FIGHTB_2
		{id = 474, dmg = 4.289999961853, offset = -0.15}, 	-- FIGHTB_3
		{id = 478, dmg = 1.3200000524521, offset = -0.11}, 	-- FIGHTB_M
		{id = 482, dmg = 1.3200000524521, offset = -0.02}, 	-- FIGHTC_1
		{id = 483, dmg = 2.3100001811981, offset = -0.09}, 	-- FIGHTC_2
		{id = 484, dmg = 3.960000038147, offset = -0.18},	-- FIGHTC_3
	},
	min_dist = 1.4,
	fov = 40.0,
	iters = 8,
	waiting = 48,
	copy_player_z = true
}

local e_temp = {
	s_task = nil,
	speed = {x = 0.0, y = 0.0, z = 0.0},
	send_speed = false,
	last_anim = 1189,
	kill_kd = os.time()
}

function sampev.onPlayerSync(playerId, data)
	local pedX, pedY, pedZ = getBotPosition()
	if getDistanceBeetweenTwoPoints3D(pedX, pedY, pedZ, data.position.x, data.position.y, data.position.z) < e_set.min_dist and not GetTaskStatus(e_temp.s_task) and e_temp.last_anim == 1189 and e_temp.kill_kd < os.time() then
		for k, v in ipairs(e_set.anim_fight) do
			if v.id == data.animationId then
				local p_angle = (math.deg(math.atan2(-data.quaternion[4], data.quaternion[1])) * 2.0) % 360.0
				local b_angle = math.ceil(getBotRotation())
				local c_angle = b_angle < 180.0 and b_angle + 180.0 or b_angle > 180.0 and b_angle - 180.0 or (p_angle < 180.0 and 0.0 or 360.0)
				local now_calc = c_angle - p_angle
				if (now_calc >= 0 and now_calc <= e_set.fov) or (now_calc < 0 and now_calc >= -e_set.fov) then
					if getBotHealth() - v.dmg > 0 then
						--print(string.format("in my fov. detected %f | player angle %f", now_calc, p_angle))
						setBotHealth(getBotHealth() - v.dmg)
						sendTakeDamage(playerId, v.dmg, 0, 3)
						e_temp.s_task = newTask(function()
							local start_speed = math.abs(v.offset)
							local step_speed = start_speed / e_set.iters
							for i = 1, e_set.iters do
								start_speed = start_speed - step_speed
								local cbX, cbY, cbZ = getBotPosition()
								cbZ = e_set.copy_player_z and data.position.z or cbZ
								local sbX, sbY = cbX + (v.offset * math.sin(math.rad(-b_angle))), cbY + (v.offset * math.cos(math.rad(-b_angle)))
								e_temp.speed.x, e_temp.speed.y, e_temp.speed.z = getVelocity(cbX, cbY, cbZ, sbX, sbY, cbZ, i == e_set.iters and 0.0 or start_speed)
								e_temp.send_speed = true
								updateSync()
								setBotPosition(sbX, sbY, cbZ)
								wait(e_set.waiting)
							end
						end)
					else
						e_temp.kill_kd = os.time() + 3
						runCommand('!kill')
					end
				end
				break
			end
		end
	end
end

function sampev.onSendPlayerSync(data)
	e_temp.last_anim = data.animationId
	if e_temp.send_speed then
		data.moveSpeed.x = e_temp.speed.x
		data.moveSpeed.y = e_temp.speed.y
		data.moveSpeed.z = e_temp.speed.z
		e_temp.send_speed = false
	end
end

function sendTakeDamage(playerId, damage, weapon, bodypart)
	local bs = bitStream.new()
	bs:writeBool(true)
	bs:writeUInt16(playerId)
	bs:writeFloat(damage)
	bs:writeUInt32(weapon)
	bs:writeUInt32(bodypart)
	bs:sendRPC(115)
end

function getDistanceBeetweenTwoPoints3D(x, y, z, x1, y1, z1)
	return math.sqrt(math.pow(x1 - x, 2.0) + math.pow(y1 - y, 2.0) + math.pow(z1 - z, 2.0))
end

function getVelocity(x, y, z, x1, y1, z1, speed)
    local x2, y2, z2 = x1 - x, y1 - y, z1 - z
    local dist = getDistanceBeetweenTwoPoints3D(x, y, z, x1, y1, z1)
    return x2 / dist * speed, y2 / dist * speed, z2 / dist * speed
end

function GetTaskStatus(task)
    return task ~= nil and task:isAlive() or false
end

-- camera fix
function sampev.onInterpolateCamera(set_pos, from_pos, dest_pos, time, mode)
    -- Check if the position is to be set for the bot
    if set_pos then
        -- Logging the fixed camera position change
        print(string.format("Fixed position for interpolate camera. From: (%.2f, %.2f, %.2f) to (%.2f, %.2f, %.2f)", 
            from_pos.x, from_pos.y, from_pos.z, dest_pos.x, dest_pos.y, dest_pos.z))

        -- Ensure the bot's position is set correctly
        -- Here, you can apply additional checks or adjustments if needed.
        setBotPosition(dest_pos.x, dest_pos.y, dest_pos.z)
    end
end