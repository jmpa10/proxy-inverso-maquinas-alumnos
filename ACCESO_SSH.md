# 🔐 Acceso SSH a Máquinas de Alumnos

## 📌 Resumen

El servidor bastion (servidorgp.somosdelprieto.com) actúa como proxy SSH y HTTPS para las máquinas de los alumnos. El sistema es dinámico y se configura desde el archivo [alumnos.csv](alumnos.csv).

## 🖥️ Acceso SSH con Proxy TCP por Puertos

Cada alumno accede **con su puerto dedicado**, el proxy Nginx redirige el tráfico TCP a su máquina:

```bash
ssh -p 2245 usuario@servidorgp.somosdelprieto.com
# Nginx redirige tráfico TCP a 192.168.5.45:22
# Introduce la contraseña de tu máquina
```

El puerto se asigna automáticamente según la IP de la máquina (22 + últimos 2 dígitos).

⚠️ **Importante**: NO hay autenticación en el bastion. Es un proxy TCP transparente.

### Tabla de Puertos SSH (Ejemplo)

| Usuario | IP Interna   | Puerto | Comando de Acceso                                    |
|---------|--------------|--------|------------------------------------------------------|
| alonso  | 192.168.5.45 | 2245   | `ssh -p 2245 usuario@servidorgp.somosdelprieto.com`  |
| victor  | 192.168.5.41 | 2241   | `ssh -p 2241 usuario@servidorgp.somosdelprieto.com`  |
| orwin   | 192.168.5.43 | 2243   | `ssh -p 2243 usuario@servidorgp.somosdelprieto.com`  |
| mcarmen | 192.168.5.42 | 2242   | `ssh -p 2242 usuario@servidorgp.somosdelprieto.com`  |
| mikel   | 192.168.5.46 | 2246   | `ssh -p 2246 usuario@servidorgp.somosdelprieto.com`  |
| luismi  | 192.168.5.44 | 2244   | `ssh -p 2244 usuario@servidorgp.somosdelprieto.com`  |
| miguel  | 192.168.5.47 | 2247   | `ssh -p 2247 usuario@servidorgp.somosdelprieto.com`  |

### 🔧 Configuración Inicial SSH

1. **Editar lista de alumnos:**
   Edita el archivo [alumnos.csv](alumnos.csv):
   ```csv
   usuario,ip
   nuevo_alumno,192.168.5.XX
   ```

2. **Regenerar configuraciones:**
   ```bash
   make down
   make build
   make up
   ```

3. **Configurar redirecciones de puerto en router:**
   Asegúrate de que los puertos 2241-2247 del router redirigen al bastion (192.168.5.10)
   ```bash
   scp bastion-proxy/install-ssh-bastion.sh root@servidorgp.somosdelprieto.com:/tmp/
   ssh root@servidorgp.somosdelprieto.com
   sudo /tmp/install-ssh-bastion.sh
   ```

4. **Cada alumno accede directamente:**
   ```bash
   ssh alonso@servidorgp.somosdelprieto.com
   # El bastion redirige automáticamente
   # Introduce la contraseña de TU máquina (la de siempre)
   ```

⚠️ **Nota**: No se gestionan contraseñas en el bastion - cada alumno usa la contraseña que ya tiene configurada en su propia máquina.

### 🔐 Configuración SSH Cliente (Opcional)

Para simplificar aún más, añade esto a `~/.ssh/config`:

```ssh-config
# Bastion Alumnos
Host alonso
    HostName servidorgp.somosdelprieto.com
    User alonso

Host victor
    HostName servidorgp.somosdelprieto.com
    User victor

Host orwin
    HostName servidorgp.somosdelprieto.com
    User orwin

# ... etc
```

Luego simplemente: `ssh alonso`

---

## 🔄 Método Alternativo: Puertos Dedicados

---

## 🔄 Método Alternativo: Puertos Dedicados

Si prefieres usar puertos dedicados en lugar del método de usuario, cada alumno tiene un puerto SSH basado en su IP:

### Puertos Asignados

| Alumno  | IP Interna      | Puerto SSH | Comando                                        |
|---------|-----------------|------------|------------------------------------------------|
| alonso  | 192.168.5.45    | **2245**   | `ssh -p 2245 usuario@servidorgp.somosdelprieto.com`     |
| victor  | 192.168.5.41    | **2241**   | `ssh -p 2241 usuario@servidorgp.somosdelprieto.com`     |
| orwin   | 192.168.5.43    | **2243**   | `ssh -p 2243 usuario@servidorgp.somosdelprieto.com`     |
| mcarmen | 192.168.5.42    | **2242**   | `ssh -p 2242 usuario@servidorgp.somosdelprieto.com`     |
| mikel   | 192.168.5.46    | **2246**   | `ssh -p 2246 usuario@servidorgp.somosdelprieto.com`     |
| luismi  | 192.168.5.44    | **2244**   | `ssh -p 2244 usuario@servidorgp.somosdelprieto.com`     |
| miguel  | 192.168.5.47    | **2247**   | `ssh -p 2247 usuario@servidorgp.somosdelprieto.com`     |

---

## 🌐 Acceso HTTPS (Apps Web)

El proxy también redirige automáticamente el tráfico HTTPS usando SNI:

- `https://app.alonso.servidorgp.somosdelprieto.com` → 192.168.5.45:443
- `https://app.victor.servidorgp.somosdelprieto.com` → 192.168.5.41:443
- etc.

Cada alumno configura un proxy inverso (Nginx/Traefik) en su máquina para servir sus aplicaciones.

## 🔄 Workflow Típico

1. **Conectar por SSH:**
   ```bash
   ssh alonso@servidorgp.somosdelprieto.com
   # Introduce la contraseña de tu propia máquina
   ```

2. **Desplegar aplicación:**
   ```bash
   docker-compose up -d
   ```

3. **Configurar proxy inverso local** (en la máquina del alumno):
   ```nginx
   server {
       listen 443 ssl;
       server_name app.alonso.servidorgp.somosdelprieto.com;
       
       ssl_certificate /etc/letsencrypt/live/app.alonso.../fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/app.alonso.../privkey.pem;
       
       location / {
           proxy_pass http://localhost:3000;
       }
   }
   ```

4. **Acceder desde internet:**
   ```
   https://app.alonso.servidorgp.somosdelprieto.com
   ```

## 🔐 Reglas del Firewall (Proxmox)

Asegúrate de que el firewall en 192.168.5.10 tenga abiertos:

- **Puerto 22**: SSH bastion con redirección automática
- **Puerto 443**: HTTPS con SNI
- **Puertos 2241-2247** (opcional): Proxies SSH por puerto si usas método alternativo

## 🚀 Comandos de Gestión

```bash
make help           # Ver todos los comandos
make init           # Inicializar proyecto
make build          # Construir imágenes
make up             # Levantar servicios
make restart        # Reiniciar nginx
make setup-bastion  # Generar script de instalación SSH
make status         # Ver estado
```

## 📝 Notas

- **Método recomendado**: Acceso SSH por usuario (puerto 22) - más simple para los alumnos
- **Método alternativo**: Puertos dedicados (22XX) - útil si no quieres crear usuarios en el servidor
- El proxy HTTPS funciona con ambos métodos
- Si añades más alumnos, actualiza STUDENTS en `.env` y regenera con `make restart`
