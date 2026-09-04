const fs = require("fs");
const path = require("path");

const sampleRate = 44100;
const outputDir = path.resolve(__dirname, "..", "assets", "audio");
fs.mkdirSync(outputDir, { recursive: true });

let seed = 0x5f3759df;
function noise() {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 0xffffffff * 2 - 1;
}

function clamp(value) {
  return Math.max(-1, Math.min(1, value));
}

function makeWav(name, seconds, sampleAt) {
  const count = Math.floor(seconds * sampleRate);
  const data = Buffer.alloc(44 + count * 2);
  data.write("RIFF", 0);
  data.writeUInt32LE(36 + count * 2, 4);
  data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(sampleRate, 24);
  data.writeUInt32LE(sampleRate * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write("data", 36);
  data.writeUInt32LE(count * 2, 40);
  for (let i = 0; i < count; i++) {
    const t = i / sampleRate;
    data.writeInt16LE(Math.round(clamp(sampleAt(t)) * 32767), 44 + i * 2);
  }
  fs.writeFileSync(path.join(outputDir, name), data);
  return data;
}

const files = [];
files.push(makeWav("dog_idle.wav", 0.8, (t) => {
  const fade = Math.min(t * 8, (0.8 - t) * 8, 1);
  return fade * (Math.sin(t * Math.PI * 2 * 58) * 0.11 + Math.sin(t * Math.PI * 2 * 116) * 0.035 + noise() * 0.012);
}));
files.push(makeWav("dog_run.wav", 0.42, (t) => {
  const pulse = [0.02, 0.22].reduce((sum, at) => sum + Math.exp(-Math.pow((t - at) / 0.025, 2)), 0);
  return pulse * (Math.sin(t * Math.PI * 2 * 96) * 0.22 + noise() * 0.15);
}));
files.push(makeWav("dog_jump.wav", 0.42, (t) => {
  const env = Math.exp(-t * 5.5);
  const frequency = 190 + t * 1450;
  return env * (Math.sin(t * Math.PI * 2 * frequency) * 0.28 + noise() * 0.055);
}));
files.push(makeWav("dog_attack.wav", 0.36, (t) => {
  const env = Math.exp(-t * 8);
  const frequency = 1180 - t * 1900;
  return env * (Math.sin(t * Math.PI * 2 * frequency) * 0.2 + noise() * 0.26);
}));
files.push(makeWav("dog_device.wav", 0.55, (t) => {
  const notes = [[0.02, 440], [0.18, 660], [0.34, 990]];
  return notes.reduce((sum, [at, freq]) => sum + Math.exp(-Math.pow((t - at) / 0.05, 2)) * Math.sin(t * Math.PI * 2 * freq) * 0.16, 0);
}));
files.push(makeWav("dog_hit.wav", 0.27, (t) => {
  const env = Math.exp(-t * 14);
  return env * (Math.sin(t * Math.PI * 2 * 122) * 0.27 + noise() * 0.23);
}));
files.push(makeWav("dog_death.wav", 0.85, (t) => {
  const env = Math.exp(-t * 2.8);
  const frequency = Math.max(42, 500 - t * 540);
  return env * (Math.sin(t * Math.PI * 2 * frequency) * 0.22 + noise() * 0.11);
}));

const gap = Buffer.alloc(Math.floor(sampleRate * 0.18) * 2);
const previewPcm = Buffer.concat(files.flatMap((file) => [file.subarray(44), gap]));
const preview = Buffer.alloc(44 + previewPcm.length);
preview.write("RIFF", 0);
preview.writeUInt32LE(36 + previewPcm.length, 4);
preview.write("WAVEfmt ", 8);
preview.writeUInt32LE(16, 16);
preview.writeUInt16LE(1, 20);
preview.writeUInt16LE(1, 22);
preview.writeUInt32LE(sampleRate, 24);
preview.writeUInt32LE(sampleRate * 2, 28);
preview.writeUInt16LE(2, 32);
preview.writeUInt16LE(16, 34);
preview.write("data", 36);
preview.writeUInt32LE(previewPcm.length, 40);
previewPcm.copy(preview, 44);
fs.writeFileSync(path.join(outputDir, "dog_sfx_preview.wav"), preview);
