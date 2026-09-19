# Use Node.js
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json ./
RUN npm install --production

# Copy application files
COPY app.js ./

# Expose port 80
EXPOSE 80

# Start the application
CMD ["node", "app.js"]