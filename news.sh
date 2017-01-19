# !/bin/bash

current_dir=`dirname $0`

# House cleaning
cp /dev/null $current_dir/check.txt
cp /dev/null $current_dir/approved.txt
cp /dev/null $current_dir/unique.txt
cp /dev/null $current_dir/unique2.txt
cp /dev/null $current_dir/lang.txt
cp /dev/null $current_dir/domains.txt
cp /dev/null $current_dir/country.txt
cp /dev/null $current_dir/approved_unique.txt
cp /dev/null $current_dir/combo.txt
cp /dev/null $current_dir/combo2.txt
cp /dev/null $current_dir/awk_list.txt
cp /dev/null $current_dir/awk_list2.txt
cp /dev/null $current_dir/SOURCE_unique.txt
cp /dev/null $current_dir/SOURCE_urls.txt
cp /dev/null $current_dir/SOURCE_urls2.txt
cp /dev/null $current_dir/alexa.txt
cp /dev/null $current_dir/new.txt
cp /dev/null $current_dir/order.txt
cp /dev/null $current_dir/paste_urls.txt
cp /dev/null $current_dir/chosen_list.txt
cp /dev/null $current_dir/english_body.txt
find $current_dir/paste/ -maxdepth 1 -type f -delete 
find $current_dir/split/ -maxdepth 1 -type f -delete 

# log entry 1
echo "" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "***************" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "$(date)" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "[[New Entry]]" >> $current_dir/feed_log.txt

# Retrieve SOURCE data
curl -o $current_dir/SOURCE_24.json "http://api.SOURCE.org/api/v1/gkg_geojson?QUERY=&TIMESPAN=30&OUTPUTFIELDS=url,name,sharingimage,tone,lang,domain&MAXROWS=1000"
cat $current_dir/SOURCE_24.json | jq '[.features[].properties | {domain: .urldomain , url: .url , lang: .urllangcode}]' >> $current_dir/SOURCE_urls.txt
cat $current_dir/SOURCE_urls.txt | jq 'unique_by(.url)' >> $current_dir/unique.txt

curl -o $current_dir/SOURCE_24.json "http://api.SOURCE.org/api/v1/gkg_geojson?QUERY=&TIMESPAN=30&OUTPUTFIELDS=url,name,sharingimage,tone,lang,domain&MAXROWS=1000"
jq '[.features[].properties | {urldomain, url, urllangcode}]' < $current_dir/SOURCE_24.json >> $current_dir/SOURCE_urls.txt
jq 'unique_by(.url)' < $current_dir/SOURCE_urls.txt >> $current_dir/unique.txt
jq -r '.[] | .urldomain +" "+ .url +" "+ .urllangcode' < $current_dir/unique.txt >> $current_dir/unique2.txt

while read domain url lang;
	do jq --arg web "$domain" '.[] | select(.domain == $web)' < $current_dir/attributes.json >> $current_dir/alexa.txt;
	country=$(jq -r '.country' < $current_dir/alexa.txt);
	lang_up=$(echo "$lang" | tr '[:lower:]' '[:upper:]');
	if [ ! -z "$country" ];	
		then curl -o $current_dir/strip.html $url;
		tag_title=$(cat $current_dir/strip.html | pup 'title text{}')
		og_title=$(cat $current_dir/strip.html | pup '[property="og:title"] attr{content}')
		attribute_title=$(cat $current_dir/strip.html | pup '[name="title"] attr{content}')
		tag_description=$(cat $current_dir/strip.html | pup '[name="description"] attr{content}')		
		og_description=$(cat $current_dir/strip.html | pup '[property="og:description"] attr{content}')
		if [ ! -z "$og_title" ];
			then title=$(echo $og_title);
				elif [ ! -z "$attribute_title" ];
					then title=$(echo $attribute_title);
						elif [ ! -z "$tag_title" ];
							then title=$(echo $tag_title);			
		fi
		if [ ! -z "$og_description" ];
			then description=$(echo $og_description);
				elif [ ! -z "$tag_description" ];
					then description=$(echo $tag_description);
		fi
		if [ ! -z "$title" ] && [ ! -z "$description" ];
			then echo 'Story.create :title=>”'$title'", :description=>”'$description'", :url=>"'$url'", :user_id=>1, :tags_a=>["'$lang_up'", "'$country'"]'>> $current_dir/see.txt;
		fi
	fi
	cp /dev/null $current_dir/alexa.txt
done < $current_dir/unique2.txt


cat $current_dir/unique.txt | jq -r '.[] | .domain' >> $current_dir/domains.txt

# Clean list
while read domain;
	do item=${domain//\"/""};
	item2=${item//\"/""};
	echo $item2 >> $current_dir/domains_noquotes.txt;
done <$current_dir/domains.txt

sort -u $current_dir/domains_noquotes.txt > $current_dir/domains_unique.txt

# Compare against FB approved domains
fb=$(cat < '$current_dir/fb_urls2.txt')

while read -r dom url lang;
	do	echo $dom >> $current_dir/check.txt
		if [[ "$fb" =~ "$dom" ]];
			then 
			echo $dom $url $lang >> $current_dir/approved.txt;
		fi
done < $current_dir/SOURCE_urls2.txt


sort -u $current_dir/approved.txt > $current_dir/approved_unique.txt

sort -u $current_dir/check.txt > $current_dir/SOURCE_unique.txt

# Check Stats
comm $current_dir/fb_urls2.txt $current_dir/SOURCE_unique.txt >> $current_dir/combo.txt

comm -1 -2 $current_dir/fb_urls2.txt $current_dir/SOURCE_unique.txt >> $current_dir/combo2.txt

wc -l $current_dir/SOURCE_unique.txt
wc -l $current_dir/combo2.txt
wc -l $current_dir/approved_unique.txt

echo "" >> $current_dir/feed_log.txt
echo "Unique" >> $current_dir/feed_log.txt
wc -l $current_dir/SOURCE_unique.txt >> $current_dir/feed_log.txt
wc -l $current_dir/combo2.txt >> $current_dir/feed_log.txt
wc -l $current_dir/approved_unique.txt >> $current_dir/feed_log.txt

# Archiving
comm -2 -3 <(sort -u "$current_dir/approved_unique.txt") <(sort -u "$current_dir/archive.txt") > "$current_dir/awk_list2.txt" 

while read l_new;
	do echo  "$l_new" >> "$current_dir/archive.txt"
done <"$current_dir/awk_list2.txt" 

echo "Deduplication" >> $current_dir/feed_log.txt
wc -l $current_dir/awk_list2.txt >> $current_dir/feed_log.txt


Split and paste lists for Facebook
split -l 50 -a 3 $current_dir/awk_list2.txt $current_dir/split/

cp -a $current_dir/split/. $current_dir/paste/

for d in $current_dir/paste/*; 
	do paste -d, -s $d > $d"_paste.txt";
	rm $d; 
done

Retrieve like and share total. Separate URLs with total count over 1000.
for e in $current_dir/paste/*; 
	do a_url=$(cat < $e); 
	curl -o $current_dir/fbook.xml "https://api.facebook.com/method/links.getStats?format=json&urls="$a_url;
	cat $current_dir/fbook.xml | jq "map(select(.share_count >= 200))" >> $current_dir/paste_urls.txt; 
done

Compile 
cat $current_dir/paste_urls.txt | jq ".[] | .url" > $current_dir/new.txt

while read url;
	do item=${url//\"/""};
	item2=${item//\"/""};
	echo $item2 >> $current_dir/chosen_list.txt;
done <$current_dir/new.txt

echo "Over 200" >> $current_dir/feed_log.txt
wc -l $current_dir/chosen_list.txt >> $current_dir/feed_log.txt
 
#Retrieve Embedly data and create RSS feed
while read english;
   do curl -o $current_dir/english.xml "http://api.embedly.com/1/oembed?url="$english"&key={{KEY}}}";
       url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/english.xml);
       description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/english.xml);
       image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/english.xml);
       title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/english.xml);
       echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/english_body.txt
done <$current_dir/chosen_list.txt

sed '/#start/r $current_dir/english_body.txt' $current_dir/rss.xml > $current_dir/english_body.xml