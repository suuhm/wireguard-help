REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!
REM !!! EDIT THIS FILE FIRST !!!
REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!

@echo off

set EXTERN_IP=IP
set KEY=yourkey

echo Starting speederv2 as admin!
echo\
.\speederv2.exe -c -l 0.0.0.0:51821 -r 127.0.0.1:50001 -f20:20 --timeout 8 -k %KEY% 
