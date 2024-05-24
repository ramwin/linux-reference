# Security 安全机制

## General Security Issues 基本安全 [官网](https://dev.mysql.com/doc/refman/8.0/en/general-security-issues.html)

### Security Guidelines

* 不要给任何用户(除了root)拥有`user`表的权限
* 学习 MySQL Access Privilege System, 使用 GRANT 和 REVODE来下发权限, 不要给更多的权限. 不要把权限给所有的hosts
* 不要保存明文密码, 使用SHA2或者其他方法保存密码到数据库, 防止别人用彩虹表, 所以要hash加盐再hash
* 密码不要用word, 因为有break passwords的programs(我都是用python随机生成的)
* 使用防火墙, 把mysql放在demilitarized zone(DMZ) `telnet server_host 3306`
* 任何由用户生成的数据都是不可靠的, 需要防止sql注入
* 不要直接链接, 使用SSL或者SSH协议, 或者通过SSH隧道来创建communication `sudo tcpdump -l -i enp4s0 -w - src or dst port 3306 | strings`

### Keeyping Passwords Secure  
如何保证密码的安全, 避免泄露密码. `validate_password` 插件可以保证密码的强度 [6.5.3 Password Validation Component](https://dev.mysql.com/doc/refman/8.0/en/validate-password.html)  
#### End-User方面
* 使用`mysql_config_editor`工具,参见 4.6.7 mysql_config_editor
* 使用 `-pyour_pass` 或者 `--password=your_pass`参数来链接
这个很方便但是不安全, 因为 使用ps命令或者看bash_history可以看到
* 使用`-p`或者`--password`参数, 但是不输入密码
这样mysql会提示你输入密码, 这样比较安全, 但是只能用在交互模式上. 不然程序会卡住
* 把密码放在.my.cnf文件, 然后用--defaults-file使用这个文件
注意把文件设置成600模式, 具体参见 4.2.7 Using Option Files
* 把密码保存到 MYSQL_PWD 环境变量
这个及其不安全, 谁都能看到. 
* 其他
在unix系统, mysql会保存命令日志, 所以使用CREATE USER 或者ALTER User的时候, 会记录下来. 所以要使用restrictive access model. 和之间.my.cnf文件一样  
一些.bash_history也应该只能自己看到

#### Administrator方面
MySQL保存密码到mysql.user表, 不能给任何人权限访问

#### [ ] Passwords和Logging
log日志因为会保存, 所以要保证log table和log file不能让别人访问. 在master和slave之间尤其要注意. log日志在哪目前还不知道, 但是默认肯定是root才能访问的.

### Making MySQL Secure Against Attackers  
直接链接,别人都会检测到. 所以需要使用加密的SSL链接
* 保证所有账户都要有个密码
* 只有运行mysqld的账户(一般是root, mysql)才能进入mysql的目录
* 永远不要使用root用户去执行MySQL. 因为会创造出一些 ~root/.bashrc
所以默认这是mysqld的运行账户是mysql
* 不要把文件授权给别的用户
也要防止mysql可以直接读取类似`/etc/passwd`的文件, 参见 5.1.8 Server System Variables
* 不要把PROCESS或者SUPER权限给非管理员用户. 
* 不要允许表的symlinks
* Stored programs和views需要控制
* GRAND的时候, 如果你不信任你的DNS, 最好使用IP而不是DNS. 如果使用通配符必须格外小心
* 限制用户的max user connections
* 要防止plugin directory是writable
