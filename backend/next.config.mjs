/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    serverComponentsExternalPackages: [
      'openai',
      'firebase-admin',
      'pino',
      'sharp'
    ]
  }
};

export default nextConfig;

