FROM node:20-slim

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps \
  && node -e "for (const name of ['cors','express','pg','dotenv']) { console.log(name + ': ' + require.resolve(name)); }" \
  && npm ls --omit=dev cors express pg dotenv \
  && npm cache clean --force

COPY src ./src

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/api/ping').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "src/index.js"]
