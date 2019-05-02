#!/bin/bash
cd /


###### Verify only Root Can Execute.
if [ $EUID -ne 0 ]; then
   echo "   This script must be run as root

   exit code 1"
   exit 1
fi






#### Verify Only Single Instance of this script gets executed.
LOCATION=~/project/
LOCKFILE=/tmp/.ids_lock.txt
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "$0 instance already running"
    exit
fi
# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}



file_init=/tmp/common_init.txt
file_latest=/tmp/common_latest.txt



create_files()
{
cd ~/
mkdir -p project
sleep 1
mkdir -p project/dir1
sleep 1
mkdir -p project/dir2
sleep 1
echo 'Text file 1'> project/file1.txt
echo 'Text file 20'> project/file2.txt
echo 'Text file 300'> project/file3.txt
echo 'Text file 4000'> project/file4.txt
echo 'Text file 50000'> project/file5.txt; sleep 1
echo 'Text file 600000'> project/dir1/file6.txt
echo 'Text file 7000000'> project/dir2/file7.txt; sleep 1


echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Files and Directories created successfully ...\n|"
sleep 1
}

function_files_check()
{
cd $LOCATION
cp /dev/null  $file_latest

echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Scanning Regular Files ...\n|"

for i in `ls $LOCATION/  ` ;
do
        find $i -type f  -printf "%TY-%Tm-%Td %TT,%s,f,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_latest;
done




echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Scanning Directories ...\n|"

for i in `ls $LOCATION/ ` ;
do
        find $i -type d  -printf "%TY-%Tm-%Td %TT,%s,d,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_latest;
done

echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Scanning Symbolic Links ...\n|"

for i in `ls $LOCATION/ ` ;
do
        find $i -type l  -printf "%TY-%Tm-%Td %TT,%s,l,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_latest;
done


echo "+----------------------------------------------------------------------------------------------+"
cat $file_latest | grep ",f," |wc -l| awk '{printf "|\t\t\tTotal Regular Files \t\t= \t %s\t\t\t\n",$1}'
cat $file_latest | grep ",d," |wc -l| awk '{printf "|\t\t\tTotal Directories / Folders \t= \t %s\t\t\t\n",$1}'
cat $file_latest | grep ",l," |wc -l| awk '{printf "|\t\t\tTotal Symbolic Links \t\t= \t %s\t\t\t\n",$1}'
echo "+----------------------------------------------------------------------------------------------+"

echo -e "|\n|\n|\n|\t\t Scanning Completed ...\n|\n|"
sleep 1;

# Calling the Verify Function
function_verify
}





function_modification_verify()
{

main_file=$1

cat $main_file|grep '<'|cut -d, -f1-3| while read line
do
        OFILENAME=$(cat $file_init | grep "$line"| cut -d, -f4)
        OTYPE=$(cat $file_init | grep "$line"| cut -d, -f3 |sed "s|f|FILE|g"|sed "s|d|DIRECTORY|g"|sed "s|l|SYMBOLIC_LINK|g")
        echo -e "|\t\t Deleted\t\t$OTYPE: \t\t  $OFILENAME"

done

cat $main_file|grep '>'|cut -d'>' -f2|tr -d '\t'|cut -d, -f1-3| while read line
do
        nFILENAME=$(cat $file_latest | grep "$line"| cut -d, -f4)
        nTYPE=$(cat $file_latest | grep "$line"| cut -d, -f3|sed "s|f|FILE|g"|sed "s|d|DIRECTORY|g"|sed "s|l|SYMBOLIC_LINK|g" )
        echo -e "|\t\t Created\t\t$nTYPE: \t\t  $nFILENAME"

done



cat $main_file|grep '|'| cut -d'|' -f2 |tr -d "\t"|cut -d, -f1-3| while read line
do
        nFILENAME=$(cat $file_latest | grep "$line"| cut -d, -f4)
        nMTIME=$(cat $file_latest | grep "$line"| cut -d, -f1 )
        nSIZE=$(cat $file_latest | grep "$line"| cut -d, -f2 )
        nTYPE=$(cat $file_latest | grep "$line"| cut -d, -f3|sed "s|f|FILE|g"|sed "s|d|DIRECTORY|g"|sed "s|l|SYMBOLIC_LINK|g" )
        nUID=$(cat $file_latest | grep "$line"| cut -d, -f5 )
        nGID=$(cat $file_latest | grep "$line"| cut -d, -f6 )
        nMODE=$(cat $file_latest | grep "$line"| cut -d, -f7 )

        echo -e "|\t\t Modified\t\t$nTYPE: \t\t  $nFILENAME"
done
}











function_verify()
{
cd /tmp

rm -rf /tmp/file_exception.txt /tmp/dir_exception.txt  /tmp/link_exception.txt 2>/dev/null 1>/dev/null



cp /dev/null /tmp/change.txt
cat $file_latest |  cut -d, -f4|while read line
do
stat $line| grep Change: |cut -d'+' -f1|cut -d':' -f2-4|sed "s|^ ||g" >> /tmp/change.txt
done

paste -d, $file_latest /tmp/change.txt > 1.txt
mv 1.txt $file_latest
rm -rf /tmp/change.txt


echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Verifying Regular Files ...\n|"




cat $file_init | grep ",f,"  > /tmp/file1.txt
cat $file_latest | grep ",f,"  > /tmp/file2.txt

sdiff -s /tmp/file1.txt /tmp/file2.txt | grep ",f,"  2>/dev/null 1>/dev/null
if [[ $? -eq 1 ]]; then
        echo -e "|\t\t No Changes Found For Regular Files.\n|";
else
        sdiff -s /tmp/file1.txt /tmp/file2.txt | grep ",f," > /tmp/file_exception.txt
        function_modification_verify /tmp/file_exception.txt
fi

rm -rf /tmp/file2.txt /tmp/file1.txt 2>/dev/null




echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Verifying Directories ...\n|"
sleep 1

cat $file_init | grep ",d,"  > /tmp/dir1.txt
cat $file_latest | grep ",d,"  > /tmp/dir2.txt
sdiff -s /tmp/dir1.txt /tmp/dir2.txt  | grep ",d," 2>/dev/null 1>/dev/null
if [[ $? -eq 1 ]]; then
        echo -e "|\t\t No Changes Found For Directories.\n|";
else
        echo -e "|\t\t Modification Found For Directories.\n|";
        sdiff -s /tmp/dir1.txt /tmp/dir2.txt  | grep ",d," > /tmp/dir_exception.txt
        function_modification_verify /tmp/dir_exception.txt
fi
rm -rf /tmp/dir2.txt /tmp/dir1.txt 2>/dev/null




echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Verifying Symbolic Links ...\n|"
sleep 1
cat $file_init | grep ",l,"  > /tmp/link1.txt
cat $file_latest | grep ",l,"  > /tmp/link2.txt
sdiff -s /tmp/link1.txt  /tmp/link2.txt | grep ",l," 2>/dev/null 1>/dev/null
if [[ $? -eq 1 ]]; then
        echo -e "|\t\t No Changes Found For Symbolic Links.\n|";
else
        echo -e "|\t\t Modification Found For Symbolic Links.\n|";
        sdiff -s /tmp/link1.txt  /tmp/link2.txt| grep ",l," > /tmp/link_exception.txt
        function_modification_verify /tmp/link_exception.txt
fi
rm -rf /tmp/link2.txt /tmp/link1.txt /tmp/file_exception.txt /tmp/link_exception.txt /tmp/dir_exception.txt  2>/dev/null

echo -e "|\n+---------------------------------------------------------------+"
}






delete_old()
{

rm -rf $LOCATION $file_init $file_latest   2>/dev/null


}

collect_checksum()
{

cd $LOCATION && find $LOCATION -type f -exec sha1sum {} \; |awk '{print $2, $1}'|sort -r > /tmp/checksum.sha1
}

collect_details()
{

cp -p /dev/null $file_init


for i in `ls $LOCATION/  ` ;
do
        find $i -type f  -printf "%TY-%Tm-%Td %TT,%s,f,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_init;
done



for i in `ls $LOCATION/  ` ;
do
        find $i -type d  -printf "%TY-%Tm-%Td %TT,%s,d,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_init;
done



for i in `ls $LOCATION/  ` ;
do
        find $i -type l  -printf "%TY-%Tm-%Td %TT,%s,l,${LOCATION}%p,%u,%g,%M\n" | sort -r >> $file_init;
done


}

merge_details()
{


cp /dev/null /tmp/change.txt
cat $file_init |  cut -d, -f4|while read line
do
stat $line| grep Change: |cut -d'+' -f1|cut -d':' -f2-4|sed "s|^ ||g" >> /tmp/change.txt
done

paste -d, $file_init /tmp/change.txt > 1.txt
mv 1.txt $file_init
rm -rf /tmp/change.txt




echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t Verification files created.\n|\n|+---------------------------------------------------------------+"
}


if [[ "$1" == init ]]
then
        function_files_init
fi


random_change()
{
START=1
END=$(cat $file_init|wc -l)
DIFF=$(($END-$START+1))
RANDOM=$$

for i in `seq 3`
do
        R=$(($(($RANDOM%$DIFF))+$START))
        SOURCE=$(cat $file_init | head -$R| tail -1|cut -d, -f4)
        if [[ "$i" == "1" ]]
        then
                touch $SOURCE
        elif [[ "$i" == "2" ]]
        then
                rm -rf $SOURCE
        elif [[ "$i" == "3" ]]
        then
                touch ${SOURCE}_bkp
        else
                chmod 777 $SOURCE
        fi
done
}



echo -e "+---------------------------------------------------------------+\n|\n|\n|\t\t 1. \tIntrusion Detection Program\n|\t\t 2. \tExit\n|\n|\n+---------------------------------------------------------------+"

read -p "Enter Input [ Default Exit ]: " -r User_Input

if [[ "$User_Input" == "1" ]]
then
        delete_old
        create_files
        collect_checksum
        collect_details
        merge_details
else
        exit 127
fi

echo -e "+---------------------------------------------------------------+\n|\n|\n|\tDo you want to list the current files and folders?\n|\n+---------------------------------------------------------------+"

read -p "Please enter 'Y' or 'N': " User_Choice

if [[ "$User_Choice" == "Y" ]];
then
        cat $file_init
fi

echo -e "+---------------------------------------------------------------+\n|\n|\n|\tDo you want the program to make changes.\n|\n+---------------------------------------------------------------+"

read -p "Please enter 'Y' or 'N': " User_data

if [[ "$User_data" == "Y" ]];
then
        echo "Triggering Random Changes";
        random_change
        function_files_check
else
        echo -e "+---------------------------------------------------------------+\n|\n|\n|\tPlease make changes manually.\n|\n+---------------------------------------------------------------+"
        read -p "Press Y once done : " User_Final
        if [[ "$User_Final"  == "Y" ]]
        then
                echo "Analysing.. "
                function_files_check
        else
                echo "Failed to Read 'Y'. Hence Exiting."
                exit 12
        fi
fi





#function_verify
rm -f ${LOCKFILE}
