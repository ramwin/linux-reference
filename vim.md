## Xiang Wang @ 2016-05-25 10:37:15


# 导航
* [配置](http://edyfox.codecarver.org/html/_vimrc_for_beginners.html)
* [多窗口](#split)
* 参考资料
    * [vim viki](http://vim.wikia.com/wiki/Main_Page)
    * [vimeo](https://vimeo.com/15443936)


# 插入
* `i, I` 插入,开头插入
* o, O 换行插入, 上一行插入
* a, A 字符后面插入, 行尾插入
* s, S 删除当前字符插入, 删除当前行插入


# 缩进
* `ctrl+v 5>` *把一行代码右移5层缩进*
* `>}` *段落之后的行缩进*
* `>ap` *段落缩进*

# 选择
* ci'、ci"、ci<、快速更改
* di'、di"、di(  快速删除
* da', da", da(  delete all '这个就是包括两边进行删除了
* V, v 列选择, 行选择
* yaw, yiw 也适用，把单词当作括号处理

# [光标移动](http://vim.wikia.com/wiki/Moving_around)
* h, j, k, l 左下上右移动
* W, w 前进一个单词(大写忽略标点)
* E, e 前进到一个单词的最后一个字母(大写忽略标点)
* R, r replace替换一个字母(大写替换至你按esc)
* T, t 找到指定的字母, 不移动到单词位置(大写往后找)
* f, F 向前(向后)找到指定的字母, 移动到单词位置
    n; 按照上次查找继续查找n次
    n, 按照上次查找反方向查找n次
* B, b 后退一个单词(大写忽略标点)
* g, G 移动到指定行数(大写最后一行)
* H(ead), M(iddle), L(ow) 移动到屏幕位置
* 移动到制定列  n|
* `#` `*` 找到当前位置单词的上一个/下一个

# 屏幕移动
* 下一行 ctrl + E 
* 上一行 ctrl + Y 
* `z + z` 把光标行移动到行中
* `z + t` 把光标行移动到top
* `z + b` 把光标行移动到bottom

# [折叠](http://www.cnblogs.com/welkinwalker/archive/2011/05/30/2063587.html)
* zv 查看此行(展开到当前行。用于查看日志，跳转到行数后直接展开)
* 折叠  zc
* 折叠当前范围 zC
* 打开折叠 zo
* 打开当前最大折叠 zO
* 折叠文件 zm
* 折叠文件到最高层 zM
* 打开文件 zr
* 打开所有折叠 zR

# 正则匹配
* [别人博客参考](http://www.cnblogs.com/PegasusWang/p/3153300.html)
* 案例  
    * `/\d\{0,2}\t.*$`
    * `<[^<]*>$`  *找到文件的最后一个中括号标签*
    * [跨行搜索](http://vim.wikia.com/wiki/Search_across_multiple_lines)

# 替换
* 位置的选择
    * :s 当前行
    * :%s 所有行
    * :5,12s 第5行到第12行
    * :.,-12s 当前行到上面12行
    * :g/^bar/s 找前三个字母为 `baz` 的行进行替换
* 示例
```
    :%s/old/net/gc
    :%s/\s\+$// # 删除行末的空格
    :100,200s/old/new/gc # 只替换100行到200行的数据
```

# 正则
* 规则:
    1. 数量: `\d\{1,3\}`, `\+`
    2. 代码块: `\(pattern\)`
    3. 使用代码块: `\1`

# 跳转
* [学习链接](http://blog.csdn.net/xxxsz/article/details/7454290)
* `[ i`查看上一次的用法
* `[ ctrl i` 跳转到上面的定义
* `] ctrl i` 跳转到下面
* `] i` 查看下一次的用法
* `g; g, \`,` 跳转到上一次/下一个/最后一次编辑的地方

* 函数, 变量的跳转  [ + ctrl + i
* `ctrl + O` 跳转到上次位置
* `ctrl + I` 跳转到下次位置

# 多窗口
* ^ws 拆分窗口
* ^wv 垂直拆分窗口
* ^ww 切换窗口
* ^wq 退出窗口
* 切换尺寸
    `:(vertical) res +5`
    `ctrl + w + `-`|`+`|`<`|`>``

# 编辑
* x, X 删除(左边，右边)一个字符
* d, D 删除
    * D 删除到行末
    * dw, d$, dd 删除单词, 末尾, 一行
    * dfx 删除到某个字符
    * dtx 删除到某个字符, 不包括这个字符
* u 撤销操作
* U 回滚上次编辑的行的数据
* 复制到剪切板  
    * `"[a-z0-9|+|*]yy` 复制到制定的剪切板 +为系统剪切板,需要安装`vim-gnome`
* 粘贴剪切板  
    * p, P 后面粘贴, 前面粘贴
    * `"[a-z0-9|+|*p` 粘贴剪切板的内容。

# 参考
* [链接](http://dsec.pku.edu.cn/~jinlong/vi/Vi.html)

# 宏
* 输入`q`进入命令模式
* 输入`a-z0-9`选择宏的命名
* 持续性操作, 知道按`q`退出
* 输入`@+命名`执行录制的宏
