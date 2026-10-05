FROM node:24-slim

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY tsconfig.json ./
COPY migrations ./migrations
COPY src ./src

# O SQLite fica em /data (monte um volume nomeado aqui para não perder os dados ao redeployar).
RUN mkdir -p /data && chown -R node:node /data /app
USER node
VOLUME /data

ENV PORT=3000 \
    DATABASE_PATH=/data/filmfinder.db
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node_modules/.bin/tsx", "src/node/server.ts"]
