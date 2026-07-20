# CAudio

CAudio is a pure GML audio loading, decoding, and streaming library. It has no native extension and supports both VM and YYC builds.

## Formats

- WAV integer PCM: 8/16-bit direct playback and 24/32-bit conversion to signed 16-bit PCM, mono or stereo.
- WAV IEEE float32: converted to signed 16-bit PCM, mono or stereo.
- FLAC: mono or stereo, up to 32-bit source samples. Sources above 16-bit are converted to signed 16-bit PCM for GameMaker playback.
- Ogg Vorbis: native GameMaker streaming with playback, seek, position, looping, and cleanup through the CAudio API.
- Compressed WAV, unsupported sample widths, and channel counts other than mono/stereo are rejected instead of being played with an incorrect fallback format.

WAV streams read PCM directly from disk. FLAC streams decode through a 256 KB sliding file window and use SEEKTABLE entries when available. Ogg Vorbis delegates decoding and streaming to GameMaker's audio backend; `caudio_create_sound` intentionally returns `-1` for OGG.

## API

```gml
caudio_create_sound(path)
caudio_create_stream(path)
caudio_play(handle, priority = 0, loop = false)
caudio_free(handle)

caudio_stream_fill(stream)
caudio_stream_prime(stream, min_queued)
caudio_stream_pump(stream, min_queued, max_fills)
caudio_stream_on_async(stream, async_load, min_queued)
caudio_stream_is_playable(stream)
caudio_stream_seek(stream, seconds)
caudio_stream_set_loop(stream, loop)
caudio_stream_get_position(stream)
caudio_stream_free(stream)
```

Successful handles include:

- `kind`: `"wav"`, `"flac"`, or `"ogg"`.
- `mode`: `"buffer"` or `"stream"`.

Creation and seek functions return `-1` on failure. `caudio_free` is idempotent.

## Streaming

Prime a stream before playback, pump it with a bounded fill budget in Step, and forward Audio Playback events:

```gml
stream = caudio_create_stream("music.flac");
if (is_struct(stream)) {
    caudio_stream_prime(stream, 3);
    caudio_play(stream, 0, false);
}

// Step
caudio_stream_pump(stream, 3, 1);

// Async - Audio Playback
caudio_stream_on_async(stream, async_load, 3);

// Clean Up
caudio_free(stream);
stream = undefined;
```

Continue forwarding Audio Playback events after Clean Up, passing `undefined` when the stream handle has been discarded. CAudio keeps a callback registry for retired queues so Runner-owned buffers are deleted only after their final callback.

Stream looping is handled by CAudio refill logic, not by GameMaker's sound-instance loop flag. Seek recreates and primes the play queue, then restarts playback. Queue buffers carry their actual sample counts, and loop positions are normalized to source sample indices so short tails and natural loop boundaries remain accurate.

Ogg Vorbis streams are native streams rather than play queues. `caudio_stream_fill`, `caudio_stream_prime`, `caudio_stream_pump`, and `caudio_stream_on_async` are safe no-ops for OGG; looping and seek use the native sound instance. Poll `caudio_stream_is_playable` before playing on HTML5, where native streams may become playable asynchronously. The query also refreshes an OGG handle's duration when the backend reports it after creation.

## Example Rooms

Two example rooms use complete songs already included with the project:

- `rm_example_full_load` with `obj_example_full_load` loads `IF = Infinity.wav` completely through `caudio_create_sound` before playback.
- `rm_example_stream` with `obj_example_stream` streams and incrementally decodes `边境之城的童谣.flac` through `caudio_create_stream`, `caudio_stream_prime`, `caudio_stream_pump`, and `caudio_stream_on_async`.

The source songs were selected from the user's `Downloads` and `Music` folders and reuse the matching Included Files instead of adding duplicate copies. `rm_example_stream` is currently first in Room Order, followed by `rm_example_full_load` and the deterministic test `Room`.

Both examples support `Space` to pause or resume, `R` to restart, `Left`/`Right` to seek by 10 seconds, `L` to toggle looping, `Tab` to switch examples, and `Escape` to quit. Both objects forward Audio Playback events so retired streaming buffers can finish callback-driven reclamation across room changes.

## Verification

The included deterministic Runner tests cover:

- PCM MD5 comparison against FFmpeg reference output.
- Unknown-total-samples FLAC decoding through physical EOF without a final full-PCM buffer copy.
- Unknown-total FLAC streams learn their sample count and duration at clean EOF.
- FLAC constant, fixed predictor, LPC, mid/side stereo, 16-bit, mono, stereo, and 24-bit-to-s16 output.
- WAV PCM24, PCM32, float32, and WAVEFORMATEXTENSIBLE 24-in-32 full-buffer and streaming conversion hashes, plus 5.1 rejection.
- Corrupted, metadata-only, and frame-boundary-truncated FLAC rejection.
- Windowed FLAC frame CRC verification without per-frame fallback file reads when the frame remains in the active window.
- Ogg Vorbis signature probing, playable state, native playback, duration, seek, position, looping, safe queue-operation no-ops, and idempotent destruction.
- Sample-accurate WAV and FLAC seek.
- Looping, queue underrun recovery, delayed callbacks, repeated queue recreation, and idempotent cleanup.
- Short streams can enable looping after non-looping prime reaches EOF; malformed non-frame-aligned WAV data and negative WAV seeks are handled safely.
- Queue-generation ownership across seek, including stale callbacks whose queue or buffer handles could otherwise collide with current resources.
- Persistent retired-queue callback ownership after Clean Up discards the stream struct.
- WAV and FLAC position across natural short-stream loop boundaries, within one source sample.
- Windows VM and YYC execution.

VM build:

```powershell
gm-cli run "CAudio.yyp" --target=windows --runtime=vm
```

The repository's `gm-options.json` points YYC at the D-drive Visual Studio Community `VsDevCmd.bat`:

```powershell
gm-cli run "CAudio.yyp" --target=windows --runtime=native
```

If a release gate appears to reuse stale code, delete only the target build directory, such as `.gmcache/build-gms2-windows-VM` or `.gmcache/build-gms2-windows-YYC`, before rerunning. Keep the normal gm-cli cache so tools and the GameMaker runtime are not downloaded again.

## Release Status

Windows VM and YYC pass the complete deterministic Runner suite. `gm-options.json` pins YYC to the D-drive Visual Studio Community instance that provides the required `v142` toolset and Windows SDK.

Remaining release risks:

- FLAC streams verify every frame CRC. CRC ranges inside the active 256 KB window are checked directly; a representative 24-frame fill dropped from 48 fallback file reads to zero while preserving corruption rejection.
- The GameMaker incremental build cache has reused stale event code during verification. Clear only the affected `.gmcache/build-gms2-windows-VM` or `.gmcache/build-gms2-windows-YYC` directory when this occurs; do not replace the complete gm-cli cache.
- HTML5 is unsupported because the implementation uses synchronous binary file APIs.
- Ogg containers using codecs other than Vorbis are rejected; OGG buffer sounds are not implemented.
