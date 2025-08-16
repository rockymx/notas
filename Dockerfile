FROM --platform=$BUILDPLATFORM golang:1.23.5-bookworm as builder

# Argumentos para compilación multi-arquitectura
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app

# Instalar dependencias de compilación (compilador de C)
RUN apt-get update && apt-get install -y gcc-aarch64-linux-gnu gcc
# Instalar esbuild para compilar el frontend
RUN go install github.com/evanw/esbuild/cmd/esbuild@latest

# Descargar dependencias de Go
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copiar todo el código fuente
COPY . .

# Compilar el frontend (JS y CSS) y guardarlo en la carpeta 'dist'
RUN esbuild index.js --bundle --minify --format=esm --outfile=dist/bundle.js --loader:.js=jsx --jsx-factory=h --jsx-fragment=Fragment

# --- CORRECCIÓN DEFINITIVA ---
# Crear el archivo index.html que falta en el repositorio directamente en la carpeta 'dist'.
RUN echo '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Zen</title><link rel="stylesheet" href="/dist/bundle.css"></head><body><script type="module" src="/dist/bundle.js"></script></body></html>' > dist/index.html

# Compilar el backend de Go, incrustando la carpeta 'dist' completa
RUN CGO_ENABLED=1 CC=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64-linux-gnu-gcc" || echo "gcc") GOOS=$TARGETOS GOARCH=$TARGETARCH go build --tags "fts5" -v -o ./zen .

# Etapa 2: Imagen Final
FROM --platform=$TARGETPLATFORM debian:bookworm-slim

# Copiar solo el programa compilado desde la etapa anterior
COPY --from=builder /app/zen /zen

# Crear puntos de montaje para los datos persistentes
VOLUME /data
VOLUME /images

# Definir variables de entorno para las carpetas de datos
ENV DATA_FOLDER=/data
ENV IMAGES_FOLDER=/images

# Comando para ejecutar la aplicación
CMD ["/zen"]
