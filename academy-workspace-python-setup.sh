#!/bin/bash

echo -e "\n\nInstalling common packages ...\n\n"

sudo yum check-update && sudo yum update -y
sudo yum install -y htop jq sqlite-devel openssl-devel zsh git
sudo yum groupinstall -y "Development Tools"
sudo amazon-linux-extras install postgresql14
sudo yum install postgresql-devel -y

# increase inotify watches
if [ ! -f /etc/sysctl.d/10-inotify.conf ]; then
  sudo sh -c 'echo "fs.inotify.max_user_watches=528288" > /etc/sysctl.d/10-inotify.conf'
  sudo sysctl -p
fi


echo -e "\n\nInstalling Google Chrome ...\n\n"
curl https://intoli.com/install-google-chrome.sh | sudo bash


echo -e "\n\nInstalling docker ...\n\n"

aws_user=$(whoami)
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -a -G docker $aws_user

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo sh -c "echo '{\"dns\": [\"8.8.8.8\", \"8.8.4.4\"]}' > /etc/docker/daemon.json"


echo -e "\n\nInstalling VSCode ...\n\n"

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
sudo yum check-update
sudo yum install code -y


echo -e "\n\nInstalling Zsh...\n\n"

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

if [ -f "\$HOME/.pyenv/pyenv.zsh" ]; then
  source "\$HOME/.pyenv/pyenv.zsh"
fi
EOF


echo -e "\n\nInstalling Yarn ...\n\n"

curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
sudo yum install -y nodejs
sudo curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
sudo yum install yarn -y


echo -e "\n\nInstalling pyenv ...\n\n"
pyenv_version=v2.3.4
pyenv_repo=https://github.com/pyenv/pyenv.git
pyenv_install_path=$HOME/.pyenv

sudo yum install -y \
	bzip2-devel \
	ncurses-devel \
	libffi-devel \
	readline-devel \
	openssl11-devel \
	tk-devel \
	xz-devel

if [ -d "$pyenv_install_path" ]; then
  cd ${pyenv_install_path} && git fetch -p && git checkout tags/$pyenv_version && cd -
  cd ${pyenv_install_path}/plugins/pyenv-virtualenv && git fetch -p && git pull --rebase origin master && cd -
else
  git clone $pyenv_repo $pyenv_install_path -b $pyenv_version
  git clone https://github.com/pyenv/pyenv-virtualenv.git $pyenv_install_path/plugins/pyenv-virtualenv
  
  cat << EOF > ~/.pyenv/pyenv.bash 
if [ -d "\$HOME/.pyenv" ]; then
  export PATH=\$HOME/.pyenv/bin:\$PATH;
  export PYENV_ROOT=\$HOME/.pyenv;

  eval "\$(pyenv init --path)";
  eval "\$(pyenv init -)";
  eval "\$(pyenv virtualenv-init -)";
fi
EOF

  cat << EOF > ~/.pyenv/pyenv.zsh 
if [ -d "\$HOME/.pyenv" ]; then
  export PATH=\$HOME/.pyenv/bin:\$PATH;
  export PYENV_ROOT=\$HOME/.pyenv;

  eval "\$(pyenv init --path)";
  eval "\$(pyenv init -)";
  eval "\$(pyenv virtualenv-init -)";
fi
EOF

  echo "source ~/.pyenv/pyenv.bash" >> ~/.bashrc
  source ~/.pyenv/pyenv.bash
fi
