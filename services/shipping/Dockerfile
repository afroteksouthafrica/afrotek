FROM node:20-alpine
WORKDIR /app
COPY services/shipping/package.json ./package.json
RUN npm install --omit=dev
COPY services/shipping/index.js ./index.js
ENV PORT=3006
EXPOSE 3006
CMD ["node", "index.js"]
