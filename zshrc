# mac才需要
# eval "$(/opt/homebrew/bin/brew shellenv)"

# ZSH_THEME=3den.zsh
# . ~/github/other/ohmyzsh/themes/3den.zsh-theme
# ZSH_THEME=powerlevel9k
# source ~/.bash_aliases
# export PS1="%B%F{034}%n@%B%F{001}%m%f%b:%B%F{002}%~%B%F{037}%#%f%b"
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
