"""Coordinated observation contracts against the real Lua modules and mock APIs."""
from pathlib import Path
from lupa import lua51
ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}")
for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
    if name.strip().endswith(".lua"):
        lua.execute((ROOT / name.strip()).read_text(encoding="utf-8"), "LifeTimeStats", lua.globals().ns)
lua.execute(r'''

local n = 0
local function check(ok, label) n=n+1; assert(ok,label) end
local function fire(e,...) ns.frame.scripts.OnEvent(ns.frame,e,...) end
fire("ADDON_LOADED","LifeTimeStats"); fire("PLAYER_ENTERING_WORLD",true,false)
check(ns.db.schema==3,"schema3 migration")
local blank=ns.NewCharRecord()
local catalog=ns.Measurement.Catalog(); check(#catalog==992,"all advertised families covered")
for _,entry in ipairs(catalog) do check(entry.definition and entry.definition.provider and entry.definition.source and entry.definition.quality,"reviewed "..entry.id) end
ns.STATS.life[#ns.STATS.life+1]={key="new_unreviewed_stat",label="new"}
local missing=ns.Measurement.Definition(ns.STATS.life[#ns.STATS.life]); check(not missing,"new rows require explicit review")
table.remove(ns.STATS.life)
local function stat(key)
 for _,list in pairs(ns.STATS) do for _,s in ipairs(list) do if s.key==key or s.rec==key then return s end end end
 error(key)
end
local ch=ns.char
check(ns.Measurement.Resolve(stat("max_airtime"),blank).availability=="unknown","record absence remains unknown")
check(not ch.measurement.historicalUnknown,"new record has a known provenance start")
local legacy=ns.NewCharRecord(); legacy.c.jumps=33; ns.Measurement.Initialize(legacy,false)
check(ns.Measurement.Resolve(stat("jumps"),legacy).quality=="historical-unknown","legacy totals don't gain invented provenance")
ns.settings.amountsSecret=true; ns.settings.healthSecret=true
C_CombatLogSecure={}; C_DamageMeter=nil
local heal=ns.Measurement.Resolve(stat("overheal"),ch)
check(heal.availability=="unavailable","unsupported combat field is unavailable")
check(ns.Measurement.Resolve(stat("max_health"),ch).currentAvailability=="available","API maxhealth independent of combat log")
check(ns.Measurement.Resolve(stat("casts"),ch).availability=="available","successful casts independent of combat log")
ch.c.overheal=8
check(ns.Measurement.Resolve(stat("overheal"),ch).value==8 and ns.Measurement.Resolve(stat("overheal"),ch).availability=="unknown","legacy nonzero preserved independently of current availability")
ch.c.overheal=0
ch.c.jumps=0
check(ns.Measurement.Resolve(stat("jumps"),ch).value==0,"observed zero remains numeric")
ns.src.amountReadable=true
check(ns.Measurement.Resolve(stat("dmg_done"),ch).availability=="available","outgoing combat text fallback remains available")
ns.src.amountReadable=nil
local hp=UnitHealthMax; UnitHealthMax=function() error("restricted") end
check(ns.Measurement.Resolve(stat("max_health"),ch).currentAvailability=="unavailable","unreadable API not coerced to zero")
UnitHealthMax=hp
ns.db.chars["Forever-Legacy"]=legacy
check(ns.Measurement.Resolve(stat("jumps"),ns.GetView("account","lifetime"),{scope="account"}).availability=="mixed","mixed account provenance")
ns.db.chars["Forever-Legacy"]=nil
local original=ns.UNIQUE_CAP; ns.UNIQUE_CAP=20000
for i=1,20000 do ch.u.test=ch.u.test or {};ch.u.test[tostring(i)]=true end;ch.un.test=20000
check(not ns.Unique("test",20001),"unique cap preserved")
check(ns.Retention.Collection(ch,"u","test").atLeast,"saturated unique count is at least")
for i=1,401 do ns.Tally("test","label"..i,1) end
check(ns.Retention.Collection(ch,"t","test").omitted,"label omission recorded")
check(ns.Retention.Collection(ch,"t","test").kept==400,"label cap unchanged")
local older=ns.NewCharRecord(); older.u.test={}; for i=1,20000 do older.u.test[tostring(i)]=true end
ns.Retention.Repair(older)
check(ns.Retention.Collection(older,"u","test").historicalUnknown,"legacy atcap omission history unknown")
local meta={started=1,historicalUnknown=false,families={combat={transitions={}}}}
for i=1,9 do meta.families.combat.transitions[i]={at=i,state="available"} end
check(not ns.Measurement.ValidateSaved(meta),"transition ninth row rejected")
meta.families.combat.transitions[9]=nil
check(ns.Measurement.ValidateSaved(meta),"bounded transitions accepted")
meta.injected=true;check(not ns.Measurement.ValidateSaved(meta),"unknown metadata field rejected")
local oversized=ns.NewCharRecord(); oversized.u.test={}; oversized.un.test=20001
for i=1,20001 do oversized.u.test[tostring(i)]=true end
ns.Retention.Repair(oversized)
check(oversized.u.test["20001"] and oversized.un.test==20001,"legacy oversized identities preserved")
local text,err=ns.SerializeFullBackup();check(type(text)=="string",err or "fullbackup")
local snap,err2=ns.DeserializeFullBackup(text);check(type(snap)=="table",err2 or "parse")
check(snap.record.retention.t.test=="omitted","retention roundtrip")
check(snap.record.measurement.started==ch.measurement.started,"provenance roundtrip")
local before=ch.c.jumps
snap.record.measurement.families.combat={transitions={{at=1,state="available",extra={deep={deeper={}}}}}}
local ok=ns.RestoreFullBackup(snap)
check(not ok and ch.c.jumps==before,"malformed deep restore rejected atomically")
local deep="m1:s1:xm1:s1:xm1:s1:xm1:s1:xm1:s1:xm1:s1:xm1:s1:xm1:s1:xn1;"
local a,b=1,0;for i=1,#deep do a=(a+deep:byte(i))%65521;b=(b+a)%65521 end
local decoded,decodeError=ns.DeserializeFullBackup("LTS3|"..string.format("%04x%04x",b,a).."|"..deep)
check(not decoded and decodeError:find("too many entries",1,true),"depth9 parser input rejected")
local prior=ns.char; LifeTimeStatsDB.schema=4; ns.char=nil; ns.InitDB()
check(ns.char==nil and LifeTimeStatsDB.schema==4,"future schema refused without downgrade")
ns.char=prior; LifeTimeStatsDB.schema=3
local csv=ns.CompendiumCSV();check(csv:find("[measurement]",1,true),"compendium metadata exported")
local data=table.concat(ns.SizeReport(),"\n"); check(data:find("Retained data windows",1,true),"data report retention")
print("MEASUREMENT PASS: "..n.." assertions")

''')
