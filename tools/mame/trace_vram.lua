-- VDP への書き込みを (フレーム, PC, コード) ごとにアドレス範囲で集計し, DMA も記録する.
-- 環境変数: PRESS="フレーム ..." (スタート押下), STOP=終了フレーム, LOG=出力ファイル
local f=0
local cpu=manager.machine.devices[":maincpu"]
local prog=cpu.spaces["program"]
local log=io.open(os.getenv("LOG") or "vt.log","w")
local st=manager.machine.ioport.ports[":ctrl1:mdpad:PAD"].fields["P1 Start"]
local presses={} for x in string.gmatch(os.getenv("PRESS") or "", "%d+") do presses[tonumber(x)]=true end
local stop=tonumber(os.getenv("STOP") or "1000")
local addr,code,inc,pend=0,0,2,nil
local reg={} for i=0,31 do reg[i]=0 end
local agg={}
local function note(kind,a)
  local k=string.format("%d %s %02x",f,kind,code)
  local e=agg[k] if not e then e={a,a,0} agg[k]=e end
  if a<e[1] then e[1]=a end if a>e[2] then e[2]=a end e[3]=e[3]+1
end
local tap=prog:install_write_tap(0xC00000,0xC00007,"vdp",function(off,data,mask)
  local pc=cpu.state["CURPC"].value
  local words={}
  if mask==0xffffffff then words={data>>16, data&0xffff} else words={data&0xffff} end
  for _,w in ipairs(words) do
    if off>=0xC00004 then
      if pend then
        addr=((pend&0x3fff)|((w&3)<<14)); code=((pend>>14)&3)|((w>>2)&0x3c); pend=nil
        if (code&0x20)~=0 and (reg[1]&0x10)~=0 then
          local len=(reg[19]|(reg[20]<<8)); if len==0 then len=0x10000 end
          local mode=reg[23]>>6
          local src=((reg[21]|(reg[22]<<8)|((reg[23]&0x7f)<<16))<<1)
          if mode<2 then
            local k=string.format("%d DMA pc=%06x code=%02x",f,pc,code)
            log:write(string.format("%s dst=%04x len=%x src=%06x\n",k,addr,len*2,src))
          else
            log:write(string.format("%d DMAFILL/COPY pc=%06x code=%02x dst=%04x len=%x mode=%d\n",f,pc,code,addr,len,mode))
          end
        end
      elseif (w&0xc000)==0x8000 then
        reg[(w>>8)&0x1f]=w&0xff
        if ((w>>8)&0x1f)==15 then inc=w&0xff end
      else pend=w end
    else
      note(string.format("pc=%06x",pc),addr)
      addr=(addr+inc)&0xffff
    end
  end
  return data
end)
local pr=0
emu.register_frame_done(function()
  f=f+1
  tap:reinstall()
  if presses[f] then st:set_value(1) pr=f end
  if pr>0 and f==pr+5 then st:clear_value() pr=0 end
  if f==stop then
    local ks={} for k,_ in pairs(agg) do ks[#ks+1]=k end
    table.sort(ks,function(a,b) return tonumber(a:match("^%d+"))<tonumber(b:match("^%d+")) end)
    for _,k in ipairs(ks) do local e=agg[k] log:write(string.format("%s %04x-%04x n=%d\n",k,e[1],e[2],e[3])) end
    log:close() manager.machine:exit()
  end
end)
