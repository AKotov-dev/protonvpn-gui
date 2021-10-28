unit configunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, FileCtrl, StdCtrls,
  ExtCtrls, XMLPropStorage, Process;

type

  { TConfigForm }

  TConfigForm = class(TForm)
    Button1: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    FileListBox1: TFileListBox;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    OpenDialog1: TOpenDialog;
    XMLPropStorage1: TXMLPropStorage;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FileListBox1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure XMLPropStorage1RestoringProperties(Sender: TObject);
    procedure XMLPropStorage1SavingProperties(Sender: TObject);
  private

  public

  end;

//Ресурсы перевода
//resourcestring
//SDeleteRecords = 'Delete selected entries other than the active one?';

var
  ConfigForm: TConfigForm;

implementation

uses Unit1;

{$R *.lfm}

{ TConfigForm }

procedure TConfigForm.FormCreate(Sender: TObject);
begin
  ConfigForm.XMLPropStorage1.FileName := MainForm.XMLPropStorage1.FileName;
end;

procedure TConfigForm.FormShow(Sender: TObject);
begin
  if FileListBox1.SelCount <> 0 then
    Button2.Enabled := True
  else
    Button2.Enabled := False;
end;

procedure TConfigForm.XMLPropStorage1RestoringProperties(Sender: TObject);
begin
  FileListBox1.ItemIndex := XMLPropStorage1.ReadInteger('findex', -1);
  FileListBox1.Click;
end;

procedure TConfigForm.XMLPropStorage1SavingProperties(Sender: TObject);
begin
  XMLPropStorage1.StoredValue['findex'] := IntToStr(FileListBox1.ItemIndex);
end;

procedure TConfigForm.Button2Click(Sender: TObject);
var
  S: TStringList;
begin
  MainForm.Shape1.Brush.Color := clYellow;
  MainForm.Shape1.Repaint;

  try
    //Создаём файл логин/пароль
    S := TStringList.Create;
    S.Add(Trim(Edit1.Text));
    S.Add(Trim(Edit2.Text));
    S.SaveToFile('/etc/protonvpn/protonvpn.pass');

    S.Clear;
    //Формируем /etc/systemd/system/protonvpn.service
    S.Add('[Unit]');

    S.Add('Description=Proton VPN Tunneling Application');
    S.Add('After=network-online.target');
    S.Add('Wants=network-online.target');
    S.Add('');

    S.Add('[Service]');
    S.Add('PrivateTmp=true');
    S.Add('Type=forking');
    S.Add('PIDFile=/run/openvpn/protonvpn.pid');
    S.Add('ExecStart=/usr/sbin/openvpn --daemon --writepid /run/openvpn/protonvpn.pid \');
    S.Add('--config ' + FileListBox1.FileName + ' --log /var/log/protonvpn.log \');

    if CheckBox1.Checked then
    begin
      S.Add('--script-security 2 --up /etc/protonvpn/update-resolv-conf \');
      S.Add('--down /etc/protonvpn/update-resolv-conf \');
    end;

    S.Add('--mute-replay-warnings --auth-user-pass /etc/protonvpn/protonvpn.pass');
    S.Add('');

    S.Add('[Install]');
    S.Add('WantedBy=multi-user.target');
    S.SaveToFile('/etc/systemd/system/protonvpn.service');
  finally
    S.Free;

    //Попутно удаляем коннект на 80-тый порт из конфига (иногда не подключается на FREE)
    Mainform.StartProcess(
      'chmod 600 /etc/protonvpn/protonvpn.pass; sed -i "/remote.*80/ d" ' +
      ConfigForm.FileListBox1.FileName +
      '; systemctl daemon-reload; systemctl stop protonvpn.service; ' +
      'systemctl restart protonvpn.service');

    //MainForm.AutoStartCheckBox.Enabled := True;

    ConfigForm.Close;
  end;
end;

procedure TConfigForm.FileListBox1Click(Sender: TObject);
begin
  //Запоминаем индекс
  XMLPropStorage1.WriteInteger('findex', FileListBox1.ItemIndex);
end;

procedure TConfigForm.Button1Click(Sender: TObject);
var
  s: ansistring;
begin
  if OpenDialog1.Execute then
  begin
    //Удаление старых *.ovpn
    RunCommand('/bin/bash', ['-c', 'rm -f /etc/protonvpn/*protonvpn.com*'], s);

    //zip или не zip
    //if Copy(OpenDialog1.FileName, Length(OpenDialog1.FileName) - 3, 4) = '.zip' then
    RunCommand('/bin/bash', ['-c', 'unzip -o "' + OpenDialog1.FileName +
      '" -d /etc/protonvpn/'], s);
   { else
      RunCommand('/bin/bash', ['-c', 'cp -f "' + OpenDialog1.FileName +
        '" /etc/protonvpn/'], s); }

    FileListBox1.UpdateFileList;

    FileListBox1.ItemIndex := 0;
    FileLIstBox1.Click;

    Button2.Enabled := True;
  end;
end;

end.
