# 📘 Cómo Funciona el Sistema Actual

## 🎯 Resumen en 30 segundos

- **Nginx** actúa como **proxy TCP** para SSH
- Cada alumno tiene un **puerto dedicado** (22XX)
- **No hay usuarios** en el bastión (192.168.5.10)
- Los alumnos se autentican **directamente en sus máquinas**

## 🔄 Flujo de Conexión

```
1. Alumno ejecuta:
   ssh -p 2245 usuario@servidorgp.somosdelprieto.com

2. DNS resuelve:
   servidorgp.somosdelprieto.com → IP pública de tu router

3. Router redirige:
   Puerto público 2245 → 192.168.5.10:2245

4. Nginx (en 192.168.5.10) redirige tráfico TCP:
   Puerto 2245 → 192.168.5.45:22

5. Alumno se autentica:
   SSH pide usuario/contraseña de la máquina 192.168.5.45

6. Resultado:
   usuario@192.168.5.45:~$  ← Sesión SSH en la máquina del alumno
```

## ⚙️ Componentes

### 1. Docker Compose (en 192.168.5.10)

```yaml
nginx-proxy:
  network_mode: host  # Escucha directamente en puertos del host
  # Escucha en: 443, 2241, 2242, 2243, 2244, 2245, 2246, 2247

config-manager:
  # Lee alumnos.csv y genera configs de Nginx
```

### 2. Nginx Stream Module

```nginx
stream {
    # Para cada alumno:
    server {
        listen 2245;
        proxy_pass 192.168.5.45:22;  # Redirige a máquina alumno
    }
}
```

### 3. Archivo alumnos.csv

```csv
usuario,ip
alonso,192.168.5.45  # Genera automáticamente puerto 2245
victor,192.168.5.41  # Genera automáticamente puerto 2241
```

## 🔢 Lógica de Puertos

El puerto SSH de cada alumno se calcula como: **22 + últimos 2 dígitos de la IP**

| IP            | Cálculo | Puerto |
|---------------|---------|--------|
| 192.168.5.41  | 22 + 41 | 2241   |
| 192.168.5.45  | 22 + 45 | 2245   |
| 192.168.5.50  | 22 + 50 | 2250   |

## 🚫 Lo que NO hace el bastión

❌ **NO** crea usuarios Linux  
❌ **NO** autentica a nadie  
❌ **NO** almacena contraseñas  
❌ **NO** ejecuta comandos SSH  

## ✅ Lo que SÍ hace el bastión

✅ **Redirige tráfico TCP** (como un cable)  
✅ **Proxy HTTPS con SNI** para aplicaciones web  
✅ **Genera configs automáticas** desde CSV  

## 🔐 Seguridad

### ¿Es seguro?

**Sí**, porque:
- El bastión solo mueve paquetes TCP, no los intercepta
- La autenticación SSH es end-to-end (alumno ↔ su máquina)
- No hay credenciales almacenadas en el bastión

### Superficie de ataque:

- **Expuesta**: Nginx en puerto 443 y 2241-2247
- **Protegida**: SSH directo al bastión (puerto 22 NO expuesto)
- **Máquinas de alumnos**: Cada una solo accesible por su puerto

## 📊 Añadir Nuevo Alumno

### Paso 1: Editar CSV
```csv
# alumnos.csv
nuevo,192.168.5.48
```

### Paso 2: Reiniciar servicios
```bash
make down && make build && make up
```

### Paso 3: Verificar puerto generado
```bash
make status
# Nuevo alumno → Puerto 2248 (22 + 48)
```

### Paso 4: Configurar router
```
Añadir redirección: 2248 → 192.168.5.10:2248 (TCP)
```

### Paso 5: Informar al alumno
```
Tu acceso SSH:
ssh -p 2248 tu_usuario@servidorgp.somosdelprieto.com
```

## 🆚 Comparación: Sistema Actual vs Alternativo

| Característica          | Sistema Actual (Puertos) | Alternativa (Usuarios) |
|-------------------------|--------------------------|------------------------|
| Comando alumno          | `ssh -p 2245 user@...`   | `ssh alonso@...`       |
| Usuarios en bastión     | ❌ No                     | ✅ Sí (crear con useradd) |
| Autenticación bastión   | ❌ No                     | ✅ Sí (passwords/keys)  |
| Complejidad bastión     | 🟢 Baja (solo Nginx)     | 🟡 Media (SSH + scripts) |
| Complejidad alumno      | 🟡 Media (recordar puerto)| 🟢 Baja (sin puerto)    |
| Mantenimiento           | 🟢 Bajo (solo CSV)       | 🟡 Medio (gestión usuarios) |

## 🎓 Para Profesor

### Dar acceso a un alumno:

1. **Asigna máquina**: 192.168.5.XX
2. **Calcula puerto**: 22XX
3. **Comunica al alumno**:
   ```
   Puerto SSH: 22XX
   Servidor: servidorgp.somosdelprieto.com
   Usuario: [tu usuario en la máquina]
   Contraseña: [tu contraseña en la máquina]
   
   Comando:
   ssh -p 22XX tu_usuario@servidorgp.somosdelprieto.com
   ```

### Revocar acceso:

1. **Opción A**: Eliminar línea de alumnos.csv y reiniciar Nginx
2. **Opción B**: Desactivar SSH en la máquina del alumno
3. **Opción C**: Eliminar redirección de puerto en router

## 🔧 Troubleshooting Rápido

### "No route to host"
→ Router no tiene redirección de ese puerto

### "Connection timeout"  
→ Nginx no está escuchando ese puerto (verifica con `make status`)

### "Permission denied"
→ Credenciales incorrectas de la máquina del alumno

### "Connection refused"
→ SSH no está activo en la máquina del alumno

```bash
# Verificar desde el bastión:
ssh usuario@192.168.5.45  # ¿Funciona?
```

## 📞 Soporte

Ver documentación completa en:
- [README.md](README.md) - Vista general
- [CONFIGURACION_ROUTER.md](CONFIGURACION_ROUTER.md) - Setup de red
- [GUIA_ALUMNOS.md](GUIA_ALUMNOS.md) - Para estudiantes
