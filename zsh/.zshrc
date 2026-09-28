# Cabecera al abrir foot: fastfetch (config en ~/.config/fastfetch/config.jsonc).
# Va antes del instant prompt de p10k para que no avise de salida en consola.
# No sale en tmux, ssh ni en un zsh lanzado dentro de otro.
# El color de acento lo genera ~/.config/sway/scripts/theme.sh (Super+Alt+T).
ff() {
  local f=~/.config/fastfetch/accent
  local -a opts
  [[ -r $f ]] && opts=(--color "$(<$f)")
  fastfetch "${opts[@]}" "$@"
}
if [[ $TERM == foot* && -z $TMUX && -z $SSH_CONNECTION && -z $_HEADER_SHOWN ]] \
   && (( $+commands[fastfetch] )); then
  export _HEADER_SHOWN=1
  ff
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Basicos de zsh (sin Oh My Zsh, no vienen por defecto) ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt AUTO_CD

# Mostrar la cabecera de nuevo cuando se quiera: ff (funcion definida arriba)

autoload -Uz compinit
compinit

# --- Teclas de navegacion (Inicio/Fin/Supr/Ctrl+flechas) ---
# Sin Oh My Zsh, ZLE no las vincula solo; usamos terminfo para que
# funcionen sea cual sea el TERM (foot, xterm, etc.)
zmodload zsh/terminfo
bindkey -e
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}"  ]] && bindkey "${terminfo[kend]}"  end-of-line
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char
[[ -n "${terminfo[kich1]}" ]] && bindkey "${terminfo[kich1]}" overwrite-mode
[[ -n "${terminfo[kpp]}"   ]] && bindkey "${terminfo[kpp]}"   beginning-of-buffer-or-history
[[ -n "${terminfo[knp]}"   ]] && bindkey "${terminfo[knp]}"   end-of-buffer-or-history
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-history
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-history

# Ctrl+flechas: saltar palabra (secuencias estilo xterm que envia foot)
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[3;5~" kill-word

# Variantes habituales de Inicio/Fin/Supr, por si terminfo no coincide
# con lo que el terminal envia realmente (modo aplicacion vs normal)
bindkey "^[[H"  beginning-of-line
bindkey "^[[1~" beginning-of-line
bindkey "^[OH"  beginning-of-line
bindkey "^[[F"  end-of-line
bindkey "^[[4~" end-of-line
bindkey "^[OF"  end-of-line
bindkey "^[[3~" delete-char

# --- Powerlevel10k ---
source ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme

# Para personalizar el prompt, ejecuta `p10k configure` o edita ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
