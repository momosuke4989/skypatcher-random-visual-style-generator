unit userscript;
const
  DRAUGRWEAPONS = $00000D14; // FomrID Listコピー参照用
  EDITORIDSUFFIX = '_RVSG';

var
  pluginName, formListPrefix: string;
  newPlugin: IwbFile;
  slNewFormListEditorIDs: TStringList;
  lNewFormListRecords: TList;

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
  slNewFormListEditorIDs := TStringList.Create;
  lNewFormListRecords := TList.Create;
  
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
  slNewFormListEditorIDs.Add('All' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('Male' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('Female' + EDITORIDSUFFIX);

  slNewFormListEditorIDs.Add('NordMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('NordFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('ImperialMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('ImperialFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('BretonMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('BretonFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('RedguardMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('RedguardFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('HighElfMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('HighElfFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('WoodElfMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('WoodElfFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('DarkElfMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('DarkElfFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('OrcMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('OrcFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('KhajiitMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('KhajiitFemale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('ArgonianMale' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add('ArgonianFemale' + EDITORIDSUFFIX);

  // レコードを直接追加できないので、バニラのFormListレコードをコピー
  baseFormList := RecordByFormID(FileByIndex(0), DRAUGRWEAPONS, True);
  // 各 Editor ID に対して FormList を作成
  for i := 0 to slNewFormListEditorIDs.count - 1 do
  begin
    newFormList := wbCopyElementToFile(baseFormList, newPlugin, True, True);
    if not Assigned(newFormList) then
    begin
      AddMessage('Failed to create FormList:' + slNewFormListEditorIDs[i]);
      Continue;
    end;
    
    // 'FormIDs' サブレコードを取得、エントリがあれば削除
    entries := ElementByPath(newFormList, 'FormIDs');
    if Assigned(entries) then begin
      RemoveElement(newFormList, 'FormIDs');
      AddMessage('The FormList contents have been cleared.');
    end;
    // FormListのEditor IDを設定
    SetElementEditValues(newFormList, 'EDID', formListPrefix + slNewFormListEditorIDs[i]);
    // FormIDsエレメントを再設定
    entries := Add(newFormList, 'FormIDs', True);
    // 自動追加されるFormIDs #0を削除
    formIDs := ElementByIndex(entries, 0);
    RemoveElement(entries, formIDs);
    // レコード配列に追加したFormListレコードを格納
    lNewFormListRecords.Add(newFormList);
    AddMessage('Created FormList:' + EditorID(ObjectToElement(lNewFormListRecords[i])));
  end;

end;

function Process(e: IInterface): integer;
var
  race: IInterface;
  i, recordFlag, genderFlag, indxAll, indxGender, indxRaceGender: cardinal;
  NPCGender, raceString: string;
begin
  Result := 0;
  
  // NPCレコード以外のレコードはスキップ
  if Signature(e) <> 'NPC_' then begin
    AddMessage('This record is not an NPC record.');
    Exit;
  end;
  
  AddMessage('Record to operate on:' + EditorID(e));
  
  // レコードが所属するプラグインをマスター指定する
  AddMasterIfMissing(newPlugin, GetFileName(GetFile(e)));
  
  // UseTraitsテンプレートフラグを持つNPCはスキップ
  recordFlag := GetElementNativeValues(ElementBySignature(e, 'ACBS'), 'Template Flags');
  if (recordFlag and $01) <> 0 then begin
    AddMessage('This record uses a template and has the Use Traits flag,');
    AddMessage('Skip the processing record.');
    Exit;
  end;
  
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
      (raceString = 'HighElf') or
      (raceString = 'WoodElf') or
      (raceString = 'DarkElf') or
      (raceString = 'Orc') or
      (raceString = 'Khajiit') or
      (raceString = 'Argonian')) then begin
     AddMessage('Skip non-basic races');
     Exit;
  end;
  
  // EditorIDを基にFormListを取得（ lNewFormListRecords を先に対応づけ済み）
  // 共通: "All" は全員に割り当て
  indxAll := slNewFormListEditorIDs.IndexOf('All' + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxAll]));

  // 性別マッチ（Male/Femaleのみ)
  indxGender := slNewFormListEditorIDs.IndexOf(NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxGender]));

  // 種族+性別マッチ
  indxRaceGender := slNewFormListEditorIDs.IndexOf(raceString + NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxRaceGender]));

end;

function Finalize: integer;
begin
  Result := 0;
  
  if Assigned(slNewFormListEditorIDs) then
    slNewFormListEditorIDs.Free;
  if Assigned(lNewFormListRecords) then
    lNewFormListRecords.Free;
end;

end.
