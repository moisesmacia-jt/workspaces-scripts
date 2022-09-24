#!/bin/env sh

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

#echo -e "\n\nInstalling SQlite 3.8...\n\n"
#
#if [ ! -d /opt/atomic ]; then
#  curl http://www6.atomicorp.com/channels/atomic/centos/7/x86_64/RPMS/atomic-sqlite-sqlite-3.8.5-3.el7.art.x86_64.rpm --output /tmp/atomic-sqlite-sqlite-3.8.5-3.el7.art.x86_64.rpm
#  curl http://www6.atomicorp.com/channels/atomic/centos/7/x86_64/RPMS/atomic-sqlite-sqlite-devel-3.8.5-3.el7.art.x86_64.rpm --output /tmp/atomic-sqlite-sqlite-devel-3.8.5-3.el7.art.x86_64.rpm
#
#  sudo yum install -y /tmp/atomic-sqlite-*.rpm
#  sudo mv /lib64/libsqlite3.so.0.8.6{,-3.17}
#  sudo cp /opt/atomic/atomic-sqlite/root/usr/lib64/libsqlite3.so.0.8.6 /lib64
#fi


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

if [ -f "\$HOME/.rbenv/rbenv.zsh" ]; then
  source "\$HOME/.rbenv/rbenv.zsh"
fi
EOF

echo -e "\n\nInstalling Yarn ...\n\n"

curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
sudo yum install -y nodejs
sudo curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
sudo yum install yarn -y

echo -e "\n\nInstalling RBenv ...\n\n"
rbenv_version=v1.2.0
rbenv_repo=https://github.com/rbenv/rbenv.git
rbenv_install_path=$HOME/.rbenv
rbenv_build_version=v20220610

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
  echo -e "bundler\nrake\nsolargraph\nforeman" > ${rbenv_install_path}/default-gems
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
  source ~/.rbenv/rbenv.bash
 
  echo -e "\n\n  > Installing ruby 3.1.2 (This could take ~15m)\n\n"
  rbenv install 3.1.2 && rbenv global 3.1.2
fi
