# echo
输出文字

```shell
echo $?  # 上一个命令的退出码
echo -e "\e[x;y;zm我要的文字\e[0m"
x,y,z代表了属性
颜色: 黑色=30，红色=31，绿色=32，黄色=33，蓝色=34，洋红=35，青色=36，白色=37
背景色: 黑色=40，红色=41，绿色=42，黄色=43，蓝色=44，洋红=45，青色=46，白色=47
其他效果: 0 关闭所有属性、1 设置高亮度（加粗）、4 下划线、5 闪烁、7 反显、8 消隐
```

* -n: 不要添加换行符
* -e: 对反斜杠`\`进行转义

```
echo -e "\0100"
echo -e '\xe6\x88\x91'
```


* exit: 退出
```
(echo 20)  # 使用20当作退出的状态码
echo $?  # 查看上次命令的状态码
```

## 变量输出
* 通过字符串拼接
```shell
echo 'export PATH='${HOME}'/bin:'${HOME}'/local/bin:$PATH' >> ~/.bash_aliases

# export PATH=/home/wangx/bin:/home/wangx/local/bin:$PATH

echo 'export PATH='${HOME}'/venv/bin:$PATH' >> ~/.bash_aliases

# export PATH=/home/wangx/bin:/home/wangx/local/bin:$PATH
```
