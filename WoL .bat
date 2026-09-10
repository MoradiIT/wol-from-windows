@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM ==== CONFIG ====
set PC_IP=192.168.1.XX
set BROADCAST_IP=192.168.XX.255
set MAC=AA-BB-CC-00-11-22
REM ================

set "PS1=%temp%\wol_%random%.ps1"

echo Checking if %PC_IP% is already on...
ping -n 3 -w 100 %PC_IP% | find "TTL=" >nul
if %errorlevel%==0 (
    echo ✔ PC is on now.
    goto :end
) else (
    echo ❌ PC is off, initiating WoL.
)

echo.
echo ✅ Sent WoL magic packet to %MAC% via %BROADCAST_IP%...

> "%PS1%" echo $mac = '%MAC%' -replace '[:-]', ''
>>"%PS1%" echo $macBytes = for ($i=0; $i -lt 12; $i+=2) { [byte][convert]::ToInt32($mac.Substring($i,2),16) }
>>"%PS1%" echo $header = [byte[]](255,255,255,255,255,255)
>>"%PS1%" echo $packet = $header + ($macBytes * 16)
>>"%PS1%" echo $udp = New-Object System.Net.Sockets.UdpClient
>>"%PS1%" echo $udp.EnableBroadcast = $true
>>"%PS1%" echo $udp.Connect([Net.IPAddress]::Parse('%BROADCAST_IP%'), 9)
>>"%PS1%" echo $udp.Send($packet, $packet.Length) ^| Out-Null
>>"%PS1%" echo $udp.Close()

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
del "%PS1%" >nul 2>&1

echo The WoL message is sent.
echo.
echo ⏳ pinging the PC to check whether it is ready:
echo.

echo Waiting for %PC_IP% to respond (checking every 5 seconds, max 25 tries)...
set /a tries=0
:waitloop
set /a tries+=1
ping -n 1 -w 1000 %PC_IP% | find "TTL=" >nul
if !errorlevel! equ 0 (
    echo ✔ PC has powered on and is responding.
    powershell -NoProfile -Command "[console]::beep(1000,700)"
    goto :end
)
if !tries! geq 25 (
    echo [❌] Gave up after 50 tries ^(2 min^). PC may be unplugged.
    goto :end
)
echo  Still off, retrying in 5s... ^(!tries!/25^)
timeout /t 5 >nul
goto :waitloop

:end
pause