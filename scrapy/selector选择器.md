# 选择器

## 根据标签选择
    response.selector.xpath('//title')
## 根据css选择
    response.selector.css('title')


# 数据处理

## 只需要获取里面的文本
    response.selector.xpath('//title/text()')
    response.selector.css('title::text')
## 把对象变成文本
    response.selector.xpath('//title/text()').extract()
## 只要获取第一个
    response.selector.xpath('//title/text()').extract_first(default='not-found')  # 没有default会返回None， 不会报错
## 获取其他属性
    response.selector.xpath('//a').xpath('@href')
    response.selector.xpath('//a/@href')
    response.selector.css('a::attr(href)')

