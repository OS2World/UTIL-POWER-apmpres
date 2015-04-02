{&Use32+} {$M 256000} {$S+} {$R-}
program ACPIPresent;

(* ACPI BIOS presence checker - returns with exitcode   *)
(*   0  ACPI not present                                *)
(*   1  ACPI present                                    *)
(* else other error                                     *)
(*                                                      *)
(* Veit Kannegieser 2005.09.19                          *)


uses
  Os2Def,
  Os2Base,
  Strings;

type
  ACPI_Root_System_Description_Pointer_structure=
    packed record
      signature_RSD_PTR :array[1..8] of char;
      checksum          :byte;
      OEM_identifier    :array[1..6] of char;
      reserved          :byte;
      physical_address_of_Root_System_Description_Table:longint;
    end;

procedure copy_phys_memory(var target;const phys_address,length:longint);

  var
    hand,
    action,
    rc                  :longint;

    ParmRec1:
      record            // Input parameter record
        phys32          :longint;
        laenge          :smallword;
      end;

    ParmRec2:
      record
        sel             :smallword;
      end;

    ParmLen             : ULong;  // Parameter length in bytes
    DataLen             : ULong;  // Data length in bytes
    Data1:
      record
        sel             :smallword;
      end;

  begin
    FillChar(target,length,0);

    if DosOpen('SCREEN$',hand,action,0,0,1,$40,nil)<>0 then
      Exit;

    ParmLen:=SizeOf(ParmRec1);

    with ParmRec1 do
      begin
        phys32:=phys_address and $fffff000;
        laenge:=((phys_address and $00000fff)+length) and $ffff;
      end;

    datalen:=SizeOf(data1);
    rc:=DosDevIOCtl(
            hand,                       // Handle to device
            IOCTL_SCR_AND_PTRDRAW,      // Category of request
            SCR_ALLOCLDT,               // Function being requested
            @ParmRec1,                  // Input/Output parameter list
            ParmLen,                    // Maximum output parameter size
            @ParmLen,                   // Input:  size of parameter list
                                        // Output: size of parameters returned
            @Data1,                     // Input/Output data area
            Datalen,                    // Maximum output data size
            @DataLen);                  // Input:  size of input data area
    if rc=0 then
      begin

        asm {&Saves None}
          push gs

            mov esi,[phys_address]
            and esi,$00000fff
            mov gs,data1.sel

            mov edi,[target]
            mov ecx,[length]
            cld
          @l1:
            mov al,gs:[esi]
            inc esi
            stosb
            loop @l1

          pop gs
        end;

        ParmLen:=SizeOf(ParmRec2);

        with ParmRec2 do
          begin
            sel:=data1.sel;
          end;

        DataLen:=0;
        rc:=DosDevIOCtl(
                hand,                           // Handle to device
                IOCTL_SCR_AND_PTRDRAW,          // Category of request
                SCR_DEALLOCLDT,                 // Function being requested
                @ParmRec2,                      // Input/Output parameter list
                ParmLen,                        // Maximum output parameter size
                @ParmLen,                       // Input:  size of parameter list
                                                // Output: size of parameters returned
                nil,                            // Input/Output data area
                Datalen,                        // Maximum output data size
                @DataLen);                      // Input:  size of input data area

      end;

    DosClose(hand);
  end;

function search_acpi(phys_address,size:longint):boolean;
  var
    buf64k              :array[0..$ffff] of byte;
    i,j,
    now                 :longint;
    sum                 :byte;
  begin
    search_acpi:=false;
    while size>0 do
      begin
        now:=size;
        if now>SizeOf(buf64k) then
          now:=SizeOf(buf64k);

        copy_phys_memory(buf64k,phys_address,now);

        i:=0;
        while i<now do
          with ACPI_Root_System_Description_Pointer_structure(buf64k[i]) do
            begin
              if  (StrLComp(@signature_RSD_PTR,'RSD PTR ',Length('RSD PTR '))=0)
              and (physical_address_of_Root_System_Description_Table<>0) then
                begin

                  sum:=0;
                  for j:=i to i+SizeOf(ACPI_Root_System_Description_Pointer_structure)-1 do
                    Inc(sum,buf64k[j]);
                  if sum=0 then
                    begin
                      search_acpi:=true; (* present *)
                      Break;
                    end;
                end;

              Inc(i,$10);
            end;

        Inc(phys_address,now);
        Dec(size        ,now);
      end;
  end;


var
  m640                  :Smallword;
  xbda                  :SmallWord;
  found                 :boolean;


begin
  copy_phys_memory(m640,$00000413,SizeOf(m640));
  copy_phys_memory(xbda,$00000417,SizeOf(xbda));

  found:=false;

  (* Search last KB of memory *)
  if m640<640 then
    found:=search_acpi(1024*m640,1024*(640-m640));

  (* Search extended BIOS data area *)
  if (not found) and (xbda<>0) then
    found:=search_acpi(16*xbda,1024);

  (* Search E000:0000..F000:FFE0 BIOS range *)
  if (not found) then
    found:=search_acpi($00e0000,$1ffe0);


  WriteLn('ACPIPresent:',Ord(found));
  Halt(Ord(found));
end.

