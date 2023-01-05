#!/bin/env sh

echo "\n\nInstalling common packages ...\n\n"

sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y
sudo apt install aptitude && sudo aptitude dist-upgrade -y
sudo aptitude install htop jq aptitude ca-certificates curl gnupg lsb-release \
	      sqlite3 sqlite3-tools sqlitebrowser libsqlite3-dev \
	      libssl-dev zsh git build-essential libpq-dev zlib1g-dev libyaml-dev \
	      language-pack-gnome-es language-pack-es chromium-browser wget -y

sudo snap install dbeaver-ce

# increase inotify watches
if [ ! -f /etc/sysctl.d/10-inotify.conf ]; then
  sudo sh -c 'echo "fs.inotify.max_user_watches=528288" > /etc/sysctl.d/10-inotify.conf'
  sudo sysctl -p
fi

echo "\n\nInstalling Docker ...\n\n"

if [ ! -f "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
fi

if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo sh -c "echo '{\"dns\": [\"8.8.8.8\", \"8.8.4.4\"]}' > /etc/docker/daemon.json"


# add current user to docker
aws_user=$(whoami)
sudo usermod -aG docker $aws_user


echo "\n\nInstalling Visual Studio Code ...\n\n"

if [ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
fi

if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
  sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
fi

sudo aptitude update; sudo aptitude install code -y


echo "\n\nInstalling Zsh ...\n\n"

ohmyzsh_repo='https://github.com/robbyrussell/oh-my-zsh.git'
ohmyzsh_install_path=${HOME}/.oh-my-zsh

if [ ! -d "$ohmyzsh_install_path" ]; then
  git clone $ohmyzsh_repo $ohmyzsh_install_path
  mkdir -p ${ohmyzsh_install_path}/custom/themes
fi

# third party plugins:
for plugin in zsh-syntax-highlighting zsh-autosuggestions zsh-completions; do
  plugin_dir=${ohmyzsh_install_path}/custom/plugins/${plugin}

  if [ -d "$plugin_dir" ]; then
    cd $plugin_dir && git fetch -p && git pull --rebase origin master && cd -
  else
    git clone https://github.com/zsh-users/${plugin}.git $plugin_dir
  fi
done

cat << EOF > ~/.zshrc
ZSH=\$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
DISABLE_AUTO_UPDATE=false

zstyle ":completion:*:git-checkout:*" sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors \${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always \$realpath'

plugins=(common-aliases git git-extras gitignore rake docker copybuffer copypath copyfile zsh-syntax-highlighting zsh-autosuggestions)

export TERM="xterm-256color"
export SHELL=/usr/bin/zsh

source \$ZSH/oh-my-zsh.sh

# reload completions
autoload -Uz compinit && compinit

if [ -f "\$HOME/.rbenv/rbenv.zsh" ]; then
  source "\$HOME/.rbenv/rbenv.zsh"
fi
EOF


echo "\n\nInstalling Yarn ...\n\n"

curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
sudo aptitude install -y nodejs
sudo curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
sudo aptitude install yarn -y


echo "\n\nInstalling RBenv ...\n\n"

rbenv_version=v1.2.0
rbenv_repo=https://github.com/rbenv/rbenv.git
rbenv_install_path=$HOME/.rbenv
rbenv_build_version=v20221225

if [ -d "$rbenv_install_path" ]; then
  rbenv update
else
  git clone $rbenv_repo $rbenv_install_path -b $rbenv_version

  # install plugins
  mkdir -p ${rbenv_install_path}/plugins

  # ruby-build
  cd ${rbenv_install_path}/plugins && git clone https://github.com/rbenv/ruby-build.git -b $rbenv_build_version
  # rbenv-default-gems
  cd ${rbenv_install_path}/plugins && git clone https://github.com/rbenv/rbenv-default-gems.git
  echo "bundler\nrake\nsolargraph\nforeman" > ${rbenv_install_path}/default-gems
  # rbenv-update
  cd ${rbenv_install_path}/plugins && git clone https://github.com/rkh/rbenv-update.git

  cat << EOF > ~/.rbenv/rbenv.bash
if [ -d "\$HOME/.rbenv" ]; then
  export PATH=\$HOME/.rbenv/bin:\$PATH;
  export RBENV_ROOT=\$HOME/.rbenv;
  eval "\$(rbenv init -)";
fi
EOF

  cat << EOF > ~/.rbenv/rbenv.zsh
if [ -d "\$HOME/.rbenv" ]; then
  export PATH=\$HOME/.rbenv/bin:\$PATH;
  export RBENV_ROOT=\$HOME/.rbenv;
  eval "\$(rbenv init - zsh)";
  . \$RBENV_ROOT/completions/rbenv.zsh
fi
EOF

  echo "source ~/.rbenv/rbenv.bash" >> ~/.bashrc
fi
