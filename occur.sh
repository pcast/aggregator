#!/bin/bash

current_dir=`dirname $0`

#House cleaning
cp /dev/null $current_dir/awk_list.txt
cp /dev/null $current_dir/awk_list2.txt
cp /dev/null $current_dir/SOURCE_unique.txt
cp /dev/null $current_dir/SOURCE_urls.txt
cp /dev/null $current_dir/SOURCE_urls2.txt
cp /dev/null $current_dir/new.txt
cp /dev/null $current_dir/order.txt
cp /dev/null $current_dir/paste_urls.txt
cp /dev/null $current_dir/chosen_list.txt
cp /dev/null $current_dir/english_body.txt
find $current_dir/paste/ -maxdepth 1 -type f -delete 
find $current_dir/split/ -maxdepth 1 -type f -delete 

#log entry 1
echo "" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "***************" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "$(date)" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "[[New Entry]]" >> $current_dir/feed_log.txt

#Retrieve SOURCE data
curl -o $current_dir/SOURCE_24.json "http://api.SOURCE.org/api/v1/gkg_geojson?QUERY=lang:eng&TIMESPAN=30&OUTPUTFIELDS=url,lang&MAXROWS=50000"
cat $current_dir/SOURCE_24.json | jq ".features[].properties.url" >> $current_dir/SOURCE_urls.txt

#clean and sort URL list
while read url;
	do item=${url//\"/""};
	item2=${item//\"/""};
	echo $item2 >> $current_dir/SOURCE_urls2.txt;
done <$current_dir/SOURCE_urls.txt

sort -u $current_dir/SOURCE_urls2.txt > $current_dir/SOURCE_unique.txt
echo "" >> $current_dir/feed_log.txt
echo "Unique" >> $current_dir/feed_log.txt
wc -l $current_dir/SOURCE_unique.txt >> $current_dir/feed_log.txt

sort $current_dir/SOURCE_urls2.txt | uniq -c | sort -n > $current_dir/order.txt

#Separate low frequency URLs
while read -r num url;
	do if [ $(echo "$num < 3" | bc) -ne 0 ];
		then
		echo $url >> $current_dir/awk_list.txt;
	fi
done <$current_dir/order.txt

echo "Low Frequency" >> $current_dir/feed_log.txt
wc -l $current_dir/awk_list.txt >> $current_dir/feed_log.txt

#Archiving
comm -2 -3 <(sort -u "$current_dir/awk_list.txt") <(sort -u "$current_dir/archive.txt") > "$current_dir/awk_list2.txt" 

while read l_new;
	do echo  "$l_new" >> "$current_dir/archive.txt"
done <"$current_dir/awk_list2.txt" 

echo "Deduplication" >> $current_dir/feed_log.txt
wc -l $current_dir/awk_list2.txt >> $current_dir/feed_log.txt


#Split and paste lists for Facebook
split -l 50 -a 3 $current_dir/awk_list2.txt $current_dir/split/

cp -a $current_dir/split/. $current_dir/paste/

for d in $current_dir/paste/*;
	do paste -d, -s $d > $d"_paste.txt";
	rm $d; 
done

#Retrieve like and share total. Separate URLs with total count over 1000.
for e in $current_dir/paste/*;
	do a_url=$(cat < $e); 
	curl -o $current_dir/fbook.xml "https://api.facebook.com/method/links.getStats?format=json&urls="$a_url;
	cat $current_dir/fbook.xml | jq "map(select(.share_count >= 400))" >> $current_dir/paste_urls.txt; 
done

#Compile 
cat $current_dir/paste_urls.txt | jq ".[] | .url" > $current_dir/new.txt

while read url;
	do item=${url//\"/""};
	item2=${item//\"/""};
	echo $item2 >> $current_dir/chosen_list.txt;
done <$current_dir/new.txt

echo "Over 1000" >> $current_dir/feed_log.txt
wc -l $current_dir/chosen_list.txt >> $current_dir/feed_log.txt

#Retrieve Embedly data and create RSS feed
while read english;
   do curl -o $current_dir/english.xml "http://api.embedly.com/1/oembed?url="$english"&key={{KEY}}&format=xml";
       url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/english.xml);
       description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/english.xml);
       image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/english.xml);
       title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/english.xml);
       echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/english_body.txt
done <$current_dir/chosen_list.txt

sed '/#start/r $current_dir/english_body.txt' $current_dir/rss.xml > $current_dir/english_rss.xml
