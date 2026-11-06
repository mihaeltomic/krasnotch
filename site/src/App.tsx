import { Bento } from "./components/Bento";
import { Cta } from "./components/Cta";
import { Footer } from "./components/Footer";
import { Hero } from "./components/Hero";
import { Manifesto } from "./components/Manifesto";
import { Marquee } from "./components/Marquee";
import { Nav } from "./components/Nav";
import { Settings } from "./components/Settings";
import { StateAccordion } from "./components/StateAccordion";

export const App = () => (
  <main className="relative w-full max-w-full overflow-x-hidden">
    <div className="ambient" aria-hidden="true" />
    <Nav />
    <Hero />
    <Manifesto />
    <Bento />
    <Marquee />
    <StateAccordion />
    <Settings />
    <Cta />
    <Footer />
  </main>
);
