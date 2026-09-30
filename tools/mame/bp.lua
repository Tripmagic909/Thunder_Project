-- MAME デバッガのブレークポイントでログを取る (-debug -debugger none と併用).
--   BPS="アドレス16進=デバッガ命令;..."  例: BPS='230a4=printf "st=%X",w@ff0002'
--   PRESS="フレーム ..." でスタートを押す, STOP=終了フレーム, LOG=出力ファイル (consolelog)
local f=0
local st=manager.machine.ioport.ports[":ctrl1:mdpad:PAD"].fields["P1 Start"]
local presses={} for x in string.gmatch(os.getenv("PRESS") or "", "%d+") do presses[tonumber(x)]=true end
local stop=tonumber(os.getenv("STOP") or "1000")
local bps=os.getenv("BPS") or ""
local pr=0
emu.register_frame_done(function()
  f=f+1
  if f==1 then
    local dbg=manager.machine.devices[":maincpu"].debug
    for spec in string.gmatch(bps, "[^;]+") do
      local addr,act=spec:match("^(%x+)=(.*)$")
      dbg:bpset(tonumber(addr,16), "1", act.."; g")
    end
    manager.machine.debugger:command("g")
  end
  if presses[f] then st:set_value(1) pr=f end
  if pr>0 and f==pr+5 then st:clear_value() pr=0 end
  if f==stop then
    local o=io.open(os.getenv("LOG") or "bp.log","w")
    for _,l in ipairs(manager.machine.debugger.consolelog) do o:write(l.."\n") end
    o:close()
    manager.machine:exit()
  end
end)
