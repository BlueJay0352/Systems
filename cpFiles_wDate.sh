#!/bin/sh
#Script for moving ESM event folders greater than X days to nfs share /mnt3
#set -xv

logDate=$(date +"%b%d%Y")
logFile="dateMove-$logDate.log"
#exec > /var/log/dateMoveScript/$logFile

#red="\033[31;40m"
#endClr="\033[0m"

dateMove=$(date +%Y%m%d -d "-180 days")                                                         ## global control date
echo  !!!Will move folders older than $dateMove!!!

f=$(find /data/archives/0648518346341351424/20* -type d | grep '.*[0-9]$')                      ## get folder names with numbers only (ie: 20171122)
        for i in $f;
          do
        dateDir=$(basename "$i")                                                                ## remove path prefix up to last slash char
            if [ "$dateDir" -lt "$dateMove" ] && [ ! -d /mnt3/"$dateDir"  ] ; then              ## evaluate if folder date is before (less than) dateMove and folder doesn't already exist in /mnt3
                echo !!"$dateDir" IS LESS THAN "$dateMove" - COPYING "$dateDir" TO /mnt3 
                rsync --remove-source-files --progress -r -a /data/archives/0648518346341351424/$dateDir /mnt3/
            elif [ "$dateDir" -ge "$dateMove" ] ; then                                          ## evaluate if folder date is equal or greater than dateMove
                echo FOLDER "$dateDir"  - NOT OLD ENOUGH TO COPY
            else
                echo SKIPPING "$dateDir" - FOLDER ALREADY EXISTS
            fi
          done;

s=$(find /data/archives/0648518346341351424/20* -type d | grep '.*[a-z]$')                      ## get folder names with folder ext (ie: 20171122.supplemental 20171128.tmp)
        for z in $s
          do
        dateDir2=$(basename "$z")                                                               ## remove path prefix up to last slash char
        fileExt=$(echo "$dateDir2" | awk -F "." '{print $2}')                                   ## extract folder extension (ie: .supplemental .tmp)
        dateDir2=$(sed -r 's/\.[^.]*$//g' <<<"$dateDir2" )                                      ## remove folder extention
        dateExt="$dateDir2"".$fileExt"                                                          ## create folder + extention var
            if [ "$dateDir2" -lt "$dateMove" ] && [ ! -d /mnt3/"$dateExt" ] ; then
                echo !!"$dateExt" IS LESS THAN "$dateMove" - COPYING "$dateExt" TO /mnt3 
                rsync --progress -r -a /data/archives/0648518346341351424/$dateExt /mnt3/
            elif [ "$dateDir2" -ge "$dateMove" ] ; then
                echo FOLDER "$dateExt" - NOT OLD ENOUGH TO COPY
            else
                echo SKIPPING "$dateExt" - FOLDER ALREADY EXISTS
            fi
          done;

servername='hostname'
sender="root@$servername"
recp="jay@mail.com"

errors=$(grep -i "error" /var/log/dateMoveScript/$logFile)

if [ ! -z "$errors" ]; then
  echo $logFile -- $errors | mail -s "$servername Archiving Errors." $recp
fi


