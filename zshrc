# mac才需要
# eval "$(/opt/homebrew/bin/brew shellenv)"

# ZSH_THEME=3den.zsh
# . ~/github/other/ohmyzsh/themes/3den.zsh-theme
# ZSH_THEME=powerlevel9k
export LANG=zh_CN.UTF-8
# . $HOME/.bash_aliases
autoload -U colors && colors
export PS1="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%~ %{$reset_color%}%% "
PATH=\
/opt/homebrew/bin/\
:$HOME/Library/Python/3.9/bin/\
:$PATH
export HOST="Mac"
source $HOME/github/linux-reference/baserc

COLOR_DEF=$'%f'
COLOR_USR=$'%F{243}'  # 灰色
COLOR_DIR=$'%F{197}'    # 璀璨洋红
# COLOR_GIT=$'%F{39}'  # 亮蓝色
COLOR_GIT=$'%F{002}'  # 绿色
setopt PROMPT_SUBST
bindkey -e  # 下面2行的汇总
bindkey '^E' end-of-line
bindkey '^A' beginning-of-line
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

export PROMPT='${COLOR_USR}%n ${COLOR_DIR}%~ ${COLOR_GIT}$(show_branch.py)${COLOR_DEF} $ '

# export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
# export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
# export HOMEBREW_INSTALL_FROM_API=1
export https_proxy=http://localhost:1087
export HTTP_PROXY=http://localhost:1087
export HTTPS_PROXY=http://localhost:1087
alias pip="pip3.12"
