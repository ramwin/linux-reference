# Linux 知识快速查询  
*这个是我平时遇到各种问题的时候记录下来的笔记.*

# Linux
* [系统](./linux/system.md)
* [user & group](./linux/user_group.md)
* [文本处理](./text.md)
* [markdown](./markdown.md)
* [bash, shell编程](./shellprogramming/README.md)


# 常用口令
* fdisk # 对磁盘进行分区
* find
    * `find . -path "*/migrations/*.py"` *查找文件*
    * `find ./ -type f -name "*.py" | xargs grep "verify_ssl"`
* notify-send
    * `notify-send 保护视力，休息一会`
* rename
    * `rename 's/group_public/group-public/g' *` *把当前目录下所有文件的group_public变成group-public*
* zentify
    * `zenity --info --text '保护视力，休息一会'



# 软件
* [database数据库](./database/README.md)
    * [mongodb](./mongodb.md)
* [chromium]
    ```
    chromium-browser --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE localhost" &
    ```
* except  # 自动输入账号密码的工具，用来自动化脚本里面避免卡住
* [git](./git/README.md)
* [MySQL](./database/README.md)
    * [Grant权限控制](./database/mysql_grant.md)
* [nginx](./nginx.md)
* [redis](./redis/README.md)
* [阮一峰的oauth讲解](http://www.ruanyifeng.com/blog/2014/05/oauth_2_0.html)
* [screen](./screen.md) *用来开启后台shell*
    ```
    screen -list
    screen -S sjtupt    # 创建新的screen
    ctrl + A + D    # 关闭当前screen
    screen -r sjtupt    # 还原之前的screen
    ```
* smtp邮件服务器
    * [digitalocean.com教程](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-14-04)
    ```
    sudo apt install mailutils
    sudo apt install postfix
    修改 inet_interfaces = loopback-only 或者 localhost
    service postfix restart
    ```
    * [配置文档](http://blog.csdn.net/reage11/article/details/9295005)
* [vim](./vim.md) [tutorial教程](http://www.openvim.com/)
