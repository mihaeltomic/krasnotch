import { Features } from "./components/Features";
import { Film } from "./components/Film";
import { Footer } from "./components/Footer";
import { Hero } from "./components/Hero";
import { Install } from "./components/Install";
import { States } from "./components/States";

export const App = () => (
  <>
    <Hero />
    <main>
      <Film />
      <States />
      <Features />
      <Install />
    </main>
    <Footer />
  </>
);
