# Use Node 18 as the base
FROM node:18-alpine

# Install system dependencies for Strapi/Sharp
RUN apk update && apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev vips-dev git > /dev/null 2>&1

# Set work directory
WORKDIR /opt/
COPY package.json package-lock.json ./
RUN npm install --only=production
ENV PATH /opt/node_modules/.bin:$PATH

# Copy application code
WORKDIR /opt/app
COPY . .

# Build the Strapi admin panel
RUN npm run build

# Expose the Strapi port
EXPOSE 1337

# Start the application
CMD ["npm", "run", "start"]