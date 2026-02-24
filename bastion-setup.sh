#!/bin/bash

# ═══════════════════════════════════════════════════════════
# Bastion Proxy - Script de Gestión con SSH Bastion
# ═══════════════════════════════════════════════════════════

PROJECT_NAME="bastion-proxy"
DOMAIN="servidorgp.somosdelprieto.com"
BASE_DOMAIN="servidorgp.somosdelprieto.com"
ALUMNOS_CSV="alumnos.csv"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# SSH Bastion
BAST_USER="bastion-proxy"
BAST_SSH_DIR="/home/${BAST_USER}/.ssh"
BAST_CONFIG="/etc/ssh/sshd_config.d/bastion.conf"

init_project() {
    echo -e "${BLUE}🚀 Creando estructura de proyecto...${NC}"
    echo ""
    
    # Crear directorios
    mkdir -p ${PROJECT_NAME}/{nginx,config-manager/templates}
    echo -e "${GREEN}✅ Directorios creados${NC}"
    
    # Crear archivo de alumnos si no existe
    if [ ! -f "${ALUMNOS_CSV}" ]; then
        cat > ${ALUMNOS_CSV} << 'EOFCSV'
# Archivo de configuración de alumnos
# Formato: usuario,ip
# Una línea por alumno
alonso,192.168.5.45
victor,192.168.5.41
orwin,192.168.5.43
mcarmen,192.168.5.42
mikel,192.168.5.46
luismi,192.168.5.44
miguel,192.168.5.47
EOFCSV
        echo -e "${GREEN}✅ Archivo alumnos.csv creado${NC}"
    fi
    
    # Crear .env
    STUDENTS_LINE=$(grep -v '^#' ${ALUMNOS_CSV} | grep -v '^$' | awk -F',' '{printf "%s:%s,", $1, $2}' | sed 's/,$//')
    cat > ${PROJECT_NAME}/.env << EOF
# Configuración
DOMAIN=${DOMAIN}

# Alumnos (generado automáticamente desde alumnos.csv)
STUDENTS=${STUDENTS_LINE}
EOF
    echo -e "${GREEN}✅ .env creado ($(grep -v '^#' ${ALUMNOS_CSV} | grep -v '^$' | wc -l | tr -d ' ') alumnos)${NC}"
    
    # Crear docker-compose.yml
    cat > ${PROJECT_NAME}/docker-compose.yml << 'EOF'
services:
  nginx-proxy:
    build: ./nginx
    container_name: nginx-proxy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
    environment:
      - DOMAIN=${DOMAIN}
    depends_on:
      - config-manager

  config-manager:
    build: ./config-manager
    container_name: config-manager
    volumes:
      - ./nginx/conf.d:/output
    environment:
      - STUDENTS=${STUDENTS}
      - DOMAIN=${DOMAIN}
    command: ["python", "generate.py"]
    restart: "no"
EOF
    echo -e "${GREEN}✅ docker-compose.yml creado${NC}"
    
    # Crear Nginx Dockerfile
    cat > ${PROJECT_NAME}/nginx/Dockerfile << 'EOF'
FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # Crear nginx.conf
    cat > ${PROJECT_NAME}/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent"';
    
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    
    include /etc/nginx/conf.d/*.conf;
}

stream {
    # HTTPS Proxy con SNI
    ssl_preread on;
    
    map $ssl_preread_server_name $backend {
        include /etc/nginx/conf.d/stream-map-entries.conf;
    }
    
    server {
        listen 443;
        proxy_pass $backend;
        proxy_buffer_size 16k;
    }
    
    # SSH Proxy - Puertos dedicados por alumno
    include /etc/nginx/conf.d/ssh-proxy.conf;
}
EOF
    
    # Crear entrypoint.sh
    cat > ${PROJECT_NAME}/nginx/entrypoint.sh << 'EOF'
#!/bin/sh
set -e

echo "⏳ Esperando configuraciones..."
while [ ! -f /etc/nginx/conf.d/stream-map-entries.conf ] || [ ! -f /etc/nginx/conf.d/ssh-proxy.conf ]; do
    sleep 2
done

echo "✅ Configuraciones listas"
nginx -t
exec "$@"
EOF
    chmod +x ${PROJECT_NAME}/nginx/entrypoint.sh
    echo -e "${GREEN}✅ Nginx configurado${NC}"
    
    # Crear Config Manager Dockerfile
    cat > ${PROJECT_NAME}/config-manager/Dockerfile << 'EOF'
FROM python:3.11-alpine

WORKDIR /app
RUN pip install --no-cache-dir jinja2

COPY generate.py /app/
COPY templates/ /app/templates/

CMD ["python", "generate.py"]
EOF
    
    # Crear generate.py
    cat > ${PROJECT_NAME}/config-manager/generate.py << 'EOF'
#!/usr/bin/env python3
import os, sys
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

STUDENTS = os.getenv('STUDENTS', '')
DOMAIN = os.getenv('DOMAIN', 'dockergp.ip-ddns.com')
OUTPUT = Path('/output')
TEMPLATES = Path('/app/templates')

def parse_students():
    students = {}
    for data in STUDENTS.split(','):
        if ':' in data.strip():
            name, ip = data.strip().split(':')
            students[name.strip()] = ip.strip()
    return students

def get_ssh_port(ip):
    """Genera puerto SSH único: 22 + últimos 2 dígitos de la IP"""
    last_octet = ip.split('.')[-1]
    return f"22{last_octet}"

def generate_configs(students):
    env = Environment(loader=FileSystemLoader(TEMPLATES))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    
    # Generate HTTPS stream-map-entries.conf
    stream_entries = []
    for s, ip in students.items():
        stream_entries.append(f"        ~^.*\\.{s}\\.{DOMAIN}$ {ip}:443;")
    stream_entries.append("        default 127.0.0.1:8443;")
    
    (OUTPUT / 'stream-map-entries.conf').write_text('\n'.join(stream_entries))
    print(f"✅ stream-map-entries.conf ({len(students)} alumnos)")
    
    # Generate SSH proxy blocks
    ssh_blocks = ["# SSH Proxy per Student\n"]
    for student, ip in students.items():
        ssh_port = get_ssh_port(ip)
        ssh_blocks.append(f"""server {{
    listen {ssh_port};
    proxy_pass {ip}:22;
    proxy_connect_timeout 10s;
}}\n""")
    
    (OUTPUT / 'ssh-proxy.conf').write_text('\n'.join(ssh_blocks))
    print(f"✅ ssh-proxy.conf ({len(students)} puertos SSH)")
    
    # Generate HTTP configs per student
    template = env.get_template('alumno.conf.j2')
    for student, ip in students.items():
        ssh_port = get_ssh_port(ip)
        config = template.render(student=student, ip=ip, domain=DOMAIN, ssh_port=ssh_port)
        (OUTPUT / f'{student}.conf').write_text(config)
        print(f"✅ {student}.conf → HTTP/HTTPS proxy + SSH port {ssh_port}")

students = parse_students()
if not students:
    print("❌ No hay alumnos configurados")
    sys.exit(1)

print(f"\n👥 Configurando {len(students)} alumnos\n")
generate_configs(students)
print("\n✅ Configuración completada\n")
print("\n📋 Acceso SSH por alumno:")
for student, ip in students.items():
    ssh_port = get_ssh_port(ip)
    print(f"   ssh -p {ssh_port} usuario@{DOMAIN}  # {student} ({ip})")
print()
EOF
    
    # Crear template
    cat > ${PROJECT_NAME}/config-manager/templates/alumno.conf.j2 << 'EOF'
# {{ student }} -> {{ ip }}
# SSH: puerto {{ ssh_port }} -> {{ ip }}:22
# HTTPS: *.{{ student }}.{{ domain }} -> {{ ip }}:443

server {
    listen 80;
    server_name *.{{ student }}.{{ domain }};

    access_log /var/log/nginx/{{ student }}.log;

    location /.well-known/acme-challenge/ {
        proxy_pass http://{{ ip }}:80;
        proxy_set_header Host $host;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF
    echo -e "${GREEN}✅ Config Manager configurado${NC}"
    
    # Crear script de configuración SSH Bastion
    cat > ${PROJECT_NAME}/setup-ssh-bastion.sh << 'EOFBASH'
#!/bin/bash

# ═══════════════════════════════════════════════════════════
# Script de configuración SSH Bastion (ejecutar EN el servidor)
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Mapeo de usuarios a IPs (debe coincidir con STUDENTS)
declare -A STUDENT_IPS
STUDENT_IPS[alonso]="192.168.5.45"
STUDENT_IPS[victor]="192.168.5.41"
STUDENT_IPS[orwin]="192.168.5.43"
STUDENT_IPS[mcarmen]="192.168.5.42"
STUDENT_IPS[mikel]="192.168.5.46"
STUDENT_IPS[luismi]="192.168.5.44"
STUDENT_IPS[miguel]="192.168.5.47"

REAL_USER="${STUDENT_IPS[$USER]}"

if [[ -z "$REAL_USER" ]]; then
    echo -e "${RED}❌ Usuario no autorizado: $USER${NC}" >&2
    exit 1
fi

echo -e "${GREEN}🔄 Redirigiendo a máquina del alumno $USER ($REAL_USER)...${NC}"
exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REAL_USER" "$@"
EOFBASH

    chmod +x ${PROJECT_NAME}/setup-ssh-bastion.sh
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${GREEN}✅ ESTRUCTURA CREADA CORRECTAMENTE${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "📁 Proyecto: ${BLUE}./${PROJECT_NAME}/${NC}"
    echo ""
    echo "📝 Próximos pasos:"
    echo "   1. make build         # Construir imágenes"
    echo "   2. make up            # Levantar servicios"
    echo "   3. make setup-bastion # Generar script de configuración SSH"
    echo "   4. make status        # Ver estado"
    echo ""
}

build_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe. Ejecuta: make init${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔨 Construyendo imágenes Docker...${NC}"
    cd ${PROJECT_NAME}
    docker compose build
    cd ..
    echo -e "${GREEN}✅ Imágenes construidas${NC}"
}

rebuild_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe. Ejecuta: make init${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔨 Reconstruyendo imágenes Docker (sin caché)...${NC}"
    echo -e "${YELLOW}⚠️  Esto puede tardar varios minutos...${NC}"
    cd ${PROJECT_NAME}
    docker compose build --no-cache
    cd ..
    echo -e "${GREEN}✅ Imágenes reconstruidas completamente${NC}"
}

start_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe. Ejecuta: make init${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🚀 Levantando servicios...${NC}"
    cd ${PROJECT_NAME}
    docker compose up -d
    echo ""
    sleep 3
    echo -e "${GREEN}✅ Servicios levantados${NC}"
    echo ""
    docker compose ps
    cd ..
}

stop_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⏹️  Parando servicios...${NC}"
    cd ${PROJECT_NAME}
    docker compose down
    cd ..
    echo -e "${GREEN}✅ Servicios parados${NC}"
}

restart_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Reiniciando nginx...${NC}"
    cd ${PROJECT_NAME}
    docker compose restart nginx-proxy
    cd ..
    echo -e "${GREEN}✅ Nginx reiniciado${NC}"
}

show_logs() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📜 Mostrando logs (Ctrl+C para salir)...${NC}"
    echo ""
    cd ${PROJECT_NAME}
    docker compose logs -f nginx-proxy
    cd ..
}

show_status() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe${NC}"
        exit 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Estado de Servicios"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    cd ${PROJECT_NAME}
    docker compose ps
    
    echo ""
    echo "📊 Alumnos configurados:"
    if [ -d "nginx/conf.d" ]; then
        ALUMNO_COUNT=$(ls -1 nginx/conf.d/*.conf 2>/dev/null | grep -v stream-map | wc -l)
        echo "   Total: ${ALUMNO_COUNT}"
        echo ""
        echo "   Lista:"
        ls -1 nginx/conf.d/*.conf 2>/dev/null | grep -v stream-map | sed 's|nginx/conf.d/||' | sed 's|.conf||' | sed 's/^/   - /'
    else
        echo "   No hay configuraciones generadas aún"
    fi
    
    echo ""
    cd ..
}

clean_project() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${YELLOW}⚠️  El proyecto no existe${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}⚠️  ADVERTENCIA: Esto eliminará todo el proyecto${NC}"
    read -p "¿Estás seguro? (escribe 'si' para confirmar): " confirm
    
    if [ "$confirm" != "si" ]; then
        echo -e "${BLUE}Operación cancelada${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}🗑️  Limpiando proyecto...${NC}"
    
    # Parar servicios si están corriendo
    if [ -f "${PROJECT_NAME}/docker-compose.yml" ]; then
        cd ${PROJECT_NAME}
        docker compose down -v 2>/dev/null || true
        cd ..
    fi
    
    # Eliminar directorio
    rm -rf ${PROJECT_NAME}
    
    echo -e "${GREEN}✅ Proyecto eliminado${NC}"
}

setup_bastion() {
    if [ ! -d "${PROJECT_NAME}" ]; then
        echo -e "${RED}❌ Proyecto no existe. Ejecuta: make init${NC}"
        exit 1
    fi
    
    if [ ! -f "${ALUMNOS_CSV}" ]; then
        echo -e "${RED}❌ Archivo ${ALUMNOS_CSV} no existe${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔧 Generando script de configuración SSH Bastion...${NC}"
    echo ""
    
    # Generar arrays de usuarios desde CSV
    USERS_ARRAY=""
    
    while IFS=',' read -r user ip; do
        # Saltar comentarios y líneas vacías
        [[ "$user" =~ ^#.*$ ]] && continue
        [[ -z "$user" ]] && continue
        
        USERS_ARRAY="${USERS_ARRAY}  [${user}]=\"${ip}\"\n"
    done < "${ALUMNOS_CSV}"
    
    # Crear script de instalación completo
    cat > ${PROJECT_NAME}/install-ssh-bastion.sh << EOFINSTALL
#!/bin/bash

# ═══════════════════════════════════════════════════════════
# Instalación SSH Bastion - Redirección Transparente
# Ejecutar EN el servidor como root
# ═══════════════════════════════════════════════════════════

set -e

RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m'

if [[ \$EUID -ne 0 ]]; then
   echo -e "\${RED}❌ Este script debe ejecutarse como root\${NC}"
   exit 1
fi

echo -e "\${BLUE}🚀 Configurando SSH Bastion con redirección transparente...\${NC}"
echo -e "\${BLUE}   Los alumnos usarán las contraseñas de sus propias máquinas\${NC}"
echo ""

# Mapeo de usuarios a IPs (generado desde alumnos.csv)
declare -A STUDENT_IPS=(
$(echo -e "$USERS_ARRAY")
)

# Crear script de redirección
mkdir -p /usr/local/bin
cat > /usr/local/bin/ssh-redirect << 'EOFRED'
#!/bin/bash

# Mapeo dinámico de usuarios a IPs
declare -A STUDENT_IPS=(
$(echo -e "$USERS_ARRAY")
)

TARGET_IP="\\\${STUDENT_IPS[\\\$USER]}"

if [[ -z "\\\$TARGET_IP" ]]; then
    echo "❌ Usuario no autorizado: \\\$USER" >&2
    exit 1
fi

echo "🔄 Conectando a máquina de \\\$USER (\\\$TARGET_IP)..."
exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "\\\$TARGET_IP" "\\\$@"
EOFRED

chmod +x /usr/local/bin/ssh-redirect

# Configurar SSH para redirección
echo -e "\${YELLOW}🔧 Configurando SSH para redirección...\${NC}"
cat > /etc/ssh/sshd_config.d/bastion.conf << 'EOFSSH'
# Configuración Bastion - Redirección Transparente
# Los usuarios se autentican en sus máquinas destino
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin no

EOFSSH

# Crear usuarios sin contraseña (solo para redirección)
echo -e "\${BLUE}👥 Creando usuarios de redirección...\${NC}"
echo ""

for student in "\${!STUDENT_IPS[@]}"; do
    ip="\${STUDENT_IPS[\$student]}"
    
    echo -e "\${YELLOW}📝 Configurando usuario: \$student → \$ip\${NC}"
    
    # Crear usuario si no existe (sin contraseña, solo redirección)
    if ! id "\$student" &>/dev/null; then
        useradd -m -s /bin/bash "\$student"
        # Bloquear contraseña (solo permite redirección SSH)
        passwd -l "\$student" > /dev/null 2>&1
        echo -e "\${GREEN}  ✅ Usuario \$student creado (solo redirección)\${NC}"
    else
        echo -e "\${BLUE}  ℹ️  Usuario \$student ya existe\${NC}"
    fi
    
    # Agregar configuración ForceCommand al archivo de configuración
    cat >> /etc/ssh/sshd_config.d/bastion.conf << EOFUSER

Match User \$student
    ForceCommand /usr/local/bin/ssh-redirect
    PasswordAuthentication no
    PubkeyAuthentication no
EOFUSER
done

echo -e "\${GREEN}✅ Configuración SSH aplicada\${NC}"

# Reiniciar SSH
systemctl restart sshd
echo -e "\${GREEN}✅ SSH reiniciado\${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "\${GREEN}✅ SSH BASTION CONFIGURADO\${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Usuarios configurados:"
for student in "\${!STUDENT_IPS[@]}"; do
    echo "   - \$student → \${STUDENT_IPS[\$student]}"
done
echo ""
echo "🔑 Los alumnos acceden con:"
echo "   ssh usuario@${BASE_DOMAIN}"
echo "   El bastion redirige automáticamente a su máquina"
echo "   Usan la contraseña de SU PROPIA MÁQUINA (no del bastion)"
echo ""
EOFINSTALL

    chmod +x ${PROJECT_NAME}/install-ssh-bastion.sh
    
    # Contar alumnos
    NUM_ALUMNOS=$(grep -v '^#' ${ALUMNOS_CSV} | grep -v '^$' | wc -l | tr -d ' ')
    
    echo -e "${GREEN}✅ Script generado: ${PROJECT_NAME}/install-ssh-bastion.sh${NC}"
    echo -e "${GREEN}✅ Configurados ${NUM_ALUMNOS} alumnos${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${YELLOW}📝 INSTRUCCIONES:${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "1. Copia el script al servidor bastion:"
    echo -e "   ${BLUE}scp ${PROJECT_NAME}/install-ssh-bastion.sh root@${BASE_DOMAIN}:/tmp/${NC}"
    echo ""
    echo "2. Conéctate al servidor y ejecútalo:"
    echo -e "   ${BLUE}ssh root@${BASE_DOMAIN}${NC}"
    echo -e "   ${BLUE}chmod +x /tmp/install-ssh-bastion.sh${NC}"
    echo -e "   ${BLUE}sudo /tmp/install-ssh-bastion.sh${NC}"
    echo ""
    echo "3. Cada alumno accederá con:"
    echo -e "   ${BLUE}ssh usuario@${BASE_DOMAIN}${NC}"
    echo -e "   ${BLUE}(usa la contraseña definida en ${ALUMNOS_CSV})${NC}"
    echo ""
    echo "📊 Alumnos configurados:"
    grep -v '^#' ${ALUMNOS_CSV} | grep -v '^$' | while IFS=',' read -r user ip password; do
        echo "   - $user ($ip)"
    done
    echo ""
}

# Main
case "$1" in
    init)
        init_project
        ;;
    build)
        build_project
        ;;
    rebuild)
        rebuild_project
        ;;
    up|start)
        start_project
        ;;
    down|stop)
        stop_project
        ;;
    restart)
        restart_project
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    clean)
        clean_project
        ;;
    setup-bastion)
        setup_bastion
        ;;
    *)
        echo -e "${RED}❌ Comando desconocido: $1${NC}"
        echo ""
        echo "Comandos disponibles:"
        echo "  init           - Inicializar proyecto"
        echo "  build          - Construir imágenes"
        echo "  up/start       - Levantar servicios"
        echo "  down/stop      - Parar servicios"
        echo "  restart        - Reiniciar nginx"
        echo "  logs           - Ver logs"
        echo "  status         - Ver estado"
        echo "  setup-bastion  - Generar script de configuración SSH"
        echo "  clean          - Limpiar proyecto"
        exit 1
        ;;
esac
