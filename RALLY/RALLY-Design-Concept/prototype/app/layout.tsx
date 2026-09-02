import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://rally-tv.josephrcoakley.chatgpt.site'),
  title: 'Rally — Live TV, alive',
  description: 'A TV-first concept for live channels and every major game, designed around the remote.',
  openGraph: {
    title: 'RALLY — Live TV, alive.',
    description: 'Fifty channels. Every game. One calm, remote-first system.',
    images: [{ url: '/og.png', width: 1200, height: 630, alt: 'RALLY — Live TV, alive.' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'RALLY — Live TV, alive.',
    description: 'Fifty channels. Every game. One calm, remote-first system.',
    images: ['/og.png'],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
