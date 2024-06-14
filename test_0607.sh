# 정기점검
routineInspection(){

      hardwareCheck(){
      	tmsh show sys hardware
      }
      
      
      interfaceCheck(){
      	tmsh show net interface | grep up
      }
      
      dateCheck(){
      	date +'%Y-%m-%d %H:%M:%S'
      }

     # ntp delay가 0.000일 시 "ntp works abnormal" 출력
      ntpCheck(){
      	ntp=$(ntpq -np)
      	delay=$(echo $ntp | awk '{print $19}')
      	if [ "$delay" == "0.000" ]; then
      		echo "ntp works abnormal"
      	else
      		echo "ntp works normal"
      	fi
      	
      }
      
     # /var /var/log 에 대한 사용률 검사
      diskCheck(){
      	df -h /var /var/log | awk '{print $6"  "$5}'
      
      }
      
     # provisioned 되지 않은 부분 제외하여 process 검사
      processCheck(){
      	tmsh show sys service | grep -v "Not provisioned"
      }
      
     # 인증서 만료 기간 검사
      certificationExpirationCheck(){
      	tmsh list sys crypto cert |  grep -e sys -e expiration
      
      }
      
     # (asm 기준) asm, audit, ltm, tmm, messages 로그를 gz 압축 파일 포함하여 하나의 파일로 합침
     # 단, notice, info 로그 제외.
     # 그 후, 다시 gz로 압축
      combineLog(){
      	DATE=$(date +"%Y%m%d")
      	gzip -d /var/log/asm.*.gz /var/log/audit.*.gz /var/log/ltm.*.gz /var/log/tmm.*.gz /var/log/messages.*.gz
      	cat /var/log/asm.* /var/log/audit.* /var/log/ltm.* /var/log/tmm.* /var/log/messages.* |grep -v notice | grep -v info> /var/log/$DATE.log
      	echo "----------" >> /var/log/$DATE.log
      	gzip /var/log/asm.* /var/log/audit.* /var/log/ltm.* /var/log/tmm.* /var/log/messages.*
      }
      
      echo "------------------------interface-------------------------"
      echo "Name  Status  Bits   Bits Pkts   Pkts    Drops   Errs   Media"
      echo "                in    out   in    out                     "
      interfaceCheck
      echo "----------------------------------------------------------"
      
      echo "------------date------------"
      dateCheck
      echo "----------------------------"
      
      echo "------------ntp------------"
      ntpCheck
      echo "---------------------------"
      
      echo "------------disk------------"
      diskCheck
      echo "----------------------------"
      
      echo "------------process------------"
      processCheck
      echo "-------------------------------"
      
      echo "------------cert expiration------------"
      certificationExpirationCheck
      echo "---------------------------------------"
      
      echo "------------hardware------------"
      hardwareCheck
      echo "--------------------------------"
      
      todayDate=$(date +"%Y%m%d")
      echo "------------log------------"
      echo "Check /var/log/$todayDate.log"
      combineLog
      echo "---------------------------"
}

if [ $# -ne 1 ]; then
	echo "Input option"
	exit 1
fi

if [ "$1" == "-h" ]; then
	echo "This script is for routine inspection"
	echo "If you want to back up, use the ./script.sh -b option"
	echo "If you do not want to back up, use the -n option" 
	exit 0
fi

# backup 없는 점검
if [ "$1" == "-n" ]; then
	routineInspection
	exit 0
fi

# backup 포함한 점검
if [ "$1" == "-b" ]; then
	routineInspection
	tmsh save sys ucs /var/local/ucs/test_$todayDate.ucs
	exit 0
fi 




