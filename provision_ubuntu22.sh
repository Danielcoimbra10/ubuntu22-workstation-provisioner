#!/usr/bin/env bash
# ==============================================================================
# Título: Ubuntu 22.04 Workstation Provisioner & Hardening Tool
# Autor: Daniel Coimbra de Oliveira
# Versão: 1.0.0
# Descrição: Script unificado para provisionamento de pacotes, configuração de
#            rede/proxy, hardening de SSH, bloqueio de armazenamento USB e
#            padronização de políticas de segurança no Mozilla Firefox.
# ==============================================================================

# ==============================================================================
# 0. VARIÁVEIS DE CONFIGURAÇÃO (PARAMETRIZE CONFORME SEU AMBIENTE)
# ==============================================================================
SSH_NEW_PORT="32800"                                       # Porta personalizada para o serviço SSH
SMB_SERVER="servidor-arquivos.local"                       # Endereço do servidor de arquivos Samba/SMB
FIREFOX_HOMEPAGE="https://intranet.exemplo.local"          # URL da página inicial corporativa do Firefox
PROXY_HOST="proxy.exemplo.local"                           # Endereço do servidor proxy HTTP/HTTPS
PROXY_PORT="8080"                                          # Porta do servidor proxy
PROXY_TYPE="1"                                             # Tipo de proxy no Firefox (1 = configuração manual)
NO_PROXY_LIST="127.0.0.1,localhost,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local" # Exceções de proxy
ENABLE_USB_BLOCK="false"                                   # Defina como "true" para bloquear pendrives USB

# ==============================================================================
# 1. VERIFICAÇÃO DE PRIVILÉGIOS ADMINISTRATIVOS
# ==============================================================================
echo "======================================================"
echo "    INICIANDO PROVISIONAMENTO - UBUNTU 22.04 LTS      "
echo "======================================================"

# Verifica se o UID do usuário atual é diferente de 0 (root)
if [ "$(id -u)" -ne 0 ]; then
    # Exibe mensagem de erro caso não tenha sido executado com sudo/root
    echo "[ERRO] Este script precisa ser executado como root ou via sudo."
    # Encerra a execução com código de erro 1
    exit 1
fi

# Identifica o usuário real que invocou o sudo (ou usa root caso logado diretamente)
TARGET_USER="${SUDO_USER:-root}"

# ==============================================================================
# 2. ATUALIZAÇÃO DO SISTEMA E INSTALAÇÃO DE PACOTES PADRÃO
# ==============================================================================
echo "[1/6] Atualizando repositórios e instalando pacotes padrão..."

# Atualiza a lista de pacotes disponíveis nos repositórios configurados
apt-get update -y

# Remove instalações antigas ou conflitantes do OpenJDK, se existirem
apt-get remove --purge -y openjdk-*

# Instala ferramentas administrativas, utilitários de rede, diagnóstico e produtividade
apt-get install -y \
    openssh-server \
    curl \
    synaptic \
    gtklp \
    catfish \
    mc \
    iftop \
    htop \
    fonts-crosextra-carlito \
    grsync \
    inxi \
    vlc \
    net-tools \
    gparted \
    exfat-fuse \
    pdfsam \
    recoll \
    inkscape \
    cups-pdf \
    diffpdf \
    xpad \
    libjbig0 \
    libtiff5 \
    fontconfig-config \
    libfontconfig1 \
    ntpdate \
    dmidecode \
    openssl \
    pciutils \
    smartmontools \
    read-edid \
    bleachbit

# Verifica se a suíte LibreOffice está instalada no sistema
if ! command -v libreoffice &> /dev/null; then
    # Instala o LibreOffice caso não seja encontrado no PATH
    echo "LibreOffice não encontrado. Instalando suíte office..."
    apt-get install -y libreoffice
else
    # Informa que o pacote já está presente
    echo "LibreOffice já está instalado."
fi

# Aplica atualizações de segurança e versões recentes aos pacotes instalados
apt-get upgrade -y

# Remove dependências órfãs e limpa o cache local de arquivos .deb baixados
apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y

# Garante que nenhum pacote ficou pendente de configuração no dpkg
dpkg --configure -a

echo "[OK] Pacotes instalados e sistema atualizado."
echo "------------------------------------------------------"

# ==============================================================================
# 3. HARDENING DO SERVIÇO SSH
# ==============================================================================
echo "[2/6] Configurando serviço SSH..."

# Define o caminho do arquivo principal de configuração do daemon SSH
SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# Verifica se o arquivo de configuração existe antes de tentar alterá-lo
if [ -f "$SSH_CONFIG_FILE" ]; then
    # Cria uma cópia de segurança do arquivo original antes da modificação
    cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.bak"
    # Substitui a linha comentada "#Port 22" pela porta personalizada definida
    sed -i "s/^#\?Port .*/Port ${SSH_NEW_PORT}/" "$SSH_CONFIG_FILE"
    # Reinicia o serviço sshd para aplicar a nova porta imediatamente
    systemctl restart sshd
    echo "[OK] Porta SSH alterada para ${SSH_NEW_PORT} e serviço reiniciado."
else
    # Alerta caso o servidor SSH não tenha sido encontrado
    echo "[AVISO] Arquivo ${SSH_CONFIG_FILE} não encontrado."
fi

echo "------------------------------------------------------"

# ==============================================================================
# 4. CONFIGURAÇÃO DE MARCADORES DE REDE (SAMBA / GTK-3.0)
# ==============================================================================
echo "[3/6] Configurando marcadores de diretórios de rede..."

# Função auxiliar para gravar os compartilhamentos SMB no arquivo bookmarks
aplicar_marcadores_gtk() {
    # Recebe o diretório base de configuração GTK como primeiro parâmetro
    local gtk_dir="$1"
    # Garante que o diretório exista
    mkdir -p "$gtk_dir"
    # Verifica a flag de controle para evitar duplicação caso o script rode novamente
    if [ ! -f "$gtk_dir/.bookmarks_provisioned" ]; then
        # Adiciona os atalhos de compartilhamento de rede ao gerenciador de arquivos
        echo "smb://${SMB_SERVER}/grupos/ Grupos" >> "$gtk_dir/bookmarks"
        echo "smb://${SMB_SERVER}/publico/ Publico" >> "$gtk_dir/bookmarks"
        echo "smb://${SMB_SERVER}/temporario/ Temporario" >> "$gtk_dir/bookmarks"
        # Cria arquivo marcador indicando que a configuração já foi aplicada
        touch "$gtk_dir/.bookmarks_provisioned"
    fi
}

# Itera sobre todos os diretórios de usuários existentes em /home
for user_home in /home/*; do
    # Verifica se o item é realmente um diretório de usuário válido
    if [ -d "$user_home" ]; then
        # Aplica os marcadores na pasta de configuração do usuário
        aplicar_marcadores_gtk "$user_home/.config/gtk-3.0"
        # Ajusta o proprietário dos arquivos criados para o respectivo usuário
        owner=$(basename "$user_home")
        chown -R "$owner":"$owner" "$user_home/.config/gtk-3.0" 2>/dev/null
    fi
done

# Aplica os mesmos marcadores no diretório /etc/skel para futuros usuários criados
aplicar_marcadores_gtk "/etc/skel/.config/gtk-3.0"

echo "[OK] Marcadores de rede configurados."
echo "------------------------------------------------------"

# ==============================================================================
# 5. PADRONIZAÇÃO E SEGURANÇA DO MOZILLA FIREFOX (HOMEPAGE, PROXY E SENHAS)
# ==============================================================================
echo "[4/6] Aplicando políticas de segurança e proxy no Mozilla Firefox..."

# Função que injeta preferências corporativas em um perfil específico do Firefox
configurar_perfil_firefox() {
    # Recebe o diretório do perfil do Firefox como parâmetro
    local profile_path="$1"
    # Define o caminho completo do arquivo user.js (preferências persistentes)
    local user_js="${profile_path}/user.js"
    # Define o caminho do arquivo logins.json (banco de senhas salvas)
    local logins_file="${profile_path}/logins.json"

    # Remove o arquivo de senhas armazenadas, caso exista, por política de segurança
    if [ -f "$logins_file" ]; then
        rm -f "$logins_file"
    fi

    # Escreve as diretivas de página inicial, proxy e bloqueio de senhas no user.js
    cat <<EOF > "$user_js"
// Configurações padronizadas pelo script de provisionamento
user_pref("browser.startup.homepage", "${FIREFOX_HOMEPAGE}");
user_pref("network.proxy.type", ${PROXY_TYPE});
user_pref("network.proxy.http", "${PROXY_HOST}");
user_pref("network.proxy.http_port", ${PROXY_PORT});
user_pref("network.proxy.ssl", "${PROXY_HOST}");
user_pref("network.proxy.ssl_port", ${PROXY_PORT});
user_pref("network.proxy.backup.ssl", "${PROXY_HOST}");
user_pref("network.proxy.backup.ssl_port", ${PROXY_PORT});
user_pref("network.proxy.no_proxies_on", "${NO_PROXY_LIST}");
user_pref("network.share_proxy_settings", true);
user_pref("signon.rememberSignons", false);
user_pref("signon.storeWhenAutocompleteOff", false);
EOF
}

# Percorre todos os usuários em /home para localizar perfis do Firefox existentes
for user_home in /home/*; do
    # Verifica se existe a pasta de perfis .mozilla/firefox para o usuário
    if [ -d "$user_home/.mozilla/firefox" ]; then
        # Itera sobre cada subpasta de perfil (ex: *.default-release)
        for profile_dir in "$user_home/.mozilla/firefox"/*; do
            # Verifica se é um diretório válido contendo prefs.js
            if [ -d "$profile_dir" ] && [ -f "$profile_dir/prefs.js" ]; then
                # Aplica as políticas ao perfil encontrado
                configurar_perfil_firefox "$profile_dir"
                # Garante que o arquivo user.js pertença ao dono da pasta home
                owner=$(basename "$user_home")
                chown "$owner":"$owner" "$profile_dir/user.js" 2>/dev/null
            fi
        done
    fi
done

# Cria template padrão no /etc/skel para novos usuários do sistema
mkdir -p "/etc/skel/.mozilla/firefox"
configurar_perfil_firefox "/etc/skel/.mozilla/firefox"

echo "[OK] Políticas do Firefox aplicadas com sucesso."
echo "------------------------------------------------------"

# ==============================================================================
# 6. RESTRIÇÃO DE DISPOSITIVOS DE ARMAZENAMENTO USB (OPCIONAL)
# ==============================================================================
echo "[5/6] Verificando política de armazenamento USB..."

# Verifica se a variável de controle está habilitada para bloquear USB
if [ "$ENABLE_USB_BLOCK" = "true" ]; then
    # Cria regra no modprobe redirecionando o carregamento do módulo usb_storage para /bin/true
    echo "install usb_storage /bin/true" > /etc/modprobe.d/disable-usb-storage.conf
    # Remove imediatamente os módulos de armazenamento USB da memória do kernel, se carregados
    modprobe -r uas usb_storage 2>/dev/null
    echo "[OK] Armazenamento USB desabilitado no kernel."
else
    # Informa que a política não foi ativada nesta execução
    echo "[INFO] Bloqueio de USB mantido inativo (ENABLE_USB_BLOCK=false)."
fi

echo "------------------------------------------------------"

# ==============================================================================
# 7. FINALIZAÇÃO
# ==============================================================================
echo "[6/6] Provisionamento do Ubuntu 22.04 concluído com sucesso!"
exit 0
