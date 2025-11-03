unit userscript;
const
  DRAUGRWEAPONS = $00000D14; // FomrID Listコピー参照用
  EDITORIDSUFFIX = '_RVSG';

var
  pluginName, formListPrefix: string;
  newPlugin: IwbFile;
  newFormListEditorIDs: TStringList;
  newFormListRecords: TList;

procedure AssignNPCToFormList(e, formListRecord: IwbMainRecord);
var
  formIDList, newFormList: IInterface;
  
begin
  formIDList := ElementByName(formListRecord, 'FormIDs');
  newFormList := ElementAssign(formIDList, HighInteger, nil, False);
  SetEditValue(newFormList, IntToHex(GetLoadOrderFormID(e), 8));
  if Assigned(newFormList) then
    AddMessage('Added FormList:' + EditorID(formListRecord));
end;


function Initialize: integer;
var
    i: integer;
    newFormList, entries, formIDs: IwbElement;
    baseFormList: IwbMainRecord;
begin
  Result := 0;
  newFormListEditorIDs := TStringList.Create;
  newFormListRecords := TList.Create;
  
  // ユーザーにファイル名を入力してもらう
  if not InputQuery('New Plugin name entry', 'Enter the Form List Plugin name (e.g. MyPlugin.esp)', pluginName) then
  begin
    AddMessage('Plugin name entry was canceled.');
    Result := 1;
    Exit;
  end;

  // ユーザーにForm Listのプレフィックスを入力してもらう
  if not InputQuery('Set Form List Prefix', 'Enter the Form List Prefix. Underscore(_) will be added.', formListPrefix) then
  begin
    AddMessage('Prefix entry was canceled.');
    Result := 1;
    Exit;
  end;
  
  // プレフィックスにアンダースコアを追加
  formListPrefix := formListPrefix + '_';
  
  // ファイル名の拡張子を確認し、必要に応じて追加
  if LowerCase(ExtractFileExt(pluginName)) <> '.esp' then
    pluginName := pluginName + '.esp';

  // 新しいプラグインを作成し、ESL フラグを設定
  newPlugin := AddNewFileName(pluginName, True);
  if not Assigned(newPlugin) then
  begin
    AddMessage('Failed to create plugin.');
    Result := 1;
    Exit;
  end;

  AddMessage('A new plugin has been created:' + pluginName);
  AddMasterIfMissing(newPlugin, 'Skyrim.esm');
  
  AddMessage('Form List Prefix:' + formListPrefix);
  
  // Editor ID のリストを初期化
  newFormListEditorIDs.Add('All' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('Male' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('Female' + EDITORIDSUFFIX);

  newFormListEditorIDs.Add('NordMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('NordFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('ImperialMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('ImperialFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('BretonMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('BretonFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('RedguardMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('RedguardFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('HighElfMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('HighElfFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('WoodElfMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('WoodElfFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('DarkElfMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('DarkElfFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('OrcMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('OrcFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('KhajiitMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('KhajiitFemale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('ArgonianMale' + EDITORIDSUFFIX);
  newFormListEditorIDs.Add('ArgonianFemale' + EDITORIDSUFFIX);

  // レコードを直接追加できないので、バニラのFormListレコードをコピー
  baseFormList := RecordByFormID(FileByIndex(0), DRAUGRWEAPONS, True);
  // 各 Editor ID に対して FormList を作成
  for i := 0 to newFormListEditorIDs.count - 1 do
  begin
    newFormList := wbCopyElementToFile(baseFormList, newPlugin, True, True);
    if not Assigned(newFormList) then
    begin
      AddMessage('Failed to create FormList:' + newFormListEditorIDs[i]);
      Continue;
    end;
    
    // 'FormIDs' サブレコードを取得、エントリがあれば削除
    entries := ElementByPath(newFormList, 'FormIDs');
    if Assigned(entries) then begin
      RemoveElement(newFormList, 'FormIDs');
      AddMessage('The FormList contents have been cleared.');
    end;
    // FormListのEditor IDを設定
    SetElementEditValues(newFormList, 'EDID', formListPrefix + newFormListEditorIDs[i]);
    // FormIDsエレメントを再設定
    entries := Add(newFormList, 'FormIDs', True);
    // 自動追加されるFormIDs #0を削除
    formIDs := ElementByIndex(entries, 0);
    RemoveElement(entries, formIDs);
    // レコード配列に追加したFormListレコードを格納
    newFormListRecords.Add(newFormList);
    AddMessage('Created FormList:' + EditorID(ObjectToElement(newFormListRecords[i])));
  end;

end;

function Process(e: IInterface): integer;
var
  race: IInterface;
  i, genderFlag, indxAll, indxGender, indxRaceGender: cardinal;
  NPCGender, raceString: string;
begin
  Result := 0;
  
  if Signature(e) <> 'NPC_' then begin
    AddMessage('This record is not an NPC record.');
    Exit;
  end;
  
  // レコードが所属するプラグインをマスター指定する
  AddMasterIfMissing(newPlugin, GetFileName(GetFile(e)));
  
  AddMessage('Record to operate on:' + EditorID(e));
  
  // 性別の取得
  genderFlag := GetElementNativeValues(e, 'ACBS\Flags');
  if (genderFlag and $1) = 0 then
    NPCGender := 'Male'
  else
    NPCGender := 'Female';
    
  // 種族の取得
  race := LinksTo(ElementByPath(e, 'RNAM'));
  raceString := EditorID(race);
  Delete(raceString, Length(raceString) - 3, 4);
  //AddMessage('raceString:' + raceString);
  
  // 基本種族以外は処理をスキップ
  if not ((raceString = 'Nord') or
      (raceString = 'Imperial') or
      (raceString = 'Breton') or
      (raceString = 'Redguard') or
      (raceString = 'HighEl') or
      (raceString = 'WoodElf') or
      (raceString = 'DarkElf') or
      (raceString = 'Orc') or
      (raceString = 'Khajiit') or
      (raceString = 'Argonian')) then begin
     AddMessage('Skip non-basic races');
     Exit;
  end;
  
  // EditorIDを基にFormListを取得（ newFormListRecords を先に対応づけ済み）
  // 共通: "All" は全員に割り当て
  indxAll := newFormListEditorIDs.IndexOf('All' + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(newFormListRecords[indxAll]));

  // 性別マッチ（Male/Femaleのみ)
  indxGender := newFormListEditorIDs.IndexOf(NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(newFormListRecords[indxGender]));

  // 種族+性別マッチ
  indxRaceGender := newFormListEditorIDs.IndexOf(raceString + NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(newFormListRecords[indxRaceGender]));

end;

function Finalize: integer;
begin
  Result := 0;
  
  if Assigned(newFormListEditorIDs) then
    newFormListEditorIDs.Free;
  if Assigned(newFormListRecords) then
    newFormListRecords.Free;
end;

end.
