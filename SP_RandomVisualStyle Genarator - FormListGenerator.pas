unit userscript;
const
  DRAUGRWEAPONS = $00000D14; // FomrID Listコピー参照用
  EDITORIDSUFFIX = '_RVSG';

var
  pluginName, formListPrefix: string;
  newPlugin: IwbFile;
  slNewFormListEditorIDs, slBasicRaces, slExcludeRaces: TStringList;
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

function GetRaceFaceGenHeadFlag(raceRecord: IInterface): Boolean;
var
  flags: cardinal;
begin
  // DATA\Flags を取得
  flags := GetElementNativeValues(raceRecord, 'DATA\Flags');

  // "FaceGen Head" フラグが ON かどうかを返す
  if (flags and $02) = 2 then
    Result := true
  else
    Result := false;
end;

function Initialize: integer;
var
    i: integer;
    newFormList, entries, formIDs: IwbElement;
    baseFormList: IwbMainRecord;
begin
  Result := 0;
  slNewFormListEditorIDs := TStringList.Create;
  slBasicRaces := TStringList.Create;
  slExcludeRaces := TStringList.Create;
  lNewFormListRecords := TList.Create;
  
  slBasicRaces.Add('Nord');
  slBasicRaces.Add('Imperial');
  slBasicRaces.Add('Breton');
  slBasicRaces.Add('Redguard');
  slBasicRaces.Add('HighElf');
  slBasicRaces.Add('WoodElf');
  slBasicRaces.Add('DarkElf');
  slBasicRaces.Add('Orc');
  slBasicRaces.Add('Khajiit');
  slBasicRaces.Add('Argonian');
  
  slExcludeRaces.Add('DefaultRace');
  slExcludeRaces.Add('InvisibleRace');
  slExcludeRaces.Add('ManekinRace');
  slExcludeRaces.Add('TestRace');
  slExcludeRaces.Add('DLC1NordRace');
  slExcludeRaces.Add('NordRaceAstrid');  // 正常に機能すると思うが見た目がホラーなので
  slExcludeRaces.Add('DoremoraRace');  // 多分追加しても問題ないがとりあえず除外指定
  
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
  // 全員および性別
  slNewFormListEditorIDs.Add(formListPrefix + 'All' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add(formListPrefix + 'Male' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add(formListPrefix + 'Female' + EDITORIDSUFFIX);

  // 基本種族
  for i := 0 to slBasicRaces.Count - 1 do begin
    slNewFormListEditorIDs.Add(formListPrefix + slBasicRaces[i] + 'Male' + EDITORIDSUFFIX);
    slNewFormListEditorIDs.Add(formListPrefix + slBasicRaces[i] + 'Female' + EDITORIDSUFFIX);
  end;
  
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
    SetElementEditValues(newFormList, 'EDID', slNewFormListEditorIDs[i]);
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
  raceRecord: IInterface;
  i, templateFlag, NPCFlag, indxAll, indxGender, indxRaceGender: cardinal;
  NPCGender, raceString: string;
  raceFaceGenHeadFlag: boolean;
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
  
  // NPCレコードフラグを取得
  NPCFlag := GetElementNativeValues(e, 'ACBS\Flags');
  templateFlag := GetElementNativeValues(ElementBySignature(e, 'ACBS'), 'Template Flags');
  
  // UseTraitsテンプレートフラグを持つNPCはスキップ
  if (templateFlag and $01) <> 0 then begin
    AddMessage('This record uses a template and has the Use Traits flag.');
    AddMessage('Skip the processing record.');
    Exit;
  end;
  
  // Editor IDにTemplateを含むNPCはスキップ
  if Pos('template', LowerCase(EditorID(e))) > 0 then begin
    AddMessage('This record is a NPC template.');
    AddMessage('Skip the processing record.');
    Exit;
  end;
  
  // playerレコードはスキップ
  if Pos('player', LowerCase(EditorID(e))) > 0 then begin
    AddMessage('This record is player.');
    AddMessage('Skip the processing record.');
    Exit;
  end;
  
  // CharGen Presetはスキップ
  if (NPCFlag and $4) = 4 then begin
    AddMessage('This record is a CharGen Prest.');
    AddMessage('Skip the processing record.');
    Exit;
  end;
  
  
  // 種族の取得
  raceRecord := LinksTo(ElementByPath(e, 'RNAM'));
  raceString := EditorID(raceRecord);
  
  // FaceGenHeadフラグを持たない種族はスキップ
  if not GetRaceFaceGenHeadFlag(raceRecord) then begin
    AddMessage(raceString + ' doesn''t have FaceGen Head Flag. Skip processing.');
    Exit;
  end;
  
  //AddMessage(raceString + ' has FaceGen Head Flag. Continue processing.');
  
  // 種族名からRace部分を取り除く
  Delete(raceString, Length(raceString) - 3, 4);
  //AddMessage('raceString:' + raceString);
  
  // 性別の判定
  if (NPCFlag and $1) = 0 then
    NPCGender := 'Male'
  else
    NPCGender := 'Female';
  
  // 除外種族は処理をスキップ
  if slExcludeRaces.IndexOf(raceString) <> -1 then begin
    AddMessage('Skip exclude races');
    Exit;
  end;
  
  // 基本種族以外は処理をスキップ
  if slBasicRaces.IndexOf(raceString) = -1 then begin
    AddMessage('Skip non-basic races');
    Exit;
  end;
  
  // EditorIDを基にFormListを取得（ lNewFormListRecords を先に対応づけ済み）
  // 共通: "All" は全員に割り当て
  indxAll := slNewFormListEditorIDs.IndexOf(formListPrefix + 'All' + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxAll]));

  // 性別マッチ（Male/Femaleのみ)
  indxGender := slNewFormListEditorIDs.IndexOf(formListPrefix + NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxGender]));

  // 種族+性別マッチ
  indxRaceGender := slNewFormListEditorIDs.IndexOf(formListPrefix + raceString + NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxRaceGender]));

end;

function Finalize: integer;
begin
  Result := 0;
  
  if Assigned(slNewFormListEditorIDs) then
    slNewFormListEditorIDs.Free;
  if Assigned(slBasicRaces) then
    slBasicRaces.Free;
  if Assigned(slExcludeRaces) then
    slExcludeRaces.Free;
  if Assigned(lNewFormListRecords) then
    lNewFormListRecords.Free;
end;

end.
