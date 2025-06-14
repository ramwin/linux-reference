source $HOME/github/linux-reference/baserc

# 用来在windows目录下用windows的git
# cd() {
#     builtin cd "$1"
#     current_path=`pwd`
#     if [[ $current_path == /mnt/d/* ]]
#     then
#         alias 'git="git.exe"'
#     else
#         alias git="git"
#     fi
# }

export TLDR_CACHE_ENABLED=1
export TLDR_CACHE_MAX_AGE=24

# 翻墙用
alias ramwinchrom='chromium-browser --proxy-server="socks5://127.0.0.1:1080" --proxy-pac-url="file:///home/wangx/github/Public/proxy_gfw.pac"&'

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

export TERM="xterm-color"
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

export NODE_PATH="${HOME}/node/lib/node_modules"

# 目录快捷方式
alias github='cd ~/github'

# python
alias pep='pep8 --max-line-length=120'
alias gitflake='git status -s | grep .py | xargs flake8'
# xset m 0 1

# django
alias dshell="python manage.py shell"

# mac 的设置
export CLICOLOR=1
# settitle coding
export LANGUAGE='en_US.UTF-8 git'
export VISUAL="vim"
export PYTHONBREAKPOINT=ipdb.set_trace
alias myfind="find . -not -path '*/site-packages/*' -not -path '*/node_modules/*'"
# alias bat="batcat"

# PS1='[\[\e[37m\]#\##\[\e[01;32m\]\u@\[\e[00;31m\]$HOSTNAME:\W]\$\[\e[m\]'
# \[\e[37m\] 白色
# PS1='[\[\e[37m\]#\[\e[00;33m\]\#\[\e[37m\]#\[\e[01;32m\]\u\[\e[36m\]@\[\e[00;31m\]$HOSTNAME:\[\e[34m\]\W\[\e[37m\]] \[\e[m\]'
# 添加git分支显示
parse_git_branch() {
    show_branch.py
    # git branch --show-current 2>/dev/null
    # git branch 2> /dev/null | grep -v '* master' | grep -v '* main' | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1="[\[\e[37m\]#\[\e[00;33m\]\#\[\e[37m\]#\[\e[01;32m\]\u\[\e[36m\]@\[\e[00;31m\]$HOSTNAME:\[\033[32m\]\W\[\033[33m\]\$(parse_git_branch)\[\033[00m\]\[\e[37m\] $ "


# -F 允许超过一屏幕时才成less
export LESS="-R-F"
export AIRFLOW_HOME=~/airflow

export AIRFLOW_HOME=/home/wangx/github/airflowtest
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow_user:airflow_pass@localhost/airflow_db
export MYPYPATH=~/github/python-reference/stubs

export HATCH_INDEX_USER="__token__"
export CMAKE_CXX_COMPILER=clang++
export CMAKE_C_COMPILER=clang


tail () { command tail -n 20 "$@"; }
head () { command head -n 20 "$@"; }
