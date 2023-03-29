# ViasEnConstruccion

**Nota:** Este proyecto fue remplazado por https://github.com/MaptimeBogota/OSM-elements-change-tracker

Identifica qué vías cambiaron de Construction a un tipo concreto de vía, para mapearlas mejor.

Este mecanismo es un script en Bash que se puede correr en cualquier máquina Linux.
Usa overpass para traer las vías en construcción. 
Después compara los datos recuperados con una versión previamente guardada en git.
Si encuentra diferencias envía un reporte a algunas personas por medio de mail.

## Instalación en Ubuntu

```
sudo apt -y install mutt
```

Y seguir algún tutorial de cómo configurarlo:

* https://www.makeuseof.com/install-configure-mutt-with-gmail-on-linux/
* https://www.dagorret.com.ar/como-utilizar-mutt-con-gmail/

Para esto hay que generar un password desde Gmail.


###  Programación desde cron

```

# Corre el verificador de vías en construcción.
0 2 * * * cd ViasEnConstruccion ; ./verificador.sh

# Borra logs viejos de ViasEnConstruccion.
0 0 * * * find ~/ViasEnConstruccion/ -maxdepth 1 -type f -name "*.log*" -mtime +15 -exec rm {} \;
0 0 * * * find ~/ViasEnConstruccion/ -maxdepth 1 -type f -name "*.json" -mtime +15 -exec rm {} \;
0 0 * * * find ~/ViasEnConstruccion/ -maxdepth 1 -type f -name "*.txt*" -mtime +15 -exec rm {} \;

