import type { Metadata } from "next";
import { ClerkProvider } from "@clerk/nextjs";

export const metadata: Metadata = {
  title: "Kinstreak",
  description: "A private shared 100-day challenge tracker.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <ClerkProvider>
    <html lang="en">
      <body>{children}</body>
    </html>
    </ClerkProvider>
  );
}
