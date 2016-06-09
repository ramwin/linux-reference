# 安装
    sudo apt-get install python-dev python-pip libxml2-dev libxslt1-dev zlib1g-dev libffi-dev libssl-dev
    sudo pip install Scrapy
## 创建项目
    scrapy startproject <projectname>
    cd <projectname>
    scrapy genspider <spidername> <url>
## 修改
    items.py
## 创建
    dmoz_spider.py
## 启动项目
    scrapy crawl dmoz
## shell启动   
    scrapy shell "http://www.dmoz.org/Computers/Programming/Languages/Python/Books/"
    response.xpath('//title')
