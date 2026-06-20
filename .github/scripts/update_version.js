/**
 * Actualiza el documento app_versions/android en Firestore con la info del nuevo build.
 *
 * Variables de entorno requeridas:
 *   FIREBASE_SERVICE_ACCOUNT  — JSON de la cuenta de servicio (sin encodear)
 *   APK_URL                   — URL pública de descarga del APK en Firebase Storage
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
  const versionCode = parseInt(process.env.VERSION_CODE, 10);
  const versionName = process.env.VERSION_NAME || '';
  const apkUrl      = process.env.APK_URL || '';
  const notes       = process.env.RELEASE_NOTES || 'Nueva versión disponible';

  if (!apkUrl) {
    console.error('Error: APK_URL no está definida');
    process.exit(1);
  }

  await db.collection('app_versions').doc('android').set({
    version_code:  versionCode,
    version_name:  versionName,
    apk_url:       apkUrl,
    release_notes: notes,
    force_update:  false,
    updated_at:    admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Firestore actualizado: versión ${versionName} (build ${versionCode})`);
  console.log(`   APK URL: ${apkUrl}`);
}

updateVersion().catch((err) => {
  console.error('Error actualizando Firestore:', err);
  process.exit(1);
});
