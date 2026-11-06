export const Film = () => (
  <section className="mx-auto max-w-6xl px-6">
    <div className="overflow-hidden border border-line bg-black">
      <video
        className="block aspect-video w-full"
        src="/krasnotch.mp4"
        poster="/poster.jpg"
        autoPlay
        muted
        loop
        playsInline
        controls
        preload="metadata"
        aria-label="Krasnotch demo: the notch glow changing as each setting changes"
      />
    </div>
  </section>
);
