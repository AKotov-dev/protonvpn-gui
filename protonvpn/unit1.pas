unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Process, DefaultTranslator, Buttons, XMLPropStorage;

type

  { TMainForm }

  TMainForm = class(TForm)
    AutoStartCheckBox: TCheckBox;
    Button1: TButton;
    Shape1: TShape;
    DownloadBtn: TButton;
    Memo1: TMemo;
    Timer1: TTimer;
    XMLPropStorage1: TXMLPropStorage;
    procedure AutoStartCheckBoxChange(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure DownloadBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure StartProcess(command: string);
  private

  public

  end;

var
  MainForm: TMainForm;

implementation

uses PingTrd, ConfigUnit;

{$R *.lfm}

{ TMainForm }

//Проверка чекбокса AutoStart
function CheckAutoStart: boolean;
var
  s: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    '[[ -n $(systemctl is-enabled protonvpn | grep "enabled") ]] && echo "yes"'], s);

  if Trim(s) = 'yes' then
    Result := True
  else
    Result := False;
end;

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    //  ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Вывод лога состояния
procedure TMainForm.Timer1Timer(Sender: TObject);
var
  LOG: TStringList;
begin
  LOG := TStringList.Create;
  if FileExists('/var/log/protonvpn.log') then
  begin
    LOG.LoadFromFile('/var/log/protonvpn.log');
    if LOG.Text <> Memo1.Lines.Text then
    begin
      Memo1.Lines.Assign(LOG);
      //Промотать список вниз
      Memo1.SelStart := Length(Memo1.Text);
      Memo1.SelLength := 0;
    end;
  end
  else
    Memo1.Text := 'The logfile not found: /var/log/protonvpn.log';
  LOG.Free;
end;

procedure TMainForm.AutoStartCheckBoxChange(Sender: TObject);
var
  s: ansistring;
begin
  Screen.Cursor := crHourGlass;
  if AutoStartCheckBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl enable protonvpn'], s)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl disable protonvpn'], s);

  AutoStartCheckBox.Checked := CheckAutoStart;
  Screen.Cursor := crDefault;
end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  StartProcess('systemctl stop protonvpn.service');
  Shape1.Brush.Color := clYellow;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  AutoStartCheckBox.Checked := CheckAutoStart;
end;

procedure TMainForm.DownloadBtnClick(Sender: TObject);
begin
  ConfigForm.Show;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  FCheckPingThread: TThread;
begin
  MainForm.Caption := Application.Title;

  //Конфиг
  if not DirectoryExists('/etc/protonvpn') then
    MkDir('/etc/protonvpn');

  XMLPropStorage1.FileName := '/etc/protonvpn/protonvpn.xml';

  //Поток проверки пинга
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;
end;

end.
