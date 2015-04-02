program APMPresent;

uses
  VpSysLow,
  Os2Def,
  Os2Base;

var
  para          :
    packed record
      Command   :ULong;
    end;

  data          :
    packed record
      pAPMPresent:ULong;
    end;

  para_len,
  data_len      :longint;

  testcfg       :longint;

begin
  if SysFileOpen('TESTCFG$',
                 open_access_ReadOnly+open_share_DenyNone,
                 testcfg)<>0 then
    Halt(0);


  para.Command:=1;              // 0=Query bus architecture.
                                //         1=Query APM
  data.pAPMPresent:=0;

  para_len:=SizeOf(para);
  data_len:=SizeOf(data);

  if DosDevIOCtl(testcfg,
                 ioctl_TestCfg_Sys,testcfg_Sys_GetBusArch,
                 @para,para_len,@para_len,
                 @data,data_len,@data_len)<>0 then
    data.pAPMPresent:=0;

  SysFileClose(testcfg);

  WriteLn('APMPresent:',data.pAPMPresent);
  Halt(data.pAPMPresent);
end.
