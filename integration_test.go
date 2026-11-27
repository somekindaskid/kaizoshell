package main
import ("strings";"testing")
func TestIntegrationBlock(t *testing.T){
 for _,lua:=range []bool{false,true}{
  base:="original\n\n"
  block:=integrationBlock(lua,true,false)
  got,e:=stripIntegration(base+block)
  if e!=nil||got!=base{t.Fatalf("strip: %q %v",got,e)}
  if !strings.Contains(block,"kaizo search")||!strings.Contains(block,"kaizo start"){t.Fatal(block)}
  if strings.Contains(integrationBlock(lua,false,false),"kaizo search"){t.Fatal("unexpected shortcut")}
  if _,e=stripIntegration(base+block+block);e==nil{t.Fatal("duplicate block accepted")}
 }
}
func TestSearchBindRecognition(t *testing.T){
 if !searchBind(desktopBind{Modmask:64,Key:"space"})||searchBind(desktopBind{Modmask:65,Key:"space"})||searchBind(desktopBind{Modmask:64,Key:"space",Submap:"resize"}){t.Fatal("incorrect shortcut detection")}
 if !ownSearchBind(desktopBind{Arg:"$HOME/.local/bin/kaizo search"})||ownSearchBind(desktopBind{Arg:"wofi"}){t.Fatal("incorrect ownership")}
}

func TestParseConfigProvider(t *testing.T){
 for _,tc:=range []struct{raw,want string}{
  {`{"configProvider":"lua"}`,"lua"},
  {`{"configProvider":"hyprlang"}`,"hyprlang"},
  {"backend: drm\nconfigProvider: lua\n","lua"},
  {"configProvider: hyprlang","hyprlang"},
  {"unknown request",""},
  {`{"configProvider":"unknown"}`,""},
 }{
  if got:=parseConfigProvider([]byte(tc.raw));got!=tc.want{t.Fatalf("provider %q: got %q want %q",tc.raw,got,tc.want)}
 }
}
