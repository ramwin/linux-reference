# export HTTPS_PROXY="http://localhost:1080"
# export HTTP_PROXY="http://localhost:1080"

# 用来在windows目录下用windows的git
cd() {
    builtin cd "$1"
    current_path=`realpath .`
    if [[ $current_path == /mnt/d/* ]]
    then
        alias 'git="git.exe"'
    else
        alias git="git"
    fi
}

export TLDR_CACHE_ENABLED=1
export TLDR_CACHE_MAX_AGE=24

alias gitlog='git log --graph --pretty=format:"%Cgreen%h %Cred%s %Creset----%C(yellow)%cn %Creset@ %ad %C(green)%d" --date=format:"%Y-%m-%d %H:%M"'

# django 快捷键
alias mshell='./manage.py shell'
alias mshell3='python3 manage.py shell'
alias mrun='./manage.py runserver'
alias collectstatic='python manage.py collectstatic'

# Docker 的快捷键
alias dockerrm='docker rm `sudo docker ps -a -q`'
alias dockerimg='docker images'

# 翻墙用
alias ramwinproxy='sslocal -s www.ramwin.com -k JinmK29U -m aes-256-cfb'
alias ramwinproxy2='sslocal -p 12288 -s band.ramwin.com -k Ramwin234 -m aes-256-cfb'
# alias ramwinchrom='chromium-browser --proxy-server="socks5://127.0.0.1:1080" --proxy-bypass-list="*.baidu.com;*.163.com;127.0.0.1:8080" &'
alias ramwinchrom='chromium-browser --proxy-server="socks5://127.0.0.1:1080" --proxy-pac-url="file:///home/wangx/github/Public/proxy_gfw.pac"&'

# 快捷操作
alias l='ls'
alias ll='ls -al'
alias mytree="tree -L 2 -d -I 'node_modules'"

# 自动打包 servlet 项目
function wxm(){
    rm -rf target
    echo 'Maven缓存已清除';
    mvn package;
    echo 'maven打包完成';
    sudo cp target/*.war /var/lib/tomcat7/webapps/zettage.war;
    echo '文件已经复制';
    sudo chmod 777 /var/lib/tomcat7/webapps/zettage.war;
    echo '已经赋予权限';
    sudo rm -rf /var/lib/tomcat7/webapps/zettage/
    echo 'tomcat缓存已经清除';
    sudo /etc/init.d/tomcat7 restart;
    echo 'tomcat重启完成，请访问页面';
}

# 运行 c++ 程序
function wxc(){
    g++ $1 && ./a.out;
}

# 运行java程序
function wxj(){
    echo '编译文件' $1;
    javac $1;
    echo '---------------编译完成,输出结果如下:--------------'
    name=$1
    left=0
    right=${#name}-5
    result=${name:0:right}
    java $result;
    echo '---------------------输出完成----------------------'
}

# export TERM="xterm-color"
# export CLICOLOR=1
# export LSCOLORS=GxFxCxDxBxegedabagaced
PYENV_ROOT="$HOME/.pyenv"
PATH=\
:/home/wangx/node/bin\
:$PYENV_ROOT/shims\
:/home/wangx/bin/\
:/home/wangx/github/python-reference/script/\
:/home/wangx/github/linux-reference/script/\
:/home/wangx/node_modules/bin/\
:/home/wangx/github/secret/\
:/usr/local/java/bin/\
:/usr/local/eclipse/\
:/usr/local/go/bin/\
:/usr/local/go/bin/\
:/usr/node/bin/\
:/home/wangx/.pyenv/bin/\
:/home/wangx/gh/bin/\
:$PATH
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

export NODE_PATH="/usr/node/lib/node_modules"

# 目录快捷方式
alias github='cd ~/github'
alias work='cd ~/github/duishang'
alias lib='cd /usr/local/lib/python3.6/*-packages/'


# python
alias pep='pep8 --max-line-length=120'
alias gitflake='git status -s | grep .py | xargs flake8'
# xset m 0 1
function settitle() {
    echo -ne "\033]0;${1}\007" 
}

# mac 的设置
export CLICOLOR=1
# settitle coding
export LANGUAGE='en_US.UTF-8 git'
export VISUAL="vim"
alias python='ipython'
# alias tldr='tldr -s http://ramwin.com:9999/tldr/pages'
export PYTHONBREAKPOINT=ipdb.set_trace
alias pypi_deploy="rm dist/* && python3 setup.py sdist bdist_wheel && twine upload dist/*"
alias myfind="find . -not -path '*/site-packages/*' -not -path '*/node_modules/*'"
# export HTTPS_PROXY=singapore.ramwin.com:5979

PS1='[\[\e[37m\]#\##\[\e[01;32m\]\u@\[\e[00;31m\]$HOSTNAME:\W]\$\[\e[m\]'
# \[\e[37m\] 白色
PS1='[\[\e[37m\]#\[\e[00;33m\]\#\[\e[37m\]#\[\e[01;32m\]\u\[\e[36m\]@\[\e[00;31m\]$HOSTNAME:\[\e[34m\]\W\[\e[37m\]] \[\e[m\]'
# 添加git分支显示
parse_git_branch() {
     git branch 2> /dev/null | grep -v '* master' | grep -v '* main' | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1="[\[\e[37m\]#\[\e[00;33m\]\#\[\e[37m\]#\[\e[01;32m\]\u\[\e[36m\]@\[\e[00;31m\]$HOSTNAME:\[\033[32m\]\W\[\033[33m\]\$(parse_git_branch)\[\033[00m\]\[\e[37m\]] $ "

export TLDR_PAGES_SOURCE_LOCATION="file:///home/wangx/github/tldr/pages/"
export TLDR_PAGES_SOURCE_LOCATION=http://tldr.ramwin.com/pages/

# -F 允许超过一屏幕时才成less
export LESS="-R-F"
