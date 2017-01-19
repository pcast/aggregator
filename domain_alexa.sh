# !/bin/bash

current_dir=`dirname $0`

cp /dev/null $current_dir/domain_attributes.txt

while read domain;
	do curl -o $current_dir/alexa.xml "http://data.alexa.com/data?cli=10&url="$domain
	country=$(xmlstarlet sel -t -m "ALEXA" -m "SD" -m "COUNTRY" -v "@NAME" < $current_dir/alexa.xml);
	global=$(xmlstarlet sel -t -m "ALEXA" -m "SD" -m "POPULARITY" -v "@TEXT" < $current_dir/alexa.xml);
	local=$(xmlstarlet sel -t -m "ALEXA" -m "SD" -m "COUNTRY" -v "@RANK" < $current_dir/alexa.xml);
	echo -e "{\"domain\":\""$domain"\", \"country\":\""$country"\", \"global\":\""$global"\", \"local\":\""$local"\"}">> /Users/paulcastronova/Desktop/domains/two/domain6_attributes.json
done <$current_dir/domain6.txt