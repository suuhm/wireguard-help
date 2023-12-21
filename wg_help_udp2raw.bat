REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!
REM !!! EDIT THIS FILE FIRST !!!
REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!

@echo off

set EXTERN_IP=IP
set KEY=yourkey

echo Starting UDP2RAW
echo\
.\udp2raw_mp.exe -c -l 0.0.0.0:50002 -r %EXTERN_IP%:443 -k %KEY% 
