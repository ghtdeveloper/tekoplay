/**
 * Sube los APKs split (arm64-v8a y armeabi-v7a) a Firebase Storage
 * y escribe las URLs públicas en GITHUB_OUTPUT.
 *
 * Variables de entorno requeridas:
 *   FIREBASE_SERVICE_ACCOUNT — JSON de la cuenta de servicio (sin encodear)
 *   GITHUB_WORKSPACE         — raíz del repositorio (provisto automáticamente por Actions)
 *   GITHUB_OUTPUT            — archivo de salida de Actions (provisto automáticamente)
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

const PROJECT_ID = 'tekoplay-38f7b';
const BUCKET     = `${PROJECT_ID}.firebasestorage.app`;
const WORKSPACE  = process.env.GITHUB_WORKSPACE || path.resolve(__dirname, '../..');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential:    admin.credential.cert(serviceAccount),
  storageBucket: BUCKET,
});

const bucket = admin.storage().bucket();

async function uploadApk(localRelPath, storagePath) {
  const localPath = path.join(WORKSPACE, localRelPath);

  if (!fs.existsSync(localPath)) {
    throw new Error(`APK no encontrado: ${localPath}`);
  }

  console.log(`Subiendo ${path.basename(localPath)} → gs://${BUCKET}/${storagePath}`);

  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: {
      contentType:  'application/vnd.android.package-archive',
      cacheControl: 'public, max-age=0, must-revalidate',
    },
  });

  // Hacer el archivo público
  await bucket.file(storagePath).makePublic();

  // URL de descarga directa (Firebase Storage REST)
  const encoded = storagePath.split('/').map(encodeURIComponent).join('%2F');
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}?alt=media`;
}

async function main() {
  const arm64Url   = await uploadApk(
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    'app-updates/android/app-arm64-v8a-release.apk',
  );

  const armeabiUrl = await uploadApk(
    'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
    'app-updates/android/app-armeabi-v7a-release.apk',
  );

  // Escribir outputs para los pasos siguientes del workflow
  const outputFile = process.env.GITHUB_OUTPUT;
  if (outputFile) {
    fs.appendFileSync(outputFile, `arm64_url=${arm64Url}\n`);
    fs.appendFileSync(outputFile, `armeabi_url=${armeabiUrl}\n`);
  }

  console.log(`arm64-v8a:   ${arm64Url}`);
  console.log(`armeabi-v7a: ${armeabiUrl}`);
}

main().catch((err) => {
  console.error('Error subiendo APKs:', err.message);
  process.exit(1);
});
