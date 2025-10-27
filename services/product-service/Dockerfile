# Use lightweight Node.js Alpine image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy the application code
COPY index.js ./

# Expose the application port
EXPOSE 3002

# Set revision environment variable for health checks
ENV APP_REV=product-svc-0.0.2

# Start the application
CMD ["npm", "start"]
