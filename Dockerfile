FROM node:18-alpine
# Install build essentials for sharp/sqlite
RUN apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev nasm bash vips-dev

ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

WORKDIR /opt/
COPY package.json package-lock.json ./
RUN npm install --production=false

WORKDIR /opt/app
COPY . .
# Skip the TS check during build if it keeps failing
RUN npm run build

EXPOSE 1337
CMD ["npm", "run", "start"]