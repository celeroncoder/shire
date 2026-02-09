import { Navbar } from '@/sections/navbar'
import { Hero } from '@/sections/hero'
import { Features } from '@/sections/features'
import { HowItWorks } from '@/sections/how-it-works'
import { Tools } from '@/sections/tools'
import { Waitlist } from '@/sections/waitlist'
import { Footer } from '@/sections/footer'

function Divider() {
  return (
    <div className="flex justify-center px-6">
      <div className="w-full max-w-xs h-px bg-gradient-to-r from-transparent via-edge-light to-transparent" />
    </div>
  )
}

export default function App() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main>
        <Hero />
        <Features />
        <Divider />
        <HowItWorks />
        <Divider />
        <Tools />
        <Waitlist />
      </main>
      <Footer />
    </div>
  )
}
