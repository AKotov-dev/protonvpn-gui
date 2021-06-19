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
var
  Ping: boolean;

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
        'if ping -c1 ya.ru &>/dev/null && [[ $(ifconfig | grep tun0) ]]; then echo "yes"; else echo "no"; fi');

      PingProcess.Options := PingProcess.Options + [poUsePipes, poWaitOnExit];
      PingProcess.Execute;

      PingStr.LoadFromStream(PingProcess.Output);

      //Результат проверки ping
      if PingStr[0] = 'yes' then
        Ping := True
      else
        Ping := False;

      Synchronize(@ShowStatus);

      Sleep(1000);
    finally
      PingStr.Free;
      PingProcess.Free;
    end;
end;

procedure CheckPing.ShowStatus;
begin
  if Ping then
    MainForm.Shape1.Brush.Color := clLime
  else
    MainForm.Shape1.Brush.Color := clYellow;
  MainForm.Shape1.Repaint;
end;

end.
