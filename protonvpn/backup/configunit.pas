unit configunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, FileCtrl, StdCtrls,
  ExtCtrls, XMLPropStorage, Process;

type

  { TConfigForm }

  TConfigForm = class(TForm)
    LoadBtn: TButton;
    RestartBtn: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    FileListBox1: TFileListBox;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    OpenDialog1: TOpenDialog;
    XMLPropStorage1: TXMLPropStorage;
    procedure LoadBtnClick(Sender: TObject);
    procedure RestartBtnClick(Sender: TObject);
    procedure FileListBox1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure XMLPropStorage1RestoringProperties(Sender: TObject);
    procedure XMLPropStorage1SavingProperties(Sender: TObject);
  private

  public

  end;

var
  ConfigForm: TConfigForm;

implementation

uses Unit1;

{$R *.lfm}

{ TConfigForm }

//Конфигурация-настройки
procedure TConfigForm.FormCreate(Sender: TObject);
begin
  ConfigForm.XMLPropStorage1.FileName := MainForm.XMLPropStorage1.FileName;
end;

//Состояние ReatartBtn, размеры формы (Plasma)
procedure TConfigForm.FormShow(Sender: TObject);
begin
  XMLPropStorage1.Restore;
  if FileListBox1.SelCount <> 0 then
    RestartBtn.Enabled := True
  else
    RestartBtn.Enabled := False;
end;

//Восстановить индекс записи в списке
procedure TConfigForm.XMLPropStorage1RestoringProperties(Sender: TObject);
begin
  FileListBox1.ItemIndex := XMLPropStorage1.ReadInteger('findex', -1);
  FileListBox1.Click;
end;

//Сохранить индекс записи в списке
procedure TConfigForm.XMLPropStorage1SavingProperties(Sender: TObject);
begin
  XMLPropStorage1.StoredValue['findex'] := IntToStr(FileListBox1.ItemIndex);
end;

//Запуск/Перезапуск VPN-соединения
procedure TConfigForm.RestartBtnClick(Sender: TObject);
var
  S: TStringList;
begin
  //Если список пуст - выйти
  if FileListBox1.Count = 0 then Exit;

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
    S.Add('--config "' + FileListBox1.FileName + '" --log /var/log/protonvpn.log \');

    S.Add('--script-security 2 --up /etc/protonvpn/update-resolv-conf \');
    S.Add('--down /etc/protonvpn/update-resolv-conf \');

    //--ping-restart 10?
    S.Add('--mute-replay-warnings --auth-user-pass /etc/protonvpn/protonvpn.pass');
    S.Add('');

    S.Add('[Install]');
    S.Add('WantedBy=multi-user.target');
    S.SaveToFile('/etc/systemd/system/protonvpn.service');
  finally
    S.Free;

    //Попутно удаляем коннект на 80-тый порт из конфига (иногда не подключается на FREE и ставим #persist-tun)
    Mainform.StartProcess(
      'chmod 600 /etc/protonvpn/protonvpn.pass; sed -i "/remote.*80/ d" "' +
      ConfigForm.FileListBox1.FileName + '"; sed -i ' + '''' +
      's/^persist-tun*/#persist-tun/' + '''' + ' "' + ConfigForm.FileListBox1.FileName +
      '"; systemctl daemon-reload; systemctl stop protonvpn.service; ' +
      'systemctl restart protonvpn.service');

    ConfigForm.Close;
  end;
end;

//Перемещение в списке, запоминаем индекс
procedure TConfigForm.FileListBox1Click(Sender: TObject);
begin
  XMLPropStorage1.WriteInteger('findex', FileListBox1.ItemIndex);
end;

//Сохраняем настройки
procedure TConfigForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  XMLPropStorage1.Save;
end;

//Загрузка конфигураций *.ovpn из архива *.zip
procedure TConfigForm.LoadBtnClick(Sender: TObject);
var
  S: ansistring;
begin
  try
    if OpenDialog1.Execute then
    begin
      //Просмотр архива на предмет конфигураций *.ovpn
      RunCommand('/bin/bash', ['-c', 'unzip -l "' + OpenDialog1.FileName +
        '" | grep ".ovpn"'], S);
      //Выход, если в *.zip отсутствуют конфигурации *.ovpn
      if Trim(S) = '' then
      begin
        MessageDlg(SNoVPNConfig, mtWarning, [mbOK], 0);
        Exit;
      end;

      //Удаление старых *.ovpn
      if RunCommand('/bin/bash', ['-c', 'rm -f /etc/protonvpn/*.ovpn'], S) then
        //Распаковка без учета структуры архива
        if RunCommand('/bin/bash', ['-c', 'unzip -j -o "' +
          OpenDialog1.FileName + '" -d /etc/protonvpn/'], S) then
          FileListBox1.UpdateFileList;

      FileListBox1.ItemIndex := 0;
      FileLIstBox1.Click;

      RestartBtn.Enabled := True;
    end;
  except
    //Возврат индекса, позиция не выбрана
    XMLPropStorage1.WriteInteger('findex', -1);
  end;
end;

end.
