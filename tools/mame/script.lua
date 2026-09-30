-- MAME 検証用スクリプト (-autoboot_script).
-- 環境変数 SCRIPT に "フレーム:命令[,引数..]" を ';' 区切りで並べる.
--   press:<ボタン>   5 フレーム押して離す (ボタン名は "P1 Start" など, '_' は空白に置換)
--   hold:<ボタン> / release:<ボタン>
--   poke:<アドレス16進>=<値16進>   RAM に 16bit 書き込み
--   shot             スクリーンショット (-snapshot_directory へ)
--   dump:<名前>      VRAM/CRAM/VSRAM/REGS/RAM を <名前>.* に保存
--   exit             終了
local f = 0
local cpu = manager.machine.devices[":maincpu"]
local prog = cpu.spaces["program"]
local vdp = manager.machine.devices[":gen_vdp"]
local pad = manager.machine.ioport.ports[":ctrl1:mdpad:PAD"]
local ev = {}
for item in string.gmatch(os.getenv("SCRIPT") or "", "[^;]+") do
  local fr, cmd = item:match("^%s*(%d+):(.+)$")
  fr = tonumber(fr)
  ev[fr] = ev[fr] or {}
  table.insert(ev[fr], cmd)
end
local releases = {}
local function field(name) return pad.fields[name:gsub("_", " ")] end
local function dumpitem(name, fn)
  local it = emu.item(vdp.items["0/" .. name]); local o = io.open(fn, "wb")
  for i = 0, it.count - 1 do local w = it:read(i) o:write(string.char((w >> 8) & 0xff, w & 0xff)) end
  o:close()
end
emu.register_frame_done(function()
  f = f + 1
  if releases[f] then for _, b in ipairs(releases[f]) do field(b):clear_value() end end
  for _, cmd in ipairs(ev[f] or {}) do
    local op, arg = cmd:match("^(%a+):?(.*)$")
    if op == "press" then
      field(arg):set_value(1)
      releases[f + 5] = releases[f + 5] or {}
      table.insert(releases[f + 5], arg)
    elseif op == "hold" then field(arg):set_value(1)
    elseif op == "release" then field(arg):clear_value()
    elseif op == "poke" then
      local a, v = arg:match("(%x+)=(%x+)")
      prog:write_u16(tonumber(a, 16), tonumber(v, 16))
    elseif op == "shot" then manager.machine.video:snapshot()
    elseif op == "dump" then
      dumpitem("m_vram", arg .. ".vram"); dumpitem("m_cram", arg .. ".cram")
      dumpitem("m_vsram", arg .. ".vsram"); dumpitem("m_regs", arg .. ".regs")
      local r = io.open(arg .. ".ram", "wb")
      for a = 0xFF0000, 0xFFFFFF, 2 do local w = prog:read_u16(a) r:write(string.char(w >> 8, w & 0xff)) end
      r:close()
    elseif op == "exit" then manager.machine:exit()
    end
  end
end)
