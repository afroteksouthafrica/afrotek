FROM public.ecr.aws/docker/library/node:20-alpine

# ⬇️ Make build arg available and persist it as an environment variable
ARG APP_REV
ENV APP_REV=${APP_REV}

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm install --only=production

# Copy app (only index.js needed)
COPY index.js ./

EXPOSE 3002
CMD ["node", "index.js"]
