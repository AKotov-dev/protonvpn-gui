unit PingTRD;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, StdCtrls, Graphics;

type
  CheckPing = class(TThread)
  private

    { Private declarations }
  protected
  var
    PingStr: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

//Флаг Ping-а (True/False) - публичный
{var
  Ping: boolean;
 }
implementation

uses unit1;

{ TRD }

procedure CheckPing.Execute;
var
  PingProcess: TProcess;
begin
  FreeOnTerminate := True; //Уничтожать по завершении

  while not Terminated do
    try
      PingStr := TStringList.Create;
      PingProcess := TProcess.Create(nil);

      PingProcess.Executable := 'bash';  //sh или xterm
      PingProcess.Parameters.Add('-c');
      PingProcess.Parameters.Add(
        //   'if [[ $(ip a | grep tun0) ]] && ping -c2 google.com &>/dev/null; then echo "yes"; else echo "no"; fi');
        'if [[ ERR=$(ping google.com -c 1 2>&1 > /dev/null) && $(ip a |  cut -f2 -d" " | grep tun) ]]; then echo "yes"; else echo "no"; fi');

      PingProcess.Options := [poUsePipes, poWaitOnExit];
      PingProcess.Execute;

      PingStr.LoadFromStream(PingProcess.Output);

      Synchronize(@ShowStatus);

      Sleep(1500);
    finally
      PingStr.Free;
      PingProcess.Free;
    end;
end;

procedure CheckPing.ShowStatus;
begin
  Application.ProcessMessages;
  if Trim(PingStr[0]) = 'yes' then
    MainForm.Shape1.Brush.Color := clLime
  else
    MainForm.Shape1.Brush.Color := clYellow;
  MainForm.Shape1.Repaint;
  MainForm.Shape1.Update;
end;

end.
