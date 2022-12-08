#!/bin/bash

# Este script descarga las vías en construcción e identifica cuáles han
# sido terminadas.
#
# Autor: Andrés Gómez - AngocA
# Version: 20221208

set -euo pipefail

# Activar para depuración.
#set -xv

LOG_FILE=output.log
QUERY_FILE=query.txt
HIGHWAY_IDS=highways_ids.txt
HISTORIC_FILES_DIR=history
WAIT_TIME=2
REPORT=report.txt
REPORT_CONTENT=reportContent.txt
DIFF_FILE=reportDiff.txt
MAILS="angoca@yahoo.com,civil.melo@gmail.com"

echo "$(date) Starting process" >> ${LOG_FILE}

if [ -f ${LOG_FILE} ] ; then
 mv ${LOG_FILE} ${LOG_FILE}-$(date +%Y%m%d-%H%M)
fi

# Chequea prerequisitos.
set +e
## git
git --version > /dev/null 2>&1
if [ ${?} -ne 0 ] ; then
 echo "ERROR: Falta instalar git."
 exit 1
fi
## wget
wget --version > /dev/null 2>&1
if [ ${?} -ne 0 ] ; then
 echo "ERROR: Falta instalar wget."
 exit 1
fi
## mutt
mutt -v > /dev/null 2>&1
if [ ${?} -ne 0 ] ; then
 echo "ERROR: Falta instalar mutt como cliente para enviar mensajes."
 exit 1
fi
set -e

# Prepara el entorno.
mkdir -p ${HISTORIC_FILES_DIR} > /dev/null
cd ${HISTORIC_FILES_DIR}
git init >> ../${LOG_FILE} 2>&1
git config user.email "maptime.bogota@gmail.com"
git config user.name "Bot Chequeo vías en construcción"
cd - > /dev/null
if [ -f ${REPORT_CONTENT} ] ; then
 mv ${REPORT_CONTENT} ${REPORT_CONTENT}-$(date +%Y%m%d-%H%M)
fi
rm -f ${DIFF_FILE}
touch ${DIFF_FILE}

cat << EOF > ${REPORT}
Reporte de modificaciones en vías en construcción de Bogotá en OpenStreetMap.

Hora de inicio: $(date).

EOF

cat << EOF > "${QUERY_FILE}"
 [out:csv(::id)];
 area[name="Bogotá"][admin_level=7][boundary=administrative]->.searchArea;
 (
   way["highway"="construction"](area.searchArea);
 );
 out ids;
EOF

wget -O "${HIGHWAY_IDS}" --post-file="${QUERY_FILE}" \
  "https://overpass-api.de/api/interpreter"
tail -n +2 "${HIGHWAY_IDS}" > "${HIGHWAY_IDS}.tmp"
 mv "${HIGHWAY_IDS}.tmp" "${HIGHWAY_IDS}"

# Itera sobre cada segmento de vía, verificando si han habido cambios.
echo "Procesando segmentos de vía..." >> ${LOG_FILE}
while read -r ID ; do
 # echo "Procesando vía con id ${ID}."
 echo "Procesando vía con id ${ID}." >> ${LOG_FILE}

 # Define el query Overpass para un id específico de vía.
 cat << EOF > ${QUERY_FILE}
[out:json];
way(${ID});
(._;>;);
out; 
EOF
 cat ${QUERY_FILE} >> ${LOG_FILE}

 # Obtiene la geometría de un id específico de vía.
 set +e
 wget -O "via-${ID}.json" --post-file="${QUERY_FILE}" "https://overpass-api.de/api/interpreter" >> ${LOG_FILE} 2>&1

 RET=${?}
 set -e
 if [ ${RET} -ne 0 ] ; then
  echo "WARN: Falló la descarga de la vía ${ID}."
  echo "WARN: Falló la descarga de la vía ${ID}." >> "${LOG_FILE}"
  continue
 fi
 
 # Elimina la línea de fecha de OSM
 sed -i'' -e '/"timestamp_osm_base":/d' "via-${ID}.json"
 rm -f "via-${ID}.json-e"

 # Procesa el archivo descargado.
 if [ -r "${HISTORIC_FILES_DIR}/via-${ID}.json" ] ; then
  # Si hay un archivo histórico, lo compara con ese para ver diferencias.
  echo via-${ID}.json >> ${DIFF_FILE}
  set +e
  diff "${HISTORIC_FILES_DIR}/via-${ID}.json" "via-${ID}.json" >> ${DIFF_FILE}
  RET=${?}
  set -e
  if [ ${RET} -ne 0 ] ; then
   mv "via-${ID}.json" "${HISTORIC_FILES_DIR}/"
   cd "${HISTORIC_FILES_DIR}/"
   git commit "via-${ID}.json" -m "Nueva versión de vía ${ID}." >> "../${LOG_FILE}" 2>&1
   cd - > /dev/null
   echo "* Revisar https://osm.org/relation/${ID}" >> ${REPORT_CONTENT}
  else
   rm "via-${ID}.json"
  fi
 else
  # Si no hay archivo histórico, copia este archivo como histórico.
  mv "via-${ID}.json" "${HISTORIC_FILES_DIR}/"
  cd "${HISTORIC_FILES_DIR}/"
  git add "via-${ID}.json"
  git commit "via-${ID}.json" -m "Versión inicial de vía ${ID}." >> "../${LOG_FILE}" 2>&1
  cd - > /dev/null
 fi

 # Espera entre requests para evitar errores.
 # echo "Esperando ${WAIT_TIME} segundos entre requests..."
 sleep ${WAIT_TIME}

done < ${HIGHWAY_IDS}

if [ -f "${REPORT_CONTENT}" ] ; then
 echo "$(date) Sending mail" >> ${LOG_FILE}
 cat "${REPORT_CONTENT}" >> ${REPORT}
 echo >> ${REPORT}
 echo "Hora de fin: $(date)" >> ${REPORT}
 echo >> ${REPORT}
 echo "Este reporte fue creado por medio de el script verificador: https://github.com/MaptimeBogota/ViasEnConstruccion" >> ${REPORT}
 echo "" | mutt -s "Detección de diferencias en vías en construcción de Bogotá" -i "${REPORT}" -a "${DIFF_FILE}" -- "${MAILS}" >> ${LOG_FILE}
fi

# Borra archivos temporales
rm -f "${QUERY_FILE}" "${HIGHWAY_IDS}" "${REPORT}"

echo "$(date) Finishing process" >> ${LOG_FILE}
echo "$(date) =================" >> ${LOG_FILE}


