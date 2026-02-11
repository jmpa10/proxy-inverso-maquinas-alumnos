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
