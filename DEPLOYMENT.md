# 🚀 Guía de Deployment en Servidor

Este documento registra el proceso de deployment en servidor de producción y los problemas encontrados con sus soluciones.

---

## 📋 Proceso de Instalación en Servidor

### Requisitos previos

- Servidor con Docker y Docker Compose instalados
- Git instalado
- Acceso SSH al servidor
- Puertos disponibles: 2241-2247, 443

### Instalación paso a paso

```bash
# 1. Clonar repositorio
git clone https://github.com/jmpa10/proxy-inverso-maquinas-alumnos
cd proxy-inverso-maquinas-alumnos

# 2. Verificar código actualizado
git log --oneline -3
# Debe mostrar commits recientes con fixes de stream.d/

# 3. Verificar que generate.py tiene el código correcto
grep -n "stream_dir" bastion-proxy/config-manager/generate.py
# Debe mostrar líneas con: stream_dir = OUTPUT / 'stream.d'

# 4. Limpiar cualquier residuo anterior
rm -rf bastion-proxy/nginx/conf.d/*
rm -rf bastion-proxy/nginx/conf.d/stream.d

# 5. Eliminar imágenes Docker viejas (IMPORTANTE)
docker rmi bastion-proxy-config-manager bastion-proxy-nginx-proxy 2>/dev/null || true
docker system prune -af

# 6. Reconstruir imágenes sin caché
make rebuild

# 7. Levantar servicios
make up

# 8. Verificar estructura de archivos generados
ls -la bastion-proxy/nginx/conf.d/
# Debe mostrar: archivos .conf de alumnos + directorio stream.d/

ls -la bastion-proxy/nginx/conf.d/stream.d/
# Debe mostrar: ssh-proxy.conf + stream-map-entries.conf

# 9. Verificar logs
make logs
# Debe mostrar: "nginx: configuration file /etc/nginx/nginx.conf test is successful"
```

---

## 🐛 Problemas Encontrados y Soluciones

### Problema 1: Error "proxy_pass directive is not allowed here"

#### Síntoma
```
nginx: [emerg] "proxy_pass" directive is not allowed here in /etc/nginx/conf.d/ssh-proxy.conf:5
nginx: configuration file /etc/nginx/nginx.conf test failed
```

#### Causa Raíz
El archivo `ssh-proxy.conf` estaba siendo generado en `/etc/nginx/conf.d/` (raíz) en lugar de en `/etc/nginx/conf.d/stream.d/` (subdirectorio).

Esto ocurría porque:
1. **Docker usaba imágenes en caché** con código antiguo de `generate.py`
2. Aunque se hizo `git pull`, la imagen Docker de `config-manager` conservaba el código viejo
3. El comando `make rebuild` no era suficiente si Docker tenía capas cacheadas

#### Diagnóstico
```bash
# Ver archivos generados en el host
ls -la bastion-proxy/nginx/conf.d/
# ❌ MAL: ssh-proxy.conf en la raíz
# ✅ BIEN: solo archivos de alumnos + directorio stream.d/

ls -la bastion-proxy/nginx/conf.d/stream.d/
# ❌ MAL: directorio no existe
# ✅ BIEN: contiene ssh-proxy.conf y stream-map-entries.conf

# Ver logs del config-manager
docker logs config-manager
# Debe mostrar: ✅ ssh-proxy.conf (X puertos SSH)

# Verificar código en generate.py
grep "stream_dir" bastion-proxy/config-manager/generate.py
# ❌ MAL: no devuelve nada (código viejo)
# ✅ BIEN: muestra líneas con stream_dir
```

#### Solución Aplicada
```bash
# 1. Forzar actualización del código desde GitHub
git fetch --all
git reset --hard origin/main

# 2. Verificar que ahora tiene el código correcto
grep -n "stream_dir" bastion-proxy/config-manager/generate.py

# 3. Parar servicios
make down

# 4. ELIMINAR imágenes Docker viejas (CRÍTICO)
docker rmi bastion-proxy-config-manager bastion-proxy-nginx-proxy

# 5. Limpiar sistema Docker completo
docker system prune -af --volumes

# 6. Limpiar directorio conf.d/
rm -rf bastion-proxy/nginx/conf.d/*

# 7. Reconstruir desde cero SIN caché
make rebuild

# 8. Levantar servicios
make up

# 9. Verificación
ls -la bastion-proxy/nginx/conf.d/stream.d/
# Ahora SÍ debe existir con los archivos correctos
```

### Problema 2: Archivos viejos persistentes en conf.d/

#### Síntoma
Después de `git clone` y `make up`, el servicio falla con archivos `.conf` en ubicaciones incorrectas.

#### Causa
- `.gitignore` ignora archivos `*.conf` dentro de `conf.d/`
- Si el directorio ya existía de un intento anterior, Git NO lo limpia
- Los archivos viejos permanecen y causan conflictos

#### Solución
Añadida limpieza automática en `make up`:
```bash
# En bastion-setup.sh → start_project()
if [ -d "${PROJECT_NAME}/nginx/conf.d" ]; then
    echo "🧹 Limpiando configuraciones antiguas..."
    rm -rf ${PROJECT_NAME}/nginx/conf.d/*
    rm -rf ${PROJECT_NAME}/nginx/conf.d/stream.d
fi
```

### Problema 3: Docker cache persistente

#### Síntoma
Aunque se hace `make rebuild`, Docker sigue usando código viejo.

#### Causa
Docker puede cachear capas intermedias incluso con `--no-cache` si:
- Las imágenes base están cacheadas
- Los archivos fuente (COPY) no han cambiado en el filesystem (aunque sí en git)

#### Solución
```bash
# Eliminar imágenes explícitamente ANTES de rebuild
docker rmi bastion-proxy-config-manager bastion-proxy-nginx-proxy
make rebuild
```

### Problema 4: Git pull no trae cambios

#### Síntoma
`grep "stream_dir" bastion-proxy/config-manager/generate.py` no devuelve nada después de `git pull`.

#### Causa
- Conflictos de merge no resueltos
- Rama local divergente de origin/main
- Archivos modificados localmente

#### Solución
```bash
# Forzar sincronización con GitHub
git fetch --all
git reset --hard origin/main

# Verificar commit actual
git log --oneline -3
```

---

## ✅ Proceso Definitivo para Deployment

Después de resolver todos los problemas, este es el **proceso definitivo y probado**:

```bash
# === INSTALACIÓN INICIAL ===

# 1. Clonar repositorio
git clone https://github.com/jmpa10/proxy-inverso-maquinas-alumnos
cd proxy-inverso-maquinas-alumnos

# 2. Forzar código actualizado (por seguridad)
git fetch --all
git reset --hard origin/main

# 3. Verificar código correcto
grep "stream_dir" bastion-proxy/config-manager/generate.py | head -2
# Debe mostrar:
#     stream_dir = OUTPUT / 'stream.d'
#     stream_dir.mkdir(parents=True, exist_ok=True)

# 4. Limpiar completamente
rm -rf bastion-proxy/nginx/conf.d/*
docker rmi bastion-proxy-config-manager bastion-proxy-nginx-proxy 2>/dev/null || true
docker system prune -af

# 5. Build y deploy
make rebuild
make up

# 6. Verificación completa
make logs
make ports
ls -la bastion-proxy/nginx/conf.d/stream.d/
```

```bash
# === ACTUALIZACIÓN DESPUÉS DE CAMBIOS ===

cd proxy-inverso-maquinas-alumnos

# 1. Forzar actualización
git fetch --all
git reset --hard origin/main

# 2. Limpiar TODO
make down
docker rmi bastion-proxy-config-manager bastion-proxy-nginx-proxy
rm -rf bastion-proxy/nginx/conf.d/*

# 3. Reconstruir y levantar
make rebuild
make up

# 4. Verificar
make logs
```

---

## 🔍 Comandos de Verificación

### Verificar código fuente correcto
```bash
# Generate.py debe tener código de stream.d/
grep -A 3 "stream_dir = OUTPUT" bastion-proxy/config-manager/generate.py

# Nginx.conf debe incluir stream.d/
grep "stream.d" bastion-proxy/nginx/nginx.conf

# Commits recientes
git log --oneline -5 | grep -E "(stream|Fix|rebuild)"
```

### Verificar archivos generados
```bash
# En el host
ls -la bastion-proxy/nginx/conf.d/
ls -la bastion-proxy/nginx/conf.d/stream.d/

# Dentro del contenedor
docker exec nginx-proxy ls -la /etc/nginx/conf.d/
docker exec nginx-proxy ls -la /etc/nginx/conf.d/stream.d/

# Buscar ssh-proxy.conf en ubicaciones correctas/incorrectas
docker exec nginx-proxy find /etc/nginx -name "ssh-proxy.conf"
# Debe estar SOLO en: /etc/nginx/conf.d/stream.d/ssh-proxy.conf
```

### Verificar configuración nginx
```bash
# Test de configuración
docker exec nginx-proxy nginx -t

# Ver includes del bloque stream
docker exec nginx-proxy cat /etc/nginx/nginx.conf | grep -A 10 "stream {"
```

### Verificar servicios
```bash
# Estado de contenedores
docker ps -a | grep bastion-proxy

# Logs en tiempo real
docker logs -f nginx-proxy
docker logs config-manager

# Puertos en escucha
docker exec nginx-proxy netstat -tlnp 2>/dev/null || true
```

---

## 📊 Checklist de Deployment Exitoso

- [ ] Código actualizado con `git reset --hard origin/main`
- [ ] `grep "stream_dir"` encuentra el código en generate.py
- [ ] Directorio `conf.d/` limpio antes de build
- [ ] Imágenes Docker viejas eliminadas
- [ ] `make rebuild` completado sin errores
- [ ] Directorio `stream.d/` existe con 2 archivos:
  - [ ] `ssh-proxy.conf`
  - [ ] `stream-map-entries.conf`
- [ ] `make logs` muestra: "test is successful"
- [ ] NO hay archivos `.conf` de stream en la raíz de `conf.d/`
- [ ] `make ports` muestra tabla de puertos correcta

---

## 🎓 Lecciones Aprendidas

1. **Docker cache es persistente**: Incluso `--no-cache` no elimina imágenes viejas. Hay que borrarlas explícitamente con `docker rmi`.

2. **Git pull no es suficiente**: Si hay cambios locales o conflictos, usar `git reset --hard origin/main`.

3. **Volúmenes Docker persisten**: Los archivos en volumenes montados NO se actualizan con rebuild. Hay que limpiarlos manualmente.

4. **Verificación en múltiples niveles**: Siempre verificar:
   - Código fuente (host)
   - Archivos generados (host)
   - Archivos en contenedor
   - Logs de nginx

5. **La limpieza manual es necesaria**: En producción, después de `git clone` siempre hacer limpieza manual del directorio `conf.d/`.

---

## 📞 Soporte

Si encuentras el error "proxy_pass directive is not allowed here":

1. Consulta [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Sigue el "Proceso Definitivo" de este documento
3. Verifica todos los items del Checklist

---

**Última actualización**: 24 de febrero de 2026  
**Servidor probado**: Ubuntu Server con Docker 25.x  
**Estado**: ✅ Funcionando correctamente en producción
