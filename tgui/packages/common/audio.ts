/**
 * Small Web Audio helper for synthesized UI blips (hover/click/confirm/error
 * affordances) shared between the `tgui` and `tgui-panel` packages. Extracted
 * from tgui-panel's CRT click sound so both packages get identical behavior
 * (one cached AudioContext, one fallback strategy) instead of duplicating the
 * oscillator boilerplate.
 *
 * This is for short synthesized tones only — real sampled audio (spawn
 * confirmations, notification chimes) should go through BYOND's asset
 * pipeline (`/datum/asset/simple` + `resolveAsset()` + `<audio>`) instead,
 * since Web Audio here has no way to play a sample file, only generate one.
 */

let audioCtx: AudioContext | null = null;

const getAudioContext = (): AudioContext | null => {
  try {
    if (!audioCtx || audioCtx.state === 'closed') {
      audioCtx = new AudioContext();
    }
    return audioCtx;
  } catch {
    return null;
  }
};

export type BlipOptions = {
  /** Starting oscillator frequency, in Hz. */
  freq: number;
  /** Frequency the oscillator ramps to by the end of the blip, in Hz. */
  freqEnd: number;
  /** Total blip duration, in seconds. */
  duration: number;
  /** Peak gain (0-1). Kept low by default — these play on every click. */
  gain?: number;
  /** Oscillator waveform. */
  type?: OscillatorType;
};

/** Plays a short synthesized tone. Silently no-ops if Web Audio is unavailable. */
export const playBlip = (options: BlipOptions) => {
  const { freq, freqEnd, duration, gain = 0.06, type = 'square' } = options;
  const ctx = getAudioContext();
  if (!ctx) {
    return;
  }
  try {
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();
    osc.connect(gainNode);
    gainNode.connect(ctx.destination);
    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      freqEnd,
      ctx.currentTime + duration * 0.67,
    );
    gainNode.gain.setValueAtTime(gain, ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(
      0.001,
      ctx.currentTime + duration,
    );
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  } catch {
    // Web Audio unavailable mid-call — silent fallback.
  }
};

/** The CRT click sound tgui-panel already used, kept as a named preset so other packages can reuse the exact same feel. */
export const playClickBlip = () =>
  playBlip({ freq: 880, freqEnd: 220, duration: 0.06, gain: 0.06 });

/** A slightly lower, longer tone for error/rejection feedback. */
export const playErrorBlip = () =>
  playBlip({
    freq: 220,
    freqEnd: 110,
    duration: 0.12,
    gain: 0.05,
    type: 'sawtooth',
  });
