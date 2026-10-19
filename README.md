# ฝึกตน (Fukton)

A personal Android app for training mindfulness, the mind, and focus while studying.

## Built by its own user

I am not building this for a market. I am a third-year Computer Engineering student, and
I wrote ฝึกตน for myself: I use it every day, on my own phone, to get through classes,
exam season and the habits I want to change. Every feature exists because I needed it,
and every change comes from something I noticed while actually using the app.

That shapes how the project works:

- **The developer is the user.** Features are tested in real life before they are kept.
  If something does not help me, it is reworked or removed.
- **Built around my real week.** The schedule, the exam-prep plan and the study rounds
  follow my actual timetable and subjects, not a generic template.
- **Private by design.** All data stays on the phone. Nothing is sent to the internet.

Others are welcome to look around or try it, but it is tuned for one person: me.

## Inspiration

- The Khaggavisana Sutta (the Rhinoceros Sutta): "Be like a lion, not startled by sounds;
  be like the wind, not caught in a net; be like a lotus, untouched by water…"
- The movement-based mindfulness practice of Luang Pho Thian Cittasubho.

## What's inside

- **Today** — a lotus pond that blooms as you practise, a daily intention, five
  commitments, a "clean mind" detox from negative media, and a daily dhamma card.
- **Practice** — mindful classroom sessions, breath watching, Luang Pho Thian's 14 hand
  movements, and mindful studying.
- **Study tools** — a 3-step study round (read it yourself and ask AI when stuck, then close
  the slides and explain it back to AI, then fix and retry), a final-exam prep plan ranked
  by weak subjects, a weekly life schedule, a guide on studying effectively, and
  "just start for 2 minutes" for tasks that are hard to begin.
- **Courtyard** — mind games (breath counting, pink lotus / gold lotus, mind reading, lotus
  path memory, body awareness) and thinking games (puzzles, quick thinking, flashcards),
  plus lotus seeds, pond decoration and a dhamma card album.
- **Verses** — Thai verses with their meaning and something to try today.
- **Path** — stats, lotus totals and medals.

## Download

Go to this repository's **Releases** page and download the latest `fukton-vN.apk`.
It installs over the previous version and keeps all practice data.

## Build

- **GitHub:** every push to `main` builds the APK and publishes a Release automatically
  (`.github/workflows/build-apk.yml`). The `DEBUG_KEYSTORE_B64` secret must hold the
  signing key in base64 so new builds install over the existing app.
- **Windows:** `powershell -ExecutionPolicy Bypass -File build-apk.ps1`

Built with Flutter.
