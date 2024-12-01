#!/usr/bin/env bash

################################################################################
# Script: debian-kde-installer.sh
# Descrição: Este script automatiza a configuração inicial de um sistema Debian
#            com o ambiente gráfico KDE Plasma.
# Autor: Jonas Santana
# Licença: MIT
# Versão: 1.0
################################################################################

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script precisa ser executado como root (use sudo)."
    exit 1
fi

# Função: Configura o arquivo sources.list para repositórios do Debian 12 "Bookworm"
configurar_sources_list() {
    echo "Fazendo backup da sources.list original..."
    if [[ -f /etc/apt/sources.list ]]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bkp
        echo "Backup criado: /etc/apt/sources.list.bkp"
    else
        echo "Arquivo /etc/apt/sources.list não encontrado, prosseguindo sem backup."
    fi

    echo "Criando nova sources.list..."
    cat <<EOF > /etc/apt/sources.list
#############################################################################################################
#                                Repositórios Oficiais - Debian 12 "Bookworm"                               #
#############################################################################################################
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

    echo "Nova sources.list criada com sucesso."

    # Atualiza a lista de pacotes
    echo "Atualizando a lista de pacotes..."
    apt update
}

# Função: Instala pacotes usando o APT
instalar_pacotes() {
    echo "Instalando pacotes: $*"
    apt install -y "$@"
    if [[ $? -ne 0 ]]; then
        echo "Erro ao instalar pacotes: $*"
        exit 1
    fi
}

# Função: Baixa e instala pacotes .deb diretamente da internet
instalar_pacotes_deb() {
    echo "Baixando e instalando pacotes .deb..."
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

    # Remove pacotes .deb após instalação
    rm -f *.deb
}

# Função: Limpa configurações de rede e configura NetworkManager
configurar_networkmanager() {
    echo "Limpando as configurações de rede..."
    cp /etc/network/interfaces /etc/network/interfaces.bkp
    cat <<EOF > /etc/network/interfaces
# Interface loopback
auto lo
iface lo inet loopback

# Outras interfaces gerenciadas pelo NetworkManager
EOF
    echo "Configurações de rede atualizadas. Backup criado: /etc/network/interfaces.bkp"
}

# Função: Configura e ativa o UFW
ufw_config() {
    echo "Configurando o firewall UFW..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp
    ufw enable
    ufw reload
    ufw status verbose
}

# Função principal: Instala todos os pacotes e configura o sistema
main_instalacao() {
    echo "Iniciando instalação e configuração do sistema..."

    # Instalar pacotes KDE Plasma e utilitários
    instalar_pacotes plasma-desktop sddm ark dolphin dolphin-plugins kcalc kate plasma-pa konsole gwenview \
    okular kde-spectacle mpv keepassxc thunderbird thunderbird-l10n-pt-br adb fastboot liblz4-tool curl \
    fonts-noto-color-emoji obs-studio exa bat ufw tlp aspell-pt-br zsh audacious ncdu git telegram-desktop \
    unzip unrar-free rar timeshift firefox-esr firefox-esr-l10n-pt-br

    # Configurar Flatpak e instalar pacotes Flatpak
    instalar_pacotes flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.rtosta.zapzap org.jdownloader.JDownloader com.stremio.Stremio

    # Baixar e instalar pacotes .deb
    instalar_pacotes_deb

    # Atualizar cache de fontes e ícones
    fc-cache -f -v
    gtk-update-icon-cache /usr/share/icons/hicolor
}

# Execução das funções
configurar_sources_list
main_instalacao
configurar_networkmanager
ufw_config

# Finalização
echo "Instalação concluída. O sistema será reiniciado em 10 segundos."
sleep 10
reboot
