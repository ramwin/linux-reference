## supervisor
[官网](http://supervisord.org/index.html)

### 安装
* [centos安装](https://www.php.cn/linux-413808.html)

### 运行supervisor
* supervisorctl
```shell
默认stop和restart会发送signal.SIGTERM:15的信号
supervisorctl stop <name>|all  停止一个进程
supervisorctl [re]start <name>|all 停止一个|所有进程
supervisorctl reread
```

### [配置文件](http://supervisord.org/configuration.html#program-x-section-example)
```
[program:redis]
user=dev
directory = /var/www/project
command=gunicorn project.wsgi -c deploy/gunicorn.conf.py
autostart=true
autorestart=true
redirect_stderr=false
stdout_logfile=/a/path
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=10
stdout_capture_maxbytes=1MB
stdout_events_enabled=false
stderr_logfile=/a/path
stderr_logfile_maxbytes=1MB
stderr_logfile_backups=10
stderr_capture_maxbytes=1MB
stderr_events_enabled=false
```

### [日志](http://supervisord.org/logging.html)
