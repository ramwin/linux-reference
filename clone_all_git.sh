#!/bin/bash
# Xiang Wang @ 2018-07-30 18:32:56

cd ..
for i in Public chuansong_spider docker hr_api_test kindle_tutorial pm25in sharemap_tests water can company_classification file hr_web lieshangwang resume shopproject website_crawler check coursera filenet inmind mindex_hr_web se weibo chicago data_spider guangdian jikang mini-sharegine secret speiyou zettage_homepage chicago2 django_localization helpme jinju pm25 shadowsocks sushizone zettage_public china-public-data django_tutorial hr_api jiushijiudu pm25check sharemap_server tplink; do
    if [ -d $i ]; then
        echo "文件夹$i已存在"
    else
        git clone git@www.ramwin.com:/ramwin/$i.git
    fi
done
