.PHONY: help init build up down restart logs status setup-bastion clean

help:
	@echo "Bastion Proxy - Gestión"
	@echo ""
	@echo "Comandos disponibles:"
	@echo "  make init           - Inicializar estructura del proyecto"
	@echo "  make build          - Construir imágenes Docker"
	@echo "  make up             - Levantar servicios"
	@echo "  make down           - Parar servicios"
	@echo "  make restart        - Reiniciar nginx"
	@echo "  make logs           - Ver logs en tiempo real"
	@echo "  make status         - Ver estado de servicios"
	@echo "  make setup-bastion  - Generar script de configuración SSH"
	@echo "  make clean          - Limpiar proyecto completo"
	@echo ""

init:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh init

build:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh build

up:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh up

down:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh down

restart:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh restart

logs:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh logs

status:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh status

setup-bastion:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh setup-bastion

clean:
	@chmod +x ./bastion-setup.sh
	@./bastion-setup.sh clean
