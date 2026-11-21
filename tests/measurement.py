"""Coordinated observation contracts against the real Lua modules and mock APIs."""
from pathlib import Path
from lupa import lua51
ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}")
lua.execute(r'''local create=CreateFrame
CreateFrame=function(...)
 local frame=create(...); local font=frame.CreateFontString
 frame.CreateFontString=function(self,...)
  local text=font(self,...)
  text.SetHeight=function(self,height) self.h=height end
  text.SetWidth=function(self,width) self.wdt=width end
  return text
 end
 return frame
end''')
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
for _,entry in ipairs(catalog) do check(entry.definition and entry.definition.provider and entry.definition.source and entry.definition.quality,"reviewed "..entry.id)
 if entry.stat.get then
  local d=entry.definition
  check(d.calculation and ((d.inputs and #d.inputs>0 and d.computedPolicy=="inputs") or d.computedPolicy=="unknown-provider"),"computed dependency/provider contract "..entry.id)
 end end
ns.STATS.life[#ns.STATS.life+1]={key="new_unreviewed_stat",label="new"}
local missing=ns.Measurement.Definition(ns.STATS.life[#ns.STATS.life]); check(not missing,"new rows require explicit review")
table.remove(ns.STATS.life)
local function stat(key)
 for _,list in pairs(ns.STATS) do for _,s in ipairs(list) do if s.key==key or s.rec==key or s.label==key then return s end end end
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
for _,label in ipairs({"Crit rate","Dodge rate"}) do
 local status=ns.Measurement.Resolve(stat(label),ch)
 check(status.currentAvailability=="unknown","unverified combat dependencies "..label)
 check(status.calculation:find("/",1,true),"human formula "..label)
end
check(ns.Measurement.Resolve(stat("Effective healing per recorded heal"),ch).currentAvailability=="unavailable","computed healing propagates unavailable dependency")
check(ns.Measurement.Resolve(stat("Gold per hour (online)"),ch).currentAvailability=="available","economy ratio has supported independent inputs")
check(ns.Measurement.Resolve(stat("Active time (not AFK)"),ch).currentAvailability=="available","time computation remains independent of combat")
check(ns.Measurement.Resolve(stat("Adventurer score"),ch).currentAvailability=="unknown","unverified multi-provider score stays conservative")
local sessionStatus=ns.Measurement.Resolve(stat("jumps"),ns.session,{scope="session"})
check(sessionStatus.started==ns.session.wallStart and sessionStatus.sessionCharacter==ns.char.meta.name,"session start and active-character scope")
local oldHP=UnitHealthMax; UnitHealthMax=function() error("unreadable") end
local absent=ns.Measurement.Resolve(stat("max_health"),ch)
check(absent.value==nil and absent.currentAvailability=="unavailable","absent record and current restriction separate")
local exported=ns.CompendiumCSV()
local hpRow=exported:match("[^\n]*,Maximum health,[^\n]*") or exported:match("[^\n]*,Most health,[^\n]*")
for line in exported:gmatch("[^\n]+") do if line:find(","..stat("max_health").label..",",1,true) then hpRow=line end end
check(hpRow and hpRow:match(",,$"),"absent record exports empty character/account fields")
ns.ToggleWindow(); ns.ShowStatDetail(stat("max_health"))
local layer
for _,frame in ipairs(frames) do if rawget(frame,"stat")==stat("max_health") then layer=frame end end
check(layer and layer.tip:GetHeight()==36 and 64+layer.tip:GetHeight()<=112,"actual summary height fits fixed facts budget")
layer.tip:SetWidth(220)
check(select(2,layer.tip:GetText():gsub("\n",""))==1 and layer.tip:GetHeight()<=48,"narrow summary remains bounded two lines")
local report;local show=ns.ShowText;ns.ShowText=function(_,_,text) report=text end
layer.measurementButton.scripts.OnClick()
check(report and report:find("Current feed: unavailable",1,true) and report:find("Calculation:",1,true),"full scroll/copy report retains complete metadata")
ns.ShowText=show
local other=ns.NewCharRecord();other.meta.name="Other";other.r.max_health=5
ns.db.chars["Forever-Other"]=other
ns.ShowStatDetail(stat("max_health"))
check(layer.facts[1].val:GetText()=="—" and layer.facts[7].val:GetText():find("5",1,true),"active absent record cannot hide another character's retained record")
ch.r.max_health=0
check(ns.Measurement.Resolve(stat("max_health"),ch).value==0,"explicit historical record zero remains a value")
ns.ShowStatDetail(stat("max_health"));check(layer.facts[1].val:GetText()=="0","genuine recorded zero remains visible")
ch.r.max_health=nil; ns.db.chars["Forever-Other"]=nil
UnitHealthMax=oldHP
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
