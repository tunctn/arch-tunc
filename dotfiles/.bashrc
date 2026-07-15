#
# ~/.bashrc
#

# ~/.local/bin for non-interactive ssh commands too (e.g. ssh arch wake-nyra)
export PATH="$HOME/.local/bin:$PATH"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"
