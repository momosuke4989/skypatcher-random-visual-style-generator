unit userscripts;

uses 'NPC Replacer Converter - Shared\NPCRC_CommonUtils';

const
  APPLYCHANCE = '99';

var
  // イニシャル処理で設定・使用する変数
  slRVSFactionName: TStringList;
  RVSGFileName: string;
  addRVS: boolean;
  
  // プロセス処理で設定する変数
  formListPrefix: string;

procedure AssignRVSExportString(const slRVSFactionName, prefix: string; var slExportString: TStringList);
var
  RVSOperation: string;
begin
  
  if addRVS = true then
    RVSOperation := 'add'
  else
    RVSOperation := 'set';
    
    slExportString.Add(';' + slRVSFactionName);
    slExportString.Add('filterByEditorIdContains=Enc, ' + slRVSFactionName + ':filterByEditorIdContainsExcluded=Template:restrictToGender=male:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Male_RVSG~' + APPLYCHANCE);

    slExportString.Add('filterByEditorIdContains=Enc, ' + slRVSFactionName + ':filterByEditorIdContainsExcluded=Template:restrictToGender=female:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Female_RVSG~' + APPLYCHANCE);
    
  
end;

function Initialize: integer;
var
  disableOpts: TStringList;
  checkBoxCaption: string;
  i: Integer;
begin
  Result := 0;
  slRVSFactionName   := TStringList.Create;
  
  RVSGFileName     := '';
  
  disableOpts      := TStringList.Create;

  slRVSFactionName.Add('Bandit=false');
  slRVSFactionName.Add('Warlock=false');
  slRVSFactionName.Add('Witch=false');
  slRVSFactionName.Add('Forsworn=false');
  slRVSFactionName.Add('GuardImperial=false');
  slRVSFactionName.Add('SoldierImperial=false');
  slRVSFactionName.Add('GuardSons=false');
  slRVSFactionName.Add('SoldierSons=false');
  slRVSFactionName.Add('VigilantOfStendarr=false');
  slRVSFactionName.Add('Dawnguard=false');
  slRVSFactionName.Add('Vampire=false');
  slRVSFactionName.Add('Hunter=false');
  slRVSFactionName.Add('Sailor=false');
  slRVSFactionName.Add('Thalmor=false');
  slRVSFactionName.Add('Alikr=false');
  slRVSFactionName.Add('Penitus=false');
  slRVSFactionName.Add('Afflicted=false');
  slRVSFactionName.Add('Cultist=false');
  
  checkBoxCaption := 'Target faction select';
  
  if MessageDlg(
    'Select which Random Visual Style Operation:' + #13#10 +
    'Yes = Add' + #13#10 +
    'No = Set',
    mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
    addRVS := true;
  
  // 各オプションの設定
  try
    if ShowCheckboxForm(slRVSFactionName, disableOpts, checkBoxCaption) then
    begin
      AddMessage('You selected:');
      for i := 0 to slRVSFactionName.Count - 1 do begin
        AddMessage(slRVSFactionName.Names[i] + ' - ' + slRVSFactionName.ValueFromIndex[i]);
      end;
    end
    else begin
      AddMessage('Selection was canceled.');
      Result := -1;
      Exit;
    end;
    
  finally
    disableOpts.Free;
  end;
  
end;

function Process(e: IInterface): integer;
var
  formListEditorID: string;
  i, underscorePos: cardinal;
begin
  Result := 0;
  underscorePos := 0;
  
  formListEditorID := '';
  
  // FormListレコードでなければスキップ
  if Signature(e) <> 'FLST' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not Form List record.');
    Exit;
  end;
  
  if RVSGFileName = '' then begin
    RVSGFileName := GetFileName(GetFile(e));
    RVSGFileName := ChangeFileExt(RVSGFileName, '');
  end;
  
  if formListPrefix = '' then begin
    formListEditorID := GetElementEditValues(e, 'EDID');
    underscorePos := Pos('_', formListEditorID);
    formListPrefix := Copy(formListEditorID, 1, underscorePos - 1);
  end;
  
  //AddMessage(RVSGFileName);
  //AddMessage(formListPrefix);
  
end;

function Finalize: integer;
var
  // 設定ファイル出力用変数
  slExport: TStringList;
  
  dlgSave: TSaveDialog;
  exportFileName, saveDir, filterString, fileExtension: string;
  RVSOperation: string;
  i: Cardinal;
begin
  Result := 0;
  
  if RVSGFileName = '' then begin
    AddMessage('The information required to generate a configuration file could not be obtained.');
    Exit;
  end;
  
  slExport         := TStringList.Create;
  
  if addRVS = true then
    RVSOperation := 'ADD - '
  else
    RVSOperation := 'SET - ';
  
  // 出力設定
  saveDir := DataPath + 'SkyPatcher Random Visual Style Generator\SKSE\Plugins\SkyPatcher\npc\SkyPatcher Random Visual Style Generator\';
  filterString := 'Ini (*.ini)|*.ini';
  fileExtension := '.ini';
    
  // ディレクトリ作成
  if not DirectoryExists(saveDir) then
    ForceDirectories(saveDir);
    
  dlgSave := TSaveDialog.Create(nil);
  try
    // ファイル保存
    dlgSave.Options := dlgSave.Options + [ofOverwritePrompt];
    dlgSave.Filter := filterString;
    dlgSave.InitialDir := saveDir;
    for i := 0 to slRVSFactionName.Count -1 do begin
      if GetBoolSLValue(slRVSFactionName.ValueFromIndex[i]) then begin
        slExport.Clear;
        AssignRVSExportString(slRVSFactionName.Names[i], formListPrefix, slExport);
        dlgSave.FileName := RVSOperation + RVSGFileName + ' - ' + slRVSFactionName.Names[i] + fileExtension;
        if dlgSave.Execute then begin
          exportFileName := dlgSave.FileName;
          AddMessage('Saving ' + exportFileName);
          slExport.SaveToFile(exportFileName);
        end;
      end;
    end;
  finally
    dlgSave.Free;
  end;
  if Assigned(slExport) then
    slExport.Free;
  if Assigned(slRVSFactionName) then
    slRVSFactionName.Free;
    
end;

end.
