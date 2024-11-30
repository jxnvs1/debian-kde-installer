#!/usr/bin/env bash

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root (use sudo)."
   exit 1
fi

# Função para fazer backup e criar nova sources.list
configurar_sources_list() {
    echo "Fazendo backup da sources.list original..."
    if [[ -f /etc/apt/sources.list ]]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bkp
        echo "Backup feito com sucesso: /etc/apt/sources.list.bkp"
    else
        echo "Arquivo /etc/apt/sources.list não encontrado, prosseguindo sem backup."
    fi

    echo "Criando nova sources.list com os repositórios oficiais do Debian 12 'Bookworm'..."
    cat <<EOF > /etc/apt/sources.list
#############################################################################################################
#                                Repositórios Oficiais - Debian 12 "Bookworm"                               #
#############################################################################################################
## Para habilitar os repos de código fonte (deb-src) e Backports basta retirar a # da linha correspondente ##
#############################################################################################################

deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

## Debian Bookworm Backports
# deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware

##############################################################################################################
EOF

    echo "Nova sources.list criada com sucesso."
    
     # Atualiza a lista de pacotes após criar a nova sources.list
    echo "Atualizando a lista de pacotes com os novos repositórios..."
    apt update
}

# Função para instalar pacotes via APT
instalar_pacotes() {
    echo "Instalando pacotes: $*"
    apt install -y "$@"
    if [[ $? -ne 0 ]]; then
        echo "Erro ao instalar pacotes: $*"
        exit 1
    fi
}


# Função para baixar e instalar pacotes .deb
instalar_pacotes_deb() {
    cd /home/jonas/Downloads
    local pacotes_deb=(
        "https://github.com/fastfetch-cli/fastfetch/releases/download/2.23.0/fastfetch-linux-amd64.deb"
        "https://launchpad.net/veracrypt/trunk/1.26.14/+download/veracrypt-1.26.14-Debian-12-amd64.deb"
        "https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"
    )
    for pacote in "${pacotes_deb[@]}"; do
        wget "$pacote"
    done
    dpkg -i *.deb
    apt install -f -y

    # Limpar os pacotes .deb baixados
    rm -f *.deb
}

# Função para limpar configurações de rede no /etc/network/interfaces
configurar_networkmanager() {
    echo "Limpando as configurações de rede do /etc/network/interfaces..."
    
    # Faz um backup do arquivo atual antes de modificar
    cp /etc/network/interfaces /etc/network/interfaces.bkp
    
    # Limpa todo o conteúdo relacionado a interfaces de rede (exceto o loopback)
    cat <<EOF > /etc/network/interfaces
# Este arquivo foi modificado pelo script de instalação.
# Mantemos apenas a interface loopback para permitir que o NetworkManager gerencie outras conexões.

auto lo
iface lo inet loopback

# Outras interfaces serão gerenciadas pelo NetworkManager.
EOF

    echo "Configurações de rede removidas. Backup criado em /etc/network/interfaces.bkp"
}

# Função principal de instalação
main_instalacao() {
    # Instalar plasma e programas
    instalar_pacotes plasma-desktop sddm ark dolphin dolphin-plugins kcalc kate plasma-pa konsole gwenview \
    okular kde-spectacle

    instalar_pacotes mpv keepassxc thunderbird thunderbird-l10n-pt-br adb fastboot liblz4-tool curl \
    fonts-noto-color-emoji obs-studio exa bat ufw tlp aspell-pt-br zsh audacious ncdu git telegram-desktop \
    unzip unrar-free rar timeshift firefox-esr firefox-esr-l10n-pt-br

    # Ativar suporte ao Flatpak e instalar pacotes Flatpak
    instalar_pacotes flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.rtosta.zapzap org.jdownloader.JDownloader com.stremio.Stremio

    # Baixar e instalar pacotes .deb
    instalar_pacotes_deb

    fc-cache -f -v    # Atualiza o cache de fontes
    gtk-update-icon-cache /usr/share/icons/hicolor   # Atualiza o cache de ícones
}

# Função para configurar o ufw
ufw-config() {
    # Configura o UFW para bloquear todas as entradas e permitir todas as saídas
    ufw default deny incoming
    ufw default allow outgoing

    # Permite as portas necessárias para o KDE Connect
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp

    # Ativa o UFW
    ufw enable

    # Recarrega as regras do UFW
    ufw reload

    # Mostra o status do UFW
    ufw status verbose
}

# Execução das funções
configurar_sources_list
main_instalacao
configurar_networkmanager
ufw-config


# Reiniciar o sistema após todas as instalações
echo "Instalação concluída com sucesso! O sistema será reiniciado em 10 segundos."
sleep 10
reboot
