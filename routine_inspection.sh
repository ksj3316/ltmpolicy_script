

hardwareCheck(){
	echo "------------hardware------------"
	tmsh show sys hardware
	echo "--------------------------------"
}


interfaceCheck(){
	
	echo "------------------------interface-------------------------"
	echo "Name  Status  Bits   Bits Pkts   Pkts    Drops   Errs   Media"
	echo "                in    out   in    out                     "
	tmsh show net interface | grep up
	echo "----------------------------------------------------------"
}

dateCheck(){
	echo "------------date------------"
	date +'%Y-%m-%d %H:%M:%S'
	echo "----------------------------"
	
}


# ntp delay가 0.000일 시 "ntp works abnormal" 출력
ntpCheck(){
	echo "------------ntp------------"
	ntp=$(ntpq -np)
	delay=$(echo $ntp | awk '{print $19}')
	if [ "$delay" == "0.000" ]; then
		echo "ntp works abnormal"
	else
		echo "ntp works normal"
	fi
	echo "---------------------------"
}


# /var, /var/log 디렉토리 사용률 확인
diskCheck(){
	echo "------------disk------------"
	df -h /var /var/log | awk '{print $6"  "$5}'
	echo "----------------------------"
}


# provision 되지 않은 process 제외하여 확인
processCheck(){
	echo "------------process------------"
	tmsh show sys service | grep -v "Not provisioned"
	echo "-------------------------------"
}


# 인증서 만료 날짜 확인
certificationExpirationCheck(){
	echo "------------cert expiration------------"
	tmsh list sys crypto cert |  grep -e sys -e expiration
	echo "---------------------------------------"
}

# 로그를 수집 (gz 압축 해제 파일 포함) 하여 하나의 log 파일로 집합
# notice, info 로그는 제외
# 해제한 gz파일 재 압축
combineLog(){
	echo "------------log------------"
	todayDate=$(date +"%Y%m%d")
	gzip -d /var/log/asm.*.gz /var/log/audit.*.gz /var/log/ltm.*.gz /var/log/tmm.*.gz /var/log/messages.*.gz
	cat /var/log/asm.* /var/log/audit.* /var/log/ltm.* /var/log/tmm.* /var/log/messages.* |grep -v notice | grep -v info> /var/log/$todayDate.log
	echo "----------" >> /var/log/$todayDate.log
	gzip /var/log/asm.* /var/log/audit.* /var/log/ltm.* /var/log/tmm.* /var/log/messages.*
	echo "Check /var/log/$todayDate.log"
	echo "---------------------------"
}


# ucs파일 /var/local/ucs 디렉토리에 저장
backupUCS(){
	todayDate=$(date +"%Y%m%d")
	tmsh save sys ucs /var/local/ucs/test_$todayDate.ucs
}


if [ $# -ne 1 ]; then
	echo "Input option"
	exit 1
fi

# --help 옵션
if [ "$1" == "-h" ]; then
	echo "This script is for routine inspection"
	echo "If you want to back up, use the ./script.sh -b option"
	echo "If you do not want to back up, use the -n option" 
	exit 0
fi

# backup 없는 점검
if [ "$1" == "-n" ]; then
	hardwareCheck
	interfaceCheck
	dateCheck
	ntpCheck
	diskCheck
	processCheck
	certificationExpirationCheck
	combineLog
	exit 0
fi

# backup 포함한 점검
if [ "$1" == "-b" ]; then
	hardwareCheck
	interfaceCheck
	dateCheck
	ntpCheck
	diskCheck
	processCheck
	certificationExpirationCheck
	combineLog
	backupUCS
	exit 0
fi 




