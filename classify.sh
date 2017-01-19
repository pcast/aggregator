#!/bin/bash

current_dir=`dirname $0`

#Clean RSS files
cp /dev/null $current_dir/english_news.xml
cp /dev/null $current_dir/english_business.xml
cp /dev/null $current_dir/english_education.xml
cp /dev/null $current_dir/english_culture.xml
cp /dev/null $current_dir/english_sports.xml

#log entry 1
echo "" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "***************" >> $current_dir/feed_log.txt
echo "" >> $current_dir/feed_log.txt
echo "$(date)" >> $current_dir/feed_log.txt

#US trends
curl -o $current_dir/trends.xml http://www.google.com/trends/hottrends/atom/feed?pn=p1
xmlstarlet sel -t -v "//rss/channel/item/title/text()" $current_dir/trends.xml >> $current_dir/keys.txt
sed -n 1,3p $current_dir/keys.txt >> $current_dir/keys_master.txt

#Other English trends
while read c_list;
	do curl -o $current_dir/trends.xml "http://www.google.com/trends/hottrends/atom/feed?pn=p"$c_list;
	xmlstarlet sel -t -v "//rss/channel/item/title/text()" $current_dir/trends.xml >> $current_dir/keys3.txt;
	sed -n 1p $current_dir/keys3.txt >> $current_dir/keys_master.txt;
	cp /dev/null $current_dir/keys3.txt;
done <$current_dir/countries.txt 

sort -u $current_dir/keys_master.txt >> $current_dir/keys_master2.txt

#Remove spaces between search terms
while read g_words;
	do echo ${g_words// /%20};
done <$current_dir/keys_master2.txt >> $current_dir/keys2.txt

#Fetch articles with images and perform quality checks
while read space_words;
	do curl -o $current_dir/space.xml "http://api.SOURCE.org/api/v1/search_ftxtsearch/search_ftxtsearch?query=sortby:rel%20sourcelang:eng%20lastminutes:60%20"$space_words"&output=artimgonlylist&dropdup=true&maxrows=1";
	address=$(grep -o 'HREF="http://[^"]*' $current_dir/space.xml);
	img_address=$(grep -o 'CLASS="thumbimg" SRC="http://[^"]*' $current_dir/space.xml);	
	address2=${address//HREF=\"/""};
	#log entry 2
	echo "" >> $current_dir/feed_log.txt
	echo "[[New Entry]]" >> $current_dir/feed_log.txt		
	echo "$address2" >> $current_dir/feed_log.txt
	
	img_address2=${img_address//CLASS=\"thumbimg\" SRC=\"/""};
	
	#image scoring process
	curl -o $current_dir/image.jpeg $img_address2;
	python3 /usr/local/lib/python2.7/dist-packages/tensorflow/models/image/imagenet/classify_image.py --image_file=$current_dir/image.jpeg >> $current_dir/image_rec.txt;
	sed -n 1p $current_dir/image_rec.txt >> $current_dir/image_top.txt;
	img_score=$(grep -o 'score = [^"]*' $current_dir/image_top.txt); 
	img_score2=${img_score//\)/""};
	img_score3=${img_score2//"score = "/""};
	img_score4=$(echo "$img_score3"|bc);
	#log entry 3
	echo "image = $img_score4" >> $current_dir/feed_log.txt

	
	#speed score and usability test
	if [ $(echo "$img_score4 > 0.2" | bc) -ne 0 ];
		then
			curl -o $current_dir/speed.xml "https://www.googleapis.com/pagespeedonline/v2/runPagespeed?url="$address2"&strategy=mobile&key={{KEY}}";
			speed=$(cat $current_dir/speed.xml | jq '.ruleGroups.SPEED.score');
			#log entry 4
			echo "speed = $speed" >> $current_dir/feed_log.txt

			usability=$(cat $current_dir/speed.xml | jq '.ruleGroups.USABILITY.score');
			#log entry 5
			echo "usability = $usability" >> $current_dir/feed_log.txt			
			
			if [ $(echo "$usability > 90" | bc) -ne 0 ];
				then
					if [ $(echo "$speed > 50" | bc) -ne 0 ];
						then
							echo "$address2" >> "$current_dir/links.txt"
						else
							echo "$address2" >> "$current_dir/slow.txt"
					fi		
				else		
					echo "$address2" >> "$current_dir/unusable.txt"
			fi
		else 
			echo "$address2" >> "$current_dir/ugly.txt"
	fi 
	
	#clean up
	cp /dev/null $current_dir/image_top.txt;
	cp /dev/null $current_dir/image_rec.txt;
done <$current_dir/keys2.txt


#Classifying the articles
while read class;

	do curl -o $current_dir/answer.xml https://api.aylien.com/api/v1/classify \
   		-H "X-AYLIEN-TextAPI-Application-Key: {{KEY}}" \
   		-H "X-AYLIEN-TextAPI-Application-ID: {{ID}}" \
   		-d url"="$class
   
	code=$(cat $current_dir/answer.xml | jq '.categories[].code');
	code2=${code:1:2};
	
	if [ -n "$code2" ];
		then
			if [ $code2 == '02' ] || [ $code2 == '03' ] || [ $code2 == '11' ] || [ $code2 == '14' ] || [ $code2 == '16' ] || [ $code2 == '17' ];
				then
					echo $class >> $current_dir/eng_news.txt;
				elif [ $code2 == '04' ] || [ $code2 == '09' ];
					then 
						echo $class >> $current_dir/eng_business.txt;
				elif [ $code2 == '15' ];
					then 
						echo $class >> $current_dir/eng_sports.txt;	
				elif [ $code2 == '01' ] || [ $code2 == '08' ] || [ $code2 == '10' ] || [ $code2 == '12' ];
					then 
						echo $class >> $current_dir/eng_culture.txt;	
				elif [ $code2 == '05' ] || [ $code2 == '06' ] || [ $code2 == '07' ] || [ $code2 == '13' ];
					then 
						echo $class >> $current_dir/eng_education.txt;	
			else	
				echo $class >> $current_dir/eng_general.txt;
			fi						
	fi
done <$current_dir/links.txt

#Creating the body of the RSS feeds
#News RSS
while read eng_news;
    do curl -o $current_dir/eng_news.xml "http://api.embedly.com/1/oembed?url="$eng_news"&key={{KEY}}&format=xml";
        url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/eng_news.xml);
        description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/eng_news.xml);
        image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/eng_news.xml);
        title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/eng_news.xml);
        echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/eng_news_body.txt;
done <$current_dir/eng_news.txt

#Business RSS
while read eng_business;
    do curl -o $current_dir/eng_business.xml "http://api.embedly.com/1/oembed?url="$eng_business"&key={{KEY}}&format=xml";
        url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/eng_business.xml);
        description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/eng_business.xml);
        image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/eng_business.xml);
        title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/eng_business.xml);
        echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/eng_business_body.txt;
done <$current_dir/eng_business.txt

#Culture RSS
while read eng_culture;
    do curl -o $current_dir/eng_culture.xml "http://api.embedly.com/1/oembed?url="$eng_culture"&key={{KEY}}&format=xml";
        url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/eng_culture.xml);
        description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/eng_culture.xml);
        image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/eng_culture.xml);
        title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/eng_culture.xml);
        echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/eng_culture_body.txt;
done <$current_dir/eng_culture.txt

#Education RSS
while read eng_education;
    do curl -o $current_dir/eng_education.xml "http://api.embedly.com/1/oembed?url="$eng_education"&key={{KEY}}&format=xml";
        url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/eng_education.xml);
        description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/eng_education.xml);
        image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/eng_education.xml);
        title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/eng_education.xml);
        echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/eng_education_body.txt;
done <$current_dir/eng_education.txt

#Sports RSS
while read eng_sports;
    do curl -o $current_dir/eng_sports.xml "http://api.embedly.com/1/oembed?url="$eng_sports"&key={{KEY}}";
        url=$(xmlstarlet sel -t -v "//oembed/url/text()" $current_dir/eng_sports.xml);
        description=$(xmlstarlet sel -t -v "//oembed/description/text()" $current_dir/eng_sports.xml);
        image=$(xmlstarlet sel -t -v "//oembed/thumbnail_url/text()" $current_dir/eng_sports.xml);
        title=$(xmlstarlet sel -t -v "//oembed/title/text()" $current_dir/eng_sports.xml);
        echo "<item><link>"$url"</link><description>"$description"</description><image>"$image"</image><title>"$title"</title><guid>"$url"</guid></item>" >> $current_dir/eng_sports_body.txt;
done <$current_dir/eng_sports.txt


#Finally, I put the information above into an RSS template so that it can be retrieved by my RSS reader. However, there is an issue with the encoding, so the final file does not render all languages properly.  This example uses english, but I would like it to support as many languages as possible.
#News
sed '/#start/r $current_dir/eng_news_body.txt' $current_dir/rss.xml >> $current_dir/eng_news_body.xml

cp /dev/null $current_dir/eng_news_body.txt

cp -f $current_dir/eng_news_body.xml $current_dir/english_news.xml
cp /dev/null $current_dir/eng_news_body.xml

#Business
sed '/#start/r $current_dir/eng_business_body.txt' $current_dir/rss.xml >> $current_dir/eng_business_body.xml

cp /dev/null $current_dir/eng_business_body.txt

cp -f $current_dir/eng_business_body.xml $current_dir/english_business.xml
cp /dev/null $current_dir/eng_business_body.xml

#Culture
sed '/#start/r $current_dir/eng_culture_body.txt' $current_dir/rss.xml >> $current_dir/eng_culture_body.xml

cp /dev/null $current_dir/eng_culture_body.txt

cp -f $current_dir/eng_culture_body.xml $current_dir/english_culture.xml
cp /dev/null $current_dir/eng_culture_body.xml

#Education
sed '/#start/r $current_dir/eng_education_body.txt' $current_dir/rss.xml >> $current_dir/eng_education_body.xml

cp /dev/null $current_dir/eng_education_body.txt

cp -f $current_dir/eng_education_body.xml $current_dir/english_education.xml
cp /dev/null $current_dir/eng_education_body.xml

#Sports
sed '/#start/r $current_dir/eng_sports_body.txt' $current_dir/rss.xml >> $current_dir/eng_sports_body.xml

cp /dev/null $current_dir/eng_sports_body.txt

cp -f $current_dir/eng_sports_body.xml $current_dir/english_sports.xml
cp /dev/null $current_dir/eng_sports_body.xml

#log entry 6
echo "" >> $current_dir/feed_log.txt
echo "Terms" >> $current_dir/feed_log.txt
wc -l $current_dir/keys_master.txt >> $current_dir/feed_log.txt
wc -l $current_dir/keys_master2.txt >> $current_dir/feed_log.txt

echo "" >> $current_dir/feed_log.txt
echo "Filters" >> $current_dir/feed_log.txt
wc -l $current_dir/ugly.txt >> $current_dir/feed_log.txt
wc -l $current_dir/unusable.txt >> $current_dir/feed_log.txt
wc -l $current_dir/slow.txt >> $current_dir/feed_log.txt

echo "" >> $current_dir/feed_log.txt
echo "Links" >> $current_dir/feed_log.txt
wc -l $current_dir/links.txt >> $current_dir/feed_log.txt

echo "" >> $current_dir/feed_log.txt
echo "Subjects" >> $current_dir/feed_log.txt
wc -l $current_dir/eng_news.txt >> $current_dir/feed_log.txt
wc -l $current_dir/eng_business.txt >> $current_dir/feed_log.txt
wc -l $current_dir/eng_education.txt >> $current_dir/feed_log.txt
wc -l $current_dir/eng_culture.txt >> $current_dir/feed_log.txt
wc -l $current_dir/eng_sports.txt >> $current_dir/feed_log.txt
wc -l $current_dir/eng_general.txt >> $current_dir/feed_log.txt

#House cleaning
cp /dev/null $current_dir/ugly.txt
cp /dev/null $current_dir/slow.txt
cp /dev/null $current_dir/unusable.txt
cp /dev/null $current_dir/links.txt
cp /dev/null $current_dir/img_links.txt
cp /dev/null $current_dir/keys.txt
cp /dev/null $current_dir/keys2.txt
cp /dev/null $current_dir/keys_master.txt
cp /dev/null $current_dir/keys_master2.txt
cp /dev/null $current_dir/eng_news.txt
cp /dev/null $current_dir/eng_business.txt
cp /dev/null $current_dir/eng_education.txt
cp /dev/null $current_dir/eng_culture.txt
cp /dev/null $current_dir/eng_sports.txt