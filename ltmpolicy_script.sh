#!/bin/bash

if [ "$1" == "-h" ]; then
    echo "New Domain to forward ./forward_policy [Domain] [Destination FQDN] [VS's IP] [VS's Port]"
    echo "If you want to delete domain, forward ./forward_policy [-d] [Domain] [VS's IP] [VS's Port]"
    echo "WAF policy with the domain name will be created automatically. please notice."
    exit 0
fi



# ip와 port를 통해 ltm policy 찾기
findingLTMPolicy(){
		# tmsh로 vs 조회 시 port number가 아닌 port name으로 표기되기 때문. ex) d="3.3.3.3:https"
		# 이는 tmsh modify cli global-settings service number 명령어로 포트 번호가 나오도록 수정 가능
		portNum="$2"
		portNumTCP="$2/tcp"
		portName=$(awk -v p=$portNumTCP '$2 == p {print $1}' /etc/services)
		if [ -z "$portName" ]; then
			d="$1:$portNum"
		else
			d="$1:$portName"
		fi
		# 해당 vs의 config를 한 줄로 저장
        vs=$(tmsh list ltm virtual \* one-line |grep -w $d)
		
		
		# vs가 없을 시 해당 문구 출력
        if [ -z "$vs" ]; then
                        echo "check ip and port"
                        exit 0
        fi	

		# 해당 문구의 단어 개수 저장 (policies를 찾기 위해 단어만큼 반복문 돌리기 위함)
        wordCount=$(echo "$vs" | wc -w)	
		
		# policies { } 에 있는 ltm policy 저장.
		ltmPolicyName=$(echo $vs | awk -v w=$wordCount '{
							j=1;
							c=0;
							left=0;
							right=0;
							ltmPolicyList="";
							for(i=1; i<=w-1; i++)
								{if($i=="policies")
									do {
										if($(i+j)=="{") left++;
										else if($(i+j)=="}") right++;
										else {
											ltmPolicyList=(ltmPolicyList$(i+j));
												c++;
										}
										j++;
										} while (left!=right)
								}
							if(ltmPolicyList=="")
								{print left}
							else if(c>1) {print "no"}
							else
								{print ltmPolicyList}
						}')
			
		# policies가 없을 시 해당 문구 출력
  
  		# 권혁진 수정 권고
    		# virtualServer=(echo "$vs" | cut -d ' ' -f 3)
		# ltmPolicyList=(tmsh list ltm virtual $virtualServer policies |grep policies | cut -d ' ' -f 6)
		# 참고용
    
        if [ "$ltmPolicyName" == "$wordCount" ]; then
			echo "No LTM Policy"
			exit 0
		# policies가 2개 이상일 시 해당 문구 출력
		elif [ "$ltmPolicyName" == "no" ]; then
			echo "there are ltm policies more than one"
			exit 0
        fi	
}



# 첫 번째 인수가 -d 일 때를 삭제 옵션으로 설정
if [ "$1" == "-d" ]; then

        if [ $# -ne 4 ]; then
                echo "please type forward_policy [-d] [Domain] [VS's IP] [VS's Port]"
                exit 1
        fi
		
		# ltm policy 찾기
        findingLTMPolicy $3 $4
		
		# 찾은 ltm policy에서 해당 도메인 삭제 후 저장
        echo "Deleting routing..."
        tmsh modify ltm policy $ltmPolicyName create-draft
        tmsh modify ltm policy Drafts/$ltmPolicyName rules delete { $2 }
        tmsh publish ltm policy /Common/Drafts/$ltmPolicyName
        tmsh save sys config

        echo "It's completed!"
        exit 0


fi

# 인수가 4개가 아닐 시 해당 문구 출력
if [ $# -ne 4 ]; then
    echo "please type forward_policy [Domain] [Destination FQDN] [VS's IP] [VS'S Port]"
    exit 1
fi



# ltm policy 찾기
findingLTMPolicy $3 $4


# 해당 ltm policy에서 rule 수정
echo "LTM Policy's name is $ltmPolicyName"

echo "Creating ASM policy..."
tmsh create asm policy $1 blocking-mode disabled encoding none policy-type security policy-builder disabled active

echo "Creating node..."
tmsh create ltm node $2 fqdn { autopopulate enabled name $2 }

echo "Creating pool..."
tmsh create ltm pool $1 members add { $2:0 }

tmsh modify ltm policy $ltmPolicyName create-draft

tmsh modify ltm policy Drafts/$ltmPolicyName rules add { $1 { conditions add { 0 { http-host host values { $1 } } } actions add { 0 { asm enable policy /Common/$1 } 1 { forward select pool $1 } } } }

# 수정 후 GUI에서 직접 default rule을 최하단 규칙으로 변경 후 저장하라는 문구
echo "It is completed!"
echo "Please save and publish the policy."
