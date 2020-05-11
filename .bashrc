#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

neofetch

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias ls='ls --color=auto'
export PS1="\[\e[34m\]\u\[\e[m\]@\h \[\e[34m\]\w\[\e[m\] \$ "

