/**
 * Actualiza el documento app_versions/android en Firestore con la info del nuevo build.
 *
 * Variables de entorno requeridas:
 *   FIREBASE_SERVICE_ACCOUNT  — JSON de la cuenta de servicio (sin encodear)
 *   APK_URL                   — URL pública del APK arm64-v8a (compatibilidad hacia atrás)
 *   APK_URL_ARM64             — URL pública del APK arm64-v8a (dispositivos modernos)
 *   APK_URL_ARMEABI           — URL pública del APK armeabi-v7a (dispositivos antiguos)
 *   VERSION_CODE              — Número de build (github.run_number)
 *   VERSION_NAME              — Nombre de versión (ej: "1.0.0+42")
 *   RELEASE_NOTES             — Notas de la versión
 */

const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function updateVersion() {
  const versionCode  = parseInt(process.env.VERSION_CODE, 10);
  const versionName  = process.env.VERSION_NAME || '';
  const apkUrl       = process.env.APK_URL || '';        // arm64-v8a (compatibilidad)
  const apkUrlArm64  = process.env.APK_URL_ARM64 || apkUrl;
  const apkUrlArmeabi = process.env.APK_URL_ARMEABI || '';
  const notes        = process.env.RELEASE_NOTES || 'Nueva versión disponible';

  if (!apkUrl) {
    console.error('Error: APK_URL no está definida');
    process.exit(1);
  }

  await db.collection('app_versions').doc('android').set({
    version_code:     versionCode,
    version_name:     versionName,
    apk_url:          apkUrl,           // arm64-v8a — campo principal (compatibilidad)
    apk_url_arm64:    apkUrlArm64,      // dispositivos modernos (95%+)
    apk_url_armeabi:  apkUrlArmeabi,    // dispositivos antiguos 32-bit
    release_notes:    notes,
    force_update:     false,
    updated_at:       admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Firestore actualizado: versión ${versionName} (build ${versionCode})`);
  console.log(`  arm64-v8a:   ${apkUrlArm64}`);
  console.log(`  armeabi-v7a: ${apkUrlArmeabi}`);
}

updateVersion().catch((err) => {
  console.error('Error actualizando Firestore:', err);
  process.exit(1);
});
