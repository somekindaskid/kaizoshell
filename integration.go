package main

import (
 "bytes"
 "encoding/json"
 "errors"
 "fmt"
 "os"
 "os/exec"
 "path/filepath"
 "strings"
 "time"
)

const integrationBegin = "KAIZO MANAGED INTEGRATION BEGIN"
const integrationEnd = "KAIZO MANAGED INTEGRATION END"

// Query the running compositor rather than guessing from the existence of files.
func parseConfigProvider(raw []byte) string {
 var data map[string]any
 if json.Unmarshal(raw,&data)==nil {
  if v,ok:=data["configProvider"].(string);ok {
   switch strings.ToLower(strings.TrimSpace(v)){case "lua":return "lua";case "hyprlang":return "hyprlang"}
  }
 }
 for _,line:=range strings.Split(string(raw),"\n"){
  k,v,ok:=strings.Cut(line,":")
  if !ok||!strings.EqualFold(strings.TrimSpace(k),"configProvider"){continue}
  switch strings.ToLower(strings.TrimSpace(v)){case "lua":return "lua";case "hyprlang":return "hyprlang"}
 }
 return ""
}
func activeConfigProvider() string {
 for _,args:=range [][]string{{"-j","status"},{"status"}}{
  if raw,e:=exec.Command("hyprctl",args...).Output();e==nil{
   if p:=parseConfigProvider(raw);p!=""{return p}
  }
 }
 return ""
}

func integrationPath() (string,error) {
 // An explicitly selected compositor config is safer than guessing.
 sig:=os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
 if sig!="" {
  if raw,e:=exec.Command("hyprctl","-j","instances").Output();e==nil {
   var instances []struct{ Instance string; PID int }
   if json.Unmarshal(raw,&instances)==nil {
    for _,i:=range instances {
     if i.Instance!=sig || i.PID<=0 {continue}
     if raw,e:=os.ReadFile(fmt.Sprintf("/proc/%d/cmdline",i.PID));e==nil {
      args:=strings.Split(string(raw),"\x00")
      for j,a:=range args {
       p:=""
       if (a=="-c"||a=="--config")&&j+1<len(args){p=args[j+1]} else if strings.HasPrefix(a,"--config="){p=strings.TrimPrefix(a,"--config=")}
       if p!="" {
        if !filepath.IsAbs(p) {return "",errors.New("custom relative Hyprland config: automatic integration skipped")}
        return safeIntegrationPath(p)
       }
      }
     }
    }
   }
  }
 }
 dir:=filepath.Join(xdg("XDG_CONFIG_HOME",".config"),"hypr")
 lua,legacy:=filepath.Join(dir,"hyprland.lua"),filepath.Join(dir,"hyprland.conf")
 if exists(lua)&&exists(legacy) {
  provider:=activeConfigProvider()
  switch provider {
  case "lua":return safeIntegrationPath(lua)
  case "hyprlang":return safeIntegrationPath(legacy)
  default:return "",errors.New("both config files exist and active provider could not be determined; run hyprctl status")
  }
 }
 if exists(lua){return safeIntegrationPath(lua)}
 return safeIntegrationPath(legacy)
}
func safeIntegrationPath(p string)(string,error){
 if filepath.Ext(p)!=".lua"&&filepath.Ext(p)!=".conf"{return "",errors.New("unsupported Hyprland configuration format")}
 // Avoid replacing symlinks (e.g. managed dotfiles) or files outside the user's home.
 if !filepath.IsAbs(p)||!filepath.IsLocal(strings.TrimPrefix(p,home+string(os.PathSeparator)))||!strings.HasPrefix(p,home+string(os.PathSeparator)){return "",errors.New("Hyprland configuration is outside your home")}
 resolved,e:=filepath.EvalSymlinks(p);if e!=nil{return "",e}
 if resolved!=p{return "",errors.New("Hyprland config uses symlinks; refusing automatic edits")}
 st,e:=os.Lstat(p);if e!=nil{return "",e};if !st.Mode().IsRegular(){return "",errors.New("Hyprland config is not a regular file")}
 return p,nil
}
func stripIntegration(s string)(string,error){
 // Keep every unmanaged byte, including blank lines.
 lines:=strings.SplitAfter(s,"\n")
 var out strings.Builder
 inside,seen:=false,false
 for _,line:=range lines{
  t:=strings.TrimSpace(line)
  if t=="# "+integrationBegin||t=="-- "+integrationBegin{
   if inside||seen{return "",errors.New("duplicate managed block")};inside=true;seen=true;continue
  }
  if t=="# "+integrationEnd||t=="-- "+integrationEnd{
   if !inside{return "",errors.New("unexpected managed block end")};inside=false;continue
  }
  if !inside{out.WriteString(line)}
 }
 if inside{return "",errors.New("incomplete managed block")}
 return out.String(),nil
}
type desktopBind struct {
 Modmask int
 Key string
 Keycode int
 Dispatcher string
 Arg string
 Submap string
 Description string
}
func getDesktopBinds()([]desktopBind,error){
 b,e:=exec.Command("hyprctl","-j","binds").Output();if e!=nil{return nil,fmt.Errorf("cannot inspect Hyprland binds: %w",e)}
 var binds []desktopBind
 if e=json.Unmarshal(b,&binds);e!=nil{return nil,e}
 if binds==nil{return nil,errors.New("invalid bind response")}
 return binds,nil
}
func searchBind(b desktopBind)bool{
 return b.Modmask==64&&(strings.EqualFold(b.Key,"space")||b.Keycode==65)&&(b.Submap==""||b.Submap=="reset"||b.Submap=="default")
}
func ownSearchBind(b desktopBind)bool{
 return strings.Contains(b.Arg,"kaizo search")||strings.Contains(b.Arg,"kaizo launcher")||b.Description=="Kaizo Search"
}
func integrationBlock(lua,addBind,replace bool)string{
 // The shell expands HOME; no user-supplied values become executable code.
 if lua{
  s:="-- "+integrationBegin+"\n"
  if addBind{
   if replace{s+="hl.unbind(\"SUPER + space\")\nhl.unbind(\"SUPER + SPACE\")\n"}
   s+="hl.bind(\"SUPER + space\", hl.dsp.exec_cmd(\"$HOME/.local/bin/kaizo search\"), { description = \"Kaizo Search\" })\n"
  }
  return s+"hl.on(\"hyprland.start\", function()\n    hl.exec_cmd(\"$HOME/.local/bin/kaizo start\")\nend)\n-- "+integrationEnd+"\n"
 }
 s:="# "+integrationBegin+"\n"
 if addBind{
  if replace{s+="unbind = SUPER, SPACE\nunbind = SUPER, space\n"}
  s+="bind = SUPER, SPACE, exec, $HOME/.local/bin/kaizo search\n"
 }
 return s+"exec-once = $HOME/.local/bin/kaizo start\n# "+integrationEnd+"\n"
}
func reloadIntegration()error{
 b,e:=exec.Command("hyprctl","reload").CombinedOutput()
 if e!=nil||!strings.EqualFold(strings.TrimSpace(string(b)),"ok"){return fmt.Errorf("Hyprland reload failed: %s %v",strings.TrimSpace(string(b)),e)}
 // Reload is asynchronous on some versions.
 time.Sleep(350*time.Millisecond)
 b,e=exec.Command("hyprctl","configerrors").CombinedOutput()
 if e!=nil{return fmt.Errorf("cannot verify config: %s %v",string(b),e)}
 if s:=strings.TrimSpace(string(b));s!=""&&s!="ok"{return fmt.Errorf("Hyprland config errors: %s",s)}
 return nil
}
func integrate(mode string)error{
 if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")==""||os.Getenv("WAYLAND_DISPLAY")==""{return errors.New("run integration inside Hyprland")}
 p,e:=integrationPath();if e!=nil{return e}
 raw,e:=os.ReadFile(p);if e!=nil{return e}
 old:=string(raw)
 clean,e:=stripIntegration(old);if e!=nil{return e}
 if mode=="status"{
  fmt.Println("Config:",p)
  fmt.Println("Managed startup:",clean!=old)
  binds,e:=getDesktopBinds();if e!=nil{return e}
  for _,b:=range binds{if searchBind(b){fmt.Printf("Super+Space: %s %s %s\n",b.Dispatcher,b.Arg,b.Description)}}
  return nil
 }
 if mode!="enable"&&mode!="replace"&&mode!="remove"{return errors.New("usage: kaizo integration enable|replace|remove|status")}
 if mode=="remove"&&clean==old{return nil}
 next:=clean
 conflict:=false
 expectedBind:=false
 if mode!="remove"{
  binds,e:=getDesktopBinds();if e!=nil{return e}
  own,other:=false,false
  for _,b:=range binds{if searchBind(b){if ownSearchBind(b){own=true}else{other=true}}}
  // A previously managed binding needs to be written again after stripping.
  hadManagedBind:=clean!=old&&strings.Contains(old, "kaizo search")
  // Keep an explicitly chosen replacement on later updates.
  replace:=mode=="replace"||(hadManagedBind&&(strings.Contains(old,"hl.unbind(\"SUPER + space\")")||strings.Contains(old,"unbind = SUPER, SPACE")))
  conflict=other&&!replace
  add:=!conflict&&(!own||hadManagedBind||replace)
  expectedBind=!conflict
  if next!=""&&!strings.HasSuffix(next,"\n"){next+="\n"}
  next+=integrationBlock(filepath.Ext(p)==".lua",add,replace)
 }
 if next==old{
  if conflict{fmt.Println("Super+Space is already assigned. Use Settings to replace it.")}
  return nil
 }
 st,e:=os.Stat(p);if e!=nil{return e}
 // Preserve original contents in a private, timestamped backup.
 backupPath:=filepath.Join(stateDir(),"hyprland-backups",fmt.Sprintf("%d-%s",time.Now().UnixNano(),filepath.Base(p)))
 if e=atomic(backupPath,raw,0600);e!=nil{return e}
 // Refuse concurrent edits rather than clobbering them.
 latest,e:=os.ReadFile(p);if e!=nil{return e};if !bytes.Equal(raw,latest){return errors.New("Hyprland config changed during integration; retry")}
 if e=atomic(p,[]byte(next),st.Mode().Perm());e!=nil{return e}
 rollback:=func(cause error)error{
  now,err:=os.ReadFile(p);if err!=nil||string(now)!=next{return fmt.Errorf("%v; config changed after write, original backup: %s",cause,backupPath)}
  if err=atomic(p,raw,st.Mode().Perm());err!=nil{return fmt.Errorf("%v; automatic rollback failed: %v; backup: %s",cause,err,backupPath)}
  _,_=exec.Command("hyprctl","reload").CombinedOutput()
  return fmt.Errorf("%v; restored original configuration",cause)
 }
 if e=reloadIntegration();e!=nil{return rollback(e)}
 if expectedBind{
  binds,e:=getDesktopBinds();if e!=nil{return rollback(e)}
  own,other:=0,0
  for _,b:=range binds{if searchBind(b){if ownSearchBind(b){own++}else{other++}}}
  if own!=1||other!=0{return rollback(errors.New("could not verify an exclusive Kaizo search binding"))}
 }
 fmt.Println("Hyprland integration:",mode,"; backup:",backupPath)
 if conflict{fmt.Println("Super+Space is already assigned. Startup is configured; use Settings to replace the shortcut.")}
 return nil
}
