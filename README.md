# 🚀 Bastion SSH + Proxy HTTPS

Sistema automatizado para gestionar acceso SSH y HTTPS a máquinas de alumnos través de un servidor bastion con **proxy TCP por puertos**.

## 🎯 ¿Cómo acceden los alumnos?

```bash
# Cada alumno usa su puerto asignado:
ssh -p 2245 usuario@servidorgp.somosdelprieto.com
```

- **Puerto**: Asignado automáticamente según IP (192.168.5.XX → Puerto 22XX)
- **Usuario/Password**: Los de su propia máquina
- **Bastión**: Solo redirige tráfico TCP, no autentica

👉 Ver [COMO_FUNCIONA.md](COMO_FUNCIONA.md) para entender el flujo completo.

## 📋 Características

- ✅ **SSH con puerto dedicado**: Cada alumno tiene un puerto específico (22XX)
- ✅ **Proxy TCP transparente**: Nginx redirige tráfico directamente a las máquinas
- ✅ **Sin usuarios en bastion**: No hay autenticación en el bastion, solo redirección
- ✅ **Sistema dinámico**: Gestión de alumnos desde archivo CSV simple
- ✅ **Proxy HTTPS con SNI**: Enrutamiento automático por subdominio
- ✅ **Configuración automática**: Generación dinámica de configs Nginx
- ✅ **Docker Compose**: Fácil despliegue y gestión
- ✅ **Escalable**: Soporta número ilimitado de alumnos

## 🏗️ Arquitectura

```
Internet
    ↓
servidorgp.somosdelprieto.com (192.168.5.10)
    ↓
┌─────────────────────────────────────┐
│   SSH Proxy (Puertos 2241-2247)     │
│   - Proxy TCP por puerto            │
│   Puerto 2245 → 192.168.5.45:22     │
│   Puerto 2241 → 192.168.5.41:22     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│   HTTPS Proxy (Puerto 443)          │
│   - SNI detecta subdominio          │
│   app.alonso.domain → 192.168.5.45  │
│   app.victor.domain → 192.168.5.41  │
└─────────────────────────────────────┘
```

## 🚀 Inicio Rápido

### 1. Configurar Alumnos

Edita el archivo [alumnos.csv](alumnos.csv) para añadir o modificar alumnos:

```csv
# usuario,ip
alonso,192.168.5.45
victor,192.168.5.41
nuevo_alumno,192.168.5.XX
```

Puedes añadir tantos alumnos como necesites - el sistema es dinámico.

**Asignación de puertos**: Cada alumno obtiene automáticamente un puerto SSH basado en su IP:
- 192.168.5.41 → Puerto 2241
- 192.168.5.45 → Puerto 2245

### 2. Inicializar y Levantar

```bash
make init    # Crear estructura y leer alumnos.csv
make build   # Construir imágenes Docker
make up      # Levantar servicios
```

### 3. Configurar Router

Ver [CONFIGURACION_ROUTER.md](CONFIGURACION_ROUTER.md) para configurar las redirecciones de puerto necesarias.

### 4. Acceso de Alumnos

Los alumnos acceden especificando su puerto asignado:

```bash
ssh -p 2245 usuario@servidorgp.somosdelprieto.com
# Nginx redirige el tráfico TCP a 192.168.5.45:22
# El alumno usa la contraseña de su propia máquina
```

**Asignación automática de puertos**: 192.168.5.XX → Puerto 22XX

Ver [GUIA_ALUMNOS.md](GUIA_ALUMNOS.md) para instrucciones completas.

## � Despliegue en Servidor

### Primera instalación desde GitHub

```bash
# 1. Clonar el repositorio
git clone https://github.com/jmpa10/proxy-inverso-maquinas-alumnos
cd proxy-inverso-maquinas-alumnos

# 2. Configurar alumnos (si es necesario)
nano alumnos.csv

# 3. Construir imágenes (IMPORTANTE: sin caché para evitar problemas)
make rebuild

# 4. Levantar servicios
make up

# 5. Verificar estado
make status
make logs
```

### Actualizar después de cambios en GitHub

```bash
# 1. Parar servicios
make down

# 2. Actualizar código
git pull

# 3. Reconstruir imágenes sin caché
make rebuild

# 4. Levantar servicios (limpia configs viejas automáticamente)
make up
```

**⚠️ Importante**: 
- `make rebuild` reconstruye imágenes sin caché
- `make up` limpia automáticamente configuraciones antiguas antes de levantar servicios

## �📚 Documentación

- **[README.md](README.md)** (este archivo) - Introducción y guía de inicio
- **[COMO_FUNCIONA.md](COMO_FUNCIONA.md)** - Explicación técnica detallada del sistema 🔍
- **[CONFIGURACION_ROUTER.md](CONFIGURACION_ROUTER.md)** - Configurar redirecciones de puerto 🌐
- **[ACCESO_SSH.md](ACCESO_SSH.md)** - Guía completa de acceso SSH
- **[GUIA_ALUMNOS.md](GUIA_ALUMNOS.md)** - Instrucciones simples para estudiantes 🎓
- **[CHEATSHEET.md](CHEATSHEET.md)** - Comandos rápidos para administradores 🚀
- **[ssh_config_ejemplo](ssh_config_ejemplo)** - Configuración SSH lista para usar

## 🛠️ Comandos Disponibles

```bash
make help           # Ver todos los comandos
make init           # Inicializar proyecto
make build          # Construir imágenes
make rebuild        # Reconstruir sin caché (después de git pull)
make up             # Levantar servicios
make down           # Parar servicios
make restart        # Reiniciar nginx
make logs           # Ver logs en tiempo real
make status         # Ver estado y puertos asignados
make ports          # Mostrar puertos SSH por alumno
make clean          # Limpiar proyecto completo
```

## 📁 Estructura del Proyecto

```
bastion-ssh/
├── bastion-setup.sh              # Script principal de gestión
├── Makefile                      # Comandos simplificados
├── README.md                     # Este archivo
├── ACCESO_SSH.md                 # Guía de acceso SSH
└── bastion-proxy/                # Proyecto Docker
    ├── docker-compose.yml
    ├── .env                      # Variables de entorno
    ├── install-ssh-bastion.sh    # Script generado para servidor
    ├── config-manager/           # Generador de configuraciones
    │   ├── Dockerfile
    │   ├── generate.py
    │   └── templates/
    │       └── alumno.conf.j2
    └── nginx/                    # Proxy HTTPS
        ├── Dockerfile
        ├── nginx.conf
        ├── entrypoint.sh
        └── conf.d/               # Configs generadas automáticamente
            ├── alonso.conf
            ├── victor.conf
            ├── stream-map-entries.conf
            └── ssh-proxy.conf
```

## 🔧 Configuración de Alumnos

Para añadir o modificar alumnos, edita el archivo [alumnos.csv](alumnos.csv):

```csv
# usuario,ip
alonso,192.168.5.45
victor,192.168.5.41
nuevo_alumno,192.168.5.50
```

**Importante**:
- Una línea por alumno: usuario,ip
- No hay límite en el número de alumnos
- NO se gestionan contraseñas aquí (cada alumno usa la de su máquina)
- El sistema regenera automáticamente todas las configuraciones

Luego regenera:

```bash
make down
make build
make up
make setup-bastion  # Regenerar script SSH
```

Y actualiza el servidor bastion:

```bash
scp bastion-proxy/install-ssh-bastion.sh root@servidorgp.somosdelprieto.com:/tmp/
ssh root@servidorgp.somosdelprieto.com 'sudo /tmp/install-ssh-bastion.sh'
```

## 📊 Monitorización

```bash
# Ver estado de servicios
make status

# Ver logs en tiempo real
make logs

# Ver configuraciones generadas
ls -la bastion-proxy/nginx/conf.d/
```

## 🔐 Seguridad

- Los alumnos solo pueden acceder a su propia máquina
- SSH con autenticación por clave pública
- HTTPS con certificados TLS (configurados en máquinas de alumnos)
- Firewall en servidor bastion

## 🐛 Troubleshooting

### Nginx no arranca

```bash
docker logs nginx-proxy
make restart
```

### Configuraciones no se generan

```bash
docker logs config-manager
make down && make up
```

### SSH no redirige correctamente

Verifica que el script esté instalado en el servidor:

```bash
ssh root@192.168.5.10 'ls -la /usr/local/bin/ssh-redirect'
ssh root@192.168.5.10 'cat /etc/ssh/sshd_config.d/bastion.conf'
```

## 📞 Soporte

Para más detalles sobre el acceso SSH, consulta [ACCESO_SSH.md](ACCESO_SSH.md).

## 📝 Licencia

Proyecto educativo - Gregorio Prieto DAW 25-26
