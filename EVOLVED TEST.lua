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

-- Функция для загрузки статистики использования прокси из JSON
function loadProxyUsage()
    local file = io.open("scripts/proxy_usage.json", "r")
    if not file then
        return {}  -- Если файл не существует, возвращаем пустую таблицу
    end
    local data = file:read("*all")
    file:close()
    
    local proxy_usage = json.decode(data)
    return proxy_usage or {}  -- Возвращаем пустую таблицу, если данные невалидны
end

-- Функция для сохранения статистики использования прокси в JSON
function saveProxyUsage(proxy_usage)
    local file = io.open("scripts/proxy_usage.json", "w")
    if file then
        file:write(json.encode(proxy_usage, {indent = true}))
        file:close()
    else
        print("[Ошибка] Не удалось сохранить статистику по прокси.")
    end
end

-- Функция для обновления статистики использования прокси
function updateProxyUsage(proxy_ip)
    local proxy_usage = loadProxyUsage()
    
    -- Если прокси уже есть в статистике
    if proxy_usage[proxy_ip] then
        proxy_usage[proxy_ip].count = proxy_usage[proxy_ip].count + 1
        proxy_usage[proxy_ip].last_used = os.time()  -- Обновляем время последнего использования
    else
        -- Если прокси нет, добавляем его в статистику
        proxy_usage[proxy_ip] = { count = 1, last_used = os.time() }
    end

    -- Сохраняем обновлённую статистику
    saveProxyUsage(proxy_usage)
end

-- Функция для проверки статистики и ограничения на подключение
function checkProxyLimit(proxy_ip)
    local proxy_usage = loadProxyUsage()
    
    -- Если прокси есть в статистике, проверяем количество подключений
    if proxy_usage[proxy_ip] then
        if proxy_usage[proxy_ip].count >= 2 then
            print("[Ошибка] Превышено максимальное количество подключений для IP: " .. proxy_ip)
            connect_random_proxy()  -- Ограничение на подключение с этого IP
        end
    end

    -- Если количество подключений не превышает 2, разрешаем подключение
    return true
end

-- Функция для подключения с прокси
function connect_random_proxy()
    if isProxyConnected() then
        proxyDisconnect()
    end
    local new_proxy = proxys[math.random(1, #proxys)]
    my_proxy_ip = new_proxy.ip

    -- Проверяем лимит подключений
    if checkProxyLimit(my_proxy_ip) then
        proxyConnect(new_proxy.ip, new_proxy.user, new_proxy.pass)
        updateProxyUsage(my_proxy_ip)  -- Обновляем статистику использования прокси
    else
        print("[Ошибка] Подключение с этим прокси невозможно из-за ограничения на количество подключений.")
    end
end

-- Функция для разделения строки на части
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

-- Функция для загрузки списка прокси из файла
function load_proxys(filename)
    local file = io.open(filename, "r")
    if not file then
        sendTG("Ошибка с загрузкой прокси")
        return
    end
    for line in file:lines() do
        local info = split(line, ":")
        proxys[#proxys + 1] = {ip = info[1]..":"..info[2], user = info[3], pass = info[4]}
    end
    file:close()
end

-- Загружаем прокси и подключаемся, если proxy включено
if cfg.main.proxy == 1 then
    load_proxys("config\\proxy.txt")
    connect_random_proxy()
end

----------------------------------------------------------------ЗАЩИТА----------------------------------------------------------------

-- Функция для получения серийного номера жесткого диска для Windows
local requests = require('requests')
local json = require('dkjson')

-- Функция для получения серийного номера процессора
local function getCpuSerial()
    local handle = io.popen("wmic csproduct get UUID")
    local result = handle:read("*a")
    handle:close()
    
    -- Извлекаем серийный номер из результата команды
    local serial = result:match("([%w%d]+)%s*$")
    return serial
end

-- Функция для загрузки разрешенных серийных номеров с GitHub
local function loadAllowedSerials()
    local url = "https://raw.githubusercontent.com/sakutov/Evolved/refs/heads/main/HWID.json"
    local response = requests.get(url)
    if response.status_code == 200 then
        local data = json.decode(response.text)
        if data and data.allowed_serials then
            return data.allowed_serials
        else
            print("[Ошибка] Формат данных с GitHub некорректен.")
            return nil
        end
    else
        print("[Ошибка] Не удалось загрузить файл с разрешенными серийными номерами.")
        return nil
    end
end

-- Функция для проверки, разрешен ли серийный номер
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

-- Функция для загрузки серийных номеров из файла
local function loadSerialsFromFile()
    local file = io.open("scripts/HWID.json", "r")
    if not file then
        return {}  -- Если файл не существует, возвращаем пустую таблицу
    end
    
    local data = file:read("*all")
    file:close()
    
    local serials = json.decode(data)
    return serials or {}  -- Возвращаем пустую таблицу, если данные невалидны
end

-- Функция для сохранения серийных номеров в файл
local function saveSerialsToFile(serials)
    local file = io.open("scripts/HWID.json", "w")
    if not file then
        print("[Ошибка] Не удалось открыть файл для записи серийных номеров.")
        return
    end
    file:write(json.encode(serials, {indent = true}))
    file:close()
end

-- Функция для добавления серийного номера в файл
local function addSerialToFile(serial)
    local serials = loadSerialsFromFile()
    
    -- Проверяем, есть ли уже этот серийный номер в файле
    for _, existingSerial in ipairs(serials) do
        if existingSerial == serial then
            print("Серийный номер уже сохранен.")
            return  -- Если серийный номер уже есть, ничего не делаем
        end
    end
    
    -- Если нет, добавляем новый серийный номер
    table.insert(serials, serial)
    saveSerialsToFile(serials)
    print("Серийный номер добавлен и сохранен.")
end

-- Получаем текущий серийный номер процессора
local currentSerial = getCpuSerial()  -- Получаем серийный номер

-- Добавляем серийный номер в файл до его проверки
addSerialToFile(currentSerial)

-- Проверяем, разрешен ли серийный номер
if checkIfSerialAllowed(currentSerial) then
    print("Серийный номер разрешен.")
else
    print("Серийный номер не разрешен, выполнение скрипта приостановлено.")
    return  -- Просто прекращаем выполнение скрипта без завершения программы
end

-- Загрузка скрипта
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
    print('			\x1b[0;33m        XYECOC\x1b[37m  - \x1b[0;32mАКТИВИРОВАН\x1b[37m           ')
    print('           \x1b[0;33m        Lile Scott & Hiko Warrior = пидоры                 \x1b[37m                                         ')
    print('')
    print('                           \x1b[37m   \x1b[0;32mfor help use !xyecoc ( ENGLISH ) | <3 \x1b[37m             ')
    print('\x1b[0;36m------------------------------------------------------------------------\x1b[37m')
end

-- при подключении
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

-----Ключ рандома + сам рандом
function random(min, max)
	math.randomseed(os.time()*os.clock())
	return math.random(min, max)
end

-----Генерация рандом ника
function generatenick()
	local names_and_surnames = {}
	for line in io.lines(getPath('config\\randomnick.txt')) do
		names_and_surnames[#names_and_surnames + 1] = line
	end
	local name = names_and_surnames[random(1, 5162)]
    local surname = names_and_surnames[random(5163, 81533)]
    local nick = ('%s_%s'):format(name, surname)
    setBotNick(nick)
	print('[\x1b[0;33mXYECOC\x1b[37m] \x1b[0;36mИзменили ник на: \x1b[0;32m'..getBotNick()..'\x1b[37m.')
	reconnect(1)
end

-- Функция для записи в файл
local function writeToFile(fileName, text)
    local file = io.open(fileName, "a")  -- открытие файла для дозаписи
    if file then
        file:write(text .. "\n")  -- записываем текст с новой строки
        file:close()  -- закрываем файл
    else
        print("Не удалось открыть файл для записи: " .. fileName)
    end
end

-- Функция для проверки уровня и записи
local function checkAndWriteLevel()
    while true do
        -- Получаем текущий уровень
        local score = getBotScore()
        -- Уровень, с которым сравниваем
        local requiredLevel = tonumber(cfg.main.finishLVL)

        print("Текущий уровень: " .. score)
        print("Необходимый уровень: " .. requiredLevel)

        -- Проверка уровня
        if score >= requiredLevel then
            print("Уровень достаточен, записываю в файл...")  -- Логируем запись в файл
            writeToFile("config\\accounts.txt", ("%s | %s | %s | %s"):format(getBotNick(), tostring(cfg.main.password), score, servername))
            vkacheno()
            generatenick()
        else
            print("Уровень недостаточен для записи.")
        end
        
        -- Пауза на 30 секунд
        wait(30000)  -- 30000 миллисекунд = 30 секунд
    end
end

-- Вызов функции при старте
newTask(checkAndWriteLevel)

-----Диалоги
function sampev.onShowDialog(id, style, title, btn1, btn2, text)
    newTask(function()
        if title:find("{FFFFFF}Регистрация | {ae433d}Создание пароля") then
            sendDialogResponse(id, 1, 0, tostring(cfg.main.password)) -- Преобразование в строку
        end
        if title:find('Правила сервера') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('E-mail') then
            sendDialogResponse(id, 1, 0, 'nomail@mail.ru')
        end
        if title:find('Приглашение') then
            sendDialogResponse(id, 1, 0, '#warrior')
        end
        if title:find('Пол') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('Ввод пароля') then
            sendDialogResponse(id, 1, 0, tostring(cfg.main.password))
        end
        if title:find('Игровой лаунчер') then
            sendDialogResponse(id, 1, 0, '')
        end
        if title:find('Предложение') then
			sendDialogResponse(id, 1, 0, '')
		end
        if title:find('Увольнение') then
			sendDialogResponse(id, 1, 0, '')
		end
        if id == 4423 then 
            sendDialogResponse(4423, 1, 0, "")
            printm("Устроился на работу грузчика!")
            gruzchik()
            return false
        end
        if title:find('Блокировка') then
			noipban()
        end
    end)
end

-----Собития на текст
function sampev.onServerMessage(color, text)
	if text:match('Добро пожаловать на {ae433d}Evolve Role Play') then
	end
	if text:match('Вы ввели неверный пароль!') then
		generatenick()
	end
	if text:match('Используйте') then
        pressSpecialKey('Y')
	end
	if text:match('Вы превысили максимальное число подключений') then
		connect_random_proxy()
	end
	if text:match('^Вы исчерпали количество попыток%. Вы отключены от сервера$') then
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

-----Текстдравы
function sampev.onShowTextDraw(id, data)
	if data.selectable and data.text == 'selecticon2' and data.position.x == 396.0 and data.position.y == 315.0 then --Dimiano - пасиба
        for i = 1, random(1, 10) do newTask(sendClickTextdraw, i * 500, id) end
    elseif data.selectable and data.text == 'selecticon3' and data.position.x == 233.0 and data.position.y == 337.0 then
        newTask(sendClickTextdraw, 6000, id)
    end
	if id == 462 then
        sendClickTextdraw(462)
    end
	if id == 2084 then
		sendClickTextdraw(2084) -- 2084 дефолт спавн, 2080 спавн семьи
	end
	if id == 2164 then
		sendClickTextdraw(2164)
	end
	if id == 2174 then
		sendClickTextdraw(2174)
	end
end

-- Уведомления в телеграм
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
				
		слапнули.					
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

        Аккаунт вкачен. 
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
		
		Аккаунт заблокировали.	
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
		
		Аккаунт заблокировали по IP.	
		Nick: %s
        IP: %s
        Server: %s
        User: %s
			
		Аккаунт прожил: %s ч. %s мин. %s с.
		]]):format(getBotNick(), my_proxy_ip, servername, cfg.telegram.user)
		newTask(sendtg, false, msg)
	end
    generatenick()
end

-- Команды
function onRunCommand(cmd)
	if cmd:find'!test' then
		msg = ('[XYECOC]\n\nТест уведомлений Telegram\nUser: '..cfg.telegram.user)
		msg = ([[
		[XYECOC]
		
		Тестирование уведомлений Telegram.	
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
        print('\x1b[0;36m==================== Вспомогательная Информация ====================\x1b[37m')
        print('\x1b[0;32mПочти все настройки находят по пути config/E-Settings.ini.\x1b[37m')
        print('\x1b[0;32mОбьясняю как работают уведомления и некоторые true or false: 1 - Да, 0 - Нет.\x1b[37m')
        print('\x1b[0;32m!quest - Команда выполняет первый квест из квестовой линии.\x1b[37m')
        print('\x1b[0;32m!fspawn - Команда устанавливает спавн на семейный штаб.\x1b[37m')
        print('\x1b[0;32mЕсли есть предложения, пишите, реализую, время от времени буду обновлять скрипт.\x1b[37m')
        print('\x1b[0;36m====================================================\x1b[37m')
    end
end

function fspawn()
    sendInput('/setspawn')
end

-- Выполнение квестов 


-- грузщики 
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
        printm("Телепортируюсь работать грузчиком.")
        tp(2137.8679199219, -2282.1091308594, 20.671875)
    end)
end

function gruzchik()
    -- 1 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 2 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 3 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 4 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 5 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 6 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 7 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 8 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 9 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 10 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 11 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 12 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    --13 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 14 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    -- 15 круг
    tp(2225.4377441406, -2276.4077148438, 14.764669418335)
    wait(3333)
    tp(2187.3654785156, -2303.673828125, 13.546875)
    printm("Взял мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    tp(2163.060546875, -2238.1853027344, 13.287099838257)
    wait(3333)
    tp(2167.7253417969, -2262.1433105469, 13.30480670929)
    printm("Отнёс мешок с зерном. Жду 15 секунд перед следующим тп для того что-бы не кикнуло.")
    wait(15000)
    teleportToRandomLocation()
end

-- побег со спавна
math.randomseed(os.time()) -- Инициализация генератора случайных чисел

local teleportActive = false -- Флаг активности телепортации

local function readCoordsFromFile(filePath)
    local coords = {}
    local file = io.open(filePath, "r")

    if not file then
        print("[Ошибка] Не удалось открыть файл: " .. filePath)
        return coords
    end

    for line in file:lines() do
        local x, y, z = line:match("([%-?%d%.]+),%s*([%-?%d%.]+),%s*([%-?%d%.]+)")
        if x and y and z then
            table.insert(coords, {tonumber(x), tonumber(y), tonumber(z)})
        end
    end

    file:close()
    return coords
end

local function getRandomCoord(coords)
    if #coords == 0 then
        print("[Ошибка] Список координат пуст.")
        return nil
    end

    local index = math.random(1, #coords)
    return coords[index]
end

local function teleportToRandomLocation()
    if teleportActive then
        print("[Ошибка] Телепортация уже выполняется, невозможно запустить новую.")
        return
    end

    teleportActive = true -- Устанавливаем флаг

    newTask(function() -- Создаём корутину для телепортации
        local coordsFile = "config/coords.txt"
        local coords = readCoordsFromFile(coordsFile)
        local randomCoord = getRandomCoord(coords)

        if randomCoord then
            local x, y, z = randomCoord[1], randomCoord[2], randomCoord[3]
            print(string.format("[INFO] Телепортируемся в: tp(%.13f, %.13f, %.13f)", x, y, z))

            -- Вызов функции tp(x, y, z)
            tp(x, y, z)
        else
            print("[Ошибка] Координаты не найдены, телепортация невозможна.")
        end

        teleportActive = false -- Сбрасываем флаг после завершения телепортации
    end)
end

-- Вызываем телепортацию при cпавне, но проверяем активность

function sampev.onSendSpawn()
    newTask(function()
        wait(959362)
        if cfg.main.runspawn == 1 then
            teleportToRandomLocation()
        else
            printm("[INFO] Побег со спавна отключен.")
        end
    end)
end

-- ФИКСЫ И ПРОЧЕЕ

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