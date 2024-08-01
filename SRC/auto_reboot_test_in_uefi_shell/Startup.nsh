#Startup.nsh, put this file in root dir of a media (cdrom-uefi-boot-img or USB)a
#Before test, you should clear the counter's value in UEFI shell
#  set felix 0
#You can change testcount, reboot interval 
#
echo -off
echo "COUNTER is %felix%"
set myFlag 0

#change max counter here: change 999999 to max test count
for %i run (%felix% 999999)
  if %felix% == %i then
    echo "[ %i ]"
    set myFlag 1
  else
    if %myFlag% == 1 then
      set felix %i
      echo "COUNTER is %felix%"
      goto Leave_For
    endif

  endif
endfor

:Leave_For
cls
echo "Auto reboot test v0.1, Felix, 20240731"
echo "Going to perform cold reboot after 60s;   counter is %felix%"
echo " "
echo "Ctrl-C to abort and return to UEFI Shell"

#sleep 60 sec
stall 60000000

#cold reboot
reset

#warm reboot
#reset -w

