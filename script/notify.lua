local notify = {}

--你的wifi名称和密码
local wifiName = ""
local wifiPasswd = ""

--这里默认用的是LuatOS社区提供的推送服务，无使用限制
--官网：https://push.luatos.org/ 点击GitHub图标登陆即可
--支持邮件/企业微信/钉钉/飞书/电报/IOS Bark

--是否使用ntfy，false则使用LuatOS社区提供的推送服务
local useNtfy = true

--LuatOS社区提供的推送服务 https://push.luatos.org/
--这里填.send前的字符串就好了
--如：https://push.luatos.org/ABCDEF1234567890ABCD.send/{title}/{data} 填入 ABCDEF1234567890ABCD
local luatosPush = "ABCDEF1234567890ABCD"

--ntfy的配置
local ntfyUrl = "https://ntfy.sh/xxx" --xxx可以自定义
local ntfyKey = "" --自建服务访问是设置的


--缓存消息
local buff = {}

--来新消息了
function notify.add(phone,data)
    log.info("notify","got sms",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end


sys.taskInit(function()
    sys.wait(1000)
    wlan.init()--初始化wifi
    wlan.connect(wifiName, wifiPasswd)
    log.info("wlan", "wait for IP_READY")
    sys.waitUntil("IP_READY", 30000)
    print("qq",collectgarbage("count"))
    if wlan.ready() then
        log.info("wlan", "ready !!")
        while true do
            print("ww",collectgarbage("count"))
            while #buff > 0 do--把消息读完
                collectgarbage("collect")--防止内存不足
                local sms = table.remove(buff,1)
                local code,h, body
                if useNtfy then--server酱
                    local data = pdu.ucs2_utf8(sms[2])
                    log.info("notify","send to ntfy",data)
                    code, h, body = http2.request(
                            "POST",
                            ntfyUrl,
                            {
                                ["Content-Type"] = "text/plain",
                                ["Title"] = sms[1],
                                ["Authorization"] = "Basic "..ntfyKey
                            },
                            data
                        ).wait()
                    log.info("notify","pushed sms notify",code,h,body,sms[1])
                else--luatos推送服务
                    --如果太长则需要分割，乐鑫的sdk默认buffer很小
                    local maxLen = 40
                    local len = #sms[2]//2--长度不能超
                    local offset = 0
                    while len > 0 do
                        collectgarbage("collect")--防止内存不足
                        log.info("notify","len,offset",len,offset)
                        local data = pdu.ucs2_utf8(sms[2]:sub(offset*2+1,(offset+maxLen)*2))
                        log.info("notify","send to luatos push server",data)
                        --多试几次好了
                        for i=1,10 do
                            code, h, body = http2.request(
                                "GET",
                                "https://push.luatos.org/"..luatosPush..".send/sms"..sms[1].."/"..string.urlEncode(data)
                            ).wait()
                            log.info("notify","pushed sms notify",code,h,body,sms[1])
                            if code == 200 then
                                break
                            end
                            sys.wait(5000)
                        end
                        offset = offset + maxLen
                        len = len - maxLen
                        log.info("notify","len,offset2",len,offset)
                    end
                end
            end
            log.info("notify","wait for a new sms~")
            print("zzz",collectgarbage("count"))
            sys.waitUntil("SMS_ADD")
        end
    else
        print("wlan NOT ready!!!!")
        rtos.reboot()
    end
end)



return notify
