# terminal终端

* [快捷键参考](https://github.com/hokein/Wiki/wiki/Bash-Shell%E5%B8%B8%E7%94%A8%E5%BF%AB%E6%8D%B7%E9%94%AE) [快捷键参考2](https://www.cnblogs.com/zhouj-happy/p/11375658.html)
* 移动

## 光标移动
* 移动: 左|下|上|右 ctrl+b(ack) | ctrl+n(ext) | ctrl+p(rev) | ctrl+f(orward)
* 移动一个单词: alt+b | alt+f
* 首: ctrl+a
* 尾: ctrl+e

## 删除快捷键:
* alt+d: 删除光标右边的单词
* ctrl+w: 删除当前光标左边的单词

## 清屏: ctrl+l

## 连续执行命令

```bash
sleep 5 && echo end
(exit 20) && echo "不会出现"  # 遇到报错就直接结束
```
