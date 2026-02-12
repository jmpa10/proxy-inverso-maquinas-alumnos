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
    
    # Create stream.d subdirectory for stream configs
    stream_dir = OUTPUT / 'stream.d'
    stream_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate HTTPS stream-map-entries.conf
    stream_entries = []
    for s, ip in students.items():
        stream_entries.append(f"        ~^.*\\.{s}\\.{DOMAIN}$ {ip}:443;")
    stream_entries.append("        default 127.0.0.1:8443;")
    
    (stream_dir / 'stream-map-entries.conf').write_text('\n'.join(stream_entries))
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
    
    (stream_dir / 'ssh-proxy.conf').write_text('\n'.join(ssh_blocks))
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
