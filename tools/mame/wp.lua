-- MAME デバッガのウォッチポイント (-debug -debugger none と併用).
--   WPS="開始16進,長さ16進,条件|アクション;..."  (条件は MAME デバッガ式. 例: wpdata==606d)
--   SCRIPT 互換の入力: PRESS="フレーム ..."(スタート), HOLD="フレーム:ボタン ..."
--   ARM=ウォッチポイントを張るフレーム, STOP=終了フレーム, LOG=出力ファイル
local f=0
local pad=manager.machine.ioport.ports[":ctrl1:mdpad:PAD"]
local presses={} for x in string.gmatch(os.getenv("PRESS") or "", "%d+") do presses[tonumber(x)]=true end
local holds={} for fr,b in string.gmatch(os.getenv("HOLD") or "", "(%d+):([%w_]+)") do holds[tonumber(fr)]=b:gsub("_"," ") end
local arm=tonumber(os.getenv("ARM") or "1")
local stop=tonumber(os.getenv("STOP") or "1000")
local pr=0
emu.register_frame_done(function()
  f=f+1
  if f==1 then manager.machine.debugger:command("g") end
  if f==arm then
    local cpu=manager.machine.devices[":maincpu"]
    for spec in string.gmatch(os.getenv("WPS") or "", "[^;]+") do
      local a,l,cond,act=spec:match("^(%x+),(%x+),([^|]*)|(.*)$")
      cpu.debug:wpset(cpu.spaces["program"],"w",tonumber(a,16),tonumber(l,16),cond,act.."; g")
    end
    manager.machine.debugger:command("g")
  end
  if presses[f] then pad.fields["P1 Start"]:set_value(1) pr=f end
  if pr>0 and f==pr+5 then pad.fields["P1 Start"]:clear_value() pr=0 end
  if holds[f] then pad.fields[holds[f]]:set_value(1) end
  if f==stop then
    local o=io.open(os.getenv("LOG") or "wp.log","w")
    for _,l in ipairs(manager.machine.debugger.consolelog) do o:write(l.."\n") end
    o:close() manager.machine:exit()
  end
end)
