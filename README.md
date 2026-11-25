# Ubuntu 22.04 Workstation Provisioner & Hardening Tool

Ferramenta desenvolvida em Shell Script (Bash) para automatizar o provisionamento, o endurecimento de segurança (*hardening*) e a padronização de pós-instalação em estações de trabalho baseadas no **Ubuntu 22.04 LTS (Jammy Jellyfish)**.

## Visão Geral

Em ambientes corporativos e institucionais com múltiplas estações de trabalho, a configuração manual pós-instalação demanda tempo elevado e está sujeita a inconsistências operacionais. Este software automatiza o ciclo completo de preparação do sistema operacional, reduzindo o tempo de *deploy* e garantindo conformidade técnica e de segurança entre as máquinas.

## Principais Funcionalidades

- **Atualização e Saneamento de Pacotes:** Remoção de pacotes legados conflitantes, atualização automatizada de índices APT, instalação não interativa de utilitários essenciais de sistema, rede, diagnóstico e suíte LibreOffice, além de limpeza de cache.
- **Hardening do Serviço SSH:** Backup automático do arquivo `sshd_config`, alteração parametrizada da porta padrão do daemon SSH e reinicialização controlada do serviço.
- **Padronização de Rede e Compartilhamentos (SMB/GTK-3.0):** Configuração idempotente de marcadores de diretórios de rede para usuários existentes e para o diretório template (`/etc/skel`).
- **Políticas de Segurança no Mozilla Firefox:** Configuração automatizada de página inicial corporativa, proxy manual de rede (HTTP/HTTPS/SSL), lista de exceções e bloqueio persistente do armazenamento local de senhas (`signon.rememberSignons`).
- **Controle de Dispositivos USB:** Módulo opcional para restrição de carregamento de módulos de armazenamento em massa (`usb_storage` / `uas`) no kernel Linux.

## Pré-requisitos

- Sistema Operacional: Ubuntu 22.04 LTS (ou derivados compatíveis com APT e systemd).
- Privilégios de superusuário (`root` ou `sudo`).
- Acesso aos repositórios APT configurados.

## Configuração e Uso

1. Clone o repositório:
   ```bash
   git clone [https://github.com/Danielcoimbra10/ubuntu22-workstation-provisioner.git](https://github.com/Danielcoimbra10/ubuntu22-workstation-provisioner.git)
   cd ubuntu22-workstation-provisioner
