import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const projectRoot = path.resolve(process.cwd());
const sourceArg = process.argv[2];

if (!sourceArg) {
  console.error('Usage: node tool/generate_app_icons.mjs <source-image>');
  process.exit(1);
}

const sourcePath = path.resolve(projectRoot, sourceArg);
const assetsDir = path.join(projectRoot, 'assets');
const iosIconDir = path.join(projectRoot, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
const androidResDir = path.join(projectRoot, 'android', 'app', 'src', 'main', 'res');
const normalizedSourcePath = path.join(assetsDir, 'app_icon_source.png');

const iosIcons = [
  ['Icon-App-20x20@1x.png', 20],
  ['Icon-App-20x20@2x.png', 40],
  ['Icon-App-20x20@3x.png', 60],
  ['Icon-App-29x29@1x.png', 29],
  ['Icon-App-29x29@2x.png', 58],
  ['Icon-App-29x29@3x.png', 87],
  ['Icon-App-40x40@1x.png', 40],
  ['Icon-App-40x40@2x.png', 80],
  ['Icon-App-40x40@3x.png', 120],
  ['Icon-App-60x60@2x.png', 120],
  ['Icon-App-60x60@3x.png', 180],
  ['Icon-App-76x76@1x.png', 76],
  ['Icon-App-76x76@2x.png', 152],
  ['Icon-App-83.5x83.5@2x.png', 167],
  ['Icon-App-1024x1024@1x.png', 1024],
];

const androidIcons = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
];

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function writePng(destPath, size, paddingRatio = 0.14) {
  const innerSize = Math.round(size * (1 - paddingRatio * 2));
  const icon = await sharp(sourcePath)
    .resize(innerSize, innerSize, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer();

  await sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: { r: 255, g: 255, b: 255, alpha: 1 },
    },
  })
    .composite([{ input: icon, gravity: 'center' }])
    .png()
    .toFile(destPath);
}

await ensureDir(assetsDir);
await ensureDir(iosIconDir);
await ensureDir(androidResDir);

await writePng(normalizedSourcePath, 1024, 0.14);

for (const [filename, size] of iosIcons) {
  await writePng(path.join(iosIconDir, filename), size, 0.14);
}

for (const [folder, size] of androidIcons) {
  const folderPath = path.join(androidResDir, folder);
  await ensureDir(folderPath);
  await writePng(path.join(folderPath, 'ic_launcher.png'), size, 0.12);
}

console.log(`Generated app icon assets from ${sourceArg}`);
