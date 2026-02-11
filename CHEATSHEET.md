# 🎯 Cheatsheet - Comandos Rápidos para el Administrador

## 🚀 Instalación Inicial (Una sola vez)

```bash
# 1. Inicializar proyecto
make init

# 2. Construir imágenes
make build

# 3. Levantar servicios
make up

# 4. Generar script de instalación SSH
make setup-bastion

# 5. Copiar e instalar en servidor bastion
scp bastion-proxy/install-ssh-bastion.sh root@192.168.5.10:/tmp/
ssh root@192.168.5.10 'sudo /tmp/install-ssh-bastion.sh'
```

## 🔄 Operaciones Diarias

```bash
# Ver estado
make status

# Ver logs en tiempo real
make logs

# Reiniciar nginx
make restart

# Parar servicios
make down

# Levantar servicios
make up
```

## 👥 Gestión de Alumnos

### Añadir nuevo alumno

1. Editar [alumnos.csv](alumnos.csv):
   ```csv
   nuevo,192.168.5.50
   ```

2. Regenerar configuraciones:
   ```bash
   make down
   make build
   make up
   make setup-bastion
   ```

3. Actualizar servidor bastion:
   ```bash
   scp bastion-proxy/install-ssh-bastion.sh root@servidorgp.somosdelprieto.com:/tmp/
   ssh root@servidorgp.somosdelprieto.com 'sudo /tmp/install-ssh-bastion.sh'
   ```

**Nota**: El alumno usará la contraseña que ya tiene configurada en su propia máquina.

### Eliminar alumno

1. Quitar línea de [alumnos.csv](alumnos.csv)
2. Regenerar (pasos anteriores)
3. En el servidor bastion:
   ```bash
   ssh root@servidorgp.somosdelprieto.com
   sudo userdel -r nombre_alumno
   ```

### Cambiar contraseña de alumno

Los alumnos usan las contraseñas de sus propias máquinas. Para cambiar:

```bash
# El alumno se conecta a su máquina
ssh alonso@servidorgp.somosdelprieto.com

# Cambia su contraseña de máquina
passwd
```

No hay contraseñas que gestionar en el bastion.

## 📊 Monitorización

```bash
# Ver servicios Docker
docker ps

# Ver logs específicos
docker logs nginx-proxy
docker logs config-manager

# Ver configuraciones generadas
ls -la bastion-proxy/nginx/conf.d/

# Ver usuarios SSH en bastion
ssh root@192.168.5.10 'cat /etc/ssh/sshd_config.d/bastion.conf'

# Ver usuarios creados
ssh root@192.168.5.10 'getent passwd | grep -E "(alonso|victor|orwin)"'
```

## 🔧 Troubleshooting

### Nginx no arranca

```bash
docker logs nginx-proxy
docker exec nginx-proxy nginx -t
make restart
```

### Configuraciones no se generan

```bash
docker logs config-manager
ls -la bastion-proxy/nginx/conf.d/
make down && make up
```

### SSH no redirige

```bash
# Verificar script en servidor
ssh root@192.168.5.10 'cat /usr/local/bin/ssh-redirect'
ssh root@192.168.5.10 'ls -la /usr/local/bin/ssh-redirect'

# Verificar configuración SSH
ssh root@192.168.5.10 'cat /etc/ssh/sshd_config.d/bastion.conf'

# Reiniciar SSH
ssh root@192.168.5.10 'sudo systemctl restart sshd'
```

### Un alumno no puede conectar

```bash
# Verificar que el usuario existe en bastion
ssh root@servidorgp.somosdelprieto.com 'id alonso'

# Verificar configuración en alumnos.csv
grep "^alonso," alumnos.csv

# Verificar que la máquina del alumno es accesible
ping 192.168.5.45
ssh 192.168.5.45  # Probar conexión directa

# Verificar logs SSH en bastion
ssh root@servidorgp.somosdelprieto.com 'sudo tail -f /var/log/auth.log'
```

**Nota**: La contraseña es la de la máquina del alumno, no del bastion.

### Proxy HTTPS no funciona

```bash
# Verificar que la configuración existe
cat bastion-proxy/nginx/conf.d/alonso.conf

# Verificar mapeo SNI
cat bastion-proxy/nginx/conf.d/stream-map-entries.conf

# Test de conectividad al alumno
ping 192.168.5.45

# Test de SSL
curl -vk https://app.alonso.servidorgp.somosdelprieto.com
```

## 🔐 Gestión de Acceso

### Ver usuarios configurados

```bash
cat alumnos.csv
```

### Verificar redirección de un alumno

```bash
grep "^alonso," alumnos.csv
# Muestra: alonso,192.168.5.45
```

### Probar redirección manualmente

```bash
# En el servidor bastion
ssh root@servidorgp.somosdelprieto.com
su - alonso
# Debería redirigir automáticamente a 192.168.5.45
```

## 📦 Backup y Restauración

### Backup de configuraciones

```bash
tar -czf bastion-backup-$(date +%Y%m%d).tar.gz bastion-proxy/
```

### Backup del servidor bastion

```bash
ssh root@192.168.5.10 'sudo tar -czf /tmp/bastion-ssh-backup.tar.gz /etc/ssh/sshd_config.d/bastion.conf /usr/local/bin/ssh-redirect /home/*/. ssh'
scp root@192.168.5.10:/tmp/bastion-ssh-backup.tar.gz .
```

### Restaurar configuraciones

```bash
tar -xzf bastion-backup-20260211.tar.gz
cd bastion-proxy
docker compose up -d
```

## 🗑️ Limpieza Completa

```bash
# Limpiar proyecto local
make clean

# Limpiar servidor bastion
ssh root@192.168.5.10 << 'EOF'
  sudo rm -f /etc/ssh/sshd_config.d/bastion.conf
  sudo rm -f /usr/local/bin/ssh-redirect
  sudo systemctl restart sshd
  for user in alonso victor orwin mcarmen mikel luismi miguel; do
    sudo userdel -r "$user" 2>/dev/null || true
  done
EOF
```

## 📊 Estadísticas

### Conexiones activas

```bash
ssh root@192.168.5.10 'who'
ssh root@192.168.5.10 'ss -tn | grep :22'
```

### Logs de acceso

```bash
# Logs nginx
docker logs nginx-proxy | tail -50

# Logs SSH bastion
ssh root@192.168.5.10 'sudo grep "ssh" /var/log/auth.log | tail -20'
```

### Uso de red

```bash
docker stats nginx-proxy
ssh root@192.168.5.10 'iftop -i eth0'
```

## 🔄 Actualización del Sistema

```bash
# 1. Hacer backup
make status  # Verificar que todo funciona
tar -czf bastion-backup-$(date +%Y%m%d).tar.gz bastion-proxy/

# 2. Actualizar configuración
vim bastion-setup.sh  # Hacer cambios

# 3. Regenerar
make down
make init   # Solo si cambiaste estructura
make build
make up

# 4. Verificar
make status
make logs
```

## 📞 Contactos Útiles

- Servidor Bastion: `servidorgp.somosdelprieto.com`
- Dominio HTTPS: `servidorgp.somosdelprieto.com`
- Proyecto: `/Users/juanmapa/Documents/EDUCACION/GREGORIO_PRIETO/Edu 25-26/DAW 2/Bastion_ssh`
- Configuración alumnos: [alumnos.csv](alumnos.csv)

## 📚 Documentación

- [README.md](README.md) - Documentación principal
- [ACCESO_SSH.md](ACCESO_SSH.md) - Guía completa SSH
- [GUIA_ALUMNOS.md](GUIA_ALUMNOS.md) - Guía para estudiantes
- [ssh_config_ejemplo](ssh_config_ejemplo) - Ejemplo de configuración SSH
