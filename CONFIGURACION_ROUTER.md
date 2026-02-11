# 🌐 Configuración de Router/Firewall

## 📋 Resumen

Para que los alumnos puedan acceder desde Internet, debes configurar **redirecciones de puerto** (port forwarding) en tu router/firewall que apunta a `servidorgp.somosdelprieto.com`.

## 🎯 IP del Bastión

- **IP Interna**: `192.168.5.10` (VM Proxmox con Docker)
- **Dominio Público**: `servidorgp.somosdelprieto.com`

## 🔌 Puertos a Redirigir

### Puerto HTTPS (Para aplicaciones web)
```
Puerto Público 443 → 192.168.5.10:443 (TCP)
```

### Puertos SSH (Uno por alumno)
```
Puerto Público → IP Destino:Puerto
─────────────────────────────────────────
2241          → 192.168.5.10:2241 (TCP)  # victor
2242          → 192.168.5.10:2242 (TCP)  # mcarmen
2243          → 192.168.5.10:2243 (TCP)  # orwin
2244          → 192.168.5.10:2244 (TCP)  # luismi
2245          → 192.168.5.10:2245 (TCP)  # alonso
2246          → 192.168.5.10:2246 (TCP)  # mikel
2247          → 192.168.5.10:2247 (TCP)  # miguel
```

## ⚙️ Configuración Genérica de Router

La ubicación exacta varía por modelo, pero generalmente se encuentra en:

```
Router Web UI → Firewall / NAT / Port Forwarding
```

### Ejemplo de entrada típica:

| Nombre      | Puerto Público | IP Interna    | Puerto Interno | Protocolo |
|-------------|----------------|---------------|----------------|-----------|
| SSH-Victor  | 2241           | 192.168.5.10  | 2241           | TCP       |
| SSH-Alonso  | 2245           | 192.168.5.10  | 2245           | TCP       |
| HTTPS-Proxy | 443            | 192.168.5.10  | 443            | TCP       |

## 🔒 Seguridad

### Recomendaciones:

1. **NO abras el puerto 22 estándar** al bastión si necesitas acceso SSH de administración
   - Usa otro puerto alto para tu SSH personal (ej: 2200)
   - O accede solo desde la red interna

2. **Firewall en el bastión**:
   ```bash
   # En 192.168.5.10 (si usas UFW):
   sudo ufw allow 443/tcp
   sudo ufw allow 2241:2247/tcp
   sudo ufw enable
   ```

3. **Monitoreo**:
   - Revisa logs regularmente: `make logs`
   - Considera fail2ban si ves intentos de fuerza bruta

## ✅ Verificación

### Desde fuera de tu red (Internet):

```bash
# Verificar puerto HTTPS
curl -k https://servidorgp.somosdelprieto.com

# Verificar puerto SSH de alonso (2245)
ssh -p 2245 usuario@servidorgp.somosdelprieto.com
```

### Desde dentro de tu red:

```bash
# Verificar que Nginx escucha en los puertos
docker exec nginx-proxy netstat -tlnp | grep -E ':(443|224)'
```

## 🔧 Troubleshooting

### "Connection refused"
- ✅ Verifica que Docker está corriendo: `make status`
- ✅ Verifica que Nginx arrancó sin errores: `make logs`
- ✅ Verifica redirecciones en router

### "Connection timeout"
- ✅ Verifica que el dominio resuelve correctamente: `nslookup servidorgp.somosdelprieto.com`
- ✅ Verifica que las redirecciones están activas en el router
- ✅ Verifica firewall del bastión: `sudo ufw status`

### Alumnos no pueden conectar
- ✅ Verifica que sus máquinas (192.168.5.41-47) tienen SSH activo: `systemctl status sshd`
- ✅ Prueba conectar desde el bastión: `ssh usuario@192.168.5.45`
- ✅ Verifica logs de Nginx: `make logs`

## 📊 Añadir Nuevos Alumnos

1. **Edita** [alumnos.csv](alumnos.csv)
2. **Reinicia** servicios: `make down && make build && make up`
3. **Añade redirección** en router para el nuevo puerto

Ejemplo: Nuevo alumno con IP 192.168.5.48 → Puerto automático 2248
```
Añadir en router: 2248 → 192.168.5.10:2248 (TCP)
```
