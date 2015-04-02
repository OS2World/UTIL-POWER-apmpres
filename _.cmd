@echo off
call stampdef apmpres.def
call pasvpo apmpres .\

call stampdef acpipres.def
call pasvpo acpipres .\

if exist %tmp%\apmpres.arj del %tmp%\apmpres.arj
arj a %tmp%\apmpres.arj -_
