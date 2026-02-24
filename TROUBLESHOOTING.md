# 🔧 Troubleshooting - Solución de Problemas

## Error: "proxy_pass directive is not allowed here"

### Síntoma
```
nginx: [emerg] "proxy_pass" directive is not allowed here in /etc/nginx/conf.d/ssh-proxy.conf:5
nginx: configuration file /etc/nginx/nginx.conf test failed
```

### Causa
Archivos `.conf` viejos permanecen en `bastion-proxy/nginx/conf.d/` de ejecuciones anteriores. El archivo `ssh-proxy.conf` debe estar en el subdirectorio `stream.d/`, no en la raíz.

### Solución Rápida (Servidor)

```bash
# 1. Parar servicios y eliminar volúmenes
cd proxy-inverso-maquinas-alumnos
make down

# 2. Limpiar MANUALMENTE el directorio conf.d/
rm -rf bastion-proxy/nginx/conf.d/*
rm -rf bastion-proxy/nginx/conf.d/stream.d

# 3. Verificar que está limpio
ls -la bastion-proxy/nginx/conf.d/

# 4. Reconstruir imágenes sin caché
make rebuild

# 5. Levantar servicios
make up

# 6. Verificar logs
make logs
```

### Verificación después de make up

```bash
# Verificar estructura de archivos generados
ls -la bastion-proxy/nginx/conf.d/
# Debe mostrar: alumnos.conf (uno por alumno) + directorio stream.d/

ls -la bastion-proxy/nginx/conf.d/stream.d/
# Debe mostrar: ssh-proxy.conf + stream-map-entries.conf

# Verificar contenido del contenedor
docker exec nginx-proxy ls -la /etc/nginx/conf.d/
docker exec nginx-proxy ls -la /etc/nginx/conf.d/stream.d/

# Si ssh-proxy.conf aparece en conf.d/ (raíz), hay un problema
# Solo debe estar en conf.d/stream.d/

# Verificar logs
docker logs nginx-proxy
# Debe mostrar: "configuration file /etc/nginx/nginx.conf test is successful"
```

## Error: Contenedor nginx-proxy en restart loop

### Síntoma
```
STATUS: Restarting (1) Less than a second ago
```

### Causa
Nginx no puede arrancar debido a errores de configuración.

### Solución

```bash
# Ver logs completos
docker logs nginx-proxy --tail 50

# Si el error persiste después de limpiar conf.d/:
# Eliminar TODO y empezar desde cero

make down
docker system prune -af --volumes  # ⚠️ ELIMINA TODAS LAS IMÁGENES Y VOLÚMENES
rm -rf bastion-proxy/nginx/conf.d/*
make rebuild
make up
```

## Error: Archivos no se generan en stream.d/

### Síntoma
Los archivos `ssh-proxy.conf` y `stream-map-entries.conf` no están en `bastion-proxy/nginx/conf.d/stream.d/`.

### Verificación

```bash
# Ver logs del config-manager
docker logs config-manager

# Debe mostrar:
# ✅ stream-map-entries.conf (X alumnos)
# ✅ ssh-proxy.conf (X puertos SSH)

# Verificar que el directorio existe
ls -la bastion-proxy/nginx/conf.d/stream.d/
```

### Solución

```bash
# Si config-manager falló, reconstruir:
make down
make rebuild
make up
```

## Error: "No such file or directory" al hacer make up

### Síntoma
```
Error: open bastion-proxy/nginx/conf.d: no such file or directory
```

### Solución

```bash
# Crear el directorio manualmente
mkdir -p bastion-proxy/nginx/conf.d

# Intentar de nuevo
make up
```

## Diferencias entre Desarrollo (local) y Producción (servidor)

### En desarrollo (tu máquina)
- Docker puede usar imágenes en caché antiguas
- Los archivos locales persisten entre ejecuciones
- **Solución**: `make rebuild` + `make up`

### En producción (servidor)
- Puede haber archivos de instalaciones anteriores
- Git no elimina archivos ignorados en `.gitignore`
- **Solución**: Limpieza manual del directorio `conf.d/`

## Comandos útiles para debugging

```bash
# Ver estado de contenedores
docker ps -a

# Ver volúmenes Docker
docker volume ls

# Ver todas las redes
docker network ls

# Eliminar todo lo relacionado con el proyecto
docker ps -a | grep bastion-proxy
docker rm -f nginx-proxy config-manager
docker volume prune -f
docker network prune -f

# Ver uso de espacio de Docker
docker system df

# Ver logs en tiempo real
docker logs -f nginx-proxy
docker logs -f config-manager

# Ejecutar comando dentro del contenedor
docker exec nginx-proxy nginx -t                    # Test nginx config
docker exec nginx-proxy cat /etc/nginx/nginx.conf  # Ver config
docker exec nginx-proxy ls -la /etc/nginx/conf.d/  # Ver archivos

# Verificar puertos en uso (Linux)
sudo netstat -tlnp | grep -E ':(224[1-7]|443)'
sudo ss -tlnp | grep -E ':(224[1-7]|443)'

# Verificar puertos en uso (macOS)
lsof -iTCP -sTCP:LISTEN -n -P | grep -E ':(224[1-7]|443)'
```

## Secuencia completa de instalación limpia (servidor)

```bash
# 1. Clonar repositorio
git clone https://github.com/jmpa10/proxy-inverso-maquinas-alumnos
cd proxy-inverso-maquinas-alumnos

# 2. Asegurarse de que conf.d/ está vacío
rm -rf bastion-proxy/nginx/conf.d/*
mkdir -p bastion-proxy/nginx/conf.d

# 3. Verificar alumnos.csv
cat alumnos.csv

# 4. Reconstruir sin caché
make rebuild

# 5. Levantar servicios
make up

# 6. Verificar que todo funciona
make logs

# 7. Ver puertos asignados
make ports

# 8. Verificar archivos generados
ls -la bastion-proxy/nginx/conf.d/
ls -la bastion-proxy/nginx/conf.d/stream.d/
```

## Problemas comunes

### 1. Git clone no trae el directorio conf.d/
**Normal**: El directorio se crea automáticamente al hacer `make up`.

### 2. Los cambios no se aplican después de git pull
**Solución**: Siempre hacer `make rebuild` después de `git pull`.

### 3. Nginx muestra "configuration test failed"
**Causa**: Archivos `.conf` en ubicaciones incorrectas.
**Solución**: Limpiar `conf.d/` manualmente y reconstruir.

### 4. Config-manager completa pero nginx falla
**Verificar**: 
- Logs de config-manager: `docker logs config-manager`
- Archivos generados: `ls bastion-proxy/nginx/conf.d/stream.d/`
- Nginx config: `docker exec nginx-proxy nginx -t`

## Contacto

Si después de seguir estos pasos el problema persiste:
1. Ejecuta: `docker logs config-manager > config-manager.log`
2. Ejecuta: `docker logs nginx-proxy > nginx-proxy.log`
3. Ejecuta: `ls -laR bastion-proxy/nginx/conf.d/ > estructura.log`
4. Revisa los archivos de log para identificar el problema

---

📝 **Nota**: La mayoría de problemas se resuelven con:
```bash
make down
rm -rf bastion-proxy/nginx/conf.d/*
make rebuild
make up
```
