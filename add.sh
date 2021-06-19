#!/bin/sh
# add.sh utorrent.com:8080 user:pass magnetfile

HOST="$1"
AUTH="$2"
FILE="$3"

if [ "$HOST" = "" ] || [ "$AUTH" = "" ] || [ "$FILE" = "" ]
then
	echo "add.sh <HOST> <AUTH> <FILE>"
	exit 0
fi

TOKEN=$(curl -c cjar --basic --user $AUTH http://$HOST/gui/token.html | sed -E 's/<html><div[^>]*>([^>]*)<\/div><\/html>/\1/g')

while read LINK           
do           
	E_LINK=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$LINK")
	URL="http://$HOST/gui/?token=$TOKEN&action=add-url&s=$E_LINK"
	echo $URL
	curl -b cjar --basic --user $AUTH $URL
	echo "OK!"       
done < $FILE 

exit 0
