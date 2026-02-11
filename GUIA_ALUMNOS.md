# 📖 Guía Rápida para Alumnos - Acceso SSH

## 🎯 Objetivo

Acceder a tu máquina de trabajo escribiendo:
```bash
ssh -p XXXX tu_usuario@servidorgp.somosdelprieto.com
```

Te pedirá tu contraseña y te conectará directamente a tu máquina.

## 🔑 Datos de Acceso

Tu profesor te proporcionará:
- **Puerto SSH**: Un número de 4 dígitos (ej: 2245)
- **Usuario**: Tu usuario en TU máquina
- **Contraseña**: La contraseña de TU máquina
- **Servidor**: servidorgp.somosdelprieto.com

## 📝 Primer Acceso

### 1️⃣ Conectar por Primera Vez

```bash
ssh -p TU_PUERTO tu_usuario@servidorgp.somosdelprieto.com
```

Ejemplo si tu puerto es 2245 y tu usuario es "alumno":
```bash
ssh -p 2245 alumno@servidorgp.somosdelprieto.com
```

Te preguntará si confías en el servidor, escribe `yes`.

Luego introduce la contraseña de tu máquina (no verás nada mientras escribes, es normal).

### 2️⃣ ¡Ya Estás Dentro!

Ahora estás en tu máquina y puedes trabajar normalmente.

## 📊 Ejemplo de Acceso por Puerto

Cada alumno tiene un puerto asignado según su máquina:

| Alumno  | IP           | Puerto | Comando de Ejemplo                                     |
|---------|--------------|--------|--------------------------------------------------------|
| alonso  | 192.168.5.45 | 2245   | `ssh -p 2245 usuario@servidorgp.somosdelprieto.com`   |
| victor  | 192.168.5.41 | 2241   | `ssh -p 2241 usuario@servidorgp.somosdelprieto.com`   |
| orwin   | 192.168.5.43 | 2243   | `ssh -p 2243 usuario@servidorgp.somosdelprieto.com`   |
| mcarmen | 192.168.5.42 | 2242   | `ssh -p 2242 usuario@servidorgp.somosdelprieto.com`   |
| mikel   | 192.168.5.46 | 2246   | `ssh -p 2246 usuario@servidorgp.somosdelprieto.com`   |
| luismi  | 192.168.5.44 | 2244   | `ssh -p 2244 usuario@servidorgp.somosdelprieto.com`   |
| miguel  | 192.168.5.47 | 2247   | `ssh -p 2247 usuario@servidorgp.somosdelprieto.com`   |

**Nota**: Reemplaza `usuario` con tu nombre de usuario en TU máquina.

## 🔧 Comandos Útiles

### Copiar archivos A tu máquina:
```bash
scp -P 2245 archivo.txt usuario@servidorgp.somosdelprieto.com:~/
```

### Copiar archivos DESDE tu máquina:
```bash
scp -P 2245 usuario@servidorgp.somosdelprieto.com:~/archivo.txt .
```

### Copiar carpetas completas:
```bash
scp -r -P 2245 carpeta/ usuario@servidorgp.somosdelprieto.com:~/
```

**Nota**: En `scp` se usa `-P` (mayúscula) para el puerto, a diferencia de `ssh` que usa `-p` (minúscula).

### (Opcional) Configurar acceso rápido:

Edita `~/.ssh/config` y añade:
```
Host miserver
    HostName servidorgp.somosdelprieto.com
    User alonso
```

Luego puedes conectar con:
```bash
ssh miserver
```

## ❓ Problemas Comunes

### "Permission denied"
- Verifica tu contraseña (es la de TU máquina, no del bastion)
- Verifica que uses tu nombre de usuario correcto
- Contacta al profesor si no recuerdas tu contraseña de máquina

### "Connection refused" o timeout
- Verifica conectividad: `ping servidorgp.somosdelprieto.com`
- Verifica que estés usando el dominio correcto
- Contacta al profesor

### "Host key verification failed"
- Elimina la clave antigua: `ssh-keygen -R servidorgp.somosdelprieto.com`
- Intenta conectar de nuevo

### "Password doesn't work"
- Usa la contraseña de TU máquina (la que usas normalmente en ella)
- Asegúrate de escribir correctamente (no verás nada mientras escribes)
- Si olvidaste tu contraseña de máquina, contacta al profesor

## 🚀 Workflow Diario

1. **Conectar:**
   ```bash
   ssh alonso@servidorgp.somosdelprieto.com
   # Introduce la contraseña de TU máquina
   ```

2. **Trabajar en tu máquina:**
   ```bash
   cd mi-proyecto
   git pull
   docker-compose up -d
   ```

3. **Salir:**
   ```bash
   exit
   ```

## 📱 Acceso desde Windows

### Opción 1: PowerShell / CMD
Los comandos son los mismos:
```powershell
ssh alonso@servidorgp.somosdelprieto.com
```

### Opción 2: PuTTY
1. Descargar PuTTY desde https://www.putty.org/
2. Host: `servidorgp.somosdelprieto.com`
3. Port: `22`
4. Click "Open"
5. Usuario: tu nombre (ej: `alonso`)
6. Contraseña: la de tu propia máquina

### Opción 3: Windows Terminal (Recomendado)
- Instalar desde Microsoft Store
- Mismos comandos que Linux/Mac

## 💡 Consejos de Seguridad

1. **Tu contraseña es la de tu máquina**: No hay contraseña especial del bastion
2. **Usa contraseñas fuertes**: mínimo 12 caracteres, mezcla letras, números y símbolos
3. **No compartas tu contraseña** con nadie
4. **Cierra sesión** cuando termines de trabajar: `exit`
5. Puedes cambiar tu contraseña de máquina con `passwd` cuando estés conectado

---

**¿Dudas?** Pregunta al profesor o busca en el grupo de la clase.
