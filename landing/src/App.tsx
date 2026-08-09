import { Lightbulb, Sparkles, Newspaper, HardDrive, Apple, Download, CheckCircle2, Clock } from 'lucide-react';
import { LiquidEther } from './components/LiquidEther';
import { TiltedCard } from './components/TiltedCard';

const ANDROID_DOWNLOAD_URL =
  'https://github.com/Stradok/Idea_vault/releases/latest/download/IdeaVault.apk';

const FEATURES = [
  {
    icon: Lightbulb,
    title: 'Capture ideas',
    caption: 'Text, photo, or voice note',
    gradient: 'from-indigo-500 to-violet-600',
  },
  {
    icon: Sparkles,
    title: 'AI research',
    caption: 'Live market data, in seconds',
    gradient: 'from-fuchsia-500 to-pink-600',
  },
  {
    icon: Newspaper,
    title: 'Track news',
    caption: 'Stories matched to your idea',
    gradient: 'from-sky-500 to-blue-600',
  },
  {
    icon: HardDrive,
    title: 'Your own Drive',
    caption: 'Not our servers — yours',
    gradient: 'from-emerald-500 to-teal-600',
  },
];

const STATUS = [
  { label: 'Sign in with Google', ok: true },
  { label: 'Capture ideas (text/photo/voice)', ok: true },
  { label: 'Saved to your Google Drive', ok: true },
  { label: 'Research tab', ok: false },
  { label: 'iOS app', ok: false },
];

export default function App() {
  return (
    <div className="min-h-screen w-full bg-background text-foreground font-sans">
      {/* Hero */}
      <section className="relative w-full min-h-[92vh] flex items-center justify-center overflow-hidden">
        <div className="absolute inset-0 z-0">
          <LiquidEther
            colors={['#4f46e5', '#a855f7', '#22d3ee']}
            mouseForce={18}
            cursorSize={110}
            resolution={0.5}
            autoDemo
            autoSpeed={0.4}
            autoIntensity={2}
          />
        </div>
        {/* Readability scrim */}
        <div className="absolute inset-0 z-[1] bg-gradient-to-b from-background/40 via-background/60 to-background pointer-events-none" />

        <div className="relative z-10 flex flex-col items-center text-center px-6 max-w-2xl pointer-events-none">
          <div className="text-5xl mb-4">💡</div>
          <h1 className="text-4xl sm:text-6xl font-bold tracking-tight text-white mb-4">
            IdeaVault
          </h1>
          <p className="text-base sm:text-lg text-white/70 mb-10 max-w-md">
            Capture business ideas, get AI research and matched tools, and
            follow related news — saved straight to your own Google Drive.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 pointer-events-auto w-full sm:w-auto px-4 sm:px-0">
            <a
              href={ANDROID_DOWNLOAD_URL}
              className="flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-primary text-primary-foreground font-semibold text-sm hover:scale-105 active:scale-95 transition-transform shadow-[0_8px_30px_rgba(124,92,255,0.4)]"
            >
              <Download className="w-4 h-4" />
              Download for Android
            </a>
            <button
              disabled
              className="flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-white/5 text-white/40 font-semibold text-sm border border-white/10 cursor-not-allowed"
            >
              <Apple className="w-4 h-4" />
              iOS — Coming soon
            </button>
          </div>
          <p className="text-white/30 text-xs mt-4 pointer-events-none">
            This link always points to the latest test build.
          </p>
        </div>
      </section>

      {/* Features */}
      <section className="relative z-10 px-6 py-20 max-w-5xl mx-auto">
        <h2 className="text-center text-white/50 text-xs font-semibold tracking-[0.2em] uppercase mb-10">
          What it does
        </h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          {FEATURES.map((f) => (
            <TiltedCard
              key={f.title}
              containerHeight="180px"
              containerWidth="100%"
              imageHeight="180px"
              imageWidth="100%"
              rotateAmplitude={10}
              scaleOnHover={1.06}
              showMobileWarning={false}
              showTooltip
              captionText={f.title}
              displayOverlayContent
              overlayContent={
                <div className="text-center px-3">
                  <p className="text-white font-semibold text-sm">{f.title}</p>
                  <p className="text-white/70 text-xs mt-1">{f.caption}</p>
                </div>
              }
            >
              <div
                className={`w-full h-full bg-gradient-to-br ${f.gradient} flex items-center justify-center`}
              >
                <f.icon className="w-9 h-9 text-white/90" strokeWidth={1.5} />
              </div>
            </TiltedCard>
          ))}
        </div>
      </section>

      {/* Install instructions */}
      <section className="relative z-10 px-6 pb-20 max-w-lg mx-auto">
        <div className="bg-card border border-border rounded-2xl p-6 sm:p-8">
          <h2 className="text-sm font-semibold mb-5">How to install</h2>
          <ol className="space-y-4 text-sm text-white/70">
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-primary/20 text-primary text-xs font-bold flex items-center justify-center">1</span>
              Tap the download button above.
            </li>
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-primary/20 text-primary text-xs font-bold flex items-center justify-center">2</span>
              Open the downloaded file. If Android blocks it, tap Settings in
              the popup and allow installs from this app (one-time step).
            </li>
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-primary/20 text-primary text-xs font-bold flex items-center justify-center">3</span>
              Tap Install, then open IdeaVault and sign in with Google.
            </li>
          </ol>
        </div>
      </section>

      {/* Status */}
      <section className="relative z-10 px-6 pb-24 max-w-lg mx-auto">
        <div className="bg-card border border-border rounded-2xl p-6 sm:p-8">
          <h2 className="text-sm font-semibold mb-5">Current status</h2>
          <div className="divide-y divide-border">
            {STATUS.map((s) => (
              <div key={s.label} className="flex items-center justify-between py-3 text-sm">
                <span className="text-white/80">{s.label}</span>
                {s.ok ? (
                  <span className="flex items-center gap-1.5 text-emerald-400 text-xs font-semibold">
                    <CheckCircle2 className="w-3.5 h-3.5" /> Working
                  </span>
                ) : (
                  <span className="flex items-center gap-1.5 text-amber-400 text-xs font-semibold">
                    <Clock className="w-3.5 h-3.5" /> Not yet
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      <footer className="relative z-10 text-center pb-12 px-6">
        <p className="text-white/30 text-xs">
          Found something broken? Message{' '}
          <a href="mailto:khawajaamman@gmail.com" className="text-primary hover:underline">
            khawajaamman@gmail.com
          </a>{' '}
          with what you tapped and what happened.
        </p>
      </footer>
    </div>
  );
}
