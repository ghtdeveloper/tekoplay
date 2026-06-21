#!/bin/bash
# Ejecuta este script UNA SOLA VEZ en tu máquina local para obtener
# los valores en base64 que debes pegar en GitHub Secrets.
#
# Uso: bash .github/encode-secrets.sh

echo ""
echo "======================================================"
echo "  VALORES PARA PEGAR EN GITHUB SECRETS"
echo "======================================================"
echo ""

# GOOGLE_SERVICES_JSON
if [ -f "android/app/google-services.json" ]; then
  echo "--- GOOGLE_SERVICES_JSON ---"
  base64 -w 0 android/app/google-services.json
  echo ""
  echo ""
else
  echo "[FALTA] android/app/google-services.json"
fi

# FIREBASE_OPTIONS_DART
if [ -f "lib/firebase_options.dart" ]; then
  echo "--- FIREBASE_OPTIONS_DART ---"
  base64 -w 0 lib/firebase_options.dart
  echo ""
  echo ""
else
  echo "[FALTA] lib/firebase_options.dart"
fi

# ENV_FILE
if [ -f ".env" ]; then
  echo "--- ENV_FILE ---"
  base64 -w 0 .env
  echo ""
  echo ""
else
  echo "[FALTA] .env"
fi

echo "======================================================"
echo "  SECRETS QUE DEBES CONFIGURAR MANUALMENTE:"
echo "======================================================"
echo ""
echo "FIREBASE_APP_ID"
echo "  Valor: 1:138445898352:android:a4923a2254fecc8c3aeab5"
echo ""
echo "FIREBASE_SERVICE_ACCOUNT"
echo "  Valor: JSON de la cuenta de servicio de Firebase"
echo "  Obtener en: Firebase Console > Configuracion del proyecto"
echo "  > Cuentas de servicio > Generar nueva clave privada"
echo ""
